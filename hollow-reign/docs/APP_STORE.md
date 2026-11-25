# Hollow Reign: App Store Guide

Status as of 2026-11-25. Not legal advice. No Apple approval is claimed or implied.

## 1. Requirements

### Xcode / SDK
- Since **28 April 2026**, apps uploaded to App Store Connect must be built with **Xcode 26 or later** using the **iOS 26 / iPadOS 26 SDK** or later. Source: [Apple Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/).
- From **9 September 2026**, iOS/iPadOS apps must **target iOS 13 or later** (same page). Developer forum reports suggest Xcode 26/27 practically support iOS 15+ deployment targets; treat as **unverified**.
- Apple's release feed shows **Xcode 27.2** dated 29 Oct 2026 ([Apple](https://developer.apple.com/news/releases/?id=10292026a)); dates in search results were inconsistent, so **verify at [developer.apple.com/xcode](https://developer.apple.com/xcode/)**. Whether an SDK 27 minimum is announced for 2027 is **unverified** (the upcoming-requirements page listed none).
- Godot 4.6 exports an Xcode project; you build it with whichever Xcode meets the above.

### Review Guidelines (relevant points; read the current text at [developer.apple.com/app-store/review/guidelines](https://developer.apple.com/app-store/review/guidelines/), not fetched this session)
- **4.1 Copycats:** do not copy another developer's app; no impersonating names, icons, or Infinity Blade-style branding.
- **4.2 Minimum functionality:** the game must be a complete, polished experience; a thin demo can be rejected.
- **2.3 Accurate metadata:** screenshots and previews must show actual in-game content; no references to other apps or platforms; no misleading keywords.
- **5.1 Privacy:** privacy policy URL required; data practices must match the App Privacy answers.
- **2.5.x Software requirements:** public APIs only, no downloading executable code, accurate hardware use.
- All of the above are from general knowledge of the guidelines. Numbering/wording is **unverified** this session.

### Privacy manifest (PrivacyInfo.xcprivacy)
- Required since 1 May 2024 to declare approved reasons for required-reason APIs, including those used by third-party SDKs ([Apple](https://developer.apple.com/news/upcoming-requirements/)).
- Categories: file timestamp, system boot time, disk space, user defaults (the key names are in Apple docs: `NSPrivacyAccessedAPICategoryFileTimestamp`, `...SystemBootTime`, `...DiskSpace`, `...UserDefaults`). Reason codes (e.g. `CA92.1` for user defaults, `C617.1` for file timestamps in the app container, `35F9.1` for boot time, `E174.1`/`85F4.1` for disk space) are from memory: **verify in [Apple docs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)**.
- The Godot iOS export template generates a manifest; Godot's export options include privacy entries for these APIs. Confirm in the 4.6 docs (not reachable this session). Declare tracking = false, no collected data types.

### Age rating (updated system)
- Apple updated age ratings; ratings were auto-migrated 31 Jan 2026 and developers must answer the updated questions ([Apple](https://developer.apple.com/news/upcoming-requirements/)).
- Tiers: **4+, 9+, 13+, 16+, 18+** ([Apple age rating values](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions)).
- Cartoon/fantasy violence: infrequent = 9+, frequent = 13+. Realistic violence: infrequent = 13+, frequent = 18+. Prolonged graphic or sadistic realistic violence = Unrated (cannot be published).
- Guidance for Hollow Reign: swordplay against armoured fantasy bosses is **frequent fantasy violence**, so expect **13+**. Keep gore non-lingering and stylised; do not choose realistic violence unless it truly applies. Answer the questionnaire honestly; Apple assigns the final rating. Questionnaire option labels not fully read: **unverified**.

### Screenshots and previews ([Apple spec](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications))
- iPhone: at least one at **1179x2556 or 1206x2622** (portrait) or **2556x1179 / 2622x1206** (landscape). A 6.9-inch size (e.g. 1320x2868) is optional.
- iPad (if supported): **2064x2752 or 2048x2732** (landscape 2752x2064 / 2732x2048).
- Up to 10 per size, JPEG/PNG, no alpha.
- App previews: spec not fetched; typically 15-30 s, H.264 or ProRes, matching screenshot resolution. **Unverified**; check App Store Connect.
- The page mentions an iPhone Duo size becoming required April 2027 for iOS 27.1 SDK; treat as **unverified** and re-check.

### Export compliance
- Hollow Reign is offline and uses no custom or network encryption. Add `ITSAppUsesNonExemptEncryption = NO` to Info.plist (Godot: iOS export option for additional plist content) so the questions are not repeated ([Apple](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)).
- You are responsible for classification; confirm Godot's engine (which may link system TLS/crypto for networking) is covered by the exemption. **Unverified**; confirm in the App Store Connect questionnaire.
- EU: DSA trader status must be set if distributing in the EU ([Apple](https://developer.apple.com/news/upcoming-requirements/)).

## 2. Listing draft (names subject to trademark clearance, see RESEARCH.md)

- **Name:** Hollow Reign (max 30 chars)
- **Subtitle (<=30):** `Dark fantasy boss duels` (23)
- **Promotional text (<=170):** `Swipe to slash. Read the telegraph. Parry, dodge and break monstrous bosses in a dark fantasy duel RPG. Offline, no ads, no in-app purchases.` (~140)
- **Description:**
  > Step into the Fallen Courtyard as the Returned Knight and face rulers who never learned to die.
  >
  > Hollow Reign is a premium dark-fantasy duel RPG built around precise swipe combat. Slash in any direction, parry by swiping against an incoming strike, dodge, and block with a limited shield. Break your foe's posture to open the killing blow.
  >
  > - Six handcrafted boss duels, from the Ashen Sentinel to the Forgotten Monarch
  > - Six haunted regions told through the environment, not exposition
  > - Gear and mastery that reward every victory
  > - Rebirth: carry your legacy into a harder return
  > - Fully offline. No ads, no accounts, no in-app purchases. One price, the whole game.
  >
  > Contains frequent fantasy violence.
- **Keywords (<=100 chars):** `dark fantasy,boss fight,sword,knight,action rpg,duel,parry,soulslike,offline,medieval,slash` (91). Do not include competitor names.
- **Category:** Games > Action (secondary: Role Playing)
- **Price suggestion:** Premium paid, around the USD 4.99 to 6.99 tier. Choose in App Store Connect; test region pricing.
- **What's New (1.0):** `Welcome to the Hollow Reign. Version 1.0: six bosses, six regions, full offline play.`

## 3. Screenshot shot-list (6, landscape)
1. Hero duel: Returned Knight vs Ashen Sentinel, embers, telegraphed overhead strike, caption "Read the telegraph".
2. Swipe-slash trail mid-combo with damage numbers off (clean HUD), caption "Swipe to slash".
3. Perfect parry flash against the Crimson Widow, caption "Parry to break their guard".
4. Posture-break stagger on the Cathedral Beast with execution prompt, caption "Break. Punish. Survive."
5. Gear/mastery screen with armour and greatsword, caption "Forge your legacy".
6. Frozen Citadel wide vista with Frostbound King, caption "Six regions. Six rulers."

Use only real in-game captures (Guideline 2.3). Higgsfield or other generated art is for marketing backplates only and must not be presented as gameplay.

## 4. 30-second app preview storyboard
| Time | Shot |
|---|---|
| 0-3 s | Fog-laden courtyard, knight walks into frame, title card |
| 3-8 s | Ashen Sentinel winds up; slow-mo telegraph; knight dodges |
| 8-14 s | Swipe combo, parry flash, stagger |
| 14-19 s | Cut to Cathedral Beast and Crimson Widow duels, quick cuts |
| 19-24 s | Gear screen, mastery fill, rebirth screen |
| 24-30 s | Forgotten Monarch on his throne, "Hollow Reign" logo, "Offline. No ads." |

All footage must be recorded from the actual build on device.
