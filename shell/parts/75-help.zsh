# 75-help.zsh — self-documenting help system
# Convention: define functions with a leading "# desc:" comment on the line
# above the function. `help` greps these descriptions across all modules.

# desc: help [pattern] — list custom functions/aliases (optionally filtered)
help() {
  local pattern="${1:-}"
  local parts_dir="$HOME/git/general/shell/parts"
  echo "── general: custom functions ──"
  awk '
    /^# desc:/ { desc = substr($0, 9); next }
    /^[a-zA-Z_][a-zA-Z0-9_]*\(\)|^function [a-zA-Z_][a-zA-Z0-9_]*/ {
      name = $0
      sub(/^function /, "", name)
      sub(/[ (].*$/, "", name)
      if (desc != "") {
        printf "  %-20s  %s\n", name, desc
        desc = ""
      } else {
        printf "  %-20s  (no description)\n", name
      }
    }
    /^[^#]/ && !/\(\)/ { desc = "" }
  ' "$parts_dir"/*.zsh 2>/dev/null | { [ -n "$pattern" ] && grep -i "$pattern" || cat; }

  echo
  echo "── general: aliases ──"
  awk '
    /^alias [a-zA-Z_][a-zA-Z0-9_-]*=/ {
      line = $0
      sub(/^alias /, "", line)
      name = line; sub(/=.*$/, "", name)
      val  = line; sub(/^[^=]*=/, "", val)
      printf "  %-15s -> %s\n", name, val
    }
  ' "$parts_dir"/*.zsh 2>/dev/null | { [ -n "$pattern" ] && grep -i "$pattern" || cat; }
}

# desc: fhelp — fuzzy-pick a function and print its source (requires fzf)
fhelp() {
  command -v fzf &>/dev/null || { echo "fzf not installed"; return 1; }
  local parts_dir="$HOME/git/general/shell/parts"
  local choice
  choice=$(grep -hE '^(function +[a-zA-Z_]|[a-zA-Z_][a-zA-Z0-9_]*\(\))' "$parts_dir"/*.zsh \
    | sed -E 's/^function +//; s/[ (].*$//' | sort -u | fzf) || return
  which "$choice"
}
