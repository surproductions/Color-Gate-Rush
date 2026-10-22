# Release report: Color Gate Rush v1.0.0

## Source
- Repository: https://github.com/surproductions/Color-Gate-Rush
- Release commit: `41650cdc051652538e09fc6d6a2ccbc4fd897b4a` on `main`
- Release: https://github.com/surproductions/Color-Gate-Rush/releases/tag/v1.0.0
- Built by GitHub Actions run #8 (https://github.com/surproductions/Color-Gate-Rush/actions/runs/39787431088), a `workflow_dispatch` with `publish_release`

## Build & test results (run #8, macos-15 runner, Xcode default, iOS 18.5 SDK)
- Core unit tests (`swift test`): 37 passed, 0 failed. The same suite also passes on Linux (swift:5.10).
- UI tests (XCUITest, iPhone 16 simulator, iOS 26.2): 5 passed. They cover:
  - the home screen
  - tutorial → pause → resume → quit
  - 12 s of autopilot gameplay
  - a manual run ending on results, then retry
  - the Style, Progress and Settings menus
- iPhone SE (3rd generation) simulator smoke test: home screen, plus 15 s of autopilot gameplay with the app still running.
- Release archive for `generic/platform=iOS`: succeeded, with no Swift compiler warnings.

## IPA
| | |
|---|---|
| File | `Color-Gate-Rush.ipa` |
| Size | 850,744 bytes |
| SHA-256 | `c7bd2891a30e343a040c9ae4c029a91def9c8c8bbb8005d3b5b490bae73c51a2` |
| Bundle ID | `com.surproductions.colorgaterush` |
| Version | 1.0.0 (8) |
| Platform / arch | iphoneos / arm64, minimum iOS 16.0 |
| Signing | **Unsigned.** The repository has no signing secrets configured. |

I downloaded the IPA from the public release URL and confirmed its SHA-256 matches. It is a valid zip, and its `Info.plist` has the expected bundle ID, version and platform.

## Not verified
- Installation on a physical device. The IPA is unsigned, and no device was available.
- Frame rate on real hardware.

## To get a device-installable build
- Either add the signing secrets described in the README and run the **iOS Build** workflow with `publish_release`,
- or re-sign this IPA yourself (AltStore, Sideloadly, or your Apple Developer certificate).
