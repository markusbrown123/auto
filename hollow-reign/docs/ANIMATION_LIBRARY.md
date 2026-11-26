# Animation library

One baked library, `assets/anim/humanoid.res` (41 clips, about 0.8 MB), built by `tools/bake_anims.gd` from sources kept
outside the build (`art/anim_src/`, `art/anim/`). Each clip stores every bone's model-space turn away from rest in a
canonical frame, so any humanoid with the standard bone names plays it (`src/chars/skin_driver.gd`).
Licences: Quaternius UAL 1 and 2 are CC0; the Explosive sample is MIT; three clips were bought from Tripo. Texts in `docs/licenses/`.

## Clips and where they are used
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

## What is still procedural
- The sword arm in every cut (so that eight swipe directions exist at all), parries, the shield arm.
- Combat footwork steps while circling (the stance clip fades out while the feet step).
- Dragons: neck aim, claw swipe, jaw, gait, tail and wings are driven bone by bone (`src/chars/dragon_skin.gd`); no authored creature clips exist.

## Gaps against the brief
| Wanted | Have | Needs |
|---|---|---|
| Eight authored directional cuts | two generic cut bodies + IK arm | a directional sword set (paid; see `ANIMATION_SOURCES.md`) |
| Sixteen individually animated combos | finisher body by combo *kind* (5 kinds) | same paid set, or hand-authored chains |
| Directional parries, high/low shield blocks | procedural | same |
| Greatsword and dual-blade sets | greatsword reuses two clips; dual uses the sword clips | same |
| Dragon walk, wing, bite, death clips | procedural bone driving | authored creature animation |

## Adding clips
Put the source GLB under `art/`, add it to `SOURCES` in `tools/bake_anims.gd` with a bone map (Mixamo names need none),
run `godot --headless --path . --script tools/bake_anims.gd`, then view with `--screen=animtest --clip=<name> [--model=<glb>] [--body=f]`.
