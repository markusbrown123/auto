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

**Totals to date:** Tripo $30.80 spent, $19.20 left (keep $5 in reserve). Higgsfield about 72 credits (about $3) spent, about 1,140 credits left. Combined about $34 of the $100 cap.

**Lessons that save money**
- Tripo standard mode with `face_limit` is $0.30 per static prop; the low-poly "P" mode is $1.10 and Higgsfield image-to-3D about $1.25. Use the P mode only for characters that need rigging.
- Failed downloads are recovered from the task id, never regenerated (`tools/tripo.py` does this automatically for props).
- Concept images for props are generated at 1k, not 2k.
