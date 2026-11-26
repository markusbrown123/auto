# Quality checklist

An encounter is accepted only when every line is checked from captures, not from tests alone.
State: [ ] not yet · [~] partly · [x] verified (name the capture).

## Per encounter
- [x] Sword grip in the palm, blade up; shield on the forearm — front / side / back sheets from `src/dev/pose_review.tscn` in `marketing/qa_pass/after/` (`knight_m__guard.png`, `knight_m_w_ashen_great__guard.png`, `knight_m_w_twin_fangs__guard.png`, `ashen_sentinel__guard.png`); two-handed off hand measured on the handle (`offhand=0.00`). Fingers are not animated (register #57)
- [~] All eight cuts travel the swiped direction — `marketing/demos/05_eight_cuts.mp4`; arm is IK along the swipe, body from two generic cut clips
- [~] Hits land on the body; parried blades touch; blocked blows land on the shield; dodged blows pass through empty space — cuts now stop in the first body they reach: `versus_hollow_soldier__knight_cuts_R.png`, `…foe_cuts_R.png` against the same names in `qa_pass/before/`; real-duel frames `duel_hollow_soldier__hit.png`, `…boss_hit.png`, `…parried.png`; block and dodge contact frames not yet isolated
- [ ] Feet do not slide in walk, footwork, dodge — not yet reviewed in slow motion
- [x] Nothing under the floor in any state — lowest skinned vertex ≥ −0.02 m in every state on the knights; bosses ≥ −0.03 m (toe tips); cloth rigid to the hips still dips on three models (register #54); the dead lie on the floor (`knight_m__die_a.png`, `ashen_sentinel__die_a.png`); dragons stand, strike and die on it (`cinder_wyrm__die.png`, `rimewyrm__roar.png`; toes register #55)
- [x] The Witness relic hangs outside the hip armour, face out, eyes on the mask's eye slits — `knight_m_witness__guard.png`
- [~] No weapon through own body in any state — measured every frame on the skinned mesh for 21 knight models, 8 humanoid bosses and 7 enemy classes (pose_review audit): clean in guard, block, footwork, walk, the eight cuts, finishers, parry, recover, stagger, hit, death; brief grazes remain in rolls and against tall helm crests (register #52, #53)
- [ ] Transitions: no pops between states at 0.25× speed
- [x] Boss has its own attack patterns and movement style — Sentinel: 20 patterns, three phases (data + balance tests)
- [x] Male and female knight both checked — both bases and 15 suits through every state in the pose_review audit; sheets for `knight_m`
- [x] Each weapon class checked (sword, greatsword, axe, dual) — on the knight with `--gear=w_ashen_great|w_headsman|w_twin_fangs`, and on the bosses and classes that carry them; `knight_m_w_ashen_great__*.png`, `knight_m_w_twin_fangs__*.png`
- [ ] Camera keeps both fighters readable through dodges and pushback
- [ ] Sounds fire on the visible frame of contact
- [x] Triangle count and draw calls recorded — Courtyard duel 402k triangles, 136 draw calls (software renderer stats)

## Demonstration recordings (owner's list of 20)
1 male walk · 2 female walk · 3 sword handling · 4 shield handling · 5 eight attacks · 6 combos · 7 parries · 8 normal/heavy/timed blocks · 9 left/right dodges · 10 footwork · 11 boss attack variety · 12 hit reactions · 13 guard break · 14 full Sentinel fight · 15 victory · 16 defeat · 17 real-time vs branching video · 18 exploration walk · 19 training ground and journal · 20 controls fading.
Recorded so far (`marketing/demos/`): 1, 2, 5, 6, 7, 8 (held and timed), 9 (sidesteps and rolls). Queued: 14, 19. Not yet recorded: 3, 4, 10, 11, 12, 13, 15, 16, 17, 18, 20.
