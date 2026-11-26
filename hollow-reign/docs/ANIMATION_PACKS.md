# Bought animation packs: catalogue

Three Game Dev Hero packs (itch.io, paid commercial licence), Mixamo-skeleton FBX, unpacked under `art/anim_src/gamedevhero/` (git-ignored).
**The licence forbids passing the source files on and this repository is public: no FBX, and no per-file conversion of one, may be put anywhere tracked.** Only the baked, combined game library `assets/anim/humanoid.res` ships (see `ANIMATION_LIBRARY.md`).

This file is generated from a scan of every file by `tools/bake_anims.gd -- --catalogue=<json>`: lengths are read from the files (30 fps), and the cuts are measured, not taken from the names (how: `ANIMATION_LIBRARY.md`, "How the cuts are measured"). Measured cut labels on clips that were not baked have **not** been checked by eye.

| Pack | Prefix in game | Folder | In-place (`IP/`) files | Root-motion (`RM/`) files |
|---|---|---|---|---|
| Sword And Shield Animation V3 | `ss_` | `SwordShieldV3/SwordShieldV3_Mixamo/` | 166 | 189 |
| Two Handed Sword Animation V3 | `th_` | `TwoHandedSwordAnimationV3/TwoHandedSwordAnimationV3_Mixamo/` | 189 | 282 |
| Dual Sword Animation V1 | `dw_` | `DualSwordAnimationV1/DualSwordAnimationV1_Mixamo/` | 167 | 188 |
| **Total** | | | **522** | **659** (all: 1181) |

## How the files are named
- File: `<pack prefix><Clip>_IP.FBX` (in place: the root stays put, the hips still shift within a pace) or `<Clip>_RM.FBX` (root motion: a `root` bone carries the travel). Every in-place clip also exists with root motion; **dodges, dashes, rolls, flips, hits, deaths, block hits and parries exist only with root motion**.
- `AttackN`: the whole attack from guard back to guard. Many are chains of two to four cuts.
- `AttackN_StageK`: the K-th piece of the chain, ending in a held pose from which the next stage starts. Stage 1 starts from guard. Playing Stage1, Stage2, ... in order gives the whole attack.
- `AttackN_StageK_Back`: the return to guard from the end of stage K (used when the chain is not continued).
- `AttackN_StageK_Complete`: stage K followed by its return to guard, as one clip.
- `AttackN_StageK_Start` (two-handed only): stage K with a short lead-in, for starting the chain at that stage.
- `..._React`: the **victim's** reaction to that attack, the same length as the attack and timed to it (paired animation). Not an attack.
- Locomotion: `Walk_` / `Run_` + direction (`Fw`, `Bw`, `L`, `R`, `FL`, `FR`, `BL`, `BR`) + `Start` / `Loopable` / `End` / `Complete` (= start + loop + end).
- Each FBX holds exactly one clip (named `Unreal Take`) on a 66-bone Mixamo skeleton with fingers; no mesh, no weapon bones.

## Sword And Shield Animation V3 (`ss_`)

### Attacks (10 attacks, 63 files in place, the same again as `_React` victims)

Cuts: direction the right-hand blade tip travels while in front of the body (R = toward the fighter's own right, L = left, U = up, D = down, thrust) @ seconds from the clip's start. "Left" = the same for the left hand (a shield, or the second sword).

| Clip | Length | Cuts (right hand) | Left hand |
|---|---|---|---|
| **Attack1** | 134 f / 4.47 s | L @0.73, DL @1.40, thrust @2.60, R @3.73 | L @0.70, DL @2.00, UR @2.73, UR @3.63 |
| Attack1_Stage1 | 68 f / 2.27 s | L @0.73, DL @1.40 | L @0.70, DL @2.00 |
| Attack1_Stage1_Back | 21 f / 0.70 s | (return) |  |
| Attack1_Stage1_Complete | 90 f / 3.00 s | L @0.73, DL @1.40 | L @0.70, DL @2.00 |
| Attack1_Stage2 | 21 f / 0.70 s | - | UR @0.43 |
| Attack1_Stage2_Back | 15 f / 0.50 s | (return) |  |
| Attack1_Stage2_Complete | 41 f / 1.37 s | - | UR @0.57 |
| Attack1_Stage3 | 43 f / 1.43 s | R @0.70 | UR @0.63 |
| Attack1_Stage3_Complete | 47 f / 1.57 s | R @0.83 | UR @0.73 |
| **Attack2** | 75 f / 2.50 s | R @1.47 | - |
| Attack2_Stage1 | 28 f / 0.93 s | - | - |
| Attack2_Stage1_Back | 11 f / 0.37 s | (return) |  |
| Attack2_Stage1_Complete | 40 f / 1.33 s | - | - |
| Attack2_Stage2 | 46 f / 1.53 s | R @0.50 | - |
| Attack2_Stage2_Complete | 49 f / 1.63 s | R @0.60 | - |
| **Attack3** | 70 f / 2.33 s | thrust @1.57 | L @1.07, L @1.53 |
| Attack3_Stage1 | 40 f / 1.33 s | - | L @1.07 |
| Attack3_Stage1_Back | 12 f / 0.40 s | (return) |  |
| Attack3_Stage1_Complete | 53 f / 1.77 s | - | L @1.07 |
| Attack3_Stage2 | 29 f / 0.97 s | thrust @0.23 | L @0.17 |
| Attack3_Stage2_Complete | 34 f / 1.13 s | thrust @0.37 | L @0.30 |
| **Attack4** | 146 f / 4.87 s | UL @0.30, DL @0.43, R @1.03, DR @1.73, thrust @3.20 | R @0.97, L @2.33 |
| Attack4_Stage1 | 18 f / 0.60 s | UL @0.30, DL @0.43 | - |
| Attack4_Stage1_Back | 14 f / 0.47 s | (return) |  |
| Attack4_Stage1_Complete | 29 f / 0.97 s | DL @0.37 | - |
| Attack4_Stage2 | 35 f / 1.17 s | U @0.07, R @0.40, DR @1.10 | R @0.33 |
| Attack4_Stage2_Back | 17 f / 0.57 s | (return) |  |
| Attack4_Stage2_Complete | 58 f / 1.93 s | UL @0.13, R @0.57, DR @1.27 | R @0.50 |
| Attack4_Stage3 | 20 f / 0.67 s | - | L @0.50 |
| Attack4_Stage3_Back | 12 f / 0.40 s | (return) |  |
| Attack4_Stage3_Complete | 30 f / 1.00 s | - | L @0.40 |
| Attack4_Stage4 | 70 f / 2.33 s | thrust @0.67 | - |
| Attack4_Stage4_Complete | 69 f / 2.30 s | thrust @0.67 | - |
| **Attack5** | 70 f / 2.33 s | R @1.07 | - |
| **Attack6** | 126 f / 4.20 s | U @0.23, thrust @2.20 | L @2.13 |
| Attack6_Stage1 | 45 f / 1.50 s | U @0.23 | - |
| Attack6_Stage1_Back | 14 f / 0.47 s | (return) |  |
| Attack6_Stage1_Complete | 60 f / 2.00 s | U @0.23 | - |
| Attack6_Stage2 | 13 f / 0.43 s | - | - |
| Attack6_Stage2_Back | 7 f / 0.23 s | (return) |  |
| Attack6_Stage2_Complete | 27 f / 0.90 s | - | - |
| Attack6_Stage3 | 66 f / 2.20 s | thrust @0.23 | L @0.13 |
| Attack6_Stage3_Complete | 70 f / 2.33 s | thrust @0.33 | L @0.27 |
| **Attack7** | 131 f / 4.37 s | DR @1.17, DL @2.33 | - |
| Attack7_Stage1 | 45 f / 1.50 s | DR @1.17 | - |
| Attack7_Stage1_Back | 7 f / 0.23 s | (return) |  |
| Attack7_Stage1_Complete | 53 f / 1.77 s | DR @1.17 | - |
| Attack7_Stage2 | 14 f / 0.47 s | - | - |
| Attack7_Stage2_Back | 10 f / 0.33 s | (return) |  |
| Attack7_Stage2_Complete | 29 f / 0.97 s | - | - |
| Attack7_Stage3 | 70 f / 2.33 s | DL @0.30 | - |
| Attack7_Stage3_Complete | 75 f / 2.50 s | DL @0.47 | - |
| **Attack8** | 120 f / 4.00 s | L @0.87, DL @1.17, R @1.90, DL @2.60 | - |
| Attack8_Stage1 | 40 f / 1.33 s | L @0.87, DL @1.17 | - |
| Attack8_Stage1_Back | 19 f / 0.63 s | (return) |  |
| Attack8_Stage1_Complete | 60 f / 2.00 s | L @0.87, DL @1.17 | - |
| Attack8_Stage2 | 21 f / 0.70 s | R @0.53 | - |
| Attack8_Stage2_Back | 14 f / 0.47 s | (return) |  |
| Attack8_Stage2_Complete | 45 f / 1.50 s | UL @0.10, DR @0.70 | - |
| Attack8_Stage3 | 57 f / 1.90 s | DL @0.50 | - |
| Attack8_Stage3_Complete | 67 f / 2.23 s | DL @0.83 | - |
| **Attack9** | 76 f / 2.53 s | L @0.53, thrust @1.33 | - |
| **Attack10** | 64 f / 2.13 s | R @0.63 | - |

### Guard, block, idle, jump, equip (in place)

| Clip | Length |
|---|---|
| Block1 | 23 f / 0.77 s |
| Block1_Idle | 30 f / 1.00 s |
| Block2 | 23 f / 0.77 s |
| Block2_Idle | 30 f / 1.00 s |
| Idle1 | 40 f / 1.33 s |
| Idle2 | 30 f / 1.00 s |
| Jump | 33 f / 1.10 s |
| Sheath | 28 f / 0.93 s |
| Unsheath | 28 f / 0.93 s |

### Locomotion (in place; 8 directions each)

| Set | Start | Loopable | End | Complete |
|---|---|---|---|---|
| Walk_Fw | 19 f / 0.63 s | 37 f / 1.23 s | 12 f / 0.40 s | 70 f / 2.33 s |
| Walk_Bw | 19 f / 0.63 s | 37 f / 1.23 s | 12 f / 0.40 s | 70 f / 2.33 s |
| Walk_L | 19 f / 0.63 s | 37 f / 1.23 s | 12 f / 0.40 s | 70 f / 2.33 s |
| Walk_R | 19 f / 0.63 s | 37 f / 1.23 s | 12 f / 0.40 s | 70 f / 2.33 s |
| Walk_FL | 19 f / 0.63 s | 37 f / 1.23 s | 12 f / 0.40 s | 70 f / 2.33 s |
| Walk_FR | 19 f / 0.63 s | 37 f / 1.23 s | 12 f / 0.40 s | 70 f / 2.33 s |
| Walk_BL | 19 f / 0.63 s | 37 f / 1.23 s | 12 f / 0.40 s | 70 f / 2.33 s |
| Walk_BR | 19 f / 0.63 s | 37 f / 1.23 s | 12 f / 0.40 s | 70 f / 2.33 s |
| Run_Fw | 12 f / 0.40 s | 19 f / 0.63 s | 7 f / 0.23 s | 40 f / 1.33 s |
| Run_Bw | 12 f / 0.40 s | 19 f / 0.63 s | 7 f / 0.23 s | 40 f / 1.33 s |
| Run_L | 12 f / 0.40 s | 19 f / 0.63 s | 7 f / 0.23 s | 40 f / 1.33 s |
| Run_R | 12 f / 0.40 s | 19 f / 0.63 s | 7 f / 0.23 s | 40 f / 1.33 s |
| Run_FL | 12 f / 0.40 s | 19 f / 0.63 s | 7 f / 0.23 s | 40 f / 1.33 s |
| Run_FR | 12 f / 0.40 s | 19 f / 0.63 s | 7 f / 0.23 s | 40 f / 1.33 s |
| Run_BL | 12 f / 0.40 s | 19 f / 0.63 s | 7 f / 0.23 s | 40 f / 1.33 s |
| Run_BR | 12 f / 0.40 s | 19 f / 0.63 s | 7 f / 0.23 s | 40 f / 1.33 s |

### Root-motion only (32 files, `RM/`)

| Group | Variants | Length | Cuts measured |
|---|---|---|---|
| Block1_Hit | - | 18 f / 0.60 s | - |
| Block1_Parry | - | 24 f / 0.80 s | - |
| Block2_Hit | - | 18 f / 0.60 s | - |
| Dash | BL, BR, Bw, FL, FR, Fw, L, R | 25 f / 0.83 s | - |
| Death | Bw, Fw, L, R | 18-27 f / 0.60-0.90 s | - |
| Dodge | BL, BR, Bw, L, R | 18 f / 0.60 s | - |
| Flip | BL, BR, Bw, FL, FR, Fw, L, R | 29 f / 0.97 s | - |
| Hit | Bw, Fw, L, R | 40 f / 1.33 s | - |

### Victim reactions (`_React`, in place): lengths match the attack of the same name (30 files)

## Two Handed Sword Animation V3 (`th_`)

### Attacks (11 attacks, 78 files in place, the same again as `_React` victims)

Cuts: direction the right-hand blade tip travels while in front of the body (R = toward the fighter's own right, L = left, U = up, D = down, thrust) @ seconds from the clip's start. "Left" = the same for the left hand (a shield, or the second sword).

| Clip | Length | Cuts (right hand) | Left hand |
|---|---|---|---|
| **Attack1** | 55 f / 1.83 s | DL @0.33, D @0.83, thrust @1.30 | DL @0.33, D @0.83, thrust @1.30 |
| Attack1_Stage1 | 13 f / 0.43 s | D @0.33 | D @0.33 |
| Attack1_Stage1_Back | 14 f / 0.47 s | (return) |  |
| Attack1_Stage1_Complete | 28 f / 0.93 s | D @0.33 | D @0.33 |
| Attack1_Stage2 | 15 f / 0.50 s | UL @0.00, D @0.37 | UL @0.00, D @0.37 |
| Attack1_Stage2_Start | 19 f / 0.63 s | D @0.50 | L @0.17, D @0.50 |
| Attack1_Stage2_Back | 13 f / 0.43 s | (return) |  |
| Attack1_Stage2_Complete | 33 f / 1.10 s | D @0.50 | L @0.17, D @0.50, UR @0.83 |
| Attack1_Stage3 | 25 f / 0.83 s | thrust @0.30 | thrust @0.30 |
| Attack1_Stage3_Complete | 28 f / 0.93 s | UR @0.67 | DL @0.20 |
| **Attack2** | 42 f / 1.40 s | U @0.33 | UL @0.33 |
| Attack2_Stage1 | 12 f / 0.40 s | UL @0.33 | - |
| Attack2_Stage1_Back | 11 f / 0.37 s | (return) |  |
| Attack2_Stage1_Complete | 24 f / 0.80 s | U @0.33 | - |
| Attack2_Stage2 | 29 f / 0.97 s | - | - |
| Attack2_Stage2_Complete | 34 f / 1.13 s | - | - |
| **Attack3** | 77 f / 2.57 s | R @0.73, DL @1.03, DL @1.60, UR @1.87 | L @1.40 |
| Attack3_Stage1 | 26 f / 0.87 s | R @0.73 | - |
| Attack3_Stage1_Back | 10 f / 0.33 s | (return) |  |
| Attack3_Stage1_Complete | 37 f / 1.23 s | R @0.73 | - |
| Attack3_Stage2 | 50 f / 1.67 s | DL @0.13, DL @0.70, UR @0.97 | L @0.50 |
| Attack3_Stage2_Complete | 57 f / 1.90 s | DL @0.40, DL @0.93, UR @1.20 | L @0.73 |
| **Attack4** | 41 f / 1.37 s | D @0.33, L @0.60, U @0.80 | D @0.33 |
| Attack4_Stage1 | 12 f / 0.40 s | D @0.33 | D @0.33 |
| Attack4_Stage1_Back | 9 f / 0.30 s | (return) |  |
| Attack4_Stage1_Complete | 22 f / 0.73 s | D @0.33 | DR @0.33 |
| Attack4_Stage2 | 28 f / 0.93 s | L @0.17, U @0.33 | - |
| Attack4_Stage2_Complete | 29 f / 0.97 s | L @0.13, U @0.40 | U @0.13 |
| **Attack5** | 54 f / 1.80 s | L @0.90, R @1.20 | - |
| Attack5_Stage1 | 18 f / 0.60 s | - | - |
| Attack5_Stage1_Back | 10 f / 0.33 s | (return) |  |
| Attack5_Stage1_Complete | 29 f / 0.97 s | - | - |
| Attack5_Stage2 | 11 f / 0.37 s | L @0.27 | - |
| Attack5_Stage2_Start | 14 f / 0.47 s | L @0.40 | - |
| Attack5_Stage2_Back | 12 f / 0.40 s | (return) |  |
| Attack5_Stage2_Complete | 27 f / 0.90 s | L @0.40, R @0.70 | - |
| Attack5_Stage3 | 23 f / 0.77 s | R @0.17 | - |
| Attack5_Stage3_Complete | 31 f / 1.03 s | R @0.43 | - |
| **Attack6** | 79 f / 2.63 s | L @0.23, R @0.97, L @1.33, DR @1.60, R @2.07 | - |
| Attack6_Stage1 | 34 f / 1.13 s | L @0.23, R @0.97 | - |
| Attack6_Stage1_Back | 11 f / 0.37 s | (return) |  |
| Attack6_Stage1_Complete | 45 f / 1.50 s | L @0.23, R @0.97 | - |
| Attack6_Stage2 | 15 f / 0.50 s | L @0.17, DR @0.47 | - |
| Attack6_Stage2_Start | 22 f / 0.73 s | L @0.40, DR @0.70 | - |
| Attack6_Stage2_Back | 10 f / 0.33 s | (return) |  |
| Attack6_Stage2_Complete | 33 f / 1.10 s | L @0.40, DR @0.70 | - |
| Attack6_Stage3 | 28 f / 0.93 s | R @0.37 | - |
| Attack6_Stage3_Complete | 29 f / 0.97 s | R @0.40 | - |
| **Attack7** | 73 f / 2.43 s | DR @0.60, L @1.20, R @1.40, R @1.83 | D @1.00 |
| Attack7_Stage1 | 22 f / 0.73 s | DR @0.60 | - |
| Attack7_Stage1_Back | 12 f / 0.40 s | (return) |  |
| Attack7_Stage1_Complete | 35 f / 1.17 s | DR @0.60 | - |
| Attack7_Stage2 | 11 f / 0.37 s | DL @0.20 | D @0.23 |
| Attack7_Stage2_Start | 16 f / 0.53 s | DL @0.37 | D @0.40 |
| Attack7_Stage2_Back | 11 f / 0.37 s | (return) |  |
| Attack7_Stage2_Complete | 28 f / 0.93 s | DL @0.37, R @0.67 | D @0.40 |
| Attack7_Stage3 | 38 f / 1.27 s | R @0.23, R @0.67 | - |
| Attack7_Stage3_Complete | 41 f / 1.37 s | U @0.33, R @0.77 | - |
| **Attack8** | 42 f / 1.40 s | DL @0.23, D @0.73, U @1.00 | D @0.23, D @0.73, UR @1.13 |
| Attack8_Stage1 | 9 f / 0.30 s | D @0.23 | D @0.23 |
| Attack8_Stage1_Back | 9 f / 0.30 s | (return) |  |
| Attack8_Stage1_Complete | 19 f / 0.63 s | D @0.23 | DR @0.23 |
| Attack8_Stage2 | 32 f / 1.07 s | UL @0.00, D @0.40, U @0.67 | D @0.40, UR @0.80 |
| Attack8_Stage2_Complete | 37 f / 1.23 s | D @0.57, U @0.83 | D @0.57, UR @0.97 |
| **Attack9** | 43 f / 1.43 s | DL @0.47, DR @0.87 | - |
| Attack9_Stage1 | 18 f / 0.60 s | DL @0.47 | - |
| Attack9_Stage1_Back | 13 f / 0.43 s | (return) |  |
| Attack9_Stage1_Complete | 32 f / 1.07 s | DL @0.47 | R @0.80 |
| Attack9_Stage2 | 24 f / 0.80 s | DR @0.23 | - |
| Attack9_Stage2_Complete | 29 f / 0.97 s | UL @0.17, DR @0.40 | - |
| **Attack10** | 78 f / 2.60 s | DR @0.60, DL @1.03, L @1.53, DR @2.10 | DL @1.07 |
| Attack10_Stage2 | 28 f / 0.93 s | DL @0.27, L @0.77 | DL @0.30 |
| Attack10_Stage2_Start | 33 f / 1.10 s | DL @0.43, L @0.93 | DL @0.47 |
| Attack10_Stage2_Back | 12 f / 0.40 s | (return) |  |
| Attack10_Stage2_Complete | 46 f / 1.53 s | DL @0.43, L @0.93 | DL @0.47 |
| Attack10_Stage3 | 26 f / 0.87 s | DR @0.37 | - |
| Attack10_Stage3_Complete | 32 f / 1.07 s | UL @0.17, DR @0.57 | - |
| **Attack11** | 50 f / 1.67 s | DL @0.73 | DL @0.70 |

### Guard, block, idle, jump, equip (in place)

| Clip | Length |
|---|---|
| Defense | 16 f / 0.53 s |
| Defense_Back | 8 f / 0.27 s |
| Defense_Idle | 44 f / 1.47 s |
| Defense_Start | 7 f / 0.23 s |
| Idle1 | 40 f / 1.33 s |
| Idle2 | 39 f / 1.30 s |
| Jump | 26 f / 0.87 s |
| Jump_Air | 5 f / 0.17 s |
| Jump_Land | 13 f / 0.43 s |
| Jump_Start | 6 f / 0.20 s |
| Sheath | 18 f / 0.60 s |
| Unsheath | 18 f / 0.60 s |

### Locomotion (in place; 8 directions each)

| Set | Start | Loopable | End | Complete |
|---|---|---|---|---|
| Walk_Fw | 6 f / 0.20 s | 24 f / 0.80 s | 6 f / 0.20 s | 38 f / 1.27 s |
| Walk_Bw | 6 f / 0.20 s | 23 f / 0.77 s | 6 f / 0.20 s | 37 f / 1.23 s |
| Walk_L | 6 f / 0.20 s | 24 f / 0.80 s | 6 f / 0.20 s | 38 f / 1.27 s |
| Walk_R | 6 f / 0.20 s | 24 f / 0.80 s | 6 f / 0.20 s | 38 f / 1.27 s |
| Walk_FL | 6 f / 0.20 s | 24 f / 0.80 s | 6 f / 0.20 s | 38 f / 1.27 s |
| Walk_FR | 6 f / 0.20 s | 24 f / 0.80 s | 6 f / 0.20 s | 38 f / 1.27 s |
| Walk_BL | 7 f / 0.23 s | 23 f / 0.77 s | 8 f / 0.27 s | 40 f / 1.33 s |
| Walk_BR | 6 f / 0.20 s | 23 f / 0.77 s | 7 f / 0.23 s | 38 f / 1.27 s |
| Run_Fw | 9 f / 0.30 s | 15 f / 0.50 s | 7 f / 0.23 s | 33 f / 1.10 s |
| Run_Bw | 5 f / 0.17 s | 15 f / 0.50 s | 5 f / 0.17 s | 27 f / 0.90 s |
| Run_L | 9 f / 0.30 s | 15 f / 0.50 s | 7 f / 0.23 s | 33 f / 1.10 s |
| Run_R | 9 f / 0.30 s | 15 f / 0.50 s | 7 f / 0.23 s | 33 f / 1.10 s |
| Run_FL | 9 f / 0.30 s | 15 f / 0.50 s | 7 f / 0.23 s | 33 f / 1.10 s |
| Run_FR | 9 f / 0.30 s | 15 f / 0.50 s | 7 f / 0.23 s | 33 f / 1.10 s |
| Run_BL | 5 f / 0.17 s | 15 f / 0.50 s | 5 f / 0.17 s | 27 f / 0.90 s |
| Run_BR | 5 f / 0.17 s | 15 f / 0.50 s | 4 f / 0.13 s | 26 f / 0.87 s |

### Root-motion only (105 files, `RM/`)

| Group | Variants | Length | Cuts measured |
|---|---|---|---|
| DashAttack | - | 28 f / 0.93 s | L @0.47, R @0.73 |
| DashRun | BL, BR, Bw, FL, FR, Fw, L, R | 16-17 f / 0.53-0.57 s | - |
| DashRun_Dash | BL, BR, Bw, FL, FR, Fw, L, R | 9-11 f / 0.30-0.37 s | - |
| DashRun_Run | BL, BR, Bw, FL, FR, Fw, L, R | 4-6 f / 0.13-0.20 s | - |
| Dash | BL, BR, Bw, FL, FR, Fw, L, R | 14 f / 0.47 s | - |
| Dash_Back | BL, BR, Bw, FL, FR, Fw, L, R | 2-4 f / 0.07-0.13 s | - |
| Death | Bw, Fw, L, R | 12 f / 0.40 s | - |
| Defense_Death | Bw, Fw, L, R | 11-13 f / 0.37-0.43 s | - |
| Defense_Hit | Bw, Fw, L, R | 16-20 f / 0.53-0.67 s | - |
| Dodge | BL, BR, Bw, L, R | 11 f / 0.37 s | - |
| Hit | Bw, Fw, L, R | 16-18 f / 0.53-0.60 s | - |
| JumpAttack | - | 25 f / 0.83 s | D @0.47 |
| JumpRun | - | 29 f / 0.97 s | - |
| JumpRun_Jump | BL, BR, Bw, FL, FR, Fw, L, R | 18 f / 0.60 s | - |
| JumpRun_Run | - | 10 f / 0.33 s | - |
| Jump | BL, BR, Bw, FL, FR, Fw, L, R | 22 f / 0.73 s | - |
| ParryAttack | - | 24 f / 0.80 s | - |
| ParryAttack_AttackOnly | - | 17 f / 0.57 s | - |
| Parry_Back | - | 3 f / 0.10 s | - |
| Parry_Complete | - | 10 f / 0.33 s | - |
| Parry_Start | - | 6 f / 0.20 s | - |
| RollAttack | - | 38 f / 1.27 s | L @0.80, R @1.03 |
| RollRun | - | 25 f / 0.83 s | - |
| RollRun_Roll | BL, BR, Bw, FL, FR, Fw, L, R | 17 f / 0.57 s | - |
| RollRun_Run | - | 7 f / 0.23 s | - |
| Roll | BL, BR, Bw, FL, FR, Fw, L, R | 22 f / 0.73 s | - |

### Victim reactions (`_React`, in place): lengths match the attack of the same name (35 files)

## Dual Sword Animation V1 (`dw_`)

### Attacks (10 attacks, 64 files in place, the same again as `_React` victims)

Cuts: direction the right-hand blade tip travels while in front of the body (R = toward the fighter's own right, L = left, U = up, D = down, thrust) @ seconds from the clip's start. "Left" = the same for the left hand (a shield, or the second sword).

| Clip | Length | Cuts (right hand) | Left hand |
|---|---|---|---|
| **Attack1** | 75 f / 2.50 s | L @1.27, UL @1.73, DR @2.20 | thrust @0.73, L @1.07, L @1.53 |
| Attack1_Stage1 | 26 f / 0.87 s | - | thrust @0.73 |
| Attack1_Stage1_Back | 16 f / 0.53 s | (return) |  |
| Attack1_Stage1_Complete | 43 f / 1.43 s | - | thrust @0.73 |
| Attack1_Stage2 | 48 f / 1.60 s | L @0.37, UL @0.83, DR @1.30 | L @0.17, L @0.63 |
| Attack1_Stage2_Complete | 55 f / 1.83 s | L @0.60, UL @1.07, DR @1.53 | L @0.40, L @0.87 |
| **Attack2** | 93 f / 3.10 s | DL @1.40, R @2.00 | thrust @0.93, DR @1.30, DR @2.07 |
| Attack2_Stage1 | 48 f / 1.60 s | DL @1.40 | thrust @0.93, DR @1.30 |
| Attack2_Stage1_Back | 21 f / 0.70 s | (return) |  |
| Attack2_Stage1_Complete | 70 f / 2.33 s | DL @1.40 | thrust @0.93, DR @1.30 |
| Attack2_Stage2 | 44 f / 1.47 s | R @0.37 | DR @0.43 |
| Attack2_Stage2_Complete | 55 f / 1.83 s | R @0.73 | DR @0.80 |
| **Attack3** | 86 f / 2.87 s | R @1.13 | L @1.77 |
| Attack3_Stage1 | 17 f / 0.57 s | - | - |
| Attack3_Stage1_Back | 15 f / 0.50 s | (return) |  |
| Attack3_Stage1_Complete | 33 f / 1.10 s | - | - |
| Attack3_Stage2 | 22 f / 0.73 s | R @0.53 | R @0.60 |
| Attack3_Stage2_Back | 12 f / 0.40 s | (return) |  |
| Attack3_Stage2_Complete | 40 f / 1.33 s | R @0.70 | R @0.77 |
| Attack3_Stage3 | 45 f / 1.50 s | - | L @0.40 |
| Attack3_Stage3_Complete | 48 f / 1.60 s | - | UR @0.07, L @0.50 |
| **Attack4** | 61 f / 2.03 s | L @0.20, DL @0.73 | L @1.27 |
| Attack4_Stage1 | 24 f / 0.80 s | L @0.20, DL @0.73 | - |
| Attack4_Stage1_Back | 20 f / 0.67 s | (return) |  |
| Attack4_Stage1_Complete | 45 f / 1.50 s | L @0.20, DL @0.73, DR @1.20 | - |
| Attack4_Stage2 | 36 f / 1.20 s | - | L @0.43 |
| Attack4_Stage2_Complete | 46 f / 1.53 s | L @0.20 | L @0.77 |
| **Attack5** | 71 f / 2.37 s | thrust @0.47, DR @0.83, R @1.37 | UR @0.40, R @0.93, thrust @1.90 |
| Attack5_Stage1 | 20 f / 0.67 s | thrust @0.47 | UR @0.40 |
| Attack5_Stage1_Back | 18 f / 0.60 s | (return) |  |
| Attack5_Stage1_Complete | 39 f / 1.30 s | thrust @0.47 | UR @0.40 |
| Attack5_Stage2 | 50 f / 1.67 s | DR @0.13, R @0.67 | DR @0.23, thrust @1.20 |
| Attack5_Stage2_Complete | 60 f / 2.00 s | R @0.47, R @1.00 | DR @0.57, thrust @1.53 |
| **Attack6** | 69 f / 2.30 s | DL @1.10, UR @1.77, DR @2.03 | - |
| Attack6_Stage1 | 20 f / 0.67 s | thrust @0.43 | - |
| Attack6_Stage1_Back | 23 f / 0.77 s | (return) |  |
| Attack6_Stage1_Complete | 44 f / 1.47 s | thrust @0.43 | - |
| Attack6_Stage2 | 48 f / 1.60 s | DL @0.40, UR @1.07, DR @1.33 | - |
| Attack6_Stage2_Complete | 49 f / 1.63 s | DL @0.43, UR @1.10, DR @1.37 | - |
| **Attack7** | 67 f / 2.23 s | DL @0.50, thrust @1.20 | DL @1.23 |
| **Attack8** | 54 f / 1.80 s | DL @0.57 | L @0.50, L @1.17 |
| Attack8_Stage1 | 21 f / 0.70 s | DL @0.57 | L @0.50 |
| Attack8_Stage1_Back | 18 f / 0.60 s | (return) |  |
| Attack8_Stage1_Complete | 40 f / 1.33 s | DL @0.57, R @1.03 | L @0.50 |
| Attack8_Stage2 | 32 f / 1.07 s | - | L @0.43 |
| Attack8_Stage2_Complete | 45 f / 1.50 s | UL @0.20 | L @0.87 |
| **Attack9** | 92 f / 3.07 s | thrust @0.30, L @1.33, DL @1.93, R @2.43 | UR @0.10, R @0.63, L @1.33, L @1.87, R @2.47, L @2.93 |
| Attack9_Stage1 | 27 f / 0.90 s | DR @0.73 | UR @0.10, R @0.63 |
| Attack9_Stage1_Back | 12 f / 0.40 s | (return) |  |
| Attack9_Stage1_Complete | 40 f / 1.33 s | DR @0.73 | UR @0.10, R @0.63 |
| Attack9_Stage2 | 38 f / 1.27 s | L @0.40, DL @1.00 | L @0.40, L @0.93 |
| Attack9_Stage2_Back | 18 f / 0.60 s | (return) |  |
| Attack9_Stage2_Complete | 59 f / 1.97 s | L @0.47, DL @1.07 | UR @0.07, L @0.47, L @1.00 |
| Attack9_Stage3 | 25 f / 0.83 s | R @0.20 | R @0.23, L @0.70 |
| Attack9_Stage3_Complete | 34 f / 1.13 s | L @0.20, R @0.50 | R @0.53 |
| **Attack10** | 79 f / 2.63 s | D @0.63, R @1.70 | UL @0.23, R @0.67, R @1.43, thrust @2.40 |
| Attack10_Stage1 | 25 f / 0.83 s | D @0.63 | UL @0.23, R @0.67 |
| Attack10_Stage1_Back | 14 f / 0.47 s | (return) |  |
| Attack10_Stage1_Complete | 40 f / 1.33 s | DR @0.67 | UL @0.23, R @0.67 |
| Attack10_Stage2 | 11 f / 0.37 s | - | - |
| Attack10_Stage2_Back | 16 f / 0.53 s | (return) |  |
| Attack10_Stage2_Complete | 30 f / 1.00 s | thrust @0.33 | UR @0.10, D @0.60 |
| Attack10_Stage3 | 41 f / 1.37 s | R @0.43 | R @0.17 |
| Attack10_Stage3_Complete | 46 f / 1.53 s | R @0.60 | UL @0.17, DR @0.37, L @1.23 |

### Guard, block, idle, jump, equip (in place)

| Clip | Length |
|---|---|
| Idle1 | 40 f / 1.33 s |
| Idle2 | 30 f / 1.00 s |
| Jump | 34 f / 1.13 s |
| Jump_Land | 17 f / 0.57 s |
| Jump_OnAir | 3 f / 0.10 s |
| Jump_Start | 12 f / 0.40 s |
| Sheath | 27 f / 0.90 s |
| Unsheath | 27 f / 0.90 s |

### Locomotion (in place; 8 directions each)

| Set | Start | Loopable | End | Complete |
|---|---|---|---|---|
| Walk_Fw | 11 f / 0.37 s | 28 f / 0.93 s | 11 f / 0.37 s | 52 f / 1.73 s |
| Walk_Bw | 11 f / 0.37 s | 28 f / 0.93 s | 11 f / 0.37 s | 52 f / 1.73 s |
| Walk_L | 11 f / 0.37 s | 28 f / 0.93 s | 11 f / 0.37 s | 52 f / 1.73 s |
| Walk_R | 11 f / 0.37 s | 28 f / 0.93 s | 11 f / 0.37 s | 52 f / 1.73 s |
| Walk_FL | 11 f / 0.37 s | 28 f / 0.93 s | 11 f / 0.37 s | 52 f / 1.73 s |
| Walk_FR | 11 f / 0.37 s | 28 f / 0.93 s | 11 f / 0.37 s | 52 f / 1.73 s |
| Walk_BL | 11 f / 0.37 s | 28 f / 0.93 s | 11 f / 0.37 s | 52 f / 1.73 s |
| Walk_BR | 11 f / 0.37 s | 28 f / 0.93 s | 11 f / 0.37 s | 52 f / 1.73 s |
| Run_Fw | 10 f / 0.33 s | 19 f / 0.63 s | 11 f / 0.37 s | 42 f / 1.40 s |
| Run_Bw | 10 f / 0.33 s | 19 f / 0.63 s | 11 f / 0.37 s | 42 f / 1.40 s |
| Run_L | 10 f / 0.33 s | 19 f / 0.63 s | 11 f / 0.37 s | 42 f / 1.40 s |
| Run_R | 10 f / 0.33 s | 19 f / 0.63 s | 11 f / 0.37 s | 42 f / 1.40 s |
| Run_FL | 10 f / 0.33 s | 19 f / 0.63 s | 11 f / 0.37 s | 42 f / 1.40 s |
| Run_FR | 10 f / 0.33 s | 19 f / 0.63 s | 11 f / 0.37 s | 42 f / 1.40 s |
| Run_BL | 10 f / 0.33 s | 19 f / 0.63 s | 11 f / 0.37 s | 42 f / 1.40 s |
| Run_BR | 10 f / 0.33 s | 19 f / 0.63 s | 11 f / 0.37 s | 42 f / 1.40 s |

### Root-motion only (29 files, `RM/`)

| Group | Variants | Length | Cuts measured |
|---|---|---|---|
| Dash | BL, BR, Bw, FL, FR, Fw, L, R | 20 f / 0.67 s | - |
| Death | Bw, Fw, L, R | 15 f / 0.50 s | - |
| Dodge | BL, BR, Bw, L, R | 15 f / 0.50 s | - |
| Hit | Bw, Fw, L, R | 22 f / 0.73 s | - |
| Roll | BL, BR, Bw, FL, FR, Fw, L, R | 25 f / 0.83 s | - |

### Victim reactions (`_React`, in place): lengths match the attack of the same name (31 files)

