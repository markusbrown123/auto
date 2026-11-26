# Voice bible — casting profiles

The existing 97 lines are provisional. Nobody has listened to them. Casting below is by written profile and by
*measured* voice properties (`docs/VOICE_CATALOG.json`: median pitch, pitch range, pace of every preset voice,
built by `tools/voice_catalog.py`). Measurement narrows the field; only a person listening can choose.
`tools/voice_reel.py` builds the audition reel: three candidates per role, same line, announced by number.

Pitch guide: low male under 105 Hz · male 105–135 · high male / low female 135–175 · female 175–215 · bright female over 215.
"Range" is p90 minus p10 of pitch on the test line: wide range = animated delivery, narrow = flat.

| Role | Who they are (from `CHARACTER_BIBLE.md`, which is the authority) | Sound | Delivery | Pitch target | Range | Pace | Processing |
|---|---|---|---|---|---|---|---|
| Narrator | Opening only; a woman's voice, possibly Lyra long ago | mature woman | Slow, grave, never portentous | 165–200 | medium | slow | light hall |
| Lyra | Researcher on the Unbound project whose mind is caught in part of the Crown | young adult woman, close | Warm, intelligent, dry; guarded until late | 185–225 | wide | medium | faint machine echo |
| Unbound (m) | A new person assembled from donated memories | adult man, plain | Grounded, economical, never quippy | 100–125 | medium | medium | none |
| Unbound (f) | The same person, female body | adult woman, level | Same lines, same restraint | 180–210 | medium | medium | none |
| Orren | Mortal smith from a line that kept scraps of the old engineering | older man, deep, rugged | Dry humour, teaches by needling | 90–115 | wide | medium-fast | none |
| Archivist | Damaged intelligence keeping the old records | androgynous, ancient | Calm, fragmentary, faintly mechanical | 130–170 | narrow | slow | band-limited, tremolo |
| Ashen Sentinel | Gate sergeant made into a guardian, told it was for one winter | immense man | Flat and helmeted; human at the end | 85–105 | narrow | slow | closed helm |
| Hollow Executioner | Still enforcing the law of a state that is gone | man, toneless | Certain, without malice | 95–120 | narrow | medium | closed helm |
| Pale Huntsman | Mortal hunter of the old engineered creatures; thinks the Unbound is tyranny returning | man, cold | Tired, patient | 95–120 | medium | slow | helm |
| Crimson Widow | Rebel commander kept alive by an experimental system; recognises people inside the Unbound | woman, sharp | Shaken, bitter; can yield | 165–200 | wide | medium | helm |
| Gravewarden | Keeper of the stored minds; knows exactly what he guards | old man | Patient, tender | under 95 | narrow | very slow | helm, low boost |
| Frostbound King | One of the last original Everbound; tried to give up immortality and sealed himself away | ancient man | Weary, dry | 90–110 | medium | slow | helm |
| Forgotten Monarch | Not an emperor: a steward appointed in the collapse to keep the machines running | mature man | Regal, controlled, never shouting | 100–125 | wide | medium | helm |
| Devourer | Centuries of discarded, corrupted memories in one body | many voices: men, women, children | Soft, human, wrong; layered from several takes | 150–200 lead | wide | slow | layered echo |

The audition reel's lines for the Widow, Monarch and Devourer were written before this table was reconciled with the character bible. They are still fair tests of the voices, but they are audition text, not script: do not treat them as canon.

## Owner's direction (2026-11-26): older, deeper, graver
The first reel was too light and modern. The target is the weight of dark-fantasy epics: deep, weathered, unhurried voices that sound as if they have been speaking in stone halls for centuries. This is a direction of tone only; no existing game's actors, lines or characters are imitated.

What that changes:
- **Casting:** the lowest and slowest voices in the measured catalogue for every role. Male roles from under about 105 Hz; female roles from the low end (about 140–175 Hz), never bright.
- **Writing:** plainer, older cadence. Short declaratives, inverted order where it is natural ("The gate has ever been shut"), no contractions for the guardians, no modern idiom, no quips. Lyra keeps warmth but loses the lightness.
- **Delivery:** higher stability than before (0.45–0.75) so lines are held and level rather than lively; pauses written in.
- **Processing:** each take set about a semitone lower, low shelf lifted, top softened, short stone-hall reflection. Guardians keep the closed-helm treatment on top.
- **Second reel:** `marketing/audition/casting_v2/` (`tools/voice_reel.py`). The script itself (`data/dialogue.json`) is to be rewritten in this cadence once a cast is chosen, then recorded.
- **Limit:** voices are chosen by measured pitch and pace, not by ear, and the catalogue gives no gender. A candidate may be the wrong sex for a role; that is for the listener to reject.

## Owner's direction, refined (later on 2026-11-26)
"Echo, not too much. Deep. Maybe Swedish, Irish, Australian accents, but realistic for an old European world. Not super-AI voices."
- **Accent:** regional and northern-European colour rather than neutral narrator English: Scottish, Irish, northern English, Scandinavian or other continental accents in English. An accent has to sound like a person from somewhere, not a put-on.
- **Depth:** from the voice itself. No pitch shifting.
- **Room:** a short stone-room reflection on every speaking character, kept low (two early echoes, quiet). Guardians' helm effect stays minimal.
- **Naturalness first:** if a take sounds synthetic it is rejected however deep it is.
- **Tooling:** the anonymous preset voices carry no accent information, so the fourth reel uses the Inworld speech model, whose voices are named individuals (several regional by name) and include Dutch, German and Russian voices that are tried reading English. Swedish and Australian voices are not offered by name on either model; the nearest available are used and labelled. `tools/voice_reel_inworld.py`, output `marketing/audition/casting_v4/`.
- **Still true:** nobody in the build environment can hear any of this. Accent labels on the reel are guesses from voice names.

## Direction notes for generation
- Lower `stability` (0.30–0.40) for Lyra, Orren, Widow, Monarch, Devourer: they need movement in the line. Higher (0.60–0.75) for Sentinel, Executioner, Archivist, Gravewarden: flatness is the character.
- Punctuate for breath, not grammar: short sentences, em dashes for held pauses, ellipses only where a thought fails.
- Spell hard names phonetically in the generation text when a take mispronounces them (keep the display text unchanged): Veyrath "VAY-rath", Skeldra "SKEL-druh", Azhurion "ah-ZHOOR-ee-on", Orren "OR-en".
- Combat efforts (grunts, breaths) are separate short takes per knight, never cut from dialogue.

## Status
- Catalogue: in progress (see the JSON for how many of the 115 presets are measured).
- Reel: built after the catalogue; then **blocked on the owner listening** and choosing one candidate per role.
- Until then the game keeps the provisional lines, labelled provisional.
