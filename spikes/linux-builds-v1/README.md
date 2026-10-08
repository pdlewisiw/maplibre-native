# Linux builds v1 (disposable spike)

Clean base: fork `main` at `f1909874093de87cb3a375573ab2228e89bbd227`, Node package `6.5.0-pre.1`. The branch includes the callback fix and optional ABI maximum from the separately reviewable draft PRs #2 and #3. Neither distro recipes nor private-runner CI belong in those source PRs.

## Validation matrix (x86_64)

| CI target | Actual reference image / OS tested | Build ABIs | Matching test Node versions |
| --- | --- | --- | --- |
| `el9` | Rocky Linux 9.8 (`ID=rocky`) | 127, 131, 137 | 22.23.1, 23.11.1, 24.21.0 |
| `el10` | Rocky Linux 10.2 (`ID=rocky`) | 127, 131, 137 | 22.23.1, 23.11.1, 24.21.0 |
| `deb13` | Debian 13 | 127, 131, 137 | 22.23.1, 23.11.1, 24.21.0 |
| `ubuntu2404` | Ubuntu 24.04 LTS | 127, 131, 137 | 22.23.1, 23.11.1, 24.21.0 |
| `ubuntu2604` | Ubuntu 26.04 LTS | 127, 131, 137 | 22.23.1, 23.11.1, 24.21.0 |

The `el9`/`el10` names label reusable EL-family *source build targets*; the only EL reference images exercised by CI are **Rocky Linux 9.8 and 10.2**. This does not certify RHEL, AlmaLinux, Oracle Linux, or other derivatives. Their own native builds and tests are required. The artifact manifest records both the target label and the actual OS ID/version from the builder image.

**Roadmap, not a test row:** Debian 14. Add a pinned `debian:14` row only after the image and required packages are available and its own ABI-specific builds, smoke renders and full suites have been validated. Debian 12 is not a supported/tested target in this spike.

Each Node tarball is pinned to a SHA-256 in `install-nodes.sh`. ABI 131 requires Node 23, which is end-of-life: test-only, not a production recommendation. Each ABI must independently pass linkage, Node import/real render and the full `platform/node` JavaScript suite in its *own target's* test image. The source image never uses or packages Node/npm. Tests do not cover native C++/CTest or TileServer GL integration.

## Build outside CI

Initialize pinned submodules and build from the repository root (not this directory):

```sh
git submodule update --init --recursive
podman build --format docker --pull=missing --target builder \
  --build-arg BASE_IMAGE=docker.io/library/debian:13 \
  --build-arg BUILD_JOBS=4 -f spikes/linux-builds-v1/Containerfile.apt \
  -t localhost/maplibre-addon:deb13-manual .
```

Use `Containerfile.apt` with Debian 13 and Ubuntu 24.04/26.04, or `Containerfile.el` with Rocky 9/10. A derivative may supply its own family-compatible `BASE_IMAGE` with required repositories enabled. Source-build portability is a goal, not a blanket guarantee about derivative package repositories or binary interchange. Run `test-in-container.sh` in a matching test image with the correct `/etc/os-release` ID/version and ABI. Do not relabel a distro-specific output as generic `linux-x64`.

### One target at a time

On a builder with enough free disk and a **clean checkout with initialized submodules**, run `bash spikes/linux-builds-v1/run-one.sh ubuntu2604` (or `el9`, `el10`, `deb13`, `ubuntu2404`). It selects the pinned base image from `matrix.json`, executes the same fixture, three ABI smoke renders and three full Node suites, then writes a checksummed artifact under `$HOME/build-artifacts/maplibre-native/exports/` and a retained copy under `retained/`. Set `BACKUP_ROOT` and `OUTPUT_DIR` to writable paths outside the checkout to customize them. The workstation's small local Podman disk is not suitable for full native builds; use the dedicated builder or an equivalently sized host. A dirty checkout is deliberately rejected to keep commit provenance truthful. This local path does **not** upload an Actions artifact.

The workflow also declares a `workflow_dispatch` choice of `all` or one target: `gh workflow run linux-builds-v1.yml -R pdlewisiw/maplibre-native --ref linux-builds-v1 -f target=ubuntu2604`. GitHub may not expose branch-only `workflow_dispatch` until the workflow is on the fork's default branch; the local script is the branch-independent path. A normal push to `linux-builds-v1` always runs all five rows.

The trusted-branch `.github/workflows/linux-builds-v1.yml` serializes five matrix jobs on the dedicated private builder. Each job separately uploads a checksummed OS-labelled bundle **after** all three matching-runtime suites pass, while retaining a runner-owned copy. All base-image tags are mutable; the exporter records the resolved base-image digest, but package and Node-header-index pinning should be reviewed before promoting this spike. Confirm a completed job, run head SHA, per-ABI TAP counts, and a downloaded artifact before claiming validation. Earlier four-row CI runs on older source commits are not five-row validation evidence.
