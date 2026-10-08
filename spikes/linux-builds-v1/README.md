# Linux builds v1 (disposable spike)

Clean base: fork `main` at `f1909874093de87cb3a375573ab2228e89bbd227`, Node package `6.5.0-pre.1`. The branch includes the callback fix and optional ABI maximum from the separately reviewable draft PRs #2 and #3. Neither distro recipes nor private-runner CI belong in those source PRs.

## Validation matrix (x86_64)

| CI target | Base image | Build ABIs | Matching test Node versions |
| --- | --- | --- | --- |
| `rl9` | Rocky 9.8 | 127, 131, 137 | 22.23.1, 23.11.1, 24.21.0 |
| `rl10` | Rocky 10.2 | 127, 131, 137 | 22.23.1, 23.11.1, 24.21.0 |
| `deb12` | Debian 12 | 127, 131, 137 | 22.23.1, 23.11.1, 24.21.0 |
| `deb13` | Debian 13 | 127, 131, 137 | 22.23.1, 23.11.1, 24.21.0 |

Each Node tarball is pinned to a SHA-256 in `install-nodes.sh`. ABI 131 requires Node 23, which is end-of-life: test-only, not a production recommendation. Each ABI must independently pass linkage, Node import/real render and the full `platform/node` JavaScript suite in its *own target's* test image. The source image never uses or packages Node/npm. Tests do not cover native C++/CTest or TileServer GL integration.

## Build outside CI

Initialize pinned submodules and build from the repository root (not this directory):

```sh
git submodule update --init --recursive
podman build --format docker --pull=missing --target builder \
  --build-arg BASE_IMAGE=docker.io/library/debian:12 \
  --build-arg BUILD_JOBS=4 -f spikes/linux-builds-v1/Containerfile.deb \
  -t localhost/maplibre-addon:deb12-manual .
```

Use `Containerfile.deb` with Debian 13, or `Containerfile.el` with Rocky 9/10. A derivative may supply its own family-compatible `BASE_IMAGE` with required repositories enabled. Source-build portability is a goal, not a blanket guarantee about derivative package repositories or binary interchange. Run `test-in-container.sh` in a matching test image with the correct `/etc/os-release` ID/major and ABI. Do not relabel a distro-specific output as generic `linux-x64`.

The trusted-push-only `.github/workflows/linux-builds-v1.yml` serializes four matrix jobs on the dedicated private builder. Each job separately uploads a checksummed distro-labelled bundle **after** all three matching-runtime suites pass, while retaining a runner-owned copy. The `debian:12` and `debian:13` tags are mutable; record the actual base image digest and packages for long-term reproducibility before promoting this spike. Confirm a completed job, run head SHA, per-ABI TAP counts, and a downloaded artifact before claiming validation.
