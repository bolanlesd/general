# 70-misc.zsh — small utilities + cross-platform updateall + python venv helpers

# desc: ppc <csv-file> — pretty-print a CSV file as aligned columns
ppc() { column -t -s, "$1"; }

# desc: hc <n> — capture the Nth-from-last history command into $COMMAND
hc() {
  COMMAND=$(history | tail -n $1 | head -n1 | awk '{$1="";print substr($0,2)}')
}

# desc: updateall — cross-platform update everything (brew / apt / dnf)
updateall() {
  if command -v brew &>/dev/null; then
    echo "🍺 brew update && upgrade..."
    brew update && brew upgrade && brew cleanup
  elif command -v apt &>/dev/null; then
    echo "📦 apt update + full-upgrade..."
    sudo apt update && sudo apt upgrade -y && sudo apt full-upgrade -y
    command -v snap &>/dev/null && sudo snap refresh
  elif command -v dnf &>/dev/null; then
    echo "📦 dnf upgrade..."
    sudo dnf upgrade -y
  else
    echo "❌ No supported package manager found (brew/apt/dnf)." >&2
    return 1
  fi
}

# desc: create_venv — make + activate ./myenv with requests/packaging preinstalled
function create_venv() {
  echo "🐍 Creating virtual environment..."
  python3 -m venv myenv
  echo "✅ Activating virtual environment..."
  source myenv/bin/activate
  echo "📦 Installing dependencies..."
  pip3 install requests packaging
}

# desc: cleanup_venv — deactivate and rm -rf ./myenv
function cleanup_venv() {
  echo "🧹 Cleaning up virtual environment..."
  deactivate 2>/dev/null
  rm -rf myenv
  echo "✅ Process completed."
}
