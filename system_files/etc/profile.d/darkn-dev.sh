# Darkn OS developer environment.
# /usr is read-only on an image-based system, so per-user tools live in $HOME.

# npm -g installs into ~/.local instead of /usr
export NPM_CONFIG_PREFIX="${HOME}/.local"

# Flutter SDK location used by the Darkn OS installer
export FLUTTER_ROOT="${HOME}/.local/share/flutter"

_darkn_path_add() {
    case ":${PATH}:" in
        *":$1:"*) ;;
        *) [ -d "$1" ] && PATH="$1:${PATH}" ;;
    esac
}

_darkn_path_add "${HOME}/.local/bin"
_darkn_path_add "${HOME}/.cargo/bin"
_darkn_path_add "${FLUTTER_ROOT}/bin"
_darkn_path_add "${HOME}/.pub-cache/bin"
export PATH

unset -f _darkn_path_add
