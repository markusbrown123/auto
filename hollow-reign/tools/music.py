#!/usr/bin/env python3
"""Original soundtrack cues through Higgsfield (ElevenLabs Music, about 9 credits a minute).
Each cue is instrumental, then made loopable by cross-fading its tail into its head.
Usage: tools/music.py [name ...]   (no arguments = every cue not yet produced)"""
import os, subprocess, sys
MOTIF = ("Built on one recurring original motif: a slow rising four-note figure on solo cello that falls back by a step, "
         "as if remembering something and losing it. Original composition, no vocals with words.")
CUES = {
 "theme": (95, "Main theme for a dark sci-fantasy epic. Opens with a lone deep cello over a distant low drone, joined by violins and French horns, "
           "swelling to full orchestra with wordless mixed choir and ancient frame drums, then falling back to the solo cello. Grand, sorrowful, mysterious. " + MOTIF),
 "hub": (80, "Quiet sanctuary music. Sparse felt piano and warm solo cello over a soft sustained string pad, a few distant bell-like metallic tones, "
               "very slow, intimate and safe but melancholy. No percussion. " + MOTIF),
 "explore_courtyard": (90, "Exploration underscore for a ruined mountain fortress in clear morning light. Restrained and atmospheric: soft high strings, "
                       "a lonely French horn call, low harp, long silences, wind-like textures, a faint distant metallic hum underneath. Calm, watchful, a little uneasy. " + MOTIF),
 "boss_ashen_sentinel": (95, "Boss battle music for a towering ancient guardian knight. Heavy slow war drums and anvil strikes, low brass and cellos in a relentless marching ostinato, "
                         "wordless male choir, building in intensity with violins driving above. Powerful, tragic, disciplined rather than frantic, 90 beats per minute. " + MOTIF),
}
os.makedirs("assets/audio/music", exist_ok=True)
for name in (sys.argv[1:] or list(CUES)):
    out = "assets/audio/music/%s.ogg" % name
    if os.path.exists(out):
        continue
    dur, prompt = CUES[name]
    try:
        r = subprocess.run(["higgsfield", "generate", "create", "elevenlabs_music_v2_5", "--prompt", prompt, "--duration", str(dur), "--force_instrumental", "true",
                            "--wait", "--wait-timeout", "8m"], capture_output=True, text=True, timeout=600, stdin=subprocess.DEVNULL)
    except subprocess.TimeoutExpired:
        print(name, "FAILED timeout"); continue
    url = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
    if not url.startswith("http"):
        print(name, "FAILED", (r.stderr or r.stdout)[-200:]); continue
    raw = out + ".src"
    subprocess.run(["curl", "-sS", "-m", "300", "-o", raw, url], check=True)
    # seamless loop: the first 5 seconds are cross-faded onto the end, so the join is inaudible
    head, body = raw + ".head.wav", raw + ".body.wav"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-t", "5", head], check=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-ss", "5", "-i", raw, body], check=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", body, "-i", head, "-filter_complex",
                    "[0:a][1:a]acrossfade=d=5:c1=tri:c2=tri,loudnorm=I=-16:TP=-1.5[o]", "-map", "[o]", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5", out], check=True)
    os.remove(head); os.remove(body)
    os.remove(raw)
    print(name, "ok", flush=True)
