# Hollow Reign: secrets, side missions and completion

Written 2026-11-26. Rules: `src/core/secrets.gd` (`Secrets`), thin wrappers in `src/core/game.gd`. Content: `tools/gen_secrets.py` writes
`data/secrets.json`, the `side` list in `data/quests.json` and the `hidden` list in `data/lore.json` (the existing `quests` and `lore`
lists are written back untouched). Subtitle lines: `tools/gen_dialogue.py` reads them from `data/secrets.json`. Tests: `tests/secrets.gd`.

**Scope.** The owner cut the first plan down part-way through ("the original was only a 2–3 hour playthrough fully"): about a dozen
secrets, at most six side missions, a completion figure that costs only a modest amount beyond the story, two milestones plus the
100% one, no grind lists. This document describes what is built at that size. What was cut is listed at the end.

Nothing here has run on a phone, and nobody has played it by hand: the road behaviour is proved by headless tests and looked at in
software-rendered captures only.

## 1. Research

Searches were made with the web search tool on 2026-11-26 and returned results; no page was fetched and read in full, so everything
below is the search tool's summary of fan wikis, guides and press, not first-hand verification. Where the summaries were thin, the
category is marked "general knowledge, unverified". Only the *kind* of idea is recorded. No name, item, place, puzzle solution or
joke from any other game is used anywhere in Hollow Reign.

| Kind of secret | Where it was seen | Verified by search? |
|---|---|---|
| Bonus items hidden in the scenery of a fixed camera path: small, unlabelled, yours only if you notice and tap them | swipe-duelling trilogy (publisher's own page says bonus items are sometimes hidden in the environment; reviews mention hidden chests) | yes (summary) |
| Bought or found sketches that show a framing of a place elsewhere; tapping the matching spot there gives an item | the trilogy's second and third games (fan wiki, community map guides) | yes (summary) |
| A deliberately silly novelty weapon as the reward of one of those sketches | community map guide | yes (summary), one example only |
| A late-game key object that, carried back to an early place, opens new rooms and optional bosses | fan wiki, forum post | yes (summary) |
| A hidden mode reached by doing the "wrong" thing at the very start (losing the first fight on purpose) | fan wiki | yes (summary) |
| A hidden ending and the next-cycle mode behind an optional chain of bosses | fan wiki, press coverage of the free update | yes (summary) |
| The whole place being small and giving up its secrets over a few repeat runs | forum review | yes (summary) |
| Walls that are not walls: struck or touched, they open onto treasure, a path or an optional boss | open-world action RPG (wikis, press) | yes (summary) |
| Whole areas gated behind an optional boss or an NPC's errand | same (guide summaries) | yes (summary) |
| NPC errands that are easy to lose track of and can be missed | same (guide summaries) | partly: "hard to track" confirmed, "fails silently if you progress too far" is general knowledge, unverified |
| Secret endings behind long optional chains | same | general knowledge, unverified (the search returned nothing on it) |
| A lore detail most players never notice, hidden in plain sight in a model or description | same (press) | yes (summary) |

What we took: tappable things in a fixed view; a drawing of somewhere else; a place that answers a return visit; one thing found
only on a second cycle; one in-world joke object; one optional duel off the road; the feeling that the place is small enough to know
completely. What we deliberately did not take: anything missable (nothing here can be failed or locked out), anything that needs a
guide (every secret has a tell in the scene or a line that points at it), and long chains.

Sources (search results, not fetched): [Wikipedia: Infinity Blade](https://Wikipedia.com/wiki/Infinity_Blade) ·
[Wikipedia: Infinity Blade II](https://Www.wikipedia.org/wiki/Infinity_Blade_II) ·
[Epic Games: Infinity Blade III](https://www.epicgames.com/infinityblade/en-US/game-info/infinity-blade-iii) ·
[Fan wiki: maps](https://infinityblade.fandom.com/wiki/Maps_in_Infinity_Blade_III) ·
[Fan wiki: negative bloodlines](https://infinityblade.fandom.com/wiki/Negative_Bloodlines) ·
[Fan wiki: the Deathless Kings](https://infinityblade.fandom.com/wiki/Infinity_Blade:_The_Deathless_Kings) ·
[AppUnwrapper: treasure maps guide](https://appunwrapper.com/2012/05/25/infinity-blade-ii-treasure-maps-guide/) ·
[Pocket Gamer: dungeon update](https://www.pocketgamer.com/infinity-blade/infinity-blade-gets-the-deathless-kings-dungeon-in-free-update) ·
[iMore forum review](https://forums.imore.com/threads/infinity-blade-in-depth-review.279288/) ·
[TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/InfinityBlade) ·
[Fextralife: secrets](https://eldenring.wiki.fextralife.com/Secrets) ·
[Fextralife: illusory walls](https://eldenring.wiki.fextralife.com/Illusory+Walls) ·
[Dot Esports: illusory walls](https://dotesports.com/general/news/all-illusory-wall-locations-in-elden-ring) ·
[PC Gamer: the 50-hit wall](https://www.pcgamer.com/uk/this-50-hit-elden-ring-illusory-wall-is-probably-a-bug/) ·
[Den of Geek: secrets](https://www.denofgeek.com/games/elden-ring-secrets-that-will-change-how-you-look-at-the-game) ·
[TheGamer: hidden areas](https://www.thegamer.com/elden-ring-hidden-secret-areas).

## 2. The secrets (thirteen)

Each secret has: a **tell** (something in the scene, or a line of a record) so it can be found by attention alone; a **hint** the
Completion page may show while it is missing (tested never to contain the solution, the name or the description); one **subtitle
line** from Lyra or the Witness, text only, not recorded; and a reward that is never a statistic you need. All hidden records are
shown in the Chronicle's Records tab once found. Stops are numbered from 0.

| id | Where | Kind | How it is found (spoiler) | Tell | Gives | Hint shown |
|---|---|---|---|---|---|---|
| `cy_loose_stone` | Courtyard 2, the Barbican | unmarked spot | Tap the pale, tilted flagstone right of the path | one flagstone paler than the rest, not lying flat, a faint light at its edge | record "The Relief Order", 60 gold | "At the Barbican, something underfoot is not as it was laid." |
| `cy_second_candle` | Courtyard 5, the chapel | return | After the Ashen Sentinel falls, come back and tap the second candle | a small cold-blue candle that was not there before | record, trophy "The Second Candle" | "The chapel alcove changes once the gate has no keeper." |
| `cy_charcoal_sketch` | Courtyard 4, gate passage | treasure sketch (the drawing) | Tap the rolled hide wedged between two stones | a pale roll between two stones | record "Sketch: The Spring" (describes the spot), 1 shard | "Somebody left their working-out in the gate passage." |
| `bw_three_stones` | Blackwood 5, the spring | treasure sketch (the place) | Holding the sketch, tap the row of three stones | three stones in a row, the middle one dark. Touched without the sketch: "They mean nothing to you yet." | finish "Soldier's blacking", 2 shards | "A drawing found elsewhere shows this spring from the artist's side." |
| `bw_dark_lantern` | Blackwood 0, Lantern Road | unmarked spot | Tap the one lantern that is not lit | a low lantern post with a dark cage, at a stop whose own text says the lanterns are "still lit" | record "The Lamplighter's Round" (gives the order for the posts), 80 gold | "On the Lantern Road, count what is lit and what is not." |
| `bw_woodpile_posts` | Blackwood 4, the Woodpile | sequence | Touch the four posts in the order the record gives: tall, split, leaning, short. A wrong touch resets | four posts told apart by shape alone | record "The Unfinished Road", 3 Old Iron, trophy "A Trimmed Wick" | "Four marker posts stand about the woodpile. A lamplighter once wrote down how they are tended." |
| `ca_end_of_cylinder` | Cathedral 4, Choir Loft | listen / wait | Stand there 16 s without acting | Lyra's remark that the hymn is a recording; the existing record "The Hymn Cylinder" | record "End of the Cylinder", 110 gold | "The hymn in the choir loft is not as endless as it sounds." |
| `cr_whispered_name` | Crypt 5, the reliquary lamp | listen / wait (rare) | Sit by the lamp 18 s without acting | the stop's own text ("It asks nothing"); Lyra says there is something to tell you below | record "A Name You Answer To", 4 shards | "The reliquary lamp asks nothing. It does, given time, say something." |
| `ro_no_shield` | Roost 6, the Summit | mastery | Defeat the Cinder Wyrm with no shield equipped | a clue on the Glass Road (Roost 0): a blade fused upright in the stone; touched, it says whoever stood there carried no shield. Not a secret, not counted (`clues` in the data) | trophy "Cast of Two Footprints", title "the Unshielded" | "Something stands fused into the Glass Road. Whoever left it carried less than you do." |
| `ci_reflection` | Citadel 1, the Wall Walk | hidden duel | After beating the Rime Duelist, come back, tap the slab of black ice, and beat what steps out | a tall slab of black ice with a faint light | record "Recall Surface", title "Twice Yourself", 4 shards | "On the Wall Walk somebody practised alone for an age. Ask what against." |
| `de_candle_bearer` | Deep 3, the Last Candle | visit with the Witness (rare) | With the Witness found, tap the small cold candle | a candle on the ground, the stop's own text ("Someone carried it this far") | record "Who Carried It", 260 gold | "The Last Candle was set down by someone. One of your companions could say who." |
| `th_parade_sword` | Throne 1, the Antechamber | in-world oddity | Tap the enormous gilt sword the looters left | a gaudy gold sword propped on a crate | record and trophy "The Parade Sword of the Ninth Jubilee" | "The Treasury was emptied by people with taste. They left one thing." |
| `cy_cycle_count` | Courtyard 0, the Breach | New Game Plus (rare) | Begin a New Game Plus; at the very first stop tap the blade standing in the rubble | a blade standing in a stone that was not there the first time | record "The Cycle Count", trophy, title "the Twice-Walked", 6 shards | "The Breach looks different to someone who has already seen how this ends." |

Families covered: unmarked tappable spots (2), return after a guardian falls (1), listen/wait (2), sequence from a record (1),
treasure sketch (1, in two halves), hidden optional duel (1), mastery (1), visit with the Witness found (1), in-world oddity (1),
New Game Plus (1).

**The three rare ones touch the central mystery without touching the endings.** The lamp reads the names of the people who made you
and leaves room for one more. The candle on the unlit stair has a living thumbprint in its wax, and Lyra was told she had never left
the sanctuary. The tally at the breach is in your own hand and is longer than one. None of them says what the Crown should become.

**The hidden duel** uses only what exists: the Rime Duelist's patterns and rig rules, retuned in memory by `Secrets.challenger()`
(health and blow weight set from the knight's own numbers, the knight's own model and weapon class, the trait `parry_open`). It is
never a guardian, never on a road's list, drops no core, and is added to `Db.foes` only when asked for. It is started through
`Explore.fight` → `main._enter_duel`, the same door as every road fight; winning returns to the same stop. Losing it is a death like
any other (the road resets, nothing is lost).

**The oddity.** The owner's example was a deliberately awful weapon you can carry. That needs an entry in `tools/gen_equipment.py`
(another agent's file during this pass), so the Parade Sword is a trophy with a record and a line, not an equippable item. An
equippable version (1 damage, the slowest swing in the game, a mastery mark that only says "Why") is a ten-line follow-up there.

## 3. Side missions (five, "in passing")

Kept in `data/quests.json` under `side`, with the same shape as the eight existing tasks, and listed with them in the Journal (tagged
"IN PASSING"). They go through the same `Game.quest_ready / quest_progress / claim_quest`. New kinds of need: `materials` (handed
over on claiming), `feats` (deeds a duel or a road stop records), `secrets`, `secrets_in`. None blocks anything.

| id | From | Ask | Reward | Cost in play |
|---|---|---|---|---|
| `orren_stock` | Orren | bring 6 Old Iron | 150 gold, finish "Oiled black" | the first two roads drop about 26 (economy simulation) |
| `orren_proof` | Orren | win 3 fights with a Courtyard Longsword in hand | 200 gold, 3 shards | the sword is 260 gold in his first stock; any three fights |
| `lyra_courtyard` | Lyra | find 3 secrets in the Fallen Courtyard | 150 gold, 2 shards | the three that do not need New Game Plus |
| `lyra_stand_still` | Lyra | twice, stay until a place has finished speaking | finish "Dusk grey", 120 gold | the two listening secrets, both on the story's road |
| `witness_record` | The Witness (once found) | find 6 secrets | title "Corrector of the Record", 300 gold | about half of them |

The eight existing tasks are unchanged and count toward completion as they are.

## 4. Completion

`Game.completion()` (read only) returns:
`{pct, categories {cat: {name, done, total}}, remains [hints], regions [{id, name, pct, unlocked, categories, remains}], milestones [{id, at, reached, reward}]}`.

Counted things (each once; `Secrets.things()` enumerates them and the test checks each has a reachable source):

| Category | What | Count | Weight overall | Weight in a region |
|---|---|---|---|---|
| Stops walked | each of the 7 stops of each road, marked when you move on from it or end the road (`profile.completion.stops`, kept through New Game Plus) | 56 | 25 | 30 |
| Guardians ended | every guardian, optional ones included | 12 | 20 | 25 |
| Secrets found | section 2 | 13 | 25 | 25 |
| Tasks done | the eight tasks and the five side missions | 13 | 15 | (no road) |
| Records recovered | the fifty road records (found by arriving) | 50 | 15 | 20 |

`pct = Σ weight × done / total`, floored to one decimal, and exactly 100 only when every category is whole. A region's figure uses the
region weights over the categories that road has. Nothing counted can be lost, so the figure never falls (tested by doing everything
in a random order). Hidden records come with their secrets and are not counted twice. Equipment owned, forge work, masteries,
sequences and endings are **not** counted: at this game's length they are the grind the owner asked to leave out.

"Something remains here" lines are the secret's own hint, or one fixed line per category ("A stretch of this road has not been
walked on foot.", "Something here has not been faced.", "A record on this road is unread.", "A task in the Journal is unfinished.").

**Milestones** (data: `milestones`; paid once by `Secrets.sync` on the next save; keepsakes only, tested to change no number):
50% finish "Field-dressed" and title "Surveyor of Ruins"; 75% trophy "The Witness's Pen"; 100% finish "Unbound gilt", trophy "The
Empty Plinth", title "the Unbound, Entire".

**Estimated effort for 100% beyond finishing the story.** The story is the six required roads, about 27 fights. For 100% a player
also needs: the Roost and the Deep (about 5 fights each by the fight-first route), the three optional guardians on the required roads
(3 fights), one or two extra walks of the Citadel's first stops if the drake of the existing task "What the Kings Bred" does not
come up (it is drawn from a pool of two: 0 to about 4 fights), a return to two stops (the chapel after the Sentinel, the Wall Walk
after the Duelist: 1 or 2 fights on the way), the hidden duel (1), any retries of the shieldless wyrm, about a minute of standing
still in two places, and starting a New Game Plus and walking to its first stop (no fight). That is **roughly 15 to 20 fights**
beyond the story. At the bot-measured 45 to 125 seconds a fight in `docs/EQUIPMENT_PROGRESSION.md`, plus the roads between them, that
is an estimated **30 to 55 minutes**. This is arithmetic from fight counts, not a timed playthrough; nobody has played it. Nothing
in the count needs gold, so the economy simulation's purse is not a constraint: the only purchase any of it asks for is a 260-gold
sword (about two wins).

## 5. Saving and migration

New profile keys (all additive, all kept through New Game Plus): `secrets {id: true}`, `secret_lore [ids]`, `feats {key: count}`,
`completion {stops, milestones, finishes, trophies, titles, title, shop}`. `SAVE_VERSION` stays 2: an older save is recognised by
having no `completion` key, and `Secrets.backfill` credits it once (a road whose guardian has fallen or that is cleared counts as
walked end to end; a road with its shortcut mechanism turned counts to that stop). `tests/fixtures/save_v2.json` is a version-2
save written by the code as it was before this pass; the tests migrate it and the three older fixtures, twice each.

## 6. What is playable now, and what is data only

Playable on the real-time road (`src/ui/explore.gd`): all hidden hotspots and their tells, the wait secrets, the sequence with
reset, the locked sketch target's line, the discovery moment (camera ease, a light, the subtitle line, a banner naming what was
found and what it gave), the hidden duel's start and its return to the same stop, "Secret found" notes for a secret earned inside
a duel. The Chronicle has a Completion page and shows found hidden records. The Journal lists side missions with the tasks.

Data only, or not shown where it should be:
- **Finishes** are stored and selectable through `Game.set_finish` / `Game.finishes_available()`, but nothing in the game draws a
  finish yet (true of the four existing ones as well), and the Armory screen does not list the earned ones (another agent's file).
- **Trophies** are listed on the Completion page. Nothing is placed in the sanctuary scene.
- **Titles**: `Game.title()` / `Game.set_title()` exist and the Completion page shows the current one. No other screen shows it and
  there is no picker.
- **The filmed road** (`settings.cine_road`, off by default, Courtyard only) has no hotspots: `src/cine/` was not to be edited.
  Secrets there are found on the real-time road.
- The side mission reward kind "Orren will stock a blade" is implemented (`completion.shop`, read by `Game.shop_unlocked`) but no
  remaining mission uses it.
- Only 2 of the 13 tells were looked at in a capture; the other positions follow the same placement rule as the coin pouches and
  could sit inside scenery at some stops. They need a look on each stop.

## 7. Cut when the scope was reduced

From 34 secrets to 13: the second listening secrets of the Courtyard, Blackwood, Roost and Citadel; the return secrets of the
Blackwood, Cathedral and Crypt; the second and third sequences (votive stands, name-plates); the second treasure sketch
(Crypt to Throne); two hidden duels (a duellist who appears if the Banneret's first blow is parried; the Sentinel as he was stored);
two mastery secrets (the Sentinel unmarked, the Winter King with every parry perfect); the "worn ring" secret of the Boneyard; the
unfinished statue; the wait in the Emptied Place. From 16 side missions to 5: the forge, carrying and hunting errands. From the
completion count: gear owned (which alone needed roughly 76,000 gold of shop stock, about one and a half further cycles), forge work
finished, masteries, sequences, endings and challenges; the 25% and per-region milestones. The deeds those would have used
(`parry_first`, `flawless`, `perfect`, `win_cls`) are still recorded by `Secrets.duel_ended`, at no cost, should any return.
