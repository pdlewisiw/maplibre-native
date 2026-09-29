# MapLibre Native Node v6.4.1: distro-specific addon builders

Source base: upstream `node-v6.4.1` (`d4bde4c93eb15650d0ddb6822d24351f792ea649`). The RBT downstream changes add a bounded Node ABI set and correct the registration callback signature. This is a source-build project, **not** a replacement for the public npm package or a universal `linux-x64` binary.

Use the exact pinned submodules (`git submodule update --init --recursive`). Build each distro separately: Rocky 9.8, Rocky 10, Ubuntu 24.04, Ubuntu 26.04, Debian 12, and Debian 13. The output is an addon for that distro's runtime; do not swap artifacts across distro families or major versions. The application must lock `@maplibre/maplibre-gl-native@6.4.1` and use a compatible Node runtime; Node 20/22/24 use ABI 115/127/137. The current RBT TileServer Ubuntu 24 image uses Node 24.

## Builder commands (run from the repository root)

The OCI build context is the repository root, not this directory. The `.containerignore` removes Git history and generated build outputs but retains source and pinned vendor modules. On low-memory hosts, keep `BUILD_JOBS=2`. Direct native builds are also possible on a matching OS; use the same CMake flags and dependency set.

```sh
# Set TMPDIR to a disk-backed filesystem if /tmp is a small tmpfs.
# Example: export TMPDIR=$HOME/.cache/maplibre-build-tmp
podman build --format docker --pull=missing -f builds/node-v6.4.1/Containerfile \
  --build-arg BASE_IMAGE=docker.io/rockylinux/rockylinux:9.8 \
  -t localhost/maplibre-node:6.4.1-rl9 .
podman build --format docker --pull=missing -f builds/node-v6.4.1/Containerfile \
  --build-arg BASE_IMAGE=docker.io/rockylinux/rockylinux:10 \
  -t localhost/maplibre-node:6.4.1-rl10 .
podman build --format docker --pull=missing -f builds/node-v6.4.1/Containerfile.deb \
  --build-arg BASE_IMAGE=docker.io/library/ubuntu:24.04 \
  -t localhost/maplibre-node:6.4.1-ubuntu24 .
podman build --format docker --pull=missing -f builds/node-v6.4.1/Containerfile.deb \
  --build-arg BASE_IMAGE=docker.io/library/ubuntu:26.04 \
  -t localhost/maplibre-node:6.4.1-ubuntu26 .
podman build --format docker --pull=missing -f builds/node-v6.4.1/Containerfile.deb \
  --build-arg BASE_IMAGE=docker.io/library/debian:12 \
  -t localhost/maplibre-node:6.4.1-debian12 .
podman build --format docker --pull=missing -f builds/node-v6.4.1/Containerfile.deb \
  --build-arg BASE_IMAGE=docker.io/library/debian:13 \
  -t localhost/maplibre-node:6.4.1-debian13 .
```

The builder verifies that ABI 115/127/137 files exist and reports `ldd` dependencies. Acceptance requires more: load the exact ABI in a matching final runtime, test TileServer `/health`, render an EPSG:3395 tile, and retain separate image IDs/digests, source revision, addon checksums, and runtime library inventory per distro. `npm ci` in TileServer fetches a published addon; replace only the locked package's `lib/node-v<abi>/mbgl.node` with the corresponding distro-built artifact. Do not publish a generic npm Linux artifact that silently selects the wrong distro library set.

## Upstream Ubuntu-binary compatibility experiment

Direct `readelf --version-info` inspection of the published upstream 6.4.1 `node-v127-linux-x64-Release.tar.gz` and `node-v137-linux-x64-Release.tar.gz` shows both addons require `GLIBC_2.38` and `GLIBCXX_3.4.32` in addition to Ubuntu's `libjpeg.so.8` and ICU 74. Rocky 9's glibc is 2.34 and Debian 12's is 2.36. Therefore bundling only Ubuntu JPEG and ICU **cannot** make that upstream artifact run on Rocky 9 or Debian 12; `$ORIGIN` RPATH cannot substitute for an older host glibc. Do not bundle glibc into this package or substitute SONAME symlinks. A newer runtime such as Rocky 10 or Debian 13 may merit a *separate* load/render experiment, but does not replace the required older-distro builds. If bundling foreign libraries is ever reconsidered, require explicit policy approval, license notices, security-update ownership, transitive dependency checks, actual Node import and EPSG:3395 rendering.
