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

if command -v xwfb-run >/dev/null 2>&1; then
    # xwayland-run's default compositor is mutter; our test image installs Weston.
    headless_runner=(xwfb-run -c weston)
elif command -v xvfb-run >/dev/null 2>&1; then
    headless_runner=(xvfb-run --auto-servernum)
else
    printf 'Neither xwfb-run nor xvfb-run is available\n' >&2
    exit 1
fi

if [[ "$stage" == smoke ]]; then
    timeout 60s "${headless_runner[@]}" node /src/spikes/001-el9-node-addon/smoke.cjs
else
    cd /src/platform/node
    printf -v test_command '%q ' "${headless_runner[@]}" npm test
    timeout 30m script -q -e -c "$test_command" /dev/null
fi
