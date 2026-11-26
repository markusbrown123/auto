#!/usr/bin/env python3
"""Concept image -> low-poly textured model -> rigged GLB, via the Tripo API.

Usage: tools/tripo.py <image.png> <out_name> [face_limit]
Writes art/models/<out_name>.glb (rigged, Mixamo bone names) and a small log
of what each step cost. The API key is never read or stored here: in the
cloud session the network proxy adds it; elsewhere set TRIPO_API_KEY.
"""
import json, os, subprocess, sys, time

API = "https://openapi.tripo3d.ai/v3"
KEY = os.environ.get("TRIPO_API_KEY", "proxy-injected")

def call(method, path, body=None, form=None):
    cmd = ["curl", "-sS", "-m", "120", "-X", method, API + path, "-H", "Authorization: Bearer " + KEY]
    if body is not None:
        cmd += ["-H", "Content-Type: application/json", "-d", json.dumps(body)]
    if form:
        cmd += ["-F", form]
    out = json.loads(subprocess.run(cmd, capture_output=True, text=True, check=True).stdout)
    if out.get("code") != 0:
        sys.exit("Tripo error on %s: %s" % (path, out))
    return out["data"]

def wait(task_id):
    while True:
        d = call("GET", "/tasks/" + task_id)
        if d["status"] in ("success", "failed", "cancelled", "banned", "expired", "unknown"):
            if d["status"] != "success":
                sys.exit("task %s ended as %s: %s" % (task_id, d["status"], d))
            return d
        time.sleep(6)

def prop(image, name, faces):
    """Static prop (weapon, shield, scenery): standard model with a polygon cap, no skeleton. 30 credits."""
    os.makedirs("art/models", exist_ok=True)
    token = call("POST", "/files", form="file=@" + image)["file_token"]
    gen = call("POST", "/generation/image-to-model", {"input": token, "model": "v3.1-20260211", "face_limit": faces, "texture": True, "pbr": True})
    g = wait(gen["task_id"])
    json.dump({"image": image, "model": {"task_id": gen["task_id"], "credits": g.get("credits_consumed")}}, open("art/models/%s.json" % name, "w"), indent=1)
    url = g["output"].get("model_url") or g["output"].get("pbr_model_url") or next(v for v in g["output"].values() if isinstance(v, str) and ".glb" in v)
    for attempt in range(4):
        if subprocess.run(["curl", "-sS", "-L", "-m", "300", "-o", "art/models/%s.glb" % name, url]).returncode == 0:
            break
        time.sleep(4)
        url = wait(gen["task_id"])["output"].get("model_url", url)   # links expire: fetch a fresh one, never regenerate
    print("prop done:", name, g.get("credits_consumed"), flush=True)

def main():
    if sys.argv[1] == "prop":
        return prop(sys.argv[2], sys.argv[3], int(sys.argv[4]) if len(sys.argv) > 4 else 6000)
    image, name = sys.argv[1], sys.argv[2]
    faces = int(sys.argv[3]) if len(sys.argv) > 3 else 30000
    os.makedirs("art/models", exist_ok=True)
    log = {"image": image}
    token = call("POST", "/files", form="file=@" + image)["file_token"]
    gen = call("POST", "/generation/image-to-model", {
        "input": token, "model": "P2-20260801", "face_limit": faces,
        "texture": True, "pbr": True, "delight": True, "texture_alignment": "original_image"})
    g = wait(gen["task_id"])
    log["model"] = {"task_id": gen["task_id"], "credits": g.get("credits_consumed")}
    print("model done:", log["model"], flush=True)
    chk = call("POST", "/animations/rig-check", {"input": gen["task_id"]})
    c = wait(chk["task_id"])
    log["rig_check"] = {"credits": c.get("credits_consumed"), "output": c.get("output")}
    print("rig check:", log["rig_check"], flush=True)
    json.dump(log, open("art/models/%s.json" % name, "w"), indent=1)      # keep the task ids even if a later step fails
    rig_type = os.environ.get("RIG_TYPE", "biped")
    body = {"input": gen["task_id"], "model": "v3.0-20260909", "rig_type": "biped", "spec": "mixamo", "out_format": "glb"}
    if rig_type != "biped":
        body = {"input": gen["task_id"], "model": "v2.5-20260210", "rig_type": rig_type, "out_format": "glb"}
    rig = call("POST", "/animations/rig", body)
    r = wait(rig["task_id"])
    log["rig"] = {"task_id": rig["task_id"], "credits": r.get("credits_consumed")}
    url = r["output"].get("model_url") or next(v for v in r["output"].values() if isinstance(v, str) and v.startswith("http"))
    subprocess.run(["curl", "-sS", "-L", "-m", "300", "-o", "art/models/%s.glb" % name, url], check=True)
    json.dump(log, open("art/models/%s.json" % name, "w"), indent=1)
    print("done:", log, flush=True)

if __name__ == "__main__":
    main()
