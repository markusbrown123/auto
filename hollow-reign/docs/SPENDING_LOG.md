# Spending log

Cap: $100 total across Higgsfield and Tripo, including everything below. Tripo credits are $0.01 each. Higgsfield credits are valued here at about $0.041 each (1,212 credits on a roughly $50 plan); that rate is an estimate.

| Date | Service | What | Units | Approx. cost |
|---|---|---|---|---|
| 2026-11-25 | Tripo | First text-to-model test (unusable: 1.46M triangles, no rig) | 20 cr | $0.20 |
| 2026-11-25 | Tripo | 18 rigged low-poly characters (2 knights, 9 bosses, 7 class models) at 135 cr | 2,430 cr | $24.30 |
| 2026-11-25 | Tripo | 21 weapons and shields at 30 cr (standard mode, 6k polygon cap) | 630 cr | $6.30 |
| 2026-11-25 | Higgsfield | 3 knight concepts, 16 character concepts (2k images at 1.25 cr) | about 24 cr | $1.00 |
| 2026-11-25 | Higgsfield | 22 weapon and shield concepts (1k images at 0.75 cr); 5 more were refused by the content filter or failed and were refunded | about 17 cr | $0.70 |
| 2026-11-25 | Higgsfield | 1 image-to-3D test (knight sword) | 30 cr | $1.25 |
| 2026-11-26 | Tripo | 13 Fallen Courtyard set pieces at 30 cr | 390 cr | $3.90 |
| 2026-11-26 | Higgsfield | 13 environment concepts (1k) | about 10 cr | $0.40 |
| 2026-11-26 | Higgsfield | 97 voice lines (ElevenLabs v4, about 0.46 cr each; a few early test lines repeated) | about 50 cr | $2.05 |
| 2026-11-26 | Higgsfield | 4 music cues, 75 to 95 seconds each (ElevenLabs Music v2.5) | about 50 cr | $2.05 |
| 2026-11-26 | Higgsfield | 1 video clip (Seedance 2.5, 5 s, 720p): the Courtyard memory scene | 35 cr | $1.45 |
| 2026-11-26 | (none) | Cinematic duel footage: 18 clips rendered from the game's own scene | 0 | $0.00 |
| 2026-11-26 | Higgsfield | 12 Blackwood environment concepts (1k) | 9 cr | $0.35 |
| 2026-11-26 | Tripo | 12 Blackwood set pieces at 30 cr | 360 cr | $3.60 |
| 2026-11-26 | (none) | Courtyard road footage: 7 clips rendered from the game's own scene | 0 | $0.00 |

**Totals to date (reconciled 2026-11-26 against both accounts):** Tripo $38.30 spent. Higgsfield about 214 credits (about $8.80) spent, about 998 credits left. Combined about $47 of the $100 cap.

**Balances:** the owner topped up Tripo on 2026-11-26; the API wallet now shows $115.30. The $100 cap has not been changed, so spending still stops at $100 combined unless told otherwise. There are also 6,200 Tripo Studio credits that can only be spent by hand in the Studio web app.

**Lessons that save money**
- Tripo standard mode with `face_limit` is $0.30 per static prop; the low-poly "P" mode is $1.10 and Higgsfield image-to-3D about $1.25. Use the P mode only for characters that need rigging.
- Failed downloads are recovered from the task id, never regenerated (`tools/tripo.py` does this automatically for props).
- Concept images for props are generated at 1k, not 2k.
- Higgsfield's CLI blocks on standard input when run from a script; pass `stdin=DEVNULL`. Run speech jobs one at a time.
- Generated model textures are capped at 1024 px on import (`project.godot`, importer defaults). That alone cut video memory from about 1.1 GB to about 330 MB.

## Animation clips (overhaul pass)

| Item | Service | Credits | Cost |
|---|---|---|---|
| 9 retargeted clips for the knight skeleton (idle, walk, run, turn, slash, hurt, fall, dive, jump) | Tripo API | 90 | $0.90 |

Running total after this entry: Tripo ≈ $39.20, Higgsfield ≈ $8.80, combined ≈ $48.00 of the $100 cap.
No failed tasks were regenerated. Nothing else was bought in this pass.

## Voice casting (continuous-development pass, 2026-11-26)

| Item | Service | Credits | Cost |
|---|---|---|---|
| Measured catalogue: one test line from each of 114 preset voices (`docs/VOICE_CATALOG.json`) | Higgsfield speech | about 53 | about $2.15 |
| Audition reel: 10 roles × 3 candidates (`marketing/audition/casting/`) | Higgsfield speech | about 14 | about $0.60 |

Account balance read after both: 931.25 credits (was about 998). One catalogue take failed and was not retried.
Animation libraries added in this pass were free (CC0 / MIT); nothing was bought.

Running total: Tripo ≈ $39.20, Higgsfield ≈ $11.55, combined ≈ **$50.75 of the $100 cap**.
