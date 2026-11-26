# Cinematic presentation experiment (2026-11-26)

One complete test of "prerecorded footage, live rules": the Fallen Courtyard, the Ashen Sentinel, the male knight with the Courtyard Longsword and Garrison Kite. The real-time duel is untouched and remains the default.

## How to try it
- In the game: Settings → **Cinematic duel (test)** → On makes the Ashen Sentinel fight use footage. Off restores the real-time duel.
- Directly: `godot --path . -- --screen=cine`.
- Recordings of actual play, made by pushing touch events into the running game: `marketing/recordings/cinematic_courtyard_gameplay.mp4` (walk, chest, travel, challenge, duel with two deliberate failures, victory), `cinematic_duel_gameplay.mp4`, and `realtime_duel_gameplay.mp4` for comparison.

## What is footage and what is live
| Prerecorded | Live in Godot |
|---|---|
| The picture: 16 combat clips, 1 travel clip, 1 intro, 1 memory scene | Touch input and swipe direction, input windows, stamina, health, damage, boss phase, victory and defeat |
| | HUD, prompts, subtitles, voices, music, ambience, effects, haptics, pause |
| | Hotspots, chest reward, flags, saves, XP, loot, progression |

Nothing is baked into the video. No service is called during play; all footage ships in `assets/video/`.

## How the fight is built
Footage: `src/cine/clip_stage.gd` films scripted takes of the real scene with Godot's movie writer; `tools/render_clips.sh` cuts and encodes them. Rules: `src/cine/cine_fight.gd`. Playback: `src/cine/cine_player.gd`. Data: `data/cine_sentinel.json`.

Two shared poses, **READY** and **OPEN**, and every clip starts and ends on one of them:

```
READY (idle loop) ─► telegraph A or B ─► parry ─► OPEN ─► counter ─► READY
                                      ├► dodge ─► OPEN ─► (unused) recover ─► READY
                                      ├► block ─► READY          └► last blow: victory
                                      └► hit   ─► READY (or defeat)
```

- 16 combat clips cover it; the tree does not grow with fight length.
- Each attack's four outcomes were filmed as four full takes that share their opening frame for frame; the telegraph is cut once and the outcomes are cut at the same branch frame. Measured difference between takes at the branch point: 0.04 to 0.05 out of 255.
- All idle motion is snapped to harmonics of a 3-second loop and every clip boundary sits on a multiple of it. Measured difference at every join (clip end to next clip start): 0.17 to 0.25 out of 255, which is firelight noise.
- Each exchange in the data file has: id, telegraph clip, valid inputs, window open and close, perfect band, stamina costs, outcome clips, impact marker, exit pose. `tests/cine.gd` checks the data for consistency.

## Rules that were verified (`tests/cine.gd`, 83 checks; `tests/cine_playback.gd`, 11 checks)
- Correct, wrong, early, late and repeated inputs. One resolution per exchange; extra swipes change nothing.
- Too-early input costs a little stamina and can be retried; input after the branch point is ignored.
- Parry, dodge (correct and wrong side), held block, guard break, counter, perfect-timing bonus.
- Damage lands once, at the clip's impact marker, identically at 120, 30 and 4 updates per second.
- **Failed offence never costs health**: an unused opening closes harmlessly; swiping at a guarding foe or countering with no stamina costs stamina or nothing.
- Time only advances by footage actually presented. With the video held for 1.2 s mid-telegraph, the clock, health and state did not move, and the answer still counted afterwards.
- Victory and defeat fire once; restart is clean; a missing clip is reported and the game falls back to the real-time duel.
- Rewards go through the same code path as the real-time duel, so they cannot be paid twice.

## Measured playback (desktop Linux, software renderer; **not an iPhone**)
| Measure | Result |
|---|---|
| Black frames in a full duel | 0 of about 3,900 inspected |
| Playback stalls | 0 |
| Branches pre-armed (first frame decoded in advance) | 36 of 37 (the very first clip is not) |
| Touch to acknowledgement | median 0.4 ms, worst 28 ms (first use of a sound) |
| Accepted input to outcome clip | at most 0.75 s by design (the window is the last 0.75 s before the branch) |
| Branch to next *new* frame | median 114 ms, 90th percentile 131 ms, worst 161 ms |
| Footage | 19 clips, 78 s, 42.7 MB (Ogg Theora 720p30, quality 7) |
| Decoders alive at peak | 9 |

The 114 ms figure is the main weakness. A pre-armed clip shows its (matching) first frame at once, but Godot's stock Theora player takes about three video frames to resume a held stream. Because every branch sits in a held pose it reads as a brief hold, not a jump. Real numbers on an iPhone are unknown until tested on one.

## Playback path
- Godot 4.6's built-in player decodes **Ogg Theora only**. MP4/H.264 does not play. Everything is encoded to `.ogv`.
- Theora is an old codec: about 0.55 MB per second at 720p here, software-decoded on the phone's CPU. H.264/HEVC through iOS's hardware decoder would be several times smaller and cheaper to play, but needs a native plugin. Not started; only worth it if this direction is chosen and Theora proves too heavy on a device.
- Screens of 16:10 and wider are filled (slight crop top or bottom); squarer screens such as iPads are letterboxed so attack cues are never cut off.

## Higgsfield in this test
One clip generated (Seedance 2.5, 5 s, 720p, 35 credits, about $1.45): the Courtyard three centuries ago, used as the Sentinel's memory scene. Given a frame of our Courtyard as reference it kept the layout and landmarks closely. It did **not** keep our armour design: the soldiers are generic plate. Conclusion: use generation for places, establishing shots and distant-memory scenes; use engine renders wherever the knight, a boss or a weapon must look exactly right or must join onto gameplay.

## Customization
The prototype shows one character and one loadout. The shipped game has two knights, about 20 weapons, 6 shields and armour tints. Options:

| Option | What it means | Cost |
|---|---|---|
| Rendered variants | Re-film the 16 combat clips per loadout | About 35 MB and 20 minutes of rendering per variant per boss. 2 knights × 4 weapon classes alone is 8× the footage: roughly 280 MB per boss. Not viable across the game |
| Enemy-focused shots | Frame the boss, keep the player off-screen or as a blade edge | One set per boss, equipment-independent, but loses the over-the-shoulder look and the player's own character |
| Real-time characters over recorded scenery | Film only the environment (or use a still) and draw both fighters live | Keeps every piece of equipment and all animation freedom. This is close to what the real-time duel already is, with a cheaper background |
| Real-time combat everywhere | Keep the existing duel | No footage cost; full customization; needs the animation polish already planned |

## Comparison with the real-time duel
| | Cinematic duel | Real-time duel |
|---|---|---|
| Swipe direction | Chooses the right answer to an attack | Also aims every cut: 8 directions, seams, chains |
| Attacking | One fixed counter per opening | Free combos during the opening |
| Timing | A 0.75 s decision window, perfect band at the end | Frame-timed parry and dodge windows |
| Equipment shown | One fixed loadout | Whatever is equipped |
| Camera and lighting | Locked, identical every time | Dynamic |
| Boss variety | New footage per boss (about 40 MB each) | Data only |
| Picture quality | Whatever the renderer can produce offline, regardless of phone | Limited by the phone |

## Recommendation
- **Use prerendered footage for exploration travel, establishing views with hotspots, boss introductions, finishing moves and story scenes.** These worked well, are equipment-light, and let the game look better than a phone could render live. Higgsfield is useful here for places and memories.
- **Keep the real-time duel for combat.** The cinematic duel is correct and responsive in its decisions, but it turns directional sword-fighting into choosing an answer, shows only one loadout, and costs about 40 MB per boss. That gives up the two things this game is built on: aiming your own cuts, and seeing your own gear.
- A middle path worth trying next: real-time fighters over a prerendered or simplified background, with prerendered intro and finisher clips. That keeps the swipe combat and customization and still buys most of the visual gain.
- Before any of this ships: play it on an iPhone. Nothing here has been.

## Extension: the whole Fallen Courtyard as cinematic exploration (hybrid)
Following the recommendation above, the Courtyard's seven stops were filmed as a road: at each stop the knight **walks** in (a new procedural walk cycle, stride tied to ground covered), the clip ends on a still view, and hotspots appear where each choice was filmed. Fights use the real-time duel.

- Settings → **Cinematic exploration (test)**, or `-- --screen=cinewalk`. Recording: `marketing/recordings/cinematic_road_gameplay.mp4`.
- `src/cine/cine_road.gd` is data-driven (`data/cine_courtyard.json`, written by the filming step, holds each stop's clip, still and hotspot positions). The choices, rewards, flags and what happens next come from the same region data and `Game` code as the normal road. Tested: every stop shows exactly the region's choices; a cache pays once.
- Each walk plays in full once per save; on a retry or a return the player arrives at the still immediately. Any walk can be skipped with a tap.
- 7 clips, 42 s, about 30 MB at quality 6.
- Known rough edges: at two stops a wall or pillar crowds one side of the frame; props for choices already taken (an opened chest, a pulled lever) still appear in the picture; the knight shown is always the male knight with sword and shield, whatever is equipped. That last one is the customization problem again, and is the main argument for drawing the knight live over a filmed background if this style is kept.

## Not done
- Device testing (no hardware attached).
- Audio audition: reels are in `marketing/audition/`; nobody has listened yet.
- Props for choices already taken still appear in the filmed views.
