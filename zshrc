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
alias edit="cursor --wait"

gco() {
  local BRANCH=$(gb)
  local FUNCTION=$1
  local COMMENT="${@:2}"
  git commit -m "$FUNCTION: $BRANCH: $COMMENT"
}

#:tgp() { terragrunt plan; }
tgpt() { terragrunt plan -target="$1"; }

ppc() { column -t -s, "$1"; }

hc() {
  COMMAND=$(history | tail -n $1 | head -n1 | awk '{$1="";print substr($0,2)}')
}

gg() {
  local TEXT="${@:1}"
  git grep -i -n "$TEXT" -- "$(git rev-parse --show-toplevel)"
}

function awsp() {
  local ENV="${1:-default}"
  export AWS_PROFILE="$ENV"
  echo "Switched to AWS_PROFILE=$AWS_PROFILE"
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


# --- Clean Terragrunt Cache ---
function cleantgcache() {
  find /hdd/git/live-projects -type d -name ".terra*" -exec rm -rf {} +
}

# --- Create PR (Azure DevOps) ---
function create_pr() {
  if ! command -v az &>/dev/null || ! command -v jq &>/dev/null; then
    echo "Required command(s) 'az' or 'jq' not found." >&2
    return 1
  fi

  if ! git rev-parse --git-dir &>/dev/null; then
    echo "Not a git repository." >&2
    return 1
  fi

  local REPO_NAME BRANCH_NAME TICKET_ID LAST_COMMIT_MESSAGE PR_TITLE PR_DESCRIPTION PR_OUTPUT

  REPO_NAME=$(basename "$(pwd)")
  BRANCH_NAME=$(git branch --show-current)
  TICKET_ID=${1:-$BRANCH_NAME}
  LAST_COMMIT_MESSAGE=$(git log -1 --pretty=%B)
  PR_DESCRIPTION=$(cat .azuredevops/pull_request_template.md)
  PR_TITLE="$LAST_COMMIT_MESSAGE"

  # Use a temp file to safely capture output
  local TMP_OUTPUT
  TMP_OUTPUT=$(mktemp)

  if ! az repos pr create \
    --auto-complete false \
    --repository "$REPO_NAME" \
    --source-branch "$BRANCH_NAME" \
    --target-branch master \
    --description "$PR_DESCRIPTION" \
    --title "$PR_TITLE" \
    --work-items "$TICKET_ID" \
    --output json >"$TMP_OUTPUT" 2>/dev/null; then
    echo "❌ Failed to create Pull Request"
    cat "$TMP_OUTPUT"
    rm -f "$TMP_OUTPUT"
    return 1
  fi

  # Try to extract URL
  if jq -e .url "$TMP_OUTPUT" &>/dev/null; then
    jq -r '"\(.repository.webUrl)/pullrequest/\(.pullRequestId)"' "$TMP_OUTPUT"
  else
    echo "❌ Failed to parse PR output"
    cat "$TMP_OUTPUT"
    rm -f "$TMP_OUTPUT"
    return 1
  fi

  rm -f "$TMP_OUTPUT"
}

# --- Update All (Ubuntu-based Systems) ---
alias updateall="sudo apt update && sudo apt upgrade -y && sudo apt full-upgrade -y && sudo snap refresh"

# --- Terragrunt Permission Extractor ---
function tgperm() {
  if [ "$1" = "destroy" ]; then
    echo "⚠️ Running Terragrunt Plan with Destroy..."
    terragrunt plan -no-color -destroy

    echo "⚠️ Proceeding with Terragrunt destroy. Confirm when prompted..."
    TF_LOG=trace terragrunt destroy &> log_destroy.log

    echo "🔍 Extracting AWS Permissions and ARNs for Destroy..."
    grep -oE "rpc.method=[^ ]*|rpc.service=[^ ]*|arn:[^ ]*" log_destroy.log | sort | uniq > all_destroy_permissions_arns.txt

    awk '
    {
      if ($1 ~ /^rpc.method=/) {
        method = substr($1, 12)
      } else if ($1 ~ /^rpc.service=/) {
        service = substr($1, 13)
        if (method != "") print method " " service
      } else if ($1 ~ /^arn:/) {
        print $1
      }
    }' all_destroy_permissions_arns.txt > extracted_destroy_permissions_arns.txt

    echo "✅ Destroy permissions and ARNs extracted → extracted_destroy_permissions_arns.txt"
    rm -f all_destroy_permissions_arns.txt

  else
    echo "🛠 Running Terragrunt Plan..."
    terragrunt plan

    read "confirm?Do you want to proceed with Terragrunt apply? (yes/no): "
    if [ "$confirm" != "yes" ]; then
      echo "⛔ Apply process aborted."
      return
    fi

    echo "🛠 Applying Changes with Terragrunt..."
    TF_LOG=trace terragrunt apply &> log_apply.log

    echo "🔍 Extracting AWS Permissions for Apply..."
    grep -oE "rpc.method=[^ ]*|rpc.service=[^ ]*" log_apply.log | sort | uniq > all_apply_permissions.txt

    awk '
    {
      if ($1 ~ /^rpc.method=/) {
        method = substr($1, 12)
      } else if ($1 ~ /^rpc.service=/) {
        service = substr($1, 13)
        if (method != "") print method " " service
      }
    }' all_apply_permissions.txt > extracted_apply_permissions.txt

    echo "✅ Apply permissions extracted → extracted_apply_permissions.txt"
    rm -f all_apply_permissions.txt
  fi

  echo "🎉 Operation completed."
}

# --- Virtual Environment Setup ---
function create_venv() {
  echo "🐍 Creating virtual environment..."
  python3 -m venv myenv
  echo "✅ Activating virtual environment..."
  source myenv/bin/activate
  echo "📦 Installing dependencies..."
  pip3 install requests packaging
}

# --- Virtual Environment Cleanup ---
function cleanup_venv() {
  echo "🧹 Cleaning up virtual environment..."
  deactivate 2>/dev/null
  rm -rf myenv
  echo "✅ Process completed."
}