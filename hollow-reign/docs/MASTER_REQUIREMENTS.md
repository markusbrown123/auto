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
