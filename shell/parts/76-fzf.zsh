# 76-fzf.zsh — fzf-powered productivity bindings
# Ctrl+G: fuzzy-search aliases/functions, insert the chosen name at the cursor.

if command -v fzf &>/dev/null; then
  _general_fzf_alias_widget() {
    local parts_dir="$HOME/git/general/shell/parts"
    local choice
    choice=$( {
      grep -hE '^alias [a-zA-Z_][a-zA-Z0-9_-]*=' "$parts_dir"/*.zsh 2>/dev/null \
        | sed -E 's/^alias //; s/=.*$//' | sed 's/^/alias  /'
      grep -hE '^(function +[a-zA-Z_]|[a-zA-Z_][a-zA-Z0-9_]*\(\))' "$parts_dir"/*.zsh 2>/dev/null \
        | sed -E 's/^function +//; s/[ (].*$//' | sed 's/^/func   /'
    } | sort -u | fzf --height=40% --reverse) || { zle redisplay; return; }
    LBUFFER+="${choice##* }"
    zle redisplay
  }
  zle -N _general_fzf_alias_widget
  bindkey '^G' _general_fzf_alias_widget
fi
