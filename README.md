# Color Gate Rush

An original neon arcade game for iPhone. Your orb rushes down a three-lane track. Fly through
gates that match its color, dodge striped barriers, and grab prisms that recolor you mid-run.
Speed and pattern complexity keep rising, so each run is short and tense, and the next one
starts right away.

Built natively with **Swift, SwiftUI and SpriteKit**. It has no third-party dependencies, no
network access, no accounts, no ads and no tracking.

## How to play

| | |
|---|---|
| **Move** | Tap the left or right half of the screen to move one lane (or switch to *Swipe* in Settings). |
| **Gates** | Only pass through a gate whose color *and shape* match your orb. A wrong color ends the run. |
| **Barriers** | Dark, striped blocks marked with an ✕. Avoid them in every color. |
| **Prisms** | Full-width bands. Passing one changes your orb to the prism's color. |
| **Shards** | Collect them for points and currency to unlock cosmetics. |
| **Shields** | Rare hexagon pickups. A shield absorbs one mistake. |

Every color has its own shape (Crimson ▲, Amber ●, Lime ■, Azure ◆, Violet ★). The orb shows
its current shape, so you never have to rely on hue alone. **Color assist** in Settings also
prints the color name on each gate.

### Scoring

Scoring is implemented in `ScoreRules` (`Packages/ColorGateRushCore/Sources/ColorGateRushCore/Scoring.swift`):

- Matching gate: `10 × multiplier`, where `multiplier = min(5, 1 + combo / 8)` (x2 at a combo of 8, x3 at 16, and so on up to x5).
- Shard: +5. Prism: +2. A shield picked up while you already hold one: +25.
- Every 25 gates in a run: +100 milestone bonus.
- Any hit resets the combo.
- Shards banked at the end of a run = shards collected + 1 per 250 points.

### Difficulty tiers

| Tier | Starts at | Colors | Notes |
|---|---|---|---|
| Warm-Up | 0 m | 2 | Wide spacing, no barriers inside gate rows |
| Rush | 350 m | 3 | Barriers can appear in gate rows |
| Overdrive | 1000 m | 4 | Longer gate runs, more double barriers |
| Hyper | 2000 m | 5 | Exactly one matching lane per gate row |
| Prismatic | 3500 m | 5 | Densest patterns |

Speed rises smoothly from 9 to a cap of 17.5 units/s. Row spacing falls from 1.15 s to a floor
of 0.56 s.

**Fairness guarantee.** The generator (`PatternGenerator`) enforces an invariant: from every
lane that is safe in one row, at least one safe lane in the next row can be reached in the time
available. That time budget assumes a 0.30 s reaction plus 0.14 s per lane switch. A player who
survives a row can therefore always survive the next one. Tests check this property across 60
seeds × 700 rows, using real speeds. A look-ahead bot also plays five seeds for 5½ minutes each,
far enough to reach the Prismatic tier.

## Features

- Full game loop with no placeholder screens: home → (first-run tutorial) → countdown →
  gameplay → results → retry, home, or cosmetics.
- Interactive tutorial with nine scripted rows, one rule per row. Mistakes are forgiven, and
  you can replay it from Settings.
- Pause and resume, with a short countdown before play continues. The game pauses itself when
  the app goes to the background, and a SpriteKit auto-unpause can't restart it by accident.
- Restart and quit both ask for confirmation. An abandoned run is never recorded, so it can't
  be used to farm rewards.
- Progression stored on the device:
  - Best score, distance and combo; highest tier; lifetime totals; the last 10 runs.
  - 15 achievements with shard rewards.
  - 17 cosmetics: 8 orb skins, 5 trails and 4 themes, 14 of them unlockable with shards.
- Each run's rewards are applied exactly once (keyed by run ID), and purchases check ownership
  and affordability, so double rewards and double spending can't happen.
- Pseudo-3D perspective rendering:
  - Textures are drawn procedurally with Core Graphics, so the game ships no image assets.
  - Row nodes and popups are pooled.
  - Particle trails, bursts, shockwaves, banners, a light screen shake and speed lines.
- Audio is synthesized at launch: 13 effects, combo-pitched gate chimes, and an 8-bar music
  loop. It uses the `.ambient` category, handles interruptions, and has music and effects
  toggles plus volume controls.
- Haptics for meaningful moments only, with a toggle.
- Accessibility:
  - Shape-coded colors and the Color assist mode.
  - A Reduce motion setting that removes the screen shake and speed lines, and calms the
    menu animations.
  - VoiceOver labels on the controls and the HUD.
  - Large touch targets.
- Save data loads defensively. Missing or invalid fields fall back to safe values.
  Unreadable data is backed up rather than deleted, and the app starts with a fresh profile.

## Project layout

```
ColorGateRush/                 iOS app (SwiftUI + SpriteKit)
  App/                         entry point, AppModel (navigation + progression), themes
  Game/                        GameScene (rendering/input), GameController, RowNode, TextureFactory
  Services/                    AudioManager (synth), HapticsManager
  Views/                       Home, Game HUD/Pause, Results, Style (cosmetics), Progress, Settings
  Resources/                   Asset catalog (app icon), privacy manifest
  Info.plist
Packages/ColorGateRushCore/    Platform-independent rules + XCTest suite (SwiftPM)
  Sources/…                    GameSession, PatternGenerator, Difficulty, Scoring, Progression,
                               Profile, ProfileStore, TutorialScript, Autopilot, SeededRandom
ColorGateRushUITests/          XCUITest smoke tests (navigation, pause, results, retry)
project.yml                    XcodeGen spec (the .xcodeproj is generated, not committed)
scripts/make_icon.py           Regenerates the app icon
scripts/ci/                    Simulator picker, IPA packaging/verification, signing/export
.github/workflows/             core-tests.yml (Linux + macOS), ios.yml (build, test, IPA, release)
```

The app target compiles the core sources directly. The Swift package exists so the rules can be
tested with `swift test` on any platform.

## Requirements

- Xcode 16 or later (CI uses the runner's default Xcode). The deployment target is **iOS 16.0**, iPhone only, portrait.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Python 3 with Pillow, but only if you want to regenerate the icon.

## Build and run

```bash
brew install xcodegen
xcodegen generate
open ColorGateRush.xcodeproj
```

In Xcode, select the **ColorGateRush** scheme and an iPhone simulator, then press Run. To run on
your own iPhone, set your team under *Signing & Capabilities*. If `com.surproductions.colorgaterush`
isn't available to your team, change the bundle identifier as well.

## Tests

```bash
# Game rules (works on macOS or Linux)
cd Packages/ColorGateRushCore && swift test

# UI smoke tests on a simulator
xcodegen generate
xcodebuild test -project ColorGateRush.xcodeproj -scheme ColorGateRush \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

Debug builds accept a few launch arguments for QA:

| Argument | Effect |
|---|---|
| `-CGRResetProfile YES` | Start with a fresh profile |
| `-CGRSkipTutorial YES` | Mark the tutorial as done |
| `-CGRGrantShards N` | Give at least N shards |
| `-CGRStartScreen game\|tutorial\|cosmetics\|progress\|settings` | Open straight to a screen |
| `-CGRAutopilot YES` | Let the look-ahead bot play |
| `-CGRSeed N` | Use a fixed course seed |
| `-CGRDebugOverlay YES` | Show tier, speed, seed and node count |

Release builds compile all of these out.

## Creating an IPA

### With GitHub Actions (recommended)

The **iOS Build** workflow runs on every push. It does the following:

1. Runs the core tests.
2. Runs the UI tests on a simulator and saves screenshots.
3. Runs a smoke test on a small-screen iPhone SE.
4. Archives a **Release build for real devices** (`generic/platform=iOS`).
5. Packages and verifies `Color-Gate-Rush.ipa`, checking the platform, arm64, the bundle ID,
   the version and the signature.
6. Uploads all of the above as a workflow artifact.

To publish a GitHub Release with the IPA attached, push a tag:

```bash
git tag v1.0.1 && git push origin v1.0.1
```

You can also run the workflow manually with **publish_release** checked.

### Signing

Without signing secrets the workflow produces an **unsigned** device IPA, and both the logs and
the release notes say so. iOS will only install it after you re-sign it, for example with
AltStore or Sideloadly using your own Apple ID, or with your developer certificate.

To have CI produce a **signed** IPA, add these repository secrets (Settings → Secrets and
variables → Actions). Never commit them.

| Secret | Value |
|---|---|
| `IOS_CERTIFICATE_P12_BASE64` | `base64 -i cert.p12` of your Apple Distribution (or Development) certificate with its private key |
| `IOS_CERTIFICATE_PASSWORD` | The .p12 password |
| `IOS_PROVISIONING_PROFILE_BASE64` | `base64 -i profile.mobileprovision` for the app's bundle ID |
| `IOS_TEAM_ID` | Your Apple Developer Team ID |

There are also two optional repository *variables*. `IOS_EXPORT_METHOD` takes `ad-hoc` (the
default), `development` or `app-store`. `IOS_BUNDLE_ID` sets the bundle ID if your profile
uses a different one.

Which devices can install the result depends on the method:

- **Ad Hoc:** devices registered in the profile.
- **Development:** your development devices.
- **App Store:** upload it to App Store Connect / TestFlight. That upload isn't automated.

### Locally

```bash
xcodegen generate
xcodebuild archive -project ColorGateRush.xcodeproj -scheme ColorGateRush -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/ColorGateRush.xcarchive \
  DEVELOPMENT_TEAM=<YOUR_TEAM_ID>
xcodebuild -exportArchive -archivePath build/ColorGateRush.xcarchive \
  -exportOptionsPlist <your ExportOptions.plist> -exportPath artifacts/
```

## Privacy

All data stays on the device in `UserDefaults`. The app makes no network calls, collects no
data and uses no tracking SDKs. `PrivacyInfo.xcprivacy` declares only the UserDefaults API, with
reason `CA92.1`.

## Known limitations

- CI produces an unsigned IPA until signing secrets are added (see above).
- The game is offline only: no cloud sync, leaderboards or Game Center.
- It is portrait and iPhone only. iPad runs the iPhone layout.
- Frame rate has been checked only in the iOS Simulator. Real-device performance hasn't been
  profiled in CI.
