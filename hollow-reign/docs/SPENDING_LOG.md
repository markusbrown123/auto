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
- Casting round 2 (owner asked for deeper, East Asian and anime-style voices): 44 new speech takes, 28 on the Inworld model (about 56 credits) and 16 on the second model (about 7 credits).
- Casting rounds 3 to 5 (owner's correction: anime-dub style, no accent): 35 second-model takes (about 16 credits), 12 Inworld takes (about 24 credits), 1 second-model take; most of round 5 is earlier takes lowered in pitch at no cost.
- Eight sculpted hilt concepts (about 10 Higgsfield credits) and eight hilt models (30 Tripo credits each = **$2.40**). Tripo graphics allocation spent so far: **$28.20** of $100.

## Final cast recorded for the three-generation campaign (2026-11-27)
Higgsfield balance read before: **1,030.83** credits. Read after: **850.54**. The account fell by 180.29 in that window; the transaction list shows 171.29 of it is this recording and 9.00 is twelve image jobs (GPT Image 2.6, 0.75 each) run by other work at the same time, logged by whoever ran them.

| Item | Service | Credits | Cost |
|---|---|---|---|
| 84 takes on the Inworld speech model, 2 each (the account shows 84 charges and 1 refund): narrator 9, Monarch 12, Lyra 10, grandson 10, granddaughter 10, the Kept 10 (5 lines x 2 bodies), Witness 8, son 3, daughter 3, Frostbound King 4, Huntsman 2, Gravewarden 2 | Higgsfield speech | 166.00 | about $6.81 |
| 16 takes on the second speech model (9 at 0.23, 7 at 0.46): Father 4, Mother 4, Crimson Widow 3 (stability 0.15), Devourer 5 (provisional voice) | Higgsfield speech | 5.29 | about $0.22 |
| Total for this pass (ceiling set for it: 220) | | **171.29** | about $7.03 |

One Witness line (`w_gravewarden_approach_01`) was refused twice by the service's content filter (once in this pass, once before it); the line was reworded ("kill you" to "end you") and then recorded. Refused jobs show as refunded or uncharged. No job was paid for twice: every job id is in `assets/audio/vo/jobs.json`. Nothing here has been listened to: recorded, unauditioned.

## Far-future environment kit (2026-11-27, task ceilings: $16 of Tripo, 40 Higgsfield credits)
Owner direction: "Environment more new and space but land like futuristic not medieval at all."
- Twelve concept images (`art/concept/env_fu_*_v1.png`, GPT Image 2.6, 0.75 credits each as billed) = **9.0 Higgsfield credits**.
- Eleven prop models (`assets/models/env_fu_{pylon,tower,wall,colossus,engine,wreck,core,husk,throne,cradle,pod}.glb`, 30 Tripo credits each) = 330 credits = **$3.30**.
- The twelfth, `env_fu_beacon`, failed inside Tripo ("Internal processing error", task `1a7b517e-ec87-4dc1-a485-41bfd2eaed1b`) and was not charged; it was not sent again. The beacon is built in code instead (`Future.beacon`).
- Balances: Tripo 6,565 credits before, 6,235 after (the account's balance endpoint; nothing frozen). Higgsfield 1,030.83 before; the other agents' speech jobs were being billed to it at the same time, so its balance after is not a measure of this task: the twelve image charges are listed singly in the account's transactions (08:28 to 08:29 UTC).
- Tripo graphics allocation spent so far: $28.20 + $3.30 = **$31.50** of $100.

## 2026-11-27: male knight v4 concepts (owner: "body is morphed every render for the male, fix, make look more like a soldier real")
Three concept images (gpt_image_2_6, 2k, 3:4): art/concept/knight_m_v4{a,b,c}.png, sheet marketing/armor_finish_pass/male_v4_concepts_A_B_C.jpg. About 1.25 credits each at list (about 3.75 credits). No 3D model bought: waiting for the owner to choose one (a knight model is 135 Tripo credits = $1.35). Account read after: View the signed-in account's balance, subscription plan, and recent credit transactions..

## 2026-11-27: protagonist voice round
Three samples on one line (elevenlabs_v4, stability 0.5): Caspian, Barrett, Holden, in marketing/audition/protagonist_round/. About 0.46 credits each (about 1.4 credits). Unauditioned. No lines regenerated; waiting for the owner's choice.

## 2026-11-27: protagonist voice round 2
Owner rejected round 1 ("more Kratos like"). Four samples (elevenlabs_v4, stability 0.7, slowed 6%, pitch lowered where marked): Vlad, Alistair −3, Caspian −4, Sterling −4, in marketing/audition/protagonist_round2/. About 0.46 credits each (about 1.9 credits). Unauditioned.

## 2026-11-27: protagonist voice round 3
Owner sent a reference clip (a real actor's performance from a published game) and asked to replicate it: not cloned, not uploaded; pitch measured locally (about 99 Hz median). Three closest licensed voices recorded dry at stability 0.85: Alistair, Bob, Vlad, in marketing/audition/protagonist_round3/. About 1.4 credits. Unauditioned.

## 2026-11-27: male protagonist re-recorded (owner's choice: Sterling, lowered 4, light helmet resonance)
45 takes (40 player_m, 5 kept_m) on elevenlabs_v4, stability 0.7; pitch −4 semitones, tempo 0.94, then bass, room, light helmet resonance, level-matched. Clean masters kept in art/vo_masters/player_m/ (not in git) so the effect chain can be changed with `tools/voices.py --post` at no cost. Planned 20.7 credits; account read 839.89 before and 828.85 after (other passes were also running, so the difference is not solely this job). Recorded, unauditioned. No fight grunts or breathing recorded yet.

## 2026-11-27: male knight v4 (concept B), one Tripo model
Owner chose concept B (`art/concept/knight_m_v4b.png`). One image-to-model, rig check, rig: `tools/tripo.py art/concept/knight_m_v4b.png knight_m_v4` -> `assets/models/knight_m_v4.glb`. One attempt, none repeated.
- Model task `1bd1328d-4fb6-4c5c-b179-adda7f9bef4a` 110 credits, rig check free (riggable biped), rig task `6d6ddd57-d102-467c-a9b4-7d1b8c56e56d` 25 credits = **135 credits = $1.35** (ids also in `art/models/knight_m_v4.json`).
- Tripo balance (`GET /v3/account/balance`) before **6,235.00**, after **6,100.00**, frozen 0.00.
- Tripo graphics allocation spent so far: $31.50 + $1.35 = **$32.85** of $100. No Higgsfield credits used in this step.

## 2026-11-27: generated sound pilot (owner approved "Full replacement", ceiling 300 credits)
Pilot of 3 sword-clash takes on mirelo_text_to_audio, 2.0 s each, 0.50 credits each = 1.50 credits (job ids in assets/audio/sfx/sfx_jobs.json). Measured result: every take contained many events (3 to 11), and two of the three had a spectral centroid of 44–81 Hz, far too low for metal on metal; only one (about 3,500 Hz) is plausible. The full run was NOT started. Synthesised files restored with `tools/sfx_buy.py --restore`. Raw takes for the owner to hear: marketing/audition/sfx_pilot/.

## 2026-11-27: female protagonist voice, round 1 (three samples)
Owner asked for a deeper, darker heroine. Three samples on one line (Elodie, Karen, Soraya; ElevenLabs v4 via Higgsfield). Higgsfield balance 827.35 -> 826.66 (0.69 credits). Samples in marketing/audition/heroine_round1/. Full re-record of her 59 lines waits for the owner's pick.

## 2026-11-28: music audition, three directions (owner approved ~30 credits)
Three 60 s instrumental cues on ElevenLabs Music v2.5 via Higgsfield, all on one new recurring theme (D minor: D, F, A, up to C, back to A): menu theme, cliffside journey, boss battle. Higgsfield balance 826.66 -> 800.50 (26.16 credits). Files: marketing/audio_pass/music_audition/ (loudness-normalised copies), art/music_audition/ (as delivered). Nothing else generated; nobody has listened yet.

## 2026-11-28: main character and merchant voice auditions (owner approved ~2 credits)
Six samples (ElevenLabs v4 via Higgsfield): main character Sterling (lowered 2), Holden, Desmond on one line; merchant Orren: Barrett, Grady, Emmett on one line. 2.76 credits (800.50 -> 797.74). Files: marketing/audition/hero_merchant_round/. Current voices unchanged until the owner approves.

## 2026-11-28: merchant Irish-accent auditions
Owner asked for more merchant options with an Irish accent. Three ElevenLabs v4 takes (Grady, Emmett, Barrett) with an accent tag, 0.92 credits each = 2.76 credits. Two Qwen TTS attempts were refused before generation (no charge). Main character space-helmet versions made from the existing take with filters only (no cost). Files: marketing/audition/hero_merchant_round/.

## 2026-11-28: merchant brogue round
Three ElevenLabs v4 takes (Barrett, Grady, Harrison), 1.15 credits each = 3.45 credits (balance now 780.03 including the concept pass running in parallel). Hero voice change applied from kept masters: no cost.

## 2026-11-28: presentation pass concepts (owner approved, ceiling 17 credits)
Ten GPT Image 2.6 images at 2k: three logo concepts at quality medium (1.75 each) and three app icons, two armour-merchant and two Forgotten Monarch concepts at low (1.25 each) = **14.00 credits**, confirmed line by line in `higgsfield account transactions`. Higgsfield balance **797.74 -> 777.53** (20.21); the other 6.21 in that window were six Eleven v4 voice jobs from a concurrent voice-audition pass, not this one. (The balance read 800.50 at the very start; 2.76 of Eleven v4 spend from that other pass landed before the first image.) No failures or refusals; two creates were rejected by the 8-concurrent-job limit before any job existed (no charge) and were submitted again once. Files, prompts and job ids: marketing/presentation_pass/concepts/README.md.

## 2026-11-28: merchant Orren re-recorded (owner's pick: Barrett, Scottish brogue)
His 4 lines (intro 01–03, idle 01) on ElevenLabs v4 via Higgsfield, 3.45 credits (logged late; amount from commit 15a11f1). Old takes in art/vo_masters/orren_prev/ (not in git).

## 2026-11-28: Forgotten Monarch v2, one Tripo model (owner approved "the king")
From the approved concept `art/concept/monarch_v2.png` (= marketing/presentation_pass/concepts/monarch_full_body.png): `tools/tripo.py art/concept/monarch_v2.png monarch_v2`. One attempt, none repeated.
- Model task `9277922d-f516-45d5-adea-f01a8be4b71f` 110 credits, rig check free (riggable biped), rig task `721c8f9e-c6be-4365-84a8-877bb2f49c2c` 25 credits = **135 credits = $1.35**.
- Tripo balance before **6,100.00**, after **5,965.00**, frozen 0.00. Graphics allocation spent: $32.85 + $1.35 = **$34.20** of $100.
- Not yet wired into the game: the concept's sword and cloak are part of the mesh (cloak weighted to the arm). Integration is a Stage 4 task.

## 2026-11-28: armour merchant Orren, full-body image + one Tripo model (owner approved ~1.75 cr + $1.35)
The approved merchant concepts hide his legs, so one full-body A-pose image was made first, from `merchant_counter_portrait.png` as the reference: GPT Image 2.6, 2k, quality medium, **1.75 credits** (Higgsfield 774.08 -> 772.33). File `art/concept/merchant_v1.png` (copy in marketing/presentation_pass/concepts/merchant_full_body.png).
Then `tools/tripo.py art/concept/merchant_v1.png merchant_v1`: model task `54ad119e-c0ac-4d19-be7a-c9ccf687082e` 110 credits, rig check free (riggable biped), rig task `26824442-c488-400d-b901-40056ea60cb8` 25 credits = **135 credits = $1.35**. Tripo balance 5,965.00 -> **5,830.00**. Graphics allocation spent: **$35.55** of $100. One attempt each, none repeated. Not yet wired into the game (Stage 4).

## 2026-11-28: sound packs approved (owner buys them directly)
The owner rejected every free recorded effect and approved the "core pair" of paid packs, to be bought by the owner
(paid directly, outside the generation caps, like the Game Dev Hero animation bundle). Prices are from store search
results, not the live pages (this container cannot open those stores); the owner confirms at checkout.
- Gamemaster Audio, Pro Sound Collection: about $39.20 (Sonniss sale) to $47 (gamemasteraudio.com); take the 16-bit/44.1 kHz
  download (about 1.8 GB). Footsteps on all surfaces, cloth foley, male and female vocal efforts, magic, sci-fi, monster
  vocals, whooshes, UI. Licence (seller's site): royalty-free, commercial use, no attribution.
- Double Trouble Audio, Medieval Armor Impacts & Movement: about $35 on Sonniss or A Sound Effect ($20 on the Unity Asset
  Store; the non-Unity copy is preferred so the licence is not tied to Unity). Plate, chainmail and leather movement and
  footsteps, armour hits, shields, parries.
Total about $59 to $82. Raw files only in git-ignored art/sfx_src/; only processed in-game sounds are committed.
Animation: free sources only (Mixamo with the owner's Adobe login, Quaternius CC0). No purchase.
