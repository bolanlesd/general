# =====================
# ZSH-Compatible Config
# =====================

# --- Editor ---
export VISUAL=vim
export EDITOR="$VISUAL"

# --- Git Branch Function (ZSH) ---
git_branch() {
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        echo "($branch)"
    fi
}

# --- Prompt Format ---
autoload -Uz vcs_info
precmd() { vcs_info }
setopt PROMPT_SUBST
PROMPT='%F{yellow}%* %F{blue}%~ %F{green}$(git_branch)%f $ '

# --- Color LS and Grep ---
if type dircolors > /dev/null 2>&1; then
    eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# --- Aliases & Functions ---
alias ms="minikube start; minikube addons enable ingress"
alias getmyip="curl ifconfig.me"
alias gl="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'"
alias gdm="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' master.."
alias gs="git status"
alias gat="git ls-files --modified | xargs git add"
alias gaa="git add -u"
alias gb="git branch | grep \"*\" | cut -d ' ' -f2"
alias tf="terraform"
alias tg="terragrunt run --tf-forward-stdout"
alias tgp="tg plan"
alias tfp="tf plan -out=tf.plan"
alias tfa="tf apply tf.plan"
alias rb="source ~/.zshrc"
alias tgo="tmux new -s seun"
alias fn="find -name $1"
alias lsd="ls -d */ | xargs du -chs | grep -v total"
alias gr="cd $(git rev-parse --show-toplevel)"
alias ocp="pbcopy"
alias rts="find . -not -path '*/\.*' | xargs -I {} sed -i '' 's/[[:space:]]*$//' {}"
alias updateall="brew update && brew upgrade"

gco() {
  local BRANCH=$(gb)
  local FUNCTION=$1
  local COMMENT="${@:2}"
  git commit -m "$FUNCTION: $BRANCH: $COMMENT"
}

tgp() { terragrunt plan; }
tgpt() { terragrunt plan -target="$1"; }

ppc() { column -t -s, "$1"; }

hc() {
  COMMAND=$(history | tail -n $1 | head -n1 | awk '{$1="";print substr($0,2)}')
}

gg() {
  local TEXT="${@:1}"
  git grep -i -n "$TEXT" -- "$(git rev-parse --show-toplevel)"
}

# Example function
awsp() {
  ENV="${1:-default}"
  export AWS_PROFILE="$ENV"
}

# Kubectl completion
if command -v kubectl &>/dev/null; then
  autoload -Uz compinit && compinit
  source <(kubectl completion zsh)
fi

# Load teleport CLI if needed
if [[ -f /opt/homebrew/share/th/th.sh ]]; then
  source /opt/homebrew/share/th/th.sh
fi

echo "✅ Loaded custom zshrc"