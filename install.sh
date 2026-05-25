#!/usr/bin/env bash
# Sets up dotfile symlinks and the ~/.zshrc bootstrap on a fresh machine.
# Idempotent: existing files are backed up with a timestamp suffix.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"

backup_if_exists() {
    local target="$1"
    if [[ -e "$target" && ! -L "$target" ]]; then
        echo "  backing up existing $target -> ${target}.bak.${TS}"
        mv "$target" "${target}.bak.${TS}"
    elif [[ -L "$target" ]]; then
        rm "$target"
    fi
}

link() {
    local src="$1" dst="$2"
    backup_if_exists "$dst"
    ln -s "$src" "$dst"
    echo "  linked $dst -> $src"
}

echo "Linking dotfiles from $REPO_DIR..."
link "$REPO_DIR/dotfiles/vimrc"     "$HOME/.vimrc"
link "$REPO_DIR/dotfiles/tmux.conf" "$HOME/.tmux.conf"

echo "Installing ~/.zshrc bootstrap..."
if [[ ! -f "$HOME/.zshrc" ]] || ! grep -q "local_copy_zshrc" "$HOME/.zshrc" 2>/dev/null; then
    backup_if_exists "$HOME/.zshrc"
    cp "$REPO_DIR/shell/zshrc.local.template" "$HOME/.zshrc"
    echo "  installed ~/.zshrc from template"
else
    echo "  ~/.zshrc already uses the bootstrap template; leaving as-is"
fi

echo "Done. Open a new shell or run: source ~/.zshrc"

