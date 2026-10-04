# Hive Strike

An original insect-themed fixed shooter for Apple TV (tvOS 16+), written in Swift + SpriteKit.
All artwork is drawn in code and all audio is synthesized at launch - no third-party or ripped assets.

## Folder layout
- `Sources/`       Swift source (App, Game, Art, Sound, Input)
- `project.yml`    XcodeGen spec; `HiveStrike.xcodeproj` is generated from it
- `Assets.xcassets/` tvOS layered app icon + Top Shelf images
- `icon/`          standalone icons: `HiveStrike_rounded_1024.png`, `HiveStrike_square_1024.png`, `HiveStrike.icns`, `tvOS/` layers and banners
- `art/`           dump of every in-game sprite (PNG, 2x)
- `make_icon.py`, `make_app_icon.py`   icon/artwork generators (Pillow)
- `dist/`, `logs/`  local build output (git-ignored; created when you build)

## Build
    brew install xcodegen
    xcodegen generate
    # simulator
    xcodebuild -project HiveStrike.xcodeproj -scheme HiveStrike -sdk appletvsimulator -configuration Release \
      -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
    # device (needs a signing team; set DEVELOPMENT_TEAM in project.yml)
    xcodebuild -project HiveStrike.xcodeproj -scheme HiveStrike -sdk appletvos -configuration Release \
      -destination 'generic/platform=tvOS' -allowProvisioningUpdates -derivedDataPath build-dev build
    xcrun devicectl device install app --device <UDID> build-dev/Build/Products/Release-appletvos/HiveStrike.app

## Notes
- Bundle ID in `project.yml` is `com.jnaina.pulstar` (reused so it installs without a new App ID).
- Launch arguments: `-autoplay` (AI plays), `-fps` (show resolution/FPS), `-dumpart` (export sprites).
- Controls: left stick/D-pad move; Fire and Bomb are remappable in Controls (A,B,X,Y,L1,R1,L2,R2); Menu = pause/back; Siri Remote supported.
- Rendering: 1920x1080 point scene at 2x (3840x2160 on a 4K output), 60 fps, pooled sprites, one runtime texture atlas.

## Signing
The Apple team ID is intentionally blank. To build for a device, either set `DEVELOPMENT_TEAM` in `project.yml` (then run `xcodegen generate`) or append `DEVELOPMENT_TEAM=<your team id>` to the `xcodebuild` command line. Simulator builds need no signing (`CODE_SIGNING_ALLOWED=NO`).
