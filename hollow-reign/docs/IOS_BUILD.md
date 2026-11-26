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
5. The purchased animation source files are not needed to build: the baked library `assets/anim/humanoid.res` is in the repository.
6. Project > Export > iOS: set a bundle identifier unique to you (a Personal Team cannot use one already registered), leave Team ID empty for now, Export Project to an empty folder with no spaces.
7. Open the exported `.xcodeproj` in Xcode, target > Signing & Capabilities > Team: your Personal Team, Automatically manage signing. Select the iPhone, Run. On the phone: Settings > General > VPN & Device Management > trust the developer profile.
8. Build only from a commit this project's status file marks as passing all suites.
