#!/usr/bin/env bash
# Fetch the existing pinned dependencies and generate the universal iPhone/iPad project.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
for tool in cmake ninja python3 xcrun curl; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Missing $tool. Install Xcode and: brew install cmake ninja python rust" >&2
        exit 2
    fi
done
# Homebrew Python is externally managed; keep build dependencies in the repo.
venv="$repo/build/ios-python"
if [[ ! -x "$venv/bin/python3" ]]; then
    python3 -m venv "$venv"
fi
if ! "$venv/bin/python3" -c 'import yaml' 2>/dev/null; then
    "$venv/bin/python3" -m pip install 'PyYAML>=6,<7'
fi
export PATH="$venv/bin:$PATH"
simulator=OFF
build="$repo/build/ios-device"
if [[ "${1:-}" == "--simulator" ]]; then
    simulator=ON
    build="$repo/build/ios-simulator"
    shift
fi
rust_target=aarch64-apple-ios
[[ "$simulator" == OFF ]] || rust_target=aarch64-apple-ios-sim
# Homebrew's Rust package has only the macOS standard library. Install an
# isolated official rustup toolchain with the target library the app needs.
# No shell profiles, global Rust installation or Homebrew files are changed.
export RUSTUP_HOME="$repo/build/ios-rustup"
export CARGO_HOME="$repo/build/ios-cargo"
if [[ ! -x "$CARGO_HOME/bin/rustup" ]]; then
    if [[ "$(uname -m)" != arm64 ]]; then
        echo "This setup currently requires an Apple silicon Mac." >&2
        exit 2
    fi
    installer="$repo/build/rustup-init"
    curl --fail --location --retry 2 \
        https://static.rust-lang.org/rustup/dist/aarch64-apple-darwin/rustup-init \
        --output "$installer"
    chmod +x "$installer"
    RUSTUP_INIT_SKIP_PATH_CHECK=yes "$installer" -y --no-modify-path \
        --profile minimal --default-toolchain stable --target "$rust_target"
fi
export PATH="$CARGO_HOME/bin:$PATH"
rustup target add --toolchain stable "$rust_target"
rust_compiler="$(rustup which --toolchain stable rustc)"
rust_cargo="$(rustup which --toolchain stable cargo)"
"$repo/native/tools/fetch_recompcore.sh"
assets="$repo/build/ios-assets/GZLE01"
if [[ ! -f "$assets/include/assets/cos_assets.h" ]]; then
    "$repo/native/tools/gen_assets.sh" --stubs --version GZLE01 --out "$assets"
fi
cmake -S "$repo/ios" -B "$build" -G Xcode \
    -U 'Rust_*' -U 'FREETYPE_*' -U 'PNG_*' -U 'ZSTD_*' \
    -DCMAKE_TOOLCHAIN_FILE="$repo/ios/cmake/ios.toolchain.cmake" \
    -DCOS_IOS_SIMULATOR="$simulator" \
    -DCOS_ASSETS_DIR="$assets" \
    -DRust_COMPILER="$rust_compiler" -DRust_CARGO="$rust_cargo" \
    -DCOS_IOS_CARGO_HOME="$CARGO_HOME" \
    -DCOS_IOS_TEAM="${COS_IOS_TEAM:-}" "$@"
# Populate the Cargo cache while setup has network access, so subsequent app
# builds do not need to download the Rust dependencies again.
"$rust_cargo" fetch --manifest-path "$build/_deps/aurora_nod-src/nod-ffi/Cargo.toml" \
    --target "$rust_target" --locked
echo "Project: $build/SwitchWakerIOS.xcodeproj"
echo "Build: cmake --build '$build' --config Release --target switchwaker"
