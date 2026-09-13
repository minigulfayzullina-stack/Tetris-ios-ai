# Tetris (iOS, SwiftUI)

A complete, dependency-free Tetris for iPhone and iPad, written in Swift.
Builds into a real `.ipa` on GitHub Actions — no Mac required locally.

<img width="0" height="0" alt="" src="">

## Features

- 10 × 20 playfield rendered with SwiftUI
- All seven tetrominoes, rotated inside a shared 4×4 bounding box
- **7-bag randomiser** so droughts never drag on
- Ghost piece showing where the current piece will land
- Wall kicks, so rotating against a wall nudges instead of refusing
- Soft drop, hard drop, pause, restart
- Scoring (1/2/3/4 lines = 100/300/500/800, scaled by level) and 20 levels
- 7-segment "next piece" preview
- Touch controls plus board gestures:
  - swipe left / right → move
  - swipe down → hard drop
  - swipe up or tap → rotate

## Layout

```
project.yml                    XcodeGen spec — generates Tetris.xcodeproj
Sources/
  TetrisApp.swift              @main entry point
  Models/
    GridPoint.swift            one cell coordinate
    Tetromino.swift            the seven shapes + rotation
    GameState.swift            board, gravity, scoring, rules
  Views/
    GameView.swift             screen layout, overlays, gestures
    BoardView.swift            the playfield
    NextPieceView.swift        upcoming-piece preview
    ControlsView.swift         on-screen buttons
    PieceType+Color.swift      shape colours (view layer only)
Assets.xcassets                asset catalog
ci/ExportOptions.plist         export settings for signed builds
ci/build-ipa.sh                the actual build (XcodeGen, sign, archive, export)
Tools/linux-rules-check/       runs the rule checks without Xcode
.github/workflows/ios-ipa.yml  thin CI wrapper that calls ci/build-ipa.sh
```

The project is defined by `project.yml` rather than a committed
`project.pbxproj`. That keeps diffs readable and means the Xcode project can
always be regenerated:

```sh
brew install xcodegen
xcodegen generate
open Tetris.xcodeproj
```

## Getting the `.ipa`

Push to `main`, or run **Actions → Build iOS IPA → Run workflow**. Either way
the `.ipa` ends up in the run's **Artifacts** section.

The build logic lives in `ci/build-ipa.sh` so it can also be run by hand on any
Mac:

```sh
ci/build-ipa.sh
```

### Unsigned (works right now)

With no signing secrets configured, the workflow compiles the app and packages
`Tetris-unsigned.ipa`. This proves the code builds, but it will **not** install
on a stock iPhone — it has to be re-signed first:

- **Sideloadly** or **AltStore** re-sign it with your Apple ID (a free account
  works, but those installs expire after 7 days), or
- install it on a jailbroken device that accepts unsigned binaries.

### Signed (directly installable)

Requires a paid Apple Developer Program membership ($99/yr). Add these secrets
under **Settings → Secrets and variables → Actions**:

| Secret | Where it comes from |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | Export your certificate from Keychain Access as `.p12`, then `base64 -i cert.p12 \| pbcopy` |
| `P12_PASSWORD` | The password you chose when exporting the `.p12` |
| `PROVISIONING_PROFILE_BASE64` | `base64 -i Tetris.mobileprovision \| pbcopy` |
| `KEYCHAIN_PASSWORD` | Any throwaway string |
| `APPLE_TEAM_ID` | 10-character Team ID from developer.apple.com |

The bundle identifier is `com.minigulfayzullina.tetris` (set in `project.yml`)
— change it to match your provisioning profile if it differs. For
`development` and `ad-hoc` exports your device UDID must be in the profile.

Export methods, selected by the `export_method` input:

| Method | Installs on | Needs |
|---|---|---|
| `development` | Registered devices | Development cert + profile with UDIDs |
| `ad-hoc` | Up to 100 registered devices | Distribution cert + ad-hoc profile |
| `app-store` | TestFlight / App Store | Distribution cert + App Store profile |
| `enterprise` | Any device, internal use | Apple Developer Enterprise Program |

## Cost

- **Public repos:** macOS runner minutes are free.
- **Private repos:** macOS bills at **10×**, so the free tier's 2,000 min/month
  is about 200 macOS minutes. A run here takes 5–15 minutes.

## Verifying the rules without Xcode

The game rules deliberately live in `Sources/Models/` and import nothing
Apple-specific (`GameState` needs only `Combine` for its published
properties, and the colours live in the view layer). That makes them
compilable and testable with the open-source Swift toolchain on Linux, which
is how the logic was validated: 93 checks covering movement, rotation, wall
kicks, collision, line clearing, scoring, level clamping, ghost placement,
game-over detection and restart — including a full 1000-piece game played by a
placement heuristic.

Reproduce it with any Swift toolchain:

```sh
Tools/linux-rules-check/run.sh
```

It copies `Sources/Models/` into a temp directory (stripping only the
`import Combine` line, which `Stubs.swift` replaces), compiles, and runs. The
game sources themselves are never modified.

## Notes and limitations

- No app icon yet; `ASSETCATALOG_COMPILER_APPICON_NAME` is empty on purpose to
  avoid a build warning. Add an `AppIcon` set and set that key to `AppIcon`
  before shipping to the App Store.
- Portrait only on iPhone (see the `INFOPLIST_KEY_...` entries in
  `project.yml`).
- The UI itself is only compiled on macOS; the Linux harness covers the rules,
  not the SwiftUI layout.
