#!/usr/bin/env python3
"""Cuts the filmed takes into the clips the game plays and encodes them as Ogg Theora.
Attack takes share their opening (the telegraph) frame for frame, so the telegraph is cut
once and each outcome is cut from its own take at the same branch frame."""
import json, os, subprocess
PRE, FPS = 3.0, 30
ATT = {"a": 1.65, "b": 1.45}
Q = "7"
def cut(src, start, dur, out):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "art/takes/%s.avi" % src, "-vf", "trim=start_frame=%d:end_frame=%d,setpts=PTS-STARTPTS" % (round((PRE + start) * FPS), round((PRE + start + dur) * FPS)),
                    "-an", "-r", str(FPS), "-c:v", "libtheora", "-q:v", Q, "-g", "15", "assets/video/sentinel_%s.ogv" % out], check=True)
done = {}
for name, dur in [("idle", 3.0), ("open", 3.0), ("counter", 3.0), ("recover", 3.0), ("victory", 6.0), ("defeat", 4.5), ("intro", 6.0), ("travel", 6.0)]:
    if os.path.exists("art/takes/%s.avi" % name):
        cut(name, 0, dur, name); done[name] = dur
for a, branch in ATT.items():
    if os.path.exists("art/takes/%s_parry.avi" % a):
        cut(a + "_parry", 0, branch, a + "_tele"); done[a + "_tele"] = branch
    for o in ["parry", "dodge", "block", "hit"]:
        if os.path.exists("art/takes/%s_%s.avi" % (a, o)):
            cut("%s_%s" % (a, o), branch, 6.0 - branch, "%s_%s" % (a, o)); done["%s_%s" % (a, o)] = round(6.0 - branch, 3)
# the Courtyard road: one travel clip and one still per stop, plus the hotspot positions filmed with them
# (the female knight's road is filmed separately as f_road_N; it shares the male film's hotspots)
for i in range(7):
    if os.path.exists("art/takes/f_road_%d.avi" % i):
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "art/takes/f_road_%d.avi" % i, "-vf", "trim=start_frame=%d:end_frame=%d,setpts=PTS-STARTPTS" % (round(PRE * FPS), round((PRE + 6.0) * FPS)),
                        "-an", "-r", str(FPS), "-c:v", "libtheora", "-q:v", "6", "-g", "15", "assets/video/courtyard_f_road_%d.ogv" % i], check=True)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "art/takes/f_road_%d.avi" % i, "-vf", "select=eq(n\\,%d)" % (round((PRE + 6.0) * FPS) - 1), "-vframes", "1", "-q:v", "3", "assets/video/stills/courtyard_f_stop_%d.jpg" % i], check=True)

road = {"region": "courtyard", "clip_len": 6.0, "stops": []}
os.makedirs("assets/video/stills", exist_ok=True)
for i in range(7):
    if not os.path.exists("art/takes/road_%d.avi" % i):
        continue
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "art/takes/road_%d.avi" % i, "-vf", "trim=start_frame=%d:end_frame=%d,setpts=PTS-STARTPTS" % (round(PRE * FPS), round((PRE + 6.0) * FPS)),
                    "-an", "-r", str(FPS), "-c:v", "libtheora", "-q:v", "6", "-g", "15", "assets/video/courtyard_road_%d.ogv" % i], check=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "art/takes/road_%d.avi" % i, "-vf", "select=eq(n\\,%d)" % (round((PRE + 6.0) * FPS) - 1), "-vframes", "1", "-q:v", "3", "assets/video/stills/courtyard_stop_%d.jpg" % i], check=True)
    spots = json.load(open("art/takes/road_%d.json" % i))["spots"] if os.path.exists("art/takes/road_%d.json" % i) else []
    road["stops"].append({"stage": i, "clip": "road_%d" % i, "still": "courtyard_stop_%d.jpg" % i, "spots": spots})
if road["stops"]:
    json.dump(road, open("data/cine_courtyard.json", "w"), indent=1)
    print(len(road["stops"]), "road stops")
total = sum(os.path.getsize("assets/video/sentinel_%s.ogv" % k) for k in done)
print(len(done), "clips,", round(total / 1048576, 2), "MB")
json.dump({"clips": done, "bytes": total}, open("art/takes/clips.json", "w"), indent=1)
