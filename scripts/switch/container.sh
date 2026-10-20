# shellcheck shell=bash
# Container helpers shared by the Switch build scripts. Source this file; it
# selects Podman (rootless, as before) or Docker. Set SWITCH_CONTAINER_ENGINE
# to podman or docker to force one.

container_engine() {
    if [[ -n ${SWITCH_CONTAINER_ENGINE:-} ]]; then
        printf '%s\n' "$SWITCH_CONTAINER_ENGINE"
    elif command -v podman >/dev/null 2>&1; then
        echo podman
    elif command -v docker >/dev/null 2>&1; then
        echo docker
    fi
}

container_image_exists() {
    local engine=$1 image=$2
    if [[ $engine == podman ]]; then
        podman image exists "$image"
    else
        docker image inspect "$image" >/dev/null 2>&1
    fi
}

# source_tree_id DIR: a short hash of a checkout's commit and local changes (its diff and untracked
# files), for build stamps that only see the checkout at a fixed mount path; "untracked" when DIR is
# not a git checkout.
source_tree_id() {
    local dir=$1 sha
    if command -v sha256sum >/dev/null 2>&1; then sha=(sha256sum); else sha=(shasum -a 256); fi
    if git -C "$dir" rev-parse --verify -q HEAD >/dev/null 2>&1; then
        { git -C "$dir" rev-parse HEAD; git -C "$dir" diff HEAD; git -C "$dir" status --porcelain; } |
            "${sha[@]}" | cut -c1-16
    else
        echo untracked
    fi
}

# native_build_image ROOT: the Switch build image's tag, a hash of Containerfile.native, so that an edit
# of it builds a new image instead of reusing the one a machine already has
native_build_image() {
    local sha
    if command -v sha256sum >/dev/null 2>&1; then sha=(sha256sum); else sha=(shasum -a 256); fi
    echo "localhost/centollos-switch-native-build:$("${sha[@]}" "$1/scripts/switch/Containerfile.native" | cut -c1-12)"
}

# container_run ENGINE ROOT [run options...] IMAGE COMMAND...
# Mounts ROOT at /work and runs as the invoking user so build outputs stay
# owned by them.
container_run() {
    local engine=$1 root=$2
    shift 2
    if [[ $engine == podman ]]; then
        podman run --rm --userns=keep-id -v "$root:/work:Z" -w /work "$@"
    else
        docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
            -v "$root:/work" -w /work "$@"
    fi
}
