#!/usr/bin/env bash
# Run exactly one reference-OS build and complete Node ABI validation locally.
# Requires a clean, submodule-initialized checkout and a roomy Podman builder host.
set -euo pipefail
selection="${1:?usage: bash spikes/linux-builds-v1/run-one.sh <el9|el10|deb13|ubuntu2404|ubuntu2604>}"
repo="$(git rev-parse --show-toplevel)"
cd "$repo"
fields="$(python3 spikes/linux-builds-v1/select-matrix.py "$selection" --fields)"
IFS=$'\t' read -r target base_image containerfile os_id version <<< "$fields"
[[ -n "$target" && -n "$version" ]] || { printf 'Invalid matrix row\n' >&2; exit 2; }
[[ -z "$(git status --porcelain --untracked-files=normal)" ]] || {
    printf 'Commit or clean source changes first, so the recorded commit describes the built bytes.\n' >&2
    exit 1
}
git submodule status --recursive | python3 -c 'import sys; bad=[line for line in sys.stdin if line.startswith(("-", "+", "U"))];
if bad:
    print("Submodules must match the recorded commit: git submodule update --init --recursive", file=sys.stderr)
    sys.exit(1)'
export GITHUB_SHA="$(git rev-parse HEAD)"
export GITHUB_REF_NAME="$(git symbolic-ref --short HEAD)"
export GITHUB_WORKSPACE="$repo"
export GITHUB_RUN_ID="manual-$(date -u +%Y%m%dT%H%M%S)-$$"
export GITHUB_RUN_ATTEMPT=1
export BASE_IMAGE="$base_image" EXPECTED_OS_ID="$os_id" EXPECTED_OS_VERSION="$version"
export BACKUP_ROOT="${BACKUP_ROOT:-$HOME/build-artifacts/maplibre-native/retained}"
export OUTPUT_DIR="${OUTPUT_DIR:-$HOME/build-artifacts/maplibre-native/exports/${target}-$(date -u +%Y%m%dT%H%M%S)-$$}"
image="localhost/maplibre-addon:${target}-${GITHUB_SHA}"
test_image="localhost/maplibre-addon-test:${target}-${GITHUB_SHA}"
printf 'Target %s: %s %s, base %s, commit %s\n' "$target" "$os_id" "$version" "$base_image" "$GITHUB_SHA"
podman build --format docker --pull=missing --target builder \
    --build-arg "BASE_IMAGE=$base_image" --build-arg BUILD_JOBS=4 \
    --file "$containerfile" --tag "$image" .
podman run --rm "$image" bash -ec 'for mode in global explicit uncapped filtered; do
    cmake -G Ninja -S /src/platform/node/tests/node_abi_bounds \
      -B "/tmp/abi-${mode}" -DMODULE_PATH=/src/platform/node/cmake/module.cmake \
      -DBOUND_MODE="$mode" >/dev/null
    printf "%s passed\n" "$mode"
done'
podman build --format docker --pull=missing --target test \
    --build-arg "BASE_IMAGE=$base_image" --build-arg BUILD_JOBS=4 \
    --file "$containerfile" --tag "$test_image" .
for stage in smoke full; do
    for abi in 127 131 137; do
        podman run --rm "$test_image" bash /src/spikes/linux-builds-v1/test-in-container.sh \
            "$os_id" "$version" "$abi" "$stage"
    done
done
bash spikes/linux-builds-v1/export-addons.sh "$target"
printf 'Validated single-target output: %s\n' "$OUTPUT_DIR"
