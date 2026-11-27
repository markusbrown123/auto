import sys, re, statistics
# per-rig: speed over 1 s windows from POS lines (every 3 frames)
rows = {}
for line in open(sys.argv[1]):
    p = line.rstrip("\n").split("\t")
    if len(p) < 3 or not p[2].startswith("POS"):
        continue
    m = dict(kv.split("=") for kv in p[2].split()[1:])
    rows.setdefault(m["rig"], []).append((float(p[1]), float(m["x"]), float(m["z"])))
for rig, r in rows.items():
    win = []
    for i in range(len(r)):
        j = i + 10   # 30 frames = 1 s (POS every 3 frames)
        if j >= len(r): break
        t0, x0, z0 = r[i]; t1, x1, z1 = r[j]
        if t1 - t0 > 1.05: continue
        v = ((x1-x0)**2 + (z1-z0)**2) ** 0.5 / (t1 - t0)
        win.append((t0, v))
    moving = [v for t, v in win if v > 0.3]
    if not moving: continue
    print("rig %s: %.1f-%.1f s, moving windows=%d, median %.3f m/s, p90 %.3f, max %.3f" % (rig, r[0][0], r[-1][0], len(moving), statistics.median(moving), sorted(moving)[int(len(moving)*0.9)-1], max(moving)))
    # segments where moving
    seg = None
    for t, v in win:
        if v > 0.3 and seg is None: seg = [t, t, []]
        if v > 0.3: seg[1] = t; seg[2].append(v)
        if v <= 0.3 and seg is not None:
            if seg[1]-seg[0] > 1: print("   moving %.1f-%.1f s median %.3f" % (seg[0], seg[1]+1, statistics.median(seg[2])))
            seg = None
    if seg and seg[1]-seg[0] > 1: print("   moving %.1f-%.1f s median %.3f" % (seg[0], seg[1]+1, statistics.median(seg[2])))
