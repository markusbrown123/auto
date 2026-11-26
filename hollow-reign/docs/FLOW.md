# Hollow Reign: the flow of a journey

How one screen becomes the next, what is on screen in between, and where a wait is still shown. The router is
`src/main.gd`; the story scenes are in `src/cine/`. Written 2026-11-26 after the flow pass (Addendum 2 of
`MASTER_REQUIREMENTS.md`: one continuous adventure, fades only when the place changes, matched poses and cameras).

Nothing here has run on a phone. Times are the scene's own clock at 30 fps on the development machine.

## A new journey

| # | Step | File | Length | How it ends, and what joins it to the next |
|---|---|---|---|---|
| 1 | Main menu | `ui/title_screen.gd` | — | New Journey opens character select over the same backdrop (no change of screen). |
| 2 | Character select | `ui/character_select.gd` | — | Confirm: 0.35 s fade to black. |
| 3 | Opening | `cine/opening.gd` | about 39 s | Opens from black, ends on black (0.3 s). First new journey only; see "Seen before". |
| 4 | Awakening | `cine/awakening.gd` | about 36 s plus the player's one tap | Black, then one light. Ends with the knight walking away from the camera into the white of the open door (0.45 s to white). |
| 5 | Approach | `cine/approach.gd` | about 6 s (longer if a line is still being spoken) | Comes out of the same white (0.5 s) behind the same walking knight, same camera offset. Ends standing at the first stop. |
| 6 | First stop of the road | `ui/explore.gd` | — | **No transition at all**: the road screen takes over the place the Approach built (`Explore.adopted`), the camera eases to its usual view, Lyra's remark plays, the choices fade in. |
| 7 | The foe is shown | `ui/explore.gd` `_reveal_then` | 1.7 s | The foe has been standing at its marker since the stop was reached. Choosing the fight starts the knight toward it; the camera goes low and looks up at it. 0.35 s fade to black. |
| 8 | First duel: the lesson | `combat/duel.gd` (`lesson`) | player-paced | Same arena, same two figures. Ends on "THE OLD LESSONS HOLD", 0.35 s fade. |
| 9 | First duel: the real fight | `combat/duel.gd` | player-paced | Finisher and victory overlay are the duel's own. |
| 10 | Rewards | `ui/overlays.gd` `victory` | — | Continue: 0.35 s fade to the next stop of the road. No menu in between. |

The filmed road (`settings.cine_road`, `cine/cine_road.gd`) replaces step 6 where footage exists. It is other
footage, so the Approach ends with a 0.35 s fade into it instead of handing the place over.

### Opening (`--screen=opening`, one shot held with `--shot=1..7`)
One hall (the `throne` arena), lit and full, then dark and empty. One shot to a line of the narrator; shots change
when the line on screen changes (the scene is played through `Story`, so subtitles, voice and ducking are the game's own).

| Shot | Line | Picture |
|---|---|---|
| 1 | "Once, men begged the gods…" | The hall at its height from the doors, slow push in. Warm light, fires, banners. |
| 2 | "Then men became gods." | From the floor, up at the seat at the end of the hall. |
| 3 | "They built bodies that could not grow old…" | A track along a line of armoured figures (guardian models, standing still), each a shape against firelight. |
| 4 | "But even eternity could not protect them…" | Back at the doors, handheld; a red light grows behind the camera. |
| 5 | "The crowns shattered…" | Dip through black (0.35 s out, 0.9 s in): the same hall, cold, fogged, fires dead, the figures down. Pulling back. |
| 6 | (same line, second half) | One of the fallen, close, from floor height. |
| 7 | "We were wrong." | Down the length of the dark floor: lamps set in the aisle come on one after another toward the seat, then the seat itself, in the wrong colour. Hold 2.6 s, cut to black. |

Any tap after 2 s ends it ("TAP TO SKIP", top right). Nothing is named and nothing is explained.

### Awakening (`--screen=awakening`, `--from=sword` starts at the prompt, `--auto` answers it)
The `chamber` arena (new: a round stone-and-metal room, the cradle, machine pylons, a block with the sword in it, one door).
The knight is `Duel.player_look()`: the chosen body and whatever is equipped.

| Beat | What happens | Camera |
|---|---|---|
| Black → one amber light | The knight sits on the floor against the foot of the cradle (`wounded` clip), unarmed. | Low and close, drifting back. |
| "Can you hear me?" / "Who are you?" | The grille on the wall brightens while Lyra speaks (all scene long). | Holds. |
| "Someone who has been waiting…" | The knight gets up: a 2.6 s cross-fade from `wounded` to `idle`. | Pulls back and up to a medium shot. |
| "What happened here?" | The knight turns to look for the voice. | Holds. |
| "That depends…" | — | Over the shoulder toward the grille. |
| "Things I couldn't possibly have seen." | — | Reverse: the helm, close. |
| "Then it worked." | Light comes up on the sword in its block. Music (`hub`) enters. | Wide: knight, cradle, sword, door. |
| Prompt | **The one interaction:** a breathing ring on the sword, "TAKE UP YOUR SWORD". | Wide, still. |
| Tap | The knight walks to the block (authored walk, arms swinging), the sword leaves the block and it and the shield are in hand. | Waits by the block, then eases in. |
| The door | The panel slides up, daylight floods in, `first_road` plays ("The doors above you open…"). The knight turns and walks out. | Behind the knight, riding with them, to white. |

### Approach (`--screen=approach`)
The region's own arena, built once. The knight walks 8 m to the stop's standing point with the camera at the offset the
Awakening ended on. On arrival the camera eases to the road screen's view; if `first_road` is still being spoken the
knight waits for it (at most 14 s), then the road screen adopts the place.

### The Witness (Courtyard, second stop)
`Companion` picks `witness_discovery` for the stop. On the real-time road the scene is staged: the knight turns to the
fallen statue head, the camera eases down to it, the mask (`witness_relic.glb`) lies against it and an amber light
kindles, the dialogue plays, the mask and light go, the knight is rebuilt wearing it (`flags.witness_found`, set by
`Companion.mark_heard`), the camera returns and the choices fade in. The filmed road plays the dialogue only, as before.
Other regions have no monument: a save that meets the Witness late gets the dialogue without the staging.

## Continue
Continue → the sanctuary of the latest save (0.35 s fade). It never plays the opening or the chamber. A road in
progress is not stored in a save (a run ends with the session), so there is nowhere further along to return to.

## Seen before
`Opening.SEEN_FILE` (`user://opening_seen`, beside the settings, not in a save slot) is written when the opening ends or
is skipped. Later new journeys go from character select straight to the chamber. The menu then shows a small
"Watch the Opening" at the bottom right; it plays the opening and returns to the menu. The chamber always plays for a
new knight: it is where that knight begins, and its lines can be tapped through.

## Where a wait or a cut is still shown
| Where | What the player sees | Why |
|---|---|---|
| Setting out for a region from the sanctuary, the map, or "retry" after a death | Loading screen | A change of region: a whole place is built. This is the case the loading screen is kept for. |
| Entering a duel when the foe's model is not yet in memory | Loading screen | Only if the player chooses within the moment it takes the road to read the foe ahead on a thread, or on the filmed road, which does not read ahead. Otherwise a 0.35 s fade. |
| Character select → opening, opening → chamber | Black, held for as long as the next set takes to build | Both scenes open on black by design, so the build is hidden in it; it is still a held frame. |
| Chamber → Approach | White, held while the Courtyard is built | A change of place, covered by the white of the doorway. |
| Road stop → duel, lesson → real duel, duel → next stop | 0.35 s fade to black, a held black frame while the arena and both fighters are built, 0.7 s in | The duel builds its own arena and rigs (`src/combat/duel.gd`, not part of this pass). The figures and the place are the same on both sides of the fade, but it is a fade, not a cut on action. |
| Opening shot 4 → 5 | Dip through black | Three hundred years pass. |
| Opening and chamber shot changes | Hard cuts | Ordinary cutting between shots of one scene. |

## Dev screens
`--screen=opening [--shot=N]`, `--screen=awakening [--from=sword] [--auto]`, `--screen=approach [--auto]`,
`--screen=newgame [--body=m|f] [--auto] [--seen] [--bot]` (the whole chain from character select; `--auto` confirms the
knight after 2.5 s, answers the sword prompt and takes the first way onward at each stop; `--seen` passes over the
opening; `--bot` lets a bot fight and skips the lesson).
