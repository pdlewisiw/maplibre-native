#!/usr/bin/env bash
set -euo pipefail

expected_id="${1:?OS ID required}"
expected_major="${2:?OS major required}"
abi="${3:?Node ABI required}"
stage="${4:?smoke or full required}"
[[ "$abi" =~ ^(127|131|137)$ ]] || { printf 'Unsupported ABI: %s\n' "$abi" >&2; exit 2; }
source /etc/os-release
[[ "$ID" == "$expected_id" && ( "$VERSION_ID" == "$expected_major" || "$VERSION_ID" == "$expected_major".* ) ]] || {
    printf 'Expected %s %s, got %s (%s)\n' "$expected_id" "$expected_major" "$PRETTY_NAME" "$VERSION_ID" >&2
    exit 1
}
export PATH="/opt/node-v${abi}/bin:$PATH"
export EXPECTED_NODE_ABI="$abi"
[[ "$(node -p 'process.versions.modules')" == "$abi" ]] || { printf 'Wrong Node ABI\n' >&2; exit 1; }
addon="/src/platform/node/lib/node-v${abi}/mbgl.node"
test -s "$addon"
if [[ "$stage" == smoke ]]; then
    ldd "$addon" > /tmp/addon-ldd.txt
    if grep -q 'not found' /tmp/addon-ldd.txt; then
        printf 'Unresolved addon libraries:\n' >&2
        grep 'not found' /tmp/addon-ldd.txt >&2
        exit 1
    fi
    printf '%s %s / ABI %s linked libraries:\n' "$ID" "$VERSION_ID" "$abi"
    grep -E 'lib(icu|jpeg|png|webp|curl)' /tmp/addon-ldd.txt || :
elif [[ "$stage" != full ]]; then
    printf 'Unknown test stage: %s\n' "$stage" >&2
    exit 2
fi

if command -v xwfb-run >/dev/null 2>&1; then
    headless_runner=(xwfb-run -c weston)
elif command -v xvfb-run >/dev/null 2>&1; then
    headless_runner=(xvfb-run --auto-servernum)
else
    printf 'Neither xwfb-run nor xvfb-run is available\n' >&2
    exit 1
fi
if [[ "$stage" == smoke ]]; then
    timeout 60s "${headless_runner[@]}" node /src/spikes/linux-builds-v1/smoke.cjs
else
    cd /src/platform/node
    printf -v test_command '%q ' "${headless_runner[@]}" npm test
    timeout 30m script -q -e -c "$test_command" /dev/null
fi
