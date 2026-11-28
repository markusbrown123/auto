# Chapter I script: the owner's decisions (2026-11-28)

The owner reviewed `docs/SCRIPT_CH1_PROPOSAL.md` and decided every changed or new line. These decisions are now in
`tools/gen_dialogue.py` and `tools/gen_secrets.py`, and from there in `data/dialogue.json`. Every line id and cinematic
trigger is kept.

Every rewritten line that had a take of its old words is marked `recorded: false`. Until a take of the new words exists
it shows as a subtitle with no sound, so an old take never plays under new words. The check in `gen_dialogue.py`
removes the mark once a matching take exists in `assets/audio/vo/takes.json`.

## Decisions

| Line | Decision | Text in the game |
|---|---|---|
| opening_03 | keep old | They built bodies that could not grow old. Thrones that could not be inherited. Kingdoms that could not escape them. |
| opening_04 | new | Eternity did not save them from the people they ruled. |
| opening_05 | owner's wording | Their crowns fell. For three hundred years, we believed ourselves free. |
| awakening_06 | owner's wording | I remember dying here. But it wasn't me. |
| witness_call_01 | owner's wording | The door won't open. That device beside it... it isn't on any of my plans. |
| witness_discovery_05 | new (chamber and the courtyard fallback, which share the line) | And rather less than I ought. They cut a good deal out of me before they shut me away. |
| witness_discovery_07 | owner's wording (shared) | If I knew, I should be a happier ornament. Lift me out. I weigh very little, and I know this road. |
| witness_chamber_01 | owner's wording | They set me here to watch that cradle. You are what it kept. Let me see you safely out. |
| courtyard_1_01 | owner's wording, **only if the picture supports it** | Look beneath the armour. There's still light. Something was keeping it alive. |
| w_courtyard_chest_01 | add (new hook) | Garrison issue. Somebody counted every piece out. I have a terrible feeling it was me. |
| courtyard_2_01 | new | It salutes before it strikes. Somebody drilled it. The drill is all that is left. |
| courtyard_3_01 | owner's wording | The winch should hold. Strange how much of their work still does. |
| courtyard_4_01 | owner's wording | That one was built to break gates. When it swings, move aside. |
| sx_cy_charcoal_sketch_01 | new | Not of here. Somebody wanted that place found again. Keep it. |
| sentinel_retry_01 | add, owner's wording (the Witness) | Again, then. Take your time. Watch his blade. |
| sentinel_memory_01 | new | Record incomplete. Observer lost. Memory retained. |
| sentinel_memory_02 | new | Subject: gate sergeant. Forty-one years in service. Volunteered. Term promised: one winter. |
| sentinel_memory_03 | owner's wording | They were people. All of them. |
| orren_intro_01 | owner's wording | So you're the one she woke. Come here. Let's see what you've brought me. |
| orren_intro_02 | new | That sword's older than my whole line. Mind you don't drop it. |
| orren_idle_01 | owner's wording | A fine blade's no use if you don't know how to care for it. |
| sx_cy_cycle_count_01 | new; New Game Plus only (`when.ng_min = 1`, unchanged) | That mark was not there the first time. Or you could not see it. I cannot tell which is worse. |

Other lines are unchanged. `w_courtyard_approach` moves from stop 2 to stop 0, as proposed, so it is the Witness's first
sight of daylight. That is the same take, so nothing new is recorded for it.

## What was built for them

- **First chest.** `Companion.on_chest(region)` plays `companion.chest[region]` (Courtyard: `w_courtyard_chest`) after
  the first chest that holds something is opened (`Explore._resolve`, treasure). It is heard once per journey and never
  at every chest. Like every Witness line, it needs the Witness to have been found.
- **Retry.** `duel.gd` already plays `<voice key>_retry` over the intro card when a guardian is met again. The scene is
  once-only, so it plays on the first retry and never again. It does not mention death, so an ordinary fall stays out
  of the story.
- **Silence after the memory record.** `duel.gd` holds 2.6 s (`MEMORY_SILENCE`) after a guardian's memory record, before
  anyone speaks again.
- **Light under the plate.** Each fallen foe on the road keeps a slow, breathing glow at the chest in its own eye
  colour (`RouteLife._ember`). Only the latest body casts light, as one small lamp with no shadow. This is what Lyra's
  courtyard_1 line points at. **Not yet checked in a render**: if the glow does not read on screen, the line goes back
  to text the picture supports.

## Direction from the owner (applies to all later writing)

- Lines must sound natural spoken aloud: plain words, no forced medieval phrasing, no constant riddles.
- Each character is distinct.
  - The knight speaks naturally and seriously, without melodrama.
  - Lyra is intelligent, curious, and increasingly unsettled.
  - The Witness is mysterious, experienced, and occasionally dry.
  - Orren is a grounded craftsman who has lived and worked in this kingdom. Some dry humour, but no jokey merchant.
- The player always knows the immediate objective. The larger mystery comes out gradually.
- Characters react only to what is on screen. Nobody describes what the player cannot see.
- Show rather than tell: environment, animation, music, camera and reactions do the work, not narration.
  - awakening_06 should come with glimpses of the inherited memory on screen.
  - After the Sentinel's record, the silence carries the moment.
- Narration is cinematic, serious and measured, with room to breathe.

## Recording

The owner asked not to record the whole script yet. The order is:

1. Consolidate the decisions (done here).
2. Send a short audition of the narrator, the knight, the Witness, Lyra and Orren.
3. After the owner approves the delivery, confirm the exact take count and credit cost before recording the rest.

The archivist (Onyx) is provisional and not in the owner's cast. `tools/voices.py` leaves the archivist alone, so
sentinel_memory_01/02 stay text only until the archivist's voice is decided.
