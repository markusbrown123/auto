#!/usr/bin/env python3
"""Turns every generated kit concept (art/concept/env_<kit>_*_v1.png) that has no model yet into a static prop
through tools/tripo.py (30 credits = $0.30 each), three at a time, then copies it into assets/models/.
A prop whose task id is already saved (art/models/<name>.json) is re-downloaded, never regenerated.
Usage: tools/kit_props.py [max_new]"""
import glob, json, os, shutil, subprocess, sys, concurrent.futures as cf
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
KITS = ("ca", "cr", "ro", "ci", "de", "th")
limit = int(sys.argv[1]) if len(sys.argv) > 1 else 999
jobs = []
for img in sorted(glob.glob("art/concept/env_*_v1.png")):
    name = os.path.basename(img)[:-7]
    if name.split("_")[1] not in KITS or os.path.exists("assets/models/%s.glb" % name):
        continue
    jobs.append((img, name))
new = [j for j in jobs if not os.path.exists("art/models/%s.json" % j[1])]
jobs = [j for j in jobs if j not in new] + new[:limit]

def run(job):
    img, name = job
    meta = "art/models/%s.json" % name
    if os.path.exists(meta):
        # paid for already: fetch it again by task id
        import tripo
        d = tripo.wait(json.load(open(meta))["model"]["task_id"])
        url = d["output"].get("model_url") or d["output"].get("pbr_model_url")
        ok = subprocess.run(["curl", "-sS", "-L", "-m", "300", "-o", "art/models/%s.glb" % name, url]).returncode == 0
    else:
        ok = subprocess.run([sys.executable, "tools/tripo.py", "prop", img, name, "6000"], stdin=subprocess.DEVNULL).returncode == 0
    path = "art/models/%s.glb" % name
    if ok and os.path.exists(path) and os.path.getsize(path) > 100000:
        shutil.copy(path, "assets/models/%s.glb" % name)
        return name, "ok"
    return name, "FAILED"

with cf.ThreadPoolExecutor(3) as ex:
    for name, status in ex.map(run, jobs):
        print(name, status, flush=True)
