# 60-azure-devops.zsh — Azure DevOps PR helper
# Usage: create_pr [TICKET_ID] [TARGET_BRANCH] [--dry-run] [--draft]
#   - Works from any directory inside a git repo (resolves repo root automatically).
#   - Auto-runs `az login --allow-no-subscription` if not already authenticated.
#   - Auto-fills the .azuredevops/pull_request_template.md based on the branch diff:
#       * Ticket ID placeholder replaced with branch / arg
#       * Description seeded from commits between target..HEAD
#       * terraform_remote_state / checkov-ignore checkboxes toggled based on diff
#       * "How has this been Tested?" pre-populated with the list of envs touched
#   - --dry-run : print the would-be PR title/branch/description and stop (no submission)
#   - --draft   : create the PR as a draft
# desc: create_pr [ticket] [target] [--dry-run] [--draft] — open an Azure DevOps PR
function create_pr() {
  # Help short-circuits before tool/git prechecks so docs work anywhere.
  for arg in "$@"; do
    case "$arg" in
      -h|--help|--explain)
        cat <<'EOF'
create_pr — open an Azure DevOps PR with an auto-filled template.

USAGE
  create_pr [TICKET_ID] [TARGET_BRANCH] [--dry-run] [--draft]

ARGUMENTS
  TICKET_ID       Work item to link. Defaults to current branch name.
  TARGET_BRANCH   PR target. Defaults to "master".

FLAGS
  -n, --dry-run   Build & preview the PR but do NOT submit it.
  -d, --draft     Submit the PR as a draft.
  -h, --help      Show this help and exit.
EOF
        return 0 ;;
    esac
  done

  if ! command -v az &>/dev/null || ! command -v jq &>/dev/null; then
    echo "Required command(s) 'az' or 'jq' not found." >&2
    return 1
  fi

  if ! git rev-parse --git-dir &>/dev/null; then
    echo "Not a git repository." >&2
    return 1
  fi

  # --- arg parsing: split flags vs positional ---
  local DRY_RUN=0 DRAFT=0
  local -a POSITIONAL
  POSITIONAL=()
  while (( $# )); do
    case "$1" in
      -n|--dry-run) DRY_RUN=1 ;;
      -d|--draft)   DRAFT=1 ;;
      -h|--help|--explain) return 0 ;;
      *) POSITIONAL+=("$1") ;;
    esac
    shift
  done

  local REPO_ROOT
  REPO_ROOT=$(git rev-parse --show-toplevel) || return 1

  if ! az account show &>/dev/null; then
    echo "🔐 az not logged in — running 'az login --allow-no-subscription'..."
    if ! az login --allow-no-subscription >/dev/null; then
      echo "❌ az login failed" >&2
      return 1
    fi
  fi

  local REPO_NAME BRANCH_NAME TICKET_ID TARGET_BRANCH LAST_COMMIT_MESSAGE PR_TITLE PR_DESCRIPTION TEMPLATE_PATH
  REPO_NAME=$(basename "$REPO_ROOT")
  BRANCH_NAME=$(git -C "$REPO_ROOT" branch --show-current)
  TICKET_ID=${POSITIONAL[1]:-${POSITIONAL[0]:-$BRANCH_NAME}}
  TARGET_BRANCH=${POSITIONAL[2]:-${POSITIONAL[1]:-master}}
  if [ -n "${POSITIONAL[0]}" ]; then TICKET_ID="${POSITIONAL[0]}"; fi
  if [ -n "${POSITIONAL[1]}" ]; then TARGET_BRANCH="${POSITIONAL[1]}"; fi
  [ -z "$TICKET_ID" ]    && TICKET_ID="$BRANCH_NAME"
  [ -z "$TARGET_BRANCH" ] && TARGET_BRANCH="master"
  LAST_COMMIT_MESSAGE=$(git -C "$REPO_ROOT" log -1 --pretty=%B)
  PR_TITLE="$LAST_COMMIT_MESSAGE"

  TEMPLATE_PATH="$REPO_ROOT/.azuredevops/pull_request_template.md"
  if [ ! -f "$TEMPLATE_PATH" ]; then
    echo "❌ PR template not found at $TEMPLATE_PATH" >&2
    return 1
  fi
  PR_DESCRIPTION=$(cat "$TEMPLATE_PATH")

  local DIFF_RANGE COMMIT_LOG ENV_LIST HAS_REMOTE_STATE HAS_CHECKOV_IGNORE
  DIFF_RANGE="origin/${TARGET_BRANCH}...HEAD"
  if ! git -C "$REPO_ROOT" rev-parse --verify -q "origin/${TARGET_BRANCH}" >/dev/null; then
    DIFF_RANGE="${TARGET_BRANCH}...HEAD"
  fi

  COMMIT_LOG=$(git -C "$REPO_ROOT" log --pretty='- %s' "${DIFF_RANGE}" 2>/dev/null | head -20)
  [ -z "$COMMIT_LOG" ] && COMMIT_LOG="- ${LAST_COMMIT_MESSAGE}"

  ENV_LIST=$(git -C "$REPO_ROOT" diff --name-only "${DIFF_RANGE}" 2>/dev/null \
    | awk -F/ 'NF>=4 && $1=="envs" {print $2"/"$3}' | sort -u | sed 's/^/  - /')

  HAS_REMOTE_STATE=$(git -C "$REPO_ROOT" diff "${DIFF_RANGE}" -- '*.tf' '*.hcl' 2>/dev/null \
    | grep -E '^\+.*terraform_remote_state' | head -1)
  HAS_CHECKOV_IGNORE=$(git -C "$REPO_ROOT" diff "${DIFF_RANGE}" -- '*.tf' '*.hcl' '*.yml' '*.yaml' 2>/dev/null \
    | grep -Ei '^\+.*checkov:skip|^\+.*skip-check' | head -1)

  PR_DESCRIPTION=${PR_DESCRIPTION//\#ticket_id_here/#${TICKET_ID}}

  local TMP_DESC TMP_BODY TMP_ENVS
  TMP_DESC=$(mktemp); TMP_BODY=$(mktemp); TMP_ENVS=$(mktemp)
  printf '%s\n' "$PR_DESCRIPTION" >"$TMP_DESC"
  printf '%s\n' "$COMMIT_LOG"     >"$TMP_BODY"
  printf '%s\n' "$ENV_LIST"       >"$TMP_ENVS"

  awk -v bodyfile="$TMP_BODY" '
    BEGIN{ while ((getline line < bodyfile) > 0) body = body line "\n"; done=0 }
    /^# Description/ && !done { print; print ""; printf "%s", body; done=1; next }
    { print }
  ' "$TMP_DESC" >"${TMP_DESC}.new" && mv "${TMP_DESC}.new" "$TMP_DESC"

  if [ -n "$HAS_REMOTE_STATE" ]; then
    sed -i.bak 's/^- \[x\] I have not added any terraform_remote_state/- [ ] I have not added any terraform_remote_state/' "$TMP_DESC" && rm -f "${TMP_DESC}.bak"
  fi

  if [ -n "$HAS_CHECKOV_IGNORE" ]; then
    sed -i.bak 's/^- \[x\] \*\*Code Changes do not include checkov ignores/- [ ] **Code Changes do not include checkov ignores/' "$TMP_DESC" && rm -f "${TMP_DESC}.bak"
  fi

  if [ -n "$ENV_LIST" ]; then
    awk -v envfile="$TMP_ENVS" '
      BEGIN{ while ((getline line < envfile) > 0) envs = envs line "\n"; done=0 }
      /^## How has this been Tested\?/ && !done {
        print; if ((getline nxt) > 0) print nxt
        print ""; print "Planned cleanly in the following envs:"
        printf "%s", envs
        done=1; next
      }
      { print }
    ' "$TMP_DESC" >"${TMP_DESC}.new" && mv "${TMP_DESC}.new" "$TMP_DESC"
  fi

  PR_DESCRIPTION=$(cat "$TMP_DESC")
  rm -f "$TMP_DESC" "$TMP_BODY" "$TMP_ENVS"

  echo "📝 PR title:       $PR_TITLE"
  echo "🌿 Source branch:  $BRANCH_NAME  ->  $TARGET_BRANCH"
  echo "🎫 Work item:      $TICKET_ID"
  echo "📦 Repo:           $REPO_NAME ($REPO_ROOT)"
  [ "$DRAFT" = "1" ]   && echo "📄 Mode:           DRAFT"
  [ "$DRY_RUN" = "1" ] && echo "🧪 Mode:           DRY-RUN (no submission)"
  echo "─── Description preview ───"
  printf '%s\n' "$PR_DESCRIPTION" | sed 's/^/  /' | head -40
  echo "───────────────────────────"

  if [ "$DRY_RUN" = "1" ]; then
    echo "🛑 Dry-run complete — PR not submitted."
    return 0
  fi

  local TMP_OUTPUT
  TMP_OUTPUT=$(mktemp)

  local -a AZ_EXTRA_ARGS
  AZ_EXTRA_ARGS=()
  [ "$DRAFT" = "1" ] && AZ_EXTRA_ARGS+=(--draft true)

  if ! (cd "$REPO_ROOT" && az repos pr create \
    --auto-complete false \
    --repository "$REPO_NAME" \
    --source-branch "$BRANCH_NAME" \
    --target-branch "$TARGET_BRANCH" \
    --description "$PR_DESCRIPTION" \
    --title "$PR_TITLE" \
    --work-items "$TICKET_ID" \
    "${AZ_EXTRA_ARGS[@]}" \
    --output json) >"$TMP_OUTPUT" 2>/dev/null; then
    echo "❌ Failed to create Pull Request"
    cat "$TMP_OUTPUT"
    rm -f "$TMP_OUTPUT"
    return 1
  fi

  if jq -e .url "$TMP_OUTPUT" &>/dev/null; then
    jq -r '"✅ \(.repository.webUrl)/pullrequest/\(.pullRequestId)"' "$TMP_OUTPUT"
  else
    echo "❌ Failed to parse PR output"
    cat "$TMP_OUTPUT"
    rm -f "$TMP_OUTPUT"
    return 1
  fi

  rm -f "$TMP_OUTPUT"
}
