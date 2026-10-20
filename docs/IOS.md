# iPhone and iPad port (in progress)

Target: iOS / iPadOS 27, iPhone 15 Pro and newer, and M4 iPad Pro. The
game is compiled natively for ARM64; no CPU JIT entitlement or JIT-enabling tool
is needed. Shader compilation still takes place in Dawn/Metal.

## Current implementation

- A CMake iOS app target (`ios/`) shared by iPhone and iPad, with separate device
  and Apple silicon simulator build directories.
- SDL's iOS entry point with an explicit scene manifest, followed by a UIKit disc
  importer and an explicit Play action. The importer uses the connecting window
  scene even before it becomes foreground-active.
- The importer accepts a user-selected file, validates the GameCube magic, disc ID
  (`GZLE01`) and disc/revision bytes, then copies through a temporary file before
  replacing the previous import. It uses security-scoped access and file coordination
  for Files providers. Header validation is preliminary; the runtime performs its
  own additional disc/asset checks. Cancelling leaves the launcher available.
- The imported disc lives in Documents/GZLE01.iso. Saves/settings live in
  Library/Application Support/SwitchWaker; disposable shaders live in
  Library/Caches/SwitchWaker. Paths are resolved on every launch, since an app's
  container path can change. Files sharing exposes Documents, not the save folder.
- Metal selected on first launch, with a default internal scale of 1.5 (720 lines).
- Source dependency providers instead of incompatible macOS ARM64 archives;
  host pkg-config lookup disabled so Homebrew libraries cannot enter the app.
- Dawn's Protobuf/IR serialization tools, Tint executables/tests and desktop GLFW
  helpers disabled. The Metal runtime does not need these; cross-compiling the
  Protobuf tools otherwise requires a separate macOS `protoc` executable.

**This is not a verified playable iOS build.** The importer compiles against both
iOS 27 SDKs. The full Release device app now configures, compiles and links,
including Dawn/Metal, SDL3, Aurora and the iOS Rust disc library. Boot, rendering,
audio, controller input and suspend/resume still require validation. Touch controls are
not implemented; the first playable milestone will require a controller. Device
requirements in the plist select ARM64 and Metal, not a specific iPhone generation.

Verified artifact: `build/ios-device/Release/switchwaker.app`, with a
22 MiB ARM64 executable targeting iOS 27.0 and both iPhone/iPad device families.
Development signing, installation and launch on the M4 iPad Pro are verified;
the importer is visible in `build/ios-importer-ipad.png`. Initial black-screen
startup was caused by the missing scene manifest: SDL chose its scene delegate
but never received a scene connection to call the application entry point.
Local logs: `build/ios-resume-configure.log`, `build/ios-resume-build.log`, and
`build/ios-resume-platform.log`. The simulator importer compiles, but the complete
simulator app has not been built or launched.

Xcode uses separate device/simulator build trees without platform suffixes.
Dawn's object-only bundle receives an anchor source so Xcode emits its archive.
The game link list is generated after compilation from source dependencies,
preserving main.dol → REL → audio order and resolving Xcode's hashed filenames
for duplicate source basenames (`native/tools/xcode_objects.py`).

## Build prerequisites

Use Xcode with the iOS 27 SDK and CMake 3.28 or newer, Ninja, Python 3.10+
and curl on an Apple silicon Mac. The configure script creates `build/ios-python` and installs
PyYAML there without modifying Homebrew Python. Dawn, SDL, nod and the other Aurora dependencies
must be available from the network on the first configuration. Source-building
nod requires the appropriate Rust target (`aarch64-apple-ios` for devices,
`aarch64-apple-ios-sim` for the simulator). The script downloads the official
rustup installer from static.rust-lang.org and maintains a private stable Rust
toolchain in `build/ios-rustup`, with Cargo in `build/ios-cargo`. It installs the
target standard library automatically; Homebrew Rust alone only supplied macOS
libraries on the development machine. It does not modify shell profiles or the
global Rust installation. Corrosion receives the explicit target and compiler.
The Rust/Aurora iOS integration now compiles and links. Do not substitute
a darwin-arm64 macOS archive. Compressed disc formats are disabled in this app.

```sh
# From the repository, with prerequisites installed:
export COS_IOS_TEAM=YOUR_APPLE_TEAM_ID
scripts/ios/configure.sh
open build/ios-device/SwitchWakerIOS.xcodeproj
```

In Xcode choose `switchwaker`, your signing team, and the attached iPhone/iPad.
The bundle ID defaults to `com.dnlflores.switchwaker`; override with
`scripts/ios/configure.sh -DCOS_IOS_BUNDLE_ID=your.unique.identifier`.
The app uses automatic development signing and no JIT entitlements.

```sh
cmake --build build/ios-device --config Release --target switchwaker
# Compile/link without a signing identity (cannot install this unsigned app):
cmake --build build/ios-device --config Release --target switchwaker -- \
  CODE_SIGNING_ALLOWED=NO CLANG_MODULE_CACHE_PATH="$PWD/build/ios-module-cache"
# Separate simulator project, not a performance substitute for a device:
scripts/ios/configure.sh --simulator
```

Runtime asset stubs are generated without game data. On device, import your own
USA revision 0 uncompressed ISO/GCM through Files. Compressed RVZ/CISO images
are unsupported. No disc is bundled or uploaded by these scripts.

## Checks and next milestones

`scripts/ios/check-platform.sh` checks Objective-C++ compilation for device and
simulator, plus plist syntax, without fetching dependencies. This does not link
or launch the game.

1. Verify installation and importer launch on iPhone (M4 iPad launch verified).
2. Test import/cancel/re-import, invalid/compressed/wrong-version files, cloud
   providers, low storage, relaunch, and save persistence on iPhone and iPad.
3. Boot to title with Metal, audio and a controller; inspect shader compilation,
   memory, frame pacing and actual internal resolution on A17 Pro and M4.
4. Handle and test background/foreground transitions, audio interruptions,
   controller reconnection, rotation and iPad resizing. Verify saves on interruption.
5. Add touch controls and finish app packaging after the native game boots.

The Mac build remains the development host; the Switch build was removed from this checkout. The native response file is
now per configuration for Xcode; macOS package selection and symbol census are
restricted to Darwin rather than every Apple operating system.
