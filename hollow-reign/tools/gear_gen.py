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
         uv="box", grain=1, urep=1.0, vk=UVK, cap_mat=None, k=UVK, gfun=None, skip=None, uvmat=None):
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

    def uvs(pts, rc, n, m=None):
        if uvmat and m in uvmat:
            bw, tile, x0, y0 = uvmat[m]
            return [np.array([0.5 + (p[0] - x0) / (2 * bw), (p[1] - y0) / tile]) for p in pts]
        if callable(uv):
            return uv(pts, rc, n)
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
            if skip and skip(r, c):
                continue
            m = m_at(r, c)
            u = uvs(pts, rc, n, m)
            g = gfun(r, c) if gfun else gu[c] * 2000 + gv[r]
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


# ============================================================================ 2D outlines, plates
def _area2(p):
    p = np.asarray(p, dtype=float)
    return float(np.sum(p[:, 0] * np.roll(p[:, 1], -1) - np.roll(p[:, 0], -1) * p[:, 1]))


def _ccw(p):
    p = np.asarray(p, dtype=float)
    return p if _area2(p) > 0 else p[::-1].copy()


def _cw(p):
    p = np.asarray(p, dtype=float)
    return p if _area2(p) < 0 else p[::-1].copy()


def _pip(pt, poly):
    x, y = pt
    inside = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            inside = not inside
    return inside


def _seg_hit(a, b, c, d):
    """True when segments ab and cd cross properly (shared end points do not count)."""
    def o(p, q, r):
        return (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
    for p in (a, b):
        for q in (c, d):
            if abs(p[0] - q[0]) < 1e-9 and abs(p[1] - q[1]) < 1e-9:
                return False
    return (o(a, b, c) * o(a, b, d) < -1e-18) and (o(c, d, a) * o(c, d, b) < -1e-18)


def triangulate(outer, holes):
    """Ear clipping of a counter-clockwise polygon with clockwise holes. Returns triangles of 2D points."""
    poly = [tuple(p) for p in outer]
    rest = [[tuple(p) for p in h] for h in holes]
    rest.sort(key=lambda h: -max(p[0] for p in h))
    while rest:
        h = rest.pop(0)
        hi = max(range(len(h)), key=lambda i: h[i][0])
        edges = [(poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly))]
        for hh in [h] + rest:
            edges += [(hh[i], hh[(i + 1) % len(hh)]) for i in range(len(hh))]
        best = None
        for j in sorted(range(len(poly)), key=lambda j: (poly[j][0] - h[hi][0]) ** 2 + (poly[j][1] - h[hi][1]) ** 2):
            if not any(_seg_hit(h[hi], poly[j], a, b) for a, b in edges):
                best = j
                break
        if best is None:
            best = 0
        poly = poly[:best + 1] + h[hi:] + h[:hi + 1] + poly[best:]
    idx = list(range(len(poly)))
    tris = []

    def cross(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])

    guard = 0
    while len(idx) > 3 and guard < 20000:
        guard += 1
        done = False
        for k in range(len(idx)):
            a, b, c = poly[idx[k - 1]], poly[idx[k]], poly[idx[(k + 1) % len(idx)]]
            if cross(a, b, c) <= 1e-14:
                continue
            ok = True
            for m in idx:
                p = poly[m]
                if p == a or p == b or p == c:
                    continue
                if cross(a, b, p) > 1e-14 and cross(b, c, p) > 1e-14 and cross(c, a, p) > 1e-14:
                    ok = False
                    break
            if ok:
                tris.append((a, b, c))
                idx.pop(k)
                done = True
                break
        if not done:
            # degenerate remainder (collinear bridge points): drop the flattest corner and carry on
            k = min(range(len(idx)), key=lambda k: abs(cross(poly[idx[k - 1]], poly[idx[k]], poly[idx[(k + 1) % len(idx)]])))
            idx.pop(k)
    if len(idx) == 3:
        tris.append((poly[idx[0]], poly[idx[1]], poly[idx[2]]))
    return tris


def mirror_x(right):
    """Full outline from its right half, listed from the bottom centre (x = 0) round to the top centre (x = 0)."""
    return list(right) + [(-x, y) for x, y in reversed(right[1:-1])]


def both(hole):
    return [hole, [(-x, y) for x, y in hole]]


def rect(x0, y0, x1, y1, c=0.0):
    if c <= 0:
        return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def circle(cx, cy, r, n=10, phase=0.0):
    return [(cx + r * math.cos(phase + 2 * math.pi * i / n), cy + r * math.sin(phase + 2 * math.pi * i / n)) for i in range(n)]


def ribbon(centre, widths, n=28):
    """Outline of a band of varying half-width along a smoothed centre line (asymmetric swept guards)."""
    c = np.asarray(centre, dtype=float)
    t = np.linspace(0, len(c) - 1, n)
    pts, hw = [], []
    for u in t:
        i = min(int(u), len(c) - 2)
        f = u - i
        p0, p1 = c[max(i - 1, 0)], c[i]
        p2, p3 = c[i + 1], c[min(i + 2, len(c) - 1)]
        pts.append(0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f + (-p0 + 3 * p1 - 3 * p2 + p3) * f ** 3))
        hw.append(widths[i] * (1 - f) + widths[i + 1] * f)
    pts = np.array(pts)
    tan = np.gradient(pts, axis=0)
    tan /= np.linalg.norm(tan, axis=1)[:, None]
    nor = np.stack([-tan[:, 1], tan[:, 0]], axis=1)
    hw = np.array(hw)[:, None]
    return list(map(tuple, pts + nor * hw)) + list(map(tuple, (pts - nor * hw)[::-1]))


def plate(B, outer, holes, zh, bev, mat, zc=0.0, grain=0):
    """A flat sculpted plate in the XY plane: an outline with pierced cut-outs, extruded 2*zh thick about z = zc,
    every rim (outer and inside each cut-out) chamfered by `bev`. Corners sharper than 35 degrees stay hard."""
    outer = _ccw(outer)
    holes = [_cw(h) for h in holes]
    loops = [outer] + holes

    def solid(pt):
        return _pip(pt, outer) and not any(_pip(pt, h) for h in holes)

    caps = []
    for loop in loops:
        cap = inset(loop, bev, sym_fix=False) if bev > 0 else loop.copy()
        caps.append(cap)
        n = len(loop)
        if bev > 0:
            layers = [(cap, zh), (loop, zh - bev), (loop, -zh + bev), (cap, -zh)]
            gv = [0, 1, 2]
        else:
            layers = [(loop, zh), (loop, -zh)]
            gv = [1]
        rings = [[(x, y, zc + z) for x, y in lp] for lp, z in layers]
        corner = []
        for i in range(n):
            e1 = loop[i] - loop[i - 1]
            e2 = loop[(i + 1) % n] - loop[i]
            cosang = float(np.dot(e1, e2) / (np.linalg.norm(e1) * np.linalg.norm(e2) + 1e-20))
            corner.append(cosang < math.cos(math.radians(35)))
        gu, g = [], 0
        for i in range(n):
            if corner[i]:
                g += 1
            gu.append(g)
        if not corner[0]:
            gu = [0 if x == g else x for x in gu]
        B.part()
        loft(B, rings, mat, gu=gu, gv=gv, cap0=False, cap1=False, grain=grain)
        # which way is out? step off the first wall face and see whether we land in metal
        flip = False
        for a, b, c in B.P[B.start:]:
            nrm = np.cross(b - a, c - a)
            if abs(nrm[2]) < 0.5 * np.linalg.norm(nrm):
                cen = (a + b + c) / 3
                step = nrm[:2] / (np.linalg.norm(nrm[:2]) + 1e-20) * 2e-4
                flip = solid((cen[0] + step[0], cen[1] + step[1]))
                break
        B.close(flip=flip)
    B.part()
    for a, b, c in triangulate(caps[0], caps[1:]):
        for z, want, g in ((zh, 1.0, 1), (-zh, -1.0, 2)):
            pa, pb, pc = (np.array([p[0], p[1], zc + z]) for p in (a, b, c))
            n = np.cross(pb - pa, pc - pa)
            if n[2] * want < 0:
                pb, pc = pc, pb
            n = np.array([0.0, 0.0, want])
            B.tri(pa, pb, pc, box_uv(pa, n, grain), box_uv(pb, n, grain), box_uv(pc, n, grain), g, mat)


def dot(B, x, y, z, r, mat="gold", h=0.0009, seg=6):
    """A small inlaid stud, flush-ish, on a face at height z; proud toward the sign of z."""
    sgn = 1.0 if z >= 0 else -1.0
    B.part()
    lathe(B, [(0.0, r), (h, r * 0.8), (h, 0.0001)], mat, seg=seg, hard=(1,), y_axis=2)
    for i in range(B.start, len(B.P)):
        B.P[i] = tuple(np.array([p[0] + x, p[1] + y, sgn * p[2] + z]) for p in B.P[i])
    B.close()


def dots(B, q, pts, zh, r=0.0022, mat="gold"):
    if q < 1:
        return
    for x, y in pts:
        for z in (zh, -zh):
            dot(B, x, y, z, r, mat)


# ============================================================================ sword parts
def stations_for(q, marks=(), tip_from=0.85, body=14):
    """Stations along a blade: even through the body, extra at `marks`, dense through the tip."""
    nb = int(round(body * q)) + 2
    tip = int(round(9 * q)) + 3
    s = list(np.linspace(0.0, tip_from, nb)) + [tip_from + (1 - tip_from) * (1 - (1 - i / tip) ** 1.6) for i in range(1, tip + 1)]
    s += [m for m in marks if 0.0 < m < 1.0]
    s = sorted(set(round(float(x), 5) for x in s))
    out = [s[0]]
    for x in s[1:]:
        if x - out[-1] > 0.0025:
            out.append(x)
    out[-1] = 1.0
    return out


def width_at(s, pts, s_tip, p):
    """Half width from control points (s, w) through a smooth curve, then an ogive from s_tip to the point.
    Control points make waisted and leaf profiles: narrow above the guard, swelling, then the long taper."""
    def body(u):
        xs = [a for a, _ in pts]
        ws = [b for _, b in pts]
        if u <= xs[0]:
            return ws[0]
        if u >= xs[-1]:
            return ws[-1]
        i = max(j for j in range(len(xs) - 1) if xs[j] <= u)
        h = xs[i + 1] - xs[i]
        f = (u - xs[i]) / h

        def slope(j):
            if j == 0:
                return (ws[1] - ws[0]) / (xs[1] - xs[0])
            if j == len(xs) - 1:
                return (ws[-1] - ws[-2]) / (xs[-1] - xs[-2])
            return (ws[j + 1] - ws[j - 1]) / (xs[j + 1] - xs[j - 1])
        m0, m1 = slope(i) * h, slope(i + 1) * h
        return (2 * f ** 3 - 3 * f * f + 1) * ws[i] + (f ** 3 - 2 * f * f + f) * m0 + (-2 * f ** 3 + 3 * f * f) * ws[i + 1] + (f ** 3 - f * f) * m1
    if s <= s_tip:
        return body(s)
    u = (s - s_tip) / (1 - s_tip)
    return body(s_tip) * (1 - u ** p)


def tip_thin(s, s_tip):
    if s <= s_tip:
        return 1.0
    u = (s - s_tip) / (1 - s_tip)
    return max(0.0, 1 - u ** 3) ** 0.6


def blade2(B, q, P):
    """Parametric blade. One quadrant of the section runs
        cutting edge -> bevel shoulder -> flat -> lip of the recessed band -> band -> groove lip -> groove floor -> centre
    P: L, y0, w (control points), s_tip, tip_p, t0, t1, bevel, optional wl (other edge: single-edged blades),
       ric (s_end, narrower_by, blunt), band (bw, end, mat, tile), groove (gw, d, s0, s1, mat),
       holes [(s, half_len_m, half_width)] pierced through the groove, flat_mat."""
    L, y0 = P["L"], P["y0"]
    band = P.get("band")
    groove = P.get("groove")
    holes = P.get("holes", []) if q >= 1 else []
    ric = P.get("ric")
    flat_mat = P.get("flat_mat", "blade")
    s_tip = P["s_tip"]
    thin_from = max(s_tip, 0.86)

    def hole_hx(s):
        for sc, hl, hx in holes:
            d = abs(s - sc) * L
            if d < hl:
                return hx * (1 - d / hl)
        return 0.0

    def quad(s, side):
        spine = side < 0 and "wl" in P
        w = width_at(s, P["wl"] if spine else P["w"], s_tip, P["tip_p"])
        t = (P["t0"] - (P["t0"] - P["t1"]) * s) * tip_thin(s, thin_from)
        b = min(P["bevel"], w * 0.45)
        e, tb = 0.0, t * 0.5
        if ric:
            rf = 1.0 - min(1.0, max(0.0, (s - ric[0]) / 0.025))
            w -= ric[1] * rf
            e = ric[2] * rf
            b *= 1 - 0.6 * rf
            tb = max(t * (0.5 + 0.42 * rf), e)
        if spine:
            e, b, tb = t * 0.82, min(0.0012, w * 0.3), t
        bw, step = 0.0, 0.0
        if band:
            bf = max(0.0, 1 - (s / band["end"]) ** 5) if s < band["end"] else 0.0
            bw = min(band["bw"] * bf ** 0.5, (w - b) * 0.80)
            step = 0.0005 * min(1.0, bf * 5)
        gw, d = 0.0, 0.0
        if groove and groove["s0"] <= s <= groove["s1"]:
            gf = min(1.0, (s - groove["s0"]) / 0.012, (groove["s1"] - s) / 0.012) ** 0.5
            gw = min(groove["gw"] * max(gf, 0.05), (bw if band else (w - b)) * 0.7)
            d = groove["d"] * gf
        if not band:
            bw = gw
        fx = max(hole_hx(s), gw * 0.45) if gw > 0 else 0.0
        fx = min(fx, gw)
        inner = max(bw - 0.0005, gw) if bw > 0 else 0.0
        return [(w, e), (w - b, tb), (bw, t), (inner, t - step), (gw, t - step), (fx, t - step - d), (0.0, t - step - d)]

    bmat = band["mat"] if band else flat_mat
    gmat = groove["mat"] if groove else bmat
    if q >= 1:
        mats = ["edge", flat_mat, flat_mat, bmat, gmat, gmat]
        groups = ["bev", "flat", "wall", "band", "gw", "g*"]
        pick = lambda p: p
    else:
        mats = ["edge", flat_mat, bmat]
        groups = ["bev", "flat", "band*"]
        pick = lambda p: [p[0], p[1], p[2], (0.0, p[2][1])]
    K = len(mats) + 1
    marks = []
    if band:
        marks += [band["end"] - 0.04, band["end"]]
    if groove:
        marks += [groove["s0"], groove["s0"] + 0.012, groove["s1"] - 0.012, groove["s1"]]
    if ric:
        marks += [ric[0], ric[0] + 0.025]
    for sc, hl, hx in holes:
        marks += [sc - hl / L, sc, sc + hl / L]
    st = stations_for(q, marks, s_tip)
    rings = []
    for s in st:
        qr = pick(quad(s, 1))
        ql = pick(quad(s, -1))
        top = qr + [(-x, z) for x, z in reversed(ql[:-1])]
        bot = [(-x, -z) for x, z in ql] + [(x, -z) for x, z in reversed(qr[:-1])]
        rings.append(ring_xz(y0 + s * L, top + bot))
    half_m = list(mats) + list(reversed(mats))
    mats_row = half_m + ["edge" if "wl" not in P else flat_mat] + half_m + ["edge"]
    ids, gid = {}, []
    for face in ("t", "b"):
        for side, lst in (("r", groups), ("l", list(reversed(groups)))):
            for g in lst:
                key = (face, g) if g.endswith("*") else (face, side, g)
                gid.append(ids.setdefault(key, len(ids)))
        gid.append(ids.setdefault(("flat", face), len(ids)))

    def in_hole(r):
        m = (st[r] + st[r + 1]) / 2
        return any(abs(m - sc) * L < hl for sc, hl, hx in holes)

    centre_cols = (K - 2, K - 1, 3 * K - 3, 3 * K - 2)
    uvmat = {}
    if band and band["mat"].startswith("engrave"):
        uvmat[band["mat"]] = (band["bw"], band.get("tile", band["bw"] * 8), 0.0, y0)
    B.part()
    loft(B, rings, [mats_row] * (len(st) - 1), gu=gid, smooth_v=True, uv=("planar", 0, 1), cap1=False,
         skip=(lambda r, c: c in centre_cols and in_hole(r)) if holes else None, uvmat=uvmat)
    B.close()
    if holes:
        # the walls of each pierced opening, facing into it
        B.part()
        R = np.asarray(rings)
        for r in range(len(st) - 1):
            if not in_hole(r):
                continue
            for it, ib, want in ((K - 2, 3 * K - 1, -1.0), (K, 3 * K - 3, 1.0)):
                a, b, c, d = R[r, it], R[r + 1, it], R[r + 1, ib], R[r, ib]
                for tri in ((a, b, c), (a, c, d)):
                    n = np.cross(tri[1] - tri[0], tri[2] - tri[0])
                    if np.dot(n, n) < 1e-20:
                        continue
                    p = list(tri)
                    if n[0] * want < 0:
                        p[1], p[2] = p[2], p[1]
                    u = [np.array([v[2] * UVK, v[1] * UVK]) for v in p]
                    B.tri(p[0], p[1], p[2], u[0], u[1], u[2], 1 if want < 0 else 2, gmat if gmat != "glow" else flat_mat)


def blade_dots(B, q, P, n=2):
    """Gold studs at the foot of each flat, either side of the band (blade tier 2 and up)."""
    if q < 1:
        return
    band = P.get("band")
    for i in range(n):
        s = 0.02 + 0.022 * i + (P["ric"][0] if P.get("ric") else 0.0)
        w = width_at(s, P["w"], P["s_tip"], P["tip_p"])
        bw = band["bw"] if band else 0.002
        x = bw + (w - P["bevel"] - bw) * 0.5
        t = P["t0"] - (P["t0"] - P["t1"]) * s
        z = t * (0.5 + 0.5 * (1 - (x - bw) / max(w - P["bevel"] - bw, 1e-6) * 1.0)) if True else t
        z = t - (t * 0.5) * ((x - bw) / max(w - P["bevel"] - bw, 1e-6))
        for sx in (-1, 1):
            if sx < 0 and "wl" in P:
                continue
            for sz in (-1, 1):
                dot(B, sx * x, P["y0"] + s * P["L"], sz * (z - 0.0002), 0.0016 - 0.0003 * i)


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


def twist_grip(B, y_top, y_bot, rx, rz, mat, q, turns_per_m=9.0, lobes=4):
    """A bar of lobed section twisted along its length (spiral-fluted metal grip)."""
    seg = 16 if q >= 1 else 8
    n = max(4, int(abs(y_top - y_bot) / (0.007 if q >= 1 else 0.02)))
    rings = []
    for i in range(n + 1):
        u = i / n
        y = y_top + (y_bot - y_top) * u
        k = (1 + 0.05 * math.sin(math.pi * u)) * (1 - 0.08 * u)
        ph = 2 * math.pi * turns_per_m * abs(y - y_top)
        ring = []
        for j in range(seg):
            a = 2 * math.pi * j / seg
            r = 1 + 0.13 * math.cos(lobes * (a - ph))
            ring.append((rx * k * r * math.cos(a), y, rz * k * r * math.sin(a)))
        rings.append(ring)
    B.part()
    loft(B, rings, mat, smooth_u=True, uv="cyl", urep=2.0, vk=UVK)
    B.close()


def collar(B, y0, y1, rx, rz, mat, seg=12, c=0.0012):
    """A ferrule / riser ring on the grip: short, proud, chamfered both sides."""
    B.part()
    lathe(B, [(y0, rx - c), (y0 + c, rx), (y1 - c, rx), (y1, rx - c)], mat, seg=seg, rz_scale=rz / rx, hard=(1, 2), grain=0)
    B.close()


def hilt_grip(B, q, top, bot, rx, rz, tier, mids=()):
    """Grip by handle tier: 0 plain cord, 1 cord between steel ferrules, 2 fine wrap divided by gold rings,
    3 a twisted steel bar banded in gold. `mids` are heights of dividing rings (risers) where the design has them."""
    seg = 12 if q >= 1 else 6
    cuts = [top] + sorted([m for m in mids], reverse=True) + [bot]
    for a, b in zip(cuts[:-1], cuts[1:]):
        if tier >= 3:
            twist_grip(B, a, b, rx * 0.96, rz * 0.96, "steel", q)
        else:
            grip(B, a, b, rx, rz, "grip" if tier < 2 else "grip_fine", seg=seg, stations=(7 if q >= 1 else 3),
                 swell=0.05, taper_bot=0.94, wraps=26.0 if tier < 2 else 40.0)
    if tier >= 1:
        ring_mat = "steel" if tier == 1 else "gold"
        w = 0.0022 if tier == 1 else 0.0016
        for y in ([top, bot] if q >= 1 else []) + list(mids):
            collar(B, y - w, y + w, rx * 1.1, rz * 1.12, ring_mat if y not in mids or tier > 1 else "steel", seg, 0.001)
        if tier >= 2 and q >= 1 and not mids:
            m = (top + bot) / 2
            for y in ((m,) if tier == 2 else (top + (bot - top) * 0.33, top + (bot - top) * 0.67)):
                collar(B, y - 0.0013, y + 0.0013, rx * 1.1, rz * 1.12, "gold", seg, 0.0008)


def lathe_part(B, prof, mat, **kw):
    B.part()
    lathe(B, prof, mat, **kw)
    B.close()


# ============================================================================ swords
# Every sword is a parameter set: blade (blade2), a sculpted plate guard, a grip by tier, a pommel.
# mod = {"blade_tier": 0-3, "grip_tier": 0-3}; ore and sharpening are material-only and applied at load.
ENGRAVE = {"wayfarer": "rule", "silver_vow": "lattice", "ashbrand": "chevron", "veilcutter": "feather",
           "oathbreaker": "circuit", "eternal_edge": "wave", "kings_remnant": "meander", "cold_resolve": "hexcell",
           "nightward": "feather", "twin_relics": "hexcell"}


def apply_blade_tier(item, P, tier):
    """0 plain recessed band and centre groove; 1 engraved band; 2 + gold studs at the foot of the blade;
    3 + the centre groove inlaid in gold. Never wider, longer or sharper-looking: only finer."""
    P = dict(P)
    if P.get("band"):
        b = dict(P["band"])
        b["mat"] = ("engrave_" + ENGRAVE[item]) if tier >= 1 else P.get("flat_mat", "blade")
        P["band"] = b
    if P.get("groove") and tier >= 3 and P["groove"]["mat"] != "glow":
        g = dict(P["groove"])
        g["mat"] = "gold"
        P["groove"] = g
    return P


def sword(B, q, item, P, mod, guard, pommel, grip_spec, parts):
    bt, gt = int(mod["blade_tier"]), int(mod["grip_tier"])
    if "blade" in parts:
        P2 = apply_blade_tier(item, P, bt)
        blade2(B, q, P2)
        if bt >= 2:
            blade_dots(B, q, P2)
        if P.get("fins"):
            P["fins"](B, q)
    if "hilt" in parts:
        guard(B, q)
        hilt_grip(B, q, grip_spec["top"], grip_spec["bot"], grip_spec["rx"], grip_spec["rz"], gt, grip_spec.get("mids", ()))
        pommel(B, q)


def _bev(q, b):
    return b if q >= 1 else 0.0


def build_wayfarer(B, q, mod, parts):
    """BALANCED. Medium blade with a gentle waist; symmetric slotted bar guard whose tips turn down; pentagonal tab pommel."""
    P = dict(L=0.80, y0=0.070, w=[(0, 0.0238), (0.14, 0.0222), (0.50, 0.0250), (0.84, 0.0165)], s_tip=0.84, tip_p=1.9,
             t0=0.0031, t1=0.0016, bevel=0.0040, band=dict(bw=0.0093, end=0.66, mat="blade"),
             groove=dict(gw=0.0013, d=0.0010, s0=0.02, s1=0.60, mat="blade_groove"))
    P.update(mod.get("P", {}))

    def guard(B, q):
        zh = 0.0055
        out = mirror_x([(0, 0.050), (0.024, 0.050), (0.030, 0.054), (0.078, 0.054), (0.091, 0.045), (0.098, 0.048),
                        (0.095, 0.062), (0.087, 0.068), (0.030, 0.068), (0.024, 0.075), (0, 0.075)])
        slot = [(0.037, 0.059), (0.077, 0.059), (0.081, 0.061), (0.077, 0.063), (0.037, 0.063), (0.034, 0.061)]
        plate(B, out, both(slot) if q >= 1 else [], zh, _bev(q, 0.0012), "steel")
        block(B, -0.016, 0.016, 0.051, 0.074, -0.0088, 0.0088, 0.0022, "steel")
        dots(B, q, [(0, 0.0625)], 0.0088, 0.0030)
        dots(B, q, [(0.0885, 0.056), (-0.0885, 0.056)], zh, 0.0020)

    def pommel(B, q):
        out = mirror_x([(0, -0.104), (0.011, -0.099), (0.019, -0.082), (0.019, -0.067), (0.012, -0.058), (0, -0.058)])
        plate(B, out, [circle(0, -0.083, 0.0052, 6, math.pi / 6)] if q >= 1 else [], 0.0075, _bev(q, 0.0016), "steel")
        if q >= 1:
            collar(B, -0.060, -0.055, 0.0152, 0.0124, "steel")

    sword(B, q, "wayfarer", P, mod, guard, pommel, dict(top=0.050, bot=-0.056, rx=0.0142, rz=0.0116), parts)
    return {"class": "sword", "name": "Wayfarer", "role": "balanced", "rarity": "common", "basic": True, "blade": P["L"],
            "tip": P["y0"] + P["L"], "pommel": 0.104, "grip_clear": 0.106, "guard_span": 0.196, "hands": 1}


def build_silver_vow(B, q, mod, parts):
    """LIGHT / FAST. The slimmest blade, needle-waisted; a small open lens-shaped frame guard; one-palm grip; bead pommel."""
    P = dict(L=0.78, y0=0.066, w=[(0, 0.0165), (0.14, 0.0140), (0.50, 0.0172), (0.72, 0.0150)], s_tip=0.72, tip_p=2.3,
             t0=0.0028, t1=0.0014, bevel=0.0030, band=dict(bw=0.0067, end=0.62, mat="blade"),
             groove=dict(gw=0.0009, d=0.0008, s0=0.03, s1=0.55, mat="blade_groove"))
    hw, hh, yc = 0.056, 0.0175, 0.0625

    def guard(B, q):
        n = 9 if q >= 1 else 4
        xs = [hw * math.sin(math.pi / 2 * i / n) for i in range(n + 1)]
        xs[-1] = hw - 0.0040
        right = [(x, yc - hh * (1 - (x / hw) ** 2) ** 0.9) for x in xs] + [(x, yc + hh * (1 - (x / hw) ** 2) ** 0.9) for x in reversed(xs)]
        win = []
        wx = [0.0175 + (0.0390 - 0.0175) * i / 5 for i in range(6)]
        for x in wx:
            win.append((x, yc - max(hh * (1 - (x / hw) ** 2) - 0.0062, 0.0006)))
        for x in reversed(wx):
            win.append((x, yc + max(hh * (1 - (x / hw) ** 2) - 0.0062, 0.0006)))
        plate(B, mirror_x(right), both(win) if q >= 1 else [], 0.0048, _bev(q, 0.0007), "steel")
        block(B, -0.0130, 0.0130, 0.047, 0.078, -0.0078, 0.0078, 0.0020, "steel")
        dots(B, q, [(0, 0.060)], 0.0078, 0.0024)
        dots(B, q, [(0.0505, yc), (-0.0505, yc)], 0.0048, 0.0016)

    def pommel(B, q):
        lathe_part(B, [(-0.046, 0.0090), (-0.051, 0.0128), (-0.060, 0.0146), (-0.070, 0.0108), (-0.075, 0.0040)], "steel",
                   seg=8, facet=True, hard=(1, 2, 3), phase=math.pi / 8)
        if q >= 1:
            collar(B, -0.0485, -0.0455, 0.0128, 0.0118, "gold", 8, 0.0008)

    sword(B, q, "silver_vow", P, mod, guard, pommel, dict(top=0.049, bot=-0.046, rx=0.0128, rz=0.0108), parts)
    return {"class": "sword", "name": "Silver Vow", "role": "light", "rarity": "common", "basic": True, "blade": P["L"],
            "tip": P["y0"] + P["L"], "pommel": 0.075, "grip_clear": 0.095, "guard_span": 0.109, "hands": 1}


def build_ashbrand(B, q, mod, parts):
    """HEAVY / DAMAGE. Broad thick leaf blade carrying its mass toward the point; a large blocky anvil guard with
    two windows and a tall collar; hand-and-a-half grip; slotted block pommel."""
    P = dict(L=0.80, y0=0.084, w=[(0, 0.0215), (0.10, 0.0205), (0.62, 0.0300), (0.80, 0.0262)], s_tip=0.80, tip_p=1.6,
             t0=0.0040, t1=0.0024, bevel=0.0050, band=dict(bw=0.0125, end=0.70, mat="blade"),
             groove=dict(gw=0.0018, d=0.0013, s0=0.03, s1=0.60, mat="blade_groove"))

    def guard(B, q):
        zh = 0.0080
        out = mirror_x([(0, 0.048), (0.030, 0.048), (0.036, 0.054), (0.068, 0.054), (0.074, 0.048), (0.088, 0.048),
                        (0.088, 0.067), (0.080, 0.075), (0.046, 0.075), (0.040, 0.083), (0.029, 0.083), (0.029, 0.092), (0, 0.092)])
        win = rect(0.043, 0.0585, 0.071, 0.0690, 0.0022)
        plate(B, out, both(win) if q >= 1 else [], zh, _bev(q, 0.0016), "steel")
        block(B, -0.0235, 0.0235, 0.050, 0.090, -0.0108, 0.0108, 0.0028, "graphite", grain=1)
        dots(B, q, [(0, 0.058), (0, 0.082)], 0.0108, 0.0026)
        dots(B, q, [(0.0815, 0.0565), (-0.0815, 0.0565)], zh, 0.0024)

    def pommel(B, q):
        out = mirror_x([(0, -0.143), (0.018, -0.143), (0.023, -0.137), (0.023, -0.113), (0.016, -0.102), (0, -0.102)])
        plate(B, out, [rect(-0.0042, -0.135, 0.0042, -0.115, 0.0015)] if q >= 1 else [], 0.0100, _bev(q, 0.0020), "steel")

    sword(B, q, "ashbrand", P, mod, guard, pommel, dict(top=0.048, bot=-0.100, rx=0.0155, rz=0.0126), parts)
    return {"class": "sword", "name": "Ashbrand", "role": "heavy", "rarity": "common", "basic": True, "blade": P["L"],
            "tip": P["y0"] + P["L"], "pommel": 0.143, "grip_clear": 0.148, "guard_span": 0.176, "hands": 1.5}


def build_veilcutter(B, q, mod, parts):
    """PRECISION / COMBO. Long slim blade with a row of diamond openings pierced through its fuller; an asymmetric
    guard: a short arm leaning toward the point, a long arm sweeping back past the knuckles; spike pommel."""
    P = dict(L=0.92, y0=0.066, w=[(0, 0.0168), (0.25, 0.0150), (0.58, 0.0172), (0.72, 0.0160)], s_tip=0.72, tip_p=2.4,
             t0=0.0030, t1=0.0014, bevel=0.0032, band=dict(bw=0.0096, end=0.60, mat="blade"),
             groove=dict(gw=0.0034, d=0.0008, s0=0.04, s1=0.50, mat="blade_groove"),
             holes=[(0.085 + 0.058 * i, 0.0105, 0.0023) for i in range(7)])

    def guard(B, q):
        zh = 0.0052
        out = ribbon([(0.052, 0.078), (0.030, 0.065), (0.0, 0.058), (-0.034, 0.056), (-0.058, 0.044), (-0.067, 0.016), (-0.058, -0.018)],
                     [0.0032, 0.0075, 0.0108, 0.0082, 0.0064, 0.0050, 0.0030], 30 if q >= 1 else 12)
        plate(B, out, [], zh, _bev(q, 0.0011), "steel")
        block(B, -0.0135, 0.0135, 0.049, 0.070, -0.0080, 0.0080, 0.0020, "steel")
        dots(B, q, [(0, 0.0595)], 0.0080, 0.0026)
        dots(B, q, [(0.030, 0.065), (-0.034, 0.056), (-0.0655, 0.018)], zh, 0.0017)

    def pommel(B, q):
        lathe_part(B, [(-0.064, 0.0095), (-0.070, 0.0126), (-0.084, 0.0108), (-0.104, 0.0042), (-0.111, 0.0008)], "steel",
                   seg=10 if q >= 1 else 6, hard=(1,))
        if q >= 1:
            collar(B, -0.0715, -0.0685, 0.0136, 0.0136, "gold", 10, 0.0008)

    sword(B, q, "veilcutter", P, mod, guard, pommel, dict(top=0.049, bot=-0.064, rx=0.0130, rz=0.0110), parts)
    return {"class": "sword", "name": "Veilcutter", "role": "precision", "rarity": "common", "basic": True, "blade": P["L"],
            "tip": P["y0"] + P["L"], "pommel": 0.111, "grip_clear": 0.113, "guard_span": 0.119, "hands": 1}


def build_oathbreaker(B, q, mod, parts):
    """Greatsword. Blunt ricasso, long taper; a wide tiered guard cut like a circuit board, with windows and slots,
    and a tall clamp up the ricasso; two-hand grip divided by a riser; keystone pommel."""
    P = dict(L=1.20, y0=0.098, w=[(0, 0.0290), (0.5, 0.0272), (0.88, 0.0190)], s_tip=0.88, tip_p=1.8,
             t0=0.0044, t1=0.0021, bevel=0.0050, ric=(0.10, 0.0045, 0.0030), band=dict(bw=0.0116, end=0.62, mat="blade"),
             groove=dict(gw=0.0017, d=0.0012, s0=0.13, s1=0.56, mat="blade_groove"))

    def guard(B, q):
        zh = 0.0090
        out = mirror_x([(0, 0.050), (0.030, 0.050), (0.030, 0.056), (0.072, 0.056), (0.072, 0.048), (0.108, 0.048), (0.108, 0.058),
                        (0.150, 0.058), (0.150, 0.072), (0.118, 0.072), (0.118, 0.081), (0.062, 0.081), (0.062, 0.091),
                        (0.028, 0.091), (0.028, 0.118), (0.020, 0.126), (0, 0.126)])
        win = rect(0.072, 0.0625, 0.108, 0.0745, 0.002)
        slot = rect(0.124, 0.0630, 0.144, 0.0670, 0.0012)
        plate(B, out, (both(win) + both(slot)) if q >= 1 else [], zh, _bev(q, 0.0018), "steel")
        block(B, -0.0245, 0.0245, 0.052, 0.116, -0.0120, 0.0120, 0.0030, "graphite", grain=1)
        dots(B, q, [(0, 0.062), (0, 0.084), (0, 0.106)], 0.0120, 0.0028)
        dots(B, q, [(0.134, 0.0605), (-0.134, 0.0605), (0.045, 0.086), (-0.045, 0.086)], zh, 0.0024)

    def pommel(B, q):
        out = mirror_x([(0, -0.322), (0.024, -0.322), (0.027, -0.314), (0.017, -0.262), (0.012, -0.252), (0, -0.252)])
        plate(B, out, [rect(-0.005, -0.308, 0.005, -0.282, 0.0018)] if q >= 1 else [], 0.0105, _bev(q, 0.0020), "steel")

    sword(B, q, "oathbreaker", P, mod, guard, pommel, dict(top=0.050, bot=-0.250, rx=0.0158, rz=0.0128, mids=(-0.074,)), parts)
    return {"class": "greatsword", "name": "Oathbreaker", "role": "heavy", "rarity": "rare", "blade": P["L"], "tip": P["y0"] + P["L"],
            "pommel": 0.322, "grip_clear": 0.300, "guard_span": 0.300, "hands": 2, "off_hand": -0.165}


def build_eternal_edge(B, q, mod, parts):
    """Legendary. Waisted leaf blade with an engraved core and one hairline light channel; the guard is a slender
    arrow-shaped frame: short wings, two long prongs that run up beside the blade, parted from it by open slits."""
    P = dict(L=0.88, y0=0.070, w=[(0, 0.0170), (0.10, 0.0158), (0.52, 0.0215), (0.80, 0.0150)], s_tip=0.80, tip_p=2.2,
             t0=0.0033, t1=0.0016, bevel=0.0034, band=dict(bw=0.0101, end=0.72, mat="blade"),
             groove=dict(gw=0.0011, d=0.0009, s0=0.11, s1=0.62, mat="glow"))
    P.update(mod.get("P", {}))

    def guard(B, q):
        zh = 0.0058
        out = mirror_x([(0, 0.049), (0.018, 0.049), (0.046, 0.060), (0.047, 0.066), (0.036, 0.070), (0.0325, 0.075),
                        (0.0285, 0.120), (0.0235, 0.150), (0.0190, 0.158), (0, 0.147)])
        slit = [(0.0195, 0.079), (0.0265, 0.079), (0.0256, 0.101), (0.0214, 0.136), (0.0195, 0.139)]
        plate(B, out, both(slit) if q >= 1 else [], zh, _bev(q, 0.0010), "steel")
        block(B, -0.0130, 0.0130, 0.050, 0.070, -0.0085, 0.0085, 0.0020, "graphite", grain=1)
        dots(B, q, [(0, 0.060)], 0.0085, 0.0028)
        dots(B, q, [(0.0415, 0.0635), (-0.0415, 0.0635), (0.0245, 0.144), (-0.0245, 0.144)], zh, 0.0016)

    def pommel(B, q):
        plate(B, circle(0, -0.133, 0.0195, 6, 0.0), [circle(0, -0.133, 0.0100, 6, 0.0)], 0.0062, _bev(q, 0.0014), "steel")
        if q >= 1:
            collar(B, -0.1150, -0.1105, 0.0140, 0.0122, "gold", 12, 0.0008)

    sword(B, q, "eternal_edge", P, mod, guard, pommel, dict(top=0.049, bot=-0.112, rx=0.0134, rz=0.0113), parts)
    return {"class": "sword", "name": "Eternal Edge", "role": "balanced", "rarity": "legendary", "blade": P["L"], "tip": P["y0"] + P["L"],
            "pommel": 0.1525, "grip_clear": 0.161, "guard_span": 0.094, "hands": 1.5, "emissive": True}


def build_kings_remnant(B, q, mod, parts):
    """Broad parallel-edged blade with a short strong point; the guard's upper edge is a row of merlons, a broken
    crown, over a long window; disc pommel pierced by a square."""
    P = dict(L=0.86, y0=0.088, w=[(0, 0.0250), (0.70, 0.0238), (0.86, 0.0196)], s_tip=0.86, tip_p=1.45,
             t0=0.0033, t1=0.0018, bevel=0.0040, band=dict(bw=0.0110, end=0.74, mat="blade"),
             groove=dict(gw=0.0016, d=0.0011, s0=0.03, s1=0.66, mat="blade_groove"))

    def guard(B, q):
        zh = 0.0065
        out = mirror_x([(0, 0.049), (0.086, 0.049), (0.096, 0.056), (0.096, 0.079), (0.084, 0.079), (0.084, 0.068), (0.071, 0.068),
                        (0.071, 0.079), (0.057, 0.079), (0.057, 0.068), (0.041, 0.068), (0.041, 0.083), (0.027, 0.083), (0.027, 0.094), (0, 0.094)])
        win = rect(0.034, 0.0545, 0.087, 0.0625, 0.0018)
        plate(B, out, both(win) if q >= 1 else [], zh, _bev(q, 0.0013), "steel")
        block(B, -0.0200, 0.0200, 0.050, 0.092, -0.0095, 0.0095, 0.0024, "steel")
        dots(B, q, [(0, 0.060), (0, 0.082)], 0.0095, 0.0026)
        dots(B, q, [(0.090, 0.0735), (-0.090, 0.0735), (0.064, 0.0735), (-0.064, 0.0735), (0.034, 0.0765), (-0.034, 0.0765)], zh, 0.0018)

    def pommel(B, q):
        plate(B, circle(0, -0.108, 0.0215, 16 if q >= 1 else 8), [circle(0, -0.108, 0.0085, 4, 0.0)], 0.0080, _bev(q, 0.0018), "steel")
        if q >= 1:
            collar(B, -0.0890, -0.0845, 0.0146, 0.0124, "gold", 12, 0.0008)

    sword(B, q, "kings_remnant", P, mod, guard, pommel, dict(top=0.049, bot=-0.086, rx=0.0142, rz=0.0118), parts)
    return {"class": "sword", "name": "King's Remnant", "role": "balanced", "rarity": "rare", "blade": P["L"], "tip": P["y0"] + P["L"],
            "pommel": 0.1295, "grip_clear": 0.135, "guard_span": 0.192, "hands": 1.5}


def build_cold_resolve(B, q, mod, parts):
    """Needle blade with a frost-coloured channel; the guard is an open hexagonal collar the blade stands in,
    a window either side of it; a four-sided crystal pommel."""
    P = dict(L=0.86, y0=0.070, w=[(0, 0.0180), (0.5, 0.0150), (0.80, 0.0105)], s_tip=0.80, tip_p=2.0,
             t0=0.0030, t1=0.0015, bevel=0.0030, band=dict(bw=0.0075, end=0.60, mat="blade"),
             groove=dict(gw=0.0010, d=0.0008, s0=0.14, s1=0.55, mat="glow"))

    def guard(B, q):
        zh = 0.0055
        out = mirror_x([(0, 0.047), (0.028, 0.047), (0.056, 0.074), (0.028, 0.101), (0, 0.101)])
        cell = _ccw([(0.0215, 0.047), (0.028, 0.047), (0.056, 0.074), (0.028, 0.101), (0.0215, 0.101)])
        win = [tuple(p) for p in inset(cell, 0.0062, sym_fix=False)]
        plate(B, out, both(win), zh, _bev(q, 0.0011), "steel")
        dots(B, q, [(0, 0.0555), (0, 0.0925)], zh, 0.0024)
        dots(B, q, [(0.0505, 0.074), (-0.0505, 0.074)], zh, 0.0017)

    def pommel(B, q):
        lathe_part(B, [(-0.070, 0.0080), (-0.077, 0.0118), (-0.091, 0.0165), (-0.113, 0.0020)], "steel", seg=4, facet=True, hard=(1, 2), phase=math.pi / 4)

    sword(B, q, "cold_resolve", P, mod, guard, pommel, dict(top=0.048, bot=-0.070, rx=0.0130, rz=0.0110), parts)
    return {"class": "sword", "name": "Cold Resolve", "role": "light", "rarity": "rare", "blade": P["L"], "tip": P["y0"] + P["L"],
            "pommel": 0.113, "grip_clear": 0.118, "guard_span": 0.112, "hands": 1, "emissive": True}


def build_nightward(B, q, mod, parts):
    """Single-edged backsword in blackened steel with a bright edge; cooling fins stand along the spine; the guard
    is a half-disc on the edge side only, pierced by three graduated ports; tab pommel with a lanyard eye."""
    L, y0 = 0.76, 0.078

    def fins(B, q):
        for i in range(6):
            ya = y0 + L * (0.085 + 0.045 * i)
            h = 0.0075 - 0.0008 * i
            B.part()
            loft(B, [[(-0.0085, ya, z), (-0.0085 - h, ya + 0.002, z), (-0.0085 - h, ya + 0.021, z), (-0.0085, ya + 0.023, z)] for z in (-0.0021, 0.0021)],
                 "graphite", smooth_u=False, grain=1)
            B.close()

    P = dict(L=L, y0=y0, w=[(0, 0.0300), (0.75, 0.0270), (0.78, 0.0262)], wl=[(0, 0.0090), (0.78, 0.0090)], s_tip=0.78, tip_p=1.5,
             t0=0.0036, t1=0.0020, bevel=0.0052, flat_mat="graphite", band=dict(bw=0.0075, end=0.60, mat="graphite"), fins=fins)

    def guard(B, q):
        zh = 0.0060
        n = 12 if q >= 1 else 5
        arc = [(0.030 + 0.056 * math.cos(a), 0.066 + 0.0175 * math.sin(a)) for a in [-math.pi / 2 + math.pi * i / n for i in range(n + 1)]]
        out = [(-0.026, 0.0485), (0.030, 0.0485)] + arc[1:-1] + [(0.030, 0.0835), (-0.014, 0.0835), (-0.026, 0.072)]
        ports = [circle(0.047, 0.066, 0.0056, 8), circle(0.0625, 0.066, 0.0045, 8), circle(0.0750, 0.066, 0.0034, 8)]
        plate(B, out, ports if q >= 1 else [], zh, _bev(q, 0.0012), "steel")
        block(B, -0.0160, 0.0160, 0.050, 0.082, -0.0090, 0.0090, 0.0022, "graphite", grain=1)
        dots(B, q, [(0, 0.066)], 0.0090, 0.0026)

    def pommel(B, q):
        plate(B, rect(-0.0135, -0.099, 0.0135, -0.062, 0.004), [circle(0, -0.0855, 0.0056, 8)] if q >= 1 else [], 0.0070, _bev(q, 0.0015), "steel")

    sword(B, q, "nightward", P, mod, guard, pommel, dict(top=0.049, bot=-0.062, rx=0.0142, rz=0.0118), parts)
    return {"class": "sword", "name": "Nightward", "role": "heavy", "rarity": "uncommon", "blade": L, "tip": y0 + L,
            "pommel": 0.099, "grip_clear": 0.111, "guard_span": 0.112, "hands": 1, "single_edged": True}


def build_twin_relics(B, q, mod, parts):
    """One of a mirrored pair (the left hand's is this model scaled -1 in X). Short leaf blade with a light channel;
    the guard is an angular C-frame that returns to the pommel as a knuckle bar."""
    P = dict(L=0.60, y0=0.062, w=[(0, 0.0180), (0.12, 0.0165), (0.55, 0.0235), (0.80, 0.0165)], s_tip=0.80, tip_p=1.9,
             t0=0.0030, t1=0.0016, bevel=0.0034, band=dict(bw=0.0090, end=0.70, mat="blade"),
             groove=dict(gw=0.0010, d=0.0008, s0=0.08, s1=0.60, mat="glow"))

    def guard(B, q):
        zh = 0.0052
        out = [(-0.024, 0.047), (0.044, 0.047), (0.050, 0.041), (0.050, -0.094), (0.044, -0.100), (0.013, -0.100), (0.013, -0.112),
               (0.052, -0.112), (0.062, -0.102), (0.062, 0.056), (0.052, 0.067), (0.020, 0.067), (0.014, 0.078), (-0.014, 0.078), (-0.020, 0.067), (-0.030, 0.062)]
        plate(B, out, [], zh, _bev(q, 0.0011), "steel")
        dots(B, q, [(0, 0.0575), (0.056, 0.030), (0.056, -0.025), (0.056, -0.080)], zh, 0.0019)

    def pommel(B, q):
        lathe_part(B, [(-0.098, 0.0115), (-0.102, 0.0142), (-0.112, 0.0142), (-0.118, 0.0090), (-0.119, 0.0030)], "steel",
                   seg=6, facet=True, hard=(1, 2, 3), phase=math.pi / 6)

    sword(B, q, "twin_relics", P, mod, guard, pommel, dict(top=0.048, bot=-0.098, rx=0.0132, rz=0.0112), parts)
    return {"class": "dual", "name": "Twin Relics", "role": "precision", "rarity": "relic", "blade": P["L"], "tip": P["y0"] + P["L"],
            "pommel": 0.119, "grip_clear": 0.146, "guard_span": 0.092, "hands": 1, "emissive": True, "pair": True, "mirror_left": True}


SWORDS = {"wayfarer": build_wayfarer, "silver_vow": build_silver_vow, "ashbrand": build_ashbrand, "veilcutter": build_veilcutter,
          "oathbreaker": build_oathbreaker, "eternal_edge": build_eternal_edge, "kings_remnant": build_kings_remnant,
          "cold_resolve": build_cold_resolve, "nightward": build_nightward, "twin_relics": build_twin_relics}
BASIC = ["wayfarer", "silver_vow", "ashbrand", "veilcutter"]
# the state each sword's own file is built in; the four basic swords also get every tier of each track as parts
DEFAULT_MOD = {"wayfarer": (1, 1), "silver_vow": (1, 1), "ashbrand": (1, 1), "veilcutter": (1, 1), "oathbreaker": (2, 1),
               "eternal_edge": (2, 2), "kings_remnant": (3, 2), "cold_resolve": (1, 2), "nightward": (1, 1), "twin_relics": (2, 2)}


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


def inset(poly, d, sym_fix=True):
    """Moves every vertex of a counter-clockwise polygon inward by d along its corner bisector."""
    poly = np.asarray(poly, dtype=float)
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
    for i in range(len(poly) if sym_fix else 0):
        if poly[i][0] * out[i][0] < 0 and abs(tan[i][0]) > 1e-6:
            out[i] = out[i] - tan[i] * (out[i][0] / tan[i][0])
    return out


def board(B, outline, table, zf, centre, off, gu=None, col_dz=None, gu_bands=(), mat_fn=None, polar=None):
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
        mats.append([(mat_fn(len(rings) - 1, row, j) or m) if mat_fn else m for j in range(N)])
        gv.append(g)
    uv = "box"
    if polar is not None:
        # lathe-turned parts: the brushing runs round the centre, not across the board
        def uv(pts, rc, n):
            out = []
            for p, (r_, c_) in zip(pts, rc):
                rad = math.hypot(p[0] - off[0], p[1] - off[1])
                ang = polar[c_] if c_ < N else polar[0] + 2 * math.pi
                out.append(np.array([(rad + p[2]) * UVK, ang * 20.0 / (2 * math.pi)]))
            return out
    B.part()
    gfun = (lambda r, c: (gu[c] if gv[r] in gu_bands else 0) * 2000 + gv[r]) if gu is not None else None
    loft(B, rings, mats[:-1], gu=[0] * N, gv=gv[:-1], uv=uv, grain=1, cap0=False, cap1=False, gfun=gfun)
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


def boss(B, cx, cy, z0, prof, mats, seg=6, facet=True, front=True, phase=0.0):
    """A turned or faceted boss on a shield face: prof is [(height, radius)], rising toward -Z on the front."""
    B.part()
    lathe(B, prof, mats, seg=seg, facet=facet, hard=range(len(prof)), y_axis=2, phase=phase)
    sg = -1.0 if front else 1.0
    for i in range(B.start, len(B.P)):
        B.P[i] = tuple(np.array([p[0] + cx, p[1] + cy, sg * p[2] + z0]) for p in B.P[i])
    B.close()


def strip(B, path, half_w, zsurf, proud, mat_top, mat_side="steel", perp=(1.0, 0.0), uvmat=None):
    """A raised band laid over a curved board along `path` [(x, y)] in model space (spines, reinforcing bars)."""
    rings = []
    for i, (x, y) in enumerate(path):
        hw = half_w(i / (len(path) - 1)) if callable(half_w) else half_w
        pts = []
        for k, lift in ((-1.0, 0.0), (-0.78, proud), (0.78, proud), (1.0, 0.0)):
            px, py = x + perp[0] * hw * k, y + perp[1] * hw * k
            pts.append((px, py, zsurf(px, py) - lift + (0.0008 if lift == 0.0 else 0.0)))
        rings.append(pts)
    B.part()
    loft(B, rings, [[mat_side, mat_top, mat_side, mat_side]] * (len(path) - 1), smooth_u=False, grain=1, uvmat=uvmat)
    B.close()


def kite_shield(B, q, S):
    """Heater / tower family: an outline wrapped round the arm, raised rim with dark inlays, engraved spine,
    bolted reinforcing bars (heavier classes), and the rear furniture: grip bar, arm strap, forearm pad."""
    hw, H_top, H_bot = S["hw"], S["H_top"], S["H_bot"]
    P = S["P"] if q >= 1 else 28
    outline = resample(S["outline"], P)
    outline[0] = (0.0, H_bot)
    for i in range(1, P // 2):
        outline[P - i] = (-outline[i][0], outline[i][1])
    outline[P // 2] = (0.0, outline[P // 2][1])
    R, T, off = S["R"], S["T"], S["off"]
    rw, rp = S["rim"], S["rim_proud"]

    def zf(x, y):
        return (R - math.sqrt(R * R - x * x)) - S["keel"] * (1 - math.sqrt(x * x + 0.0009) / hw) + S["dish"] * (y - S["dish_y"]) ** 2

    centre = np.array([0.0, S["centre_y"]])
    fm = S["field"]
    field = [("s", 0.0, 0.0, fm, 0), ("s", 0.3, 0.0, fm, 0), ("s", 0.62, 0.0, fm, 0), ("s", 0.80, 0.0, fm, 0),
             # an engraved line that follows the outline inside the field
             ("s", 0.815, -0.0012, fm, 20), ("s", 0.83, 0.0, fm, 21), ("s", 0.86, 0.0, fm, 0)] if q >= 1 else \
            [("s", 0.0, 0.0, fm, 0), ("s", 0.6, 0.0, fm, 0)]
    table = field + [
        ("s", 0.972, 0.0, "gold", 1), ("i", rw + 0.003, 0.0004, "steel", 2),
        ("i", rw, rp, "steel", 3), ("i", 0.0040, rp, "steel", 4), ("i", 0.0, 0.0012, "steel", 5),
        ("i", 0.0, -T + 0.001, "steel", 6), ("i", 0.004, -T - 0.0015, "steel", 7), ("i", rw - 0.0025, -T - 0.0015, "steel", 8),
        ("i", rw, -T, "leather", 9)]
    table += [("s", 0.86, -T, "leather", 9), ("s", 0.5, -T, "leather", 9), ("s", 0.0, -T, "leather", 9)] if q >= 1 else [("s", 0.5, -T, "leather", 9), ("s", 0.0, -T, "leather", 9)]
    rim_row = next(i for i, r in enumerate(table) if r[4] == 3)
    inlay = S["inlay"]

    def mat_fn(ri, row, j):
        # dark inlays let into the rim's top face, between bright lengths: a segmented, machined rim
        if ri == rim_row and q >= 1:
            u = j / P
            if any(a <= u < b for a, b in inlay):
                return "graphite"
        return None

    board(B, outline, table, zf, centre, off, mat_fn=mat_fn)

    def front_z(x, y):                  # model space
        return zf(x - off[0], y - off[1]) + off[2]

    def back_z(x, y):                   # board space, as before
        return zf(x, y) + T + off[2]

    if q >= 1:
        rim_mid = inset(outline, rw * 0.56)
        for j in range(0, P, P // S["rivets"]):
            x, y = rim_mid[j]
            rivet(B, (x + off[0], y + off[1], zf(x, y) - rp + off[2]), S["rivet_r"], S["rivet_r"] * 0.46, "steel", 6 if S.get("hex_bolts") else 8)
    # engraved spine down the middle of the face
    y_a, y_b = S["spine"]
    n = 12 if q >= 1 else 4
    path = [(off[0], off[1] + y_a + (y_b - y_a) * i / n) for i in range(n + 1)]
    sw = S["spine_w"]
    strip(B, path, lambda u: sw * (1 - 0.45 * u), front_z, 0.0032, "engrave_circuit", uvmat={"engrave_circuit": (sw, sw * 8, off[0], off[1] + y_a)})
    bx, by = off[0], off[1] + y_a + 0.012
    boss(B, bx, by, front_z(bx, by) - 0.002, [(0.0, 0.034), (0.006, 0.034), (0.009, 0.029), (0.009, 0.016), (0.0065, 0.014), (0.0065, 0.0001)],
         ["steel", "steel", "steel", "graphite", "graphite"], seg=6, phase=math.pi / 6)
    if q >= 1:
        dot(B, bx, by, front_z(bx, by) - 0.0085, 0.0045, "gold", 0.0012)
    for yb in S.get("bars", []):
        hx = S["bar_hw"](yb)
        nb = 10 if q >= 1 else 3
        strip(B, [(off[0] - hx + 2 * hx * i / nb, off[1] + yb) for i in range(nb + 1)], 0.017, front_z, 0.0045, "steel", perp=(0.0, 1.0))
        if q >= 1:
            for k in (-0.82, -0.3, 0.3, 0.82):
                x = off[0] + hx * k
                rivet(B, (x, off[1] + yb, front_z(x, off[1] + yb) - 0.0045), 0.0050, 0.0022, "steel", 6)

    def slope(x):
        return (back_z(x + 0.02 - off[0], -off[1]) - back_z(x - 0.02 - off[0], -off[1])) / 0.04

    hand_grip(B, 0.052, back_z(-off[0], -off[1]), "grip", q, slope=slope(0.0))
    sx = S["strap_x"]
    arm_strap(B, sx, 0.021 if not S.get("bars") else 0.026, 0.062, back_z(sx - off[0], -off[1]), 0.078, "leather", n=10 if q >= 1 else 4, slope=slope(sx))
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
    return {"class": "shield", "width": 2 * hw, "height": S["height"], "role": S["role"],
            "board_centre": [off[0], off[1] + (H_top + H_bot) / 2, off[2]], "strap_x": sx, "thickness": T}


def build_heater(B, q):
    """BALANCED. Streamlined heater: flat top, straight shoulders, two arcs to a point; segmented steel rim,
    graphite-blue field with an engraved contour line and an engraved spine under a hexagonal boss."""
    H_top, H_bot, hw, y_mid = 0.25, -0.41, 0.245, 0.06
    pts = []
    for i in range(41):
        t = 1 - i / 40
        pts.append((hw * (1 - t ** 2.15), y_mid - (y_mid - H_bot) * t))
    rc = 0.034
    for i in range(1, 9):
        a = math.pi / 2 * i / 8
        pts.append((hw - rc + rc * math.cos(a), H_top - rc + rc * math.sin(a)))
    pts += [(x, y + 0.012 * (1 - (x / (hw - rc)) ** 2)) for x, y in [((hw - rc) * (1 - i / 6), H_top) for i in range(1, 7)]]
    S = dict(outline=pts + [(-x, y) for x, y in reversed(pts[1:-1])], P=80, hw=hw, H_top=H_top, H_bot=H_bot, height=H_top + 0.012 - H_bot,
             R=0.47, T=0.008, keel=0.006, dish=0.07, dish_y=-0.08, centre_y=-0.05, off=(-0.105, -0.045, -0.058), field="enamel",
             rim=0.0305, rim_proud=0.0042, rivets=10, rivet_r=0.0048, strap_x=-0.205, role="balanced",
             inlay=[(0.035, 0.115), (0.885, 0.965), (0.44, 0.56), (0.215, 0.275), (0.725, 0.785)], spine=(0.150, -0.300), spine_w=0.016)
    info = kite_shield(B, q, S)
    info["name"] = "Heater"
    return info


def build_tower(B, q):
    """HEAVY. Tall kite-tower: square shoulders, long straight flanks, a tapered blunt foot; deeper wrap, thicker
    board, broad rim, two bolted reinforcing bars across the face. Reads as the slow, many-blocks class."""
    H_top, H_bot, hw = 0.37, -0.51, 0.26
    right = [(0.0, H_bot), (0.085, H_bot), (0.112, H_bot + 0.026), (hw, -0.20), (hw, H_top - 0.055), (hw - 0.055, H_top), (0.0, H_top)]
    dense = []
    for a, b in zip(right[:-1], right[1:]):
        for i in range(12):
            dense.append((a[0] + (b[0] - a[0]) * i / 12, a[1] + (b[1] - a[1]) * i / 12))
    dense.append(right[-1])
    S = dict(outline=dense + [(-x, y) for x, y in reversed(dense[1:-1])], P=96, hw=hw, H_top=H_top, H_bot=H_bot, height=H_top - H_bot,
             R=0.42, T=0.011, keel=0.004, dish=0.03, dish_y=-0.05, centre_y=-0.06, off=(-0.105, -0.050, -0.066), field="graphite",
             rim=0.040, rim_proud=0.0058, rivets=16, rivet_r=0.0058, hex_bolts=True, strap_x=-0.205, role="heavy",
             inlay=[(0.06, 0.14), (0.86, 0.94), (0.455, 0.545), (0.25, 0.31), (0.69, 0.75)], spine=(0.265, -0.420), spine_w=0.019,
             bars=[0.170, -0.130], bar_hw=lambda y: 0.212 if y > -0.2 else 0.15)
    info = kite_shield(B, q, S)
    info["name"] = "Tower"
    return info


def build_round(B, q):
    """LIGHT. Compact domed buckler: two stepped tiers cut by four seams and engraved rings, a two-tone turned
    rim, a hexagonal boss ringed by one narrow light channel. Small and quick to bring round."""
    Rr = 0.235
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

    T = 0.008
    off = (-0.098, 0.0, -0.060)
    centre = np.array([0.0, 0.0])
    fd = 0.038               # rim width: the "i" inset that defines the field boundary radius
    fr = Rr - fd

    def s(r):
        return r / fr

    inner = [("s", 0.0, 0.0040, "graphite", 0), ("s", s(0.034), 0.0040, "graphite", 1), ("s", s(0.034), 0.0018, "glow", 2),
             ("s", s(0.0375), 0.0018, "graphite", 3), ("s", s(0.0375), 0.0048, "gold", 4), ("s", s(0.041), 0.0048, "graphite", 5),
             ("s", s(0.044), 0.0040, "graphite", 6)]
    rings_eng = [("s", s(0.074), 0.0040, "graphite", 30), ("s", s(0.0755), 0.0026, "graphite", 31), ("s", s(0.077), 0.0040, "graphite", 6),
                 ("s", s(0.098), 0.0040, "graphite", 32), ("s", s(0.0995), 0.0026, "graphite", 33), ("s", s(0.101), 0.0040, "graphite", 6)]
    outer = [("s", s(0.118), 0.0040, "graphite", 9), ("s", s(0.122), 0.0, "enamel", 10),
             ("i", fd, 0.0, "steel", 11), ("i", fd - 0.003, 0.0040, "graphite", 12), ("i", 0.0215, 0.0040, "steel", 13),
             ("i", 0.0200, 0.0056, "steel", 14), ("i", 0.0045, 0.0056, "steel", 15), ("i", 0.0, 0.0012, "steel", 16),
             ("i", 0.0, -T + 0.001, "steel", 17), ("i", 0.0045, -T - 0.002, "steel", 18), ("i", fd - 0.008, -T - 0.002, "steel", 19),
             ("i", fd - 0.005, -T, "graphite", 22), ("s", 0.55, -T, "graphite", 22), ("s", 0.0, -T, "graphite", 22)]
    table = inner + (rings_eng if q >= 1 else []) + outer
    if q < 1:
        table = [inner[0], inner[1], inner[2], inner[3], inner[6]] + outer

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
    board(B, outline, table, zf, centre, off, gu=None if q < 1 else gu, col_dz=col_dz if q >= 1 else None, gu_bands=(10,), polar=angs)

    def back_z(x, y):
        return zf(x, y) + T + off[2]

    fz = off[2]
    boss(B, off[0], off[1], fz - 0.0035, [(0.0, 0.031), (0.0050, 0.031), (0.0085, 0.026), (0.0085, 0.013), (0.0060, 0.011), (0.0060, 0.0001)],
         ["steel", "steel", "steel", "graphite", "graphite"], seg=6, phase=math.pi / 6)
    if q >= 1:
        dot(B, off[0], off[1], fz - 0.0092, 0.0042, "gold", 0.0012)
        for i in range(8):
            a = math.pi / 8 + math.pi / 4 * i
            x, y = (Rr - 0.0122) * math.cos(a), (Rr - 0.0122) * math.sin(a)
            rivet(B, (x + off[0], y + off[1], zf(x, y) - 0.0056 + off[2]), 0.0040, 0.0018, "steel", 6)
        # rear: a low housing under a hexagonal cap, where the plates are keyed together
        zb = back_z(0, 0)
        boss(B, off[0], off[1], zb - 0.001, [(0.0, 0.044), (0.0050, 0.044), (0.0070, 0.040), (0.0070, 0.0001)], ["graphite", "graphite", "graphite"],
             seg=20, facet=False, front=False)
        boss(B, off[0], off[1], zb + 0.006, [(0.0, 0.018), (0.0040, 0.018), (0.0058, 0.015), (0.0058, 0.0001)], ["steel", "steel", "steel"],
             seg=6, front=False, phase=math.pi / 6)
        dot(B, off[0], off[1], zb + 0.0118, 0.0040, "gold", 0.0010)

    def slope(x):
        return (back_z(x + 0.02 - off[0], -off[1]) - back_z(x - 0.02 - off[0], -off[1])) / 0.04

    hand_grip(B, 0.050, back_z(-off[0], -off[1]), "grip", q, slope=slope(0.0))
    sx = -0.195
    arm_strap(B, sx, 0.019, 0.058, back_z(sx - off[0], -off[1]), 0.074, "leather", n=10 if q >= 1 else 4, slope=slope(sx))
    return {"class": "shield", "name": "Round", "role": "light", "width": 2 * Rr, "height": 2 * Rr,
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
    _save("steel_orm", _orm(0.54 + 0.10 * (h - 0.5), 0.9))
    # --- worn steel: the same brushing under a patina, pits and stray scratches
    pat = _norm01(_blur_wrap(rng.random((S, S)), 34, 10) + 0.3 * _blur_wrap(rng.random((S, S)), 8, 3))
    pat = np.clip((pat - 0.42) * 2.4, 0, 1)
    pits = np.clip((_norm01(_blur_wrap(rng.random((S, S)), 1.6, 1.6)) - 0.78) * 5, 0, 1)
    scr = np.clip((_norm01(_blur_wrap(rng.random((S, S)), 0.7, 12)) - 0.9) * 10, 0, 1) * 0.5
    hw = h * 0.8 - pits * 0.22 - scr * 0.2 + pat * 0.05
    val = 0.62 + 0.05 * (h - 0.5) - 0.08 * pat - 0.03 * pits + 0.03 * scr
    warm = pat * 0.045
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


PATTERNS = ["rule", "lattice", "chevron", "feather", "circuit", "wave", "meander", "hexcell"]


def engrave_textures():
    """Engraved line-work for blade bands: one 128 x 512 tile per pattern (the band is 9 - 17 mm wide, so a
    line is about 0.4 mm and stays crisp in a close-up). Depth goes to the normal map, a darker fill to the
    albedo and a rougher floor to the ORM. Every pattern repeats along V."""
    from PIL import ImageDraw
    rng = np.random.default_rng(11)
    W, H = 512, 2048

    def lines(draw, pts, w=13):
        for dy in (-H, 0, H):
            draw.line([(x, y + dy) for x, y in pts], fill=255, width=w, joint="curve")

    def ring(draw, x, y, r, w=10):
        for dy in (-H, 0, H):
            draw.ellipse([x - r, y + dy - r, x + r, y + dy + r], outline=255, width=w)

    brushed = _norm01(_blur_wrap(rng.random((512, 128)), 26, 0.6))
    for name in PATTERNS:
        im = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(im)
        for x in (30, W - 30):
            lines(d, [(x, -10), (x, H + 10)], 9)
        if name == "rule":
            for x in (W / 2 - 74, W / 2 + 74):
                lines(d, [(x, -10), (x, H + 10)], 11)
            for i in range(16):
                y = H * i / 16
                ln = 120 if i % 4 == 0 else 66
                lines(d, [(62, y), (62 + ln, y)], 10)
                lines(d, [(W - 62, y), (W - 62 - ln, y)], 10)
        elif name == "lattice":
            for i in range(-2, 10):
                y = H * i / 8
                lines(d, [(62, y), (W - 62, y + (W - 124))], 11)
                lines(d, [(W - 62, y), (62, y + (W - 124))], 11)
        elif name == "chevron":
            for i in range(8):
                y = H * i / 8
                lines(d, [(62, y + 170), (W / 2, y), (W - 62, y + 170)], 13)
                lines(d, [(150, y + 215), (W / 2, y + 96), (W - 150, y + 215)], 9)
        elif name == "feather":
            lines(d, [(W / 2, -10), (W / 2, H + 10)], 13)
            for i in range(16):
                y = H * i / 16
                lines(d, [(W / 2, y), (W - 66, y - 118)], 10)
                lines(d, [(W / 2, y), (66, y - 118)], 10)
        elif name == "circuit":
            for tr in ([(0.30, 0.0), (0.30, 0.16), (0.50, 0.25), (0.50, 0.44), (0.30, 0.53), (0.30, 1.0)],
                       [(0.72, 0.0), (0.72, 0.09), (0.84, 0.14), (0.84, 0.37)], [(0.72, 0.50), (0.72, 1.0)],
                       [(0.16, 0.64), (0.16, 0.86)], [(0.50, 0.60), (0.50, 0.90)], [(0.72, 0.50), (0.60, 0.44), (0.60, 0.33)]):
                lines(d, [(x * W, y * H) for x, y in tr], 12)
            for x, y in ((0.84, 0.37), (0.16, 0.64), (0.16, 0.86), (0.50, 0.60), (0.50, 0.90), (0.60, 0.33)):
                ring(d, x * W, y * H, 22, 12)
        elif name == "wave":
            for sgn in (-1, 1):
                lines(d, [(W / 2 + sgn * 120 * math.sin(2 * math.pi * 3 * y / H), y) for y in range(-20, H + 21, 8)], 12)
            for i in range(6):
                ring(d, W / 2, H * (i + 0.25) / 6 * 1.0 + H / 24, 20, 9)
        elif name == "meander":
            pts, x0, x1 = [], 150, W - 150
            for i in range(-1, 9):
                y = H * i / 8
                pts += [(x0, y), (x0, y + 128), (x1, y + 128), (x1, y + 256)]
            lines(d, pts[:-1] + [(x1, pts[-1][1])], 13)
            for i in range(8):
                lines(d, [(W / 2 - 40, H * i / 8 + 64), (W / 2 + 40, H * i / 8 + 64)], 9)
        elif name == "hexcell":
            r = H / 14 / math.sqrt(3)
            for i in (-1, 0, 1):
                for j in range(-1, 15):
                    cx, cy = W / 2 + 1.5 * r * i, (j + 0.5 * (i % 2)) * math.sqrt(3) * r
                    lines(d, [(cx + r * 0.92 * math.cos(math.pi / 3 * k), cy + r * 0.92 * math.sin(math.pi / 3 * k)) for k in range(7)], 9)
        dep = np.asarray(im.resize((128, 512), Image.LANCZOS), dtype=float) / 255.0
        _save("eng_%s_a" % name, _rgb((0.70 + 0.05 * (brushed - 0.5)) * (1 - 0.62 * dep), (0.975, 0.99, 1.0)))
        _save("eng_%s_n" % name, _normal_from(brushed * 0.12 - dep, 2.2))
        _save("eng_%s_orm" % name, _orm(0.54 + 0.10 * (brushed - 0.5) + 0.26 * dep, 0.9 - 0.25 * dep))


# name: (base colour factor, metallic, roughness, albedo, normal, orm, normal scale, emissive)
MATERIALS = {
    "steel": ((1, 1, 1), 1.0, 0.42, "steel_a", "steel_n", "steel_orm", 0.22, None),
    "blade": ((1, 1, 1), 1.0, 0.42, "steel_a", "steel_n", "steel_orm", 0.22, None),
    "blade_groove": ((0.6, 0.61, 0.64), 1.0, 0.5, "steel_a", "steel_n", "steel_orm", 0.5, None),
    "fuller": ((0.62, 0.63, 0.66), 1.0, 0.5, "steel_a", "steel_n", "steel_orm", 0.5, None),
    "edge": ((0.80, 0.81, 0.83), 1.0, 0.30, None, None, None, 1.0, None),
    "graphite": ((0.085, 0.09, 0.105), 0.8, 0.5, "fine_a", "fine_n", "satin_orm", 0.4, None),
    "enamel": ((0.075, 0.095, 0.135), 0.8, 0.5, "fine_a", "fine_n", "satin_orm", 0.5, None),
    "gold": ((0.95, 0.66, 0.27), 1.0, 0.45, "steel_a", "steel_n", "steel_orm", 0.5, None),
    "grip": ((0.20, 0.21, 0.24), 0.0, 0.85, "wrap_a", "wrap_n", "wrap_orm", 1.0, None),
    "grip_fine": ((0.15, 0.155, 0.175), 0.0, 0.85, "wrap_a", "wrap_n", "wrap_orm", 0.8, None),
    "leather": ((0.115, 0.095, 0.085), 0.0, 0.85, "fine_a", "fine_n", "matte_orm", 1.0, None),
    "glow": ((0.03, 0.05, 0.06), 0.0, 0.6, None, None, None, 1.0, ((0.38, 0.8, 1.0), 1.0)),
}
for _p in PATTERNS:
    MATERIALS["engrave_" + _p] = ((1, 1, 1), 1.0, 0.5, "eng_%s_a" % _p, "eng_%s_n" % _p, "eng_%s_orm" % _p, 1.0, None)
# per-item substitutions: the weathered greatsword swaps the steel set and warms the leather
VARIANT = {}


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


SHIELDS = {"shield_round": build_round, "shield_heater": build_heater, "shield_tower": build_tower}
# blade metals: a tint applied at load to the blade's own surfaces (GearModel.apply_mod); no extra files
ORES = {"steel": [1.0, 1.0, 1.0], "silver": [1.2, 1.21, 1.22], "graphite": [0.34, 0.35, 0.38],
        "bronze": [1.05, 0.78, 0.46], "frost": [0.80, 0.92, 1.08]}


def export(name, build, variant=None):
    """Builds one model at both detail levels; returns (info, stats)."""
    stats, info = {}, {}
    for q, suffix in ((1.0, ""), (0.4, "_lod")):
        B = Builder()
        res = build(B, q)
        surf = finish(B)
        path = os.path.join(OUT, name + suffix + ".glb")
        write_glb(path, name + suffix, surf, variant or {})
        allp = np.concatenate([np.array(d["pos"]) for d in surf.values()])
        if q == 1.0:
            info = dict(res)
            info["lo"] = [round(float(x), 4) for x in allp.min(axis=0)]
            info["hi"] = [round(float(x), 4) for x in allp.max(axis=0)]
            info["materials"] = [m for m in MATERIALS if m in surf]
        stats["tris" + suffix] = sum(len(d["idx"]) for d in surf.values()) // 3
        stats["verts" + suffix] = sum(len(d["pos"]) for d in surf.values())
        stats["bytes" + suffix] = os.path.getsize(path)
    return info, stats


# ============================================================================ hybrids: our blade in a generated hilt
# A hybrid is a code-built blade seated in an image-to-3D hilt (guard + grip + pommel). The generated model comes
# normalised (1 unit long, guard along Z, pommel at -Y); bake_hilt() turns it into the gear convention.
#   src      the generated GLB under gear/hilts/
#   scale    metres per model unit, chosen so the grip is a hand's thickness (about 15 mm radius)
#   y_hand   model height of the centre of the main hand: 5 cm (half a palm, at `scale`) under the guard's collar
#   seat     model height where the blade leaves the hilt (top of the socket or collar); the blade starts 13 mm inside
#   flatten  (from_y, factor): generated guards come out too deep front to back; squeeze the depth above from_y
#   P        changes to the base sword's blade so its foot is hidden by the socket
#   tint, rough_max: the blade's steel brought to the hilt's metal (measured from its textures)
HYBRIDS = {
    "wayfarer_h": dict(base="wayfarer", src="hilt_wayfarer", scale=0.255, y_hand=-0.016, seat=0.500, collar=0.18, grip=(-0.38, 0.18),
                       flatten=None, P=dict(w=[(0, 0.0212), (0.14, 0.0216), (0.50, 0.0250), (0.84, 0.0165)]),
                       tint=[0.66, 0.645, 0.62], rough_max=0.42, hands=1.5),
    "eternal_edge_h": dict(base="eternal_edge", src="hilt_eternal", scale=0.3375, y_hand=-0.088, seat=0.440, collar=0.06, grip=(-0.26, 0.06),
                           flatten=(0.05, 0.62), P={}, tint=[0.72, 0.68, 0.62], rough_max=0.42, hands=1),
}


def bake_hilt(spec, dst):
    """Rewrites a generated hilt into the gear convention (origin at the hand, +Y to the tip, guard along X,
    metres) and drops its embedded textures in favour of the files Godot already extracted beside the source."""
    d = open(os.path.join(OUT, "hilts", spec["src"] + ".glb"), "rb").read()
    jl = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + jl])
    b0 = 20 + jl + 8
    prim = j["meshes"][0]["primitives"][0]

    def read(ai, dtype, comps):
        a = j["accessors"][ai]
        bv = j["bufferViews"][a["bufferView"]]
        off = b0 + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        return np.frombuffer(d, dtype=dtype, count=a["count"] * comps, offset=off).reshape(-1, comps).copy()

    pos = read(prim["attributes"]["POSITION"], np.float32, 3)
    nrm = read(prim["attributes"]["NORMAL"], np.float32, 3)
    uv = read(prim["attributes"]["TEXCOORD_0"], np.float32, 2)
    idx = read(prim["indices"], np.uint32 if j["accessors"][prim["indices"]]["componentType"] == 5125 else np.uint16, 1).astype(np.uint32)
    depth = np.ones(len(pos))
    if spec.get("flatten"):
        y_from, k = spec["flatten"]
        t = np.clip((pos[:, 1] - y_from) / 0.06, 0, 1)
        depth = 1 - (1 - k) * t * t * (3 - 2 * t)
    sc = spec["scale"]
    out_p = np.stack([pos[:, 2], pos[:, 1] - spec["y_hand"], -pos[:, 0] * depth], axis=1) * sc
    out_n = np.stack([nrm[:, 2], nrm[:, 1], -nrm[:, 0] / depth], axis=1)
    out_n /= np.linalg.norm(out_n, axis=1)[:, None]
    buf = bytearray()
    views, accs = [], []

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

    p2 = {"attributes": {"POSITION": add(out_p.astype(np.float32), 34962, 5126, "VEC3", True), "NORMAL": add(out_n.astype(np.float32), 34962, 5126, "VEC3"),
                         "TEXCOORD_0": add(uv, 34962, 5126, "VEC2")}, "indices": add(idx.reshape(-1), 34963, 5125, "SCALAR"), "material": 0}
    mat = dict(j["materials"][0])
    mat["name"] = "hilt"
    images = []
    for im in j["images"]:
        ext = ".png" if im.get("mimeType") == "image/png" else ".jpg"
        images.append({"uri": "hilts/%s_%s%s" % (spec["src"], im["name"], ext)})
    name = os.path.basename(dst)[:-4]
    g = {"asset": {"version": "2.0", "generator": "hollow-reign gear_gen (baked hilt)"}, "scene": 0, "scenes": [{"nodes": [0]}],
         "nodes": [{"name": name, "mesh": 0}], "meshes": [{"name": name, "primitives": [p2]}], "materials": [mat],
         "textures": j["textures"], "images": images, "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
         "buffers": [{"byteLength": len(buf)}], "bufferViews": views, "accessors": accs}
    for t in g["textures"]:
        t["sampler"] = 0
    while len(buf) % 4:
        buf.append(0)
    js = json.dumps(g, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    with open(dst, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(buf)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A))
        f.write(js)
        f.write(struct.pack("<II", len(buf), 0x004E4942))
        f.write(buf)
    return {"tris": len(idx) // 3, "verts": len(out_p), "bytes": os.path.getsize(dst), "lo": out_p.min(axis=0), "hi": out_p.max(axis=0), "pos": out_p}


def build_hybrids(manifest):
    for hid, spec in HYBRIDS.items():
        base = spec["base"]
        sc, yh = spec["scale"], spec["y_hand"]
        y0 = (spec["seat"] - yh) * sc - 0.013
        P = dict(spec["P"], y0=round(y0, 4))
        hilt = bake_hilt(spec, os.path.join(OUT, hid + "__hilt0.glb"))
        parts = {"hilt0": {k: hilt[k] for k in ("tris", "verts", "bytes")}}
        info = {}
        for t in range(4):
            info_t, st = export("%s__blade%d" % (hid, t), lambda B, q: SWORDS[base](B, q, {"blade_tier": t, "grip_tier": 0, "P": P}, ("blade",)))
            parts["blade%d" % t] = st
            info = info_t if t == DEFAULT_MOD[base][0] else info
        # <id>.glb must exist for GearModel.exists(): it is the default blade alone; spawn() always joins the parts
        bt = DEFAULT_MOD[base][0]
        _, st = export(hid, lambda B, q: SWORDS[base](B, q, {"blade_tier": bt, "grip_tier": 0, "P": P}, ("blade",)))
        g0, g1 = [(y - yh) * sc for y in spec["grip"]]
        # optional ring overlays for the handle tiers a generated grip cannot change itself
        pos = hilt["pos"]
        for tier, ys in ((2, (0.3, 0.7)), (3, (0.2, 0.4, 0.6, 0.8))):
            def rings(B, q, ys=ys):
                for u in ys:
                    y = g0 + (g1 - g0) * u
                    near = pos[np.argsort(np.abs(pos[:, 1] - y))[:16]]
                    rx = float(np.abs(near[:, 0]).max()) + 0.0012
                    rz = float(np.abs(near[:, 2]).max()) + 0.0012
                    collar(B, y - 0.0016, y + 0.0016, rx, rz, "gold", 12 if q >= 1 else 6, 0.0008)
                return {}
            _, st = export("%s__rings%d" % (hid, tier), rings)
            parts["rings%d" % tier] = st
        blade_stats = parts["blade%d" % bt]
        info.update({"name": manifest.get(base, {}).get("name", base) + " (hybrid)", "hybrid": True, "base": base, "hilt_source": "hilts/%s.glb" % spec["src"],
                     "tris": blade_stats["tris"] + hilt["tris"], "tris_lod": blade_stats["tris_lod"] + hilt["tris"], "verts": blade_stats["verts"] + hilt["verts"],
                     "bytes": blade_stats["bytes"] + hilt["bytes"], "parts": parts,
                     "tip": round(y0 + info["blade"], 4), "pommel": round(-float(hilt["lo"][1]), 4), "grip_clear": round(g1 - g0, 4),
                     "guard_span": round(float(hilt["hi"][0] - hilt["lo"][0]), 4), "hands": spec["hands"],
                     "lo": [round(float(min(hilt["lo"][i], info["lo"][i])), 4) for i in range(3)],
                     "hi": [round(float(max(hilt["hi"][i], info["hi"][i])), 4) for i in range(3)],
                     "materials": info["materials"] + ["hilt"], "blade_tint": spec["tint"], "blade_rough_max": spec["rough_max"],
                     "default_mod": {"blade_tier": bt, "grip_tier": 0, "ore": "steel", "sharpened": True}, "rig_scale": 1.15})
        manifest[hid] = info
        print("%-14s blade %d + hilt %d tris, hilt %.0f kB (+ %d kB shared textures), grip %.3f m, guard %.3f m, tip %.3f" % (
            hid, blade_stats["tris"], hilt["tris"], hilt["bytes"] / 1024,
            sum(os.path.getsize(os.path.join(OUT, "hilts", f)) for f in os.listdir(os.path.join(OUT, "hilts")) if f.startswith(spec["src"] + "_") and not f.endswith(".import")) // 1024,
            g1 - g0, info["guard_span"], info["tip"]))


def main():
    os.makedirs(OUT, exist_ok=True)
    if sys.argv[1:] == ["--hybrids"]:
        mpath = os.path.join(OUT, "gear_manifest.json")
        manifest = json.load(open(mpath))
        build_hybrids(manifest)
        json.dump(manifest, open(mpath, "w"), indent=1)
        return
    want = sys.argv[1:] or (list(SWORDS) + list(SHIELDS))
    textures()
    engrave_textures()
    mpath = os.path.join(OUT, "gear_manifest.json")
    old = json.load(open(mpath)) if os.path.exists(mpath) else {}
    manifest = {k: old[k] for k in ["_mods"] + list(SWORDS) + list(SHIELDS) + list(HYBRIDS) if k in old}
    manifest["_mods"] = {
        "ores": ORES, "blade_tiers": 4, "grip_tiers": 4,
        "naming": "<id>.glb is the sword at default_mod. Basic swords also have <id>__blade<0-3>.glb and <id>__hilt<0-3>.glb "
                  "(each with _lod): GearModel.spawn(id, lod_at, false, {blade_tier, grip_tier, ore, sharpened}) joins one of each. "
                  "ore and sharpened are material-only and need no files."}
    for item in want:
        if item in SWORDS:
            bt, gt = DEFAULT_MOD[item]
            mod = {"blade_tier": bt, "grip_tier": gt}
            info, stats = export(item, lambda B, q: SWORDS[item](B, q, mod, ("blade", "hilt")))
            info.update(stats)
            info["default_mod"] = {"blade_tier": bt, "grip_tier": gt, "ore": "steel", "sharpened": True}
            if item in BASIC:
                parts = {}
                for t in range(4):
                    _, st = export("%s__blade%d" % (item, t), lambda B, q: SWORDS[item](B, q, {"blade_tier": t, "grip_tier": 0}, ("blade",)))
                    parts["blade%d" % t] = st
                    _, st = export("%s__hilt%d" % (item, t), lambda B, q: SWORDS[item](B, q, {"blade_tier": 0, "grip_tier": t}, ("hilt",)))
                    parts["hilt%d" % t] = st
                info["parts"] = parts
        else:
            info, stats = export(item, SHIELDS[item])
            info.update(stats)
        info["rig_scale"] = 1.15      # the knights are heroic figures: the rig draws gear 15% over life size
        manifest[item] = info
        print("%-14s tris %5d / %4d  verts %5d  surfaces %d  %6.1f kB" % (item, info["tris"], info["tris_lod"], info["verts"], len(info["materials"]), info["bytes"] / 1024))
    json.dump(manifest, open(mpath, "w"), indent=1)


if __name__ == "__main__":
    main()
