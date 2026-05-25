# 30-git.zsh — git aliases and helpers
alias gl="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'"
alias gdm="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' master.."
alias gs="git status"
alias gat="git ls-files --modified | xargs git add"
alias gaa="git add -u"
alias gb="git branch | grep \"*\" | cut -d ' ' -f2"

# desc: gco <prefix> <msg...> — commit as "<prefix>: <branch>: <msg>"
gco() {
  local BRANCH=$(gb)
  local FUNCTION=$1
  local COMMENT="${@:2}"
  git commit -m "$FUNCTION: $BRANCH: $COMMENT"
}

# desc: gg <text> — case-insensitive git grep from repo root
gg() {
  local TEXT="${@:1}"
  git grep -i -n "$TEXT" -- "$(git rev-parse --show-toplevel)"
}
