# SwitchWaker

## What it is

SwitchWaker is an unofficial native port of a 2002 GameCube adventure game (disc ID `GZLE01`, USA,
revision 0, the reference; and `GZLP01`, Europe, revision 0, with its five languages) to iPhone and
iPad (in progress), the Mac and Linux. The game is compiled from its decompilation
(the [`game/`](game/README.md) folder) and drawn with [Aurora](https://github.com/encounter/aurora);
there is no CPU emulation.

## Standing on the shoulders of others

SwitchWaker would not exist without these projects. The hard part, understanding the game, is
their work; this repository adds the layer that runs it on new hardware.

- **[zeldaret/tww](https://github.com/zeldaret/tww)**: the community decompilation of the game.
  The careful, byte-for-byte matching work of its contributors produced almost all of the code in
  [`game/`](game/README.md). Without it there is nothing to port.
- **[snrubrm/tww](https://github.com/snrubrm/tww)**: a personal fork of zeldaret/tww that completes
  the functions still missing, with AI-assisted decompilation (in its author's words). `game/` was
  imported from it; units that zeldaret has since matched are taken from zeldaret again.
- **[encounter/aurora](https://github.com/encounter/aurora)**: the GameCube SDK reimplemented over
  WebGPU (Dawn), which draws the game and reads the controllers on every platform.
- **[Dusklight](https://github.com/TwilitRealm/dusklight)** (TwilitRealm): the native port of a
  sibling game on Aurora; the model for this project's SDK layer, and CC0 helper code.
- **[BetterWW](https://github.com/WideBoner/betterww)** (WideBoner) and
  **[wwrando](https://github.com/LagoLunatic/wwrando)** (LagoLunatic; with brainfubar, MelonSpeedruns
  and JarheadHME): the options menu's "Calidad de vida" (quality of life) options are derived from
  their patches ([docs/QOL_PLAN.md](docs/QOL_PLAN.md)).
- **[Dolphin](https://dolphin-emu.org)**: its DSP HLE plays the game's audio (`native/dsp_hle/`, GPL).
- **[elliotttate/Wind-Waker-Recomp](https://github.com/elliotttate/Wind-Waker-Recomp)** and
  **[RecompCore](https://github.com/elliotttate/RecompCore)**: the static recompilation this work
  started from, and the DSP adapter.

If you enjoy this port, the decompilation projects above are where the credit belongs. Every
component and its license: [THIRD_PARTY.md](THIRD_PARTY.md).

## How it was made: AI use

Be aware of this before you use or build on this repository:

- **This project's own code was written with AI.** Nearly all of the code outside `game/` (the SDK
  layer, the run harness, the Switch platform layer, patches, tools and scripts), the documentation
  and the commit messages were written by an AI coding agent, Anthropic's Claude through Claude
  Code. The human authors chose what to build, set the priorities, reviewed the code line by line,
  played and tested it on the Mac and on a real Switch, reported the bugs and decided what went in.
  Commits written with the agent say so in a `Co-Authored-By: Claude` line.
- **Part of the decompilation is AI-assisted too**: the functions snrubrm/tww completed (see
  above). The rest of `game/` is zeldaret's human work. If you want only human-written
  decompilation, use [zeldaret/tww](https://github.com/zeldaret/tww).
- **How it is checked**: human review of the code, line by line, plus builds on every platform, a
  regression suite of boot milestones and smoke tests, automated sweeps over every stage, room,
  actor, event, item and boss (also under AddressSanitizer), and play on hardware
  ([native/README.md](native/README.md)). Bugs can still slip through; reports are welcome.

## What you need

- **Your own legally obtained copy of the disc**: `GZLE01` (USA) or `GZLP01` (Europe) revision 0, as
  an uncompressed `.iso`. The build generates what it needs from it. The version is fixed at build
  time: the European disc needs the European build (below).
- **This repository contains no game assets, executables or data.** The binaries you build contain
  code generated from your disc: they are for your own use only; do not share them.
- **No release binaries are provided** for now, precisely because they carry headers generated
  from the disc compiled in.

## Build on the Mac (Apple silicon)

Requirements: Xcode command line tools, `brew install cmake ninja python` (Python 3.10 or newer)
and the network the first time.

```sh
git clone https://github.com/centollOS/SwitchWaker switchwaker && cd switchwaker
export COS_DISC=/path/to/GZLE01.iso          # every script and the game read the disc from here
native/tools/fetch_recompcore.sh             # ref/recompcore: Dolphin's DSP HLE (audio)
native/tools/gen_assets.sh                   # build/native-mac/assets/GZLE01: headers from your disc
cmake -S native -B build/native-mac -G Ninja
ninja -C build/native-mac switchwaker          # build/native-mac/switchwaker
build/native-mac/switchwaker                   # a 960x720 window
```

Details, run options and tests: [native/README.md](native/README.md). Full regression:
`native/tools/regress.sh`.

**The European disc** (`GZLP01`) is a separate build directory with `-DCOS_VERSION=3`
([docs/PAL_DISC_PLAN.md](docs/PAL_DISC_PLAN.md)); its language follows the system's (English, German,
French, Spanish or Italian), `COS_GAME_LANGUAGE=en|de|fr|es|it` or the options menu fixes one:

```sh
export COS_DISC=/path/to/GZLP01.iso
native/tools/gen_assets.sh --version GZLP01   # build/native-mac/assets/GZLP01
cmake -S native -B build/native-mac-eur -G Ninja -DCOS_VERSION=3 \
    -DCOS_ASSETS_DIR=$PWD/build/native-mac/assets/GZLP01
ninja -C build/native-mac-eur switchwaker
COS_BUILD_DIR=build/native-mac-eur native/tools/regress.sh   # the tools take the build directory
```

## Build on Linux (x86_64 or aarch64)

Requirements: clang (GCC is untested), CMake 3.28 or newer, Ninja, Python 3.10 or newer, git, and the
development headers SDL 3 needs for its video and audio backends; at run time a Vulkan driver
(any GPU's, or Mesa's). On Debian 13 / Ubuntu 24.04:

```sh
sudo apt install clang lld cmake ninja-build pkg-config python3 git zlib1g-dev \
    libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxfixes-dev libxi-dev libxss-dev \
    libxtst-dev libxkbcommon-dev libwayland-dev wayland-protocols libdecor-0-dev \
    libegl-dev libgl-dev libgles-dev libvulkan-dev libdrm-dev libgbm-dev \
    libasound2-dev libpulse-dev libpipewire-0.3-dev libudev-dev libdbus-1-dev libibus-1.0-dev \
    mesa-vulkan-drivers
```

Then, as on the Mac but in `build/native-linux`:

```sh
git clone https://github.com/centollOS/SwitchWaker switchwaker && cd switchwaker
export COS_DISC=/path/to/GZLE01.iso
native/tools/fetch_recompcore.sh
native/tools/gen_assets.sh --out "$PWD/build/native-linux/assets/GZLE01"   # absolute: the script works in build/decomp
CC=clang CXX=clang++ cmake -S native -B build/native-linux -G Ninja
ninja -C build/native-linux switchwaker        # build/native-linux/switchwaker
build/native-linux/switchwaker
```

Aurora draws with Vulkan, then OpenGL ES, then nothing (null) if neither works; `COS_BACKEND=opengl`
(or `vulkan`, `opengles`, `null`) asks for one first. Dawn and nod come as Aurora's prebuilt
packages, SDL 3 is built from source. The regression runs with
`COS_BUILD_DIR=build/native-linux native/tools/regress.sh` (the link census and the duplicate
symbol census are Mac-only and skipped). Headless (no display, no GPU, e.g. in a container):
`COS_ALLOW_CPU_ADAPTER=1 xvfb-run -a native/tools/run.sh title` uses Mesa's software Vulkan.

Fullscreen (Linux and the Mac): `COS_FULLSCREEN=1` starts fullscreen, and **F11** or **Alt+Enter**
switches between fullscreen and the window while the game runs.

## Build with Docker (any OS)

`scripts/docker/build.sh` builds the Linux binary entirely in containers, on
Linux, macOS, or Windows (in a WSL 2 shell, with Docker Desktop's WSL integration or Podman). The
host needs only bash, git and Docker or Podman; the disc is bind-mounted read-only and never
copied into an image.

```sh
scripts/docker/build.sh linux --disc /path/to/GZLE01.iso          # build/native-linux/switchwaker
scripts/docker/build.sh linux --disc /path/to/GZLE01.iso --test   # plus headless checks
```

The Linux binary is built for the container's architecture, which is the host's (x86_64 on a PC,
aarch64 on Apple silicon); `--platform linux/amd64` builds the other one under emulation. The disc
decides the version (GZLP01: `build/native-linux-eur`). The asset
headers are generated once into `build/assets/GZLE01` (`build/assets/GZLP01`). Downloads stay between runs in the
repository's ignored `build/` and `ref/` folders (Aurora and its packages in
`build/native-linux/_deps`, the decompilation and its tools in `build/decomp-docker`, RecompCore in
`ref/recompcore`) and in the engine's image cache.
`scripts/docker/build.sh --help` lists every option. On Windows, keep the clone inside the WSL file
system (for example `~/switchwaker`), not under `/mnt/c`: builds there are much slower.

## Windows (status)

There is no native Windows build yet; it is low priority. Windows users can build the Linux binary
(and run it under WSLg) with Docker, as above. What a native port would need, and
an estimate: [docs/WINDOWS.md](docs/WINDOWS.md).

## Continuous integration

`.github/workflows/ci.yml` checks what can be checked without a disc: scripts lint, Aurora, the SDK
layer and the run harness built and unit-tested on Linux x86_64 and aarch64. It runs only when started by hand (Actions tab, "Run workflow"), to keep the
private repository's Actions minutes. The game itself builds without the disc in the runtime-assets
mode ([docs/RUNTIME_ASSETS.md](docs/RUNTIME_ASSETS.md): `gen_assets.sh --stubs`, `-DCOS_RUNTIME_ASSETS=ON`;
the data arrays are read from the player's disc at start-up), which the CI job also builds; the default
build still compiles the headers generated from your disc.

## iPhone and iPad (in progress)

An experimental native ARM64 app target for iOS / iPadOS 27 lives in `ios/`.
It includes a disc importer and app-container storage, but the complete game
build and device gameplay have not yet been verified. Build prerequisites,
checks and remaining milestones: [docs/IOS.md](docs/IOS.md).

## Options

- In-game options menu: **F1** (or L+R+Z on a controller). Saved to `settings.ini` in the user
  directory (`user/` next to the executable on the Mac and Linux; the app container on iOS).
- Button remapping: options menu > *Controles* (*Controls*): pick a GameCube button, press the controller
  button you want for it (two actions swap buttons); Minus cancels and can never be assigned.
  "Restaurar controles por defecto" puts them all back, as does deleting the `COS_PAD_` lines of
  `settings.ini`. Xbox controllers and GameCube adapters keep their
  usual mapping.
- Language: the options menu and the shader loading screen are in Spanish or English, following the
  system language (`LANG` on the Mac and Linux); `COS_LANG=es` or `COS_LANG=en` forces one.
- `COS_*` variables (the environment, or for developer variables the `[dev]` section of
  `settings.ini`): [native/README.md](native/README.md).
- HD textures (optional, a Dolphin-format pack you supply): [docs/HD_TEXTURES.md](docs/HD_TEXTURES.md).
- 16:9 widescreen: [docs/WIDESCREEN.md](docs/WIDESCREEN.md).

## Status

Boots and plays on the Mac, with sound, controllers, memory-card saves and an
options menu. Played by hand mostly on the opening island and a few other areas; automated sweeps
run on the Mac over every stage and room, every actor, particle effect, model and screen, every event
of every stage, every item through its item-get demo, saves loaded back, every enemy fought and
every boss room, also under AddressSanitizer ([native/README.md](native/README.md), "Sweeps"). The iOS
app builds and starts on an M4 iPad Pro; gameplay there is not verified yet ([docs/IOS.md](docs/IOS.md)).
The Linux build boots to the same milestones and
passes the regression in a container with software Vulkan (aarch64); it has not been played on a
Linux desktop with a GPU yet.
Known issues: [docs/NATIVE_PORT_PLAN.md](docs/NATIVE_PORT_PLAN.md), "Known bugs".

## License

- The project's own code: **MIT** ([LICENSE](LICENSE)).
- `game/` (the decompilation): **CC0-1.0** ([game/LICENSE](game/LICENSE)).
- `native/dsp_hle/` (audio, over Dolphin's DSP HLE): **GPL-2.0-or-later**
  ([native/dsp_hle/LICENSE](native/dsp_hle/LICENSE)). Every build links it today, so **the
  resulting binaries are GPL**.
- Other components: [THIRD_PARTY.md](THIRD_PARTY.md). Contributing: [CONTRIBUTING.md](CONTRIBUTING.md).

## Disclaimer

Independent project, not affiliated with or endorsed by any video game company. Trademarks
mentioned or alluded to belong to their respective owners. No game content is included or
distributed.

---

## Authors

Pulpparty, depende3000, and the SwitchWaker contributors, with an AI coding agent (see "How it was
made: AI use"). Thanks to everyone behind the projects in "Standing on the shoulders of others".
