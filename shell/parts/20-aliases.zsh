# 20-aliases.zsh — small everyday aliases
alias ms="minikube start; minikube addons enable ingress"
alias getmyip="curl ifconfig.me"
alias rb="source ~/.zshrc"
alias tgo="tmux new -s seun"
alias fn="find -name $1"
alias lsd="ls -d */ | xargs du -chs | grep -v total"
alias gr="cd \$(git rev-parse --show-toplevel)"
alias ocp="pbcopy"
alias yt-dl="bash ~/git/general/scripts/youtube-download.sh"
alias rts="find . -not -path '*/\.*' | xargs -I {} sed -i '' 's/[[:space:]]*\$//' {}"

# Prefer Cursor when available, fall back to VS Code
if command -v cursor &>/dev/null; then
  alias edit="cursor --wait"
else
  alias edit="code --wait"
fi
