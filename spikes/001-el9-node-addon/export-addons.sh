#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_SHA:?source commit is required}"
: "${GITHUB_REF_NAME:?branch is required}"
: "${GITHUB_WORKSPACE:?workspace is required}"
: "${GITHUB_RUN_ID:?run ID is required}"
: "${GITHUB_RUN_ATTEMPT:?run attempt is required}"

repo="$GITHUB_WORKSPACE"
version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$repo/platform/node/package.json")"
branch="${GITHUB_REF_NAME//\//-}"
for value in "$version" "$branch"; do
    [[ "$value" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || { printf 'Unsafe build label: %s\n' "$value" >&2; exit 2; }
done
[[ "$GITHUB_SHA" =~ ^[0-9a-f]{40}$ ]] || { printf 'Invalid source commit\n' >&2; exit 2; }
code="${BUILD_DATECODE:-$(date -u +%y%m%d%H%M)}"
[[ "$code" =~ ^[0-9]{10}$ ]] || { printf 'Date code must be UTC YYMMDDHHMM\n' >&2; exit 2; }
build_id="${version}_${branch}_${code}"
backup_root="${BACKUP_ROOT:-/opt/actions-runner/artifacts/maplibre-native}"
mkdir -p -- "$backup_root"
# Never merge into or replace a previous build, even on a retry in the same minute.
for distro in rl9 rl10; do
    [[ ! -e "$backup_root/${build_id}_${distro}" ]] || { printf 'Backup already exists: %s\n' "$backup_root/${build_id}_${distro}" >&2; exit 1; }
done
[[ ! -e "$repo/dist" ]] || { printf 'Workspace dist/ already exists; refusing to mix outputs\n' >&2; exit 1; }

staging="$(mktemp -d "$backup_root/.export-XXXXXXXX")"
cid=''
cleanup() {
    if [[ -n "$cid" ]]; then podman rm "$cid" >/dev/null 2>&1 || :; fi
    if [[ -d "$staging" ]]; then rm -rf -- "$staging"; fi
}
trap cleanup EXIT

for distro in rl9 rl10; do
    name="${build_id}_${distro}"
    image="localhost/maplibre-addon:${distro}-${GITHUB_SHA}"
    image_id="$(podman image inspect --format '{{.Id}}' "$image")"
    mkdir -p -- "$staging/$name"
    cid="$(podman create "$image" true)"
    sources=()
    for abi in 127 131 137; do
        src="/src/platform/node/lib/node-v${abi}/mbgl.node"
        dest="$staging/$name/node-v${abi}/mbgl.node"
        mkdir -p -- "$(dirname "$dest")"
        podman cp "$cid:$src" "$dest"
        sources+=("$src")
    done
    podman rm "$cid" >/dev/null
    cid=''
    source_hashes="$(podman run --rm "$image" sha256sum "${sources[@]}")"
    while read -r expected src; do
        abi="${src%/mbgl.node}"
        abi="${abi##*/}"
        target="$staging/$name/$abi/mbgl.node"
        actual="$(sha256sum "$target")"
        [[ "${actual%% *}" == "$expected" ]] || { printf 'Copy checksum mismatch: %s\n' "$src" >&2; exit 1; }
    done <<< "$source_hashes"
    (
        cd "$staging/$name"
        sha256sum node-v127/mbgl.node node-v131/mbgl.node node-v137/mbgl.node > SHA256SUMS
        sha256sum --check SHA256SUMS
    )
    printf 'package_version=%s\nbranch=%s\ndatecode_utc=%s\nsource_commit=%s\nrun_id=%s\nrun_attempt=%s\ntarget=%s-x86_64\nbuilder_image=%s\nbuilder_image_id=%s\ncoverage=node-v127 smoke and full Node suite; node-v131 and node-v137 build/linkage only\n' \
        "$version" "$GITHUB_REF_NAME" "$code" "$GITHUB_SHA" "$GITHUB_RUN_ID" "$GITHUB_RUN_ATTEMPT" "$distro" "$image" "$image_id" > "$staging/$name/BUILD-INFO.txt"
done

mkdir -- "$repo/dist"
for distro in rl9 rl10; do
    name="${build_id}_${distro}"
    mv -- "$staging/$name" "$backup_root/$name"
    cp -a -- "$backup_root/$name" "$repo/dist/"
    ( cd "$backup_root/$name" && sha256sum --check SHA256SUMS )
    ( cd "$repo/dist/$name" && sha256sum --check SHA256SUMS )
    printf 'Retained: %s\n' "$backup_root/$name"
done
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf 'build_id=%s\n' "$build_id" >> "$GITHUB_OUTPUT"
fi
printf 'Exported and verified: %s\n' "$build_id"
