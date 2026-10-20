# iOS graphics and mods

The comparison target is [griches/PS5_SwitchWaker](https://github.com/griches/PS5_SwitchWaker),
the GameCube port, rather than the separate Wii U Wind Waker HD port. Most of its
visual and gameplay options already come from the shared SwitchWaker code.

## Controller options menu

After pressing **Play** in the launcher, press the controller's **Back / View /
Select** button at the title screen or during play. A DualSense touchpad click
also opens it. The original L-trigger + R-trigger + right-shoulder combination
and keyboard F1 remain available. The menu blocks game input while it is open;
in a loaded game it also pauses gameplay.

Use the D-pad or left stick to select a row, left/right to change a value, the
shoulder buttons to change tabs, and B or Back to close. Face-button labels can
vary with the controller. Choices are saved in the app's settings file.

| Feature | iOS option / behavior |
|---|---|
| Widescreen camera, culling and HUD | Graphics > Aspect ratio: 16:9 or 16:10; 4:3 is the original. Restart the app after changing it. |
| High-resolution textures | Import an extracted DDS folder through the launcher, then Graphics > HD textures. Runtime toggle; originals remain available. |
| Texture size | Graphics > HD texture max size. Start with 1024; Full uses the pack's largest textures and more memory. |
| Higher internal resolution | Graphics > Internal resolution, through 1440p and 2160p at 16:9. Other aspect ratios have different widths. The default remains 720 lines. |
| Interpolated 60 fps | Performance > 60 fps (interpolation). Game logic stays at 30 fps. |
| Dynamic resolution | Existing graphics option adapts internal resolution; output resolution is managed by iOS rather than PS5 display modes. |
| Community quality-of-life options | Quality of life: the BetterWW preset or individual options, including Swift/Brisk Sail, instant text, faster rolling/climbing/grappling/blocks, fast Ballad travel, no song replays, intro skip, full sea chart and Tingle chests without the Tingle Tuner. |
| Controls | Existing remapping, camera inversion and camera-shake options. |
| Portability fixes | PS5 source safeguards for zero-divisor angle calculations and invalid arctangent-table inputs are included under TARGET_PC. |

The PS5's Vulkan driver, display-output controls, shader caches and x86 exception
handler are platform-specific. iOS uses Metal and its own shader cache. PS5
performance measurements do not establish iPad performance. The optional 4K and
60 fps settings are choices, not measured performance guarantees.

Mods remain off on a fresh install. The resolution default is supplied after
loading saved settings so it does not lock the menu or override a saved choice.

## Import an HD texture pack

1. Obtain a Dolphin DDS pack for GZLE01, such as the Hypatia pack referenced in
   the PS5 port's README. Extract the archive first on a computer. ZIP/7z archives
   and PNG-only packs are not accepted by this importer.
2. Make its `GZL` folder available through Files (for example through iCloud Drive
   or external storage).
3. In SwitchWaker's launcher, tap **Import HD texture folder…** and select `GZL`.
   Selecting its parent folder also works when it contains a `GZL` directory.
4. Keep the app open while it copies. The copied DDS headers are checked before
   replacing the installed folder. Import errors leave the old pack in place.
5. Tap **Play**, press Back at the title screen, and enable **Graphics > HD textures**.

The pack is copied into `Documents/hd_textures`, visible in Files under
**On My iPad > SwitchWaker** (or On My iPhone). `COS_HD_PACK` is resolved to that
container's current path each launch. Saves remain in Application Support.
Do not replace a pack through Files while the game is using it.

Texture packs and controller-symbol overlays are separate downloads from their
authors and are not bundled in this app. To use an optional controller-button
set from the same pack, merge it over `GZL` before importing. Match it to the
controller's actual mapping; the PS5's fixed DualSense mapping is not forced
onto every iOS controller.

There is no general Gecko/PowerPC patch or community mod loader here. The listed
BetterWW-style options are native implementations already in the game code;
additional community mods require individual compatibility work.

## Verification

- UIKit sources compile against device and simulator SDKs; plist syntax passes.
- Filesystem tests exercise the actual importer with first install, re-import,
  nested GZL folders, invalid DDS files, empty folders and symbolic links; rejected
  imports preserve the previous pack and remove staging files.
- Settings tests verify editable platform defaults, saved resolution on relaunch,
  explicit launch overrides and fresh-install mods/diagnostics staying off.
- The imported math safeguards pass AddressSanitizer and UndefinedBehaviorSanitizer
  checks for valid inputs, zero divisors and invalid floating-point inputs.

Actual controller Back input, full texture-pack coverage and performance at the
new resolutions still need an in-game device session. Folder-provider downloads,
low storage and interruption during import also need device testing.
