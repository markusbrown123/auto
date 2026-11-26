# Hollow Reign — audit and bug register

Audit of the Fallen Courtyard / Ashen Sentinel encounter against the overhaul brief.
Everything here was observed in software-rendered captures inside the build container.
Nothing has been run on an iPhone, and no audio has been listened to by a person.

Severity: **A** breaks the fantasy or the fight · **B** clearly visible · **C** polish.

## Fixed in this pass

| # | Sev | Issue | Reproduce | Root cause | Fix | Verified by |
|---|---|---|---|---|---|---|
| 1 | A | Fighters stood on fixed spots for the whole duel | Any duel before this pass | Rigs were placed once in `Duel.setup` | Stance system: both rigs sit on a rotating line; foe circles, closes, gives ground; hits and blocks push bodies back (`Duel._footwork`) | Captures at 7 s and 9 s show different angles and distances |
| 2 | A | Dodge was a lean on the spot | Press a dodge pad | `FighterRig.dodge` only tilted the body | Dodge now moves the knight 1.25 m sideways; the line swings to the new position, the foe turns at its own rate, camera follows | Visual capture; 2,654 rule checks unaffected |
| 3 | A | Only two fixed three-cut combos, not discoverable | L-R-L or U-D-U | Hard-coded `COMBOS` constant | 16 data-driven combos in `data/combos.json`, weapon-class filtered, with posture, stamina, armour-pierce and after-dodge/parry/stagger bonuses | `t_meters_combos` (sequence, repeat-cut, class filter, discovery) |
| 4 | B | No record of combos or place to practise | — | Feature absent | Journal tab (pattern, damage, stamina, use, count) and Orren's training ground (foe stands open, nothing dies) | Captures of both screens; training checks in tests |
| 5 | B | Blocking had one outcome | Hold shield | Single block branch | Timed block (raised within 0.22 s of impact): no stamina, no chip damage, adds posture and burst | Test "a block raised at the last instant costs nothing" |
| 6 | B | Control pads always fully drawn over the fight | Any duel | Fixed 62% fill | Pads rest at 20%, light fully with a glow under the thumb, fade back; "Control visibility" slider down to hidden; touch areas unchanged | Capture; touch suite passes |
| 7 | A | Walk and death were procedural and read as puppetry | Explore road; die | No authored motion | Nine authored clips bought and baked (`assets/anim/humanoid.res`); walk and fall are layered on the skeleton, sword arm stays on IK | `--screen=animtest` capture sequence |
| 8 | B | Shield stayed upright in mid-air after death | Die with a shield | Shield kept its guard rotation | Shield rotates flat and is clamped to the ground during the fall | animtest capture |
| 9 | B | Repeating a cut was penalised even inside a combo that needs it | U-D-D | Same-direction rule ran before combo check | Penalty waived when the cut continues a known sequence of two or more | Test "a combo may repeat a cut" |

## Fixed in the continuous pass (found by an independent code review)

| # | Sev | Issue | Reproduce | Root cause | Fix | Verified by |
|---|---|---|---|---|---|---|
| 22 | A | Combos could be cashed in repeatedly from overlapping cuts (greatsword D,D,D,D = Colossus every cut) | Spam a 2-cut combo in one opening | Cut history never cleared on completion | History cleared unless a longer combo is still reachable; same combo twice running keeps only 35% of its bonus | Test "a finished combo cannot be cashed in again" |
| 23 | A | Timed block was free every time by tapping the shield | Flutter the shield through an attack | Timer reset on every press | Only a raise after 0.4 s at rest can be timed | Test "fluttering the shield…" |
| 24 | B | A posture break caused by a timed block was lost | Timed-block with posture nearly full | Recovery code overwrote the stagger | Early return when staggered | Code read |
| 25 | B | A timed block at zero stamina was a guard break | Timed-block when exhausted | `cost 0 <= 0` | Break only when not timed | Code read |
| 26 | A | Rolls gave near-permanent invulnerability and chained without a gap | Roll repeatedly, assist on | I-frames scaled past the lock; dodge buffered out of a roll; 1-point stamina gate | I-frames end before the roll does, no buffering out of a roll, real cost gate | Test "nothing chains or buffers out of a roll" |
| 27 | B | Blade stayed frozen at the clash point into the next action | Parry then cut at once | Pin never cleared | Pins cleared on swing, telegraph, stagger, hurt, death | Code read |
| 28 | B | Authored leg motion was computed then thrown away | Any body clip | Leg IK ran after the clip layer | Leg IK first, clip over it | Code read; needs a fresh capture |
| 29 | B | After the first sidestep, deaths and hit reactions had no hip travel | Dodge, then die | Travel flag never restored | Reset every frame | Code read |
| 30 | C | Training turned every later cut into a critical after one posture break | Break posture in training | Stagger converted without clearing the flag | Flag cleared, recover event sent | Code read |
| 31 | C | Heavy combos were free at zero stamina | Falling Crown when exhausted | Cost clamped, not required | Combo needs its stamina or lands as a plain cut | Code read |
| 32 | C | Burst of footstep sounds during rolls and shoves | Roll | Footfalls driven by distance alone | None during dodges or fast displacement | Code read |

Review items not yet acted on: one-frame pose pop on some clip changes; roll animation can end 0.15 s before the rules free the player; sidestep line maths leaves a small slide back; skeleton layer does about 44 bone reads/writes per rig per frame (unmeasured on mobile); toe-out differences between skeletons become a small constant yaw.

## Fixed in the animation QA pass (clipping, floor, weapons)

Found with `src/dev/pose_review.tscn`: one rig in a plain lit room on a floor slab, every state played, the real skinned
vertices measured every frame (lowest point, blade against the wielder's own body, shield against body and blade, joints),
and each state rendered FRONT / SIDE / BACK. Numbers are in metres on a 1.95 m figure (dragons: rig units, shoulder = 1.6).
Pairs are in `marketing/qa_pass/before/` and `marketing/qa_pass/after/` under the same file name.

| # | Sev | Issue | Reproduce | Root cause | Fix | Verified by |
|---|---|---|---|---|---|---|
| 33 | A | Feet 4–12 cm inside the floor in guard, footwork and walk, on every knight, suit and boss | `pose_review --poses=guard,walk` (before: lowest vertex −0.04 … −0.12) | Ankle target was a fixed 8 cm whatever the model's foot and sole were | `SkinDriver._measure` keeps the outermost mesh points of each bone; `_plant` lays a near-floor foot flat, lifts the ankle until the sole is on the floor and solves the leg again | `knight_m__guard.png`, `knight_m__walk.png`; lowest ≥ −0.01 on all 21 knight models audited |
| 34 | A | In every cut, finisher, parry and sidestep one foot was up to 18 cm under the floor or hung 30 cm in the air | `--poses=cut_R,cut_U,fin_Counter,dodge_l` | A body clip mixed in by turning each bone 65% of the way does not put the feet 65% of the way | Each ankle is put at the height between the two poses' own ankle heights and the leg solved again (`SkinDriver.drive`) | `knight_m__cut_R.png`, `knight_m__cut_U.png`, `ashen_sentinel__tel_R.png` |
| 35 | A | The dead lay 20 cm inside the floor; the sword point 32 cm and the shield rim 12 cm under it | `--poses=die_a` | The death clip's hip height does not suit every skeleton; weapon and shield kept their guard aim | `SkinDriver._ground` lifts (and settles) the whole body on its lowest measured point; `FighterRig._off_floor` tilts a blade so neither point nor pommel is under; the shield rim is lifted | `knight_m__die_a.png`, `ashen_sentinel__die_a.png` |
| 36 | B | Rolls were tumbled 19–24 cm above the floor | `--poses=roll_r` | Same hip-height mismatch | Whole-body clips are settled onto the floor as well as lifted out of it | `knight_m__roll_r.png` |
| 37 | A | During a cut the body turned side-on (up to 120° at the hips), the head looked away from the opponent, the sword arm reached behind the back and the shield arm folded to 17° with the shield in the face | `--poses=cut_U --t=0.07,0.17` | The clip's trunk turn was applied to bones already carried round by their parents (turned twice over), while both arms stayed on IK to targets fixed in rig space | Trunk blended from the procedural pose with at most 0.6 rad of clip yaw; head re-aimed at the opponent within 1.05 rad of the chest; hand targets ride with the shoulders; arms never fold tighter than 40° nor lock straight | `knight_m__cut_U.png`, `knight_m__cut_R.png` |
| 38 | B | Sword arm passed through the wielder's own shield in cross-body wind-ups; the blade passed through the shield arm on leftward follow-throughs | `--poses=cut_R,cut_DL` (before: 258 arm vertices inside the board) | Shield arm held its guard position through every cut | The shield swings open to the side (low, or high and forward for a cut ending low-left); board pushed off arm, thigh, head and trunk; `_clear_shield` keeps the blade on the hand's side of the board | `knight_m__cut_R.png`; audit `shield`/`bshield` = 0 for the eight cuts |
| 39 | A | Blade through the wielder's own neck, head, thigh or trunk: hit reaction (43 neck/head vertices), roll (108 head), death, stagger, overhead wind-ups (hand inside the helm), second blade of a dual wielder through the head | `--poses=hurt,roll_l,stagger`, `--gear=w_twin_fangs --poses=cut_D` | Blade direction was never tested against the body; in whole-body clips the weapon kept its old aim while the clip threw the arm | `_clear_blade` turns the blade about the hand out of head, trunk, thigh, shin and other-arm capsules taken from the real skeleton (wider for axe heads); `_out_of_helm` keeps arc hands outside the helm; in whole-body clips the weapon follows the hand's own grip axis | `knight_m__hurt.png`, `knight_m_w_twin_fangs__cut_D.png` |
| 40 | A | Two-handed weapons: the off hand was 18–24 cm off the handle in every state (player greatsword, Sentinel, Gravewarden, Frostbound King, glaives) | `--gear=w_ashen_great --poses=guard` (before: `offhand=0.21`) | Off-hand target assumed a 20 cm handle below the grip and was never solved to the real hand | `SkinDriver.reach_hand` brings the palm onto the handle after the pose is solved; the grip offset comes from the weapon model's real pommel length | `knight_m_w_ashen_great__guard.png`; `offhand=0.00` |
| 41 | B | The hand did not hold the handle: the blade left an open hand at any angle, the grip point sat at the knuckles | any weapon, close view | The hand bone simply followed the forearm | `SkinDriver.grip`: handle across the palm leaving on the thumb side, knuckles as near in line with the forearm as that allows; grip point moved into the palm | `knight_m_witness__guard.png` (hand close-up), greatsword and dual sheets |
| 42 | A | Long blades plunged into the floor: greatsword recovery and upward cut (point 0.5 m under), Sentinel while open | `--gear=w_ashen_great --poses=recover,cut_U`, `--foe=ashen_sentinel --poses=recover` | Poses written for a 1 m sword; the low end of vertical arcs pointed back at the wielder's shins | `_off_floor`; `_arc_low` stops the low end of a rising or falling cut 64° from straight ahead | `knight_m_w_ashen_great__recover.png`, `ashen_sentinel__recover.png` |
| 43 | A | In rolls, hit reactions and deaths the shield stayed where the guard had it or ended inside the head (566 head vertices in the board) | `--poses=roll_l,die_a` | Shield placed at the hand with a fixed rig-space facing | Strapped to the forearm for whole-body clips (outside of the arm, facing away from the chest), board pushed off the body, rim kept above the floor | `knight_m__roll_r.png`, `knight_m__die_a.png` |
| 44 | A | Weapons through the opponent: at the duel's own striking distance the middle of the blade passed through the foe's centre and swept out the far side; bodies overlapped | `pose_review --versus=hollow_soldier --dirs=R,D` | `reach()` left out the 0.4 m the step and lean carry the hand forward; nothing stopped a blade at a body | `reach()` corrected (fighters stand 0.4 m further apart at the blow); cuts and thrusts are walked in sub-steps and stop in the first body they reach, hold 0.13 s and draw back (`auto_bite`, public `bite()`); a raised shield or a parrying blade is met first | `versus_hollow_soldier__knight_cuts_R.png`, `…knight_cuts_D.png`, `…foe_cuts_R.png` |
| 45 | B | The Witness relic faced into the knight's body, sat sunk in the hip armour, and its two glowing eyes floated 10 cm off the mask at the thigh | `--witness --poses=guard --zoom=3.2` | The model's front is +X, not +Z; position was a fixed offset from the procedural pelvis | Yaw and eye positions measured on the model (`RELIC_YAW`, `RELIC_EYES`); hung from the real hip bone just outside whatever armour the suit has there; light moved in front of the face | `knight_m_witness__guard.png` |
| 46 | A | All three dragons stood about 10% of their leg height inside the floor | `--foe=cinder_wyrm --poses=guard` (before `low=-0.11`) | The fit took the lowest bone as the ground, not the soles of the mesh | `DragonSkin._measure`: ground from the leg vertices; no whole-body bob while standing | `cinder_wyrm__guard.png`; `low=0.00` on all three |
| 47 | A | A dying dragon sank straight down through the floor on rigid legs (0.7 units) | `--poses=die` | Death was a lowering of the whole node | The body comes down onto its measured belly; each leg is rolled out from under it until no joint is under the floor (`_splay`) | `cinder_wyrm__die.png`, `rimewyrm__die.png` |
| 48 | A | A dragon's claw swipe drove a spur and toes 0.6–0.95 units under the floor; toes dug 0.3–0.5 under in the gait | `--poses=claw_R,walk` | The leg was swung from its root with the paw rigid | The paw joint is turned back level as the leg swings or rises; the animal rides up by any remaining depth | `cinder_wyrm__claw_R.png`; worst now −0.09 |
| 49 | B | Dragon skeletons were misread: horns and jaw flapped with the wings (Veyrath, Azhurion); on Skeldra the "neck" included the trunk (aiming the head swung the body), the "jaw" was the bone carrying a foreleg, and one hind leg was not recognised | `tools`-style dump of `DragonSkin._analyse` | Chains were classed by position only | Neck stops at bones that carry legs; wings must hang from the trunk and be chains of three or more; jaw may not carry a leg; unnamed leg-like chains are found | Dump before/after; `rimewyrm__roar.png` |
| 50 | B | Rimewyrm's wings turned down through its hind legs when it spread them | `--foe=rimewyrm --poses=roar` | Spread assumed wings held up in a V at rest | Spread is measured from each model's own rest elevation; no wing bone is turned into the floor | `rimewyrm__roar.png` |
| 51 | B | Beast claws and hands 5 cm in the floor in low wind-ups; long skirts 6 cm under in lunges | `--foe=cathedral_beast --poses=tel_U`, `--foe=forgotten_monarch --poses=thrust` | No floor test for hands or cloth | Hand targets kept a hand's radius above the floor; hips lifted by up to 3 cm for what hangs from them | audit: −0.03 and −0.02 |

## Open

| # | Sev | Issue | Reproduce | Suspected cause | Plan |
|---|---|---|---|---|---|
| 10 | A | Sword strikes are still procedural arcs; weight transfer is approximate | Any swing | Only walk/fall clips are layered; the bought "slash" clip is a generic one-hand gesture, not eight directional cuts | Needs directional attack clips (licensed or authored). Not solvable with the clips owned; see "Animation sources" below |
| 11 | A | Parry does not guarantee the two blades touch | Parry any blow | Spark is placed at a midpoint, blades are not solved to meet | Solve the player's blade to the foe's blade segment at the impact frame |
| 14 | B | Devourer and dragons are not on the stance system | Fight a dragon | `DragonRig` has its own placement | Give dragons their own approach/retreat |
| 15 | B | 550k–750k triangles per frame in duels | Any duel, render stats | Generated models are unreduced; no LOD | Decimate and add LODs before any device claim |
| 16 | B | Cinematic road always shows the male knight | Play as the female knight with the filmed road on | Footage was filmed once | Hybrid: filmed background with the live knight composited |
| 17 | B | Two filmed road stops are crowded in frame | Courtyard stops 3 and 5 | Camera spots | Re-film |
| 18 | C | Parry cue ring is still a drawn arrow | Any incoming blow with prompts on | Legacy prompt | Replace with blade glint; prompt already optional in Settings |
| 19 | A | All 97 voice lines are provisional and unauditioned | — | Voices were picked by name | Casting profiles and a multi-candidate reel for the owner to choose from |
| 20 | A | Music and effects have never been heard by a person | — | No audio output in the build container | Owner review; six-bus mix still to do (currently Music/Sfx/Voice) |
| 21 | A | No iPhone build or measurement exists | — | Needs a Mac with Xcode and a device | Blocked on hardware |
| 52 | C | In a roll the blade or shield still grazes the wielder's own forearm or shoulder for two or three frames (≤ 33 sampled vertices) | `pose_review --poses=roll_r,roll_l` | Roll clips were authored without a sword or shield | Roll clips that carry both, or a sheathing gesture |
| 53 | C | Tall helm crests (base knight) are grazed by the blade returning from an upward cut; a dual wielder's off blade grazes the other forearm when a cut is halted | `--poses=cut_U`, `--foe=crimson_widow --poses=halt` | Body capsules do not include crests; two blades are solved one after the other | Per-model crest capsule; solve the pair together |
| 54 | C | Skirt and robe hems dip 2–3 cm into the floor in the deepest lunges (Monarch, Widow) | `--foe=forgotten_monarch --poses=thrust` | Cloth is rigid to the hips; the lift is capped at 3 cm so the feet do not float | Cloth bones, or shorter hems |
| 55 | C | Dragon toes dip up to 0.06–0.16 units for a few frames in the gait, a claw swipe and the fall | `--foe=rimewyrm --poses=walk,claw_L,die` | Toe flesh hangs below the joints that are tested | Leg IK for dragons |
| 56 | B | The generated dragon models do not lunge: a bite is read from the neck's aim only, so "head through the player" could not be reproduced and `DragonRig._keep_out` is unverified on screen | `pose_review --versus=cinder_wyrm --dirs=D` | The skin layer drives aim, jaw, legs, wings; not the head's position | Neck IK to the procedural head target |
| 57 | C | Fingers are not animated: an open hand lies on the handle | any close view | No finger poses | A curl pose for the grip hands |
| 58 | B | Foot sliding in walk and footwork was not reviewed in motion in this pass (the review is still frames) | — | — | Slow-motion recordings |

## Animation sources (investigated)

- Owned: nine clips retargeted to the knight skeleton by Tripo (idle, walk, run, turn, slash, hurt, fall, dive, jump). $0.90.
  Usable now: walk, run, idle, fall, dive. "hurt" is a seated wounded loop, suited to the defeat screen. "slash" is not a sword cut.
- Tripo's preset list has no directional sword set, parries, shield blocks or sidesteps.
- A full sword-and-shield set (eight cuts, parries, blocks, steps, hit reactions) exists in commercial motion libraries whose licences permit shipping in a game. Buying one is a spending and licensing decision for the owner; it would import through the same bake step, because the skeleton already uses the standard humanoid bone names.

### Armory suit inspection (2026-11-26, `marketing/armor_pass/knights.jpg`)
All 16 suit models load on both bodies, read as distinct, and hold the sword in the hand. Open defects seen in the captures:
- The shield covers the whole torso in the Armory pose, hiding the suit being chosen. Lower or hide the shield (or turn the knight) when the armour-suit slot is selected.
- The shield hand's fingers show through the front face of the shield.
- The knight is small in the Armory frame and the lower legs fall behind the dialogue line; needs the dedicated inspection framing.
- Suits not yet checked in motion (authored clips, relic placement) or in a duel.

