# Hollow Reign: Research Notes

Status as of 2026-11-25. Anything not confirmed by a source is marked **unverified**. Nothing here is legal advice.

## 1. Infinity Blade reference (design study only)

| Title | Release | Notes |
|---|---|---|
| Infinity Blade | Dec 2010 (unverified in this pass; from general knowledge) | Chair Entertainment / Epic, built on Unreal Engine 3 |
| Infinity Blade II | Dec 2011 (unverified in this pass) | Expanded gear, secrets, dual-weapon options |
| Infinity Blade III | Sep 2013 (unverified in this pass) | Added a larger structure and hub-style changes |

Release years are from background knowledge, not re-verified with a fetched source this session.

### How combat worked (from general knowledge; not re-verified this session)
- Directional swipe attacks: the player slashes across the screen. Swipe direction matters for parrying.
- Parry: swipe against the enemy's attack direction at the right moment. A successful parry opens the enemy to a counter.
- Dodge: left and right dodge buttons or swipes avoid attacks.
- Block: a block button with a limited shield or stamina resource.
- Break/stun windows: parries and dodges create openings. Combos in the opening deal bonus damage.
- Camera: fixed over-the-shoulder duel camera, stylised and cinematic.
- Flow: on-rails exploration between duels (tap-to-move through fixed paths), then a boss duel.
- Loop: bloodline/rebirth. Defeat the boss, pass the legacy to a new hero, replay with carried-over gear. Gear mastery grants XP as items are used.

### Why it was removed (December 2018)
Epic stopped selling the trilogy on 10 Dec 2018. Paraphrased reporting: Epic said it had become increasingly difficult to support the series at the standard it wanted, and existing owners could re-download for the foreseeable future with in-app purchases disabled.
- Quote reported by outlets: "it has become increasingly difficult for our team to support the Infinity Blade series at a level that meets our standards." Sources surfaced by search: [MacRumors](https://macrumors.com/2018/12/10/infinity-blade-games-removed-from-app-store), [Game Developer](https://gamedeveloper.com/business/citing-support-issues-epic-stops-selling-i-infinity-blade-i-games), [TouchArcade](https://toucharcade.com/2018/12/10/end-of-an-era-the-infinity-blade-trilogy-is-no-longer-available/).
- The primary Epic post was **not fetched** (host unreachable in this environment); the quote is as relayed by search summaries.
- Speculation by journalists (Fortnite focus, Epic's own store) is inference, not a stated reason.

## 2. The maintenance trap and how Hollow Reign avoids it

| Risk | Infinity Blade lesson | Hollow Reign mitigation |
|---|---|---|
| Engine churn | Old Unreal 3 mobile pipeline became costly to keep current | Godot 4.6, MIT licensed, engine source archived with the project; pin the version |
| OS churn | New iOS releases and SDK requirements force rebuilds | Annual rebuild cadence each autumn; keep deployment target modest |
| 32-bit cutoff | Apple dropped 32-bit apps (iOS 11) | 64-bit arm64 only from day one |
| Server dependencies | Online services age out | Fully offline, no servers, no accounts |
| IAP dependencies | Store/receipt rule changes (e.g. SHA-256 receipts, StoreKit changes) | Premium one-time price, no IAP |
| Dependency sprawl | Third-party SDKs need privacy manifests and updates | No third-party SDKs; engine only |

Apple's [upcoming requirements page](https://developer.apple.com/news/upcoming-requirements/) shows the cadence of forced updates (SDK minimum raised April 2026, deployment target raised September 2026), which is why an annual rebuild is budgeted.

## 3. Soulslike boss design principles (takeaways)
- **Readable telegraphs:** every damaging move has a distinct silhouette, wind-up pose, and audio cue.
- **Delayed attacks:** vary release timing so button-mashing parries fail; teach the rhythm first, then break it in later phases.
- **Phase transitions:** change moveset, arena, or tempo at health thresholds, with a short invulnerable beat to reset the player.
- **Punish windows:** big attacks end in recovery the player can read; reward with damage and posture break.
- **Posture/stagger:** a second bar (poise) lets skilled play shorten the fight without raising damage.
- **Fairness over HP inflation:** raise complexity and tempo, not health pools; avoid unavoidable damage and off-screen attacks.
- **Environmental storytelling:** the arena, statues, banners, and the boss's armour tell the history; no lore dumps.
- **Mobile-specific:** large hit targets, generous input buffer, forgiving first parry window, short retry loop.

## 4. IP guidance
- Game mechanics and ideas (swipe combat, parry, stamina) are generally not protected by copyright; specific expression is (code, art, characters, names, music, text, distinct UI layouts).
- Do **not** copy: names, characters, story, art assets, music, sound effects, screen layouts, icons, or marketing language from Infinity Blade or any other game.
- Do not use "Infinity Blade", "Blade" branding proximity, or "Infinity" in titles, keywords, or metadata. Do not name the game as a clone ("like Infinity Blade") in App Store metadata (Guideline 2.3, 4.1).
- Lore, bosses and regions in this project are original.
- This is not legal advice; consult an IP attorney before launch.

## 5. Trademark check: "Hollow Reign"

Searches run (web search only, no direct USPTO/EUIPO/WIPO/App Store/Steam database access):
- `"Hollow Reign" game`
- `"Hollow Reign" trademark OR app OR steam OR "App Store"`

Findings:
- No exact-match game titled "Hollow Reign" surfaced.
- Near matches: **"Hollow reigns"**, a free itch.io prototype ("software remake") at [itch.io](https://fire-x6x.itch.io/hollow-reigns-game); a Steam dark-fantasy action RPG named **"Hollow"** ([Steam](https://store.steampowered.com/app/4901160), [Steam](https://store.steampowered.com/app/5054910)); **Hollow Survivors** ([Steam](https://store.steampowered.com/app/2285940/Hollow_Survivors)); **Hollowgrace** ([Xbox](https://www.xbox.com/en-US/games/store/-/9P3G7VTTLPZT)); **Hollowcross** ([Steam](https://store.steampowered.com/app/4926270/Hollowcross)).
- "Hollow reigns" on itch.io is a very close spelling. Possible confusion risk in the games category: **flag**.
- A crowded "Hollow ..." namespace in games suggests the "Hollow" element is weak/common; "Reign" adds some distinction.
- **Not searched / unverified:** USPTO TESS/Trademark Search, EUIPO, WIPO Global Brand DB, the iOS App Store (not directly searchable here), Google Play, domain/social handles.

Recommendation: do **not** treat the name as clear. Commission a USPTO/EUIPO clearance search (classes 9, 41; possibly 28) and an App Store name search in App Store Connect before committing to branding.

### Five fallback titles (unsearched; each needs the same clearance)
1. Ashen Crown
2. Gravebound Reign
3. The Returned Knight
4. Cinder Throne
5. Hollow Crown Duel
