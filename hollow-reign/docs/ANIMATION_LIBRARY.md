# Animation library

One baked library, `assets/anim/humanoid.res` (**169 clips, 2.75 MB**, 221 s of motion; it was 41 clips and 0.80 MB before the bought packs went in), built by `tools/bake_anims.gd` from sources kept
outside the build (`art/anim_src/`, `art/anim/`). Each clip stores every bone's model-space turn away from rest in a
canonical frame (fighter faces -Z, Y up), so any humanoid with the standard bone names plays it (`src/chars/skin_driver.gd`).
Every clip has the same 23 tracks: rotation for 22 bones (hips, three spine bones, neck, head, both shoulders, upper arms, forearms and **hands**, both legs to the toes) and one hip position track. Fingers are not baked; the grip is closed by code.
Licences: Quaternius UAL 1 and 2 are CC0; the Explosive sample is MIT; three clips were bought from Tripo; the `ss_`, `th_` and `dw_` clips come from three Game Dev Hero packs under a paid commercial licence that **forbids passing on the source files**: the FBX stay in the git-ignored `art/anim_src/gamedevhero/`, and only this combined library ships. Texts in `docs/licenses/`. Catalogue of everything in the packs: `ANIMATION_PACKS.md`.

Machine-readable twin of the tables below: `assets/anim/clip_meta.json` (written by the bake; do not edit by hand, edit `tools/anim_pack_clips.json` and re-bake).

## The first 41 clips (free libraries) and where they are used
| Clip | Source | Used for | State |
|---|---|---|---|
| walk, jog, sprint, idle | UAL 1 | walk on the road and in menus; others unused | walk in game |
| sword_idle, shield_idle | UAL 1 / 2 | combat stance (body) | in game |
| cut_a, cut_b (+ recoveries), cut_c, sword_attack | UAL 1 / 2 | body under every sword cut; arm aimed by IK along the swipe | in game |
| combo3, heavy_combo | UAL 2 | not used (whole multi-hit clips; the game needs single hits) | baked only |
| lunge, shield_dash, shield_bash | UAL 2 | combo finishers by kind (counter, armour-piercing, guard-breaking) | in game |
| sword_block | UAL 2 | not used yet | baked only |
| guard_break, knockback, stunned, knockdown | UAL 2 / Explosive | stagger uses stunned; others unused | partly |
| hit_chest, hit_head, hit_f/b/l/r, block_hit | UAL 1 / Explosive | hurt uses hit_chest; directional hits unused | partly |
| step_l, step_r, step_back | Explosive | sidestep (body) | in game |
| roll_l, roll_r, roll_fwd, roll_back | Explosive / UAL 1 | roll (whole body) | in game |
| death, death_b, fall | UAL 1 / Explosive / Tripo | death uses death | in game |
| dive, wounded | Tripo | unused | baked only |

## Clips from the bought packs (128)

`ss_` sword and shield: 61 · `th_` two-handed: 41 · `dw_` dual swords: 26. Since the rig pass they drive every cut, foe blow, parry body, block and draw (see "Authored combat" below); the tables here are the bake's own measurements on the source skeleton.

Reading the attack tables. **Cut**: the way the right-hand blade tip travels while it is out in front of the body, in the fighter's own frame: R = toward the fighter's right, L = left, U = up, D = down, and the diagonals; an opponent facing the fighter sees left and right swapped. **Wind-up** = seconds from the clip's start to when the blade starts into the first cut; **contact** = when the tip is fastest while in front; **recovery** = seconds from the end of the last cut to the clip's end. **Dir** = unit vector [right, up, toward the opponent]. "By eye" is what was seen on `knight_m_ash` in the captures under `marketing/anim_pack_pass/`; a blank means the clip was baked and measured but **not looked at**.

### Sword and shield: attacks, chains and finishers

| Clip | Source file (`..._IP.FBX` / `_RM.FBX`) | Length | Cut | Dir | Wind-up | Contact | Recovery | Further cuts | By eye |
|---|---|---|---|---|---|---|---|---|---|
| `ss_c1_1` | Attack1_Stage1_IP | 2.27 | **L** | -0.9 -0.2 -0.3 | 0.53 | 0.73 | 0.54 | DL @1.40 |  |
| `ss_c1_2` | Attack1_Stage2_IP | 0.70 | none measured | | | | | left arm: UR @0.43 |  |
| `ss_c1_3` | Attack1_Stage3_IP | 1.43 | **R** | +0.8 -0.0 -0.6 | 0.50 | 0.70 | 0.56 | - |  |
| `ss_c4_1` | Attack4_Stage1_IP | 0.60 | **DL** | -0.7 -0.8 -0.0 | 0.43 | 0.43 | 0.00 | - |  |
| `ss_c4_2` | Attack4_Stage2_IP | 1.17 | **R** | +0.8 -0.1 -0.6 | 0.30 | 0.40 | 0.00 | DR @1.10 |  |
| `ss_c4_3` | Attack4_Stage3_IP | 0.67 | none measured | | | | | left arm: L @0.50 |  |
| `ss_c4_4` | Attack4_Stage4_IP | 2.33 | **thrust** | -0.3 +0.3 +0.9 | 0.40 | 0.67 | 1.53 | - |  |
| `ss_c7_1` | Attack7_Stage1_IP | 1.50 | **DR** | +0.8 -0.4 -0.5 | 1.00 | 1.17 | 0.17 | - |  |
| `ss_c7_2` | Attack7_Stage2_IP | 0.47 | none measured | | | | | - |  |
| `ss_c7_3` | Attack7_Stage3_IP | 2.33 | **DL** | -0.5 -0.8 +0.1 | 0.00 | 0.30 | 1.90 | - |  |
| `ss_c8_1` | Attack8_Stage1_IP | 1.33 | **L** | -0.9 +0.3 -0.2 | 0.47 | 0.87 | 0.00 | DL @1.17 |  |
| `ss_c8_2` | Attack8_Stage2_IP | 0.70 | **R** | +0.8 -0.2 -0.5 | 0.23 | 0.53 | 0.00 | - |  |
| `ss_c8_3` | Attack8_Stage3_IP | 1.90 | **DL** | -0.8 -0.6 -0.1 | 0.13 | 0.50 | 1.20 | - |  |
| `ss_cut_d` | Attack4_Stage1_Complete_IP | 0.97 | **DL** | -0.6 -0.8 +0.0 | 0.00 | 0.37 | 0.47 | - | ok: overhead chop ending low on the left; the best 'down' in the pack |
| `ss_cut_dl` | Attack8_Stage3_Complete_IP | 2.23 | **DL** | -0.8 -0.6 -0.1 | 0.47 | 0.83 | 1.20 | - | ok: from the right shoulder down to the left; starts from a mid-chain pose |
| `ss_cut_dr` | Attack7_Stage1_Complete_IP | 1.77 | **DR** | +0.8 -0.4 -0.5 | 1.00 | 1.17 | 0.44 | - | ok: back turned in the wind-up, then high left to low right |
| `ss_cut_dr2` | Attack8_Stage2_Complete_IP | 1.50 | **DR** | +0.9 -0.4 -0.3 | 0.50 | 0.70 | 0.47 | - | ok: high left to low right; starts from a mid-chain pose |
| `ss_cut_l` | Attack9_IP | 2.53 | **L** | -0.2 -0.0 -1.0 | 0.17 | 0.53 | 1.10 | thrust @1.33 | ok: cut right to left, dropping from shoulder to hip height |
| `ss_cut_r` | Attack2_Stage2_Complete_IP | 1.63 | **R** | +0.9 -0.0 -0.4 | 0.43 | 0.60 | 0.90 | - | ok: spin with the back turned in the wind-up, then a level cut left to right |
| `ss_cut_r2` | Attack5_IP | 2.33 | **R** | +0.9 -0.3 -0.2 | 0.87 | 1.07 | 1.03 | - | ok: level cut left to right, then a turn behind the shield |
| `ss_cut_r_high` | Attack1_Stage3_Complete_IP | 1.57 | **R** | +0.8 -0.0 -0.6 | 0.63 | 0.83 | 0.57 | - | ok: high cut left to right |
| `ss_fin_cleave` | Attack7_Stage3_Complete_IP | 2.50 | **DL** | -0.5 -0.8 +0.1 | 0.07 | 0.47 | 1.90 | - | ok: chop from high right down to the front |
| `ss_fin_double` | Attack4_Stage2_Complete_IP | 1.93 | **R** | +0.9 -0.1 -0.4 | 0.43 | 0.57 | 0.50 | DR @1.27 | ok: level cut left to right, a turn, then a second cut |
| `ss_fin_lunge` | Attack4_Stage4_Complete_IP | 2.30 | **thrust** | -0.2 +0.3 +0.9 | 0.43 | 0.67 | 1.50 | - | plausible: shield in front, then the point driven low at the viewer |
| `ss_fin_spin` | Attack2_IP | 2.50 | **R** | +0.9 -0.0 -0.4 | 1.30 | 1.47 | 0.90 | - |  |
| `ss_shield_bash` | Attack1_Stage2_Complete_IP | 1.37 | none measured | | | | | left arm: UR @0.57 |  |
| `ss_shield_bash2` | Attack10_IP | 2.13 | **R** | +0.8 +0.2 -0.6 | 0.07 | 0.63 | 1.10 | - | unclear: reads as a shove with the shield plus a small sword movement (seen in an early capture only) |
| `ss_shield_swipe` | Attack3_Stage1_Complete_IP | 1.77 | none measured | | | | | left arm: L @1.07 |  |
| `ss_spin_l` | Attack1_Stage1_IP [0.00-1.15 s] | 1.15 | **L** | -0.9 -0.2 -0.3 | 0.53 | 0.73 | 0.05 | - | ok but showy: spin, then a cut from high right to low left; ends mid-chain with the back turned (trimmed clip) |
| `ss_thrust` | Attack6_Stage3_Complete_IP | 2.33 | **thrust** | -0.4 +0.3 +0.9 | 0.00 | 0.33 | 1.90 | - | plausible: crouching lunge with the point toward the viewer; hard to read from the front |
| `ss_thrust2` | Attack3_Stage2_Complete_IP | 1.13 | **thrust** | -0.5 +0.4 +0.7 | 0.00 | 0.37 | 0.56 | - | plausible: low crouching thrust, shield lifted; small and hard to read from the front |

Left arm (the shield) in the same clips: `ss_c1_1` L @0.70, DL @2.00; `ss_c1_2` UR @0.43; `ss_c1_3` UR @0.63; `ss_c4_2` R @0.33; `ss_c4_3` L @0.50; `ss_cut_r_high` UR @0.73; `ss_fin_double` R @0.50; `ss_shield_bash` UR @0.57; `ss_shield_swipe` L @1.07; `ss_spin_l` L @0.70; `ss_thrust` L @0.27; `ss_thrust2` L @0.30.

### Sword and shield: everything else

| Clip | Kind | Source file | Length | Loops | Travel (hip heights) | By eye |
|---|---|---|---|---|---|---|
| `ss_block` | block | Block1_IP | 0.77 |  | in place | ok: shield raised in front of chest and face, then lowered |
| `ss_block2` | block | Block2_IP | 0.77 |  | in place | ok: looks the same height as ss_block from front and side; no visible high/mid difference |
| `ss_block2_hit` | block_hit | Block2_Hit_RM | 0.60 |  | 0.26 |  |
| `ss_block2_idle` | block | Block2_Idle_IP | 1.00 | yes | in place |  |
| `ss_block_hit` | block_hit | Block1_Hit_RM | 0.60 |  | 0.28 | ok: shield held, body rocks back |
| `ss_block_idle` | block | Block1_Idle_IP | 1.00 | yes | in place |  |
| `ss_dash_b` | dodge | Dash_Bw_RM | 0.83 |  | 4.17 |  |
| `ss_dash_l` | dodge | Dash_L_RM | 0.83 |  | 3.90 |  |
| `ss_dash_r` | dodge | Dash_R_RM | 0.83 |  | 4.82 | seen only leaving the frame to the right |
| `ss_death_b` | death | Death_Bw_RM | 0.90 |  | 3.87 | seen only leaving the frame backward |
| `ss_death_f` | death | Death_Fw_RM | 0.83 |  | 2.19 | ok: pitches forward to the floor |
| `ss_death_l` | death | Death_L_RM | 0.77 |  | 2.26 |  |
| `ss_death_r` | death | Death_R_RM | 0.60 |  | 0.65 |  |
| `ss_dodge_b` | dodge | Dodge_Bw_RM | 0.60 |  | 2.09 | ok: hop back |
| `ss_dodge_l` | dodge | Dodge_L_RM | 0.60 |  | 2.09 | ok: hop to the fighter's left |
| `ss_dodge_r` | dodge | Dodge_R_RM | 0.60 |  | 2.09 |  |
| `ss_hit_b` | hit | Hit_Bw_RM | 1.33 |  | 1.77 |  |
| `ss_hit_f` | hit | Hit_Fw_RM | 1.33 |  | 1.72 | ok: knocked back; travels about 1.8 m if the clip's travel is applied |
| `ss_hit_l` | hit | Hit_L_RM | 1.33 |  | 1.78 | ok: knocked to the fighter's right |
| `ss_hit_r` | hit | Hit_R_RM | 1.33 |  | 1.77 |  |
| `ss_idle` | idle | Idle1_IP | 1.33 | yes | in place |  |
| `ss_idle2` | idle | Idle2_IP | 1.00 | yes | in place |  |
| `ss_parry` | parry | Block1_Parry_RM | 0.80 |  | 0.01 | ok: shield swept out to the fighter's left, opening the guard |
| `ss_run_f` | move | Run_Fw_Loopable_IP | 0.63 | yes | in place |  |
| `ss_sheath` | equip | Sheath_IP | 0.93 |  | in place |  |
| `ss_unsheath` | equip | Unsheath_IP | 0.93 |  | in place |  |
| `ss_walk_b` | move | Walk_Bw_Loopable_IP | 1.23 | yes | in place |  |
| `ss_walk_f` | move | Walk_Fw_Loopable_IP | 1.23 | yes | in place | ok: walks forward, feet on the floor |
| `ss_walk_l` | move | Walk_L_Loopable_IP | 1.23 | yes | in place |  |
| `ss_walk_r` | move | Walk_R_Loopable_IP | 1.23 | yes | in place |  |

### Two-handed: attacks, chains and finishers

| Clip | Source file (`..._IP.FBX` / `_RM.FBX`) | Length | Cut | Dir | Wind-up | Contact | Recovery | Further cuts | By eye |
|---|---|---|---|---|---|---|---|---|---|
| `th_combo4` | Attack10_IP | 2.60 | **DR** | +0.8 -0.4 -0.4 | 0.43 | 0.60 | 0.20 | DL @1.03, L @1.53, DR @2.10 |  |
| `th_combo_thrust` | Attack1_IP | 1.83 | **DL** | -0.8 -0.4 -0.3 | 0.13 | 0.33 | 0.43 | D @0.83, thrust @1.30 | ok: chop, chop, then a thrust |
| `th_cut_d` | Attack4_Stage1_Complete_IP | 0.73 | **D** | +0.3 -0.9 -0.2 | 0.03 | 0.33 | 0.03 | - | ok: overhead chop; the tip is fastest a few frames after the marked contact |
| `th_cut_d2` | Attack1_Stage1_Complete_IP | 0.93 | **D** | -0.2 -1.0 +0.1 | 0.13 | 0.33 | 0.43 | - | ok: overhead chop driven into the ground in front |
| `th_cut_dl` | Attack11_IP | 1.67 | **DL** | -0.8 -0.5 -0.3 | 0.47 | 0.73 | 0.77 | - | ok: leaping cut from high right to low left (both feet leave the floor) |
| `th_cut_dl2` | Attack9_Stage1_Complete_IP | 1.07 | **DL** | -0.8 -0.5 -0.4 | 0.33 | 0.47 | 0.44 | - | ok: high right to low left |
| `th_cut_dr` | Attack7_Stage1_Complete_IP | 1.17 | **DR** | +0.8 -0.4 -0.4 | 0.43 | 0.60 | 0.10 | - | ok: high left to low right |
| `th_cut_l` | Attack5_Stage2_Complete_IP | 0.90 | **L** | -0.9 -0.3 +0.1 | 0.07 | 0.40 | 0.00 | R @0.70 | ok: cut right to left, then a return cut |
| `th_cut_r` | Attack3_Stage1_Complete_IP | 1.23 | **R** | +0.9 -0.1 -0.5 | 0.53 | 0.73 | 0.10 | - | ok: level cut left to right |
| `th_cut_r2` | Attack5_Stage3_Complete_IP | 1.03 | **R** | +0.8 -0.1 -0.6 | 0.30 | 0.43 | 0.36 | - | ok: level cut left to right from a mid-chain pose |
| `th_cut_u` | Attack2_Stage1_Complete_IP | 0.80 | **U** | -0.2 +0.9 -0.3 | 0.13 | 0.33 | 0.00 | - | ok: rising cut on the right side, low to overhead |
| `th_cut_ur` | Attack1_Stage3_Complete_IP | 0.93 | **UR** | +0.3 +0.4 -0.9 | 0.50 | 0.67 | 0.00 | - | ok: rising cut from low left to high right |
| `th_dash_attack` | DashAttack_RM | 0.93 | **L** | -1.0 -0.0 -0.1 | 0.10 | 0.47 | 0.00 | R @0.73 | seen only leaving the frame toward the viewer |
| `th_jump_attack` | JumpAttack_RM | 0.83 | **D** | +0.4 -0.9 +0.0 | 0.00 | 0.47 | 0.26 | - | seen only leaving the frame toward the viewer (5.9 hip heights of travel) |
| `th_overhead` | Attack8_IP | 1.40 | **DL** | -0.7 -0.6 -0.4 | 0.00 | 0.23 | 0.00 | D @0.73, U @1.00 | ok: two overhead chops |
| `th_parry_attack` | ParryAttack_RM | 0.80 | none measured | | | | | - |  |
| `th_spin` | Attack7_IP | 2.43 | **DR** | +0.8 -0.4 -0.4 | 0.43 | 0.60 | 0.46 | L @1.20, R @1.40, R @1.83 |  |
| `th_sweep` | Attack3_IP | 2.57 | **R** | +0.9 -0.1 -0.5 | 0.53 | 0.73 | 0.24 | DL @1.03, DL @1.60, UR @1.87 |  |

### Two-handed: everything else

| Clip | Kind | Source file | Length | Loops | Travel (hip heights) | By eye |
|---|---|---|---|---|---|---|
| `th_block` | block | Defense_IP | 0.53 |  | in place | ok: blade brought up to guard and back |
| `th_block_hit_b` | block_hit | Defense_Hit_Bw_RM | 0.60 |  | 2.40 |  |
| `th_block_hit_f` | block_hit | Defense_Hit_Fw_RM | 0.67 |  | 0.81 | ok: guard held, shoved back |
| `th_block_hit_l` | block_hit | Defense_Hit_L_RM | 0.53 |  | 0.17 |  |
| `th_block_hit_r` | block_hit | Defense_Hit_R_RM | 0.60 |  | 1.25 |  |
| `th_block_in` | block | Defense_Start_IP | 0.23 |  | in place |  |
| `th_block_out` | block | Defense_Back_IP | 0.27 |  | in place |  |
| `th_death_b` | death | Death_Bw_RM | 0.40 |  | 2.13 |  |
| `th_death_f` | death | Death_Fw_RM | 0.40 |  | 3.05 | seen only leaving the frame backward |
| `th_dodge_b` | dodge | Dodge_Bw_RM | 0.37 |  | 2.09 |  |
| `th_dodge_l` | dodge | Dodge_L_RM | 0.37 |  | 2.09 |  |
| `th_dodge_r` | dodge | Dodge_R_RM | 0.37 |  | 2.09 |  |
| `th_guard` | block | Defense_Idle_IP | 1.47 | yes | in place | ok: blade held up across the front; the left hand is open, off the handle |
| `th_hit_b` | hit | Hit_Bw_RM | 0.57 |  | 0.71 |  |
| `th_hit_f` | hit | Hit_Fw_RM | 0.60 |  | 0.21 | ok: small flinch |
| `th_hit_l` | hit | Hit_L_RM | 0.57 |  | 0.25 |  |
| `th_hit_r` | hit | Hit_R_RM | 0.53 |  | 0.33 |  |
| `th_idle` | idle | Idle1_IP | 1.33 | yes | in place | ok: low guard, blade trailing behind |
| `th_idle2` | idle | Idle2_IP | 1.30 | yes | in place |  |
| `th_parry` | parry | Parry_Complete_RM | 0.33 |  | 0.06 | ok: blade snapped up overhead |
| `th_roll_l` | dodge | Roll_L_RM | 0.73 |  | 5.20 |  |
| `th_roll_r` | dodge | Roll_R_RM | 0.73 |  | 5.46 |  |
| `th_walk_f` | move | Walk_Fw_Loopable_IP | 0.80 | yes | in place |  |

### Dual swords: attacks, chains and finishers

| Clip | Source file (`..._IP.FBX` / `_RM.FBX`) | Length | Cut | Dir | Wind-up | Contact | Recovery | Further cuts | By eye |
|---|---|---|---|---|---|---|---|---|---|
| `dw_a2` | Attack2_IP | 3.10 | **DL** | -0.9 -0.5 -0.1 | 0.83 | 1.40 | 0.93 | R @2.00 |  |
| `dw_a5` | Attack5_IP | 2.37 | **thrust** | -0.4 +0.3 +0.8 | 0.00 | 0.47 | 0.77 | DR @0.83, R @1.37 |  |
| `dw_cross` | Attack1_IP | 2.50 | **L** | -1.0 -0.2 -0.2 | 1.00 | 1.27 | 0.03 | UL @1.73, DR @2.20 |  |
| `dw_cut_dl` | Attack8_IP | 1.80 | **DL** | -0.9 -0.4 -0.0 | 0.33 | 0.57 | 0.93 | - | ok: right blade from overhead down to the left |
| `dw_cut_dr` | Attack10_Stage1_Complete_IP | 1.33 | **DR** | +0.1 -0.2 -1.0 | 0.00 | 0.67 | 0.50 | - | ok: right blade high left to right |
| `dw_cut_l` | Attack4_Stage2_Complete_IP | 1.53 | **L** | -1.0 -0.0 -0.2 | 0.00 | 0.20 | 0.73 | - | poor: the measured cut at 0.20 s is the blades crossing; the visible action is a spin later in the clip |
| `dw_cut_r` | Attack3_Stage2_Complete_IP | 1.33 | **R** | +0.9 -0.3 -0.2 | 0.53 | 0.70 | 0.50 | - | ok: right blade left to right |
| `dw_cut_r2` | Attack10_Stage3_Complete_IP | 1.53 | **R** | +0.7 -0.1 -0.7 | 0.43 | 0.60 | 0.80 | - |  |
| `dw_double` | Attack4_IP | 2.03 | **L** | -1.0 +0.2 -0.1 | 0.03 | 0.20 | 0.76 | DL @0.73 |  |
| `dw_flurry` | Attack9_IP | 3.07 | **thrust** | -0.4 +0.2 +0.9 | 0.00 | 0.30 | 0.37 | L @1.33, DL @1.93, R @2.43 | ok (side view): lunge with both blades, more cuts follow |
| `dw_lunge` | Attack7_IP | 2.23 | **DL** | -0.8 -0.6 -0.1 | 0.10 | 0.50 | 1.00 | thrust @1.20 | ok: right blade down-left, then a jumping turn |
| `dw_spin` | Attack10_IP | 2.63 | **D** | +0.3 -0.6 -0.7 | 0.00 | 0.63 | 0.80 | R @1.70 | ok (side view): low spinning cuts |
| `dw_thrust` | Attack10_Stage2_Complete_IP | 1.00 | **thrust** | -0.4 +0.3 +0.9 | 0.07 | 0.33 | 0.60 | - | plausible: both blades drawn in then driven forward; hard to read from the front |
| `dw_x` | Attack6_IP | 2.30 | **DL** | -0.7 -0.7 -0.2 | 0.63 | 1.10 | 0.03 | UR @1.77, DR @2.03 | ok: turn with the back to the viewer, then crossing cuts |

Left arm (the second sword) in the same clips: `dw_a2` thrust @0.93, DR @1.30, DR @2.07; `dw_a5` UR @0.40, R @0.93, thrust @1.90; `dw_cross` thrust @0.73, L @1.07, L @1.53; `dw_cut_dl` L @0.50, L @1.17; `dw_cut_dr` UL @0.23, R @0.67; `dw_cut_l` L @0.77; `dw_cut_r` R @0.77; `dw_cut_r2` UL @0.17, DR @0.37, L @1.23; `dw_double` L @1.27; `dw_flurry` UR @0.10, R @0.63, L @1.33, L @1.87, R @2.47, L @2.93; `dw_lunge` DL @1.23; `dw_spin` UL @0.23, R @0.67, R @1.43, thrust @2.40; `dw_thrust` UR @0.10, D @0.60.

### Dual swords: everything else

| Clip | Kind | Source file | Length | Loops | Travel (hip heights) | By eye |
|---|---|---|---|---|---|---|
| `dw_death_b` | death | Death_Bw_RM | 0.50 |  | 2.81 | ok: pitches forward to the floor (named Bw in the pack) |
| `dw_death_f` | death | Death_Fw_RM | 0.50 |  | 1.70 |  |
| `dw_dodge_b` | dodge | Dodge_Bw_RM | 0.50 |  | 2.09 |  |
| `dw_dodge_l` | dodge | Dodge_L_RM | 0.50 |  | 2.09 | ok: hop to the fighter's left |
| `dw_dodge_r` | dodge | Dodge_R_RM | 0.50 |  | 2.09 |  |
| `dw_hit_b` | hit | Hit_Bw_RM | 0.73 |  | 0.19 |  |
| `dw_hit_f` | hit | Hit_Fw_RM | 0.73 |  | 1.46 | ok: knocked back |
| `dw_hit_l` | hit | Hit_L_RM | 0.73 |  | 1.88 |  |
| `dw_hit_r` | hit | Hit_R_RM | 0.73 |  | 1.77 |  |
| `dw_idle` | idle | Idle1_IP | 1.33 | yes | in place | ok, but only the right-hand sword is visible in the capture |
| `dw_idle2` | idle | Idle2_IP | 1.00 | yes | in place |  |
| `dw_walk_f` | move | Walk_Fw_Loopable_IP | 0.93 | yes | in place | ok: walks forward with both blades |

### Which clip for which swipe

First measured cut of each single attack (chains and finishers left out). Swipe names as in `DuelSim.DIRS`, in the fighter's own frame.

| Cut | Sword and shield | Two-handed | Dual |
|---|---|---|---|
| L | `ss_cut_l`, `ss_spin_l` | `th_cut_l`, `th_dash_attack` | `dw_double` |
| R | `ss_cut_r`, `ss_cut_r2`, `ss_cut_r_high` | `th_cut_r`, `th_cut_r2` | `dw_cut_r`, `dw_cut_r2` |
| U | **none** | `th_cut_u` | **none** |
| D | `ss_cut_d` | `th_cut_d`, `th_cut_d2` | **none** |
| UL | **none** | **none** | **none** |
| UR | **none** | `th_cut_ur` | **none** |
| DL | `ss_cut_dl` | `th_cut_dl`, `th_cut_dl2` | `dw_a2`, `dw_cut_dl`, `dw_lunge` |
| DR | `ss_cut_dr`, `ss_cut_dr2` | `th_cut_dr` | `dw_cut_dr` |
| thrust | `ss_thrust`, `ss_thrust2` | **none** | `dw_a5`, `dw_thrust` |

`ss_cut_d` measures as DL (it ends low on the left) but is an overhead chop by eye and is listed under D. `dw_cut_l` is left out: its measured cut is not a cut by eye.
**Gaps: sword and shield has no rising cut at all (U, UL, UR) and dual swords have none either and no straight D.** For those swipes keep the present IK arm, or borrow the nearest diagonal.

### Chains (sword and shield)
`ss_c4_1..4`, `ss_c8_1..3`, `ss_c7_1..3`, `ss_c1_1..3` are the stages of four pack attacks, in order (`chain` and `stage` in `clip_meta.json`). Each stage ends in a held pose and the next starts from it, so they can be played back to back; to stop a chain early, blend from the end of a stage to `ss_idle` (the packs' own `_Back` return clips were not baked). Stages with no measured cut (`ss_c4_3`, `ss_c7_2`, `ss_c1_2`) are shield shoves or steps between cuts. The chain stages were **not** looked at one by one; their parents were seen as `ss_cut_*` / `ss_fin_*` (`_Complete` versions of the same stages).

## Authored combat (the rig pass)

`FighterRig` now swings from these clips with the whole body. Code: the "authored attacks" part of `src/chars/fighter_rig.gd` (tables `AU_CUTS`, `AU_COMBOS`), and in `src/chars/skin_driver.gd` the per-arm mask (`arm_r`, `arm_l`), the eased change of pose (`crossfade`), the sword-arm roll (`clip_roll`) and `clip_hand()`, which works out where a clip puts a hand on the model in use without posing it. `--noauthored` (or `FighterRig.authored = false`) plays the old procedural arm for comparison.

**The rules own the time.** The rig's state machine is unchanged and still follows `DuelSim`: a player's cut lands at 60% of the class's swing time (sword 0.16 s, axe 0.23 s, greatsword 0.28 s, dual 0.11 s after the swipe), a foe's at the end of its telegraph. For each attack the rig:
1. finds the clip's *contact*: the moment in the cut at which the far part of the blade is furthest ahead of the fighter, measured on the model and weapon in use (`au_contact`; the bake's `contact`, tip fastest, is after the blade has passed the centre on a level cut);
2. finds the *wound-up pose*: the moment before contact at which the blade is furthest back along the line it is about to travel (high for a falling cut, out to the left for a cut to the right);
3. maps time: a player's cut starts 0.1 s of clip before the wound-up pose and runs to contact in the time the rules give (slow at first, fastest at contact), so the clip's own 0.4–1.0 s wind-up is never played; a foe eases into the wound-up pose in the first 0.2 s of its warning, **holds it for the whole warning window**, and goes from it to contact in the last half of its `swing`; after contact the clip runs on at 1.2 times its own pace;
4. eases in from whatever pose came before over 0.09 s (0.05 s for dual blades), so the blade moves on the first frame;
5. stops what is played of the follow-through where the chest would turn more than 75° from the opponent or the hand would come back beside the wielder's own neck (the packs' spins and over-the-shoulder recoveries are not shown), and never plays into the next cut of a multi-cut clip.

**Direction.** The line the blade tip travels over the last 70 ms before the hit (as seen from behind the fighter) is computed for the clip on this model; the sword arm is then rolled about the line to the opponent (30% at the collar bone, 70% at the shoulder, at most 57°) until that line is the swiped one. Where two clips are offered for a swipe the one that ends nearer the line is played.

**Contact.** The blade stops in the first body it meets (the clip is walked in sub-steps against the opponent's capsules, as the procedural cut was) and is held 0.13 s, longer for a combo's last cut. `halt()` freezes a foe's cut at its contact pose. `reach()` is that of the clip chosen, so the duel steps the fighter to where the blade arrives (the duel now asks after `swing()`). `clash()` and `brace()` are unchanged: the pinned arm is taken off the clip (`arm_r` / `arm_l` = 0) and solved to the world point on the frame it is asked for, while the body goes on with the clip.

### Which clip for which swipe (as played)

Swipes are in the fighter's own frame; a foe facing the camera swaps left and right. "roll" is what the solver applies on `knight_m` at the class's own swing time.

| Swipe | Sword and shield (also axe, cleaver, sword alone) | Two-handed (greatsword, glaive) | Dual |
|---|---|---|---|
| R | `ss_cut_r_high` | `th_cut_r2` | `dw_cut_r` |
| L | `ss_cut_l` (roll ≈ −20°) | `th_cut_l` first cut (roll ≈ −20°) | `dw_double` first cut (roll ≈ +25°) |
| D | `ss_cut_d` | `th_cut_d` | `dw_cut_dr` (measures down-left on the rig; roll ≈ +30°) |
| DL | `ss_cut_dl` | `th_cut_l` first cut (roll ≈ +20°) | `dw_cut_dl` |
| DR | `ss_cut_dr2` (roll ≈ −20°) | `th_cut_dr` | `dw_cross` third cut |
| U | `th_cut_u` with the sword arm only; shield arm on its own guard | `th_cut_u` | `th_cut_u` (both blades rise together) |
| UL | `th_cut_u`, as U, rolled left | `th_cut_u` rolled left | `th_cut_u` rolled left |
| UR | `ss_cut_r_high` rolled up ≈ 40° | `th_cut_u` rolled right or `th_cut_r2` rolled up, whichever ends nearer | `dw_cut_r` rolled up |
| thrust (foes) | `ss_thrust2` | `th_combo_thrust` third blow | `dw_flurry` first blow |

Claws stay procedural (no set suits them). **The missing rising cuts:** for sword and shield, U and UL borrow the two-handed rising cut one-handed (body and sword arm from the clip, shield arm masked back to its procedural guard), and UR is the high right cut rolled upward; chosen by looking at `marketing/authored_pass/ss_knight_m.jpg` against the procedural arm. Dual blades borrow the same rising cut with both hands.

Rejected for ordinary cuts after looking or measuring on the rig: `ss_c8_1` (a raised knee through the whole cut), `ss_cut_r`, `ss_cut_dr`, `ss_c7_1`, `ss_fin_spin`, `th_cut_r`, `th_sweep` (start with the back to the opponent: chest 120–145° away), `th_cut_dl` (leaves the floor), `th_cut_dl2` (knee lifted to hip height in the wind-up), `dw_cross` first cut and `dw_cut_l` (side-on at contact). `tools/anim_pack_clips.json` was not changed: trimming is done at play time.

### Combos

`Duel` hands the rig the combos the player knows (`combo_book`). The rig keeps its own short history of swipes; from the second cut of a recognised sequence each cut is the one written for that place in that combo, and the cut that completes one (the rules name its kind) is its finisher, held or followed through longer. The first cut is always the ordinary one for its swipe: nothing is known yet. Every cut still lands on the rules' instant and is still rolled onto its swipe.

| Combo (swipes) | Sword and shield / axe | Two-handed | Dual |
|---|---|---|---|
| Double Slash (L R) | return cut `ss_c8_2` | `th_cut_l` return cut | `dw_a2` second cut |
| Riposte (U R) | `ss_fin_double` first cut | `th_cut_l` return cut | – |
| Rising Fang (D U R) | last: `ss_c4_2` | last: `th_cut_l` return cut | last: `dw_a2` second cut |
| Armor Splitter (R L D) | last: `ss_fin_cleave` | last: `th_cut_d2` (into the ground) | last: `dw_lunge` |
| Crossbreaker (L UR DL) | last: `ss_c8_3` | last: `th_cut_dl2` | last: `dw_x` first cut |
| Mirror Step (DR UL DR) | last: `ss_c8_2` | last: `th_spin` third cut | last: `dw_x` third cut |
| Falling Crown (U D D) | `ss_c4_1`, then `th_cut_d2` one-handed | last: `th_cut_d2` | last: `dw_lunge` |
| Reversal (R L R U) | third `ss_cut_r2`, last `th_cut_u` held | third `th_cut_l` return, last `th_cut_u` held | third `dw_a2` second cut |
| Serpent's Path (DL UR L D) | last: `ss_c7_3` | last: `th_overhead` | last: `dw_lunge` |
| Eternal Edge (U DR L UL D) | second `ss_c8_2`, last `th_cut_d` one-handed | last: `th_cut_d2` | last: `dw_lunge` |
| Twin Fang (L R L R, dual) | | | `dw_a2` second cut, `dw_cut_l`, `dw_cut_r` |
| Whirlwind (UL DR UR DL, dual) | | | second `dw_x` third cut, last `dw_x` first cut |
| Headsman's Due (U D, axe) | last: `th_cut_d2` one-handed | | |
| Timberfall (DL DR D, axe) | second `ss_c8_2`, last `ss_fin_cleave` | | |
| Colossus (D D, greatsword) | | second: `th_cut_d2` | |
| Tidebreaker (L R D U, greatsword) | | `th_cut_l` return, `th_cut_d2`, `th_cut_u` held | |

Limits: combos sharing their first cuts cannot differ there; several finishers reuse a clip (`th_cut_d2`, `dw_lunge`); a finisher that bites is held in the body, so its own recovery is only seen when it meets nothing.

### Parry, block, draw

- Parry: body and shield arm from `ss_parry` (shield swept aside) or `th_parry`; the sword arm stays on the procedural parry arc and is then pinned by `clash()`. Dual: procedural, the packs have none.
- Block: `ss_block_idle` / `th_guard` while the guard is up; on `brace()` the body plays `ss_block_hit` / `th_block_hit_f` and the shield arm is pinned to the blow.
- `draw()` / `sheath()`: body from `ss_unsheath` / `ss_sheath` (all classes: only that pack has them). The weapon hangs at the left hip (long blades across the back, a second blade at the right hip); the hand is brought onto the grip by IK before the weapon moves, and carries it back before letting go.
- Hit reactions, staggers and deaths are unchanged (the free-library clips of the QA pass); sidesteps and rolls now use the packs' (see "Motion polish").

### Equipment on the rig (2026-11-26, gear pass)

- **Body and armour.** `look.parts` = `{body, helm, chest, shoulders, arms, legs, boots -> suit id}`; `FighterRig.build` dresses the base knight (`ArmorParts.host_path`) from it, `wear_parts(loadout)` swaps pieces on a standing rig, `has_parts()`. `SkinDriver.measure_parts` re-measures floor contact, clearances and hit volumes from the worn meshes. `CineActor` inherits this through `Duel.player_look()`.
- **Hand-modelled gear** (`look.gear`, `look.gear_mod`, `look.shield.gear`): spawned by `GearModel.spawn` and placed by the manifest (`GearModel.hold`), never fitted. `weapon_len` = `tip` x `rig_scale`, `_pommel`, `_off_grip` (two-handers: `off_hand`), board centre and half-sizes (`_sh_c`, `_sh_hw`, `_sh_hh`) feed `reach()`, `_off_floor`, the off-hand reach, `_clear_shield`, the body push and `hit_caps`.
- **Which way a sword is turned.** A gear sword's +X is its knuckle side (Veilcutter is turned half round to agree); `_held_basis` lays +X over the knuckles of the holding hand (`SkinDriver.grip_fwd`), so cuts lead with the true edge and a knuckle bow covers the fingers. The left blade of a pair is the mirror image.
- **Shield.** A shield's face is its local -Z everywhere on a fighter (`PropModel.shield(..., face_out)` turns the fitted first-generation models to agree; the Armory's own flip is gone). A gear shield is *worn*: grip bar in the fist on the forearm's line, +X along the forearm (elbow to hand), so the board follows the forearm and its face is the outside of the arm. The guard hand is carried across the body for it (`SkinDriver.pole_l`: elbow out). In falls, rolls and hit reactions the board is turned to face away from the chest, and the arm is taken along when the board is pushed off the body.
- **Hands.** `SkinDriver.curl(side, 0..1)` closes the fingers and thumb; the rig closes the sword hand on the grip and the shield hand on the bar (only on fighters carrying the new equipment), opens them for a sheathed weapon and during a Recall.
- **Presenting the weapon.** `present_weapon(style := "auto", opts := {})` -> seconds. `auto`: Recall for an advanced weapon (full the first time `opts.key` is seen in a session, short after, short when `opts.quick`), a draw for an ordinary one (nothing when `opts.quick`); `"recall"`, `"recall_short"`, `"draw"`, `"none"`; `opts.slot = "shield"`. The receiving hand is open for the first 30% and closed by 48% of the Recall, as the hilt forms. `draw()` / `sheath()` on an advanced weapon recall and dismiss it instead. A cut thrown meanwhile completes it at once. `Recall.play(rig, item_id, short)` is the Armory's hook.
- `--oldlook` / `FighterRig.old_look`: whole-suit swap and first-generation weapon models, for comparison.

Audit on the new body (`pose_review`, 30 fps, sampling as dense as on one suit; both bodies; Wayfarer, Silver Vow, Ashbrand, Veilcutter with the heater, the round and tower shields, Oathbreaker, Twin Relics): lowest point 0.00-0.02 in every state (no foot under the floor), `float` 0.02-0.05, shield-hand vertices through the board 0, body vertices in the board 0, off hand on the greatsword's grip 0.00, `dir_err` within 5 deg (sword and shield), 6 (greatsword), 10 (pair). Open: see the register.

### Motion polish: stance, planted feet, sidestep, roll, road walk (2026-11-27)

No clip was added to the library in this pass (still 169 clips, 2.75 MB): everything used was already baked. Code: the
"motion polish" sections at the end of `src/chars/fighter_rig.gd`, the "feet placed by the rig" and "a clip's own travel"
sections of `src/chars/skin_driver.gd`. `--oldanim` (or `FighterRig.polish = false`) plays what was there before.

- **Guard.** Body and legs from the packs' own stances (`ss_idle`, `th_idle`, `dw_idle`, body-only at 0.85 so the arms stay
  on IK and the gear's grip points stay exact). Sword hand at chest height with the blade up and angled at the opponent
  (`_guard_pose`), a strapped shield at the ribs angled across the body, the greatsword in a middle guard with both hands
  on the grip, the pair offset (off blade lower, point at the belly). Slow breathing and a drift of the point.
  Behind a raised shield (`ss_block_idle`, `ss_block_hit`) the sword arm keeps that guard: the pack's block holds the
  sword low and level across the body, which from the duel camera was a blade lying sideways.
- **Feet in a fight (`_feet_step`).** Each foot is planted in the world. When the body has moved 17 cm off a foot (5 cm
  once it has stood still for 0.3 s) that foot steps to where the stance wants it, one foot at a time, travelling while it
  is off the floor. This replaces the sine footwork cycle for circling, shoves, steps in and back; the hips drop if a leg
  cannot reach. Off during an authored cut (the clip's own step shows) and during a roll.
- **Sidestep.** `ss_dodge_l/r`, `th_dodge_l/r`, `dw_dodge_l/r` as whole-body clips (sword arm kept on its guard; the clip
  trails it level). The rules own the time (the rig's 0.5 s) and the duel owns the distance (1.25 m): the clip is played
  over that time, front-loaded (`1 - (1-u)^1.7`), and the body is put where the clip's own travel curve says, scaled to
  1.25 m (`_dg_root`: rig offset = wanted travel minus what the duel has already moved the rig). What each foot does
  along the line of travel is scaled by the same factor (`_feet_dodge`), so a foot planted in the clip is planted in the
  world. The packs have no forward dodge; `ss_dodge_b` is baked but the game has no back-step input, so it is unused.
- **Roll.** `th_roll_l/r` for every weapon set (the only authored combat roll in the packs: sword and shield has flips,
  not rolls). The tumble takes the first 66% of the rig's 0.84 s (`ROLL_UP`) and the rest is the rise into guard, so the
  knight stands ready when the rules free them; travel is scaled from about 5 m to what is left of the duel's 2.55 m,
  and the body keeps half-way between the clip's curve and where the duel has the rig (the camera follows the rig). Grounded by the
  lowest body point. A strapped shield is slung onto the back for the roll (`_dock`: on the mid-spine, face outward, the
  body raised up to 6 cm to roll over it) and comes back onto the arm as the knight rises; the feet that land in the
  last third are scaled like a sidestep's.
- **Road walk.** Free-library `walk` as a whole-body clip (arms swing; sword carried low with the point forward and down,
  the shield hanging on the arm; greatsword: arms stay on IK). Stride from the clip measured on the skeleton in use
  (`SkinDriver.clip_stride`, 1.28 m a cycle on the knight), shortened on a climb. Out of combat the body follows whoever
  moves the rig as a damped mass (`_travel`): it gathers way and comes to rest over about half a second and turns through
  an arc, which is this pass's start and stop (the packs' `Walk_Fw_Start/End` were not baked). A foot that is down stays
  where it came down, at the height `FighterRig.ground` gives (`HighRoad` sets `Highland.height`); the hips come down to
  the lower foot, the body leans into the slope. `CineActor` stands with the sword low (`rest_carry`).
- **Cuts.** A strapped shield arm takes only 30% of an authored cut's arm pose (it was thrown back with the board's face
  to the camera).

- **After the camera pass for rolls and sidesteps (same day; docs/CAMERA_BIBLE.md "The move shot").** The duel now carries
  the knight round the circle they stand on at the clip's own pace (`FighterRig.carry_step`), so in a sidestep or a roll
  the body is on the rig's origin (no half-way placement, no slide back as the roll rises). A sidestep passes over the
  first 15% of its clip and plays the rest as `1 - (1-u)^2.2` (`DODGE_SKIP`, `DODGE_WARP`): 40 cm off the line at
  0.06-0.10 s. The shield goes onto the back and comes off it in two frames. `--oldrollcam` plays all of this as it was.

Audit additions (`pose_review`): `slip` (cm an ankle travels over the ground while within 3 cm of its standing height,
worst single contact), `moved` / `off10` / `off40` (seconds until the hips have moved 1, 10, 40 cm), `sh_arm` (shield-arm
vertices through the face of the board); states `circle`, `shove`, `road`; `dodge_*` and `roll_*` are now carried across
the floor as the duel carries them; `--strip=<fps> --view=duel|side|front|back|q` writes one view as a strip of frames;
`--slope=<deg>` walks the `road` state up a slope with a 16 cm rock step; `--strides` prints clip strides and travel curves.

### Rig API added

`sheath(instant := false) -> float`, `draw(instant := false) -> float` (seconds it will take), `is_sheathed() -> bool`, `preview_attack(dir := "R", time := 0.5) -> float`, `preview_block(hold := 1.0) -> float` (seconds until back in guard), `au_set() -> String`, `combo_book: Array`, static `authored: bool`, static `clip_meta(name) -> Dictionary`. `ArmoryRig` overrides `_pick_clip`; the authored layer runs after it (`_au_apply`), so these work there too while an attack, block or draw is in progress.

## How to play one of these clips with the arms (for the rig pass)
The clips carry both arms, both hands and the spine. What decides whether the arms follow the clip is **`SkinDriver.clip_full`**:

- `skin.clip_full = false` (what `FighterRig._pick_clip` sets for cuts today): `_overlay(false)` applies hips, spine, neck, head and legs only, limits the trunk's turn to `TRUNK_YAW`, and both arms are then solved by IK to the procedural hand targets.
- `skin.clip_full = true` with `skin.clip_w > 0`: after the IK, `drive()` calls `_overlay(true)`, which writes the clip's `LeftShoulder/Arm/ForeArm/Hand` and `RightShoulder/Arm/ForeArm/Hand` rotations at weight `clip_w`; `FighterRig._fit_props` then sees `whole == true` and turns the sword to `skin.hand_axis("Right")` (and the second sword to `hand_axis("Left")`, the shield to the left forearm). This is exactly the path `test_clip` and the death and hit clips already use, and the path every capture in `marketing/anim_pack_pass/` went through.
- Also set `skin.clip_travel = 0.0` unless the clip's own travel is wanted: the hip track stores travel from the first frame in hip heights, and the root-motion clips travel a long way (`hip_travel` in the meta: dodges 2.1, hits up to 1.8, `th_jump_attack` 5.9).
- Per-arm mask: `skin.arm_r` and `skin.arm_l` (0..1) scale how much of a whole-body clip each arm takes; 0 leaves that arm on IK.

Suggested lookup for a swipe: read `assets/anim/clip_meta.json` once; for the weapon class take the prefix (`ss_` sword with shield, `th_` greatsword, `dw_` dual); among clips with `kind == "attack"` pick one whose `use_for` (if present) or else `swipe` equals the swipe (`"L"`, `"UR"`, ... or `"thrust"`); fall back to the present body clip plus IK arm where the table above says none. If the game's swipe is the direction on screen with the camera behind the player, it is already in the fighter's frame; for a foe facing the camera, left and right are swapped (`mirror`).

Timing: the duel's own phases should drive the clip's time, not the other way round, because the wind-ups are long (0.4 to 1.0 s) and differ per clip. Map `WINDUP` onto clip time `0 .. hits[0].start` (or start part-way in, e.g. from `start - 0.25`, to shorten a long wind-up), `STRIKE` onto `start .. end` with the sim's hit instant placed on `contact`, and `FOLLOW` onto `end .. length`. `windup`, `contact` and `recovery` at the top of each entry repeat the first cut's numbers; `hits[]` has every cut (`start`, `contact`, `end`, `front` = the stretch the tip is in front, `dir`, `swipe`, `at` = where the tip is at contact relative to the hips' ground point, in hip heights, `hand_peak` = when the hand itself is fastest, `tip_speed` in hip heights per second). All times are seconds from the baked clip's start.

Each clip's `rest_dir` meta now also has `LeftHand` and `RightHand` (toward the middle knuckle) for the pack clips. `SkinDriver.LIMB_CHILD` does not list the hands, so it is unused; adding `"LeftHand": "LeftHandMiddle1", "RightHand": "RightHandMiddle1"` there would line an A-pose model's rest hand up with the T-pose source. Not done (the file was being edited by another pass) and not tested.

## How the cuts are measured
`tools/bake_anims.gd` poses the source skeleton at 30 fps and follows a point 0.85 hip heights along each hand's blade axis (from the little-finger knuckle toward the index knuckle: the same axis `SkinDriver.hand_axis` gives the game's sword). A **cut** is a stretch where that tip is at least 0.6 hip heights ahead of the hips, below 1.9 hip heights (not being carried round over the head), and moving faster than 6 hip heights a second, with a peak of at least 10; its direction is the tip's travel over that stretch, weighted by speed. A **thrust** is the tip being driven at least 0.5 further forward to 1.1 or more ahead of the hips without such a cut. Fast movement beside or behind the body counts as wind-up or return. This is a measurement on the source skeleton with an assumed blade length, not on the game's weapons: contact times are good to about two frames, and the labels were wrong or doubtful for a few clips, noted in the "By eye" column (`after` in `tools/anim_pack_clips.json` drops a back-swing that passes in front).

## Seen in the captures (defects included)
Captures: `marketing/anim_pack_pass/*.jpg`, all through the game's `FighterRig` + `SkinDriver` with `clip_full`, on `knight_m_ash`; one from the `--screen=animtest --clip=` viewer, the rest from `tools/dev/clip_sheet.sh` (front = from where the opponent stands, side = from the fighter's right).
- Facing, handedness and scale are right: the fighter faces -Z, sword in the right hand, shield on the left forearm, feet on the floor in idles, walks, blocks and cuts, no twisted limbs seen.
- The sword stays in the hand in every frame looked at.
- The pack is showy: `ss_cut_r`, `ss_cut_dr`, `ss_spin_l`, `ss_cut_r2`, `ss_fin_double`, `dw_x`, `dw_cut_l` turn the fighter's back to the opponent for part of the clip; `th_cut_dl`, `dw_lunge` leave the floor.
- Wind-ups are long for a swipe game (0.4 to 1.0 s before the blade starts in).
- Two-handed: the left hand is open and off the handle in `th_guard` and in some frames of `th_cut_u`, `th_cut_l`, `th_cut_d2` (the rig's off-hand reach does not always land).
- `th_cut_d2` drives the blade tip to the floor in front; the rig's floor guard keeps it from going through.
- `dw_idle`: only the right-hand sword is visible in the side capture; not explained.
- The shield crosses in front of the body and sword arm in the spins (as authored).
- `ss_block` and `ss_block2` look the same height: the pack has no distinct high and mid block.
- Root-motion clips (`*_hit_*`, `*_death_*`, `*_dodge_*`, `*_dash_*`, `th_roll_*`, `th_jump_attack`, `th_dash_attack`) travel out of the capture frame within a few frames, so their later poses (lying dead, landing) were **not seen**.
- Not looked at at all: the chain stages `ss_c*`, `ss_idle*`, `ss_run_f`, `ss_walk_b/l/r`, `ss_sheath/unsheath`, the `_l/_r/_b` variants of hits, deaths, dodges and dashes not named above, `th_roll_*`, `th_spin`, `th_sweep`, `th_combo4`, `th_parry_attack`, `dw_a2`, `dw_a5`, `dw_cross`, `dw_double`, `dw_cut_r2`. Nothing was judged in motion: only stills.

## What the packs do not have
- No block or parry of any kind for dual swords.
- No hit-on-block for the sword beyond `ss_block_hit` / `ss_block2_hit`; one shield parry (`ss_parry`), one two-handed parry (`th_parry`).
- Dodges only left, right, back (and diagonals back); no forward dodge. Dashes, rolls (two-handed and dual) and flips (sword and shield) exist in eight directions; only a few were baked.
- Deaths are short (0.4 to 0.9 s) throws in four directions.

## What is still procedural
- With `--noauthored`: the sword arm in every cut. Otherwise only: claws, dual-blade parries and blocks, the sword arm of a parry up to the pin, and the roll that aims a clip's cut along the swipe.
- Combat footwork steps while circling (the stance clip fades out while the feet step).
- Dragons: neck aim, claw swipe, jaw, gait, tail and wings are driven bone by bone (`src/chars/dragon_skin.gd`); no authored creature clips exist.

## Gaps against the brief
| Wanted | Have | Needs |
|---|---|---|
| Eight authored directional cuts | in game for all three sets; rising cuts for sword and shield and for dual are the two-handed rising cut borrowed, UR a right cut rolled upward | true one-handed rising cuts do not exist in the packs |
| Sixteen individually animated combos | each has its own table row from its second cut on (see Combos); finishers reuse a few clips | more finisher clips; first cuts cannot differ |
| Directional parries, high/low shield blocks | one shield block height, one shield parry, one two-handed parry baked | not in the packs |
| Greatsword and dual-blade sets | in game | dual has no block or parry clip |
| Dragon walk, wing, bite, death clips | procedural bone driving | authored creature animation |

## Adding clips
GLB sources: put the file under `art/`, add it to `SOURCES` in `tools/bake_anims.gd` with a bone map (Mixamo names need none).
Bought packs (FBX, read with `FBXDocument`): add a line to `tools/anim_pack_clips.json`: `"<prefix>_<name>": {"src": "<clip name without the pack prefix and _IP/_RM>", "kind": "attack|combo|finisher|shield_attack|block|block_hit|parry|hit|death|dodge|idle|move|equip"}` plus, as needed, `"loop": true`, `"rm": true` (take the root-motion file), `"from"` / `"to"` (seconds: bake part of a clip), `"after"` (ignore cuts before this time), `"chain"` / `"stage"`, `"use_for"`, `"seen"`.
Then run `godot --headless --path . --script tools/bake_anims.gd` (about 15 s; rewrites the library and `clip_meta.json`; the first 41 clips come out bit-identical) and look at the result: `--screen=animtest --clip=<name> [--model=<glb>] [--body=f]`, or a contact sheet with `tools/dev/clip_sheet.sh --clips=a,b --out=<png> [--views=front,side] [--weapon=greatsword|dual] [--n=7]`.
`tools/bake_anims.gd -- --catalogue=<json>` measures every file in the packs instead (this is what `ANIMATION_PACKS.md` is made from); `tools/dev/fbx_probe.gd -- <file>` prints one file's skeleton and tracks.
