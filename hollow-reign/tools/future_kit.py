#!/usr/bin/env python3
"""The far-future environment kit (env_fu_*): concept images through the Higgsfield CLI, then static props through
tools/tripo.py. Owner direction: the land is natural, everything built on it is far-future, nothing is medieval.

Usage: tools/future_kit.py concept [id ...]     art/concept/env_fu_<id>_v1.png (about 1.25 Higgsfield credits each)
       tools/future_kit.py model [id ...]       art/models/env_fu_<id>.glb     (30 Tripo credits each)
       tools/future_kit.py install [id ...]     copies the GLBs into assets/models/
Nothing is generated twice: a concept or model that exists is skipped; a model whose task id was logged
(art/models/<name>.json) is downloaded again from that task, never paid for again."""
import concurrent.futures as cf, json, os, shutil, subprocess, sys

STYLE = ("Environment set piece for an original far-future science fiction game: a relic of a vanished advanced civilisation standing on wild natural land. "
         "Monolithic forms in matte off-white ceramic and dark brushed gunmetal alloy, large plain panels cut with precise straight seams, "
         "thin lines of pale cyan light in a few seams, ancient exposed machinery where panels have fallen away. "
         "Weathered for centuries: rain streaks, dull stains, chipped edges, lichen and moss at its foot. Not shiny, not chrome. "
         "Not medieval: no stone blocks, no bricks, no masonry, no arches, no battlements, no wood, no cloth. ")
FRAME = (" A single isolated object, complete and fully visible, three-quarter front view, standing on nothing, plain light grey background, "
         "soft even daylight, realistic materials, high detail, game environment asset. No people, no text, no logos.")
# id: (description, face limit)
KIT = {
 "pylon": ("A tall freestanding monolith pylon: a slender four-sided tapering slab of pale ceramic plates over a dark alloy core, leaning very slightly, "
           "one vertical seam of cyan light up its front face, a notched head, a heavy flared alloy foot half sunk in turf.", 2500),
 "tower": ("A tall slim watch spire: a smooth tapering hexagonal tower of pale ceramic in three setbacks with dark alloy collars between them, "
           "cantilevered fins near the top, a broken open crown showing dark ribs, vertical light slits, stains running down from every joint.", 3500),
 "wall": ("A long straight section of defensive bulkhead wall: tall leaning armoured panels of pale ceramic braced by dark alloy ribs, a line of cyan light under its flat top, "
          "one end torn away showing the honeycomb structure and cables inside, grass and moss along its foot.", 3000),
 "colossus": ("A colossal dormant guardian machine kneeling on one knee with its head bowed and its long arms resting on the ground: smooth featureless ceramic shell plates "
              "over a dark mechanical frame, no face, one shoulder plate missing showing dead machinery, moss on its shoulders and back, a dim cyan light in its chest.", 4500),
 "engine": ("A huge ancient machine half buried in the ground at a tilt: a ribbed cylindrical turbine housing of dark alloy with a ring of ceramic cowling, "
            "one side open showing coils and vanes, thick cables trailing from it, grass growing over its lower half, a faint cyan glow deep inside.", 3500),
 "beacon": ("A slender standing beacon lamp: a thin dark alloy mast on a small three-footed base, carrying a tall narrow glowing amber-white light element "
            "held between two ceramic blades at its head.", 1500),
 "wreck": ("A fallen curved segment of a gigantic ring structure lying on the ground: a thick arc of pale ceramic shell over dark alloy ribs, broken at both ends, "
           "a channel on its inner face that once carried light, half sunk in earth with grass over one end.", 3000),
 "core": ("A great machine core on a low stepped alloy dais: a tall ceramic ring standing upright holding a dark faceted sphere in its centre with thin cyan light in its seams, "
          "heavy conduits running from the ring down into the dais, symmetrical, imposing, old.", 4500),
 "husk": ("A dead maintenance machine slumped on the ground: a low four-legged walker with a smooth ceramic carapace and thin jointed alloy legs folded under it, "
          "one sensor eye dark, a panel hanging open, moss on its back.", 3000),
 "throne": ("A machine throne: a tall high-backed seat cut from dark alloy and pale ceramic, its back rising into a thin vertical spine with a ring-shaped halo of machine parts behind the head, "
            "conduits and cables running from the armrests and the back down into a low square dais, thin lines of amber light in the seams. Empty, front view, symmetrical. A seat a tall armoured person could sit in.", 6000),
 "cradle": ("A stasis cradle: a long open capsule bed of pale ceramic lying horizontally on a dark alloy base, three thin alloy hoops arched over the bed, "
            "a raised head unit at one end with a dark glass panel and thin lines of teal light, its transparent cover slid off to one side, cables running from the base. Empty, nobody inside.", 6000),
 "pod": ("An upright stasis pod standing against a slab of dark alloy: a tall capsule of pale ceramic with a long narrow frosted dark glass window, "
         "a thin vertical line of teal light, pipes and cables at its foot, sealed, condensation stains.", 2500),
 "stack": ("An archive stack: a tall narrow tower of stacked dark alloy memory blocks held in a pale ceramic frame, rows of tiny amber lights in its face most of them dead, "
           "scorched black on one side, some blocks pulled out and lying at its foot in ash.", 2500),
 "vent": ("A big scorched exhaust stack: a short wide ribbed cylinder of dark burnt alloy with ceramic heat tiles, many of them fallen off, "
          "a deep orange glow down its throat, soot streaks, a grille around its foot.", 2500),
 "icepylon": ("A tall four-sided tapering monolith pylon of pale ceramic plates over a dark alloy core, sheathed on one side in thick clear blue ice with long icicles, "
              "snow on its ledges, one vertical seam of cold cyan light up its front face.", 3000),
 "antenna": ("A toppled dish antenna array: a wide shallow ceramic dish on a broken alloy gimbal mount lying tilted on the ground, its feed arm snapped, "
             "vines and moss growing through it.", 3000),
}

def concept(cid):
    out = "art/concept/env_fu_%s_v1.png" % cid
    if os.path.exists(out):
        return cid, "exists"
    r = subprocess.run(["higgsfield", "generate", "create", "gpt_image_2_6", "--prompt", STYLE + KIT[cid][0] + FRAME, "--aspect_ratio", "1:1",
                        "--resolution", "1k", "--wait", "--wait-timeout", "10m"], capture_output=True, text=True, stdin=subprocess.DEVNULL)
    url = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
    if not url.startswith("http"):
        return cid, "FAILED: " + (r.stderr or r.stdout)[-300:]
    subprocess.run(["curl", "-sS", "-m", "180", "-o", out, url], check=True)
    return cid, "ok"

def model(cid):
    name = "env_fu_" + cid
    if os.path.exists("art/models/%s.glb" % name):
        return cid, "exists"
    if os.path.exists("art/models/%s.json" % name):
        return cid, "task logged, model missing: recover it by task id, do not regenerate"
    r = subprocess.run([sys.executable, "tools/tripo.py", "prop", "art/concept/%s_v1.png" % name, name, str(KIT[cid][1])], capture_output=True, text=True, stdin=subprocess.DEVNULL)
    return cid, (r.stdout + r.stderr).strip()[-300:]

def install(cid):
    name = "env_fu_" + cid
    shutil.copyfile("art/models/%s.glb" % name, "assets/models/%s.glb" % name)
    return cid, "installed"

def main():
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    what = sys.argv[1]
    ids = sys.argv[2:] or list(KIT)
    fn = {"concept": concept, "model": model, "install": install}[what]
    with cf.ThreadPoolExecutor(4) as ex:
        for cid, status in ex.map(fn, ids):
            print(cid, status, flush=True)

if __name__ == "__main__":
    main()
