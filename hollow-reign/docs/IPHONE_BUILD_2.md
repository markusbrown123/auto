# iPhone test build 2 (first-boss slice), 2026-11-28

Branch `claude/hollow-reign-game-dev-srhrwr`. The final commit is the one that adds this file; the game code in it is
the code every check below ran on (later checkpoint commits, if any, only add logs).

## What was checked on this code
- `tools/check.sh`: no script errors.
- `tools/test.sh`: all 11 suites pass (tests 3843, equipment 3802, generations 580, secrets 1449, cine 83, plus armory,
  shop_forge, integration, campaign, touch, cine playback).
- `tools/clone_test.sh`: fresh clone of the pushed branch imports with 0 errors and runs with 0 load errors.
- A Mac-style update over an old import (the blue starting-shield texture already extracted) re-extracts the new grey one.
- Two complete automated playthroughs by synthetic touch, from a new save to the Ashen Sentinel's defeat and the sanctuary
  after it (`marketing/build_check/slice/final_m.log`, `final_f.log`): male knight with two deliberate deaths and
  "Retry from checkpoint", female knight straight through. Both ended normally: 0 stuck steps, 0 script errors, no crash.
  Each logged one "tap missed" on the pause button: the button opens the pause screen on touch-down, so the release lands
  on the pause screen; the game paused correctly both times. The "no card on screen" lines were the test player
  misreading the cards (fixed in the test player; a separate run tapped the cards themselves).
- Six-item gameplay check at normal speed (`marketing/build_check/REPORT.md`) and the enemy-defence check
  (`marketing/enemy_defence_pass/`).
- Not checked: anything on a phone, a real finger, frame rate, memory, heat, and how anything sounds (nobody has listened).

## Changes since the first iPhone test
**Combat**
- Free swiping: every swipe is a cut in any of eight directions. Into an open foe up to four quick swipes queue and land
  in order (8 swipes at 7 a second = 8 cuts). Into a guarding foe only the latest is kept, so spam stays a losing plan.
- The shown line is a bonus, not a requirement: along the seam ×1.6, a counter after a parry ×2.0, variety bonus.
- Enemies defend: once recovered they raise their guard; cuts into it are deflected (about 10% damage, extra stamina),
  their weapon visibly swings across to meet the cut, with its own deflect sound. After 2–4 guarded cuts (per enemy) they
  punish. Openings after parry / dodge / perfect block now differ by enemy (0.8–1.5 s); a poise break gives about 3 s.
- Blocking: a held block never costs health while stamina lasts. Each block uses a shield charge; with none left it costs
  much more stamina instead. Perfect block (raised at the last instant): free, stuns the foe. Unblockable blows are
  warned about 1.2 s ahead (word, red blade, rings) and go through a shield. Guard break only when stamina runs out.
- Big swipe indicators: wide, translucent white finger trail; large centred animated prompt line (amber for the counter).
- Bosses and big enemies: sword animations reworked (gather, coil, follow-through, planted feet, both hands on two-handers).

**Death and checkpoints**
- "YOU HAVE FALLEN" screen with Retry from checkpoint and Return to main menu. Retry restarts at the last road checkpoint
  with full health; enemies along it reset; gold, items and levels kept; no time jump.

**Walking and places**
- Walk speed slowed to match the walk animation (1.12 m/s); one footstep per foot plant, per surface; clear paths;
  slower scenic walks in the story scenes; high-road landmarks; far-future arenas.

**Look**
- New male knight (your concept B), monochrome gunmetal armour, helmets, no hood, no neon, charcoal undersuit.
- Shield clipping fixed; starting shield and other shields grey instead of blue; cloak colour choice removed.
- Lamp post no longer stands in front of the knight in the second-fall scene; stacked pause panels fixed.

**Sound and voices**
- Sound engine: variation without repeats, layering, per-surface footsteps; resynthesised clashes, impacts, whooshes,
  parry and the new deflect (synthesised, no purchases).
- Male knight: new voice (Sterling, lowered, light helmet echo), all 45 lines. Female knight: her original voice with the
  softer space-helmet filter, all 45 lines. All other voices unchanged.

## Known issues and unfinished
- Nothing has run on a phone yet in this build; performance, memory and audio are unverified.
- Sound is still synthesised. If it sounds cheap, the plan is openly licensed recordings (no generated effects).
- Enemy animation: the Pike Sergeant's rising glaive cut and the Gravewarden's rising cut pass through their own thigh;
  big enemies' hit reactions still use older poses; a spent greatsword can lie where the knight steps.
- Enemy openings were only watched on video for the Ashen Sentinel and Hollow Soldier; the others are tuned by numbers.
- The witness orb can be faint in bright daylight; the roll camera can swing widely; first-step walk animation is plain.
- Armour weight classes (A/C), more voice work and fight grunts for the male knight are not started (on hold by request).
- The filmed road and filmed duel (Settings > In testing) are off by default; leave them off.
- App size is large (about 1 GB) because later regions' models ship too.

## 1. Update the repository (Terminal, copy and paste)
```sh
cd ~/Developer/auto
git status --short | head
cp hollow-reign/export_presets.cfg ~/Desktop/hollow-reign-export_presets.backup.cfg
git stash push --include-untracked -m "local changes before iPhone build 2"
git fetch origin claude/hollow-reign-game-dev-srhrwr
git checkout claude/hollow-reign-game-dev-srhrwr
git merge --ff-only FETCH_HEAD
git log -1 --oneline
cp ~/Desktop/hollow-reign-export_presets.backup.cfg hollow-reign/export_presets.cfg
cd hollow-reign && tools/mac_import.sh
```
- `git log -1 --oneline` must show the final commit given in chat (or a later "checkpoint" commit that only adds logs).
- The `cp` back restores your own export settings (bundle identifier, team), so signing is not set up again. The
  repository's export settings have not changed since the build you installed.
- If `git stash` says "No local changes to save", that is fine.
- `tools/mac_import.sh` takes several minutes and should end with "Import files changed by this Mac: 0".
  If Godot is not in /Applications: `tools/mac_import.sh /path/to/Godot.app`.

## 2. Import cache
You do not need to delete `.godot`. The import settings are unchanged; `tools/mac_import.sh` re-imports only what changed
(models, the shield, voices, sounds). Only if Godot shows missing or white textures afterwards: quit Godot, then
`rm -rf ~/Developer/auto/hollow-reign/.godot && ~/Developer/auto/hollow-reign/tools/mac_import.sh` (a full re-import).

## 3. Export to Xcode (Godot 4.6)
1. Open Godot, open `~/Developer/auto/hollow-reign/project.godot`, wait until the import bar at the bottom is finished.
2. Project > Export… > select your existing **iOS** preset (do not add a new one).
3. Check that Bundle Identifier and Team are what you used last time (they come from your restored file).
4. Click **Export Project…**, choose the **same folder and name** as last time, untick "Export With Debug", Save, and
   allow it to overwrite.

## 4. Install over the existing app (Xcode)
1. If Xcode has the old project open: File > Close Project. Then open the `.xcodeproj` in the export folder.
2. Select the target > Signing & Capabilities: "Automatically manage signing" on, Team = the same team as before.
   Bundle Identifier must be exactly the one installed on the phone; same identifier = the app is replaced, not added.
3. Connect the iPhone by cable, unlock it, choose it as the run destination at the top of the window.
4. Product > Run (⌘R). Xcode builds and installs over the existing Hollow Reign. Saves are kept (same identifier).
5. With a free Personal Team the 7-day limit restarts from this install. If the phone asks, trust the developer again
   in Settings > General > VPN & Device Management.

## 5. Phone checklist (both of you)
**Start**
- [ ] Launches; title and menu readable; buttons easy to hit; nothing under the notch or home bar.
- [ ] Continue from your old save works; a New Legacy also works.
- [ ] Character select: male knight in grey armour and helmet, no hood, no blue; female knight the same style.

**Fighting (Hollow Soldier, Banneret, Pike Sergeant, Rampart Breaker, Gate Colossus, Ashen Sentinel)**
- [ ] Swipe fast in every direction when the enemy is open: every swipe becomes a cut, in order, with no lag.
- [ ] The white finger trail is wide and clear; the big centre line shows parry/danger (white) and counter (amber).
- [ ] After a parry, dodge or perfect block the enemy staggers and you get a short window for a flurry.
- [ ] When the enemy recovers you can see it raise its guard; cuts into the guard spark off its weapon, sound different,
      and do little; keep swiping and it punishes you.
- [ ] Holding block: no health lost; shield charges count down; with none left stamina drains faster; guard breaks only
      when stamina is gone. Perfect block (raise just before the hit) stuns the enemy.
- [ ] Unblockable attacks are clearly warned (word, red blade) and hit through the shield.
- [ ] Hits, blocks and deflections each look and sound different.
- [ ] Big enemies' swings look heavy and natural; their feet stay planted.
- [ ] Pause during a fight (II, top right) opens one pause panel; Resume continues.

**Death and checkpoints**
- [ ] Die on purpose: fall, fade, "YOU HAVE FALLEN", Retry from checkpoint.
- [ ] Retry puts you at the last road checkpoint with full health, the enemy is back, gold and items are kept, no time jump.

**Walking and story**
- [ ] Walking is slower and heavy; footsteps match the feet and change with the ground; nothing blocks the path.
- [ ] Story walks are slow and scenic; landmarks visible; nothing stands in front of the knight.
- [ ] The male voice: deeper, helmet echo; the female voice: original with space-helmet filter. Say if either is wrong.
- [ ] The rest of the voices sound as before.

**Whole slice**
- [ ] Play from a new save to the Ashen Sentinel's defeat and back to the sanctuary without a crash or getting stuck.
- [ ] Armory, Shop, Forge and Settings work; quitting and relaunching continues where you left off.
- [ ] Note any stutter, heat, battery drain, crash, or a place where the app closed by itself (which scene).
