# Animation sources for Hollow Reign

Researched 2026-11-26. Goal: a skeletal animation library that can ship in a paid iOS game and covers the sword-combat move list, retargetable onto our Mixamo-named rig through `tools/bake_anims.gd`.

Every licence line below was read on the primary page on that date unless it is marked **unverified**. Prices are the listed USD prices on that date; itch.io and Fab prices move with sales.

## Recommendation

**Best free option: Quaternius Universal Animation Library 1 + 2 (Standard tier, CC0), topped up with the free Explosive unarmed sample (MIT) for rolls and directional hit reactions, and KayKit (CC0) only for two-handed and dual-wield placeholders.** All four archives are downloaded under `art/anim_src/`.

- UAL is the only free set with realistic proportions, a 65-joint rig with fingers, a T-pose rest that matches Mixamo, and a one-to-one joint correspondence with the Mixamo names we use.
- The free tiers give us a workable one-handed sword and shield core: a 3-hit combo split into hits and recoveries, a heavy combo, a lunge, a block, a shield idle, a shield bash, a guard break, hit reactions, a knockback, a roll, a death, walk, jog and sprint.
- The free tiers do **not** give us: eight labelled attack directions, directional parries, high/low shield blocks, a real greatsword set, a real dual-blade set, finishers, or retreating attacks.

**Cheapest upgrade that stays CC0: $24.98.** UAL2 Source ($14.99) adds the light and heavy 4-hit chains as separate hits, aerial attacks, uppercut, ground pound and 8-way walk. UAL1 Pro ($9.99) adds left/right dodges, shoulder and stomach hit reactions, a second death, 8-way jog and sword draw/sheathe. This still leaves parries, shield high/low, greatsword, dual blades and finishers uncovered.

**Best paid option for the full list: three Game Dev Hero packs on itch.io, $59.97 total.**

| Pack | Price | What it closes |
|---|---|---|
| Sword And Shield Animation V3 | $19.99 | shield blocks (7), 4-way hits and deaths, dodges, dashes, combos, paired reaction/execution clips |
| Two Handed Sword Animation V3 | $19.99 | greatsword set, 5 parry clips, 8 rolls, 4-way defence hits |
| Dual Sword Animation V1 | $19.99 | dual-blade set, 8 rolls, dodges, dashes |

Each ships a `*_Mixamo.zip` with FBX on the Mixamo skeleton, so the bake step needs no bone map. The licence explicitly names Godot and commercial games. Three things to know before buying: the contents of the Mixamo zips were not inspected (paid), the files are FBX rather than GLB, and the licence has a no-generative-AI-training clause and asks that the clips not be easily extractable from the shipped game.

**Alternative single purchase: Explosive "RPG Animations GLB", $79.99.** 1,157 clips across 15 weapon styles (sword, shield, two-handed sword, dagger and more), delivered as GLB for Godot. Its free 64-clip sample is downloaded and inspected below, so the skeleton and quality can be judged before paying. It is hand-keyed and stylised, with larger proportions than our knight.

## Comparison

Coverage columns: **1H** one-handed attacks and combos, **S&S** sword-and-shield stances and blocks, **Parry** directional parries, **Evade** rolls, dodges and sidesteps, **2H** greatsword, **Dual** dual blades, **React** hits, staggers and deaths, **Fin** finishers.

### Free

| Source | Licence (quote, URL) | Price | Format | 1H | S&S | Parry | Evade | 2H | Dual | React | Fin | Skeleton | Download status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Quaternius UAL 1 Standard | "Free to use in personal, educational and commercial projects. (CC0 License)" https://quaternius.itch.io/universal-animation-library ; `License.txt` in the zip: "CC0 1.0 Universal (CC0 1.0) Public Domain Dedication" | Free (43 of 126 clips) | GLB, FBX | 1 attack, idle | no | no | forward roll | no | no | 2 hits, 1 death | no | 65 joints, UE-style names, T-pose rest | **Downloaded**, no login |
| Quaternius UAL 2 Standard | Same wording, https://quaternius.itch.io/universal-animation-library-2 ; same `License.txt` | Free (43 of 134 clips) | GLB, FBX | 3-hit combo split, heavy combo, lunge | shield idle, block, bash, guard break | no | slide only | no | no | knockback | no | Same rig as UAL 1 | **Downloaded**, no login |
| KayKit Character Animations 1.1 | "Free for personal and commercial use, no attribution required. (CC0 Licensed)" https://kaylousberg.itch.io/kaykit-character-animations | Free (all clips) | GLB, FBX | chop, 2 slices, stab, jump chop | block, block hit, block attack | no | 4-way dodge hops | 5 attacks, idle | 3 attacks | 2 hits, 2 deaths | no | 23 joints, no neck, shoulders or fingers, chibi proportions | **Downloaded**, no login |
| Explosive RPG Animations GLB FREE | "License: MIT" https://store.godotengine.org/asset/explosive-llc/rpg-character-animations-pack-free/ (no licence file inside the zip) | Free | GLB, FBX | unarmed only | unarmed block, block break | no | 4-way rolls, 3 dodges, dive roll | no | no | 4-way hits, knockback, knockdown, stunned, death | no | 53 joints, `B_` prefix, T-pose, faces -Z, about 1.45x our scale | **Downloaded**, no login |
| Mixamo | Adobe FAQ, seen only as a search snippet: characters and animations may be used "royalty free for personal, commercial, and non-profit projects" including video games. https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html returned Adobe "Access Denied" to this session, so the wording is **unverified** | Free | FBX | good | good | some | good | good | limited | good | few | Native `mixamorig:` | **Not downloaded**: needs an Adobe login we do not have |
| MoCap Online free T.C. Sword pack | "Standard License included — covers personal, indie, and commercial use up to 1M end users / $1M revenue. Royalty-free, perpetual." https://mocaponline.com/products/tc-sword | $0.00 | FBX, BIP, Unity, UE4, iClone | sampler | no | no | no | no | no | no | no | **unverified** | Not downloaded: store checkout flow; itch mirror is 55 MB at https://mocaponline.itch.io/free-3d-sword-animation-pack; clip list not published |
| Kenney Animated Characters | "License: Creative Commons CC0" https://kenney.nl/assets/animated-characters-1 | Free | FBX | no | no | no | no | no | no | no | no | **unverified** | Not downloaded: only basic idle, run and jump clips, no combat |
| Rokoko free mocap assets | Search snippet only: usable "in any animation, VFX, game, 3D project you want, including for commercial use" https://www.rokoko.com/mocap/free-mocap-assets (**unverified**, the URL I tried returned 404) | Free | FBX | no sword set found | no | no | no | no | no | no | no | **unverified** | Not downloaded: needs a Rokoko account |
| Reallusion ActorCore free motions | **unverified**: the site is a JavaScript app and returned no readable terms | Free tier plus paid packs | FBX after export | **unverified** | | | | | | | | **unverified** | Not downloaded: needs a Reallusion account |
| CMU Graphics Lab mocap | **unverified**: `mocap.cs.cmu.edu` failed TLS verification through the proxy. Secondary sources quote "free for all uses" | Free | ASF/AMC, BVH conversions | no sword set | no | no | no | no | no | no | no | CMU skeleton | Not downloaded. Not useful: raw mocap, no weapon combat |
| 100STYLE | "This work is licensed under a Creative Commons Attribution 4.0 International License." "For creative or commercial work please credit in an appropriate way." https://www.ianxmason.com/100style/ | Free, credit required | BVH | no | no | no | no | no | no | no | no | BVH | Not downloaded: locomotion styles only |

### Not usable in a paid game

| Source | Licence (quote, URL) | Why excluded |
|---|---|---|
| Bandai Namco Research Motiondataset 1 and 2 | "Bandai-Namco-Research-Motiondataset-1: CC BY-NC 4.0", same for dataset 2. https://github.com/BandaiNamcoResearchInc/Bandai-Namco-Research-Motiondataset | Non-commercial |
| Ubisoft LAFAN1 | "This dataset can be used under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International Public License" https://github.com/ubisoft/ubisoft-laforge-animation-dataset | Non-commercial and no derivatives |

### Paid

| Source | Licence (quote, URL) | Price | Format | Coverage | Skeleton | Godot use |
|---|---|---|---|---|---|---|
| Quaternius UAL 1 Pro / Source | CC0, as above | $9.99 Pro, $14.99 Source | GLB, FBX, plus .blend in Source | 126 clips: adds Dodge_Left/Right, Hit_Shoulder_L/R, Hit_Stomach, Death02, 8-way jog and crouch, Sword_Enter/Exit, Sword_Attack_Standing, Kick | Same as free tier | Yes, "tested in Godot" |
| Quaternius UAL 2 Source | CC0, as above | $14.99 | GLB, FBX, .blend | 134 clips: adds Sword_Light_A-D, Sword_Heavy_A-D with recoveries, aerial combo, uppercut, ground pound, 8-way walk, Melee_Knee, Sprint_Shield | Same as free tier | Yes |
| Game Dev Hero packs (itch.io) | "You are granted a non-exclusive, worldwide, perpetual license to use the animations in personal and commercial projects." "Import the animations into game engines such as Unreal Engine, Unity, Godot, or similar software." https://itch.io/blog/1578239/animation-asset-license | $19.99 each for Sword And Shield V3, Two Handed Sword V3, Dual Sword V1, One Handed Sword V6. Great Sword V1 $14.99. All-in bundle $524.99 | FBX (UE5 Manny and Mixamo skeletons), .unitypackage, UE project | S&S V3: 355 clips. 2H V3: 471 clips incl. 5 parry, 8 roll, 5 dodge, 8 dash, 4-way hit, death and defence hit. Dual V1: 355 clips. Each has multi-hit combos, single-stage attacks, and paired "Reaction/Execution" clips usable as finishers | Mixamo zip included (contents **unverified**) | Yes, named in the licence. Has a no-AI-training clause and an "embedded, not easily extracted" clause. The licence link appears on the 2H, Dual, 1H V6 and Great Sword pages; I did not see it on the Sword And Shield V2/V3 pages (**unverified** for those two) |
| Explosive RPG Animations GLB | "The products may be used Royalty Free: For personal or commercial use. In broadcast, multimedia, video games or animation." https://www.explosive.ws/pages/terms-of-use | $79.99 | GLB, FBX source | 1,157 clips, 15 styles incl. Sword, Shield, 2 Handed Sword, Dagger, Mace, Spear; in-place and root-motion versions | `B_` rig as in the free sample (assumed same, **unverified**) | Yes, sold for Godot. A Godot store reviewer says the files need clean-up |
| Yummy Games "260 Sword and Shield Mocap Animations" (Fab) | Fab Standard License summary: "Use the assets with any compatible tools (usage is not limited to Unreal Engine)" https://www.fab.com/eula | Page data shows $29.99 and $59.99 tiers, discounted to $14.99 and $29.99 on the day checked (which tier is which is **unverified**) | Unreal Engine only | 14 attacks, 10 blocks, 7 combos, 4 dodges, 7 finishers with reactions, 4 hits, 4 deaths, 8-way locomotion in four modes | UE4/UE5 mannequin | Permitted by licence, but needs Unreal Engine to export FBX first. Needs an Epic login to buy |
| Unity Asset Store packs (Longsword Animset Pro, SwordShield_MocapAnimPack, RPG Character Mecanim Animation Pack) | EULA 2.2.1 grants a licence "to incorporate the Asset ... into an electronic application or digital media" with no engine restriction for non-Restricted Assets. https://unity.com/legal/as-terms | About $50 to $70 from search snippets (**unverified**, store prices are script-rendered) | .unitypackage with FBX inside | Good S&S and longsword coverage | Unity humanoid, bone names vary | Licence allows it for assets not marked Restricted, but each pack must be checked, a Unity login is needed, and FBX must be pulled out of the package |
| MoCap Online paid packs | Same Standard License as the free pack, capped at 1M end users / $1M revenue | **unverified** | FBX and others | **unverified**: no sword-and-shield pack price found | **unverified** | Likely yes |
| RancidMilk | **unverified**: no listing found by search | | | | | |

## Coverage of the wanted move list

| Wanted | Free today (downloaded) | Gap closed by |
|---|---|---|
| Eight-direction sword attacks | Partial. KayKit chop, horizontal slice, diagonal slice, stab; UAL2 Sword_Regular_A/B/C; UAL1 Sword_Attack. Mirroring left/right in the bake step gets about six directions | UAL2 Source (Light A-D, Heavy A-D, uppercut); Game Dev Hero single-stage attacks (20 to 41 per pack) |
| 2-5 hit combos | UAL2 Sword_Regular_A, _B, _C with recoveries (3-hit), Sword_Regular_Combo, Sword_Heavy_Combo (one 4.3 s clip) | UAL2 Source for 4-hit light and heavy chains as separate hits |
| Sword-and-shield stances and idles | UAL2 Idle_Shield_Loop, UAL1 Sword_Idle | Game Dev Hero S&S V3 |
| Directional parries | None. UAL2 Sword_Block and KayKit Melee_Block are single generic blocks | Game Dev Hero 2H V3 (5 parry clips); otherwise author by hand |
| High/low shield blocks | None. UAL2 Shield_OneShot and Idle_Shield_Loop only | Game Dev Hero S&S V3 (7 block clips, heights **unverified**); Fab Yummy pack (10 blocks) |
| Left/right dodge rolls | Explosive UnarmedRollLeft/Right/Forward/Backward; UAL1 Roll (forward) | UAL1 Pro Dodge_Left/Right |
| Sidesteps | Explosive UnarmedDodgeLeft/Right/Backward; KayKit Dodge_Left/Right | |
| Lunges | UAL2 Sword_Dash; KayKit Melee_1H_Attack_Stab | |
| Advancing / retreating attacks | Advancing: UAL2 Sword_Dash, Shield_Dash. Retreating: none | Game Dev Hero root-motion attacks |
| Heavy attacks | UAL2 Sword_Heavy_Combo; KayKit Melee_1H_Attack_Jump_Chop | UAL2 Source Heavy A-D |
| Two-handed greatsword | KayKit Melee_2H_* (5 attacks and idle, stylised) | Game Dev Hero 2H V3 or Great Sword V1 |
| Dual blades | KayKit Melee_Dualwield_* (3 attacks, stylised) | Game Dev Hero Dual Sword V1 |
| Hit reactions | UAL1 Hit_Chest, Hit_Head; Explosive UnarmedGetHitF1/B1/L1/R1, BlockGetHit1/2; KayKit Hit_A/B | |
| Staggers | UAL2 Hit_Knockback, Idle_Shield_Break; Explosive UnarmedStunned, Knockdown1, KnockbackBack1/2, BlockBreak1 | |
| Walk / run | UAL1 Walk_Loop, Jog_Fwd_Loop, Sprint_Loop; Explosive 8-way run and strafe | |
| Finishers | None | Game Dev Hero paired Reaction/Execution clips; Fab Yummy pack (7 finishers) |
| Deaths | UAL1 Death01; KayKit Death_A/B; Explosive UnarmedDeath1 | |

## What was downloaded

All under `/home/user/auto/hollow-reign/art/anim_src/`. Each archive sits in its own directory with the original zip and an `extracted/` folder. Nothing from the archives was executed.

| Directory | Source | Zip SHA-256 | Use this file |
|---|---|---|---|
| `quaternius_ual1/` | itch.io, "Universal Animation Library[Standard].zip" v3.0 | `cc73fc4e495b82958207316596317a3f40b9fa38065bde1027937452da537724` | `extracted/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb` (in place) or `UAL1_Standard_RM.glb` (root motion) |
| `quaternius_ual2/` | itch.io, "Universal Animation Library 2[Standard].zip" v2.2 | `4008ea208a604773a2b2177d965f0f5d3195498b5bf838c3f5785d68e95f2a68` | `extracted/Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb` or `UAL2_Standard_RM.glb` |
| `kaykit_character_animations/` | itch.io, "Free 1.1" | `65882f31f905ad2e953819648a59287cdeab8f623908d5ef701971d3758be20f` | `extracted/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/*.glb` |
| `explosive_rpg_free/` | Godot Asset Store, v0.1.0 | not recorded | `extracted/Unarmed.glb` (in place) or `Unarmed_RM.glb` |

Download hosts that worked: `quaternius.itch.io`, `kaylousberg.itch.io`, `itchio-mirror.cb031a832f44726753d6267436f3b414.r2.cloudflarestorage.com`, `store.godotengine.org`, `fra1.digitaloceanspaces.com`. No download host was refused by the proxy.

## Clip lists (parsed from the GLB JSON chunks)

Durations in seconds. Both UAL files are 30 fps and key translation, rotation and scale on all 65 joints. The `_RM` variants hold the same clip names.

### Quaternius UAL 1 Standard, `UAL1_Standard.glb` (43 clips)

A_TPose (2.50s), Crouch_Fwd_Loop (2.00s), Crouch_Idle_Loop (2.93s), Dance_Loop (1.00s), Death01 (2.40s), Driving_Loop (1.67s), Fixing_Kneeling (5.20s), Hit_Chest (0.33s), Hit_Head (0.43s), Idle_Loop (2.50s), Idle_Talking_Loop (2.93s), Idle_Torch_Loop (1.27s), Interact (2.00s), Jog_Fwd_Loop (0.93s), Jump_Land (1.27s), Jump_Loop (2.50s), Jump_Start (1.33s), PickUp_Table (0.83s), Pistol_Aim_Down (0.17s), Pistol_Aim_Neutral (0.17s), Pistol_Aim_Up (0.17s), Pistol_Idle_Loop (1.67s), Pistol_Reload (1.67s), Pistol_Shoot (0.63s), Punch_Cross (1.00s), Punch_Jab (0.87s), Push_Loop (2.67s), Roll (1.47s), Sitting_Enter (1.30s), Sitting_Exit (1.03s), Sitting_Idle_Loop (1.67s), Sitting_Talking_Loop (2.93s), Spell_Simple_Enter (0.53s), Spell_Simple_Exit (0.43s), Spell_Simple_Idle_Loop (2.10s), Spell_Simple_Shoot (0.50s), Sprint_Loop (0.67s), Swim_Fwd_Loop (1.33s), Swim_Idle_Loop (3.33s), Sword_Attack (1.53s), Sword_Idle (1.67s), Walk_Formal_Loop (1.33s), Walk_Loop (1.33s)

### Quaternius UAL 2 Standard, `UAL2_Standard.glb` (43 clips)

A_TPose (2.50s), Chest_Open (1.37s), ClimbUp_1m (0.67s), Consume (1.33s), Farm_Harvest (2.50s), Farm_PlantSeed (2.77s), Farm_Watering (3.80s), Hit_Knockback (0.83s), Idle_FoldArms_Loop (2.50s), Idle_Lantern_Loop (2.50s), Idle_No_Loop (2.50s), Idle_Rail_Call (2.50s), Idle_Rail_Loop (2.50s), Idle_Shield_Break (1.07s), Idle_Shield_Loop (2.50s), Idle_TalkingPhone_Loop (2.93s), LayToIdle (1.53s), Melee_Hook (0.47s), Melee_Hook_Rec (0.60s), NinjaJump_Idle_Loop (2.00s), NinjaJump_Land (1.27s), NinjaJump_Start (0.97s), OverhandThrow (1.33s), Shield_Dash (1.10s), Shield_OneShot (0.83s), Slide_Exit (0.50s), Slide_Loop (2.00s), Slide_Start (0.83s), Sword_Block (1.23s), Sword_Dash (1.57s), Sword_Heavy_Combo (4.33s), Sword_Regular_A (0.43s), Sword_Regular_A_Rec (0.97s), Sword_Regular_B (0.53s), Sword_Regular_B_Rec (1.03s), Sword_Regular_C (2.00s), Sword_Regular_Combo (3.00s), TreeChopping_Loop (0.97s), Walk_Carry_Loop (2.00s), Yes (2.50s), Zombie_Idle_Loop (1.33s), Zombie_Scratch (1.80s), Zombie_Walk_Fwd_Loop (1.33s)

### KayKit Character Animations 1.1 (139 clip entries in Rig_Medium, 34 in Rig_Large, each file repeats `T-Pose`)

**`Rig_Medium_CombatMelee.glb`:** Melee_1H_Attack_Chop (1.07s), Melee_1H_Attack_Jump_Chop (1.33s), Melee_1H_Attack_Slice_Diagonal (1.00s), Melee_1H_Attack_Slice_Horizontal (1.37s), Melee_1H_Attack_Stab (1.60s), Melee_2H_Attack_Chop (1.63s), Melee_2H_Attack_Slice (1.10s), Melee_2H_Attack_Spin (2.40s), Melee_2H_Attack_Spinning (0.67s), Melee_2H_Attack_Stab (1.60s), Melee_2H_Idle (1.07s), Melee_Block (1.07s), Melee_Block_Attack (1.07s), Melee_Block_Hit (1.07s), Melee_Blocking (1.07s), Melee_Dualwield_Attack_Chop (1.27s), Melee_Dualwield_Attack_Slice (1.17s), Melee_Dualwield_Attack_Stab (1.60s), Melee_Unarmed_Attack_Kick (0.93s), Melee_Unarmed_Attack_Punch_A (1.17s), Melee_Unarmed_Idle (1.07s), T-Pose (0.00s)

**`Rig_Medium_CombatRanged.glb`:** Ranged_1H_Aiming (1.07s), Ranged_1H_Reload (1.17s), Ranged_1H_Shoot (1.07s), Ranged_1H_Shooting (1.60s), Ranged_2H_Aiming (1.60s), Ranged_2H_Reload (1.60s), Ranged_2H_Shoot (1.07s), Ranged_2H_Shooting (1.07s), Ranged_Bow_Aiming_Idle (1.83s), Ranged_Bow_Draw (1.33s), Ranged_Bow_Draw_Up (1.33s), Ranged_Bow_Idle (1.57s), Ranged_Bow_Release (1.33s), Ranged_Bow_Release_Up (1.37s), Ranged_Magic_Raise (2.10s), Ranged_Magic_Shoot (0.93s), Ranged_Magic_Spellcasting (0.67s), Ranged_Magic_Spellcasting_Long (2.53s), Ranged_Magic_Summon (4.30s), T-Pose (0.00s)

**`Rig_Medium_General.glb`:** Death_A (0.80s), Death_A_Pose (0.00s), Death_B (2.63s), Death_B_Pose (0.00s), Hit_A (0.67s), Hit_B (0.87s), Idle_A (1.07s), Idle_B (2.13s), Interact (1.30s), PickUp (1.30s), Spawn_Air (1.30s), Spawn_Ground (1.30s), T-Pose (0.00s), Throw (1.37s), Use_Item (1.60s)

**`Rig_Medium_MovementAdvanced.glb`:** Crawling (1.07s), Crouching (1.07s), Dodge_Backward (0.40s), Dodge_Forward (0.40s), Dodge_Left (0.40s), Dodge_Right (0.40s), Running_HoldingBow (0.80s), Running_HoldingRifle (0.80s), Running_Strafe_Left (0.80s), Running_Strafe_Right (0.80s), Sneaking (2.13s), T-Pose (0.00s), Walking_Backwards (1.07s)

**`Rig_Medium_MovementBasic.glb`:** Jump_Full_Long (2.33s), Jump_Full_Short (1.17s), Jump_Idle (1.07s), Jump_Land (0.67s), Jump_Start (0.60s), Running_A (0.80s), Running_B (0.80s), T-Pose (0.00s), Walking_A (1.07s), Walking_B (1.07s), Walking_C (1.60s)

**`Rig_Medium_Simulation.glb`:** Cheering (1.67s), Lie_Down (3.00s), Lie_Idle (2.67s), Lie_StandUp (2.33s), Push_Ups (1.03s), Sit_Chair_Down (0.80s), Sit_Chair_Idle (3.60s), Sit_Chair_StandUp (0.80s), Sit_Floor_Down (1.00s), Sit_Floor_Idle (4.00s), Sit_Floor_StandUp (1.13s), Sit_Ups (1.73s), T-Pose (0.00s), Waving (2.13s)

**`Rig_Medium_Special.glb`:** EXPERIMENTAL_Medium_Transform (1.00s), Skeletons_Awaken_Floor (2.30s), Skeletons_Awaken_Floor_Long (3.83s), Skeletons_Awaken_Standing (1.00s), Skeletons_Death (2.00s), Skeletons_Death_Pose (0.00s), Skeletons_Death_Resurrect (2.70s), Skeletons_Idle (4.27s), Skeletons_Inactive_Floor_Pose (0.00s), Skeletons_Inactive_Standing_Pose (0.00s), Skeletons_Spawn_Ground (3.57s), Skeletons_Taunt (1.03s), Skeletons_Taunt_Longer (3.00s), Skeletons_Walking (1.60s), T-Pose (0.00s)

**`Rig_Medium_Tools.glb`:** Chop (4.33s), Chopping (1.33s), Dig (4.67s), Digging (1.40s), Fishing_Bite (2.23s), Fishing_Cast (1.93s), Fishing_Catch (3.23s), Fishing_Idle (2.33s), Fishing_Reeling (1.60s), Fishing_Struggling (3.43s), Fishing_Tug (1.90s), Hammer (4.33s), Hammering (2.67s), Holding_A (1.00s), Holding_B (1.00s), Holding_C (1.00s), Lockpick (3.00s), Lockpicking (2.33s), Pickaxe (6.03s), Pickaxing (3.73s), Saw (2.40s), Sawing (0.67s), T-Pose (0.00s), Work_A (2.53s), Work_B (3.10s), Work_C (3.67s), Working_A (1.50s), Working_B (2.53s), Working_C (2.00s)

**`Rig_Large_CombatMelee.glb`:** Melee_1H_Slash (1.57s), Melee_1H_Stab (1.40s), Melee_2H_Attack (1.33s), Melee_2H_Idle (1.57s), Melee_2H_Slam (2.83s), Melee_Block (1.07s), Melee_Block_Attack (1.03s), Melee_Block_Hit (0.67s), Melee_Blocking (1.07s), Melee_Dualwield_Slash (1.03s), Melee_Dualwield_SlashCombo (1.60s), Melee_Unarmed_Idle (1.07s), Melee_Unarmed_Kick (1.70s), Melee_Unarmed_Punch (1.23s), Melee_Unarmed_Smash (3.47s), T-Pose (0.00s)

**`Rig_Large_General.glb`:** Death_A (1.67s), Death_A_Pose (0.00s), Hit_A (0.70s), Idle_A (1.97s), Idle_B (6.00s), T-Pose (0.00s)

**`Rig_Large_MovementAdvanced.glb`:** Dodge_Backwards (0.33s), Dodge_Forward (0.33s), Dodge_Left (0.33s), Dodge_Right (0.33s), T-Pose (0.00s)

**`Rig_Large_MovementBasic.glb`:** Running_A (1.07s), T-Pose (0.00s), Walking_A (1.07s)

**`Rig_Large_Simulation.glb`:** Flexing (4.30s), T-Pose (0.00s)

**`Rig_Large_Special.glb`:** EXPERIMENTAL_Large_Transform (1.67s), T-Pose (0.00s)

### Explosive RPG Animations GLB FREE, `Unarmed.glb` (64 clips)

UnarmedActivate (1.03s), UnarmedAttackKickL1 (1.03s), UnarmedAttackKickR1 (1.03s), UnarmedAttackL1 (0.83s), UnarmedAttackL2 (0.83s), UnarmedAttackL3 (0.83s), UnarmedAttackR1 (0.83s), UnarmedAttackR2 (0.83s), UnarmedAttackR3 (0.83s), UnarmedBlock (2.03s), UnarmedBlockBreak1 (1.03s), UnarmedBlockGetHit1 (0.53s), UnarmedBlockGetHit2 (0.53s), UnarmedBoost1 (1.03s), UnarmedDeath1 (1.33s), UnarmedDiveRollForward1 (1.37s), UnarmedDodgeBackward (0.70s), UnarmedDodgeLeft (0.70s), UnarmedDodgeRight (0.70s), UnarmedFall (1.10s), UnarmedGetHitB1 (0.53s), UnarmedGetHitF1 (0.53s), UnarmedGetHitL1 (0.53s), UnarmedGetHitR1 (0.53s), UnarmedGetup1 (4.03s), UnarmedIdle (1.70s), UnarmedIdleAlert1 (1.37s), UnarmedIdleInjured (1.70s), UnarmedJump (0.63s), UnarmedKnockbackBack1 (1.23s), UnarmedKnockbackBack2 (0.90s), UnarmedKnockdown1 (1.57s), UnarmedLand (0.50s), UnarmedPickup (1.23s), UnarmedRevive1 (1.23s), UnarmedRollBackward (0.90s), UnarmedRollForward (0.90s), UnarmedRollLeft (0.90s), UnarmedRollRight (0.90s), UnarmedRunBackward (0.83s), UnarmedRunBackwardLeft (0.83s), UnarmedRunBackwardRight (0.83s), UnarmedRunForward (0.83s), UnarmedRunForwardLeft (0.83s), UnarmedRunForwardRight (0.83s), UnarmedRunLeft (0.83s), UnarmedRunRight (0.83s), UnarmedSprint (0.63s), UnarmedStrafeBackward (0.83s), UnarmedStrafeBackwardLeft (0.83s), UnarmedStrafeBackwardRight (0.83s), UnarmedStrafeForward (0.83s), UnarmedStrafeForwardLeft (0.83s), UnarmedStrafeForwardRight (0.83s), UnarmedStrafeLeft (0.83s), UnarmedStrafeRight (0.83s), UnarmedStunned (2.03s), UnarmedTurn180Left (1.53s), UnarmedTurn180Right (1.53s), UnarmedTurnLeft90 (0.53s), UnarmedTurnLeftLoop (0.37s), UnarmedTurnRight90 (0.53s), UnarmedTurnRightLoop (0.37s), UnarmedWalkInjured (0.83s)

### Full clip names of the paid Quaternius tiers

Read from the public animation viewer data at https://quaternius.com/animviewer.html, not from a purchased file. Names there drop the `_Loop` suffix.

**UAL 1 Source (126):** BackFlip, Celebration, ClimbLedge, ClimbLedge_RM, Climb_Down, Climb_Enter, Climb_Exit, Climb_Idle, Climb_Left, Climb_Left_RM, Climb_Right, Climb_Right_RM, Climb_Up, Counter_Angry, Counter_Enter, Counter_Exit, Counter_Give, Counter_Idle, Counter_Show, Crawl_Bwd, Crawl_Enter, Crawl_Exit, Crawl_Fwd, Crawl_Idle, Crawl_Left, Crawl_Right, Crouch_Bwd, Crouch_Bwd_L, Crouch_Bwd_R, Crouch_Enter, Crouch_Exit, Crouch_Fwd, Crouch_Fwd_L, Crouch_Fwd_R, Crouch_Idle, Crouch_Left, Crouch_Right, Crying, Dance, Death01, Death02, Dodge_Left, Dodge_Left_RM, Dodge_Right, Dodge_Right_RM, Drink, Driving, Fixing_Kneeling, GroundSit_Enter, GroundSit_Exit, GroundSit_Idle, Hit_Chest, Hit_Head, Hit_Shoulder_L, Hit_Shoulder_R, Hit_Stomach, Idle, Idle_LookAround, Idle_Paper, Idle_Rock, Idle_Scissors, Idle_Talking, Idle_Tired, Idle_Torch, Interact, Jog_Bwd, Jog_Bwd_L, Jog_Bwd_R, Jog_Fwd, Jog_Fwd_L, Jog_Fwd_LeanL, Jog_Fwd_LeanR, Jog_Fwd_R, Jog_Left, Jog_Right, Jump, Jump_Land, Jump_Start, Kick, PickUp_Kneeling, PickUp_Table, Pistol_Aim_Down, Pistol_Aim_Neutral, Pistol_Aim_Up, Pistol_Idle, Pistol_Reload, Pistol_Shoot, PunchKick_Enter, PunchKick_Exit, Punch_Cross, Punch_Jab, Push, Push_Enter, Push_Exit, Roll, Roll_RM, Sitting_Enter, Sitting_Exit, Sitting_Idle, Sitting_Idle02, Sitting_Idle03, Sitting_Nodding, Sitting_Talking, Spell_Double_Enter, Spell_Double_Exit, Spell_Double_Idle, Spell_Double_Shoot, Spell_Simple_Enter, Spell_Simple_Exit, Spell_Simple_Idle, Spell_Simple_Shoot, Sprint, Sprint_Enter, Sprint_Exit, Swim_Fwd, Swim_Idle, Sword_Attack, Sword_Attack_RM, Sword_Attack_Standing, Sword_Enter, Sword_Exit, Sword_Idle, Turn90_L, Turn90_R, Walk, Walk_Formal

**UAL 2 Source (134):** Bandage, Bow_Aim_Down, Bow_Aim_Neutral, Bow_Aim_Up, Bow_Notch, Bow_RapidShoot, Bow_Shoot, Chest_Open, ClimbUp_1m_RM, ClimbUp_2m_RM, Consume, DoubleJump, Farm_Harvest, Farm_PickingTree, Farm_PlantSeed, Farm_ScatteringSeeds, Farm_Watering, Fish_Cast, Fish_Cast_Idle, Fish_OH_Idle, Fish_Reel, Fish_Reel_Failed, GetOffWall_2m_RM, Hit_Knockback, Hit_Knockback_RM, IdleToLay, Idle_FoldArms, Idle_Lantern, Idle_No, Idle_Rail, Idle_Rail_Call, Idle_Shield, Idle_Shield_Break, Idle_TalkingPhone, JogToFlip, KipUp, LayToIdle, LiftAir_Fall, LiftAir_Fall_Impact, LiftAir_Fall_RM, LiftAir_Hit_L, LiftAir_Hit_R, LiftAir_Idle, LiftAir_RM, Melee_Combo, Melee_Hook, Melee_Hook_Rec, Melee_Knee, Melee_Knee_Rec, Melee_Uppercut, Mining, MonsterTransformation, NinjaJump_Double, NinjaJump_Idle, NinjaJump_Land, NinjaJump_Start, OverhandThrow, SafetyVault_RM, Shield_Dash_RM, Shield_OneShot, Slide, Slide_Exit, Slide_Start, Sprint_Shield, StepUp_RM, Surprise, SwordLight_C_Rec, Sword_Aerial_A, Sword_Aerial_A_Rec, Sword_Aerial_B, Sword_Aerial_Combo, Sword_Aerial_Idle, Sword_Block, Sword_Dash_RM, Sword_GroundPound_RM, Sword_Heavy_A, Sword_Heavy_A_Rec, Sword_Heavy_B, Sword_Heavy_B_Rec, Sword_Heavy_C, Sword_Heavy_C_Rec, Sword_Heavy_Combo, Sword_Heavy_D, Sword_Light_A, Sword_Light_A_Rec, Sword_Light_B, Sword_Light_B_Rec, Sword_Light_C, Sword_Light_Combo, Sword_Light_D, Sword_Regular_A, Sword_Regular_A_Rec, Sword_Regular_B, Sword_Regular_B_Rec, Sword_Regular_C, Sword_Regular_Combo, Sword_UpperCut_RM, TreeChopping, Turn180_L_RM, Turn180_R_RM, Walk_Bwd, Walk_Bwd_L, Walk_Bwd_R, Walk_Carry, Walk_Fwd, Walk_Fwd_L, Walk_Fwd_R, Walk_L, Walk_R, WallRun_Jump_L, WallRun_Jump_R, WallRun_L, WallRun_R, Yes, Zombie_Bite, Zombie_Idle, Zombie_Run_Bwd, Zombie_Run_Bwd_L, Zombie_Run_Bwd_R, Zombie_Run_Fwd, Zombie_Run_Fwd_L, Zombie_Run_Fwd_R, Zombie_Run_L, Zombie_Run_R, Zombie_Scratch, Zombie_Spawn, Zombie_Walk_Bwd, Zombie_Walk_Bwd_L, Zombie_Walk_Bwd_R, Zombie_Walk_Fwd, Zombie_Walk_Fwd_L, Zombie_Walk_Fwd_R, Zombie_Walk_L, Zombie_Walk_R

## Joint names

### Quaternius UAL 1 and 2 (65 joints, identical in both)

```
root
  pelvis
    spine_01
      spine_02
        spine_03
          neck_01
            Head
          clavicle_l
            upperarm_l
              lowerarm_l
                hand_l
                  thumb_01_l  thumb_02_l  thumb_03_l  thumb_04_leaf_l
                  index_01_l  index_02_l  index_03_l  index_04_leaf_l
                  middle_01_l middle_02_l middle_03_l middle_04_leaf_l
                  ring_01_l   ring_02_l   ring_03_l   ring_04_leaf_l
                  pinky_01_l  pinky_02_l  pinky_03_l  pinky_04_leaf_l
          clavicle_r  (mirror of the left chain, suffix _r)
    thigh_l
      calf_l
        foot_l
          ball_l
            ball_leaf_l
    thigh_r  (mirror, suffix _r)
```

Each finger is a chain `_01 > _02 > _03 > _04_leaf`. `Head` is capitalised; every other joint is lower case.

### KayKit Rig_Medium and Rig_Large (23 joints)

```
root
  hips
    spine
      chest
        head
        upperarm.l > lowerarm.l > wrist.l > hand.l > handslot.l
        upperarm.r > lowerarm.r > wrist.r > hand.r > handslot.r
    upperleg.l > lowerleg.l > foot.l > toes.l
    upperleg.r > lowerleg.r > foot.r > toes.r
```

### Explosive (53 joints)

```
Motion
  B_Pelvis
    B_Spine > B_Spine1 > B_Spine2
      B_Neck > B_Head
      B_L_Clavicle > B_L_UpperArm > B_L_Forearm > B_L_Hand
        B_L_Finger0 > B_L_Finger01 > B_L_Finger02   (thumb)
        B_L_Finger1 > B_L_Finger11 > B_L_Finger12   (index)
        B_L_Finger2 ... B_L_Finger4                 (middle, ring, pinky)
      B_R_Clavicle ...  (right thumb is named B_R_Finger0, B_R_Finger0.001, B_R_Finger0.002)
    B_L_Thigh > B_L_Calf > B_L_Foot > B_L_Toe0
    B_R_Thigh > B_R_Calf > B_R_Foot > B_R_Toe0
```

## Proposed joint map to Mixamo short names

| Mixamo short name | Quaternius UAL | KayKit | Explosive |
|---|---|---|---|
| (none, root motion) | `root` | `root` | `Motion` |
| Hips | `pelvis` | `hips` | `B_Pelvis` |
| Spine | `spine_01` | `spine` | `B_Spine` |
| Spine1 | `spine_02` | none, leave at rest | `B_Spine1` |
| Spine2 | `spine_03` | `chest` | `B_Spine2` |
| Neck | `neck_01` | none, leave at rest | `B_Neck` |
| Head | `Head` | `head` | `B_Head` |
| LeftShoulder / RightShoulder | `clavicle_l` / `clavicle_r` | none, leave at rest | `B_L_Clavicle` / `B_R_Clavicle` |
| LeftArm / RightArm | `upperarm_l` / `upperarm_r` | `upperarm.l` / `upperarm.r` | `B_L_UpperArm` / `B_R_UpperArm` |
| LeftForeArm / RightForeArm | `lowerarm_l` / `lowerarm_r` | `lowerarm.l` / `lowerarm.r` | `B_L_Forearm` / `B_R_Forearm` |
| LeftHand / RightHand | `hand_l` / `hand_r` | `wrist.l` / `wrist.r` (fold `hand.l` / `hand.r` in if it is animated) | `B_L_Hand` / `B_R_Hand` |
| LeftUpLeg / RightUpLeg | `thigh_l` / `thigh_r` | `upperleg.l` / `upperleg.r` | `B_L_Thigh` / `B_R_Thigh` |
| LeftLeg / RightLeg | `calf_l` / `calf_r` | `lowerleg.l` / `lowerleg.r` | `B_L_Calf` / `B_R_Calf` |
| LeftFoot / RightFoot | `foot_l` / `foot_r` | `foot.l` / `foot.r` | `B_L_Foot` / `B_R_Foot` |
| LeftToeBase / RightToeBase | `ball_l` / `ball_r` | `toes.l` / `toes.r` | `B_L_Toe0` / `B_R_Toe0` |
| LeftHandThumb1-3 | `thumb_01_l` to `thumb_03_l` | none | `B_L_Finger0`, `01`, `02` |
| LeftHandIndex1-3 | `index_01_l` to `index_03_l` | none | `B_L_Finger1`, `11`, `12` |
| LeftHandMiddle1-3 | `middle_01_l` to `middle_03_l` | none | `B_L_Finger2`, `21`, `22` |
| LeftHandRing1-3 | `ring_01_l` to `ring_03_l` | none | `B_L_Finger3`, `31`, `32` |
| LeftHandPinky1-3 | `pinky_01_l` to `pinky_03_l` | none | `B_L_Finger4`, `41`, `42` |
| LeftHand*4 (tips) | `*_04_leaf_l` | none | none |

Right-hand fingers follow the same pattern with `_r` / `B_R_`. `ball_leaf_l/r` and KayKit `handslot.l/r` have no Mixamo counterpart and should be dropped.

## Godot 4.6 and bake-step notes

Measured from the downloaded files:

- **Rest pose.** UAL, KayKit and Explosive all rest in a T-pose (upper arm along the X axis, legs straight down), the same as Mixamo. No A-pose correction is needed. UAL also ships an `A_TPose` clip that holds the rest pose.
- **Facing.** UAL and KayKit face +Z with Y up. Explosive faces -Z (its `Motion` root carries a 180 degree turn), so its model-space deltas need a half turn about Y before they are applied.
- **Scale.** Hip height at rest is 0.917 m for UAL, 0.406 m for KayKit and 1.330 m for Explosive. Scale the Hips position track by `our hip height / source hip height`. KayKit also has a much longer torso relative to its legs, so its clips will look stylised on a realistic knight.
- **Local axes differ from Mixamo.** The joints' local rest rotations are not the Mixamo ones (UAL `upperarm_l` rest is `[0.180 0.684 -0.180 0.684]`, and its `root` is turned -90 degrees about X). If `bake_anims.gd` stores a delta in each bone's *local* frame, the result will be wrong on these rigs. Take the delta in *model space* instead: with `G` the bone's global rotation in the source skeleton, store `D = G_pose * inverse(G_rest)`, then on our rig set `G_target = D * G_target_rest` and convert back to a local rotation with the target parent's global. Because all rests are T-poses, no further offset is needed.
- **Root motion.** The `_RM` files move `root`; the plain files keep `root` still. Use the plain files with the current bake step, which only keeps the Hips position.
- **Loops.** UAL marks loops with a `_Loop` suffix, which can drive the `LOOPS` list. UAL attacks come as hit plus `_Rec` recovery, which suits combo cancelling.
- **KayKit zero-length clips.** `T-Pose`, `Death_A_Pose` and other `*_Pose` clips have duration 0 and should be skipped.
- **FBX packs.** The Game Dev Hero files are FBX. `tools/bake_anims.gd` reads them with `FBXDocument` / `FBXState` (same calls as `GLTFDocument`); tested, see "Game Dev Hero packs: bought and inspected" below.
- **Alternative route.** Godot's importer can retarget on import with a `BoneMap` and `SkeletonProfileHumanoid`; the map table above is what that needs. That would mean moving files out of `art/`, which the importer ignores today.

## Blockers and things not verified

- No proxy refusals for download hosts. `mocap.cs.cmu.edu` failed TLS verification through the proxy; `helpx.adobe.com` answered with Adobe's own "Access Denied"; one Rokoko URL returned 404.
- Mixamo needs an Adobe login. Rokoko and ActorCore need accounts. Fab needs an Epic login. Unity Asset Store needs a Unity login. None were attempted.
- Not inspected: the Explosive full pack's skeleton (paid, not bought). The Game Dev Hero packs have since been bought and inspected (next section).
- The Quaternius website now carries a "Quaternius Asset License (QAL) v1.0" page dated 2026-08-28 that forbids reselling the assets as assets. The UAL pages and the `License.txt` inside both downloaded zips still say CC0, and the FAQ says each kit is "either CC0 or the QAL License". Keep the downloaded `License.txt` files as the record of the terms we obtained them under.
- (Superseded: the free libraries and the bought packs are baked and played in the game; `ANIMATION_LIBRARY.md`.)

## Game Dev Hero packs: bought and inspected

The three packs recommended above were bought and unpacked to `art/anim_src/gamedevhero/` (git-ignored; **the licence forbids passing the source files on, and this repository is public, so no FBX or per-file conversion may be tracked**). Full clip list with lengths: `ANIMATION_PACKS.md`. What is baked into the game and how: `ANIMATION_LIBRARY.md`.

What the files turned out to be, measured with `tools/dev/fbx_probe.gd` and `tools/bake_anims.gd -- --catalogue=`:

- 1,181 FBX files: 522 in place (`IP/`) and 659 with root motion (`RM/`). One clip per file, 30 fps, no mesh.
- Skeleton: 66 bones, plain Mixamo names with **no** `mixamorig` prefix (`Hips`, `Spine`..`Spine2`, `Neck`, `Head`, `LeftShoulder`..`LeftHand`, fingers `*Hand{Thumb,Index,Middle,Ring,Pinky}1-4`, `LeftUpLeg`..`LeftToe_End`) under one extra `root` bone. No bone map is needed.
- Rest pose: T-pose, metres, Y up, **facing +Z** (left arm on +X), hips 1.043 m, all bone scales 1. The tool's toe-direction test turns it onto -Z like the other sources.
- Tracks: rotation on every bone, position on `root` and `Hips` only. In `IP` files `root` stays at the origin; in `RM` files it carries the travel.
- **Corrections to the table above** (it was written from the sellers' pages): hit reactions, deaths, dodges, dashes, rolls, flips, block hits and parries exist **only in the root-motion files**. Sword and shield has 2 block poses (`Block1`, `Block2`) with a hit on each and one parry, not 7 blocks. The two-handed pack has one parry (start / complete / back) and a parry-attack, not 5 parries. The dual pack has **no block or parry at all**. The `_React` files are the victim's half of each attack (paired), not the attacker's.
- The attacks are showy: many turn the fighter's back to the opponent in a spin, and many chain two to four cuts. Rising cuts (up, up-left, up-right) barely exist in the sword-and-shield pack.
