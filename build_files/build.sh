#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -af "/ctx/system_files"/. /

# Files are authored on Windows, so set the executable bits here.
chmod 0755 /usr/libexec/darkn-installer /usr/bin/darkn-welcome /usr/libexec/darkn-backup /usr/libexec/darkn-groups /usr/libexec/darkn-flatpak-extra \
    /usr/libexec/darkn-launch /usr/libexec/darkn-ocr /usr/libexec/darkn-colorpick \
    /usr/libexec/darkn-unzip-ar /usr/libexec/darkn-mount-ntfs /usr/libexec/darkn-update-notify
# darkn-setup reopens the setup wizard; darkn-backup is the backup tool.
ln -sf /usr/bin/darkn-welcome /usr/bin/darkn-setup
ln -sf /usr/libexec/darkn-backup /usr/bin/darkn-backup

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
    gtk-layer-shell \
    yakuake \
    tesseract \
    tesseract-langpack-eng \
    tesseract-langpack-ara

# dotool's install script reloads udev, which cannot work inside an image
# build, so install it without running scripts. Its udev rule is a plain file.
dnf5 install -y --setopt=tsflags=noscripts dotool
command -v dotool

### Arabic language support
# Locale, spell checking and a full set of Arabic fonts: Noto for the
# interface, Amiri and Scheherazade for documents, plus the faces Arabic
# web and print design relies on.
dnf5 install -y \
    glibc-langpack-ar \
    hunspell-ar \
    fribidi \
    google-noto-sans-arabic-vf-fonts \
    google-noto-sans-arabic-ui-vf-fonts \
    google-noto-naskh-arabic-vf-fonts \
    google-noto-kufi-arabic-vf-fonts \
    amiri-fonts \
    amiri-quran-fonts \
    sil-scheherazade-new-fonts \
    sil-lateef-fonts \
    vazirmatn-vf-fonts \
    ibm-plex-sans-arabic-fonts

# Popular Arabic typefaces that Fedora does not package, taken from the
# Google Fonts repository (all under the SIL Open Font License) at a pinned
# commit, so the content is fixed by the commit hash.
GFONTS_COMMIT="5bb28733cec313b63fbd415b574b5ae35c8aa8b8"
GFONTS_FAMILIES=(cairo tajawal almarai changa elmessiri reemkufi arefruqaa markazitext readexpro)
git init -q /tmp/gfonts
git -C /tmp/gfonts remote add origin https://github.com/google/fonts.git
git -C /tmp/gfonts sparse-checkout set "${GFONTS_FAMILIES[@]/#/ofl/}"
git -C /tmp/gfonts fetch -q --depth 1 --filter=blob:none origin "${GFONTS_COMMIT}"
git -C /tmp/gfonts checkout -q FETCH_HEAD
test "$(git -C /tmp/gfonts rev-parse HEAD)" = "${GFONTS_COMMIT}"
for family in "${GFONTS_FAMILIES[@]}"; do
    install -d "/usr/share/fonts/darkn-arabic/${family}"
    install -m 0644 /tmp/gfonts/ofl/"${family}"/*.ttf "/usr/share/fonts/darkn-arabic/${family}/"
    install -m 0644 /tmp/gfonts/ofl/"${family}"/OFL.txt "/usr/share/fonts/darkn-arabic/${family}/"
done
rm -rf /tmp/gfonts

# Flatpak apps do not read /etc/fonts, but they do read the user's own
# fontconfig directory, so give every new user the same Arabic font rules.
install -D -m 0644 /etc/fonts/conf.d/56-darkn-arabic.conf /etc/skel/.config/fontconfig/conf.d/56-darkn-arabic.conf

fc-cache -f
fc-list :lang=ar family | grep "Noto Sans Arabic" >/dev/null || echo "WARNING: font check failed: fc-list :lang=ar family | grep "Noto Sans Arabic" >/dev/null" | tr -d "\"" >&2
fc-scan --format "%{family}
" /usr/share/fonts/darkn-arabic/cairo/ || true
fc-list : file | grep -c darkn-arabic || echo "WARNING: darkn-arabic fonts are not visible to fontconfig" >&2
fc-match "Traditional Arabic" | grep -i "amiri" >/dev/null || echo "WARNING: font alias check failed" >&2
locale -a | grep -i '^ar_EG' >/dev/null

### Keyboard shortcuts and quick tools
# Shortcuts are declared in /usr/share/applications/darkn-*.desktop
# (X-KDE-Shortcuts) and /etc/skel/.config/kglobalshortcutsrc; the reference
# page is /usr/share/darkn/shortcuts.html.
# Yakuake is the drop-down terminal on F12; it has to be running to answer.
install -D -m 0644 /usr/share/applications/org.kde.yakuake.desktop /etc/xdg/autostart/org.kde.yakuake.desktop
command -v spectacle
command -v tesseract
tesseract --list-langs | grep -x ara >/dev/null

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
# Flatpak (offered by the setup wizard) and this is its Plasma wallpaper plugin,
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

### System settings
# Terminal tools, the GitHub CLI and NTFS repair tools.
dnf5 install -y gh fzf zoxide bat eza ntfsprogs

# KDE reads /usr/share/kde-settings/kde-profile before /etc/xdg, and Aurora
# keeps its defaults there, so Darkn's desktop defaults go to the same place.
KDE_PROFILE="/usr/share/kde-settings/kde-profile/default/xdg"
kset() {
    local file="$1"
    shift
    HOME=/tmp kwriteconfig6 --file "${KDE_PROFILE}/${file}" "$@"
}

# Password at login, but no automatic screen lock (Meta+L locks by hand).
kset kscreenlockerrc --group Daemon --key Autolock false
kset kscreenlockerrc --group Daemon --key LockOnResume true

# Nothing turns off on its own: no dimming, no screen off, no sleep.
kset powerdevilrc --group AC --group Display --key DimDisplayWhenIdle false
kset powerdevilrc --group AC --group Display --key TurnOffDisplayWhenIdle false
kset powerdevilrc --group AC --group SuspendAndShutdown --key AutoSuspendAction 0

# Reopen the apps that were running at the last logout.
kset ksmserverrc --group General --key loginMode restorePreviousLogout

# NumLock on (0 = on, 1 = off, 2 = leave unchanged).
kset kcminputrc --group Keyboard --key NumLock 0

# Mute notifications while sharing the screen or using a fullscreen app.
kset plasmanotifyrc --group DoNotDisturb --key WhenScreenSharing true
kset plasmanotifyrc --group DoNotDisturb --key WhenFullscreen true

# English interface with a 12-hour clock, metric units and A4 paper.
kset plasma-localerc --group Formats --key LANG en_US.UTF-8
kset plasma-localerc --group Formats --key LC_MEASUREMENT en_GB.UTF-8
kset plasma-localerc --group Formats --key LC_PAPER en_GB.UTF-8

# File manager: one set of view settings for every folder (see /etc/skel).
kset dolphinrc --group General --key GlobalViewProps true

grep -q '^Autolock=false' "${KDE_PROFILE}/kscreenlockerrc"

# Default time zone; the installer can still change it.
ln -sf ../usr/share/zoneinfo/Africa/Cairo /etc/localtime

# Updates are announced, not applied automatically: the user decides when.
systemctl disable uupd.timer
systemctl disable brew-update.timer brew-upgrade.timer || true
systemctl --global enable darkn-update-notify.timer

# Windows data drives (NTFS) are mounted at boot.
systemctl enable darkn-mount-ntfs.service

### Hardware control: RGB lighting and Razer devices
# OpenRGB drives motherboard, RAM, cooler and peripheral lighting. Aurora
# already ships its udev rules; board and RAM lighting also need the I2C
# modules loaded (see /etc/modules-load.d/darkn-rgb.conf).
dnf5 install -y openrgb i2c-tools

# OpenRazer: the kernel module is the one Universal Blue builds and signs
# for this exact kernel; the daemon comes from the OpenRazer project's repo,
# which is then switched off so it is not used for anything else.
dnf5 config-manager addrepo \
    --from-repofile="https://download.opensuse.org/repositories/hardware:/razer/Fedora_$(rpm -E %fedora)/hardware:razer.repo"
dnf5 install -y /akmods-rpms/kmods/*openrazer*.rpm openrazer-daemon
dnf5 config-manager setopt hardware_razer.enabled=0
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -n1)"
find "/usr/lib/modules/${KERNEL_VERSION}" -name 'razer*.ko*' | grep . >/dev/null

### Fonts
# Coding, interface and document fonts, so nothing has to be added later.
# Carlito is metric-compatible with Calibri; Liberation covers Arial,
# Times New Roman and Courier New.
dnf5 install -y \
    jetbrains-mono-fonts-all \
    fira-code-fonts \
    cascadia-code-fonts \
    cascadia-mono-fonts \
    adobe-source-code-pro-fonts \
    ibm-plex-mono-fonts \
    ibm-plex-sans-fonts \
    google-roboto-fonts \
    google-roboto-mono-fonts \
    open-sans-fonts \
    google-carlito-fonts \
    liberation-fonts-all \
    google-noto-color-emoji-fonts

# JetBrains Mono Nerd Font: the coding font with the icon glyphs that the
# terminal prompt and file listings use. Pinned release and checksum.
NERD_FONTS_VERSION="3.5.1"
NERD_FONTS_SHA256="04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf"
curl -fL --retry 3 -o /tmp/JetBrainsMono.tar.xz \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONTS_VERSION}/JetBrainsMono.tar.xz"
echo "${NERD_FONTS_SHA256}  /tmp/JetBrainsMono.tar.xz" | sha256sum -c -
install -d /usr/share/fonts/darkn-nerd-fonts
tar -xJf /tmp/JetBrainsMono.tar.xz -C /usr/share/fonts/darkn-nerd-fonts --wildcards '*.ttf' 'OFL.txt'
fc-cache -f
fc-list family | grep "JetBrainsMono Nerd Font" >/dev/null || echo "WARNING: font check failed: fc-list family | grep "JetBrainsMono Nerd Font" >/dev/null" | tr -d "\"" >&2
fc-list family | grep "Inter" >/dev/null || echo "WARNING: font check failed: fc-list family | grep "Inter" >/dev/null" | tr -d "\"" >&2

### Per-app notification sounds
# darkn-notify-soundd plays the sound a user assigned to an app or a group
# of apps; darkn-notification-sounds is its settings window (PyQt6).
# The sound themes give a good set of sounds to choose from.
dnf5 install -y python3-pyqt6 pipewire-utils ocean-sound-theme oxygen-sounds sound-theme-freedesktop \
    rsms-inter-vf-fonts
chmod 0755 /usr/libexec/darkn-notify-soundd /usr/bin/darkn-notification-sounds
systemctl --global enable darkn-notify-sound.service
python3 -m py_compile /usr/libexec/darkn-notify-soundd /usr/bin/darkn-notification-sounds
find /usr/libexec /usr/bin -maxdepth 1 -name '__pycache__' -exec rm -rf {} +
python3 -c "import PyQt6.QtWidgets, PyQt6.QtSvg"
command -v pw-play
command -v busctl

### Setup wizard, install engine and backups
# Nothing is installed behind the user's back: the wizard (darkn-welcome)
# shows the catalog, and darkn-installer installs only what was chosen.
# The user service resumes an install that was interrupted.
dnf5 install -y restic pciutils dbus-tools mokutil
python3 -m json.tool /usr/share/darkn/catalog.json >/dev/null
python3 -m py_compile /usr/libexec/darkn-installer /usr/bin/darkn-welcome
find /usr/libexec /usr/bin -maxdepth 1 -name '__pycache__' -exec rm -rf {} +
command -v restic
command -v lspci

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
bash -n /usr/libexec/darkn-backup
bash -n /usr/libexec/darkn-groups
test -x /usr/libexec/ublue-brew-trust-brewfile
