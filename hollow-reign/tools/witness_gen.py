#!/usr/bin/env python3
"""The Witness: a small floating instrument, built from parameters like the swords (see tools/gear_gen.py and
docs/CHARACTER_BIBLE.md, "The Witness"). No Blender, no generation service.

    python3 tools/witness_gen.py          # every variant, both detail levels, manifest

Writes assets/models/witness/<variant>_<part>[_lod].glb and witness_manifest.json. The parts are separate files
because they move against each other (src/chars/witness_drone.gd):
    shell_a   the half of the body that stays put
    shell_b   the half that parts from it along `open_axis` when it is attentive (the seam widens)
    light     what shows in the seam: the only lit surface on the body
    ring      the halo: it floats free, tilts and turns to what the Witness looks at; its front (-Z) carries a
              short lit dash, the same light as the seam
    fin       one vane (variant "plumb" only); the manifest lists where the three hang on shell_b
Conventions: metres, life size; +Y up; the FRONT is -Z; the origin is the centre of the seam.
Surfaces: "ceramic" (matte pale shell), "alloy" (brushed caps, ring, vanes), "seam" (dark inner lip), "light".
The three variants exist so they can be judged side by side (`pose_review.gd --drone`); the game loads CHOSEN.
"""
import json, math, os, struct, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gear_gen as G

OUT = os.path.join(G.ROOT, "assets", "models", "witness")
CHOSEN = "gnomon"

G.MATERIALS.update({
    "ceramic": ((0.80, 0.785, 0.75), 0.0, 0.62, None, "fine_n", None, 0.18, None),
    "alloy": ((0.80, 0.81, 0.84), 0.62, 0.40, "steel_a", "steel_n", "steel_orm", 0.3, None),
    "seam": ((0.07, 0.075, 0.085), 0.6, 0.55, None, None, None, 1.0, None),
    "light": ((1.0, 0.93, 0.82), 0.0, 0.5, None, None, None, 1.0, ((1.0, 0.80, 0.50), 1.6)),
    # second pass: flat satin panels over a graphite core, a gloss-black insert that carries the light, gold caps
    "panel": ((0.88, 0.87, 0.84), 0.0, 0.42, None, "fine_n", None, 0.12, None),
    "core": ((0.055, 0.058, 0.066), 0.5, 0.55, None, None, None, 1.0, None),
    "glass": ((0.012, 0.014, 0.018), 0.0, 0.07, None, None, None, 1.0, None),
    "accent": ((0.86, 0.62, 0.28), 1.0, 0.36, "steel_a", "steel_n", "steel_orm", 0.3, None),
    # third pass: an old instrument. Pitted pale plates that have lost their glaze, dark bronze gone brown, a few
    # fittings turned green; nothing polished, nothing gold
    # (their textures are this tool's own: assets/models/witness/tex/, written by relic_textures())
    "bone": ((0.92, 0.89, 0.82), 0.0, 1.0, "relic_bone_a", "relic_bone_n", "relic_bone_orm", 1.0, None),
    "bronze": ((1.0, 1.0, 1.0), 1.0, 1.0, "relic_bronze_a", "relic_bone_n", "relic_bronze_orm", 0.8, None),
    "verdigris": ((0.36, 0.62, 0.55), 0.0, 1.0, "relic_bone_a", "relic_bone_n", "relic_bone_orm", 1.0, None),
})


def relic_textures():
    """The gnomon's own surfaces, tiling, 256 px (one tile covers 6.25 cm): an unglazed pale ceramic that has
    pitted, stained in the hollows and crazed; and a bronze gone brown with green in its low places."""
    from PIL import Image
    rng = np.random.default_rng(31)
    S = 256
    out = os.path.join(OUT, "tex")
    os.makedirs(out, exist_ok=True)

    def save(name, arr):
        Image.fromarray(arr).save(os.path.join(out, name + ".png"), optimize=True)
    blur, n01 = G._blur_wrap, G._norm01
    grain = n01(blur(rng.random((S, S)), 1.1, 1.1))
    mott = n01(blur(rng.random((S, S)), 22, 22))
    stain = np.clip((n01(blur(rng.random((S, S)), 12, 9) + 0.5 * blur(rng.random((S, S)), 4, 4)) - 0.52) * 3.0, 0, 1)
    pits = np.clip((n01(blur(rng.random((S, S)), 2.2, 2.2)) - 0.74) * 5, 0, 1)
    # crazing: the thin ridges where two smooth noise fields cross their middle
    c1, c2 = n01(blur(rng.random((S, S)), 9, 9)), n01(blur(rng.random((S, S)), 7, 7))
    crack = np.clip(1.0 - np.minimum(np.abs(c1 - 0.5), np.abs(c2 - 0.5)) * 70, 0, 1) * 0.5
    scr = np.clip((n01(blur(rng.random((S, S)), 0.7, 9)) - 0.9) * 10, 0, 1) * 0.5
    val = 0.84 + 0.07 * (mott - 0.5) + 0.04 * (grain - 0.5) - 0.30 * stain - 0.22 * pits - 0.30 * crack + 0.05 * scr
    warm = 0.10 * stain + 0.05 * crack
    save("relic_bone_a", (np.clip(np.stack([val * (1.0 + warm * 0.3), val * (1.0 - warm * 0.3), val * (1.0 - warm * 1.3)], axis=-1), 0, 1) * 255).astype(np.uint8))
    save("relic_bone_n", G._normal_from(n01(grain * 0.25 - pits * 0.9 - crack * 0.8 - scr * 0.3 + mott * 0.2), 1.8))
    save("relic_bone_orm", G._orm(0.86 + 0.08 * (grain - 0.5) + 0.08 * stain - 0.10 * scr, 0.0))
    # bronze: brown metal, darker and rougher where the green sits
    green = np.clip((n01(blur(rng.random((S, S)), 10, 10) + 0.6 * blur(rng.random((S, S)), 3, 3)) - 0.55) * 3.2, 0, 1)
    b = 0.36 + 0.10 * (mott - 0.5) + 0.06 * (grain - 0.5) - 0.10 * pits
    rgb = np.stack([b * 1.18, b * 0.86, b * 0.56], axis=-1)
    gcol = np.stack([0.22 + 0.1 * grain, 0.40 + 0.1 * grain, 0.34 + 0.1 * grain], axis=-1)
    rgb = rgb * (1 - green[..., None] * 0.8) + gcol * green[..., None] * 0.8
    save("relic_bronze_a", (np.clip(rgb, 0, 1) * 255).astype(np.uint8))
    save("relic_bronze_orm", G._orm(0.60 + 0.10 * (grain - 0.5) + 0.30 * green + 0.1 * pits, 0.85 - 0.8 * green))


def seg_for(q, n):
    return max(6, int(round(n * (0.55 if q < 1.0 else 1.0) / 2)) * 2)


def band(B, radius, half_w, half_h, seg, mat, dash=0.0, y=0.0):
    """A flat halo: a rectangular section (radial half_w, vertical half_h) swept round Y.
    `dash` is the angle (radians) of the outer face, centred on the front (-Z), that is lit."""
    sec = [(radius + half_w, -half_h), (radius + half_w, half_h), (radius - half_w, half_h), (radius - half_w, -half_h)]
    sec.append(sec[0])
    rings = []
    for r, yy in sec:
        # column 0 sits half a step off the front so the dash is symmetric about -Z
        rings.append([(r * math.sin(2 * math.pi * (i - 0.5) / seg), y + yy, -r * math.cos(2 * math.pi * (i - 0.5) / seg)) for i in range(seg)])
    n_dash = int(round(dash / (2 * math.pi) * seg / 2)) * 2 if dash > 0 else 0
    lit = set(range(0, n_dash // 2)) | set(range(seg - n_dash // 2, seg))
    mats = [[("light" if (r == 0 and cc in lit) else mat) for cc in range(seg)] for r in range(len(sec) - 1)]
    B.part()
    G.loft(B, rings, mats, gv=list(range(len(sec) - 1)), smooth_u=True, cap0=False, cap1=False, uv="cyl", urep=8.0)
    B.close()


def turned(B, prof, mats, seg, hard=()):
    B.part()
    G.lathe(B, prof, mats, seg=seg, hard=hard, uv="cyl", urep=4.0)
    B.close()


# ---------------------------------------------------------------------------- A: the plumb
# A turned teardrop hung point down, like the bob of a plumb line: the oldest instrument for finding true.
# It parts at its widest; three vanes lie along the taper and lift when it attends.
PLUMB_SEAM = 0.0026          # half the height of the seam at rest
PLUMB_R = 0.0225


def plumb_shell_a(B, q):
    s = seg_for(q, 20)
    y0 = PLUMB_SEAM
    prof = [(y0, 0.0001), (y0, 0.0185), (y0, 0.0212), (y0 + 0.0022, PLUMB_R), (0.015, 0.0226), (0.027, 0.0202), (0.037, 0.0160), (0.0455, 0.0106),
            (0.0455, 0.0086), (0.0500, 0.0086), (0.0518, 0.0070), (0.0518, 0.0001)]
    mats = ["seam", "seam", "ceramic", "ceramic", "ceramic", "ceramic", "ceramic", "alloy", "alloy", "alloy", "alloy"]
    if q < 1.0:
        prof = [prof[i] for i in (0, 2, 3, 5, 7, 8, 9, 10, 11)]
        mats = ["seam", "ceramic", "ceramic", "ceramic", "alloy", "alloy", "alloy", "alloy"]
        turned(B, prof, mats, s, hard=(1, 3, 4, 5, 6, 7))
    else:
        turned(B, prof, mats, s, hard=(1, 2, 7, 8, 9, 10))


def plumb_shell_b(B, q):
    s = seg_for(q, 20)
    y0 = -PLUMB_SEAM
    prof = [(-0.0840, 0.0001), (-0.0700, 0.0040), (-0.0655, 0.0052), (-0.0655, 0.0046), (-0.0480, 0.0098), (-0.0300, 0.0152), (-0.0140, 0.0196),
            (y0 - 0.0022, 0.0218), (y0, 0.0206), (y0, 0.0185), (y0, 0.0001)]
    mats = ["alloy", "alloy", "alloy", "ceramic", "ceramic", "ceramic", "ceramic", "ceramic", "seam", "seam"]
    if q < 1.0:
        prof = [prof[i] for i in (0, 2, 3, 5, 7, 8, 10)]
        mats = ["alloy", "alloy", "ceramic", "ceramic", "ceramic", "seam"]
        turned(B, prof, mats, s, hard=(1, 2, 4, 5))
    else:
        turned(B, prof, mats, s, hard=(1, 2, 3, 7, 8, 9))


def plumb_light(B, q):
    s = seg_for(q, 20)
    turned(B, [(-0.0125, 0.0172), (0.0035, 0.0172)], "light", s)


def plumb_ring(B, q):
    band(B, 0.0530, 0.0011, 0.0030, seg_for(q, 36), "alloy", dash=math.radians(40))


def plumb_fin(B, q):
    """One vane, hinge at the origin, lying down -Y, its outer face toward -Z (the drone turns it to its place)."""
    L, w0, w1, t = 0.0400, 0.0042, 0.0016, 0.0013
    rings = []
    for y, w, c in ((0.0, w0 * 0.7, 0.0), (-0.004, w0, 0.0), (-L * 0.55, (w0 + w1) * 0.5, 0.0), (-L, w1, 0.0)):
        rings.append([(-w, y, -t), (w, y, -t), (w, y, 0.0), (-w, y, 0.0)])
    B.part()
    G.loft(B, rings, "alloy", smooth_u=False, smooth_v=True, grain=1)
    B.close()


# ---------------------------------------------------------------------------- B: the reed
# A tall narrow lozenge split down its length: two half shells with the light standing between them.
REED_H, REED_RX, REED_RZ = 0.070, 0.0200, 0.0125


def _reed_half(B, q, sign):
    n_y = 7 if q < 1.0 else 13
    n_a = 4 if q < 1.0 else 8
    gap = 0.0016
    rings = []
    for i in range(n_y):
        v = -1.0 + 2.0 * i / (n_y - 1)
        y = REED_H * math.sin(v * math.pi / 2)
        k = max(0.02, (1.0 - abs(math.sin(v * math.pi / 2)) ** 2.6) ** 0.62)
        pts = [(sign * gap, y, -REED_RZ * k * 0.86)]
        for a in range(n_a + 1):
            t = -math.pi / 2 + math.pi * a / n_a
            pts.append((sign * (gap + REED_RX * k * math.cos(t)), y, REED_RZ * k * math.sin(t)))
        pts.append((sign * gap, y, REED_RZ * k * 0.86))
        rings.append(pts)
    n = len(rings[0])
    mats = [[("seam" if c == n - 1 else "ceramic") for c in range(n)] for _ in range(n_y - 1)]
    gu = [1] + [0] * (n - 2) + [2]
    B.part()
    G.loft(B, rings, mats, gu=gu, smooth_v=True, uv="box")
    B.close()


def reed_shell_a(B, q):
    _reed_half(B, q, -1.0)


def reed_shell_b(B, q):
    _reed_half(B, q, 1.0)


def reed_light(B, q):
    n_y = 5 if q < 1.0 else 9
    rings = []
    for i in range(n_y):
        v = -1.0 + 2.0 * i / (n_y - 1)
        y = REED_H * 0.93 * math.sin(v * math.pi / 2)
        k = max(0.02, (1.0 - abs(math.sin(v * math.pi / 2)) ** 2.6) ** 0.62)
        z = REED_RZ * k * 0.80
        rings.append([(-0.0042, y, -z), (0.0042, y, -z), (0.0042, y, z), (-0.0042, y, z)])
    B.part()
    G.loft(B, rings, "light", smooth_u=False, smooth_v=True)
    B.close()


def reed_ring(B, q):
    band(B, 0.0420, 0.0011, 0.0028, seg_for(q, 36), "alloy", dash=math.radians(40))


# ---------------------------------------------------------------------------- C: the lens
# A flat turned disc parted at its rim, with a wide halo: the widest and lowest of the three.
def lens_shell_a(B, q):
    s = seg_for(q, 24)
    y0 = 0.0022
    turned(B, [(y0, 0.0001), (y0, 0.036), (y0, 0.0400), (y0 + 0.002, 0.0415), (0.010, 0.036), (0.0155, 0.024), (0.0175, 0.012),
               (0.0175, 0.0125), (0.0205, 0.0115), (0.0205, 0.0001)],
           ["seam", "seam", "ceramic", "ceramic", "ceramic", "ceramic", "alloy", "alloy", "alloy"], s, hard=(1, 2, 6, 7, 8))


def lens_shell_b(B, q):
    s = seg_for(q, 24)
    y0 = -0.0022
    turned(B, [(-0.0260, 0.0001), (-0.0240, 0.0070), (-0.0190, 0.0090), (-0.0190, 0.0085), (-0.0150, 0.022), (-0.0095, 0.035), (y0 - 0.002, 0.0412),
               (y0, 0.0400), (y0, 0.036), (y0, 0.0001)],
           ["alloy", "alloy", "alloy", "ceramic", "ceramic", "ceramic", "ceramic", "seam", "seam"], s, hard=(1, 2, 3, 6, 7, 8))


def lens_light(B, q):
    turned(B, [(-0.0110, 0.0335), (0.0030, 0.0335)], "light", seg_for(q, 24))


def lens_ring(B, q):
    band(B, 0.0600, 0.0011, 0.0028, seg_for(q, 44), "alloy", dash=math.radians(30))


# ============================================================================ second pass: faceted panels
# The owner's note on the plumb: too plain (a white spinning top) and too small. What is wanted is the feel of a
# manufactured product: flat white panels with crisp bevels, dark seams showing a graphite core, a gloss-black
# insert carrying the light, a couple of gold caps, and panels that MOVE. Three silhouettes, all our own.
def _inset(q, d, n):
    """A convex planar polygon (3D points) pulled in by d on every side."""
    out = []
    N = len(q)
    for i in range(N):
        a, b, c = q[i - 1], q[i], q[(i + 1) % N]
        e1, e2 = b - a, c - b
        n1 = np.cross(n, e1)
        n2 = np.cross(n, e2)
        n1 /= np.linalg.norm(n1) + 1e-12
        n2 /= np.linalg.norm(n2) + 1e-12
        out.append(b + d * (n1 + n2) / (1.0 + float(np.dot(n1, n2)) + 1e-9))
    return np.array(out)


def slab(B, quad, mat, gap=0.0022, thick=0.0055, bev=0.0013, q=1.0, away=(0.0, 0.0, 0.0), lift=0.0, top=None):
    """One flat panel: the polygon `quad` (3D, any winding) pulled in by `gap`, raised `thick` along its normal
    (the side away from the point `away`), with its upper rim bevelled. `lift` starts it above its own plane."""
    P = np.array(quad, dtype=float)
    c = P.mean(axis=0)
    n = np.zeros(3)
    for i in range(len(P)):
        n += np.cross(P[i] - c, P[(i + 1) % len(P)] - c)
    n /= np.linalg.norm(n)
    if np.dot(n, c - np.array(away)) < 0:
        P = P[::-1]
        n = -n
    base = _inset(P, gap, n)
    rings = [base + n * lift, base + n * (lift + thick - bev), _inset(P, gap + bev, n) + n * (lift + thick)]
    if q < 1.0:
        rings = [rings[0], rings[2]]
    R, N = len(rings), len(P)
    mats = [[mat] * N for _ in range(R - 1)]
    # wound round n and rising along it, the loft already faces out: no orientation pass (the low model is open-backed)
    B.part()
    G.loft(B, rings, mats, smooth_u=False, smooth_v=False, cap0=q >= 1.0, cap1=True, cap_mat=top or mat)


def solid(B, rings, mat, cap_mat=None):
    B.part()
    G.loft(B, rings, mat, smooth_u=False, smooth_v=False, cap_mat=cap_mat)
    B.close()


# ---------------------------------------------------------------------------- D: the lantern (chosen)
# A cut-gem body of flat panels, wider than it is deep, leaning forward: the crown is swept back and the keel runs
# down to a forward point, so from the side it is a slanted lozenge and from the front a keystone. A gloss-black
# visor band runs round its waist with one horizontal bar of light on the front and a short one at the back.
# The crown lifts, the keel drops and the two cheek panels slide out when it attends; a line of light shows in the
# seam the crown leaves. Nothing radial, no centre: the focal point is the bar.
#            y       half x  half z  corner  z shift
LAN = [(0.060, 0.052, 0.034, 0.016, 0.020),      # top
       (0.034, 0.098, 0.064, 0.030, 0.010),      # shoulder
       (0.011, 0.110, 0.072, 0.034, 0.000),      # visor, upper edge
       (-0.011, 0.107, 0.070, 0.033, -0.003),    # visor, lower edge
       (-0.044, 0.072, 0.048, 0.022, -0.014),    # belly
       (-0.074, 0.030, 0.020, 0.009, -0.026)]    # foot
FRONT, BACK, RIGHT, LEFT = 6, 2, 0, 4             # facet numbers of chamfer_rect (corners are the odd ones)


def lan_ring(i, k=1.0):
    y, hx, hz, c, dz = LAN[i]
    return [np.array((x * k, y, z * k + dz)) for x, z in G.chamfer_rect(hx, hz, c)]


def lan_facet(i, f):
    a, b = lan_ring(i), lan_ring(i + 1)
    return [a[f], a[(f + 1) % 8], b[(f + 1) % 8], b[f]]


def lantern_core(B, q):
    """What shows in the seams: the graphite body just inside the panels, the line of light under the crown's
    lower edge, and the two gold caps."""
    solid(B, [lan_ring(i, 0.955) for i in range(6)], "core")
    y = LAN[2][0]
    solid(B, [[p + np.array((0, dy, 0)) for p in lan_ring(2, 0.975)] for dy in (0.0008, 0.0050)], "light", cap_mat="core")
    # caps: a low gold tablet on the crown's flat, a gold shoe on the point
    t = lan_ring(0, 0.62)
    solid(B, [[p + np.array((0, dy, 0)) for p in (t if dy < 0.008 else lan_ring(0, 0.5))] for dy in (0.002, 0.0075, 0.0095)], "accent")
    lo = lan_ring(5, 0.9)
    solid(B, [[p + np.array((0, dy, 0)) * 1.0 for p in (lo if k == 1 else lan_ring(5, 0.9 * k))] for dy, k in ((0.001, 1), (-0.0065, 1), (-0.0085, 0.8))], "accent")


def lantern_crown(B, q):
    for row in (0, 1):
        for f in range(8):
            slab(B, lan_facet(row, f), "panel", q=q)
    slab(B, lan_ring(0)[::-1], "accent", q=q, gap=0.0034, thick=0.0034)      # the crown's flat is its gold cap


def lantern_keel(B, q):
    for row in (3, 4):
        for f in range(8):
            slab(B, lan_facet(row, f), "panel", q=q)


def lantern_cheek(B, q):
    """The right cheek (the left is the same part mirrored by the drone): the side panel of the visor band and
    the corner behind it."""
    slab(B, lan_facet(2, RIGHT), "panel", q=q, thick=0.0070)
    slab(B, lan_facet(2, 1), "panel", q=q, thick=0.0070)


def lantern_visor(B, q):
    """The gloss insert across the front and its two corners, the bar of light on it, and the short bar behind."""
    for f in (5, FRONT, 7, BACK):
        slab(B, lan_facet(2, f), "glass", q=q, gap=0.0006, thick=0.0034, bev=0.0006)
    # the bar is NOT centred: it starts left of the middle of the front and runs round the right front corner, so
    # the thing has a side it looks from, like the index of an instrument, and nothing about it is a pair of eyes
    def bar(f, t0, t1, hh=0.0045):
        a = lan_facet(2, f)
        l0, l1 = (a[0] + a[3]) / 2, (a[1] + a[2]) / 2
        v = np.array((0.0, 1.0, 0.0))
        p0, p1 = l0 + (l1 - l0) * t0, l0 + (l1 - l0) * t1
        slab(B, [p0 - v * hh, p1 - v * hh, p1 + v * hh, p0 + v * hh], "light", q=q, gap=0.0, thick=0.0010, bev=0.0003, lift=0.0034)
    bar(FRONT, 0.10, 0.62)
    bar(7, 0.0, 0.82)
    bar(BACK, 0.34, 0.66)


# ---------------------------------------------------------------------------- E: the dart
# Three overlapping plates in an arrowhead, a bar of light under the leading edge. Fast and flat.
def dart_core(B, q):
    solid(B, [[np.array(p) for p in ((x * k, y, z) for x, z in ((0.0, -0.085), (0.026, 0.0), (0.014, 0.07), (-0.014, 0.07), (-0.026, 0.0)))]
              for y, k in ((-0.016, 0.6), (-0.004, 1.0), (0.008, 1.0))], "core")
    solid(B, [[np.array((x, y, z)) for x, z in ((-0.030, -0.064), (0.030, -0.064), (0.036, -0.056), (-0.036, -0.056))] for y in (-0.008, -0.002)], "light")
    solid(B, [[np.array((x, y, z)) for x, z in ((-0.012, 0.070), (0.012, 0.070), (0.012, 0.075), (-0.012, 0.075))] for y in (-0.006, 0.006)], "light")
    solid(B, [[np.array((x * k, y, -0.086 - 0.012 * (1 - k))) for x in (-0.006, 0.006)] + [np.array((0.0, y, -0.100))] for y, k in ((-0.004, 1.0), (0.002, 1.0))], "accent")


def dart_top(B, q):
    slab(B, [(0.0, 0.010, -0.098), (0.048, 0.010, 0.012), (0.0, 0.010, 0.066), (-0.048, 0.010, 0.012)], "panel", q=q, thick=0.0055, away=(0, -1, 0))


def dart_wing(B, q):
    """The right wing, hinged along its inner edge (the drone mirrors it for the left)."""
    slab(B, [(0.0, 0.0, -0.062), (0.088, -0.030, 0.062), (0.074, -0.026, 0.094), (0.004, 0.0, 0.040)], "panel", q=q, thick=0.0050, away=(0.04, -1, 0))


# ---------------------------------------------------------------------------- F: the hexring
# Six wedge segments standing in a ring that faces what it looks at, round a small graphite core; the light is the
# gap between core and ring.
def hex_core(B, q):
    solid(B, [[np.array((0.026 * math.cos(math.radians(60 * i)), 0.026 * math.sin(math.radians(60 * i)), z)) for i in range(6)] for z in (-0.020, 0.020)], "core")
    solid(B, [[np.array((r * math.cos(math.radians(60 * i)), r * math.sin(math.radians(60 * i)), z)) for i in range(6)] for z, r in ((-0.004, 0.047), (0.004, 0.047))], "light")
    solid(B, [[np.array((r * math.cos(math.radians(60 * i)), r * math.sin(math.radians(60 * i)), z)) for i in range(6)] for z, r in ((-0.0235, 0.012), (-0.020, 0.016))], "accent")


def hex_seg(B, q):
    """One segment, at the top of the ring; the drone turns five more into place."""
    r0, r1, zh = 0.056, 0.104, 0.017
    pts = [np.array((r * math.sin(a), r * math.cos(a), 0.0)) for r, a in ((r0, -math.pi / 6), (r1, -math.pi / 6), (r1, math.pi / 6), (r0, math.pi / 6))]
    slab(B, [p + np.array((0, 0, -zh + 0.004)) for p in pts], "panel", q=q, gap=0.0030, thick=0.0040, away=(0, 0.08, 0))
    slab(B, [p + np.array((0, 0, zh - 0.004)) for p in pts], "panel", q=q, gap=0.0030, thick=0.0040, away=(0, 0.08, 0))
    solid(B, [[p * k + np.array((0, 0.08 * (1 - k), z)) for p in pts] for z, k in ((-zh + 0.004, 0.93), (zh - 0.004, 0.93))], "core")



# ============================================================================ third pass: the gnomon (chosen)
# The owner's note on the lantern: it reads as a smart speaker, and it is too small in a fight. Wanted: an ancient,
# weathered, slightly lopsided relic-machine, upright and angular, half as large again, with a brighter light that
# turns to look. The gnomon is the upright blade of a sundial: the instrument that tells the truth by where the
# light falls. A tall shard of dark bronze, six-sided and never symmetric, its top cut on a slant; pale pitted plates
# cover most of it and some are chipped or gone. A hooded lamp is carried off-centre on its front ridge and turns by
# itself to what the Witness looks at: one flat five-sided pane of light. A tall vane stands off its left side and
# the snapped stub of its twin off the right; a small weight hangs free under its point.
# Nothing here is a shell round an eye: the body is a blade, the light is a lamp on its front, and nothing splits.
#          y       left x  right x  front z  back z  z shift  slant (y per x)
GN = [(0.150, 0.030, 0.038, 0.030, 0.022, 0.006, 0.55),
      (0.072, 0.052, 0.062, 0.048, 0.034, 0.002, 0.0),
      (0.000, 0.058, 0.066, 0.054, 0.038, 0.000, 0.0),
      (-0.078, 0.038, 0.044, 0.040, 0.027, -0.006, 0.0),
      (-0.150, 0.012, 0.015, 0.016, 0.010, -0.014, 0.0)]
GN_LAMP = (0.010, 0.040, -0.046)       # where the lamp turns (the manifest places it)


def gn_ring(i, k=1.0, dy=0.0):
    y, xl, xr, zf, zb, dz, sl = GN[i]
    pts = [(0.005, -zf), (xr, -0.25 * zf), (0.70 * xr, zb), (-0.006, 1.14 * zb), (-0.70 * xl, zb), (-xl, -0.25 * zf)]
    return [np.array((x * k, y + sl * x + dy, z * k + dz)) for x, z in pts]


def gn_facet(i, f):
    a, b = gn_ring(i), gn_ring(i + 1)
    return [a[f], a[(f + 1) % 6], b[(f + 1) % 6], b[f]]


def chip(quad, corner, along=0.3, down=0.35):
    """The facet with one corner broken off: a five-sided plate."""
    q = [np.array(p, dtype=float) for p in quad]
    a, b, c = q[corner - 1], q[corner], q[(corner + 1) % 4]
    out = q[:corner] + [b + (a - b) * along, b + (c - b) * down] + q[corner + 1:]
    return out


def gn_plates(B, q, cells):
    """cells: (row, facet, thickness, chipped corner or None). Old plates are not all one thickness."""
    for row, f, thick, ch in cells:
        quad = gn_facet(row, f)
        if ch is not None:
            quad = chip(quad, ch)
        slab(B, quad, "bone", q=q, gap=0.0030, thick=thick, bev=0.0016, away=(0.0, GN[row][0] * 0.5 + GN[row + 1][0] * 0.5, 0.0))


def gnomon_core(B, q):
    """The bronze shard itself, the line of light under the brow plates, the lit rule down its back, and the dark
    socket the lamp sits in."""
    solid(B, [gn_ring(i, 0.93) for i in range(5)], "bronze", cap_mat="bronze")
    solid(B, [gn_ring(1, 0.975, dy) for dy in (-0.0030, 0.0022)], "light", cap_mat="core")
    # the back, left of the ridge, has lost its plate: a dark recess with one upright rule of light (what the duel
    # camera sees of where it faces)
    a = gn_facet(1, 3)
    slab(B, a, "core", q=q, gap=0.0040, thick=0.0020, bev=0.0005, away=(0, 0.036, 0))
    m0, m1 = (a[0] * 0.62 + a[1] * 0.38), (a[3] * 0.62 + a[2] * 0.38)
    w = (a[1] - a[0]) / np.linalg.norm(a[1] - a[0]) * 0.0042
    p0, p1 = m0 + (m1 - m0) * 0.16, m0 + (m1 - m0) * 0.84
    slab(B, [p0 - w, p0 + w, p1 + w, p1 - w], "light", q=q, gap=0.0, thick=0.0012, bev=0.0003, lift=0.0020, away=(0, 0.036, 0))
    # the socket: the two front facets behind the lamp
    for f in (0, 5):
        slab(B, gn_facet(1, f), "core", q=q, gap=0.0040, thick=0.0022, bev=0.0005, away=(0, 0.036, 0))
    # a green collar where the point narrows, and a cap on the slanted top
    solid(B, [gn_ring(3, 1.06, dy) for dy in (-0.004, 0.005)], "verdigris")
    slab(B, gn_ring(0)[::-1], "bronze", q=q, gap=0.0050, thick=0.0050, bev=0.0015, away=(0, 0.0, 0))


def gnomon_brow(B, q):
    """The plates of the slanted head: they lift when it attends. One is chipped."""
    gn_plates(B, q, [(0, 0, 0.0075, None), (0, 1, 0.0065, 1), (0, 2, 0.0080, None), (0, 3, 0.0060, None), (0, 4, 0.0075, None), (0, 5, 0.0070, None)])


def gnomon_flank_r(B, q):
    gn_plates(B, q, [(1, 1, 0.0090, None), (1, 2, 0.0070, 2)])


def gnomon_flank_l(B, q):
    gn_plates(B, q, [(1, 4, 0.0080, 0)])


def gnomon_keel(B, q):
    """The lower plates: they drop when it attends. The back-left one below the waist is gone."""
    gn_plates(B, q, [(2, 0, 0.0080, None), (2, 1, 0.0065, None), (2, 2, 0.0075, None), (2, 4, 0.0070, 3), (2, 5, 0.0085, 1),
                     (3, 0, 0.0060, None), (3, 1, 0.0060, None), (3, 3, 0.0055, None), (3, 4, 0.0060, None), (3, 5, 0.0060, None)])


def gnomon_lamp(B, q):
    """The lamp, in its own frame: it turns about the origin, its pane faces -Z. A five-sided bronze cowl, longer
    over the top than underneath and longer on the right than the left, with two pale plates on its roof."""
    sec = [(-0.031, -0.011), (0.003, -0.024), (0.036, -0.009), (0.030, 0.020), (-0.025, 0.023)]

    def ring(z, k, rake):
        return [np.array((x * k, y * k, z - rake * (y + 0.024) - 0.10 * max(x, 0.0))) for x, y in sec]
    back, mid, front = ring(0.016, 0.62, 0.0), ring(-0.004, 0.96, 0.0), ring(-0.030, 1.0, 0.36)
    solid(B, [back, mid, front], "bronze", cap_mat="seam")
    slab(B, front, "light", q=q, gap=0.0060, thick=0.0016, bev=0.0005, away=(0, 0, 0.05))
    for f, t in ((3, 0.0060), (2, 0.0048)):
        slab(B, [mid[f], mid[(f + 1) % 5], front[(f + 1) % 5], front[f]], "bone", q=q, gap=0.0022, thick=t, bev=0.0014, away=(0, 0, -0.01))
    # the stalk it turns on
    solid(B, [[np.array((x * k, y * k, z)) for x, y in ((-0.010, -0.008), (0.010, -0.008), (0.010, 0.008), (-0.010, 0.008))] for z, k in ((0.014, 1.0), (0.034, 0.8))], "verdigris")


def _blade(B, outline, t, mat):
    """A flat vane in the YZ plane, 2 t thick, from its outline [(y, z)]."""
    solid(B, [[np.array((x, y, z)) for y, z in outline] for x in (-t, t)], mat)


def gnomon_vane(B, q):
    """The tall left vane: hinge at the origin, standing up +Y, its outer face toward -X."""
    out = [(-0.050, 0.006), (0.0, -0.020), (0.090, -0.032), (0.176, -0.016), (0.204, 0.014), (0.110, 0.040), (0.0, 0.030)]
    _blade(B, out, 0.0045, "bronze")
    inlay = [(0.012, -0.012), (0.088, -0.022), (0.160, -0.010), (0.104, 0.030), (0.012, 0.022)]
    for sx in (-1.0, 1.0):
        slab(B, [np.array((sx * 0.0045, y, z)) for y, z in inlay], "bone", q=q, gap=0.0, thick=0.0030, bev=0.0012, away=(0, 0.1, 0.004))


def gnomon_stub(B, q):
    """What is left of the right vane: snapped off on a slant."""
    _blade(B, [(-0.030, 0.004), (0.0, -0.016), (0.050, -0.024), (0.084, 0.006), (0.056, 0.030), (0.0, 0.026)], 0.0045, "bronze")
    solid(B, [[np.array((x, y, z)) for y, z in ((0.048, -0.022), (0.083, 0.006), (0.056, 0.028))] for x in (-0.0055, 0.0055)], "verdigris")


def gnomon_weight(B, q):
    """The plumb weight that hangs free under the point: origin at its top."""
    d = [(0.0, -1.0), (1.0, 0.0), (0.0, 1.0), (-1.0, 0.0)]
    solid(B, [[np.array((x * r, y, z * r * 0.8)) for x, z in d] for y, r in ((0.0, 0.003), (-0.016, 0.015), (-0.058, 0.002))], "bronze")
    solid(B, [[np.array((x * r, y, z * r * 0.8)) for x, z in d] for y, r in ((-0.0135, 0.0165), (-0.0185, 0.0165))], "light")


def _fin_mounts():
    """Where the three vanes hang on the plumb's lower half: hinge point, and (YXZ degrees) a turn about Y to
    their place and a lean that lays them along the taper. None is at the front: the dash on the ring is."""
    out = []
    for deg in (60.0, 180.0, 300.0):
        a = math.radians(deg)
        r = 0.0208
        out.append(dict(mesh="fin", at=[round(-r * math.sin(a), 5), -0.0125 + PLUMB_SEAM * 0, round(-r * math.cos(a), 5)], rot=[-17.5, deg, 0], turn=[13.0, 0, 0], under="shell_b"))
    return out


def _halo(axis, dist, fins=()):
    """The first pass's layout: a body that parts at a seam, a free halo that does the looking."""
    return [dict(mesh="shell_a"), dict(mesh="light"), dict(mesh="shell_b", slide=[a * dist for a in axis], talk=[a * dist * 0.35 for a in axis]),
            dict(mesh="ring", group="halo", lit="dash")] + list(fins)


# Each variant: `build` {mesh name: function}, `parts` [how each mesh is placed and how it moves], and
#   aim   "halo": the body turns slowly and the halo (group "halo") tips toward the target
#         "body": the whole thing turns its front (-Z) to the target
#   glow  how bright its light is drawn (1 = the lantern);  lamp_range: reach of its small real light (m);
#   flare the width (m) of the soft bloom on the lamp;  tilt [degrees the body tips to look, degrees it banks]
#   lo, hi  the bulk the game keeps clear of things, when that is not simply the box round every part
#   size  how much over life size the game draws it;  lie, lie_rot: the height of its centre and its turn
#         (degrees) when it lies dormant
# A part: mesh, at [m], rot [degrees, YXZ], scale [x, y, z] (a mirrored twin), under (another part's mesh name: it
# rides on that part), group, lit ("dash": its light surface is the second light, lit after the seam on waking), and
# its motion, all in its own frame: slide [m] x attention, breathe [m] x a slow idle wave, talk [m] x voice level,
# turn [degrees] x attention, talk_turn [degrees] x voice level, look [yaw, pitch limits in degrees]: the part turns
# by itself to what the Witness looks at (the lamp), ahead of the body.
VARIANTS = {
    "gnomon": dict(build=dict(core=gnomon_core, brow=gnomon_brow, flank_r=gnomon_flank_r, flank_l=gnomon_flank_l, keel=gnomon_keel, lamp=gnomon_lamp,
                              vane=gnomon_vane, stub=gnomon_stub, weight=gnomon_weight),
                   aim="body", size=1.35, lie=0.062, lie_rot=[78, 0, 14], glow=1.7, lamp_range=1.5, flare=0.20, tilt=[9.0, 8.0],
                   lo=[-0.08, -0.17, -0.06], hi=[0.08, 0.17, 0.06], parts=[
                       dict(mesh="core", lit="dash"),
                       dict(mesh="brow", slide=[0, 0.0075, 0.0015], breathe=[0, 0.0016, 0], talk=[0, 0.0040, 0]),
                       dict(mesh="flank_r", slide=[0.0075, 0, 0.0020], talk=[0.0034, 0, 0]),
                       dict(mesh="flank_l", slide=[-0.0075, 0, 0.0020], talk=[-0.0034, 0, 0]),
                       dict(mesh="keel", slide=[0, -0.0070, -0.0012], breathe=[0, -0.0010, 0]),
                       dict(mesh="lamp", at=list(GN_LAMP), look=[62.0, 34.0], slide=[0, 0, -0.0060], talk=[0, 0, -0.0020]),
                       dict(mesh="vane", at=[-0.070, -0.020, 0.012], rot=[0, -52.0, 7.0], turn=[0, 0, 13.0], talk_turn=[0, 0, 5.0], breathe=[0, 0.0015, 0]),
                       dict(mesh="stub", at=[0.078, 0.004, 0.012], rot=[0, 48.0, -8.0], turn=[0, 0, -11.0], talk_turn=[0, 0, -4.0]),
                       dict(mesh="weight", at=[0.004, -0.172, -0.016], slide=[0, -0.012, 0], breathe=[0, -0.0050, 0], talk=[0, 0.0040, 0])]),
    "lantern": dict(build=dict(core=lantern_core, crown=lantern_crown, keel=lantern_keel, cheek=lantern_cheek, visor=lantern_visor),
                    aim="body", size=1.12, lie=0.076, lie_rot=[80, 0, 0], parts=[
                        dict(mesh="core"), dict(mesh="visor", lit="dash"),
                        dict(mesh="crown", slide=[0, 0.0050, 0.0012], breathe=[0, 0.0013, 0], talk=[0, 0.0028, 0]),
                        dict(mesh="keel", slide=[0, -0.0040, -0.0010], breathe=[0, -0.0008, 0]),
                        dict(mesh="cheek", slide=[0.0055, 0, 0], talk=[0.0020, 0, 0]),
                        dict(mesh="cheek", scale=[-1, 1, 1], slide=[0.0055, 0, 0], talk=[0.0020, 0, 0])]),
    "dart": dict(build=dict(core=dart_core, top=dart_top, wing=dart_wing), aim="body", size=1.12, lie=0.03, lie_rot=[0, 0, 8], parts=[
        dict(mesh="core"), dict(mesh="top", slide=[0, 0.004, 0.006], breathe=[0, 0.001, 0]),
        dict(mesh="wing", at=[0.012, 0.004, 0], turn=[0, 0, -9.0], talk=[0, -0.002, 0]),
        dict(mesh="wing", at=[-0.012, 0.004, 0], scale=[-1, 1, 1], turn=[0, 0, -9.0], talk=[0, -0.002, 0])]),
    "hexring": dict(build=dict(core=hex_core, seg=hex_seg), aim="body", size=1.12, lie=0.03, lie_rot=[80, 0, 0], parts=[dict(mesh="core")] + [
        dict(mesh="seg", rot=[0, 0, 60.0 * i], slide=[0, 0.0065, 0], breathe=[0, 0.0012, 0], talk=[0, 0.0020, 0]) for i in range(6)]),
    "plumb": dict(build=dict(shell_a=plumb_shell_a, shell_b=plumb_shell_b, light=plumb_light, ring=plumb_ring, fin=plumb_fin),
                  aim="halo", size=1.5, lie=0.027, lie_rot=[0, 0, 84], ring_y=0.0050, parts=_halo([0, -1, 0], 0.0032, _fin_mounts())),
    "reed": dict(build=dict(shell_a=reed_shell_a, shell_b=reed_shell_b, light=reed_light, ring=reed_ring),
                 aim="halo", size=1.5, lie=0.02, lie_rot=[0, 0, 84], ring_y=0.0, parts=_halo([1, 0, 0], 0.0030)),
    "lens": dict(build=dict(shell_a=lens_shell_a, shell_b=lens_shell_b, light=lens_light, ring=lens_ring),
                 aim="halo", size=1.5, lie=0.045, lie_rot=[0, 0, 8], ring_y=0.0, parts=_halo([0, -1, 0], 0.0040)),
}


def retex(path):
    """The shared detail textures live with the gear: point this file's image URIs there."""
    raw = open(path, "rb").read()
    jl = struct.unpack("<I", raw[12:16])[0]
    js = raw[20:20 + jl].decode().rstrip().replace('"tex/', '"../gear/tex/').replace('"../gear/tex/relic_', '"tex/relic_').encode()
    while len(js) % 4:
        js += b" "
    rest = raw[20 + jl:]
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + len(rest)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A))
        f.write(js)
        f.write(rest)


def main():
    os.makedirs(OUT, exist_ok=True)
    relic_textures()
    manifest = {"_chosen": CHOSEN, "_front": "-Z", "_origin": "centre of the body"}
    for name, V in VARIANTS.items():
        info = {k: V[k] for k in ("aim", "size", "lie", "lie_rot", "parts", "ring_y", "glow", "lamp_range", "flare", "tilt") if k in V}
        lo, hi = np.ones(3) * 9, np.ones(3) * -9
        tris = {"": 0, "_lod": 0}
        for part, fn in V["build"].items():
            uses = sum(1 for p in V["parts"] if p["mesh"] == part)
            for q, suffix in ((1.0, ""), (0.4, "_lod")):
                B = G.Builder()
                fn(B, q)
                surf = G.finish(B)
                path = os.path.join(OUT, "%s_%s%s.glb" % (name, part, suffix))
                G.write_glb(path, "%s_%s%s" % (name, part, suffix), surf, {})
                retex(path)
                tris[suffix] += uses * sum(len(d["idx"]) for d in surf.values()) // 3
                if q == 1.0:
                    allp = np.concatenate([np.array(d["pos"]) for d in surf.values()])
                    for p in V["parts"]:
                        if p["mesh"] == part and "rot" not in p:
                            sc = np.array(p.get("scale", [1, 1, 1]))
                            pts = allp * sc + np.array(p.get("at", [0, 0, 0]))
                            lo, hi = np.minimum(lo, pts.min(axis=0)), np.maximum(hi, pts.max(axis=0))
        ext = max(hi - lo)
        if name == "hexring":
            lo, hi = np.array((-0.104, -0.104, -0.024)), np.array((0.104, 0.104, 0.024))
        if "lo" in V:      # the bulk the game keeps clear of things (vanes and the hanging weight stand outside it)
            lo, hi = np.array(V["lo"]), np.array(V["hi"])
        info.update(tris=tris[""], tris_lod=tris["_lod"], lo=[round(float(x), 4) for x in lo], hi=[round(float(x), 4) for x in hi])
        manifest[name] = info
        print("%-8s tris %4d / %4d   %4.1f wide, %4.1f tall, %4.1f deep (cm, life size; drawn x%.2f)" % (
            name, tris[""], tris["_lod"], (hi[0] - lo[0]) * 100, (hi[1] - lo[1]) * 100, (hi[2] - lo[2]) * 100, V["size"]))
    json.dump(manifest, open(os.path.join(OUT, "witness_manifest.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
