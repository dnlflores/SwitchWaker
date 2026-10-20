# Third-party code

Pins are the ones the build uses today; licenses marked "check" were not read from a local copy
when this was written.

SwitchWaker contains, builds against, or fetches at build time the components below. Nothing in this
list is game data: the repository contains no asset, executable or data file of the game, and every
build reads them from the player's own disc.

## In this repository

| Path | Origin | License |
|---|---|---|
| `game/` | The game's decompilation, imported from a fork ([github.com/snrubrm/tww](https://github.com/snrubrm/tww)) at `b09eebc` of the community decompilation project ([github.com/zeldaret/tww](https://github.com/zeldaret/tww)), changed by later commits of this repository under `TARGET_PC` (see `game/README.md`) | CC0-1.0 (`game/LICENSE`) |
| `native/include/helpers/{endian.h,endian_gx.hpp,endian_ssystem.h,offset_ptr.h}`, `native/src/helpers/offset_ptr.cpp` | [Dusklight](https://github.com/TwilitRealm/dusklight) (TwilitRealm) at `40457c6`; the SDK-over-Aurora layer follows Dusklight's model | CC0-1.0 |
| `native/dsp_hle/` | Adapted from elliotttate's recompilation project ([github.com/elliotttate/Wind-Waker-Recomp](https://github.com/elliotttate/Wind-Waker-Recomp)) (`runtime/host/src/dsp_hle_backend.cpp`, `apple/ios/src/dsp_common_shim.cpp`); compiles Dolphin's DSPHLE (below) | GPL-2.0-or-later (`native/dsp_hle/LICENSE`, SPDX headers in each file) |
| `native/patches/aurora/` | Patches to Aurora | same as Aurora (MIT) |

The quality-of-life options (`docs/QOL_PLAN.md`, `native/src/pc/features/pc_qol.cpp`, the options
menu's "Calidad de vida" tab in `native/src/pc/features/pc_menu.cpp` and the hunks in `game/` the plan
lists) are derived from the patches and tweaks of [BetterWW](https://github.com/WideBoner/betterww)
(WideBoner, at `4501481`) and [wwrando](https://github.com/LagoLunatic/wwrando) (LagoLunatic, at
`9775811`). Their assembly patches cannot run here (the game is compiled from its decompilation), so
each patch was rewritten in the decompiled function it changes, reproducing its behaviour and its
constants (speeds, frame counts, message numbers, event bits) closely. No asset of theirs (textures,
models, icons) is in this repository. BetterWW credits LagoLunatic (BetterWW modifies his code),
brainfubar (his wwrando fork was used to make BetterWW), MelonSpeedruns (the original design of the
Brisk Sail) and JarheadHME (releases); wwrando credits MelonSpeedruns (game and graphic design),
Hypatia (textures), SageOfMirrors and LordNed (file format documentation) and CryZe (event flag
documentation). Both projects are under this license:

```
The MIT License (MIT)

Copyright (c) 2018 LagoLunatic

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Everything else is the project's own code under the MIT license (`LICENSE`), copyright Pulpparty
and depende3000, and the SwitchWaker contributors.

## Fetched at build time (not in the repository)

| Component | Pin | Used for | License |
|---|---|---|---|
| [Aurora](https://github.com/encounter/aurora) | `3227d76` | GameCube SDK over WebGPU (GX, VI, PAD, DVD, CARD, THP) | MIT |
| [Dawn](https://dawn.googlesource.com/dawn) | Mac: Aurora's prebuilt package; iOS: built from source (Aurora's pin) | WebGPU implementation | BSD-3-Clause |
| [abseil-cpp](https://github.com/abseil/abseil-cpp) | Aurora's / Dawn's pin | Dawn dependency | Apache-2.0 |
| [SDL 3](https://github.com/libsdl-org/SDL) | Aurora's pin (built from source on iOS) | window, input, audio | Zlib |
| [Dear ImGui](https://github.com/ocornut/imgui) | Aurora's pin | menus and overlays | MIT |
| [fmt](https://github.com/fmtlib/fmt) | Aurora's pin | formatting | MIT |
| [xxHash](https://github.com/Cyan4973/xxHash) | Aurora's pin | hashing | BSD-2-Clause |
| [Tracy](https://github.com/wolfpld/tracy) | Aurora's pin | profiler hooks (off) | BSD-3-Clause |
| [SQLite](https://sqlite.org) | Aurora's pin | pipeline and texture caches | Public domain |
| [nod](https://github.com/encounter/nod) | Aurora's prebuilt package (Mac); built from source on iOS | disc reader | MIT OR Apache-2.0 (check) |
| [RecompCore](https://github.com/elliotttate/RecompCore) (Dolphin) | `8ab24da` | Dolphin's DSP HLE sources (`native/tools/fetch_recompcore.sh`) | GPL-2.0-or-later |
| [bc7enc_rdo](https://github.com/richgel999/bc7enc_rdo) | `b943862` | HD texture pack converter (`native/tools/hd_pack`) | MIT or Unlicense (bc7e.ispc: Apache-2.0, not built) |
| [decomp-toolkit](https://github.com/encounter/decomp-toolkit) (`dtk`) | the decomp's pin | asset header generation from the player's disc (`native/tools/gen_assets.sh`) | MIT OR Apache-2.0 (check) |

## Binaries

A build that includes `native/dsp_hle` (the default) links Dolphin's GPL-2.0-or-later code: the
resulting `switchwaker` executable and iOS app are distributed under GPL-2.0-or-later terms, with their
corresponding source. Builds contain code generated from the player's disc and are for the
player's own use only.
