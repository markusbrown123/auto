#!/usr/bin/env python3
"""Records the voice lines of data/dialogue.json through the Higgsfield CLI into assets/audio/vo/.

Cast, pitch and stability come from data/dialogue.json ("voices", "voice_pitch", "voice_stability"), which
tools/gen_dialogue.py writes from tools/cast_final.json. "inworld:<voice>" = inworld_text_to_speech (about 2 credits a
take); a bare name = a preset on elevenlabs_v4 (about 0.46).

What is recorded: every line of every scene that is not a secret (kind "secret" stays text only), whose take is missing
or was made from other words (assets/audio/vo/takes.json: file -> hash of the text). The archivist is left alone.
The knight's lines are recorded per body (<line>_m / <line>_f) with the voice of the line's "cast" (player, forebear,
heir); the Kept likewise, plus <line>.ogg (the male take), which is the file the game plays for it today.

Rules this follows: one speech job at a time, stdin closed, every job id written to assets/audio/vo/jobs.json BEFORE
waiting on it, so a run that dies or times out picks the paid job up again instead of paying twice; a job is also looked
for in the account's recent jobs before a new one is created. A network error fails that line, not the run.
Pitch is lowered once, here, and noted in lowered.json. Loudness is set by measurement to the median of the earlier takes.

Usage: tools/voices.py [scene_id ...] [--plan] [--only=role,role] [--ceiling=220] [--limit=N] [--files=a.ogg,b.ogg]
Nobody has listened to anything this makes."""
import hashlib, json, os, re, shutil, subprocess, sys, tempfile, time

VO = "assets/audio/vo"
D = json.load(open("data/dialogue.json"))
ARGS = [a for a in sys.argv[1:] if a.startswith("--")]
def opt(name, default=None):
    for a in ARGS:
        if a.startswith("--%s=" % name):
            return a.split("=", 1)[1]
    return default
PLAN = "--plan" in ARGS
CEILING = float(opt("ceiling", "220"))
LIMIT = int(opt("limit", "100000"))
ONLY = opt("only", "").split(",") if opt("only") else []
COST = {"inworld": 2.0, "eleven": 0.46}
TARGET_LUFS, PEAK_DB = -18.4, -1.8          # measured on the 246 earlier takes: median -18.3/-18.4 LUFS, peaks to about -1.5 dBFS

# the same light room as the earlier takes: a little weight, two quiet early reflections, the voice itself untouched
ROOM = "bass=g=2.5:f=150,aecho=0.9:0.35:55|110:0.16|0.08"
# the female knight (owner's choice): presence up, low-mids down, lighter room
CLEAR = "highpass=f=90,equalizer=f=3500:t=q:w=1.2:g=4.5,equalizer=f=250:t=q:w=1.0:g=-2,treble=g=1.5:f=7000,aecho=0.9:0.22:45|95:0.10|0.05"
# Female knight (owner, 2026-11-27): her original voice behind a space-helmet filter, option 3 made a little softer.
HELM_F = "highpass=f=200,lowpass=f=5400,equalizer=f=1600:t=q:w=0.8:g=3,acompressor=threshold=0.12:ratio=3:attack=5:release=60,aecho=1.0:0.85:5|9|14:0.27|0.19|0.11,aecho=0.9:0.25:40:0.08,loudnorm=I=-18:TP=-2"
SLOW = ",atempo=0.93"                        # the Kept: "a voice the player knows, slowed"
# The male knight's post chain (bass + room + loudnorm, as the approved audition). The pre-treatment master of every take of
# these roles (after pitch and tempo, before this chain) is kept in MASTERS, so a changed chain is applied by
# `tools/voices.py --post` alone: no paid job is ever repeated for it.
PLAYER_M_FX = json.load(open("tools/cast_final.json"))["player_m"]["fx"]
STERLING_FX = PLAYER_M_FX
MASTER_ROLES = ("player_m", "kept_m", "effort_m")
MASTERS = "art/vo_masters/player_m"          # lossless wav, gitignored
ROLE_FX = {
 "player_f": CLEAR + "," + HELM_F, "witness": ROOM + ",aecho=0.9:0.25:11:0.12", "narrator": "bass=g=2:f=150,aecho=0.9:0.4:80|170:0.18|0.1",
 "player_m": STERLING_FX, "kept_m": STERLING_FX + SLOW, "kept_f": CLEAR + SLOW + "," + HELM_F,   # male knight: Sterling (cast_final.json), the Kept's extra 7% on top
 # the Widow (tools/cast_final.json): bass +2 at 160 Hz, presence +2.5 at 2.8 kHz, light room
 "widow": "bass=g=2:f=160,equalizer=f=2800:t=q:w=1.2:g=2.5,aecho=0.9:0.35:55|110:0.16|0.08",
 "devourer": "aecho=0.8:0.8:60|130|210:0.4|0.3|0.2,chorus=0.6:0.9:55|70:0.4|0.3:0.25|0.4:2|1.3",
}

def load(name, default):
    p = os.path.join(VO, name)
    return json.load(open(p)) if os.path.exists(p) else default
def save(name, data):
    p = os.path.join(VO, name)
    json.dump(data, open(p + ".tmp", "w"), indent=1, sort_keys=True)
    os.replace(p + ".tmp", p)
TAKES = load("takes.json", {})       # file -> hash of the text it was recorded from
LOWERED = load("lowered.json", {})   # file -> semitones already applied (never apply twice)
JOBS = load("jobs.json", {})         # file -> {id, model, voice, hash, status, credits}: every job ever paid for here

def text_hash(line):
    return hashlib.sha1(line["text"].encode()).hexdigest()[:12]

def hf(*args, timeout=90):
    """One CLI call. Never raises: returns (ok, stdout, stderr-tail)."""
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

_ids = None
def eleven_voice(name):
    global _ids
    if _ids is None:
        raw, _ = hf_json("voices", "list")
        items = (raw.get("items", raw.get("voices", [])) if isinstance(raw, dict) else raw) or []
        _ids = {v["name"]: v for v in items}
    return _ids.get(name)

def same_job(j, model, voice, text, stability):
    p = j.get("params") or {}
    if model == "inworld":
        return j.get("job_type") == "inworld_text_to_speech" and p.get("prompt") == text and p.get("voice") == voice
    d = p.get("dialogue") or [{}]
    return (j.get("job_type") == "elevenlabs_v4" and len(d) == 1 and d[0].get("text") == text
            and [v.get("name") for v in p.get("voices") or []] == [voice] and p.get("stability") == stability)

def find_recent(model, voice, text, stability):
    """A job for exactly this take that the account already holds (and has paid for), newest first."""
    jobs, _ = hf_json("generate", "list", "--audio", "--size", "40")
    for j in jobs or []:
        if same_job(j, model, voice, text, stability) and j.get("status") not in ("failed", "nsfw", "canceled", "cancelled"):
            return j["id"]
    return None

def create(model, voice, text, stability):
    if model == "inworld":
        args = ["generate", "create", "inworld_text_to_speech", "--prompt", text, "--voice", voice]
    else:
        v = eleven_voice(voice)
        if v is None:
            return None, "no preset voice called " + voice
        f = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False)
        json.dump([{"text": text, "voice_id": v["id"], "voice_type": v["voice_type"]}], f); f.close()
        args = ["generate", "create", "elevenlabs_v4", "--dialogue", "@" + f.name] + (["--stability", str(stability)] if stability is not None else [])
    out, err = hf_json(*args, timeout=120)
    if isinstance(out, list) and out and isinstance(out[0], str):
        return out[0], ""
    if isinstance(out, list) and out and isinstance(out[0], dict) and out[0].get("id"):
        return out[0]["id"], ""
    # the call may have reached the service even though its answer did not reach us: look before paying again
    time.sleep(4)
    jid = find_recent(model, voice, text, stability)
    return jid, ("recovered after: " if jid else "") + (err or str(out))[-200:]

def wait(jid, seconds=300):
    """Polls one job. Returns (status, url)."""
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

def lufs(path):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"], capture_output=True, text=True).stderr
    i = re.findall(r"I:\s+(-?[\d.]+) LUFS", r); pk = re.findall(r"Peak:\s+(-?[\d.]+) dBFS", r)
    return (float(i[-1]) if i else -70.0), (float(pk[-1]) if pk else 0.0)

def pre_chain(role):
    st = D.get("voice_pitch", {}).get(role, 0)
    tempo = D.get("voice_tempo", {}).get(role, 1.0)
    return ["rubberband=pitch=%.5f:tempo=%.4f:formant=preserved" % (2 ** (st / 12.0), tempo)] if st or tempo != 1.0 else []

def finish(src, out, role, base):
    """src (wav) -> the role's room/fx -> loudness by measurement -> ogg, as the earlier takes are."""
    fx = ROLE_FX.get(role, ROLE_FX.get(base, ROOM))
    wav = out + ".wav"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-af", fx, "-ac", "1", "-ar", "44100", wav], check=True)
    i, pk = lufs(wav)
    if i < -60:                                   # too short for a gated measurement: level it by its peak instead
        gain = (PEAK_DB - 3.0) - pk
    else:
        gain = TARGET_LUFS - i
    # the limiter only catches the few peaks a loudness match pushes over; it is not there to squash
    for _ in range(3):                            # a peaky take loses level to the limiter: measure the result and correct
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-af", "volume=%.2fdB,alimiter=limit=%.4f:level=false:attack=3:release=60" % (gain, 10 ** (PEAK_DB / 20.0)),
                        "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5", out], check=True)
        got = lufs(out)[0]
        if i < -60 or abs(got - TARGET_LUFS) <= 0.4 or gain - (TARGET_LUFS - i) > 4.0:
            break
        gain += TARGET_LUFS - got
    os.remove(wav)
    return lufs(out)

def master(raw, out, role, base):
    """pitch + tempo (once) -> [master kept] -> the role's fx -> loudness by measurement -> ogg."""
    st = D.get("voice_pitch", {}).get(role, 0)
    pre = out + ".pre.wav"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw] + (["-af", ",".join(pre_chain(role))] if pre_chain(role) else []) + ["-ac", "1", "-ar", "44100", pre], check=True)
    if role in MASTER_ROLES:
        os.makedirs(MASTERS, exist_ok=True)
        shutil.copy(pre, os.path.join(MASTERS, os.path.basename(out)[:-4] + ".wav"))
    res = finish(pre, out, role, base)
    os.remove(pre)
    if st:
        LOWERED[os.path.basename(out)] = st
        save("lowered.json", LOWERED)
    elif os.path.basename(out) in LOWERED:
        del LOWERED[os.path.basename(out)]
        save("lowered.json", LOWERED)
    return res

# ---------------------------------------------------------------- what is wanted
def priority(sid):
    """Generation I, then II up to the first guardian, then the rest of II, then III."""
    g3 = sid.startswith(("gen3_", "kept_", "monarch_g3", "facility", "final_door", "devourer")) or sid.endswith("_g3")
    if sid.startswith("gen1_"):
        return 0
    if g3:
        return 3
    early = sid.startswith(("opening", "awakening", "first_road", "gen2_arrive", "courtyard", "sentinel", "witness_discovery", "w_courtyard", "w_sentinel"))
    return 1 if early else 2

def model_of(role):
    c = D["voices"][role]
    return ("inworld", c[8:]) if c.startswith("inworld:") else ("eleven", c)

# --files=a.ogg,b.ogg: only these takes (an audition of a few lines from larger scenes)
FILES = set(next((x[8:].split(",") for x in ARGS if x.startswith("--files=")), []))
jobs = []          # (line id, role, base speaker, file)
wanted = [a for a in sys.argv[1:] if not a.startswith("--")] or list(D["scenes"])
seen = set()
for sid in sorted(wanted, key=lambda s: (priority(s), list(D["scenes"]).index(s))):
    if D["scenes"][sid].get("kind") == "secret":
        continue      # found-secret lines are text only by design (tests/secrets.gd)
    for lid in D["scenes"][sid]["lines"]:
        line = D["lines"][lid]; sp = line["speaker"]
        if sp == "archivist":
            continue  # provisional voice, not in the owner's cast: its four takes are left as they are
        if sp == "player" or line.get("by_body"):
            cast = line.get("cast", sp)
            roles = [(cast + "_" + b, "_" + b) for b in (["m", "f"] if "body" not in line else [line["body"]])]
        else:
            roles = [(sp, "")]
        for role, suffix in roles:
            f = "%s%s.ogg" % (lid, suffix)
            if role not in D["voices"] or f in seen or (ONLY and role not in ONLY) or (FILES and f not in FILES):
                continue
            seen.add(f)
            recast = bool(ONLY) and JOBS.get(f, {}).get("voice") != model_of(role)[1]   # --only=: a take made with another voice is redone
            if not os.path.exists(os.path.join(VO, f)) or TAKES.get(f) != text_hash(line) or recast:
                jobs.append((lid, role, sp, f, sid))

def paid():
    recs = [j for k, j in JOBS.items() if k != "_superseded"] + list(JOBS.get("_superseded", []))
    return sum(float(j.get("credits", 0)) for j in recs if j.get("status") != "failed")

def has_job(lid, role, f):
    rec = JOBS.get(f)
    return bool(rec and rec.get("hash") == text_hash(D["lines"][lid]) and rec.get("voice") == model_of(role)[1] and rec.get("status") != "failed")
plan = sum(COST[model_of(r)[0]] for lid, r, _, f, _ in jobs if not has_job(lid, r, f))
print("%d takes wanted; about %.1f credits still to pay; %.1f paid so far by this tool; ceiling %.0f" % (len(jobs), plan, paid(), CEILING), flush=True)
if PLAN:
    for lid, role, sp, f, sid in jobs:
        print("  %-28s %-12s %-18s %s" % (f, role, D["voices"][role], D["lines"][lid]["text"][:70]))
    sys.exit(0)

if "--post" in ARGS:
    # re-run only the post chain (ROLE_FX) over the kept masters: no CLI, no paid job. Efforts take their role from the file name.
    for w in sorted(os.listdir(MASTERS)) if os.path.isdir(MASTERS) else []:
        f = w[:-4] + ".ogg"
        role = "effort_m" if f.startswith("efforts_m_") else ("kept_m" if f.startswith("kept_") else "player_m")
        i, pk = finish(os.path.join(MASTERS, w), os.path.join(VO, f), role, role)
        if f in JOBS:
            JOBS[f]["lufs"], JOBS[f]["peak"] = i, pk
        print("%s post %.1f LUFS peak %.1f" % (f, i, pk), flush=True)
    save("jobs.json", JOBS)
    sys.exit(0)

if "--remaster" in ARGS:
    # takes this tool made whose measured level is off: fetch the paid job's audio again (free) and master it again
    for f, rec in sorted(JOBS.items()):
        if f == "_superseded" or rec.get("status") != "done" or abs(rec.get("lufs", TARGET_LUFS) - TARGET_LUFS) <= 0.5:
            continue
        lid = f[:-4] if f[:-4] in D["lines"] else f[:-6]
        if TAKES.get(f) != rec["hash"] or lid not in D["lines"]:
            continue
        status, url = wait(rec["id"], 30)
        raw = os.path.join(VO, f + ".src")
        if not url or subprocess.run(["curl", "-sS", "-f", "--retry", "3", "-m", "120", "-o", raw, url]).returncode != 0:
            print(f, "could not fetch", status, flush=True); continue
        before = rec["lufs"]
        rec["lufs"], rec["peak"] = master(raw, os.path.join(VO, f), rec["role"], D["lines"][lid]["speaker"])
        os.remove(raw); save("jobs.json", JOBS)
        if D["lines"][lid].get("by_body") and f.endswith("_m.ogg"):
            shutil.copy(os.path.join(VO, f), os.path.join(VO, lid + ".ogg"))
        print("%s remastered %.1f -> %.1f LUFS peak %.1f" % (f, before, rec["lufs"], rec["peak"]), flush=True)
    sys.exit(0)

done = 0
for lid, role, sp, f, sid in jobs[:LIMIT]:
    line = D["lines"][lid]; h = text_hash(line); out = os.path.join(VO, f)
    model, voice = model_of(role)
    stability = D.get("voice_stability", {}).get(role) if model == "eleven" else None
    try:
        rec = JOBS.get(f)
        if not (rec and rec.get("hash") == h and rec.get("voice") == voice and rec.get("status") != "failed"):
            if rec:       # a take of other words or another voice: keep the record of what was paid
                JOBS.setdefault("_superseded", []).append(dict(rec, file=f))
            if paid() + COST[model] > CEILING:
                print(f, "NOT RECORDED: ceiling of %.0f credits reached (%.1f paid)" % (CEILING, paid()), flush=True)
                continue
            jid, note = create(model, voice, line["text"], stability)
            if not jid:
                print(f, "FAILED to create:", note.replace("\n", " "), flush=True)
                continue
            rec = {"id": jid, "model": model, "voice": voice, "hash": h, "status": "created", "credits": COST[model], "role": role}
            JOBS[f] = rec; save("jobs.json", JOBS)
        status, url = wait(rec["id"])
        if not url:
            rec["status"] = "failed" if not status.startswith("pending") else "pending"
            rec["note"] = status
            if rec["status"] == "failed":
                rec["credits"] = 0        # the service does not charge for a job that fails
            save("jobs.json", JOBS)
            print(f, "NOT DONE:", status, "(job %s kept; run again to collect it)" % rec["id"] if rec["status"] == "pending" else "", flush=True)
            continue
        raw = out + ".src"
        r = subprocess.run(["curl", "-sS", "-f", "--retry", "3", "-m", "120", "-o", raw, url], capture_output=True, text=True)
        if r.returncode != 0:
            rec["status"] = "pending"; save("jobs.json", JOBS)
            print(f, "DOWNLOAD FAILED (job %s is paid and kept; run again):" % rec["id"], r.stderr[-120:], flush=True)
            continue
        i, pk = master(raw, out, role, sp)
        os.remove(raw)
        rec["status"] = "done"; rec["lufs"] = i; rec["peak"] = pk; save("jobs.json", JOBS)
        TAKES.update(load("takes.json", {})); TAKES[f] = h
        if line.get("by_body") and f.endswith("_m.ogg"):       # the file the game plays for this speaker today
            shutil.copy(out, os.path.join(VO, lid + ".ogg")); TAKES[lid + ".ogg"] = h
            if f in LOWERED:
                LOWERED[lid + ".ogg"] = LOWERED[f]; save("lowered.json", LOWERED)
        save("takes.json", TAKES)
        done += 1
        print("%s ok  %s %s  %.1f LUFS peak %.1f" % (f, role, voice, i, pk), flush=True)
    except Exception as e:                                      # one bad line must not end the run
        print(f, "ERROR", repr(e)[:200], flush=True)
print("recorded %d; %.1f credits paid by this tool in all" % (done, paid()), flush=True)
