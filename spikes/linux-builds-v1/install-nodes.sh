#!/usr/bin/env bash
# Test-only pinned x64 Node runtimes. Each tarball is verified before extraction.
set -euo pipefail
for spec in \
  '127 22.23.1 7a8cb04b4a1df4eaf432125324b81b29a088e73570a23259a8de1c65d07fc129' \
  '131 23.11.1 a2029c2b0cb05d10248e887c5df3f8547b7ab4aaa4e63b8e4da03e72f478140e' \
  '137 24.21.0 6e1db87ef58b8819e5d5402eff1536491b18edd8eb7bee5ef7897876e88dc5ff'; do
  read -r abi version checksum <<< "$spec"
  archive="/tmp/node-v${version}-linux-x64.tar.gz"
  curl --fail --location --retry 4 --output "$archive" \
    "https://nodejs.org/dist/v${version}/node-v${version}-linux-x64.tar.gz"
  printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check -
  mkdir -p "/opt/node-v${abi}"
  tar -xzf "$archive" -C "/opt/node-v${abi}" --strip-components=1
  rm -- "$archive"
  actual="$("/opt/node-v${abi}/bin/node" -p 'process.versions.modules')"
  [[ "$actual" == "$abi" ]] || { printf 'Node %s: expected ABI %s, got %s\n' "$version" "$abi" "$actual" >&2; exit 1; }
done
