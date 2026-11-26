# Character bible

| Character | Who they are | Wants | Voice direction | Cast voice (provisional) |
|---|---|---|---|---|
| The Unbound (m/f) | A new person assembled from donated memories | To know whether their identity is their own | Grounded, economical, never quippy | Callum / Imogen |
| Lyra, the Voice Beyond | A researcher on the Unbound project whose mind is caught in part of the Crown | To free the minds in the network, which may end her | Young adult, warm, intelligent, dry; slightly ethereal through old machinery | Vesper |
| The Witness | The recorder of the Everbound courts, a human mind shut in its own ceremonial mask for refusing to erase the record of atrocities; memory deliberately cut, returning in pieces | That the record be true, itself included | Older man, conversational, dry, light British or Scottish cadence; unhurried, exact, amused at the wrong moments; never mock-archaic, never shouting | not cast (third reel) |
| Orren, the blacksmith | Mortal smith from a line that kept scraps of the old engineering | To keep dangerous relics working and out of fools' hands; distrusts the Unbound at first | Older, deep, rugged, dry humour | Gideon |
| The Archivist | Damaged intelligence keeping the old records | To have the record be complete | Androgynous, calm, ancient, faintly mechanical, fragmentary | Onyx |
| Narrator | Opening only; a woman's voice (may be Lyra, long ago) | — | Slow, grave | Helena |
| Ashen Sentinel | Gate sergeant made into a guardian, told it was for one winter | To be relieved | Immense, flat, helmeted; human at the end | Sterling |
| Hollow Executioner | Still enforcing the law of a state that is gone | The sentence carried out | Toneless, certain | Vlad |
| Pale Huntsman | Mortal hunter of the old engineered creatures; thinks the Unbound is tyranny returning | To end what the kings bred | Cold, tired | Brooks |
| Crimson Widow | Rebel commander kept alive by an experimental system; recognises people inside the Unbound | To stop minds being used as tools again | Sharp, shaken, bitter; can yield | Sloane |
| Cathedral Beast | Engineered guardian of the cathedral's lower facility | — (no speech) | Roars only | — |
| Gravewarden | Keeper of the stored minds; knows exactly what he guards | Someone to remember their names | Old, patient, tender | Bram |
| Frostbound King | One of the last original Everbound; tried to give up immortality and sealed himself away | That no one repeat his kind's mistakes | Ancient, weary, dry | Alistair |
| The Forgotten Monarch | Not an emperor: a steward appointed in the collapse to keep the machines running | Civilization's survival, at a price he has counted | Mature, regal, controlled, never shouting | Caspian |
| The Devourer of Names | Centuries of discarded, corrupted memories in one body | To be someone again | Many voices: men, women, children | Luna (to be layered) |
| Veyrath, the Cinder Wyrm | Siege creature woken under a volcanic fortress | — | — | — |
| Skeldra, the White Ruin | Guardian that survived in the frozen mountains | — | — | — |
| Azhurion, the Last Wing | Oldest engineered dragon; part armour, part machine (not yet in game) | — | — | — |

Voices were chosen from a list that gives names only, with no descriptions and no way for the build environment to listen. Treat the casting as placeholder until someone auditions it. Changing a voice is one line in `tools/gen_dialogue.py` plus re-running `tools/voices.py` for that speaker's lines.

In-game name mapping: the dragon bosses are still labelled Veyrath and Skeldra in `data/bosses.json` (ids `cinder_wyrm` and `rimewyrm`).

## The Witness: full entry
**Design.** A ceremonial mask of blackened metal with faded gold inlay, amber glass eyes, an inscription round the rim that has been filed away in one place (where a name was), and an inner light that brightens when it speaks and gutters when a memory comes back. One cheek is cracked and one eye is dimmer than the other. It is an object of office, like a seal or a mace. It is not a head, has never held a head since the sealing, and has no body. It rides on the knight's belt or at the shoulder. It cannot move or act; it can only see, remember and talk.

**History.** See `STORY_BIBLE.md`, "The Witness". In one line: it wrote down the judgments of thirteen kings, tidied the past seventeen times when ordered, refused the eighteenth, and was walled up under their monument with the refusal cut out of its memory.

**Voice on the page.**
- Short sentences in plain old-world English. Understatement, not ornament. "Rather", "I should like", "one ought" are in its mouth; "thee", "thou", "forsooth" never are.
- Dry before grave. It makes the joke first and lets the weight arrive afterwards: "A candle three hundred years alight. In my day we called that a miracle. We were paid to."
- It indicts itself as readily as anyone: "By persons like me, in rooms like this. I merely wrote it down neatly."
- It corrects itself when a memory is not its own: "I was here. No. I was told I was here."
- It calls Lyra "the voice in the walls" until late, Orren "your smith", the player nothing at all.
- It gives the player information and opinions, never orders, and never an answer to the final choice.

**With the others.** Lyra: mutual suspicion that becomes a working respect; they agree only that "broken is not gone". Orren: his line survived by trusting nobody in a mask, and the Witness approves. The Archivist: the machine keeps what was recorded, the Witness remembers what was struck out; they have not yet been written a scene together. The Forgotten Monarch: the Witness has served "reasonable men" all its life and knows exactly what he is.

**What stays unknown.** Its name. Which of the thirteen kings was cut out of it. Who gave the order of the Great Silence, if anyone did.

**Where its lines live.** `tools/gen_dialogue.py`, the section headed "the Witness"; scene ids start `w_` (`w_<region>_<place>`, `w_<foe>_approach`, `w_<foe>_victory`, `w_talk_<topic>`) plus `witness_discovery`. Every line is marked `"recorded": false`.