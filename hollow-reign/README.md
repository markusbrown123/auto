# Eternal Edge

A dark-fantasy sword-duelling action RPG for iPhone and iPad. Swipe to cut, swipe against a blow to parry it, step aside, hold the line, and learn each guardian's rhythm. Premium, offline, no ads, no purchases, no accounts.

Built with **Godot 4.6** (GDScript, Mobile renderer). See `docs/RESEARCH.md` for why Godot rather than Unreal.

## Run it
1. Install Godot 4.6 (standard build) from godotengine.org.
2. Open `project.godot`, press Play.

On desktop the mouse acts as a finger. Keyboard: arrow keys cut, `A`/`D` dodge, `Space` blocks.

## Controls (touch)
- **Swipe** in any of eight directions to cut. Cuts only bite while the foe is open (recovering or staggered); a guarding foe deflects them, and repeated reckless swings provoke a counter.
- **Swipe against an incoming blow** to parry. The closing ring shows the timing, the arrow shows the direction. A perfect parry staggers the foe.
- **Arrow buttons** dodge left and right. Some attacks can only be dodged one way; a perfect dodge earns a boosted counter.
- **Shield button** (hold) blocks, at a stamina cost. Red-glowing attacks cannot be blocked.
- Alternate cut directions to build a chain. Repeating the same cut glances off.

## Tests
```
tools/test.sh [path-to-godot]
```
Runs three suites: `tests/tests.gd` (combat rules, fairness, progression, saves), `tests/integration.gd` (every screen, and a bot-played duel against every foe through the real scene), and `tests/touch.gd` (synthetic multi-touch through a real window; uses xvfb on Linux).

`tools/shoot.sh <dir> <times> [--demo=<foe> | --screen=<name>]` renders screenshots without a GPU.

## Layout
```
data/        items, foes and regions as JSON (add content here, no code changes)
src/core/    Db (data), Game (profile, saves, progression), Stats, Sfx
src/combat/  DuelSim (pure rules), Duel (presentation), DuelBot, SwipeInput
src/chars/   FighterRig: procedural armoured rig with IK-driven attacks
src/world/   Arena (procedural environments), Backdrop, Look (materials)
src/ui/      title, sanctuary hub, road/exploration, HUD, overlays, settings
tools/       data authoring scripts, audio synthesizer, test and capture scripts
docs/        research, App Store, iOS build, privacy policy, prompts, credits
```

## Status
See `DEVELOPMENT_STATUS.md` for what works, what is placeholder, and what is next.
