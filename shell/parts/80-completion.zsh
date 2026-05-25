# 80-completion.zsh — kubectl completion + teleport CLI
if command -v kubectl &>/dev/null; then
  autoload -Uz compinit && compinit
  source <(kubectl completion zsh)
fi

if [[ -f /opt/homebrew/share/th/th.sh ]]; then
  source /opt/homebrew/share/th/th.sh
fi
