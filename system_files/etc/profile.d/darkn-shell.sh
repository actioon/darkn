# Darkn OS: a nicer interactive terminal.
# Git-aware prompt (starship), smart directory jumping (zoxide: "z name"),
# fuzzy history and file search (fzf: Ctrl+R, Ctrl+T), and Aurora's aliases
# for eza and bat. Everything is skipped quietly if a tool is missing.

# Interactive bash only.
[ -n "${BASH_VERSION:-}" ] || return 0
case "$-" in
    *i*) ;;
    *) return 0 ;;
esac

if [ -r /usr/share/ublue-os/bling/bling.sh ]; then
    . /usr/share/ublue-os/bling/bling.sh
fi

if command -v starship >/dev/null 2>&1 && [ -z "${STARSHIP_SHELL:-}" ]; then
    eval "$(starship init bash)"
fi

if command -v zoxide >/dev/null 2>&1 && ! type __zoxide_z >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --bash 2>/dev/null)"
fi
