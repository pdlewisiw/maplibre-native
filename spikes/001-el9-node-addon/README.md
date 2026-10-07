# 001 — EL9/EL10 MapLibre Native Node-addon builds

## Question

Given the current MapLibre Native source plus the spike's Node callback and ABI-bound changes, when it is built separately in Rocky Linux 9.8 and Rocky Linux 10.2 containers, do both builds produce a native `mbgl.node` that loads and renders under matching Node and passes the Node addon suite without Ubuntu runtime-library dependencies?

## Scope

- This is a fork-only feasibility spike on `rl9-dev`, not the separate upstream-based `el9-node-build` worktree.
- Build separately in pinned Rocky 9.8 and Rocky 10.2 containers on the private EL9 runner; the host OS is not the binary target.
- Do not modify TileServer GL, the RBT projection patch, production images, or services.
- The spike retains a maximum Node ABI of 137; that experimental bound is not an upstream portability change.

## CI gates

The `rl9-addon.yml` push workflow runs in order: compile Rocky 9, compile Rocky 10, prepare both test images, smoke-test both, then run the full Node JS suite on both. Each test image has checksum-verified Node 22.23.1 (module ABI 127) and npm dependencies installed using `npm ci --ignore-scripts`. The test-only image installs `xwayland-run`, Xwayland and Weston when that stack is packaged; otherwise it installs Xvfb. The test wrapper prefers `xwfb-run -c weston` when installed and falls back to `xvfb-run --auto-servernum`. EL10 no longer packages Xvfb in the checked repositories, so it uses `xwfb-run` with Xwayland on a headless Weston compositor; EL9 retains the Xvfb fallback. The packaged `xwfb-run --help` confirms `-c weston` selects the installed backend and `--auto-servernum` is unused. This is only an X11 test harness change, not a renderer/backend change. Node, the addon and all linked runtime libraries stay in their distro-specific container. The smoke test checks `ldd` for missing libraries, loads the local `mbgl.node` through the package's `index.js`, and renders a 64 × 64 background style. The full test runs the selected wrapper around `npm test` (`tape test/js/**/*.test.js`) with a TTY and propagates its exit status.

The 127/131/137 addon binaries are built for each distro, but only ABI 127 is runtime-loaded and exercised here. Build images remain in the runner-owned Podman store; this workflow does not publish downloadable artifacts or validate TileServer GL integration.

## Verdict

The previous CI run compiled both Rocky 9.8 and Rocky 10.2 addons but stopped at the old EL10 test-image Xvfb package install. In a subsequent targeted preflight on `ghbuilder-03`, the cached compiled images were reused: the EL9 test image ran the updated wrapper with `xvfb-run --auto-servernum`, rendered 16,384 bytes, and passed all 185 Node JS tests (exit 0). A disposable EL10 test image built from the cached EL10 compiler image installed `xwayland-run`, Xwayland, Weston and checksum-verified Node 22.23.1; the updated wrapper ran with `xwfb-run -c weston`, rendered 16,384 bytes, and passed all 185 Node JS tests (exit 0). The test image build and script were preflighted independently of the repo's push workflow; a new CI run on the modified commit, downloadable artifact delivery, native C++ tests and TileServer GL integration remain unverified. Do not infer those gates from this Node suite.
