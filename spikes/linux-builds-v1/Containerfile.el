# EL-family build recipe. Supply a base image with development repositories enabled
# for derivatives that do not call their optional repository "crb".
ARG BASE_IMAGE=docker.io/rockylinux/rockylinux:9.8
ARG BUILD_JOBS=4
FROM ${BASE_IMAGE} AS builder
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /src
ARG BUILD_JOBS
RUN dnf install -y --setopt=install_weak_deps=False dnf-plugins-core \
    && if dnf repolist --all | grep -Eq '^crb[[:space:]]'; then dnf config-manager --set-enabled crb; fi \
    && dnf install -y --setopt=install_weak_deps=False \
      ca-certificates clang cmake gcc gcc-c++ git libcurl-devel libicu-devel \
      libjpeg-turbo-devel libpng-devel libuv-devel libwebp-devel libX11-devel \
      mesa-libGL-devel ninja-build pkgconf-pkg-config tar which \
    && dnf clean all
COPY . /src
RUN cmake --preset linux-opengl-node -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CXX_COMPILER_LAUNCHER= -DMLN_WITH_GLFW=OFF -DNODE_MODULE_MAXIMUM_ABI=137 \
    && cmake --build build --target mbgl-node.abi-127 mbgl-node.abi-131 mbgl-node.abi-137 -j "${BUILD_JOBS}" \
    && for abi in 127 131 137; do \
         addon="platform/node/lib/node-v${abi}/mbgl.node"; \
         test -s "$addon"; \
         echo "=== $addon ==="; \
         ldd "$addon"; \
         ! ldd "$addon" | grep -q 'not found'; \
       done

# Test-only: Node/npm and headless display never enter the builder artifact image.
FROM builder AS test
RUN if dnf -q list --available xwayland-run >/dev/null 2>&1; then \
         dnf install -y --setopt=install_weak_deps=False epel-release \
         && dnf install -y --setopt=install_weak_deps=False xwayland-run xorg-x11-server-Xwayland weston; \
    else \
         dnf install -y --setopt=install_weak_deps=False xorg-x11-server-Xvfb; \
    fi \
    && command -v curl \
    && bash /src/spikes/linux-builds-v1/install-nodes.sh \
    && dnf clean all
ENV PATH="/opt/node-v127/bin:${PATH}"
RUN cd /src/platform/node && npm ci --ignore-scripts
