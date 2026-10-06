#!/usr/bin/env bash
set -euo pipefail

major="$1"
stage="$2"
source /etc/os-release
[[ "${VERSION_ID}" == "${major}" || "${VERSION_ID}" == "${major}."* ]] || {
    printf 'Expected EL%s, got %s\n' "$major" "$PRETTY_NAME" >&2
    exit 1
}
[[ "$(node -p 'process.versions.modules')" == 127 ]] || {
    printf 'Expected Node addon ABI 127\n' >&2
    exit 1
}
addon=/src/platform/node/lib/node-v127/mbgl.node
test -s "$addon"

if [[ "$stage" == smoke ]]; then
    ldd "$addon" > /tmp/addon-ldd.txt
    if grep -q 'not found' /tmp/addon-ldd.txt; then
        printf 'Unresolved addon libraries:\n' >&2
        grep 'not found' /tmp/addon-ldd.txt >&2
        exit 1
    fi
    printf 'Rocky %s native addon linked libraries:\n' "$major"
    grep -E 'lib(icu|jpeg|png|webp|curl)' /tmp/addon-ldd.txt || :
elif [[ "$stage" != full ]]; then
    printf 'Unknown test stage: %s\n' "$stage" >&2
    exit 2
fi

Xvfb :99 -screen 0 1024x768x24 -nolisten tcp > /tmp/xvfb.log 2>&1 &
xvfb_pid=$!
trap 'kill "$xvfb_pid" 2>/dev/null || :' EXIT
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    [[ -S /tmp/.X11-unix/X99 ]] && break
    sleep 1
done
[[ -S /tmp/.X11-unix/X99 ]] || { printf 'Xvfb failed to start\n' >&2; exit 1; }
export DISPLAY=:99

if [[ "$stage" == smoke ]]; then
    timeout 60s node /src/spikes/001-el9-node-addon/smoke.js
else
    cd /src/platform/node
    timeout 30m script -q -e -c 'npm test' /dev/null
fi