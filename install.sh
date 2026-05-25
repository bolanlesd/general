#!/usr/bin/env bash
# Sets up dotfile symlinks, ~/.zshrc bootstrap, bin/general on PATH,
# and git hooks. Idempotent — existing files are backed up with a timestamp.
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
# Detect whether ~/.zshrc is our template (any version) by looking for the
# `git/general` repo path marker — broader than the old `local_copy_zshrc` grep.
if [[ ! -f "$HOME/.zshrc" ]] || ! grep -q "git/general" "$HOME/.zshrc" 2>/dev/null; then
    backup_if_exists "$HOME/.zshrc"
    cp "$REPO_DIR/shell/zshrc.local.template" "$HOME/.zshrc"
    echo "  installed ~/.zshrc from template"
else
    echo "  ~/.zshrc already uses the bootstrap template; leaving as-is"
fi

echo "Ensuring ~/.zshrc.local exists for per-machine overrides..."
[[ -f "$HOME/.zshrc.local" ]] || { touch "$HOME/.zshrc.local"; echo "  created empty ~/.zshrc.local"; }

echo "Linking bin/general onto PATH..."
mkdir -p "$HOME/.local/bin"
chmod +x "$REPO_DIR/bin/general"
link "$REPO_DIR/bin/general" "$HOME/.local/bin/general"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "  ⚠️  $HOME/.local/bin not on PATH — add: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

echo "Installing git pre-commit hook..."
HOOK_DIR="$REPO_DIR/.git/hooks"
if [[ -d "$HOOK_DIR" ]]; then
    backup_if_exists "$HOOK_DIR/pre-commit"
    chmod +x "$REPO_DIR/scripts/git-hooks/pre-commit"
    ln -s "$REPO_DIR/scripts/git-hooks/pre-commit" "$HOOK_DIR/pre-commit"
    echo "  linked $HOOK_DIR/pre-commit"
fi

echo "Building dist/zshrc..."
bash "$REPO_DIR/scripts/build-zshrc.sh"

echo "Done. Open a new shell or run: source ~/.zshrc"
echo "Then run: general doctor"
