#!/usr/bin/env python3
"""Hollow Reign - generated replacement for the synthesised combat, footstep and foley sounds (Higgsfield CLI).

One table (FILES) lists every file: engine name (same family and numbering as src/core/sfx.gd POOLS), family, model, text
prompt, requested duration. Paid jobs follow tools/voices.py: one job at a time, stdin closed, every job id is written to
assets/audio/sfx/sfx_jobs.json BEFORE waiting on it, a network error fails that file and not the run, a recorded job is
never paid again (a pending one is collected by its id; a job the account already holds is found again before creating).
The raw download of every take is kept in art/sfx_masters/ (git-ignored); everything after that is free and re-runnable.

  tools/sfx_buy.py --plan                 files, model, credits each and total; no job, no file written
  tools/sfx_buy.py                        buy what is missing, then post-process what was bought
  tools/sfx_buy.py --only=clash,step_stone --limit=N --ceiling=300
  tools/sfx_buy.py --post                 post-process the kept masters again (no CLI, no cost)
  tools/sfx_buy.py --restore              put the synthesised files back, remove what this tool added
  tools/sfx_buy.py --report[=raw]         per file: duration, peak, loudness, centroid, problem flags (final files, or the raw masters)
  --only takes family names (clash, block, parry, guard_break, hit_armor, hit_flesh, whoosh_light, whoosh_med, whoosh_heavy,
  step_stone, step_metal, step_grass, step_snow, step_water, jingle, shield_hit, draw, sheath, body_fall, rustle, roll) or file names.

Post: leading silence cut so the sound starts PREROLL (4 ms) in, the single loudest event kept (clean further events are
saved as extra numbered variants after the family's last file; src/core/sfx.gd finds them by itself), tail trimmed and
faded, mono 44.1 kHz 16-bit, peak <= -2 dBFS, loudness matched per family (targets of docs/AUDIO_NOTES.md). Before a
synthesised file is first overwritten it is copied to assets/audio/sfx_synth_backup/ (a .gdignore keeps Godot from
importing it); a file whose take failed or has not been bought is simply left as it was, so no variant number goes missing.
Nobody has listened to anything this makes."""
import hashlib, json, os, re, shutil, subprocess, sys, time
import numpy as np
from scipy import signal
from scipy.io import wavfile
from scipy.ndimage import uniform_filter1d

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
SFX = os.path.join(ROOT, "assets", "audio", "sfx")
BACKUP = os.path.join(ROOT, "assets", "audio", "sfx_synth_backup")
MASTERS = os.path.join(ROOT, "art", "sfx_masters")
JOBS_PATH = os.path.join(SFX, "sfx_jobs.json")
POST_PATH = os.path.join(SFX, "sfx_post.json")      # what this tool wrote (extras and new slots), for --restore
SR = 44100
PREROLL = 0.004
PEAK_CAP_DB = -2.0
MAX_EXTRA = 3                                        # clean extra events kept per take

ARGS = [a for a in sys.argv[1:] if a.startswith("--")]
def opt(name, default=None):
    for a in ARGS:
        if a == "--" + name:
            return ""
        if a.startswith("--%s=" % name):
            return a.split("=", 1)[1]
    return default

# ---------------------------------------------------------------- the table
DRY = ("Single isolated one-shot sound effect, dry, close-miked, clean studio recording. No music, no voice, no speech, "
       "no reverb tail, no echo, no room ambience, no background noise. Silence after the sound.")
# per family: loudness target (LUFS-M, as docs/AUDIO_NOTES.md), longest useful length s, fade-out ms, model
FAM = {
    "clash": (-20.0, 1.6, 70, "mirelo_text_to_audio"), "block": (-21.0, 0.7, 45, "mirelo_text_to_audio"),
    "parry": (-17.0, 1.6, 200, "mirelo_text_to_audio"), "guard_break": (-17.0, 1.5, 150, "mirelo_text_to_audio"),
    "hit_armor": (-21.0, 0.7, 45, "mirelo_text_to_audio"), "hit_flesh": (-17.5, 0.6, 45, "mirelo_text_to_audio"),
    "whoosh_light": (-17.0, 0.5, 30, "mirelo_text_to_audio"), "whoosh_med": (-16.5, 0.7, 30, "mirelo_text_to_audio"),
    "whoosh_heavy": (-16.3, 1.0, 40, "mirelo_text_to_audio"),
    "step_stone": (-21.0, 0.6, 60, "mirelo_text_to_audio"), "step_metal": (-20.0, 0.7, 60, "mirelo_text_to_audio"),
    "step_grass": (-24.0, 0.6, 60, "mirelo_text_to_audio"), "step_snow": (-23.5, 0.6, 60, "mirelo_text_to_audio"),
    "step_water": (-22.0, 0.7, 60, "mirelo_text_to_audio"),
    "jingle": (-28.0, 0.5, 50, "mirelo_text_to_audio"),
    "shield_hit": (-19.0, 0.9, 60, "mirelo_text_to_audio"), "draw": (-24.0, 1.1, 60, "mirelo_text_to_audio"),
    "sheath": (-24.0, 1.0, 60, "mirelo_text_to_audio"), "body_fall": (-19.0, 1.5, 120, "mirelo_text_to_audio"),
    "rustle": (-27.0, 0.6, 50, "mirelo_text_to_audio"), "roll": (-23.0, 0.9, 60, "mirelo_text_to_audio"),
}
FILES = []          # (file stem, family, prompt, seconds)
def add(fam, dur, descs):
    for i, d in enumerate(descs, 1):
        FILES.append(("%s_%d" % (fam, i), fam, d + " " + DRY, dur))

add("clash", 2.0, [
    "Two steel longswords striking edge to edge, a hard bright clang with a ringing metallic tail.",
    "A steel sword crossguard slamming into another blade, heavy metallic clang with a short ring.",
    "Two heavy broadswords clashing flat on flat, deep resonant clang with a long metallic ring.",
    "Two swords colliding with a short glancing scrape of steel on steel, then a sharp clang.",
    "A powerful overhead sword strike met by another sword, loud ringing impact, medieval combat.",
    "Two arming swords meeting at the tips, a tight higher-pitched clink with quick decay."])
add("block", 1.2, [
    "A sword blow stopped by a blade held in a hard block, muted heavy metal clunk with a short ring.",
    "A heavy sword strike blocked on an iron-bound wooden shield, dull thud with a metal clank.",
    "Steel sword hitting a raised steel vambrace guard, dull metallic knock, almost no ring.",
    "A forceful sword cut blocked with a crossed blade, low heavy metallic clank, short decay."])
add("parry", 2.0, [
    "A sword parry, one blade deflecting another with a crisp bright metallic shing and a clean high ring.",
    "A precise sword parry, blade sliding off blade, a sharp high-pitched steel chime that rings out.",
    "A perfectly timed sword parry, bright ringing steel on steel, a satisfying clear metallic ping."])
add("guard_break", 2.0, [
    "A heavy sword blow smashing through a guard, loud crunching metal and splintering wood, a shield breaking apart.",
    "A massive strike shattering a shield, deep crack and splintering wood with falling metal fragments.",
    "A crushing blow breaking a defender's guard, heavy metal crunch, splinters and a rattle of fragments."])
add("hit_armor", 1.5, [
    "A steel sword slamming against a plate-armour breastplate, heavy dull metallic crunch, no ring.",
    "A sword blow glancing off a steel pauldron, hard metallic thud and scrape.",
    "A heavy sword strike denting plate armour, deep clanking impact with short rattle.",
    "A blade chopping into mail and plate armour, crunching metallic thud."])
add("hit_flesh", 1.0, [
    "A sword blade cutting into a body, a wet meaty slash with a dull thud, no scream, no grunt.",
    "A heavy sword hit into flesh, short wet chop and impact, no vocal sound.",
    "A blade slicing across a body, a quick wet slice with a soft thud, no voice.",
    "A sword thrust into a body, a dull wet stab impact, no voice."])
add("whoosh_light", 1.0, [
    "A fast light sword swing through the air, a quick thin whoosh of a blade cutting air.",
    "A quick short sword slash, a sharp airy whoosh, light and fast.",
    "A rapid blade flick through air, a thin high whoosh with a faint edge whistle."])
add("whoosh_med", 1.2, [
    "A steady sword swing through the air, a full natural whoosh of a blade passing close to the microphone.",
    "A medium-speed longsword cut, a smooth airy whoosh that rises and falls.",
    "A controlled sword slash passing by, a natural blade whoosh with a soft airy body."])
add("whoosh_heavy", 1.5, [
    "A slow heavy greatsword swing, a deep powerful whoosh with low air push.",
    "A massive two-handed weapon swing through air, a big low whoosh that builds and passes.",
    "A heavy overhead sword chop, a deep rushing whoosh with weight behind it."])

_SURFACE = {"stone": "a hard stone floor", "metal": "a hollow metal deck plate", "grass": "soft grass and packed earth",
            "snow": "deep crunchy snow", "water": "shallow water, splashing"}
_STEP = ["left foot, heel first, firm and heavy", "right foot, flat heavy planting with a small scuff",
         "left foot, slightly lighter and slower", "right foot, heavy deliberate stomp",
         "left foot, a short step with weight shifting forward", "right foot, a heavy step with the toe dragging a little"]
for _s, _d in _SURFACE.items():
    add("step_" + _s, 1.0, ["One single footstep of a knight in full steel plate armour on %s: %s, one step only, "
                            "heavy armoured boot, subtle armour plate creak and chain mail jingle after the impact." % (_d, v) for v in _STEP])
add("jingle", 1.0, [
    "Subtle quiet rattle of chainmail and steel plates as an armoured knight shifts weight, no footstep.",
    "A small jangle of armour straps and plates, a soft metallic shiver, very quiet.",
    "Light chain mail links shifting and steel plate scraping softly, a gentle armour movement.",
    "A brief quiet clink and creak of plate armour and leather buckles."])
add("shield_hit", 1.5, [
    "A sword strike on a metal-rimmed wooden shield, a heavy boom thud with an iron rim clank.",
    "A heavy blow landing on a shield, deep wooden thump and a bright metal rim rattle.",
    "A blade chopping into a round shield, dull wooden impact with short metallic ring."])
add("draw", 1.5, [
    "A sword being drawn from a leather scabbard, a smooth metallic slide ending in a soft ring.",
    "A longsword unsheathed quickly, steel scraping against leather and the throat of the scabbard."])
add("sheath", 1.5, [
    "A sword sliding back into a leather scabbard, a slow metal scrape ending in a soft final click."])
add("body_fall", 2.0, [
    "A heavy armoured knight collapsing onto a stone floor, a single crash of steel plate armour, then clatter.",
    "A fully armoured body falling to the ground, heavy thud and rattling steel plates settling."])
add("rustle", 1.0, [
    "Cloth and light leather armour rustling in a quick dodge sidestep, a soft fabric swish with a faint buckle clink.",
    "A fast evasive move, cloak and leather armour movement, a brief cloth rustle with a hint of chain jingle."])
add("roll", 1.5, [
    "An armoured knight performing a combat roll on the ground, cloth and plate scraping, ending in a dull thump.",
    "A forward roll in light armour, a rolling scrape of cloth and metal across stone, short landing thud."])

PREFIX = {s: s for s in FAM}      # family -> pool file prefix (stem = prefix_N)
COUNT = {f: sum(1 for x in FILES if x[1] == f) for f in FAM}
BY_STEM = {x[0]: x for x in FILES}

# ---------------------------------------------------------------- cost and the CLI
RATE = {"mirelo_text_to_audio": 0.25}       # credits per second, measured with `generate cost` (1 s 0.25, 5 s 1.25, 10 s 2.5)
_cost_cache = {}
def hf(*args, timeout=90):
    try:
        r = subprocess.run(["higgsfield"] + list(args), capture_output=True, text=True, timeout=timeout, stdin=subprocess.DEVNULL)
        return r.returncode == 0, r.stdout, (r.stderr or "")[-200:]
    except subprocess.TimeoutExpired:
        return False, "", "cli timeout"
    except OSError as e:
        return False, "", str(e)

def hf_json(*args, timeout=90):
    ok, out, err = hf(*args, "--json", timeout=timeout)
    try:
        return json.loads(out) if out.strip() else None, err
    except ValueError:
        return None, (out + err)[-200:]

def model_args(model, prompt, dur):
    if model == "seed_audio":
        return ["--prompt", prompt, "--format", "wav", "--sample_rate", "44100"]
    return ["--prompt", prompt, "--duration", str(dur)]

def cost(stem, live=True):
    """Credits for one file: asked of `higgsfield generate cost` (free, creates no job), else the measured rate."""
    _, fam, prompt, dur = BY_STEM[stem]
    model = FAM[fam][3]
    key = (model, dur if model in RATE else prompt)
    if key not in _cost_cache:
        c = None
        if live:
            j, _ = hf_json("generate", "cost", model, *model_args(model, prompt, dur))
            if isinstance(j, dict) and "credits" in j:
                c = float(j["credits"])
        _cost_cache[key] = c if c is not None else RATE.get(model, 1.1) * dur
    return _cost_cache[key]

def load_json(p, default):
    return json.load(open(p)) if os.path.exists(p) else default
def save_json(p, d):
    json.dump(d, open(p + ".tmp", "w"), indent=1, sort_keys=True)
    os.replace(p + ".tmp", p)

def phash(stem):
    x = BY_STEM[stem]
    return hashlib.sha1(("%s|%s|%s" % (FAM[x[1]][3], x[2], x[3])).encode()).hexdigest()[:12]

def find_recent(stem):
    """A job for exactly this prompt that the account already holds and paid for (the answer to a create may have been lost)."""
    x = BY_STEM[stem]
    jobs, _ = hf_json("generate", "list", "--audio", "--size", "60")
    for j in jobs or []:
        if j.get("job_type") == FAM[x[1]][3] and (j.get("params") or {}).get("prompt") == x[2] \
                and j.get("status") not in ("failed", "nsfw", "canceled", "cancelled"):
            return j["id"]
    return None

def create(stem):
    x = BY_STEM[stem]; model = FAM[x[1]][3]
    out, err = hf_json("generate", "create", model, *model_args(model, x[2], x[3]), timeout=120)
    if isinstance(out, list) and out and isinstance(out[0], str):
        return out[0], ""
    if isinstance(out, list) and out and isinstance(out[0], dict) and out[0].get("id"):
        return out[0]["id"], ""
    if isinstance(out, dict) and out.get("id"):
        return out["id"], ""
    time.sleep(4)
    jid = find_recent(stem)
    return jid, ("recovered after: " if jid else "") + (err or str(out))[-200:]

def wait(jid, seconds=300):
    t0 = time.time(); status = "unknown"
    while time.time() - t0 < seconds:
        j, _ = hf_json("generate", "get", jid, timeout=60)
        if isinstance(j, dict):
            status = j.get("status", "unknown")
            if status == "completed" and j.get("result_url"):
                return status, j["result_url"]
            if status in ("failed", "nsfw", "canceled", "cancelled"):
                return status, ""
        time.sleep(4)
    return "pending:" + status, ""

def master_path(stem):
    for f in sorted(os.listdir(MASTERS)) if os.path.isdir(MASTERS) else []:
        if f.rsplit(".", 1)[0] == stem:
            return os.path.join(MASTERS, f)
    return None

# ---------------------------------------------------------------- audio
def decode(path):
    r = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                       capture_output=True, stdin=subprocess.DEVNULL)
    return np.frombuffer(r.stdout, dtype="<f4").astype(float)

def momentary_max(x):
    from gen_audio_combat import momentary_max as mm
    return mm(x)

def envelope(x, ms=4.0):
    return uniform_filter1d(np.abs(x), max(1, int(ms * SR / 1000)))

def events(x):
    """Segments of x, one per separate strike: (start, end, peak) with boundaries at the quietest point between strikes.
    A ringing tail decays smoothly and stays one event; a second strike needs its own prominent envelope peak 120 ms or
    more later."""
    e = envelope(x); m = e.max()
    if m <= 0:
        return []
    pk, _ = signal.find_peaks(e, height=0.2 * m, distance=int(0.12 * SR), prominence=0.12 * m)
    if len(pk) == 0:
        pk = np.array([int(np.argmax(e))])
    cuts = [0] + [int(a + np.argmin(e[a:b])) for a, b in zip(pk[:-1], pk[1:])] + [len(x)]
    return [(cuts[i], cuts[i + 1], float(np.abs(x[cuts[i]:cuts[i + 1]]).max())) for i in range(len(pk))]

def shape(seg, fam):
    """lead and tail trim, fade, level. Returns float array with PREROLL of silence in front, or None if empty."""
    tgt, maxlen, fade_ms, _ = FAM[fam]
    seg = seg - np.mean(seg)
    pk = np.abs(seg).max()
    if pk < 1e-4:
        return None
    on = int(np.argmax(np.abs(seg) > 0.03 * pk))
    seg = seg[max(0, on - int(0.001 * SR)):]
    env = uniform_filter1d(np.abs(seg), int(0.02 * SR))
    live = np.nonzero(env > 0.01 * env.max())[0]            # tail: until 40 dB under the loudest part
    seg = seg[:int(live[-1]) + 1] if len(live) else seg
    seg = seg[:int(maxlen * SR)]
    fo = min(int(fade_ms * SR / 1000), len(seg) // 2)
    if fo > 1:
        seg[-fo:] *= np.linspace(1, 0, fo) ** 1.5
    ramp = int(0.0007 * SR)
    seg[:ramp] *= np.linspace(0, 1, ramp)
    seg = seg / np.abs(seg).max()
    g = 10 ** ((tgt - momentary_max(seg)) / 20)
    cap = 10 ** (PEAK_CAP_DB / 20)
    g = min(g, cap)
    return np.concatenate([np.zeros(int(PREROLL * SR)), seg * g])

def write_wav(path, x):
    wavfile.write(path, SR, np.round(np.clip(x, -1, 1) * 32767).astype(np.int16))

def clean_extras(x, evs, main):
    out = []
    e = envelope(x)
    for k, (a, b, p) in enumerate(evs):
        if k == main or len(out) >= MAX_EXTRA:
            continue
        if p < 0.3 * evs[main][2] or b - a < int(0.06 * SR):
            continue
        if a > 0 and e[a] > 0.2 * p:                       # starts inside the previous sound's tail: not clean
            continue
        if p >= 0.99:
            continue
        out.append(k)
    return out

# ---------------------------------------------------------------- post-processing
def post(only):
    os.makedirs(BACKUP, exist_ok=True)
    gd = os.path.join(BACKUP, ".gdignore")
    if not os.path.exists(gd):
        open(gd, "w").close()
    state = load_json(POST_PATH, {"written": [], "extras": {}})
    for name in state["extras"]:                           # extras are rebuilt from scratch each time so numbering stays contiguous
        p = os.path.join(SFX, name + ".wav")
        if os.path.exists(p):
            os.remove(p)
    state["written"] = [w for w in state["written"] if w not in state["extras"]]
    state["extras"] = {}
    nxt = dict(COUNT)
    done = 0
    for stem, fam, _, _ in FILES:
        if only and fam not in only and stem not in only:
            continue
        m = master_path(stem)
        if not m:
            continue
        x = decode(m)
        evs = events(x) if len(x) else []
        if not evs:
            print("%-18s empty or silent master, left as it was" % stem); continue
        main = int(np.argmax([p for _, _, p in evs]))
        y = shape(x[evs[main][0]:evs[main][1]], fam)
        if y is None:
            print("%-18s silent, left as it was" % stem); continue
        dst = os.path.join(SFX, stem + ".wav"); bk = os.path.join(BACKUP, stem + ".wav")
        if os.path.exists(dst) and not os.path.exists(bk) and stem not in state["written"]:
            shutil.copy2(dst, bk)
        write_wav(dst, y)
        if stem not in state["written"]:
            state["written"].append(stem)
        note = ""
        for k in clean_extras(x, evs, main):
            z = shape(x[evs[k][0]:evs[k][1]], fam)
            if z is None:
                continue
            nxt[fam] += 1
            name = "%s_%d" % (PREFIX[fam], nxt[fam])
            write_wav(os.path.join(SFX, name + ".wav"), z)
            state["extras"][name] = stem; state["written"].append(name)
            note += " +%s" % name
        done += 1
        print("%-18s %d event%s, kept #%d, %.2f s%s" % (stem, len(evs), "s" if len(evs) > 1 else "", main + 1, len(y) / SR, note))
        save_json(POST_PATH, state)
    save_json(POST_PATH, state)
    print("post-processed %d files; run tools/check.sh once so Godot imports the new files" % done)

def restore():
    state = load_json(POST_PATH, {"written": [], "extras": {}})
    n = 0
    for f in sorted(os.listdir(BACKUP)) if os.path.isdir(BACKUP) else []:
        if f.endswith(".wav"):
            shutil.copy2(os.path.join(BACKUP, f), os.path.join(SFX, f)); n += 1
    removed = 0
    for name in state["written"]:
        if not os.path.exists(os.path.join(BACKUP, name + ".wav")) and os.path.exists(os.path.join(SFX, name + ".wav")):
            os.remove(os.path.join(SFX, name + ".wav")); removed += 1
    save_json(POST_PATH, {"written": [], "extras": {}})
    print("restored %d synthesised files, removed %d generated-only files (Godot drops their orphaned .import files on the next import)" % (n, removed))

# ---------------------------------------------------------------- report
def family_of(stem):
    m = re.match(r"(.+)_\d+$", stem)
    return m.group(1) if m and m.group(1) in FAM else None

def centroid(x):
    s = np.abs(np.fft.rfft(x)) ** 2; f = np.fft.rfftfreq(len(x), 1 / SR)
    return float((s * f).sum() / (s.sum() + 1e-12))

def tonal_score(x):
    """Fraction of loud frames whose strongest spectral peak is far above the floor AND has a harmonic partner at 2f and 3f.
    Metal rings are inharmonic, so a high score suggests sustained pitched content (music, a voice, a hum)."""
    n = 4096; hop = 2048
    if len(x) < n * 2:
        return 0.0, 0
    w = np.hanning(n); fr = np.fft.rfftfreq(n, 1 / SR)
    frames = [np.abs(np.fft.rfft(x[i:i + n] * w)) for i in range(0, len(x) - n, hop)]
    top = max(f.max() for f in frames)
    hits = tot = 0
    for f in frames:
        if f.max() < top * 10 ** (-40 / 20):
            continue
        tot += 1
        med = np.median(f) + 1e-9; k = int(np.argmax(f[3:n // 6])) + 3
        if f[k] / med < 10 ** (25 / 20):
            continue
        ok = all(f[max(0, k * h - 2):k * h + 3].max() / med > 10 ** (15 / 20) for h in (2, 3) if k * h + 3 < len(f))
        hits += ok
    return (hits / tot if tot else 0.0), tot

def flags(x, fam, final):
    pk = np.abs(x).max()
    out = []
    if pk >= 0.995 or (np.abs(x) >= 0.99 * pk).sum() >= 4 and pk >= 0.98:
        out.append("CLIPPED")
    if pk < 10 ** (-30 / 20):
        out.append("NEAR-SILENT")
    maxlen = FAM[fam][1] if fam else 3.0
    env = uniform_filter1d(np.abs(x), int(0.02 * SR)); live = np.nonzero(env > 0.01 * (env.max() + 1e-12))[0]
    sound_len = (live[-1] - live[0]) / SR if len(live) else 0.0
    if sound_len > maxlen * (1.0 if final else 1.6):
        out.append("TOO-LONG(%.2fs)" % sound_len)
    if len(events(x)) > 1:
        out.append("MULTI-EVENT(%d)" % len(events(x)))
    sc, tot = tonal_score(x)
    if sc >= 0.5 and tot >= 6:
        out.append("TONAL?(%.0f%%)" % (sc * 100))
    return out

def report(raw):
    print("%-20s%7s%9s%8s%13s  flags" % ("file", "dur s", "peak dB", "LUFS-M", "centroid Hz"))
    names = []
    if raw:
        names = [(f.rsplit(".", 1)[0], os.path.join(MASTERS, f)) for f in sorted(os.listdir(MASTERS))] if os.path.isdir(MASTERS) else []
    else:
        post_state = load_json(POST_PATH, {"written": []})
        names = [(n, os.path.join(SFX, n + ".wav")) for n in post_state["written"] if os.path.exists(os.path.join(SFX, n + ".wav"))]
        names.sort(key=lambda t: (family_of(t[0]) or "", int(t[0].rsplit("_", 1)[1])))
    bad = 0
    for stem, p in names:
        x = decode(p)
        if not len(x):
            print("%-20s unreadable" % stem); continue
        fam = family_of(stem)
        fl = flags(x, fam, not raw)
        bad += bool(fl)
        pk = 20 * np.log10(np.abs(x).max() + 1e-9)
        print("%-20s%7.2f%9.1f%8.1f%13.0f  %s" % (stem, len(x) / SR, pk, momentary_max(x), centroid(x), " ".join(fl)))
    print("%d files, %d with flags (a flag is a reason to listen, not a verdict)" % (len(names), bad))

# ---------------------------------------------------------------- run
def wanted(only):
    return [x for x in FILES if not only or x[1] in only or x[0] in only]

def main():
    only = [s for s in opt("only", "").split(",") if s]
    unknown = [s for s in only if s not in FAM and s not in BY_STEM]
    if unknown:
        sys.exit("unknown --only name(s): %s" % ", ".join(unknown))
    ceiling = float(opt("ceiling", "300")); limit = int(opt("limit", "100000"))
    if opt("report") is not None:
        return report(opt("report") == "raw")
    if "--restore" in ARGS:
        return restore()
    if "--post" in ARGS:
        return post(only)
    jobs = load_json(JOBS_PATH, {})
    paid = lambda: sum(float(j.get("credits", 0)) for j in jobs.values() if j.get("status") != "failed")
    rows = wanted(only)
    todo = [x for x in rows if not master_path(x[0])]
    if "--plan" in ARGS:
        print("%-18s %-22s %5s %8s  %s" % ("file", "model", "sec", "credits", "state"))
        total = 0.0
        for stem, fam, prompt, dur in rows:
            c = cost(stem)
            rec = jobs.get(stem)
            state = "have master" if master_path(stem) else ("job recorded (%s), collect free" % rec["status"] if rec and rec.get("hash") == phash(stem)
                                                              and rec.get("status") != "failed" else "to buy")
            if state == "to buy":
                total += c
            print("%-18s %-22s %5.1f %8.2f  %s" % (stem, FAM[fam][3], dur, c, state))
        fams = {}
        for stem, fam, _, _ in rows:
            fams[fam] = fams.get(fam, 0) + 1
        print("\n%d files (%s)" % (len(rows), ", ".join("%s %d" % kv for kv in fams.items())))
        print("still to pay: %.2f credits (about $%.2f at 1 credit = $0.01); paid so far by this tool: %.2f; ceiling %.0f" % (total, total / 100, paid(), ceiling))
        print("(each credit figure is the answer of `higgsfield generate cost`; no job was created)")
        return
    os.makedirs(MASTERS, exist_ok=True)
    done = 0
    for stem, fam, prompt, dur in todo[:limit]:
        try:
            rec = jobs.get(stem)
            if not (rec and rec.get("hash") == phash(stem) and rec.get("status") != "failed"):
                if rec:
                    jobs.setdefault("_superseded", []).append(dict(rec, file=stem))
                c = cost(stem)
                if paid() + c > ceiling:
                    print(stem, "NOT RECORDED: ceiling of %.0f credits reached (%.2f paid)" % (ceiling, paid()), flush=True)
                    continue
                jid, note = create(stem)
                if not jid:
                    print(stem, "FAILED to create:", note.replace("\n", " "), flush=True)
                    continue
                rec = {"id": jid, "model": FAM[fam][3], "hash": phash(stem), "status": "created", "credits": c, "seconds": dur}
                jobs[stem] = rec; save_json(JOBS_PATH, jobs)
            status, url = wait(rec["id"])
            if not url:
                rec["status"] = "failed" if not status.startswith("pending") else "pending"
                rec["note"] = status
                if rec["status"] == "failed":
                    rec["credits"] = 0                  # the service does not charge a failed job
                save_json(JOBS_PATH, jobs)
                print(stem, "NOT DONE:", status, ("(job %s kept; run again to collect it)" % rec["id"]) if rec["status"] == "pending" else "", flush=True)
                continue
            ext = os.path.splitext(url.split("?")[0])[1] or ".wav"
            raw = os.path.join(MASTERS, stem + ext)
            r = subprocess.run(["curl", "-sS", "-f", "--retry", "3", "-m", "120", "-o", raw, url], capture_output=True, text=True, stdin=subprocess.DEVNULL)
            if r.returncode != 0:
                rec["status"] = "pending"; save_json(JOBS_PATH, jobs)
                print(stem, "DOWNLOAD FAILED (job %s is paid and kept; run again):" % rec["id"], r.stderr[-120:], flush=True)
                continue
            rec["status"] = "done"; save_json(JOBS_PATH, jobs)
            done += 1
            print("%s ok (job %s, %.2f credits)" % (stem, rec["id"], rec["credits"]), flush=True)
        except Exception as e:                           # one bad file must not end the run
            print(stem, "ERROR", repr(e)[:200], flush=True)
    print("collected %d; %.2f credits recorded in all" % (done, paid()), flush=True)
    post(only)

if __name__ == "__main__":
    main()
