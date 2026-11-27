# Hollow Reign: Godot 4.6 to TestFlight (Mac required)

Status as of 2026-11-25. The Godot 4.6 docs page could not be fetched (docs.godotengine.org unreachable here). Details below come from Godot 4.4/4.5/4.7 docs seen via search ([4.5](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_ios.html), [stable](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)) and may differ for 4.6. Re-read the 4.6 page before building.

## Prerequisites
1. A Mac running a macOS version supported by the current Xcode. Xcode 27.2 appears to require macOS Tahoe 26.6 or later (search-result claim; **unverified**).
2. **Xcode 26 or later** with the iOS 26 SDK or later (Apple's requirement since 28 Apr 2026: [Apple](https://developer.apple.com/news/upcoming-requirements/)). Confirm the latest at [developer.apple.com/xcode](https://developer.apple.com/xcode/).
3. Apple Developer Program membership, USD 99/year ([enroll](https://developer.apple.com/programs/)). Price not re-verified this session.
4. Godot **4.6** editor (standard build, not .NET unless needed) and the **matching 4.6 export templates** (Editor > Manage Export Templates > Download and Install).
5. Command line tools selected: `sudo xcode-select -switch /Applications/Xcode.app`.

## Steps
1. **App Store Connect record:** Apps > New App. Platform iOS, name, primary language, bundle ID, SKU. Pick the name only after trademark clearance (RESEARCH.md).
2. **Identifiers:** developer.apple.com > Certificates, IDs & Profiles > register an explicit App ID. `com.hollowreign.game` is a **placeholder**; the bundle ID may contain only letters, digits, hyphens and periods, and cannot be changed after the first upload.
3. **Godot export preset:** Project > Export > Add > iOS. Set:
   - Application > App Store Team ID (10-character Team ID from your Apple account)
   - Bundle Identifier (same as the App ID)
   - Short/Long Version (e.g. 1.0.0) and build number (increment each upload)
   - Icons and launch screen (1024x1024 icon without alpha; required images, per docs)
   - Capabilities: target `arm64`; Mobile renderer
   - Privacy: required-reason API declarations; no tracking; no collected data. Add `ITSAppUsesNonExemptEncryption = NO` via additional plist content.
   - Deployment target: at least iOS 13 (Apple), recommend iOS 16 or later for Metal feature coverage (**recommendation, not verified requirement**).
4. **Export** to a folder: avoid spaces in the exported project name (can corrupt the Xcode project, per docs). Result: `.xcodeproj` and a `.pck`.
5. **Open in Xcode.** Per the 4.5 docs, add the exported Godot project folder as a referenced folder (Reference files in place, Create folders) and delete the exported `.pck` entry from the project navigator if that doc procedure applies to 4.6. Verify.
6. **Signing:** Xcode > target > Signing & Capabilities: choose your Team, enable Automatically manage signing (or use a manual profile).
7. **Test on device:** connect an iPhone, select it, Run. The simulator supports only the Compatibility renderer per 4.7 docs; this project uses Mobile, so test on hardware.
8. **Archive:** Product > Destination > Any iOS Device (arm64), Product > Archive.
9. **Validate and Upload:** Organizer > Distribute App > App Store Connect > Upload. Wait for processing and fix any validation errors (missing privacy manifest, wrong icon, SDK too old).
10. **TestFlight:**
    - Internal testing: up to 100 internal members (App Store Connect users); builds are available once processed.
    - External testing: create a group, add testers or a public link, complete Test Information and submit the build for Beta App Review. First external build needs review.
    - Counts and review timing are from memory: **unverified**.
11. **App Store submission:** complete metadata (APP_STORE.md), Age Rating questionnaire, App Privacy answers (Data Not Collected), privacy policy URL, export compliance, pricing, screenshots; select the build; Submit for Review.

## What cannot be done from Linux
- Xcode, signing, provisioning, archive, upload (Transporter/altool requires macOS)
- Device debugging and Instruments profiling
- Metal GPU capture and thermal checks on real hardware
- TestFlight installation
- You can: edit and test the GDScript logic, headless Godot checks, and prepare assets and docs on Linux.

## Device-profiling plan
- Targets: **60 fps** on recent iPhones (current generation and prior two); **30 fps floor** on the oldest supported device.
- Tools: Xcode Instruments (Time Profiler, Metal System Trace, Allocations, Energy Log), Godot's built-in profiler and monitors.
- Thermal: check `ProcessInfo.thermalState` (or Instruments Thermal State) during a 20-minute boss-rush session; target no sustained "serious" state; add a quality-reduction fallback (lower shadow/particle caps, 30 fps cap) on elevated thermal states.
- Memory: stay well under per-app limits on the oldest device (target below 1.5 GB resident; target is a project choice, not an Apple number).
- Checks per build: cold start under 5 s, no frame hitches above 50 ms in boss transitions, battery drain per 30 minutes.

## What is already in this repository
- `export_presets.cfg` contains an **iOS** preset: bundle id `com.hollowreign.game` (placeholder), arm64, min iOS 15.0, iPhone + iPad, icon `assets/icons/icon_1024.png`, tracking disabled, launch background near-black. `application/app_store_team_id` is empty and must be filled in.
- The preset was written by hand on Linux using the option names found in the Godot 4.6 binary; it has **not** been opened in the Godot editor on a Mac or exported. On first open, check the Export dialog for warnings and re-save.
- The `privacy/*_access_reasons` values are left at 0 (none selected). Godot itself touches file timestamps, disk space, system boot time and user defaults, so tick the matching reasons in the Export dialog (it shows them as checkboxes) before uploading, or App Store Connect will flag the missing privacy manifest entries.
- `project.godot` sets landscape orientation, the Mobile renderer and ETC2/ASTC texture compression.
- No iOS build has been produced. That needs a Mac with Xcode and an Apple Developer account.

## Quick start: first build on your own iPhone, before the developer account is approved (added 2026-11-26)
A free Apple ID "Personal Team" in Xcode can install to your own phone (the app expires after 7 days; TestFlight and the App Store need the paid programme). Not yet tried by anyone on this project.
1. Mac: `sudo xcodebuild -license accept` (done 2026-11-26), open Xcode once, install the iOS platform, Xcode > Settings > Accounts > add your Apple ID.
2. iPhone: connect by cable, Trust, then Settings > Privacy & Security > Developer Mode > on, restart.
3. Install Godot 4.6 (standard) and its export templates (Editor > Manage Export Templates).
4. `git clone -b claude/hollow-reign-game-dev-srhrwr https://github.com/markusbrown123/auto.git`, open `auto/hollow-reign/project.godot` in Godot and let it import (several minutes the first time).
   Preferred since 2026-11-27 (an editor crash was reported during the first import on a Mac): import without the editor window first. In Terminal, `cd auto/hollow-reign && tools/mac_import.sh` (pass the path to Godot.app if it is not in /Applications). It runs the headless import twice and reports how many `.import` files this Mac changed; that number should be 0. Then open the project. When updating an existing clone: in GitHub Desktop discard all local changes first (they are Godot's own rewrites), pull, delete the hidden `hollow-reign/.godot` folder, run the script again.
   Texture import settings are frozen in the repository (compressed, mipmapped, automatic 3D detection off), so the editor should never rewrite an `.import` file. If GitHub Desktop shows changed `.import` files after opening the project, report which ones.
   `marketing/`, `art/` and `shots/` carry a `.gdignore`: Godot does not import screenshots, recordings or source art.
5. The purchased animation source files are not needed to build: the baked library `assets/anim/humanoid.res` is in the repository.
6. Project > Export > iOS: set a bundle identifier unique to you (a Personal Team cannot use one already registered), leave Team ID empty for now, Export Project to an empty folder with no spaces.
7. Open the exported `.xcodeproj` in Xcode, target > Signing & Capabilities > Team: your Personal Team, Automatically manage signing. Select the iPhone, Run. On the phone: Settings > General > VPN & Device Management > trust the developer profile.
8. Build only from a commit this project's status file marks as passing all suites.

## First export of the first-boss slice: what was checked from Linux, and what to watch (added 2026-11-27, slice QA)
Nothing below was verified on a Mac, in Xcode or on a phone. "Checked" means read against the Godot 4.6 binary's own option names or measured in the software renderer.

**Checked and set in the repository**
- `export_presets.cfg`: every option name in it exists in the 4.6 editor binary. Name "Hollow Reign" (from `project.godot`), version 0.1.0 (build 1), min iOS 15.0, arm64, iPhone + iPad, icon `assets/icons/icon_1024.png` (1024 x 1024, RGB, no alpha; the file exists).
- Required-reason API declarations are now filled in (they were 0): file timestamp `C617.1`, system boot time `35F9.1`, disk space `E174.1`, user defaults `CA92.1`. These are the reasons that fit an engine reading and writing its own save files. Confirm the four boxes are ticked in Project > Export > iOS > Privacy when the preset is first opened; if Godot shows them unticked, tick them.
- `ITSAppUsesNonExemptEncryption = false` is in `application/additional_plist_content` (the export-compliance question is then not asked on every upload).
- Orientation: `window/handheld/orientation=4` (sensor landscape: both landscape ways, never portrait). Stretch `canvas_items` / `expand` on a 1280 x 720 reference: the UI was captured at 1560 x 720 (19.5:9) and at 2532 x 1170 and 2796 x 1290 window sizes.
- Safe area: menus, the duel HUD, the road and the sanctuary take their margins from `DisplayServer.get_display_safe_area()` (`UI.safe_margins`). SKIP on the story scenes now does too. On a desktop the insets can be faked: `-- --notch=87,0,87,39` (left, top, right, bottom in 720-high units; these are an iPhone 14's 47 pt sides and 21 pt bottom).
- Graphics preset: a phone or tablet starts on **Performance** the first time (`Game.default_quality`); Settings offers Balanced and High. Frame cap 60 with vsync on; the 120 option exists in Settings.
- Touch: `emulate_mouse_from_touch` is on (the engine default), which is what lets a finger press buttons; `emulate_touch_from_mouse` is on for desktop testing and does nothing on a phone. Low-processor mode is off. Audio output latency is the engine default (15 ms).
- A fight pauses itself when the app loses focus or is sent to the background (a call, the notification shade, the app switcher): `main.pause_fight()`. This only runs on a phone and has not been seen working on one.
- Textures: all 337 model textures that were stored lossless (and so sat uncompressed in video memory) are now imported VRAM-compressed, as the knights' already were. On export for iOS they are ETC2 (`import_etc2_astc`; ASTC only for textures marked high quality, none are). Video memory in the Courtyard duel fell from 339 MB to 148 MB in the software renderer. Floors (`assets/textures`) and the engraving sheets (`assets/models/gear/tex`) are still lossless because custom shaders sample them; that is about 20 MB.
- Filmed road and the cinematic duel (Theora, `assets/video/*.ogv`, 110 MB) are off by default (`cine_road`, `cine` under Settings > In testing).

**Watch for on the first export**
1. The first import on the Mac recompresses 427 textures: several minutes, and the editor may look frozen.
2. App size. `export_filter="all_resources"` ships everything under `assets/`: about 1.2 GB of models before compression, most of them for regions after the slice. Expect an `.ipa` near or over 1 GB. That is fine for a cable install; it is over the cellular download limit and needs a cut list before TestFlight.
3. Whether Theora video plays on iOS at all is unknown. Leave the two "In testing" switches off on the phone unless that is what is being tested.
4. The name field in character select uses the system keyboard. Whether the keyboard covers the field or the "Choose a Blade" button in landscape is unknown; the name is optional.
5. First-launch shader compilation: each new place may hitch the first time it is shown (there is no shader pre-warm; `shader_baker/enabled` exists in the 4.6 preset options and is worth trying if hitches are bad).
6. Memory: the software renderer reports 127 to 148 MB of video memory in the slice's heaviest scenes after the texture change. ETC2 on the phone will differ. If iOS kills the app in a duel, try Performance first, then report which scene.
7. Triangles: about 400,000 to 500,000 primitives a frame in the Courtyard (shadow pass included). Not reduced in this pass; the first thing to cut if the frame rate is poor is sun shadows on scenery.
8. A journey in progress on a road is not stored: if iOS ends the app while it is in the background, Continue returns to the sanctuary with everything earned kept and the road to walk again (by the Winch Gate once it is open).
9. Haptics, the home-indicator and notch margins, rotation between the two landscape ways, and audio levels have only been checked in code or by meter, never felt or heard.

**The automated run to compare a phone session against**: `docs/FLOW.md`, "The slice, played by touch".
