#!/usr/bin/env python3
"""Summarises an audio log written by `-- --audiolog=<file>` (src/core/sfx.gd).

Usage: tools/dev/audiolog_report.py <audiolog.tsv> [slice.log]

With the slice bot's step log the timeline is cut at its STEP lines (both files use the game clock). Per segment:
step sounds played and swallowed by the retrigger gap, steps per second, steps per rig, steps from a rig that was
not moving (speed under 0.05 m/s), from a rig not visible, the most rigs with footsteps on at once, the armour
layers (jingle, armor) and everything else that started.
"""
import re
import sys
from collections import Counter, defaultdict


def load(path):
    rows = []
    for line in open(path, encoding="utf-8"):
        f = line.rstrip("\n").split("\t")
        if len(f) < 3 or f[0] == "t":
            continue
        if f[2] == "rig":
            rows.append({"t": rows[-1]["t"] if rows else 0.0, "kind": "rig", "who": f[3]})
            continue
        f += [""] * (9 - len(f))
        rows.append({"t": float(f[0]), "kind": f[2], "name": f[3], "bus": f[4], "vol": float(f[5] or 0), "who": f[7], "stack": f[8]})
    return rows


def steps_of(path):
    out = []
    for line in open(path, encoding="utf-8"):
        m = re.match(r"\[\s*([\d.]+)s game.*\] STEP (.*)", line)
        if m:
            out.append((float(m.group(1)), m.group(2).strip()))
    return out


def rig_of(who):
    return who.split(" ")[0] if who else "(no rig)"


def field(who, key):
    m = re.search(key + r"=(\S+)", who)
    return m.group(1) if m else ""


def report(rows, segs):
    if not segs:
        segs = [(0.0, "all")]
    segs = segs + [(1e9, "end")]
    for i in range(len(segs) - 1):
        a, name = segs[i]
        b = segs[i + 1][0]
        part = [r for r in rows if a <= r["t"] < b]
        if not part:
            continue
        dur = max(0.001, min(b, part[-1]["t"]) - a)
        steps = [r for r in part if r["kind"] == "pool" and r["name"].startswith("step_")]
        gated = [r for r in part if r["kind"] == "step_gated"]
        jingle = [r for r in part if r["kind"] == "pool" and r["name"].startswith("jingle")]
        armor = [r for r in part if r["kind"] == "sfx" and r["name"].startswith("armor")]
        still = [r for r in steps + gated if r["who"] and float(field(r["who"], "spd") or 9) < 0.05]
        hidden = [r for r in steps + gated if field(r["who"], "vis") == "false"]
        per_rig = Counter(rig_of(r["who"]) for r in steps + gated)
        rig_counts = [int(r["name"]) for r in part if r["kind"] == "rigs"]
        other = Counter((r["kind"], re.sub(r"_\d+$", "_n", r["name"])) for r in part
                        if r["kind"] not in ("rigs", "rig", "step_gated") and not (r["kind"] == "pool" and (r["name"].startswith("step_") or r["name"].startswith("jingle"))))
        print(f"== {name}  [{a:.1f} s .. {a + dur:.1f} s, {dur:.1f} s]")
        print(f"   step requests {len(steps) + len(gated)} (played {len(steps)}, gated {len(gated)}); played/s {len(steps) / dur:.2f};"
              f" from a still rig {len(still)}; from a hidden rig {len(hidden)}")
        print(f"   armour: jingle {len(jingle)}, armor {len(armor)}; most rigs with footsteps on at once {max(rig_counts) if rig_counts else 0}")
        for rig, n in per_rig.most_common(8):
            print(f"     {rig}: {n} requests ({n / dur:.2f}/s)")
        if other:
            print("   other: " + ", ".join(f"{k[0]}:{k[1]} x{n}" for k, n in sorted(other.items())))


def main():
    rows = load(sys.argv[1])
    segs = steps_of(sys.argv[2]) if len(sys.argv) > 2 else []
    report(rows, segs)
    # whole-run step stacks, to show which code put the feet down
    st = Counter(r["stack"].split(" < ")[1] if " < " in r["stack"] else r["stack"] for r in rows if r["kind"] in ("pool", "step_gated") and r["name"].startswith("step_"))
    print("== step callers (frame above _footfall)")
    for k, n in st.most_common(10):
        print(f"   {n:5d}  {k}")


if __name__ == "__main__":
    main()
