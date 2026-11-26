#!/usr/bin/env python3
"""Procedural hard-surface equipment generator for Hollow Reign.

Writes GLB models (metres, +Y along the blade / up the shield) and the shared detail textures to
assets/models/gear/. No Blender, no image-to-3D: every vertex comes from the parameter sets below.

    python3 tools/gear_gen.py            # all items, both LODs, textures, manifest
    python3 tools/gear_gen.py wayfarer   # one item

Conventions (see docs/EQUIPMENT_DESIGN_BIBLE.md):
  swords  : origin = centre of the main hand on the grip, +Y to the tip, guard along X, flat of the blade faces Z
  shields : origin = centre of the hand grip, +Y up, the FRONT faces -Z (the rig's "outward"), +X is the bearer's right
"""
import json, math, os, struct, sys
import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "models", "gear")
UVK = 16.0          # UV units per metre: one texture tile covers 6.25 cm


# ============================================================================ mesh builder
class Builder:
    """Collects triangles with a smoothing group and a material each. Normals are averaged only between
    faces that share a position AND a group, so hard edges are exactly where the modelling code puts them."""

    def __init__(self):
        self.P, self.UV, self.G, self.M = [], [], [], []
        self.gbase = 0
        self.start = 0

    def part(self):
        self.gbase += 10_000_000
        self.start = len(self.P)

    def tri(self, a, b, c, ua, ub, uc, g, m):
        n = np.cross(b - a, c - a)
        if np.dot(n, n) < 1e-18:
            return
        self.P.append((a, b, c))
        self.UV.append((ua, ub, uc))
        self.G.append(self.gbase + g)
        self.M.append(m)

    def close(self, flip=None):
        """Ends a closed part: turns it inside out if its volume came out negative."""
        vol = 0.0
        for a, b, c in self.P[self.start:]:
            vol += np.dot(a, np.cross(b, c))
        if (vol < 0) if flip is None else flip:
            for i in range(self.start, len(self.P)):
                a, b, c = self.P[i]
                ua, ub, uc = self.UV[i]
                self.P[i] = (a, c, b)
                self.UV[i] = (ua, uc, ub)


def box_uv(p, n, grain=1, k=UVK):
    """Box projection. `grain` is the axis the brushing runs along where the face allows it (it becomes V)."""
    a = int(np.argmax(np.abs(n)))
    others = [i for i in range(3) if i != a]
    v = grain if grain in others else others[1]
    u = [i for i in others if i != v][0]
    return np.array([p[u] * k, p[v] * k])


def loft(B, rings, mat, gu=None, gv=None, smooth_u=False, smooth_v=True, cap0=True, cap1=True,
         uv="box", grain=1, urep=1.0, vk=UVK, cap_mat=None, k=UVK, gfun=None):
    """Skins a stack of closed rings [R, N, 3]. `mat` is a name or an [R-1][N] table. Faces are grouped by
    gu[column] and gv[ring interval]; equal ids are smoothed together.
    uv: "box" (projection, brushing along `grain`), ("planar", u_axis, v_axis) or "cyl" (u around, v along)."""
    rings = np.asarray(rings, dtype=float)
    R, N, _ = rings.shape
    if gu is None:
        gu = [0] * N if smooth_u else list(range(N))
    if gv is None:
        gv = [0] * (R - 1) if smooth_v else list(range(R - 1))
    cen = rings.mean(axis=1)
    vlen = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(cen, axis=0), axis=1))])

    def m_at(r, c):
        return mat if isinstance(mat, str) else mat[r][c]

    def uvs(pts, rc, n):
        if uv == "box":
            return [box_uv(p, n, grain, k) for p in pts]
        if uv == "cyl":
            return [np.array([c / N * urep, vlen[r] * vk]) for r, c in rc]
        _, ua, va = uv
        return [np.array([p[ua] * k, p[va] * k]) for p in pts]

    for r in range(R - 1):
        for c in range(N):
            c2 = (c + 1) % N
            pts = [rings[r, c], rings[r, c2], rings[r + 1, c2], rings[r + 1, c]]
            rc = [(r, c), (r, c + 1), (r + 1, c + 1), (r + 1, c)]
            n = np.cross(pts[1] - pts[0], pts[3] - pts[0]) + np.cross(pts[3] - pts[2], pts[1] - pts[2])
            u = uvs(pts, rc, n)
            g = gfun(r, c) if gfun else gu[c] * 2000 + gv[r]
            m = m_at(r, c)
            B.tri(pts[0], pts[1], pts[2], u[0], u[1], u[2], g, m)
            B.tri(pts[0], pts[2], pts[3], u[0], u[2], u[3], g, m)
    for end, on in ((0, cap0), (R - 1, cap1)):
        if not on:
            continue
        ctr = cen[end]
        cm = cap_mat or m_at(min(end, R - 2), 0)
        for c in range(N):
            a, b = rings[end, c], rings[end, (c + 1) % N]
            if end == 0:
                a, b = b, a
            n = np.cross(a - ctr, b - ctr)
            B.tri(ctr, a, b, box_uv(ctr, n, grain, k), box_uv(a, n, grain, k), box_uv(b, n, grain, k), 9_000_000 + end, cm)


def ring_xz(y, pts):
    """A ring in the XZ plane at height y from 2D points [(x, z)]."""
    return [(x, y, z) for x, z in pts]


def ngon(n, rx, rz, phase=0.0):
    return [(rx * math.cos(phase + 2 * math.pi * i / n), rz * math.sin(phase + 2 * math.pi * i / n)) for i in range(n)]


def chamfer_rect(hx, hz, c):
    """Octagon: a rectangle (half sizes hx, hz) with its four corners cut by c."""
    c = min(c, hx * 0.95, hz * 0.95)
    return [(hx, -hz + c), (hx, hz - c), (hx - c, hz), (-hx + c, hz), (-hx, hz - c), (-hx, -hz + c), (-hx + c, -hz), (hx - c, -hz)]


def lathe(B, prof, mat, seg=12, rz_scale=1.0, hard=(), facet=False, uv="box", grain=1, urep=2.0, vk=UVK, phase=0.0, y_axis=1):
    """Turns a profile [(y, radius)] about Y (or about Z when y_axis=2: wheel pommels, bosses).
    `hard` lists profile indices where the surface creases. `facet` gives flat sides (n-gon bar stock)."""
    rings, gv, g = [], [], 0
    for i, (y, r) in enumerate(prof):
        pts = ngon(seg, max(r, 1e-6), max(r, 1e-6) * rz_scale, phase)
        if y_axis == 1:
            rings.append([(x, y, z) for x, z in pts])
        else:
            rings.append([(x, z, y) for x, z in pts])
        if i > 0:
            gv.append(g)
        if i in hard:
            g += 1
    mats = mat if isinstance(mat, str) else [[m] * seg for m in mat]
    loft(B, rings, mats, gv=gv, smooth_u=not facet, uv=uv, grain=grain, urep=urep, vk=vk)


def block(B, x0, x1, y0, y1, z0, z1, c, mat, grain=0, slope=0.0):
    """A box with every edge chamfered by c (built as a loft along Y of chamfered rectangles).
    `slope` shears it in Z along X so a plate can sit on a curved board."""
    hx, hz = (x1 - x0) / 2, (z1 - z0) / 2
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    rings = []
    for y, inset in ((y0, c), (y0 + c, 0.0), (y1 - c, 0.0), (y1, c)):
        rings.append([(cx + x, y, cz + z + slope * x) for x, z in chamfer_rect(hx - inset, hz - inset, c * 0.8)])
    B.part()
    loft(B, rings, mat, smooth_u=False, smooth_v=False, grain=grain)
    B.close()


# ============================================================================ sword parts
def blade(B, y0, length, prof, seg_mats, seg_groups, stations):
    """Blade as a loft of cross-sections. prof(s) returns the K points of one quadrant from the cutting edge
    (w, e) to the centre line (0, t). seg_mats / seg_groups name the K-1 faces between them; a group ending in
    '*' is shared across the centre line (a fuller is one smooth trough), every other face is its own facet."""
    K = len(seg_mats) + 1
    rings = []
    for s in stations:
        q = prof(s)
        top = q + [(-x, z) for x, z in reversed(q[:-1])]
        bot = [(-x, -z) for x, z in q] + [(x, -z) for x, z in reversed(q[:-1])]
        rings.append(ring_xz(y0 + s * length, top + bot))
    half_m = list(seg_mats) + list(reversed(seg_mats))
    mats_row = half_m + ["edge"] + half_m + ["edge"]
    ids, gid = {}, []
    for face in ("t", "b"):
        for side, lst in (("r", seg_groups), ("l", list(reversed(seg_groups)))):
            for g in lst:
                key = (face, g) if g.endswith("*") else (face, side, g)
                gid.append(ids.setdefault(key, len(ids)))
        gid.append(ids.setdefault(("flat", face), len(ids)))
    B.part()
    loft(B, rings, [mats_row] * (len(stations) - 1), gu=gid, smooth_v=True, uv=("planar", 0, 1), cap1=False)
    B.close()


def stations_for(q, marks=(), tip_from=0.85):
    """Stations along a blade: even through the body, extra at `marks`, dense through the tip."""
    body = int(round(12 * q)) + 2
    tip = int(round(9 * q)) + 3
    s = list(np.linspace(0.0, tip_from, body)) + [tip_from + (1 - tip_from) * (1 - (1 - i / tip) ** 1.6) for i in range(1, tip + 1)]
    for m in marks:
        s.append(m)
    s = sorted(set(round(float(x), 5) for x in s))
    out = [s[0]]
    for x in s[1:]:
        if x - out[-1] > 0.004:
            out.append(x)
    out[-1] = 1.0
    return out


def taper(s, w0, w1, s_tip, p=1.8):
    """Half width: straight taper w0 -> w1 up to s_tip, then an ogive to the point."""
    if s <= s_tip:
        return w0 + (w1 - w0) * s / s_tip
    u = (s - s_tip) / (1 - s_tip)
    return w1 * (1 - u ** p)


def tip_thin(s, s_tip):
    if s <= s_tip:
        return 1.0
    u = (s - s_tip) / (1 - s_tip)
    return max(0.0, 1 - u ** 3) ** 0.6


def fuller_pts(wf, t, d, n):
    """Trough from the lip (wf, t) to the centre (0, t-d): n points after the lip."""
    return [(wf * math.cos(a), t - d * math.sin(a)) for a in [math.pi / 2 * i / n for i in range(1, n + 1)]]


def guard_bar(B, half, y, hy, hz, mat, end_scale=0.7, sweep=0.0, sweep_pow=1.6, seg=6, chamfer=0.25, flare=0.0, grain=0):
    """Cross-guard along X: a chamfered bar that slims toward its ends; `sweep` lifts the ends toward the tip,
    `flare` swells the last few centimetres into a stop."""
    rings = []
    n = seg * 2 + 1
    for i in range(n):
        u = -1 + 2 * i / (n - 1)
        a = abs(u)
        k = 1 - (1 - end_scale) * a ** 1.3 + flare * max(0.0, (a - 0.8) / 0.2) ** 2
        yy = y + sweep * a ** sweep_pow
        sec = chamfer_rect(hy * k, hz * k, min(hy, hz) * k * chamfer * 2)
        rings.append([(u * half, yy + a_, b_) for a_, b_ in sec])
    # end faces get a shallow pyramid chamfer
    e0 = [(rings[0][j][0] - hy * 0.25, y + sweep + (rings[0][j][1] - y - sweep) * 0.6, rings[0][j][2] * 0.6) for j in range(8)]
    e1 = [(rings[-1][j][0] + hy * 0.25, y + sweep + (rings[-1][j][1] - y - sweep) * 0.6, rings[-1][j][2] * 0.6) for j in range(8)]
    rings = [e0] + rings + [e1]
    gv = [0] + [1] * (n - 1) + [2]
    B.part()
    loft(B, rings, mat, gv=gv, smooth_u=False, grain=grain)
    B.close()


def grip(B, y_top, y_bot, rx, rz, mat, seg=12, swell=0.06, taper_bot=0.9, wraps=26.0, stations=7):
    """Oval grip core between two heights with a slight barrel swell; cylindrical UVs carry the wrap pattern."""
    prof = []
    for i in range(stations):
        u = i / (stations - 1)
        k = (1 + swell * math.sin(math.pi * u)) * (1 - (1 - taper_bot) * u)
        prof.append((y_top + (y_bot - y_top) * u, rx * k))
    B.part()
    lathe(B, prof, mat, seg=seg, rz_scale=rz / rx, uv="cyl", urep=2.0, vk=wraps)
    B.close()


def collar(B, y0, y1, rx, rz, mat, seg=12, c=0.0012):
    """A ferrule / riser ring on the grip: short, proud, chamfered both sides."""
    B.part()
    lathe(B, [(y0, rx - c), (y0 + c, rx), (y1 - c, rx), (y1, rx - c)], mat, seg=seg, rz_scale=rz / rx, hard=(1, 2), grain=0)
    B.close()


# ============================================================================ swords
def build_wayfarer(B, q):
    """Starter arming sword: fullered lenticular blade, straight octagonal cross, graphite cord grip, wheel pommel."""
    seg = 12 if q >= 1 else 6
    nf = 3 if q >= 1 else 1
    L, y0 = 0.80, 0.066
    f_end = 0.60

    def prof(s):
        w = taper(s, 0.0265, 0.0160, 0.84, 1.9)
        t = (0.0031 - 0.0015 * s) * tip_thin(s, 0.9)
        b = min(0.0042, w * 0.45)
        fu = max(0.0, 1 - (s / f_end) ** 6) ** 0.5 if s < f_end else 0.0
        wf = min(0.0078 * (1 - 0.25 * s) * fu, (w - b) * 0.6)
        d = 0.0012 * min(1.0, fu * 2.0)
        return [(w, 0.0), (w - b, t * 0.52), (wf, t)] + fuller_pts(wf, t, d, nf)

    blade(B, y0, L, prof, ["edge", "steel"] + ["fuller"] * nf, ["bev", "flat"] + ["f*"] * nf, stations_for(q, (f_end - 0.03, f_end)))
    guard_bar(B, 0.098, 0.059, 0.0070, 0.0095, "steel", end_scale=0.72, seg=4 if q >= 1 else 2, flare=0.16)
    block(B, -0.021, 0.021, 0.050, 0.071, -0.0135, 0.0135, 0.0028, "steel")
    grip(B, 0.050, -0.056, 0.0150, 0.0120, "grip", seg=seg, stations=7 if q >= 1 else 3)
    if q >= 1:
        collar(B, 0.046, 0.051, 0.0166, 0.0136, "steel", seg)
        collar(B, -0.058, -0.053, 0.0156, 0.0128, "steel", seg)
    # wheel pommel, axis along Z: flat faces, chamfered rim, shallow recessed centre
    B.part()
    pz, pr = 0.0125, 0.0235
    prof_w = [(-pz, 0.0001), (-pz, 0.010), (-pz - 0.0008, 0.011), (-pz - 0.0008, pr - 0.0055), (-pz + 0.004, pr),
              (pz - 0.004, pr), (pz + 0.0008, pr - 0.0055), (pz + 0.0008, 0.011), (pz, 0.010), (pz, 0.0001)]
    if q < 1:
        prof_w = [(-pz, 0.0001), (-pz, pr - 0.005), (-pz + 0.004, pr), (pz - 0.004, pr), (pz, pr - 0.005), (pz, 0.0001)]
    lathe(B, prof_w, "steel", seg=20 if q >= 1 else 8, hard=range(len(prof_w)), y_axis=2, grain=0)
    for i in range(B.start, len(B.P)):
        B.P[i] = tuple(p + np.array([0.0, -0.079, 0.0]) for p in B.P[i])
    B.close()
    if q >= 1:
        block(B, -0.0045, 0.0045, -0.107, -0.1015, -0.0045, 0.0045, 0.0012, "steel")
    return {"class": "sword", "name": "Wayfarer", "blade": L, "tip": y0 + L, "pommel": 0.107 if q >= 1 else 0.1025,
            "grip_clear": 0.106, "guard_span": 0.196, "hands": 1}


def build_oathbreaker(B, q):
    """Practical greatsword: blunt ricasso, broad shallow fuller, long two-hand grip split by a steel riser."""
    seg = 12 if q >= 1 else 6
    nf = 3 if q >= 1 else 1
    L, y0 = 1.21, 0.076
    r_end, f0, f_end = 0.105, 0.03, 0.56

    def prof(s):
        ric = 1.0 - min(1.0, max(0.0, (s - r_end) / 0.03))        # 1 in the ricasso, 0 once the edge is ground
        w = taper(s, 0.0300, 0.0185, 0.88, 1.8) - 0.0030 * ric
        t = (0.0044 - 0.0023 * s) * tip_thin(s, 0.93)
        e = 0.0030 * ric
        b = min(0.0052, w * 0.45) * (1 - 0.6 * ric)
        fu = 0.0
        if f0 < s < f_end:
            fu = min(1.0, (s - f0) / 0.02) ** 0.5 * max(0.0, 1 - ((s - f0) / (f_end - f0)) ** 6) ** 0.5
        wf = min(0.0105 * (1 - 0.3 * s) * fu, (w - b) * 0.6)
        d = 0.0014 * min(1.0, fu * 2.0)
        tb = t * 0.5 + (t * 0.92 - t * 0.5) * ric
        return [(w, e), (w - b, max(tb, e)), (wf, t)] + fuller_pts(wf, t, d, nf)

    blade(B, y0, L, prof, ["edge", "steel"] + ["fuller"] * nf, ["bev", "flat"] + ["f*"] * nf,
          stations_for(q, (f0, f0 + 0.02, r_end, r_end + 0.03, f_end - 0.03, f_end), 0.88))
    guard_bar(B, 0.158, 0.064, 0.0085, 0.0120, "steel", end_scale=0.62, sweep=0.012, seg=5 if q >= 1 else 2, flare=0.2)
    block(B, -0.027, 0.027, 0.052, 0.080, -0.0165, 0.0165, 0.0035, "steel")
    # two grip sections either side of a riser where the hands divide
    grip(B, 0.052, -0.072, 0.0160, 0.0128, "grip", seg=seg, stations=6 if q >= 1 else 3, swell=0.04, taper_bot=0.96)
    grip(B, -0.078, -0.250, 0.0152, 0.0124, "grip", seg=seg, stations=7 if q >= 1 else 3, swell=0.05, taper_bot=0.84)
    collar(B, -0.0795, -0.0705, 0.0182, 0.0150, "steel", seg, 0.002)
    if q >= 1:
        collar(B, 0.046, 0.0535, 0.0178, 0.0146, "steel", seg, 0.0015)
        collar(B, -0.254, -0.247, 0.0150, 0.0124, "steel", seg, 0.0015)
    # faceted pear ("scent-stopper") pommel, eight flats
    B.part()
    lathe(B, [(-0.250, 0.0125), (-0.262, 0.0150), (-0.292, 0.0235), (-0.312, 0.0215), (-0.322, 0.0130), (-0.324, 0.0060)],
          "steel", seg=8, facet=True, hard=(1, 2, 3, 4), phase=math.pi / 8)
    B.close()
    return {"class": "greatsword", "name": "Oathbreaker", "blade": L, "tip": y0 + L, "pommel": 0.324,
            "grip_clear": 0.302, "guard_span": 0.316, "hands": 2, "off_hand": -0.165}


def build_eternal_edge(B, q):
    """Legendary: two ground steel edge rails on a recessed graphite core that carries one hairline light
    channel; short forward-swept guard with a chevron blade collar; hand-and-a-half grip, hexagonal cap."""
    seg = 12 if q >= 1 else 6
    L, y0 = 0.865, 0.066
    c_end, ch0, ch_end = 0.70, 0.075, 0.60

    def prof(s):
        w = taper(s, 0.0220, 0.0165, 0.78, 2.1)
        t = (0.0033 - 0.0016 * s) * tip_thin(s, 0.9)
        b = min(0.0036, w * 0.45)
        cf = max(0.0, 1 - (s / c_end) ** 3) if s < c_end else 0.0        # core closes to a point
        cw = min(0.0078 * cf, (w - b) * 0.62)
        step = 0.00055 * min(1.0, cf * 4)
        on = 1.0 if ch0 <= s <= ch_end else 0.0
        hw = min(0.0011 * on, cw * 0.5)
        hd = 0.0010 * on
        return [(w, 0.0), (w - b, t * 0.5), (cw, t), (cw * 0.9, t - step), (hw, t - step), (hw, t - step - hd), (0.0, t - step - hd)]

    mats = ["edge", "steel", "graphite", "graphite", "glow", "glow"]
    groups = ["bev", "flat", "wall", "core*", "cwall", "ch*"]
    if q < 1:
        def prof_l(s):
            p = prof(s)
            return [p[0], p[1], p[2], p[4], (0.0, p[4][1])]
        blade(B, y0, L, prof_l, ["edge", "steel", "graphite", "glow"], ["bev", "flat", "core*", "ch*"], stations_for(q, (ch0, ch_end, c_end), 0.78))
    else:
        blade(B, y0, L, prof, mats, groups, stations_for(q, (ch0 - 0.004, ch0, ch_end, ch_end + 0.004, c_end - 0.05, c_end), 0.78))
    # guard: slim graphite bar whose ends lean toward the blade, steel centre block, thin gold seam
    guard_bar(B, 0.080, 0.0595, 0.0066, 0.0095, "steel", end_scale=0.66, sweep=0.013, sweep_pow=1.0, seg=5 if q >= 1 else 2, chamfer=0.32)
    block(B, -0.0175, 0.0175, 0.0505, 0.070, -0.0118, 0.0118, 0.0026, "steel")
    block(B, -0.0185, 0.0185, 0.0585, 0.0615, -0.0124, 0.0124, 0.0008, "gold")
    # blade collar: a flat sleeve up the first 6 cm whose top edge is a chevron pointing down the blade
    B.part()
    rings = []
    hw, hz = 0.0185, 0.0052
    for y, k, notch in ((0.068, 1.0, 0.0), (0.072, 1.06, 0.0), (0.118, 0.94, 0.030), (0.1195, 0.86, 0.030)):
        sec = chamfer_rect(hw * k, hz * (0.6 + 0.4 * k), 0.0022)
        rings.append([(x, y - notch * (1 - abs(x) / (hw * k)) * (1.0 if notch else 0.0), z) for x, z in sec])
    loft(B, rings, "graphite", smooth_u=False, smooth_v=False, grain=1)
    B.close()
    grip(B, 0.050, -0.112, 0.0136, 0.0114, "grip", seg=seg, stations=8 if q >= 1 else 3, swell=0.035, taper_bot=0.93, wraps=30.0)
    for y in ((0.0465, -0.0005, -0.062, -0.1125) if q >= 1 else (0.0465, -0.1125)):
        collar(B, y - 0.0018, y + 0.0018, 0.0150 if y > 0 or y < -0.1 else 0.0146, 0.0127, "gold", seg, 0.0008)
    # long hexagonal cap
    B.part()
    lathe(B, [(-0.114, 0.0128), (-0.119, 0.0148), (-0.143, 0.0160), (-0.152, 0.0118), (-0.154, 0.0050)],
          "steel", seg=6, facet=True, hard=(1, 2, 3), phase=math.pi / 6, rz_scale=0.86)
    B.close()
    return {"class": "sword", "name": "Eternal Edge", "blade": L, "tip": y0 + L, "pommel": 0.154,
            "grip_clear": 0.162, "guard_span": 0.164, "hands": 1.5, "emissive": True}


# ============================================================================ shields
def resample(poly, n):
    """Closed polygon resampled to n points evenly by arc length (keeps the first point)."""
    poly = np.asarray(poly, dtype=float)
    seg = np.linalg.norm(np.roll(poly, -1, axis=0) - poly, axis=1)
    cum = np.concatenate([[0.0], np.cumsum(seg)])
    out = []
    for i in range(n):
        d = cum[-1] * i / n
        j = min(int(np.searchsorted(cum, d, side="right")) - 1, len(poly) - 1)
        f = (d - cum[j]) / max(seg[j], 1e-9)
        out.append(poly[j] * (1 - f) + poly[(j + 1) % len(poly)] * f)
    return np.array(out)


def inset(poly, d):
    """Moves every vertex of a counter-clockwise polygon inward by d along its corner bisector."""
    if d == 0:
        return poly.copy()
    prev = np.roll(poly, 1, axis=0)
    nxt = np.roll(poly, -1, axis=0)
    e1 = poly - prev
    e2 = nxt - poly
    e1 /= np.linalg.norm(e1, axis=1)[:, None]
    e2 /= np.linalg.norm(e2, axis=1)[:, None]
    n1 = np.stack([-e1[:, 1], e1[:, 0]], axis=1)
    n2 = np.stack([-e2[:, 1], e2[:, 0]], axis=1)
    bis = n1 + n2
    ln = np.linalg.norm(bis, axis=1)[:, None]
    bis /= np.maximum(ln, 1e-9)
    cos_half = np.clip((bis * n1).sum(axis=1), 0.5, 1.0)[:, None]
    out = poly + bis * d / cos_half
    # at a sharp point (the foot of a heater) neighbours would cross the centre line: slide them back along
    # their edge to it, so the inset outline closes in a clean mitre instead of folding over itself
    tan = e1 + e2
    for i in range(len(poly)):
        if poly[i][0] * out[i][0] < 0 and abs(tan[i][0]) > 1e-6:
            out[i] = out[i] - tan[i] * (out[i][0] / tan[i][0])
    return out


def board(B, outline, table, zf, centre, off, gu=None, col_dz=None, gu_bands=()):
    """Shield body. `table` rows are (kind, value, proud, material, group) running from the middle of the front,
    out over the rim, round the edge and back to the middle of the rear:
      ("s", f, h)  the field boundary scaled toward `centre` by f      ("i", d, h)  the outline inset by d
    h is how far the ring stands proud of the front surface zf(x, y) (toward -Z); negative h is behind it.
    The material and group belong to the band between a row and the next."""
    N = len(outline)
    field_d = max(v for kind, v, *_ in table if kind == "i")
    field = inset(outline, field_d)
    rings, mats, gv = [], [], []
    for row in table:
        kind, v, h, m, g = row
        ring2 = centre + (field - centre) * v if kind == "s" else inset(outline, v)
        ring = []
        for j, (x, y) in enumerate(ring2):
            dz = col_dz(j, row) if col_dz else 0.0
            ring.append((x + off[0], y + off[1], zf(x, y) - h + dz + off[2]))
        rings.append(ring)
        mats.append([m] * N)
        gv.append(g)
    B.part()
    gfun = (lambda r, c: (gu[c] if gv[r] in gu_bands else 0) * 2000 + gv[r]) if gu is not None else None
    loft(B, rings, mats[:-1], gu=[0] * N, gv=gv[:-1], uv="box", grain=1, cap0=False, cap1=False, gfun=gfun)
    B.close()


def rivet(B, p, r, h, mat, seg=8):
    """Low dome with its flat on the XY plane at p, proud toward -Z."""
    B.part()
    lathe(B, [(0.0, r), (h * 0.55, r * 0.9), (h * 0.95, r * 0.5), (h, 0.0001)], mat, seg=seg, y_axis=2)
    for i in range(B.start, len(B.P)):
        B.P[i] = tuple(np.array([q[0] + p[0], q[1] + p[1], -q[2] + p[2]]) for q in B.P[i])
    B.close()


def arm_strap(B, x, half_w, y_span, z_back, rise, mat, thick=0.0035, n=10, plates=True, slope=0.0):
    """Leather loop the forearm passes through: an arch over X = x from the rear face, both ends on steel plates."""
    def at(a):
        return -y_span * math.cos(a), z_back + rise * math.sin(a) ** 0.8

    rings = []
    for i in range(n + 1):
        a = math.pi * i / n
        y, z = at(a)
        y0, z0 = at(max(a - 0.02, 0.0))
        y1, z1 = at(min(a + 0.02, math.pi))
        ty, tz = y1 - y0, z1 - z0
        ln = math.hypot(ty, tz)
        ny, nz = -tz / ln, ty / ln
        o = thick / 2
        s0, s1 = -slope * half_w, slope * half_w
        rings.append([(x - half_w, y + ny * o, z + nz * o + s0), (x + half_w, y + ny * o, z + nz * o + s1),
                      (x + half_w, y - ny * o, z - nz * o + s1), (x - half_w, y - ny * o, z - nz * o + s0)])
    B.part()
    loft(B, rings, mat, smooth_u=False, uv="cyl", urep=2.0, vk=UVK)
    B.close()
    if plates:
        for sgn in (-1, 1):
            block(B, x - half_w - 0.004, x + half_w + 0.004, sgn * y_span - 0.011, sgn * y_span + 0.011, z_back - 0.001, z_back + 0.0045, 0.0012, "steel", slope=slope)


def hand_grip(B, half_len, z_back, mat_bar, q, r=0.0115, slope=0.0):
    """Rigid grip bar the fist closes round, centred on the origin along Y, carried on two steel posts."""
    seg = 10 if q >= 1 else 6
    B.part()
    lathe(B, [(-half_len, r * 0.9), (-half_len * 0.5, r * 1.04), (0.0, r * 1.08), (half_len * 0.5, r * 1.04), (half_len, r * 0.9)],
          mat_bar, seg=seg, uv="cyl", urep=2.0, vk=26.0)
    B.close()
    for sgn in (-1, 1):
        y = sgn * (half_len + 0.007)
        # post: from the bar down to the rear face
        block(B, -0.0085, 0.0085, y - 0.008, y + 0.008, z_back - 0.001, 0.0125, 0.002, "steel")
        block(B, -0.016, 0.016, y - 0.013, y + 0.013, z_back - 0.001, z_back + 0.004, 0.0012, "steel", slope=slope)


def build_heater(B, q):
    """Streamlined heater: flat top, straight shoulders, two arcs to a point; wrapped round the arm, shallow keel,
    raised steel rim with a hairline of gold inside it, graphite enamel field."""
    H_top, H_bot, hw = 0.25, -0.41, 0.245          # outline in board space (centre of the shoulders at y = 0)
    y_mid = 0.06
    pts = []
    n_arc = 40
    for i in range(n_arc + 1):                    # right side, tip upward to the shoulder
        t = 1 - i / n_arc
        pts.append((hw * (1 - t ** 2.15), y_mid - (y_mid - H_bot) * t))
    rc = 0.034
    for i in range(1, 9):                         # rounded top-right corner
        a = math.pi / 2 * i / 8
        pts.append((hw - rc + rc * math.cos(a), H_top - rc + rc * math.sin(a)))
    top = [(x, y + 0.012 * (1 - (x / (hw - rc)) ** 2)) for x, y in [((hw - rc) * (1 - i / 6), H_top) for i in range(1, 7)]]
    pts += top
    left = [(-x, y) for x, y in reversed(pts[1:-1])]
    P = 80 if q >= 1 else 28
    outline = resample(pts + left, P)
    # make it exactly symmetric and counter-clockwise, starting at the tip
    outline[0] = (0.0, H_bot)
    for i in range(1, P // 2):
        outline[P - i] = (-outline[i][0], outline[i][1])
    outline[P // 2] = (0.0, outline[P // 2][1])
    R = 0.47

    def zf(x, y):
        return (R - math.sqrt(R * R - x * x)) - 0.006 * (1 - math.sqrt(x * x + 0.0009) / hw) + 0.07 * (y + 0.08) ** 2

    T = 0.008
    centre = np.array([0.0, -0.05])
    # board centre relative to the hand grip (origin): hand toward the bearer's right, a little above centre
    off = (-0.105, -0.045, -0.058)
    field = [("s", 0.0, 0.0, "enamel", 0), ("s", 0.3, 0.0, "enamel", 0), ("s", 0.62, 0.0, "enamel", 0), ("s", 0.86, 0.0, "enamel", 0)] if q >= 1 else \
            [("s", 0.0, 0.0, "enamel", 0), ("s", 0.6, 0.0, "enamel", 0)]
    table = field + [
        ("s", 0.972, 0.0, "gold", 1), ("i", 0.0335, 0.0004, "steel", 2),
        ("i", 0.0305, 0.0042, "steel", 3), ("i", 0.0040, 0.0042, "steel", 4), ("i", 0.0, 0.0012, "steel", 5),
        ("i", 0.0, -T + 0.001, "steel", 6), ("i", 0.004, -T - 0.0015, "steel", 7), ("i", 0.028, -T - 0.0015, "steel", 8),
        ("i", 0.0305, -T, "leather", 9)]
    table += [("s", 0.86, -T, "leather", 9), ("s", 0.5, -T, "leather", 9), ("s", 0.0, -T, "leather", 9)] if q >= 1 else [("s", 0.5, -T, "leather", 9), ("s", 0.0, -T, "leather", 9)]
    board(B, outline, table, zf, centre, off)

    def back_z(x, y):
        return zf(x, y) + T + off[2]

    if q >= 1:
        rim_mid = inset(outline, 0.0172)
        for j in range(0, P, P // 10):
            x, y = rim_mid[j]
            rivet(B, (x + off[0], y + off[1], zf(x, y) - 0.0042 + off[2]), 0.0048, 0.0022, "steel")
    # rear: grip bar at the origin, arm strap toward the elbow, a pad for the forearm between them
    def slope(x):
        return (back_z(x + 0.02 - off[0], -off[1]) - back_z(x - 0.02 - off[0], -off[1])) / 0.04

    hand_grip(B, 0.052, back_z(-off[0], -off[1]), "grip", q, slope=slope(0.0))
    sx = -0.205
    arm_strap(B, sx, 0.021, 0.062, back_z(sx - off[0], -off[1]), 0.078, "leather", n=10 if q >= 1 else 4, slope=slope(sx))
    if q >= 1:
        rings = []
        for i in range(9):
            x = -0.165 + 0.125 * i / 8
            zb = back_z(x - off[0], -off[1])
            hy = 0.05 * (0.82 + 0.18 * math.sin(math.pi * i / 8) ** 0.5)
            th = 0.0075 * (0.45 + 0.55 * math.sin(math.pi * i / 8) ** 0.5)
            rings.append([(x, -hy, zb - 0.001), (x, hy, zb - 0.001), (x, hy * 0.9, zb + th), (x, -hy * 0.9, zb + th)])
        B.part()
        loft(B, rings, "leather", gu=[0, 1, 2, 3], uv="box")
        B.close()
    return {"class": "shield", "name": "Heater", "width": 2 * hw, "height": H_top + 0.012 - H_bot,
            "board_centre": [off[0], off[1] + (H_top + H_bot) / 2, off[2]], "strap_x": sx, "thickness": T}


def build_round(B, q):
    """Compact technological round shield: domed, two stepped graphite tiers cut by four seams, steel rim,
    a small hub ringed by one narrow light channel."""
    Rr = 0.255
    base = 64 if q >= 1 else 24
    angs = [2 * math.pi * i / base for i in range(base)]
    seams = [math.pi / 4 + math.pi / 2 * i for i in range(4)]
    gw = 0.011
    groove = {}
    if q >= 1:
        for a in seams:
            angs += [a - gw, a + gw]
        angs = sorted(angs)
        for j, a in enumerate(angs):
            for sa in seams:
                if abs(a - sa) < 1e-6:
                    groove[j] = True
    N = len(angs)
    outline = np.array([(Rr * math.cos(a), Rr * math.sin(a)) for a in angs])
    Rs = 0.72

    def zf(x, y):
        return Rs - math.sqrt(Rs * Rs - x * x - y * y)

    T = 0.009
    off = (-0.098, 0.0, -0.060)
    centre = np.array([0.0, 0.0])
    fd = 0.040               # rim width: the "i" inset that defines the field boundary radius (Rr - fd = 0.215)
    fr = Rr - fd

    def s(r):
        return r / fr

    table = [
        ("s", 0.0, 0.0085, "steel", 0), ("s", s(0.026), 0.0085, "steel", 1), ("s", s(0.034), 0.0062, "steel", 2),
        ("s", s(0.040), 0.0062, "steel", 3), ("s", s(0.040), 0.0030, "glow", 4), ("s", s(0.0435), 0.0030, "graphite", 5),
        ("s", s(0.0435), 0.0052, "gold", 6), ("s", s(0.047), 0.0052, "graphite", 7),
        ("s", s(0.050), 0.0040, "graphite", 8), ("s", s(0.128), 0.0040, "graphite", 9), ("s", s(0.132), 0.0, "enamel", 10),
        ("s", 1.0, 0.0, "steel", 11),
        ("i", fd, 0.0, "steel", 11), ("i", fd - 0.003, 0.0045, "steel", 12), ("i", 0.0045, 0.0045, "steel", 13), ("i", 0.0, 0.0010, "steel", 14),
        ("i", 0.0, -T + 0.001, "steel", 15), ("i", 0.0045, -T - 0.002, "steel", 16), ("i", fd - 0.008, -T - 0.002, "steel", 17),
        ("i", fd - 0.005, -T, "graphite", 18), ("s", 0.55, -T, "graphite", 18), ("s", 0.0, -T, "graphite", 18)]
    table.pop(11)        # ("s", 1.0) is the same ring as the inset-fd row that follows
    if q < 1:
        table = [table[0], table[2], table[3], table[4], table[5], table[8], table[9], table[10]] + table[11:]

    def col_dz(j, row):
        # seams: a narrow groove across the outer tier only
        if groove.get(j) and (row[4] == 10 or (row[0] == "i" and row[1] == fd and row[2] == 0.0)):
            return 0.0018
        return 0.0

    gu = [0] * N
    if q >= 1:
        blockn = 0
        for j in range(N):
            if groove.get(j) or groove.get((j + 1) % N) or groove.get((j - 1) % N):
                blockn += 1
            gu[j] = blockn
    board(B, outline, table, zf, centre, off, gu=None if q < 1 else gu, col_dz=col_dz if q >= 1 else None, gu_bands=(10,))

    def back_z(x, y):
        return zf(x, y) + T + off[2]

    if q >= 1:
        for i in range(8):
            a = math.pi / 8 + math.pi / 4 * i
            x, y = (Rr - 0.021) * math.cos(a), (Rr - 0.021) * math.sin(a)
            rivet(B, (x + off[0], y + off[1], zf(x, y) - 0.0045 + off[2]), 0.0042, 0.0018, "steel", 6)
        # rear hub: the housing the plates fold out from
        B.part()
        zb = back_z(0, 0)
        lathe(B, [(zb - 0.002, 0.050), (zb + 0.008, 0.050), (zb + 0.011, 0.046), (zb + 0.011, 0.020), (zb + 0.008, 0.020), (zb + 0.008, 0.017), (zb + 0.011, 0.017), (zb + 0.011, 0.0001)],
              ["graphite", "graphite", "steel", "graphite", "glow", "graphite", "graphite"], seg=20, hard=range(8), y_axis=2)
        for i in range(B.start, len(B.P)):
            B.P[i] = tuple(p + np.array([off[0], off[1], 0.0]) for p in B.P[i])
        B.close()
    def slope(x):
        return (back_z(x + 0.02 - off[0], -off[1]) - back_z(x - 0.02 - off[0], -off[1])) / 0.04

    hand_grip(B, 0.050, back_z(-off[0], -off[1]), "grip", q, slope=slope(0.0))
    sx = -0.200
    arm_strap(B, sx, 0.021, 0.060, back_z(sx - off[0], -off[1]), 0.076, "leather", n=10 if q >= 1 else 4, slope=slope(sx))
    return {"class": "shield", "name": "Round", "width": 2 * Rr, "height": 2 * Rr,
            "board_centre": [off[0], off[1], off[2]], "strap_x": sx, "thickness": T, "emissive": True}


# ============================================================================ textures
def _blur_wrap(a, sy, sx):
    """Periodic Gaussian blur (FFT), so every texture tiles."""
    h, w = a.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    k = np.exp(-2 * (math.pi ** 2) * ((fy * sy) ** 2 + (fx * sx) ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * k))


def _norm01(a):
    return (a - a.min()) / max(a.max() - a.min(), 1e-9)


def _normal_from(h, strength):
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * strength
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * strength
    n = np.stack([-dx, dy, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def _save(name, arr):
    os.makedirs(os.path.join(OUT, "tex"), exist_ok=True)
    Image.fromarray(arr).save(os.path.join(OUT, "tex", name + ".png"), optimize=True)


def _rgb(v, tint=(1, 1, 1)):
    return (np.clip(np.stack([v * tint[0], v * tint[1], v * tint[2]], axis=-1), 0, 1) * 255).astype(np.uint8)


def _orm(rough, metal):
    return (np.clip(np.stack([np.ones_like(rough), rough, np.full_like(rough, metal) if np.isscalar(metal) else metal], axis=-1), 0, 1) * 255).astype(np.uint8)


def textures():
    rng = np.random.default_rng(7)
    S = 256
    # --- brushed steel: long satin strokes along V, a few shorter hairlines
    long_ = _norm01(_blur_wrap(rng.random((S, S)), 26, 0.6))
    short = _norm01(_blur_wrap(rng.random((S, S)), 6, 0.5))
    h = _norm01(long_ * 0.7 + short * 0.3)
    _save("steel_a", _rgb(0.70 + 0.05 * (h - 0.5), (0.975, 0.99, 1.0)))
    _save("steel_n", _normal_from(h, 1.0))
    _save("steel_orm", _orm(0.52 + 0.10 * (h - 0.5), 1.0))
    # --- worn steel: the same brushing under a patina, pits and stray scratches
    pat = _norm01(_blur_wrap(rng.random((S, S)), 14, 14) + 0.5 * _blur_wrap(rng.random((S, S)), 4, 4))
    pat = np.clip((pat - 0.35) * 2.2, 0, 1)
    pits = np.clip((_norm01(_blur_wrap(rng.random((S, S)), 1.6, 1.6)) - 0.78) * 5, 0, 1)
    scr = np.clip((_norm01(_blur_wrap(rng.random((S, S)), 0.6, 30)) - 0.74) * 6, 0, 1) * 0.6
    hw = h * 0.8 - pits * 0.22 - scr * 0.2 + pat * 0.05
    val = 0.62 + 0.05 * (h - 0.5) - 0.10 * pat - 0.03 * pits + 0.03 * scr
    warm = pat * 0.10
    _save("worn_a", (np.clip(np.stack([val * (0.99 + warm * 0.6), val * 0.985, val * (1.0 - warm)], axis=-1), 0, 1) * 255).astype(np.uint8))
    _save("worn_n", _normal_from(_norm01(hw), 1.4))
    _save("worn_orm", _orm(0.50 + 0.10 * (h - 0.5) + 0.16 * pat + 0.06 * pits - 0.05 * scr, 1.0 - 0.15 * pat))
    # --- fine bead-blast: carries graphite, enamel and leather through the colour factor
    f = _norm01(_blur_wrap(rng.random((S, S)), 1.3, 1.3))
    mott = _norm01(_blur_wrap(rng.random((S, S)), 20, 20))
    _save("fine_a", _rgb(0.90 + 0.06 * (mott - 0.5) + 0.04 * (f - 0.5)))
    _save("fine_n", _normal_from(f, 0.5))
    _save("satin_orm", _orm(0.50 + 0.08 * (mott - 0.5) + 0.06 * (f - 0.5), 0.8))
    _save("matte_orm", _orm(0.84 + 0.08 * (f - 0.5), 0.0))
    # --- cord wrap under leather: 8 turns a tile, one turn of pitch across the tile so it tiles round the grip
    v, u = np.mgrid[0:S, 0:S] / S
    cord = np.abs(np.sin(math.pi * (v * 8 + u))) ** 0.55
    fib = _norm01(_blur_wrap(rng.random((S, S)), 0.8, 2.5))
    hc = cord * 0.9 + fib * 0.1
    _save("wrap_a", _rgb(0.34 + 0.34 * cord + 0.08 * (fib - 0.5)))
    _save("wrap_n", _normal_from(hc, 3.2))
    _save("wrap_orm", _orm(0.90 - 0.14 * cord + 0.06 * (fib - 0.5), 0.0))


TEX = ["steel_a", "steel_n", "steel_orm", "worn_a", "worn_n", "worn_orm", "fine_a", "fine_n", "satin_orm", "matte_orm", "wrap_a", "wrap_n", "wrap_orm"]

# name: (base colour factor, metallic, roughness, albedo, normal, orm, normal scale, emissive)
MATERIALS = {
    "steel": ((1, 1, 1), 1.0, 0.42, "steel_a", "steel_n", "steel_orm", 0.22, None),
    "fuller": ((0.62, 0.63, 0.66), 1.0, 0.5, "steel_a", "steel_n", "steel_orm", 0.5, None),
    "edge": ((0.80, 0.81, 0.83), 1.0, 0.30, None, None, None, 1.0, None),
    "graphite": ((0.085, 0.09, 0.105), 0.8, 0.5, "fine_a", "fine_n", "satin_orm", 0.4, None),
    "enamel": ((0.075, 0.095, 0.135), 0.8, 0.5, "fine_a", "fine_n", "satin_orm", 0.5, None),
    "gold": ((0.95, 0.66, 0.27), 1.0, 0.45, "steel_a", "steel_n", "steel_orm", 0.5, None),
    "grip": ((0.20, 0.21, 0.24), 0.0, 0.85, "wrap_a", "wrap_n", "wrap_orm", 1.0, None),
    "leather": ((0.115, 0.095, 0.085), 0.0, 0.85, "fine_a", "fine_n", "matte_orm", 1.0, None),
    "glow": ((0.03, 0.05, 0.06), 0.0, 0.6, None, None, None, 1.0, ((0.38, 0.8, 1.0), 1.0)),
}
# per-item substitutions: the weathered greatsword swaps the steel set and warms the leather
VARIANT = {
    "oathbreaker": {"steel": ((0.92, 0.92, 0.92), 1.0, 0.5, "worn_a", "worn_n", "worn_orm", 0.8, None),
                    "fuller": ((0.5, 0.5, 0.52), 1.0, 0.6, "worn_a", "worn_n", "worn_orm", 1.0, None),
                    "edge": ((0.70, 0.71, 0.73), 1.0, 0.34, None, None, None, 1.0, None),
                    "grip": ((0.22, 0.165, 0.125), 0.0, 0.88, "wrap_a", "wrap_n", "wrap_orm", 1.0, None)},
}


# ============================================================================ GLB writer
def finish(B):
    """Normals per (position, group), then weld. Returns {material: (pos, nrm, uv, idx)}."""
    acc = {}
    keys = []
    for (a, b, c), g in zip(B.P, B.G):
        n = np.cross(b - a, c - a)
        n /= np.linalg.norm(n)
        tri_keys = []
        for p, q1, q2 in ((a, b, c), (b, c, a), (c, a, b)):
            e1, e2 = q1 - p, q2 - p
            ang = math.acos(max(-1.0, min(1.0, float(np.dot(e1, e2) / (np.linalg.norm(e1) * np.linalg.norm(e2) + 1e-20)))))
            k = (round(float(p[0]) * 2e5), round(float(p[1]) * 2e5), round(float(p[2]) * 2e5), g)
            acc[k] = acc.get(k, 0) + n * ang
            tri_keys.append(k)
        keys.append(tri_keys)
    out = {}
    for i, ((a, b, c), (ua, ub, uc), m) in enumerate(zip(B.P, B.UV, B.M)):
        d = out.setdefault(m, {"map": {}, "pos": [], "nrm": [], "uv": [], "idx": []})
        for p, u, k in ((a, ua, keys[i][0]), (b, ub, keys[i][1]), (c, uc, keys[i][2])):
            n = acc[k]
            n = n / (np.linalg.norm(n) + 1e-20)
            vk = (k, round(float(u[0]) * 4096), round(float(u[1]) * 4096))
            j = d["map"].get(vk)
            if j is None:
                j = len(d["pos"])
                d["map"][vk] = j
                d["pos"].append(p)
                d["nrm"].append(n)
                d["uv"].append(u)
            d["idx"].append(j)
    return out


def write_glb(path, name, surf, variant):
    buf = bytearray()
    views, accs, prims, mats, texs, imgs = [], [], [], [], [], []
    img_ix, tex_ix = {}, {}

    def tex(n):
        if n is None:
            return None
        if n not in tex_ix:
            img_ix[n] = len(imgs)
            imgs.append({"uri": "tex/%s.png" % n})
            tex_ix[n] = len(texs)
            texs.append({"source": img_ix[n], "sampler": 0})
        return {"index": tex_ix[n]}

    def add(arr, target, ctype, typ, minmax=False):
        while len(buf) % 4:
            buf.append(0)
        views.append({"buffer": 0, "byteOffset": len(buf), "byteLength": arr.nbytes, "target": target})
        buf.extend(arr.tobytes())
        a = {"bufferView": len(views) - 1, "componentType": ctype, "count": len(arr), "type": typ}
        if minmax:
            a["min"] = arr.min(axis=0).tolist()
            a["max"] = arr.max(axis=0).tolist()
        accs.append(a)
        return len(accs) - 1

    order = [m for m in MATERIALS if m in surf]
    for m in order:
        d = surf[m]
        pos = np.array(d["pos"], dtype=np.float32)
        nrm = np.array(d["nrm"], dtype=np.float32)
        uv = np.array(d["uv"], dtype=np.float32)
        idx = np.array(d["idx"], dtype=np.uint16 if len(pos) < 65536 else np.uint32)
        prim = {"attributes": {"POSITION": add(pos, 34962, 5126, "VEC3", True), "NORMAL": add(nrm, 34962, 5126, "VEC3"),
                               "TEXCOORD_0": add(uv, 34962, 5126, "VEC2")},
                "indices": add(idx, 34963, 5123 if idx.dtype == np.uint16 else 5125, "SCALAR"), "material": len(mats)}
        prims.append(prim)
        col, metal, rough, ta, tn, to, ns, emis = variant.get(m, MATERIALS[m])
        md = {"name": m, "pbrMetallicRoughness": {"baseColorFactor": [col[0], col[1], col[2], 1.0], "metallicFactor": metal, "roughnessFactor": rough}}
        if ta:
            md["pbrMetallicRoughness"]["baseColorTexture"] = tex(ta)
        if to:
            md["pbrMetallicRoughness"]["metallicRoughnessTexture"] = tex(to)
        if tn:
            md["normalTexture"] = dict(tex(tn), scale=ns)
        if emis:
            md["emissiveFactor"] = list(emis[0])
            md["extensions"] = {"KHR_materials_emissive_strength": {"emissiveStrength": emis[1]}}
        mats.append(md)
    while len(buf) % 4:
        buf.append(0)
    gltf = {"asset": {"version": "2.0", "generator": "hollow-reign gear_gen"}, "scene": 0, "scenes": [{"nodes": [0]}],
            "nodes": [{"name": name, "mesh": 0}], "meshes": [{"name": name, "primitives": prims}], "materials": mats,
            "buffers": [{"byteLength": len(buf)}], "bufferViews": views, "accessors": accs}
    if texs:
        gltf["textures"] = texs
        gltf["images"] = imgs
        gltf["samplers"] = [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}]
    if any("extensions" in m for m in mats):
        gltf["extensionsUsed"] = ["KHR_materials_emissive_strength"]
    js = json.dumps(gltf, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(buf)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A))
        f.write(js)
        f.write(struct.pack("<II", len(buf), 0x004E4942))
        f.write(buf)


ITEMS = {"wayfarer": build_wayfarer, "oathbreaker": build_oathbreaker, "eternal_edge": build_eternal_edge,
         "shield_heater": build_heater, "shield_round": build_round}


def main():
    os.makedirs(OUT, exist_ok=True)
    want = sys.argv[1:] or list(ITEMS)
    textures()
    mpath = os.path.join(OUT, "gear_manifest.json")
    manifest = json.load(open(mpath)) if os.path.exists(mpath) else {}
    for item in want:
        entry = {}
        for q, suffix in ((1.0, ""), (0.4, "_lod")):
            B = Builder()
            info = ITEMS[item](B, q)
            surf = finish(B)
            path = os.path.join(OUT, item + suffix + ".glb")
            write_glb(path, item + suffix, surf, VARIANT.get(item, {}))
            allp = np.concatenate([np.array(d["pos"]) for d in surf.values()])
            tris = sum(len(d["idx"]) for d in surf.values()) // 3
            verts = sum(len(d["pos"]) for d in surf.values())
            if q == 1.0:
                entry.update(info)
                entry["lo"] = [round(float(x), 4) for x in allp.min(axis=0)]
                entry["hi"] = [round(float(x), 4) for x in allp.max(axis=0)]
                entry["materials"] = [m for m in MATERIALS if m in surf]
            entry["rig_scale"] = 1.15      # the knights are heroic figures: the rig draws gear 15% over life size
            entry["tris" + suffix] = tris
            entry["verts" + suffix] = verts
            entry["bytes" + suffix] = os.path.getsize(path)
            print("%-14s%-5s tris %5d  verts %5d  surfaces %d  %6.1f kB" % (item, suffix or "hi", tris, verts, len(surf), os.path.getsize(path) / 1024))
        manifest[item] = entry
    json.dump(manifest, open(mpath, "w"), indent=1)


if __name__ == "__main__":
    main()
