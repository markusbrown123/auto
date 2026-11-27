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
CHOSEN = "plumb"

G.MATERIALS.update({
    "ceramic": ((0.80, 0.785, 0.75), 0.0, 0.62, None, "fine_n", None, 0.18, None),
    "alloy": ((0.80, 0.81, 0.84), 0.62, 0.40, "steel_a", "steel_n", "steel_orm", 0.3, None),
    "seam": ((0.07, 0.075, 0.085), 0.6, 0.55, None, None, None, 1.0, None),
    "light": ((1.0, 0.93, 0.82), 0.0, 0.5, None, None, None, 1.0, ((1.0, 0.80, 0.50), 1.6)),
})


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


def _fin_mounts():
    """Where the three vanes hang on the plumb's lower half: hinge point, turn about Y (degrees), and the lean
    (degrees from vertical) that lays them along the taper. None is at the front: the dash on the ring is."""
    out = []
    for deg in (60.0, 180.0, 300.0):
        a = math.radians(deg)
        r = 0.0208
        out.append({"at": [round(-r * math.sin(a), 5), -0.0125, round(-r * math.cos(a), 5)], "yaw": deg, "lean": 17.5})
    return out


VARIANTS = {
    "plumb": dict(parts=dict(shell_a=plumb_shell_a, shell_b=plumb_shell_b, light=plumb_light, ring=plumb_ring, fin=plumb_fin),
                  open_axis=[0, -1, 0], open_dist=0.0032, ring_y=0.0050, fins=_fin_mounts(), fin_open=13.0),
    "reed": dict(parts=dict(shell_a=reed_shell_a, shell_b=reed_shell_b, light=reed_light, ring=reed_ring),
                 open_axis=[1, 0, 0], open_dist=0.0030, ring_y=0.0, fins=[], fin_open=0.0),
    "lens": dict(parts=dict(shell_a=lens_shell_a, shell_b=lens_shell_b, light=lens_light, ring=lens_ring),
                 open_axis=[0, -1, 0], open_dist=0.0040, ring_y=0.0, fins=[], fin_open=0.0),
}


def retex(path):
    """The shared detail textures live with the gear: point this file's image URIs there."""
    raw = open(path, "rb").read()
    jl = struct.unpack("<I", raw[12:16])[0]
    js = raw[20:20 + jl].decode().rstrip().replace('"tex/', '"../gear/tex/').encode()
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
    manifest = {"_chosen": CHOSEN, "_front": "-Z", "_origin": "centre of the seam"}
    for name, V in VARIANTS.items():
        info = {k: V[k] for k in ("open_axis", "open_dist", "ring_y", "fins", "fin_open")}
        lo, hi = np.ones(3) * 9, np.ones(3) * -9
        tris = {"": 0, "_lod": 0}
        for part, fn in V["parts"].items():
            for q, suffix in ((1.0, ""), (0.4, "_lod")):
                B = G.Builder()
                fn(B, q)
                surf = G.finish(B)
                path = os.path.join(OUT, "%s_%s%s.glb" % (name, part, suffix))
                G.write_glb(path, "%s_%s%s" % (name, part, suffix), surf, {})
                retex(path)
                n = sum(len(d["idx"]) for d in surf.values()) // 3
                tris[suffix] += n * (len(V["fins"]) if part == "fin" else 1)
                if q == 1.0 and part != "fin":
                    allp = np.concatenate([np.array(d["pos"]) for d in surf.values()])
                    lo, hi = np.minimum(lo, allp.min(axis=0)), np.maximum(hi, allp.max(axis=0))
        info.update(parts=list(V["parts"]), tris=tris[""], tris_lod=tris["_lod"], lo=[round(float(x), 4) for x in lo], hi=[round(float(x), 4) for x in hi])
        manifest[name] = info
        print("%-6s tris %4d / %3d   %.1f cm tall, %.1f cm across the ring" % (name, tris[""], tris["_lod"], (hi[1] - lo[1]) * 100, (hi[0] - lo[0]) * 100))
    json.dump(manifest, open(os.path.join(OUT, "witness_manifest.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
