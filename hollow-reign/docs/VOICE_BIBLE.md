# Voice bible — casting profiles

The existing 97 lines are provisional. Nobody has listened to them. Casting below is by written profile and by
*measured* voice properties (`docs/VOICE_CATALOG.json`: median pitch, pitch range, pace of every preset voice,
built by `tools/voice_catalog.py`). Measurement narrows the field; only a person listening can choose.
`tools/voice_reel.py` builds the audition reel: three candidates per role, same line, announced by number.

Pitch guide: low male under 105 Hz · male 105–135 · high male / low female 135–175 · female 175–215 · bright female over 215.
"Range" is p90 minus p10 of pitch on the test line: wide range = animated delivery, narrow = flat.

| Role | Who they are | Age, sound | Delivery | Pitch target | Range | Pace | Processing |
|---|---|---|---|---|---|---|---|
| Narrator | The voice of the record; outside the story | 50s woman, warm and dry | Unhurried, never portentous; reads history as loss, not legend | 165–200 | medium | slow | light hall |
| Lyra | The mind in the crown's machinery; the knight's only company | 30s woman, close, intelligent | Quiet, quick thoughts, guarded humour; warmth arrives late | 185–225 | wide | medium | faint machine echo |
| Knight (m) | The Unbound, male | 30s, tired, plain-spoken | Few words, no heroics; asks real questions | 100–125 | medium | medium | none |
| Knight (f) | The Unbound, female | 30s, level, watchful | Same lines, same restraint | 180–210 | medium | medium | none |
| Orren | Smith and trainer; has buried many like you | 60s man, rough | Dry, impatient, kind underneath; teaches by needling | 90–115 | wide | medium-fast | none |
| Archivist | A record that speaks | ageless, neutral | Flat catalogue cadence that breaks once | 130–170 | narrow | slow | band-limited, tremolo |
| Ashen Sentinel | Gate guard still on duty centuries after the gate fell | 40s man, formal | Clipped challenge and response; grief when the order ends | 85–105 | narrow | slow | closed helm |
| Hollow Executioner | Clerk of deaths | 50s man, bureaucratic | Bored precision | 95–120 | narrow | medium | closed helm |
| Pale Huntsman | Tracker of what the kings bred | 40s man, rural | Patient, low, amused | 95–120 | medium | slow | helm |
| Crimson Widow | Duelist who knew your teacher | 40s woman, exact | Courteous, cutting, a little fond | 165–200 | wide | medium | helm |
| Gravewarden | Keeper of the vaults | old man, vast | Slow, hollow, pitying | under 95 | narrow | very slow | helm, low boost |
| Frostbound King | Saw the ascension happen | 60s man, regal ruin | Weary authority, long vowels | 90–110 | medium | slow | helm |
| Forgotten Monarch | The last wearer of the crown | 50s man, magnetic | Reasonable, intimate, certain | 100–125 | wide | medium | helm |
| Devourer | What the crown made of a father | unplaceable | Soft, human, wrong | 150–200 | wide | slow | layered echo |

## Direction notes for generation
- Lower `stability` (0.30–0.40) for Lyra, Orren, Widow, Monarch, Devourer: they need movement in the line. Higher (0.60–0.75) for Sentinel, Executioner, Archivist, Gravewarden: flatness is the character.
- Punctuate for breath, not grammar: short sentences, em dashes for held pauses, ellipses only where a thought fails.
- Spell hard names phonetically in the generation text when a take mispronounces them (keep the display text unchanged): Veyrath "VAY-rath", Skeldra "SKEL-druh", Azhurion "ah-ZHOOR-ee-on", Orren "OR-en".
- Combat efforts (grunts, breaths) are separate short takes per knight, never cut from dialogue.

## Status
- Catalogue: in progress (see the JSON for how many of the 115 presets are measured).
- Reel: built after the catalogue; then **blocked on the owner listening** and choosing one candidate per role.
- Until then the game keeps the provisional lines, labelled provisional.
