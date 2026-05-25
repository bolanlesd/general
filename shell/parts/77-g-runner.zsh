# 77-g-runner.zsh — `g <script>` runs anything from ~/git/general/scripts/
# desc: g <script> — run a script from ~/git/general/scripts (tab-completes)
g() {
  local scripts_dir="$HOME/git/general/scripts"
  if [ -z "$1" ]; then
    echo "Usage: g <script-name> [args...]"
    echo "Available scripts:"
    find "$scripts_dir" -type f \( -name '*.sh' -o -name '*.py' \) 2>/dev/null \
      | sed "s|$scripts_dir/||" | sort | sed 's/^/  /'
    return 1
  fi
  local name="$1"; shift
  local candidates=(
    "$scripts_dir/$name"
    "$scripts_dir/$name.sh"
    "$scripts_dir/$name.py"
  )
  local found
  for f in "${candidates[@]}"; do
    if [ -f "$f" ]; then found="$f"; break; fi
  done
  if [ -z "$found" ]; then
    found=$(find "$scripts_dir" -type f \( -name "$name" -o -name "$name.sh" -o -name "$name.py" \) 2>/dev/null | head -1)
  fi
  if [ -z "$found" ]; then
    echo "g: script '$name' not found under $scripts_dir" >&2
    return 1
  fi
  case "$found" in
    *.py) python3 "$found" "$@" ;;
    *)    bash "$found" "$@" ;;
  esac
}

# tab completion for g
_g_complete() {
  local scripts_dir="$HOME/git/general/scripts"
  local -a names
  names=("${(@f)$(find "$scripts_dir" -type f \( -name '*.sh' -o -name '*.py' \) 2>/dev/null \
    | sed "s|$scripts_dir/||; s|\.sh\$||; s|\.py\$||")}")
  compadd -- "${names[@]}"
}
compdef _g_complete g 2>/dev/null
