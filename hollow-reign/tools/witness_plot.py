#!/usr/bin/env python3
"""Draws where the Witness went, from a log written by the game (HR_WITNESS_LOG=<file>, see WitnessDrone._log).

    python3 tools/witness_plot.py <log> <out.png> [title]

Left: the ground seen from above (1 m grid). The drone's path is coloured by what it was doing; the knight (K), the
foe (F) and the camera (C) are drawn where they were, with the camera's lines to both fighters every two seconds.
Right: the screen, with the duel's pads and bars: every logged position as a dot the size the drone was on screen.
Prints how often it was nearer the lens than a fighter AND inside that fighter's line, off screen, or on a pad.
"""
import math, sys
from PIL import Image, ImageDraw

MOOD = {"ring": (90, 200, 255), "dart": (255, 90, 90), "dip": (255, 210, 70), "near_knight": (120, 255, 140), "over_foe": (220, 130, 255),
        "shoulder": (200, 200, 200), "fallen": (150, 150, 150), "orbit": (90, 200, 255), "scout": (255, 170, 60), "inspect": (255, 230, 90),
        "scan": (255, 255, 200), "pause": (255, 120, 200), "lead": (120, 255, 140), "address": (220, 130, 255)}


def main():
    rows = []
    for line in open(sys.argv[1]):
        p = line.split()
        if len(p) == 16:
            rows.append([float(p[0]), p[1]] + [float(x) for x in p[2:]])
    if not rows:
        print("no rows")
        return
    duel = any(r[7] < 900 for r in rows)
    W, H, S = 760, 760, 62.0
    cx = sum(r[5] for r in rows) / len(rows)
    cz = sum(r[6] for r in rows) / len(rows)
    img = Image.new("RGB", (W + 980, H), (22, 24, 30))
    d = ImageDraw.Draw(img)

    def pt(x, z):
        return (W / 2 + (x - cx) * S, H / 2 + (z - cz) * S)
    for i in range(-7, 8):
        d.line([pt(cx + i, cz - 7), pt(cx + i, cz + 7)], fill=(40, 43, 52))
        d.line([pt(cx - 7, cz + i), pt(cx + 7, cz + i)], fill=(40, 43, 52))
    bad_line = off = pad = 0
    last = None
    for n, r in enumerate(rows):
        t, mood, x, y, z, kx, kz, fx, fz, camx, camz, sx, sy, vw, vh, half = r
        if n % 20 == 0:
            for (ax, az) in ((kx, kz), (fx, fz)):
                if ax < 900:
                    d.line([pt(camx, camz), pt(ax, az)], fill=(70, 60, 44))
            d.ellipse([pt(camx, camz)[0] - 3, pt(camx, camz)[1] - 3, pt(camx, camz)[0] + 3, pt(camx, camz)[1] + 3], fill=(200, 160, 90))
        for (ax, az, col) in ((kx, kz, (200, 205, 215)), (fx, fz, (190, 90, 70))):
            if ax < 900:
                q = pt(ax, az)
                d.ellipse([q[0] - 2, q[1] - 2, q[0] + 2, q[1] + 2], fill=col)
        q = pt(x, z)
        if last:
            d.line([last, q], fill=MOOD.get(mood, (255, 255, 255)), width=2)
        last = q
        # nearer the lens than a fighter and within 0.5 m of the line to them, in plan
        for (ax, az) in ((kx, kz), (fx, fz)):
            if ax > 900 or mood in ("shoulder", "fallen", "near_knight", "over_foe"):
                continue
            dx, dz = ax - camx, az - camz
            L = math.hypot(dx, dz)
            tt = ((x - camx) * dx + (z - camz) * dz) / (L * L)
            dist = abs((x - camx) * dz - (z - camz) * dx) / L
            if 0.05 < tt < 1.0 and dist < 0.5 and y < 2.2:
                bad_line += 1
        if sx < 0 or sy < 0 or sx > vw or sy > vh:
            off += 1
        if duel and ((sx - half < 168 and 52 < sy + half and sy - half < 130) or sy + half > vh - 112 or (sx + half > vw - 64 and sy - half < 64)):
            pad += 1
    for (label, r, col) in (("K", rows[-1][5:7], (200, 205, 215)), ("F", rows[-1][7:9], (190, 90, 70)), ("C", rows[-1][9:11], (200, 160, 90))):
        if r[0] < 900:
            d.text((pt(*r)[0] + 6, pt(*r)[1] - 6), label, fill=col)
    # the screen
    vw, vh = rows[0][13], rows[0][14]
    k = 900.0 / vw
    ox, oy = W + 40, 60
    d.rectangle([ox, oy, ox + vw * k, oy + vh * k], outline=(120, 124, 135))
    if duel:
        for (a, b, c, e) in ((0, 52, 168, 130), (0, vh - 112, 104, vh - 8), (vw - 104, vh - 112, vw, vh - 8), (vw / 2 - 52, vh - 112, vw / 2 + 52, vh - 8),
                             (vw - 64, 0, vw, 64), (24, 8, 274, 40), (357, 20, 922, 64)):
            d.rectangle([ox + a * k, oy + b * k, ox + c * k, oy + e * k], outline=(170, 110, 60))
    for r in rows:
        sx, sy, half = r[11], r[12], max(2.0, r[15])
        col = MOOD.get(r[1], (255, 255, 255))
        d.ellipse([ox + (sx - half) * k, oy + (sy - half) * k, ox + (sx + half) * k, oy + (sy + half) * k], outline=col)
    yy = oy + vh * k + 16
    xx = ox
    for name, col in MOOD.items():
        if any(r[1] == name for r in rows):
            d.rectangle([xx, yy, xx + 10, yy + 10], fill=col)
            d.text((xx + 14, yy - 1), name, fill=(210, 212, 220))
            xx += 24 + 7 * len(name)
    msg = "%s   %.0f s, %d samples   in a camera-to-fighter line: %d   off screen: %d   over a pad or bar: %d" % (
        sys.argv[3] if len(sys.argv) > 3 else "", rows[-1][0] - rows[0][0], len(rows), bad_line, off, pad)
    d.text((12, 10), msg, fill=(230, 232, 240))
    img.save(sys.argv[2])
    print(msg)


if __name__ == "__main__":
    main()
