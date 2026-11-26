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

## Open

| # | Sev | Issue | Reproduce | Suspected cause | Plan |
|---|---|---|---|---|---|
| 10 | A | Sword strikes are still procedural arcs; weight transfer is approximate | Any swing | Only walk/fall clips are layered; the bought "slash" clip is a generic one-hand gesture, not eight directional cuts | Needs directional attack clips (licensed or authored). Not solvable with the clips owned; see "Animation sources" below |
| 11 | A | Parry does not guarantee the two blades touch | Parry any blow | Spark is placed at a midpoint, blades are not solved to meet | Solve the player's blade to the foe's blade segment at the impact frame |
| 12 | B | Sentinel holds its greatsword upright through its own head while open | `--screen=training` | Recover pose blade target assumes a one-handed weapon length | Per-weapon recover pose |
| 13 | B | Authored clips verified on the male knight only | — | Other skeletons have different rest poses; the retarget is a rest-relative approximation | Run animtest for the female knight and all nine bosses; disable per model where it distorts |
| 14 | B | Devourer and dragons are not on the stance system | Fight a dragon | `DragonRig` has its own placement | Give dragons their own approach/retreat |
| 15 | B | 550k–750k triangles per frame in duels | Any duel, render stats | Generated models are unreduced; no LOD | Decimate and add LODs before any device claim |
| 16 | B | Cinematic road always shows the male knight | Play as the female knight with the filmed road on | Footage was filmed once | Hybrid: filmed background with the live knight composited |
| 17 | B | Two filmed road stops are crowded in frame | Courtyard stops 3 and 5 | Camera spots | Re-film |
| 18 | C | Parry cue ring is still a drawn arrow | Any incoming blow with prompts on | Legacy prompt | Replace with blade glint; prompt already optional in Settings |
| 19 | A | All 97 voice lines are provisional and unauditioned | — | Voices were picked by name | Casting profiles and a multi-candidate reel for the owner to choose from |
| 20 | A | Music and effects have never been heard by a person | — | No audio output in the build container | Owner review; six-bus mix still to do (currently Music/Sfx/Voice) |
| 21 | A | No iPhone build or measurement exists | — | Needs a Mac with Xcode and a device | Blocked on hardware |

## Animation sources (investigated)

- Owned: nine clips retargeted to the knight skeleton by Tripo (idle, walk, run, turn, slash, hurt, fall, dive, jump). $0.90.
  Usable now: walk, run, idle, fall, dive. "hurt" is a seated wounded loop, suited to the defeat screen. "slash" is not a sword cut.
- Tripo's preset list has no directional sword set, parries, shield blocks or sidesteps.
- A full sword-and-shield set (eight cuts, parries, blocks, steps, hit reactions) exists in commercial motion libraries whose licences permit shipping in a game. Buying one is a spending and licensing decision for the owner; it would import through the same bake step, because the skeleton already uses the standard humanoid bone names.
