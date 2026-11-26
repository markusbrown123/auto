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
total = sum(os.path.getsize("assets/video/sentinel_%s.ogv" % k) for k in done)
print(len(done), "clips,", round(total / 1048576, 2), "MB")
json.dump({"clips": done, "bytes": total}, open("art/takes/clips.json", "w"), indent=1)
