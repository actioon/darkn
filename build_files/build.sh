#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

# Files are authored on Windows, so set the executable bits here.
chmod 0755 /usr/libexec/darkn-user-setup /usr/libexec/darkn-groups
ln -sf /usr/libexec/darkn-user-setup /usr/bin/darkn-setup

### Programming languages and build tools
# The base image (aurora-dx-nvidia-open) already ships VS Code, Docker,
# git, gh, android-tools and the NVIDIA driver. This adds the toolchains.

dnf5 install -y \
    nodejs24 \
    nodejs24-npm \
    pnpm \
    java-25-openjdk-devel \
    dotnet-sdk-10.0 \
    rustup \
    gcc \
    gcc-c++ \
    clang \
    gdb \
    make \
    cmake \
    ninja-build \
    pkgconf-pkg-config \
    python3-pip \
    uv \
    kubernetes1.36-client \
    sqlite \
    ripgrep \
    jq \
    unzip \
    zip \
    xz \
    fuse-libs

# Fedora ships versioned Node.js binaries (node-24). Make sure the plain
# `node`, `npm` and `npx` commands exist.
for tool in node npm npx; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        ln -s "/usr/bin/${tool}-24" "/usr/bin/${tool}"
    fi
done

### Image signature policy
# Only accept Darkn OS images that are signed with our cosign key, the same
# way Aurora verifies its own images.
install -D -m 0644 /ctx/cosign.pub /usr/lib/pki/containers/darkn.pub
jq '.transports.docker["ghcr.io/actioon/darkn"] = [{
        "type": "sigstoreSigned",
        "keyPath": "/usr/lib/pki/containers/darkn.pub",
        "signedIdentity": {"type": "matchRepository"}
    }]' /etc/containers/policy.json >/tmp/policy.json
install -m 0644 /tmp/policy.json /etc/containers/policy.json
jq -e '.transports.docker["ghcr.io/actioon/darkn"][0].type == "sigstoreSigned"' /etc/containers/policy.json

### Services
systemctl enable podman.socket
systemctl enable darkn-groups.service
systemctl --global enable darkn-user-setup.service

### Sanity checks: fail the build if a toolchain is missing
node --version
npm --version
pnpm --version
java -version
javac -version
DOTNET_CLI_HOME=/tmp DOTNET_CLI_TELEMETRY_OPTOUT=1 dotnet --list-sdks
gcc --version
g++ --version
cmake --version
python3 --version
uv --version
kubectl version --client
command -v rustup-init
command -v code
command -v docker
command -v git
command -v gh
command -v flatpak
bash -n /usr/libexec/darkn-user-setup
bash -n /usr/libexec/darkn-groups
test -x /usr/libexec/ublue-brew-trust-brewfile
