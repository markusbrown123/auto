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

**Totals to date:** Tripo $34.70 spent. Higgsfield about 170 credits (about $7) spent, 1,042 credits left. Combined about $42 of the $100 cap.

**Balances:** the owner topped up Tripo on 2026-11-26; the API wallet now shows $115.30. The $100 cap has not been changed, so spending still stops at $100 combined unless told otherwise. There are also 6,200 Tripo Studio credits that can only be spent by hand in the Studio web app.

**Lessons that save money**
- Tripo standard mode with `face_limit` is $0.30 per static prop; the low-poly "P" mode is $1.10 and Higgsfield image-to-3D about $1.25. Use the P mode only for characters that need rigging.
- Failed downloads are recovered from the task id, never regenerated (`tools/tripo.py` does this automatically for props).
- Concept images for props are generated at 1k, not 2k.
- Higgsfield's CLI blocks on standard input when run from a script; pass `stdin=DEVNULL`. Run speech jobs one at a time.
- Generated model textures are capped at 1024 px on import (`project.godot`, importer defaults). That alone cut video memory from about 1.1 GB to about 330 MB.
