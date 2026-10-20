# Device build. Set COS_IOS_SIMULATOR=ON in a separate build directory for the simulator.
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_OSX_ARCHITECTURES arm64 CACHE STRING "Apple target architecture")
set(CMAKE_OSX_DEPLOYMENT_TARGET "27.0" CACHE STRING "Minimum iOS / iPadOS version")
if (COS_IOS_SIMULATOR)
    set(CMAKE_OSX_SYSROOT iphonesimulator CACHE STRING "Apple SDK")
    set(Rust_CARGO_TARGET aarch64-apple-ios-sim CACHE STRING "Rust target triple" FORCE)
else ()
    set(CMAKE_OSX_SYSROOT iphoneos CACHE STRING "Apple SDK")
    set(Rust_CARGO_TARGET aarch64-apple-ios CACHE STRING "Rust target triple" FORCE)
endif ()
# Host programs are needed by generators; linked libraries and headers must
# come from the target SDK or source builds, never the Mac's Homebrew prefix.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_DISABLE_FIND_PACKAGE_PkgConfig TRUE CACHE BOOL "Do not import host pkg-config libraries" FORCE)
list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES COS_IOS_SIMULATOR)
