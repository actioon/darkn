#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

# Files are authored on Windows, so set the executable bits here.
chmod 0755 /usr/libexec/darkn-user-setup /usr/libexec/darkn-groups /usr/libexec/darkn-flatpak-extra
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
    postgresql \
    mariadb \
    sqlite \
    ripgrep \
    jq \
    unzip \
    zip \
    xz \
    fuse-libs \
    plasma-smart-video-wallpaper-reborn \
    wl-clipboard \
    dotool \
    gtk-layer-shell

### Voice typing (speech to text)
# Handy: offline dictation into any app, with the Cohere Transcribe Arabic
# model for Arabic and mixed Arabic/English speech. Pinned to an exact
# release and checksum; bump both to update.
# It pastes through the clipboard (wl-clipboard) and sends Ctrl+V with dotool.
HANDY_VERSION="0.10.0"
HANDY_SHA256="2c77658d4939fbaeb82e168830d549b758d954e23e387a50017112dbc2735992"
curl -fL --retry 3 -o /tmp/handy.rpm \
    "https://github.com/cjpais/Handy/releases/download/v${HANDY_VERSION}/Handy-${HANDY_VERSION}-1.x86_64.rpm"
echo "${HANDY_SHA256}  /tmp/handy.rpm" | sha256sum -c -
dnf5 install -y --nogpgcheck /tmp/handy.rpm
command -v handy
command -v kate

### Live wallpapers
# Video wallpapers come from Fedora's plasma-smart-video-wallpaper-reborn
# (installed above). Interactive ones are handled by waywallen: the app is a
# Flatpak (see darkn.preinstall) and this is its Plasma wallpaper plugin,
# pinned to an exact release and checksum.
WAYWALLEN_KDE_VERSION="0.4.6"
WAYWALLEN_KDE_SHA256="f98647b301d16c00f711adc7dcbf8ca6d23f237fad1835f13916079ad9c032ce"
curl -fL --retry 3 -o /tmp/waywallen-kde.zip \
    "https://github.com/waywallen/waywallen-display/releases/download/v${WAYWALLEN_KDE_VERSION}/waywallen-kde-${WAYWALLEN_KDE_VERSION}-x86_64.zip"
echo "${WAYWALLEN_KDE_SHA256}  /tmp/waywallen-kde.zip" | sha256sum -c -
unzip -q /tmp/waywallen-kde.zip -d /usr/share/plasma/wallpapers/
test -f /usr/share/plasma/wallpapers/org.waywallen.kde/metadata.json
chmod -R u=rwX,go=rX /usr/share/plasma/wallpapers/org.waywallen.kde

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
systemctl enable darkn-flatpak-extra.service
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
psql --version
mariadb --version
grep -q '^GPGKey=' /usr/share/darkn/artcraft-oci.flatpakrepo
bash -n /usr/libexec/darkn-flatpak-extra
command -v rustup-init
command -v code
command -v docker
command -v git
command -v gh
command -v flatpak
bash -n /usr/libexec/darkn-user-setup
bash -n /usr/libexec/darkn-groups
test -x /usr/libexec/ublue-brew-trust-brewfile
