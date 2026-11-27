# Hollow Reign: story bible

Canon for the game. Source: the director's lore brief of 2026-11-25, which replaces all earlier narrative. Companion files: `WORLD_HISTORY.md`, `CHARACTER_BIBLE.md`, `CAMPAIGN_SCRIPT.md`, `CINEMATIC_SCRIPT.md`, `DIALOGUE_DATABASE.json`.

## Premise
A far-future world that looks medieval. Its castles, temples, relic swords and dragons are the remains of a technological civilization nobody remembers. What people call magic is machinery they no longer understand. The game never says this outright at the start: the player should believe they are in a knightly fantasy until they walk beneath the Cathedral of Ash and find a working laboratory.

## The player: the Unbound
Male or female knight, same role, separate voice. Wakes in a damaged resurrection chamber under an abandoned fortress, nineteen years after the Great Silence. Remembers a name, a childhood, some training, and also things that happened centuries before their birth, belonging to several people.

The truth, revealed in the Sunken Crypt: mortal researchers built the Unbound to end the Crown. Their mind is assembled from memories donated by soldiers, engineers, civilians and survivors. They are a new person carrying the old world's experience. Because no single consciousness record owns them, they can enter Crown facilities without being controlled. They are not a returning god; they are humanity's attempt to move past gods.

## The Witness
The second companion, added by the final production brief of 2026-11-26. Full character entry in `CHARACTER_BIBLE.md`.

- **What it is.** A human mind, very old, held in the instrument of its own office: the court's lantern, a faceted pod of white panels on a graphite core, a helmet wide, with one off-centre bar of warm light that gutters when it thinks (form changed 2026-11-27 at the owner's direction; it was a mask at the belt before: `CHARACTER_BIBLE.md`, "The Witness"). It is an instrument and nothing else: not a head, not a face, no body. It floats free: it roams near the knight, goes to look at things, and keeps to the edge of a fight. The mask of the next paragraph is what the recorder WORE in life; the lantern hung over the judgment table, and it is what the mind was shut in.
- **Who it was.** The recorder of the Everbound courts of Vaelora. The mask was the office: it was worn to set down judgments, so that the record had no face to bribe. Seventeen times in the Age of Crowns the past was tidied and the recorder held the pen (the Archivist's "history has been rewritten seventeen times" is the same count, seen from the machine's side). The eighteenth order, near the end of the War of Broken Thrones, was to erase the record of what was done to put down the rising. The recorder refused. The Everbound could not destroy a mind the record depended on, so they cut out what they could of its memory, shut the mind in its own mask, and walled it under the monument of the thirteen kings in what is now the Fallen Courtyard. It has been there for more than three hundred years. It slept through the Great Silence.
- **Where it is found.** Chapter I, the Fallen Courtyard, second stop (stage 1, beyond the rubble, where the path divides): the monument has fallen, and under its plinth is a chamber that is on none of Lyra's plans. Scene `witness_discovery`. A save that is already past that stop finds it at the next stop it reaches.
- **What it wants.** For the record to be true, including the parts that condemn it. It does not ask to be freed, restored or forgiven.
- **How it speaks.** Cynical, dry, exact; conversational old-world English, never mock-archaic. It talks before important places, at landmarks, before most guardians and after them, and in the sanctuary when asked. It does not talk in a fight and never says the same thing twice.
- **Its memory.** Deliberately cut, and returning at places that touch it. The order of return is the order of the road: the Sentinel's posting order (Courtyard), the toll clerk (Blackwood), the procession and the Rising (Cathedral), the ledger at the lower door (Crypt), the tally of shells (Roost), the queen struck from the rolls and the first refusal (Citadel), its office and the oath (Deep), and at last why it was shut away (Throne). It never recovers its own name, and one of the thirteen kings stays cut out of it. Both are left open on purpose.
- **The Witness and Lyra.** They do not trust each other at first and they remember differently. Lyra speaks from inside the Crown and from its records; the Witness from outside and from before, with holes. Where they disagree the game does not say who is right: whether the guardians were "people" or "volunteers", whether the Great Silence came without warning, how anyone can count time from inside, whether every stored mind can be saved. Lyra stays the emotional centre and the authority on origins, consciousness and the ethics of immortality. The Witness is the authority on the courts, the kings and what was done.
- **What it must not do.** It does not reveal the chapter mysteries ahead of their chapters: it names a laboratory only at the Cathedral Beast's door, knows nothing of the Unbound's origin until the Crypt has shown it, and does not know what the Crown is eating. It never makes the final choice or recommends one ("What is decided in there is yours to decide. I shall only witness it."). It is present in all three endings as the one who will set down what happened.

## Who speaks
Fixed by the final brief and encoded in `data/dialogue.json` under `speech` (any foe not listed is category A). `src/core/companion.gd` and `src/combat/duel.gd` enforce it.

| Category | Who | Rule |
|---|---|---|
| A | Cathedral Beast, Veyrath, Skeldra, Azhurion, every lesser foe | No human speech. Before the fight the Witness (or Lyra, if the Witness cannot) says what the thing is. |
| B | Ashen Sentinel, Hollow Executioner, Gravewarden | At most four short lines each. The Sentinel keeps its challenge and its last words. |
| C | Forgotten Monarch, Crimson Widow, Frostbound King, Pale Huntsman | Directed dialogue. |
| D | The Devourer of Names | Layered fragments and whispers only, never a sentence addressed to the player. |

## Central conflict
The Eternal Crown, the old immortality network, has woken and is consuming stored human minds to keep itself running. Destroy it and everyone stored inside is lost. Leave it and it keeps feeding. The Forgotten Monarch believes sacrificing some to keep civilization's machines alive is the lesser evil, and he is not simply wrong.

## Tone and rules
- Reveal through architecture, equipment, records and stray lines, not exposition.
- Every guardian was a person. Each boss gets a human moment, usually at death.
- Resurrection is acknowledged in the fiction: the chamber, Lyra, and some bosses notice the player coming back.
- No reuse of any other game's names, characters, dialogue or designs.

## Structure
| Chapter | Region | Guardian | What the player learns |
|---|---|---|---|
| I. The Broken Oath | The Fallen Courtyard | Ashen Sentinel | The enemies were people |
| II. The Kingdom Without Kings | The Blackwood | Hollow Executioner (optional: Pale Huntsman) | Someone is waking the guardians on purpose; meet Orren |
| III. The Woman Who Remembered | The Cathedral of Ash | Crimson Widow, then Cathedral Beast | The world is science fiction; the cathedral is a laboratory |
| IV. The City of the Dead | The Sunken Crypt | Gravewarden | The Unbound's origin; the Crown is eating the stored dead |
| (side) | The Wyrm's Roost | Veyrath, the Cinder Wyrm | The dragons were engineered siege weapons |
| V. The King Who Refused Eternity | The Frozen Citadel | Frostbound King (optional: Skeldra, the White Ruin) | How the Crown can be divided |
| Secret | The Hollow Deep | The Devourer of Names | The minds the system failed; unlocks the third ending |
| VI. The Hollow Throne | The former capital | The Forgotten Monarch | The choice |

The Wyrm's Roost and the Hollow Deep exist in the game as full regions; the brief treats their bosses as optional or secret. They currently sit on the main road and should be made optional when the ending logic is built. A third dragon, Azhurion, the Last Wing, is canon but not yet in the game.

## Endings
1. **The Final Silence.** The Crown is disconnected. Immortality ends; the archives, and Lyra, are lost. Sunrise.
2. **The Last Steward.** The Unbound takes over the Crown without the Monarch's methods. Deliberately ambiguous.
3. **The Free Cities.** Needs the optional quests, recovered memories and the Devourer defeated. The Crown is split into independent systems nobody can rule; the stored choose to stay, be re-embodied or let go; Lyra may exist outside the network.

Post-credits, whichever ending: a far fortress under an unfamiliar sky, a machine waking, "Local network disconnected. Searching for external systems." A distant signal answers.

## Implementation status (2026-11-26)
- In the game: opening narration, awakening with Lyra, a Lyra remark at each Courtyard stop, the Sentinel's challenge, last words and memory record, Orren at the forge, resurrection lines, and first-meeting and death exchanges for the other guardians. All subtitled; voiced where audio exists.
- In the game as text only (subtitles, nothing recorded): the Witness. Discovery scene, a remark on approaching each region, three landmark remarks per region, an exchange before and a remark after every guardian and dragon, twelve optional sanctuary conversations (four of them arguments with Lyra), and the returning memories. Chosen and rationed by the `Companion` autoload. The sanctuary conversation list and the archive screen have an API (`Companion.sanctuary_topics()`, `play_topic()`, `archive()`) but no screen yet; the mask has no model on the knight and the discovery has no filmed scene.
- Speech categories are enforced: the Sentinel's retry line was cut, the Devourer's lines were rewritten as fragments (so its three recorded takes are no longer used), and silent foes get companion context instead of an intro.
- Not yet built: the Widow's yield-or-fight choice, the Huntsman's peaceful resolution, memory-flashback chapters, the three endings and their choice, the post-credits scene, the 50 lore discoveries, the Monarch's regeneration phase.
