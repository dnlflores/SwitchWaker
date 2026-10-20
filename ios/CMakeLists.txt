cmake_minimum_required(VERSION 3.28)
project(SwitchWakerIOS LANGUAGES C CXX OBJC OBJCXX)
# Device and simulator already use separate build trees. Keep Xcode's paths
# consistent with generator expressions written into the ordered object list
# and Dawn's archive bundling commands.
set_property(GLOBAL PROPERTY XCODE_EMIT_EFFECTIVE_PLATFORM_NAME OFF)
set(CMAKE_XCODE_ATTRIBUTE_EFFECTIVE_PLATFORM_NAME "")
if (NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
    message(FATAL_ERROR "Use -DCMAKE_TOOLCHAIN_FILE=ios/cmake/ios.toolchain.cmake")
endif ()

# Desktop darwin-arm64 archives cannot link into an iOS executable. Build dependencies
# for this SDK; explicit system targets can be supplied by a dependency superbuild.
set(AURORA_DAWN_PROVIDER vendor CACHE STRING "Dawn provider")
set(AURORA_NOD_PROVIDER vendor CACHE STRING "nod provider")
set(AURORA_SDL3_PROVIDER vendor CACHE STRING "SDL3 provider")
set(AURORA_DAWN_LINKAGE static CACHE STRING "Dawn linkage")
set(AURORA_NOD_LINKAGE static CACHE STRING "nod linkage")
set(AURORA_SDL3_LINKAGE static CACHE STRING "SDL3 linkage")
# The launcher supports plain ISO/GCM. Avoid unused compression libraries in
# nod and keep Aurora's disposable shader caches uncompressed on this target.
set(AURORA_CACHE_USE_ZSTD OFF CACHE BOOL "Compress shader caches" FORCE)
foreach (_compression BZIP2 LZMA ZLIB ZSTD)
    set(NOD_COMPRESS_${_compression} OFF CACHE BOOL "Compressed disc support" FORCE)
endforeach ()
set(DAWN_ENABLE_METAL ON CACHE BOOL "Metal backend")
set(DAWN_ENABLE_VULKAN OFF CACHE BOOL "Vulkan backend")
set(DAWN_ENABLE_DESKTOP_GL OFF CACHE BOOL "Desktop OpenGL backend")
set(DAWN_ENABLE_OPENGLES OFF CACHE BOOL "OpenGL ES backend")
set(DAWN_BUILD_SAMPLES OFF CACHE BOOL "Dawn samples")
set(DAWN_BUILD_TESTS OFF CACHE BOOL "Dawn tests")
set(DAWN_USE_GLFW OFF CACHE BOOL "Desktop windowing helpers" FORCE)
# Protobuf and Tint's IR serializer are development tooling, not needed by the
# Metal renderer. Protoc would have to run on macOS, not the iOS target.
set(DAWN_BUILD_PROTOBUF OFF CACHE BOOL "Dawn protobuf tooling" FORCE)
set(TINT_BUILD_IR_BINARY OFF CACHE BOOL "Tint binary IR tooling" FORCE)
set(TINT_BUILD_CMD_TOOLS OFF CACHE BOOL "Tint command-line tools" FORCE)
set(TINT_BUILD_TESTS OFF CACHE BOOL "Tint tests" FORCE)
set(TRACY_ENABLE OFF CACHE BOOL "Profiler")
set(COS_RUNTIME_ASSETS ON CACHE BOOL "Load game assets from the imported disc")
if (NOT COS_RUNTIME_ASSETS)
    message(FATAL_ERROR "The iOS app requires COS_RUNTIME_ASSETS=ON")
endif ()

add_library(cos_ios_entry STATIC src/main.cpp src/platform.mm)
target_compile_options(cos_ios_entry PRIVATE "$<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>")
target_link_libraries(cos_ios_entry PUBLIC "-framework UIKit" "-framework Foundation"
        "-framework UniformTypeIdentifiers")
set(COS_EXE_ENTRY cos_ios_entry)
add_subdirectory(../native native)
if (CMAKE_GENERATOR STREQUAL "Xcode" AND TARGET webgpu_dawn)
    # Xcode omits the archive phase for Dawn's object-only bundled library.
    # A real source gives it an archive phase that includes those objects.
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/dawn_archive_stub.c"
            "/* Anchor for Xcode's Dawn archive phase. */\n")
    target_sources(webgpu_dawn PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/dawn_archive_stub.c")
endif ()
set(COS_IOS_CARGO_HOME "" CACHE PATH "Private Cargo cache used by the setup script")
if (COS_IOS_CARGO_HOME AND COMMAND corrosion_set_env_vars)
    corrosion_set_env_vars(nod "CARGO_HOME=${COS_IOS_CARGO_HOME}")
endif ()
# Aurora chooses SDL inside the native subdirectory. Read the entry library's public
# dependencies instead of relying on that subdirectory's private CMake variables.
target_link_libraries(cos_ios_entry PUBLIC "$<TARGET_PROPERTY:aurora::main,INTERFACE_LINK_LIBRARIES>")
target_compile_definitions(cos_ios_entry PRIVATE COS_GAME_ID_STR="${COS_GAME_ID}")

set(COS_IOS_BUNDLE_ID "com.dnlflores.switchwaker" CACHE STRING "iOS bundle identifier")
set(COS_IOS_TEAM "" CACHE STRING "Apple development team for signing")
set_target_properties(switchwaker PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in"
        MACOSX_BUNDLE_GUI_IDENTIFIER "${COS_IOS_BUNDLE_ID}"
        MACOSX_BUNDLE_BUNDLE_NAME "SwitchWaker"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "0.1.0"
        MACOSX_BUNDLE_BUNDLE_VERSION "1"
        XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
        XCODE_ATTRIBUTE_SUPPORTS_MACCATALYST NO
        XCODE_ATTRIBUTE_CODE_SIGN_STYLE Automatic
        XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${COS_IOS_TEAM}"
        XCODE_GENERATE_SCHEME TRUE)
