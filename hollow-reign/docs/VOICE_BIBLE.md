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

## Direction notes for generation
- Lower `stability` (0.30–0.40) for Lyra, Orren, Widow, Monarch, Devourer: they need movement in the line. Higher (0.60–0.75) for Sentinel, Executioner, Archivist, Gravewarden: flatness is the character.
- Punctuate for breath, not grammar: short sentences, em dashes for held pauses, ellipses only where a thought fails.
- Spell hard names phonetically in the generation text when a take mispronounces them (keep the display text unchanged): Veyrath "VAY-rath", Skeldra "SKEL-druh", Azhurion "ah-ZHOOR-ee-on", Orren "OR-en".
- Combat efforts (grunts, breaths) are separate short takes per knight, never cut from dialogue.

## Status
- Catalogue: in progress (see the JSON for how many of the 115 presets are measured).
- Reel: built after the catalogue; then **blocked on the owner listening** and choosing one candidate per role.
- Until then the game keeps the provisional lines, labelled provisional.
