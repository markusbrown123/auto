# Master requirements

Consolidated from every owner brief. Status lives in `DEVELOPMENT_BACKLOG.md`; this file is the scope.

## Identity
Spiritual successor to classic swipe sword-duelling games: directional swipe combat, Soulslike bosses, sleek sci-fantasy knights (approved male and female designs), eight regions, nine bosses plus the Devourer and three dragons (Veyrath, Skeldra, Azhurion), the Everbound / Eternal Crown story with three endings, New Game Plus. Entirely original.

## Combat
- Eight-direction swipes, each producing the matching physical cut; short input buffer; no stuck states.
- Both fighters constantly move: approach, retreat, circle, lunge, stagger back, pushback.
- 12–20 discoverable combos, visually distinct and strategic; journal; training ground; discovery by experiment, mastery, manuals, Orren, memories, legendary weapons.
- Blocks: normal, heavy, timed, perfect; shield recoil, pushback, guard break, shield-specific traits. Weapon visibly strikes the shield.
- Parries: directional; blades visibly meet; perfect-parry signature.
- Dodges: sidesteps and left/right rolls that move the body; enemy visibly misses; camera follows.
- Attacks visibly connect. Defensive cancelling in recovery windows.
- Every boss mechanically and stylistically unique; combat director never reads current input; seeded RNG.
- Weapon classes (sword, greatsword, axe, dual, …) differ in speed and power.

## Animation
Authored/licensed skeletal animation, not stiff procedural motion: stances, eight cuts, combos, parries, high/low blocks, rolls, sidesteps, lunges, advancing/retreating/heavy attacks, greatsword and dual sets, reactions, staggers, walk/run, finishers, deaths. No clipping, floating weapons, sliding feet, bent joints, wrong grips. Male and female, every weapon class, every boss. Review from several angles and in slow motion.

## Presentation
- Real-time combat stays. Branching filmed exploration continues; hybrid (filmed backgrounds, live customised knight) investigated.
- Cinematic walking, boss intros, memories, conversations, finishers. Video must not hide broken animation. Every sequence inspected for continuity and correct equipment.
- Camera redesign. Premium interface that almost disappears in combat: pads at ~20% idle, lit on press, adjustable to hidden; subtle temporary sword trails; no permanent arrows.
- Interactive onboarding and training.

## Audio
- Recast all voices from written casting profiles; expressive settings; audition reel for the owner. Existing 97 lines are provisional.
- Weapon, shield, footstep, armour, effort, ambience sounds synchronised to visible events.
- Adaptive original soundtrack. Six buses: Music, Dialogue, Combat, Ambience, Interface, Cinematics.

## Campaign
All environments from generated kits (none left primitive), all bosses, dragons, modular armour, weapons and shields, progression, optional quests, lore collectibles, memories, three endings, New Game Plus.

## Quality and delivery
- Functional and visual regression tests; male and female; every weapon class and boss.
- Bug register with repro, severity, cause, fix, verification.
- Triangle reduction and LODs (currently 550k–750k per frame).
- iOS export preparation. No device claims without a device.
- 20 demonstration recordings (list in `QUALITY_CHECKLIST.md`).
- Documents: this file, DEVELOPMENT_BACKLOG, DEVELOPMENT_STATUS, BUG_REGISTER, ASSET_MANIFEST, SPENDING_LOG, QUALITY_CHECKLIST, CLAUDE.md; lore docs CAMPAIGN_SCRIPT, CINEMATIC_SCRIPT, VOICE_BIBLE, SOUNDTRACK_PLAN, SOUND_DESIGN_BIBLE, AUDIO_ASSET_MANIFEST.

## Limits
$100 combined cap. No device, no Mac, no human ears in the build environment.

---
# Addendum: definitive final production brief (2026-11-26, second and third documents)
Everything above still applies. New or changed requirements:

## Narrative
- Setting stated plainly: a far technological future that reads as medieval fantasy; people take forgotten technology for magic; the player learns the truth gradually.
- **The Witness** — new major companion: an ancient human consciousness in a damaged ceremonial mechanical mask (blackened metal, faded gold, amber eyes, inscriptions, inner light), imprisoned for refusing to erase records of atrocities; found early, rides on the player's belt or armour; cynical, dry, wise, with deliberately erased and returning memories. Speaks before important areas, during travel, at landmarks, before selected bosses, after victories, in optional sanctuary conversations; rarely in combat; never repeats after each death; has an archive of stories heard. Original design, not a severed head.
- Lyra keeps her own role (origins, consciousness, the ethics of immortality, the emotional centre). The two sometimes disagree and remember differently.
- **Enemy speech:** A) creatures, dragons, the Cathedral Beast, lesser monsters: no human speech, only creature sound and movement. B) Sentinel, Executioner, Gravewarden, automated guardians: silent or a few short lines. C) Monarch, Widow, Frostbound King, Huntsman, Lyra, Orren, Witness, Archivist: directed dialogue. The Devourer: layered whispers and fragments, not speeches.
- Cinematic monster introductions built from place, warning signs, companion context, sound and shadow before the reveal.
- All three endings fully directed (not text), the Witness present in each without taking the choice from the player; credits and the post-credit scene.
- Quests become scripted (conversations, investigation, return visits), not profile conditions.
- Resolve the undesigned ninth guardian.

## Voice and audio
- Mature, weathered, grounded old-world performances; cast by personality, not depth alone; no pitch-shifting every voice, no heavy helm effects, no identical voices across roles; verify the cast on a reel before recording in bulk. Casting notes per role are in the brief (Witness: older man, conversational, dry, light British or Scottish cadence).
- Creature sound libraries per major monster; layered combat effects by material; interface sound language; full soundtrack with motifs for the Witness, Lyra and the Crown.

## Combat and animation
- Left/right dodge and left/right roll as controls; sixteen combos each with their own movement, timing, cost and recovery; block reactions through the whole body; dragons with jaw, walk, wing fold and flap, bite, roar, breath, reactions and death.
- Precise grip and attachment per weapon; two-handed grips keep both hands on.

## Graphics, shaders, effects
- Materials audit (no liquid-plastic metal, no shiny stone), texture review, a mobile shader library, deliberate lighting per region (nothing pure black, no blown silver), restrained post-processing.
- Sword trails redesigned as thin blade-following ribbons; sparks at true contact points; dust on steps and rolls; elemental, dragon, environmental and cinematic effects with budgets.
- Three working graphics presets; particle and geometry budgets; device targets unclaimed until measured.

## Complete game experience (third document)
- One reusable UI theme: blackened steel, antique gold, silver, charcoal, muted crimson, serif headings.
- Launch sequence; animated main menu with the player's knight (Continue, New Journey, Character, Equipment, World Map, Chronicle, Training, Settings, Credits); multiple save slots with summaries and delete confirmation.
- Cinematic male/female selection with rotation; opening cinematic; awakening; Witness discovery cinematic.
- Loading screens with original art, gentle motion, spoiler-safe lore and tips, honest progress.
- Equipment screen around a live rotatable knight; slots for helm, chest, shoulders, gauntlets, legs, boots, weapons, shield, rings, relics; comparison with clear up/down indicators; **real modular armour geometry** in named sets (Crownless, Ashbound, Frostwarden, Widow's Regalia, Gravekeeper, Sovereign, Dragonforged, Architect).
- Weapon collection with a rotating 3D weapon, rarity (Common, Uncommon, Rare, Legendary, Relic), mastery that unlocks things, legendary reveal cinematics.
- Orren's forge as a place: upgrades with a short sequence, shop, sell, sort, favourites.
- World map of Vaelora that reveals as the player progresses; chapter presentation; in-scene route selection.
- Settings: graphics, audio (master, music, dialogue, combat, ambience), controls, accessibility (subtitle size and background, reduced shake/flash/motion, forgiving timing, clearer telegraphs), save management, legal. All must work and persist.
- Victory and defeat screens in the game's own voice.
- End-to-end test of the whole flow; a 20-item demonstration package; iOS export preparation.

## Budget
- The owner says a further $100 has been added "to the graphics API account" for graphics and cinematics, on top of the $100 cap. **Not yet visible:** balances read at the time of the brief were Tripo 9,415 credits and Higgsfield 880 credits, both unchanged. Until a top-up is seen, spending stays inside the original cap (about $30 left).
- Order of spending: animation, voices, combat sound, essential cinematics, missing gameplay assets. Not scenery.

## Extra documents to maintain
GRAPHICS_BIBLE.md, SHADER_LIBRARY.md, VFX_BIBLE.md, ANIMATION_LIBRARY.md, PERFORMANCE_REPORT.md, AUDIO_ASSET_MANIFEST.json.
