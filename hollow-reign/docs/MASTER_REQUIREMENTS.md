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

---
# Addendum 2: frame-based cinematic and combat reference (2026-11-26)
The owner supplied five timestamped contact sheets from a reference playthrough of a classic swipe sword-duelling game (the video file itself did not reach the build environment; only the sheets did, and no audio). They are a reference for *feel* — camera, rhythm, continuity, teaching — not for content. Nothing from it is reused; all assets stay original.

What the sheets show, and what Hollow Reign must do in its own way:
- **Camera director.** Distinct shots chosen by events: wide establishing, low-angle reveal, close-up, over-the-shoulder and reverse for dialogue, walking track, standard combat framing, defensive reaction, blade-struggle close-up, stagger, phase transition, finishing strike, victory, defeat, discovery. Combat framing keeps attacks readable; cinematics move more. Consistent screen direction.
- **Continuity.** Menu → selection → opening → awakening → walk → enemy reveal → combat → finisher → rewards → onward, with matched poses and cameras; fades only for a change of place. No loading screen between short interactions.
- **Opening.** The fall of the immortal civilization without giving the mystery away; the knight wakes in the resurrection chamber; Lyra; find the weapon; walk to the first enemy; combat taught by the encounter; the Witness found early.
- **Teaching.** In the first encounter: swipes, shield, left/right dodge, rolls, parries, counters, two- and three-hit combinations, stamina. Temporary indicators, the enemy throws the matching attack, the instruction goes when done. Experienced players are not interrupted.
- **Rhythm.** A full defensive-and-offensive exchange inside a few seconds. Consecutive enemy attacks; not every defence opens the foe; repeated successful defences destabilise it; a parry break gives the long opening. No long lockouts.
- **Blade struggle.** Occasionally a parry locks blades: close camera, both push, a short interactive action (rapid taps), success destabilises, failure hands control back. Used sparingly.
- **Combos.** All sixteen keep their own choreography, timing, cost, recovery and purpose; the player chooses.
- **Mid-battle story beats** for intelligent bosses at a phase threshold, skippable after the first time, state preserved, possibly a choice.
- **Finishers** unique to major bosses; creatures do not make speeches.
- **Environmental storytelling:** machines, hidden chambers, inscriptions; a major revelation beneath the Cathedral of Ash.
- **Measured testing:** input acknowledgement delay, transition delay, contact accuracy, branch delay, frame pacing, memory; dynamic recordings of every action.
- **Priority:** one complete Sentinel encounter with all twelve elements (approach, companion dialogue, introduction, movement, contextual teaching, defensive exchanges, chosen combos, contact, blade struggle, finisher, rewards, onward), compared against the reference principles; then the rest of the campaign.

---
# Addendum 3: equipment, character redesign and RPG progression (owner, 2026-11-26)
Three briefs received together. All earlier requirements stay in force.

**Visual direction (changes the current look).** The existing suits are "too spiky, excessively shiny, exaggerated and generic". Target: sleek fitted science-fantasy plate, about 70% elegant medieval / 30% advanced military technology; brushed steel, dark graphite, black undersuit, restrained gold, subtle light; compact visored helmets with no horns; natural athletic proportions for both knights, flat boots, no exposed areas. Rarity must not mean more spikes: the best gear is often the cleanest. Study the general design language of the named references (ArtStation albums by the original character lead, the 2014 artist reference portal) but make original assets; never reproduce a signature item. The legendary "Eternal Edge" must have its own profile and must not recreate the famous sword of the reference game.
**Armour families:** Crownless, Ashbound, Frostwarden, Widow, Gravekeeper, Sovereign, Dragonforged, Architect (male and female each). Inspect and refine the 16 existing suits before paying for replacements.
**Swords:** 12–20 collectable blades with believable edges, thickness, grips, guards, pommels. Directions: Wayfarer, Silver Vow, Ashbrand, King's Remnant, Cold Resolve, Nightward, Oathbreaker (greatsword), Veilcutter, Twin Relics, Eternal Edge. Compare controlled hard-surface modelling against image-to-3D; prefer whichever is cleaner. **Shields:** heater, round, kite, curved technological, segmented; real rear grips; classes differ in weight, stamina and blocking.
**Benchmark first:** one polished male knight, one polished female knight, three exceptional swords, two exceptional shields; then apply the language to everything without asking for minor approvals.
**Recall:** original ancient technology that reconstructs an advanced weapon into the hand, hilt first then blade to tip, a narrow pulse, then solid metal; shader + particles on the real model, short, restrained, reduced-effects setting. Advanced shields unfold. Ordinary weapons are drawn and sheathed with authored animation; nothing teleports without Recall. Used in awakening, first lesson, boss introductions, discoveries, previews; short versions on repeats.
**Real equipment, not skins.** Slots: helmet, chest, shoulders, gauntlets, legs, boots, main weapon, secondary where supported, shield, ring, relic. Mix pieces across families. Investigate splitting the existing suits into parts on a shared body and skeleton; where a suit cannot be split cleanly it stays a complete set and the interface must say so honestly.
**Equipment interface.** Landscape: collection carousel on the left (finger tracking, momentum, snapping, neighbours partly visible, big rotating 3D item, optional grid), live animated full-body knight on the right wearing the preview. Camera moves to the slot being browsed; rotate and zoom. Preview never equips or saves; Equip commits. Actions: Preview, Compare, Equip, Upgrade, Inspect, Favourite, Preview Attack, preview block. Locked items can be viewed, not equipped. Comparison is always against what is equipped, green/red, lower-is-better handled. Only statistics that a real system uses. Quick swipes stay responsive; long animations only on deliberate inspection.
**Progression.** Rarity: Common, Uncommon, Rare, Legendary, Relic. Every victory gives something (experience, gold, mastery, materials, sometimes gear); guaranteed boss rewards; discovery states (undiscovered silhouette, discovered, owned, equipped) with spoiler-free hints; reveal presentation for new gear; per-weapon mastery; light/medium/heavy armour with real effects; optional set bonuses, mixing stays valid; cosmetic finishes and an appearance override kept separate from real gear; no paid cosmetics, adverts, energy or loot boxes. Economy guards: no exploits, no duplicate boss rewards, cannot sell equipped or quest items, no negative currency.
**Forge (Orren).** Upgrade swords, shields and individual armour pieces; craft, buy, sell; short skippable upgrade sequence using the actual item; longer for legendary.
**Sanctuary as a place**, reflecting achievements (weapon racks, trophies, machinery). Main menu shows the equipped knight. The player's real gear appears in every in-engine cinematic.
**Architecture.** Data-driven item definitions with stable ids, separate from ownership/progress data; safe save migration.
**Testing loop:** fight → reward → inspect → swipe → compare → equip → see it held → upgrade → fight → save → restart → everything persists; all armour combinations for clipping; both knights; rapid browsing; preview never alters the save.
**Review captures required:** old vs refined armour, turnarounds, starter vs legendary, sword and shield collections, material close-ups, previews, drawing, Recall, shield deployment, approach, combat with the new gear. Never present concept images as game assets.
**Budget:** Tripo allocation for essential 3D gear only; refine existing assets and model hard surfaces by hand first; Tripo funds cannot be moved to other services.

**Owner follow-up (2026-11-26, with a photo of four ornate display swords): "Futuristic style".** The first benchmark swords were too plain and historical. Swords need individual sculpted guards with cut-outs, waisted blades with engraved line-work, slender twisted or corded grips, distinctive pommels, small gold accents. The photographed swords are an existing game's signature weapons: take the general language only, never their shapes.

**Owner follow-ups (2026-11-26):** three or four basic swords in the futuristic style that differ in damage or speed (Wayfarer balanced, Silver Vow light, Ashbrand heavy, Veilcutter precision), one chosen at the start of a journey; shields differ by number of blocks and movement speed (light, balanced, heavy); weapons are modded at the forge by blade, handle, ore and sharpen, and the model shows the mods; new swords come from bosses.
**Owner follow-up (2026-11-26):** gold earned in fights buys weapons in an item shop whose stock unlocks with progress, with expensive weapons as saving goals; boss weapon drops are few, about three in the whole campaign.
**Owner follow-up (2026-11-26):** small secrets to explore in the spirit of open-world action RPG hidden content and the classic swipe-duelling trilogy's Easter eggs (research the kinds of idea; original content only), plus a 100% completion layer with light optional side missions.
**Owner correction (2026-11-26):** keep the game compact — a full playthrough of about 2–3 hours, like the game that inspired it. Few secrets (about 10–12) and few side missions (4–6); 100% should add little time. Do not pad length.
**Owner direction (2026-11-26, with five reference screenshots):** the game must open with a very cinematic scenic grass-and-cliff road to a distant landmark, a lineage story (a parent climbs first and falls, "you die twice", then the next of the family takes up the climb) with a twist of our own, a "cool intro", and a scenic, intentional-looking walk-up to the first battle. Victory screen: per-equipped-item mastery bars, level bar, gold pouch counting into the total. Store: flick list with one large item, price and Buy prominent, mastery, key stat changes, Compare. Structure only; our own story, names, look and landmark.

---
# Addendum 4: definitive generational campaign (owner, 2026-11-26)
Full text: `docs/GENERATIONAL_CAMPAIGN_BRIEF.md`. Three generations of one family (Father, Son, Last Heir; female equivalents) face the same never-aging Forgotten Monarch; the Inheritance Engine carries gear and knowledge forward; two canonical deaths at authored moments; the world and its encounters change each generation; final victory opens the facility beneath the throne; three endings; optional legacy journeys afterwards. Supersedes the single-knight campaign and the parent/sibling prologue idea. Stays compact (about 2–3 hours).

**Owner decisions (2026-11-27):** armour is a mix of the original medieval look and the future look; trial the sculpted sword guards; ordinary death is a normal part of the game and its story ("you probably have to die at least once"), so the Engine-restores-the-present-hero lines stay; the owner will choose voices by listening: four candidates per character, each file labelled with the character; then finalise bugs, storyline and video renders and make everything functional and ready to test on the owner's phone.
**Owner direction (2026-11-27):** "Environment more new and space, but land — like futuristic, not medieval at all." Built structures should read as advanced technology on a planet's surface (non-Earth sky, engineered megastructures, alloy and ceramic, light lines); natural land stays. Benchmark on the opening road first; the six region arenas (medieval kits today) follow once the owner has seen the benchmark. Characters stay a mix of medieval and future.
**Owner direction (2026-11-27):** the Witness must not be a head or mask at the hip ("exactly like God of War… feels Egyptian, not clean"). It becomes a small, clean, futuristic machine that floats and follows the knight, in the spirit of a floating companion from a space shooter but an original design, not a copy of it.
**Owner follow-up on the Witness (2026-11-27, with a photo of a replica of the famous floating companion):** wants that feel: crisp white faceted panels, dark seams, small accent caps, a glossy insert carrying the light, real presence. Must stay an original shape (not a star of pyramid plates around one round eye). The first redesign (a plain teardrop "plumb") was too plain and too small; second design pass in progress.
