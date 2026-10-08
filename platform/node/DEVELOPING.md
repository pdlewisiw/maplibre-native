# Developing the MapLibre Native Node.js module

This document explains how to build the [Node.js](https://nodejs.org/) bindings for [MapLibre Native](../../README.md) for contributing to the development of the bindings themselves. If you just want to use the module, you can simply install it via `npm`; see [README.md](README.md) for installation and usage instructions.

## Building

To develop these bindings, you’ll need to build them from source. Building requires the prerequisites listed in either
the [macOS](../macos/INSTALL.md#requirements), [Linux](../linux/README.md#prerequisites), or [Windows](../windows/README.md#prerequisites) install documentation, depending
on the target platform.

First you'll need to install dependencies:


#### MacOS

```bash
brew install \
  cmake \
  ccache \
  ninja \
  pkg-config \
  glfw3 \
  libuv
```

#### Linux (Debian and Ubuntu)

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  clang \
  cmake \
  ccache \
  ninja-build \
  pkg-config \
  libcurl4-openssl-dev \
  libglfw3-dev \
  libuv1-dev \
  libpng-dev \
  libicu-dev \
  libjpeg-dev \
  libwebp-dev \
  libx11-dev \
  libgl-dev \
  xvfb
if [ -x /usr/sbin/update-ccache-symlinks ]; then
  sudo /usr/sbin/update-ccache-symlinks
fi
```

`libjpeg-dev` is the distribution's development-package name; the underlying JPEG
implementation can vary. Package names for other Linux families are not interchangeable.

#### Linux (Rocky Linux 9 and 10)

Enable Rocky's CRB development repository before installing build dependencies:

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --set-enabled crb
sudo dnf install -y \
  clang cmake gcc gcc-c++ git ninja-build pkgconf-pkg-config \
  libcurl-devel libicu-devel libjpeg-turbo-devel libpng-devel \
  libuv-devel libwebp-devel libX11-devel mesa-libGL-devel
```

Other Enterprise Linux derivatives may name or enable their development repositories
differently; check their package sources rather than assuming the Rocky commands apply.
Install a headless display runner separately when running the Node tests; it is not
required to compile the addon.

### Compiling

To compile the Node.js bindings and install module dependencies, from the repository root directory, first run:

#### MacOS

```bash
cmake . -B build -G Ninja -DMLN_WITH_NODE=ON -DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DCMAKE_BUILD_TYPE=Release -DMLN_WITH_OPENGL=OFF -DMLN_WITH_METAL=ON -DMLN_WITH_WERROR=OFF
```

#### Linux

For a server-side Node addon build without GLFW, use the existing Linux Node preset.
It selects `clang`/`clang++` (included in the package lists above) without
hard-coding a compiler version; the launcher override allows building without
`ccache` if that optional tool is not installed:

```bash
cmake --preset linux-opengl-node -DMLN_WITH_GLFW=OFF -DCMAKE_CXX_COMPILER_LAUNCHER=
```

Keep `MLN_WITH_GLFW` enabled if building the GLFW example targets. To use `ccache`,
omit the empty launcher override. On all Linux distributions, CMake still requires
the development libraries listed above; this option does not change the JPEG, ICU,
or OpenGL dependencies of the addon.

### Building

Finally, build:
```bash
cmake --build build -j "$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null)"
```

## Testing

To test the Node.js bindings:

```bash
npm test
```

## Merging your pull request

To clean up your pull request and prepare it for merging, update your local `main` branch, then run `git rebase -i main` from your pull request branch to squash/fixup commits as needed. When your work is ready to be merged, you can run `git merge --ff-only YOUR_BRANCH` from `main` or click the green merge button in the GitHub UI, which will automatically squash your branch down into a single commit before merging it.

## Publishing
See [`RELEASE.md`](RELEASE.md) for instructions on publishing a node release.
