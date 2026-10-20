# Notes for agents

This checkout targets iPhone and iPad ([docs/IOS.md](docs/IOS.md)). The Mac build stays as the
development host: the run harness, the smokes and the regression run there. There is no Switch build
here; do not add one back.

## Build the iOS app

```sh
export COS_IOS_TEAM=<Apple team id>
scripts/ios/configure.sh                          # build/ios-device (Xcode project)
cmake --build build/ios-device --config Release --target switchwaker
scripts/ios/check-platform.sh                     # the UIKit importer for device and simulator, the plist
```

Without a signing identity, append `-- CODE_SIGNING_ALLOWED=NO` to the build (the app then cannot be
installed). `scripts/ios/configure.sh --simulator` makes the separate simulator project. Prerequisites,
storage paths and the open milestones: [docs/IOS.md](docs/IOS.md).

## Defaults are for the player

A fresh install (no `settings.ini`) must start with player defaults: frame-rate counter and every
diagnostic, perf or capture option off, mods off, no `[dev]` section. A new diagnostic or test option
ships off and goes in the options menu's Depuración section. Check the fresh-install defaults again
whenever the settings code changes; a player's saved `settings.ini` keeps what they chose.

Developer variables without a menu row (`COS_TRACE`, `COS_BOOT_STAGE`, ...) go in the `[dev]` section of
`settings.ini` or the environment ([native/README.md](native/README.md)).

## Mac build

Build the target by name: `cmake --build build/native-mac --target switchwaker`, and check the date of
`build/native-mac/switchwaker` before trusting a run. The default target once left the binary a day old
without an error, and a whole debugging pass compared the old binary with itself.

## Checks

Per change, run the checks that change touches (its build, the affected stages, its own verification).
The full regression (`native/tools/regress.sh`) and the stage sweep (`native/tools/run.sh boot-sweep`) only
at checkpoints (every few integrated changes, or at the end of a phase); bisect if a checkpoint fails.
