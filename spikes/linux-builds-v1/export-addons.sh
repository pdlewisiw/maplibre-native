#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_SHA:?source commit is required}"
: "${GITHUB_REF_NAME:?branch is required}"
: "${GITHUB_WORKSPACE:?workspace is required}"
: "${GITHUB_RUN_ID:?run ID is required}"
: "${GITHUB_RUN_ATTEMPT:?run attempt is required}"
target="${1:?target label is required (rl9, rl10, deb12, deb13)}"
[[ "$target" =~ ^[a-z][a-z0-9_-]*$ ]] || { printf 'Unsafe target: %s\n' "$target" >&2; exit 2; }
repo="$GITHUB_WORKSPACE"
version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$repo/platform/node/package.json")"
branch="${GITHUB_REF_NAME//\//-}"
for value in "$version" "$branch"; do
    [[ "$value" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || { printf 'Unsafe build label: %s\n' "$value" >&2; exit 2; }
done
[[ "$GITHUB_SHA" =~ ^[0-9a-f]{40}$ ]] || { printf 'Invalid source commit\n' >&2; exit 2; }
code="${BUILD_DATECODE:-$(date -u +%y%m%d%H%M)}"
[[ "$code" =~ ^[0-9]{10}$ ]] || { printf 'Date code must be UTC YYMMDDHHMM\n' >&2; exit 2; }
name="${version}_${branch}_${code}_${target}"
backup_root="${BACKUP_ROOT:-/opt/actions-runner/artifacts/maplibre-native}"
mkdir -p -- "$backup_root"
[[ ! -e "$backup_root/$name" ]] || { printf 'Backup already exists: %s\n' "$backup_root/$name" >&2; exit 1; }
[[ ! -e "$repo/dist" ]] || { printf 'Workspace dist/ already exists; refusing to mix outputs\n' >&2; exit 1; }

staging="$(mktemp -d "$backup_root/.export-XXXXXXXX")"
cid=''
cleanup() {
    if [[ -n "$cid" ]]; then podman rm "$cid" >/dev/null 2>&1 || :; fi
    if [[ -d "$staging" ]]; then rm -rf -- "$staging"; fi
}
trap cleanup EXIT
image="localhost/maplibre-addon:${target}-${GITHUB_SHA}"
image_id="$(podman image inspect --format '{{.Id}}' "$image")"
base_image="${BASE_IMAGE:-not-recorded}"
base_digest='not-recorded'
if [[ "$base_image" != not-recorded ]]; then
    base_digest="$(podman image inspect --format '{{.Digest}}' "$base_image")"
fi
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
    actual="$(sha256sum "$staging/$name/$abi/mbgl.node")"
    [[ "${actual%% *}" == "$expected" ]] || { printf 'Copy checksum mismatch: %s\n' "$src" >&2; exit 1; }
done <<< "$source_hashes"
(
    cd "$staging/$name"
    sha256sum node-v127/mbgl.node node-v131/mbgl.node node-v137/mbgl.node > SHA256SUMS
    sha256sum --check SHA256SUMS
)
printf 'package_version=%s\nbranch=%s\ndatecode_utc=%s\nsource_commit=%s\nrun_id=%s\nrun_attempt=%s\ntarget=%s-x86_64\nbase_image=%s\nbase_image_digest=%s\nbuilder_image=%s\nbuilder_image_id=%s\ncoverage=Node ABI 127/131/137 smoke and full Node suite in target test image\n' \
    "$version" "$GITHUB_REF_NAME" "$code" "$GITHUB_SHA" "$GITHUB_RUN_ID" "$GITHUB_RUN_ATTEMPT" "$target" "$base_image" "$base_digest" "$image" "$image_id" > "$staging/$name/BUILD-INFO.txt"
mkdir -- "$repo/dist"
mv -- "$staging/$name" "$backup_root/$name"
cp -a -- "$backup_root/$name" "$repo/dist/"
( cd "$backup_root/$name" && sha256sum --check SHA256SUMS )
( cd "$repo/dist/$name" && sha256sum --check SHA256SUMS )
printf 'Retained: %s\n' "$backup_root/$name"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then printf 'build_id=%s\n' "$name" >> "$GITHUB_OUTPUT"; fi
printf 'Exported and verified: %s\n' "$name"
