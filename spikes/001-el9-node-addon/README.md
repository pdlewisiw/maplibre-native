# 001 — EL9/EL10 MapLibre Native Node-addon builds

## Question

Given the current upstream MapLibre Native source with all pinned submodules, when it is built separately in Rocky Linux 9.8 and Rocky Linux 10 containers using the upstream `linux-opengl-node` CMake preset, does each build produce a native `mbgl.node` without Ubuntu runtime-library dependencies?

## Scope

- Builder-only feasibility test for both EL9 and EL10.
- Uses the unmodified upstream source on branch `rbt/el9-node-addon-spike`.
- Does not modify TileServer GL, the RBT projection patch, production images, or services.
- The first run deliberately validates EL package availability and CMake configuration before adding a Node runtime/render test.

## Observable checks

1. `cmake --preset linux-opengl-node` configures successfully on both EL majors.
2. Each build produces `platform/node/lib/node-v*/mbgl.node`.
3. `ldd` on each produced addon has no unresolved dependency.

## Verdict

Pending first container build.
