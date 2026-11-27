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

## Region kits and dragons (continuous pass, 2026-11-26)

| Item | Service | Credits | Cost |
|---|---|---|---|
| 42 environment concepts for six regions + 3 dragon concepts | Higgsfield images | 35.25 | about $1.45 |
| 42 static scenery models (cathedral, crypt, roost, citadel, deep, throne; 7 each) | Tripo, standard model, 6k faces | 1,260 | $12.60 |
| Veyrath: low-poly model (rig charged on completion) | Tripo P model + quadruped rig | 110 + 25 | $1.35 |

Balances read after: Tripo 9,685 credits with 25 held; Higgsfield 896 credits. No failed tasks, nothing regenerated.

Running total: Tripo ≈ $53.15, Higgsfield ≈ $13.00, combined ≈ **$66.15 of the $100 cap**.
Planned and not yet spent: two more dragons (Skeldra, Azhurion) at $1.35 each, only if the first one rigs and animates acceptably.

| Skeldra and Azhurion: low-poly model + quadruped rig each | Tripo | 2 × 135 | $2.70 |

All three dragons rigged and seen in game. Running total: Tripo ≈ $55.85, Higgsfield ≈ $13.00, combined ≈ **$68.85 of the $100 cap**.

| Second audition reel (deeper, older direction): 30 takes | Higgsfield speech | 15.9 | about $0.65 |

Running total: Tripo ≈ $55.85, Higgsfield ≈ $13.65, combined ≈ **$69.50 of the $100 cap**.

## Final production brief pass (2026-11-26)

| Item | Service | Credits | Cost |
|---|---|---|---|
| Third audition reel: 34 takes, cast by character, unprocessed | Higgsfield speech | about 16 | about $0.65 |
| Witness relic concept | Higgsfield image | about 1 | about $0.04 |
| Witness relic model | Tripo static prop | 30 | $0.30 |

Running total: Tripo ≈ $56.15, Higgsfield ≈ $14.35, combined ≈ **$70.50 of the original $100 cap**.
The further $100 the owner reports adding for graphics was not visible on either account when checked (Tripo 9,415 credits, Higgsfield 880 credits, both unchanged), so nothing has been spent against it.

| Fourth audition reel (regional and continental voices, Inworld model): 34 takes + 1 test, 2 credits each; one timed-out take recovered by job id, not regenerated | Higgsfield speech | 70 | about $2.87 |

Running total: Tripo ≈ $56.15, Higgsfield ≈ $17.22, combined ≈ **$73.37 of the original $100 cap**.

## Budget correction (2026-11-26, from the owner's Tripo billing screenshot)
The Tripo account has received $150 in total: $50 on 25 Nov and $100 on 26 Nov 00:16. The $100 is the "added graphics allocation" in the final brief; it was already in the wallet when that brief arrived, which is why no new top-up appeared. The owner has now authorised it as a dedicated graphics allocation on top of the original cap.
- Original cap: $100 across both services. Spent so far ≈ $73.37, plus the voice recording now running (about $12 when complete) and 9 ground textures (about $0.40).
- Graphics allocation: up to $100, on Tripo only (3D models, rigs). Tripo wallet shows $93.85. It cannot pay for Higgsfield images, video or speech.

| Owner-approved cast recorded (Witness, male knight, narrator, Sentinel/Executioner): 144 takes on the Inworld model; one line refused by the content filter and left as a subtitle | Higgsfield speech | about 288 | about $11.80 |
| 17 armour-set concepts (2k, from the knight references) + 9 ground textures | Higgsfield images | about 28 | about $1.15 |

Higgsfield balance read after: 472.68 credits.
**Original $100 cap:** Tripo $56.15 + Higgsfield ≈ $30.20 = about **$86.35**. About $13.65 left; Higgsfield (images, video, speech, music) can only be paid from this.
**Graphics allocation ($100, Tripo only):** 16 armour-suit models complete (8 suits x 2 bodies, 135 credits each) = **$21.60**. The last one (`knight_f_hollow`) failed to download and was recovered from its paid rig task id at no extra cost.

## Higgsfield top-up authorised (owner, 2026-11-26)
The Higgsfield balance rose by exactly 1,000 credits (472.68 → 1,472.68). The owner confirmed it is "meant to be used for better graphics, fixing bugs, clipping, characters in the floor, swords going through": a clean, professional result. It is spendable on Higgsfield work that serves that (images, textures, footage, speech), still logged item by item, and still not to be burned on things the existing tools can do.
Most of what the owner listed (clipping, floor penetration, weapons passing through) is code and animation work that costs nothing to fix.

## Animation packs (owner purchase, 2026-11-26)
The owner bought the Game Dev Hero bundle ($59.97, paid directly by the owner, outside the generation caps): Sword & Shield V3, Two-Handed Sword V3, Dual Sword V1 (Mixamo skeleton, 1,181 FBX). Source files live only in the git-ignored `art/anim_src/gamedevhero/` and the private repo `hollow-reign-anims`; the licence forbids redistributing them, so they must never be committed here. No licence text was inside the zips.

## Benchmark knights v3 (2026-11-26)
Two sleek starter-knight concepts (`art/concept/knight_{m,f}_v3.png`, about 2.5 Higgsfield credits) and two rigged models (`assets/models/knight_{m,f}_v3.glb`, 135 Tripo credits each = **$2.70**) from the Tripo graphics allocation. Graphics allocation spent so far: $21.60 + $2.70 = **$24.30**.

## Opening road props (2026-11-26)
Two concept images (about 2.5 Higgsfield credits) and two prop models, `env_road_gatehouse` and `env_road_dead_tree` (30 Tripo credits each = **$0.60**), from the Tripo graphics allocation. Allocation spent so far: **$24.90** of $100.

## Casting round, futuristic gate and sculpted hilt trial (2026-11-27)
- Final casting round: 27 new speech takes (about 54 Higgsfield credits), 17 earlier takes reused. Asked for by the owner.
- Three concept images (about 3.75 Higgsfield credits) and three prop models: `env_road_gate_future`, `hilt_wayfarer`, `hilt_eternal` (30 Tripo credits each = **$0.90**). Tripo graphics allocation spent so far: **$25.80** of $100. The medieval `env_road_gatehouse` ($0.30, bought the day before) is unused after the owner's futuristic-environment direction.
