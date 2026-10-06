# 001 — EL9/EL10 MapLibre Native Node-addon builds

## Question

Given the current MapLibre Native source plus the spike's Node callback and ABI-bound changes, when it is built separately in Rocky Linux 9.8 and Rocky Linux 10.2 containers, do both builds produce a native `mbgl.node` that loads and renders under matching Node and passes the Node addon suite without Ubuntu runtime-library dependencies?

## Scope

- This is a fork-only feasibility spike on `rl9-dev`, not the separate upstream-based `el9-node-build` worktree.
- Build separately in pinned Rocky 9.8 and Rocky 10.2 containers on the private EL9 runner; the host OS is not the binary target.
- Do not modify TileServer GL, the RBT projection patch, production images, or services.
- The spike retains a maximum Node ABI of 137; that experimental bound is not an upstream portability change.

## CI gates

The `rl9-addon.yml` push workflow runs in order: compile Rocky 9, compile Rocky 10, prepare both test images, smoke-test both, then run the full Node JS suite on both. A test image has checksum-verified Node 22.23.1 (module ABI 127), npm dependencies installed using `npm ci --ignore-scripts`, and Xvfb. The smoke test checks `ldd` for missing libraries, loads the local `mbgl.node` through the package's `index.js`, and renders a 64 × 64 background style. The full test uses `npm test` (`tape test/js/**/*.test.js`) under Xvfb with a TTY and propagates its exit status.

The 127/131/137 addon binaries are built for each distro, but only ABI 127 is runtime-loaded and exercised here. Build images remain in the runner-owned Podman store; this workflow does not publish downloadable artifacts or validate TileServer GL integration.

## Verdict

Rocky 9.8 compilation and `ldd` completed in the previous CI run. Rocky 10.2 compilation, matching-Node load/render and both full suites remain unverified until the expanded workflow completes. Interpret each gate separately; do not claim tests or artifact delivery from a successful image build alone.
