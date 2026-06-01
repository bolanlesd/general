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

# ---------------------------------------------------------------------------
# create_sprints — Azure DevOps sprint creation helper
# Usage: create_sprints [--org ORG] [--project PROJECT] [--count N]
#                       [--prefix NAME] [--start YYYY-MM-DD] [--cadence DAYS]
#                       [--next N] [--dry-run] [--help]
# desc: create_sprints [opts] — create Azure DevOps sprints with auto-seeded work items
# ---------------------------------------------------------------------------
function create_sprints() {
  # ── defaults (match existing script) ──────────────────────────────────────
  local ORG="${AZDO_ORG:-}"
  local PROJECT="${AZDO_PROJECT:-}"
  local TEAM="${AZDO_TEAM:-Architecture Team}"
  # Parent iteration path under which new sprints will be created.
  # az boards expects a project-prefixed absolute path, e.g.
  #   \Youlend-Infrastructure\Iteration
  local ITER_ROOT="${AZDO_ITER_ROOT:-Youlend-Infrastructure\\Iteration}"
  # Area path for seeded work items (project-relative, e.g. "Architecture Team").
  # Defaults to the team name when unset.
  local AREA="${AZDO_AREA:-}"
  local COUNT=5
  local CADENCE=14
  local NEXT_SPRINT=18
  local START=""
  local PREFIX="Architecture Sprint"
  local DRY_RUN=0
  local VERBOSE=0

  # ── help ──────────────────────────────────────────────────────────────────
  _cs_help() {
    cat <<'EOF'
create_sprints — create Azure DevOps sprints and seed default work items.

USAGE
  create_sprints [OPTIONS]

OPTIONS
  --org      ORG          Azure DevOps org URL (or set AZDO_ORG env var)
  --project  PROJECT      Azure DevOps project  (or set AZDO_PROJECT env var)
  --team     TEAM         Team name [default: "Architecture Team"]
  --root     ITER_ROOT    Iteration parent path [default: "Youlend-Infrastructure\\Iteration"]
  --area     AREA         Area path for seeded work items (project-relative) [default: TEAM]
  --prefix   PREFIX       Sprint name prefix [default: "Architecture Sprint"]
  --next     N            Starting sprint number [default: 18]
  --count    N            Number of sprints to create [default: 5]
  --start    YYYY-MM-DD   Start date of the first new sprint
  --cadence  DAYS         Sprint length in days [default: 14]
  -n, --dry-run           Preview sprints without creating them
  -v, --verbose           Show timestamps and extra detail
  -h, --help              Show this help and exit

ENVIRONMENT
  AZDO_ORG        default --org value
  AZDO_PROJECT    default --project value
  AZDO_TEAM       default --team value
  AZDO_ITER_ROOT  default --root value
  AZDO_AREA       default --area value
  AZURE_DEVOPS_EXT_PAT  Personal Access Token (required by az devops)

EXAMPLES
  create_sprints --next 18 --count 3 --start 2025-09-03
  create_sprints --org https://dev.azure.com/myorg --project MyProj --dry-run

DELEGATING TO AN AI AGENT
  Paste a prompt like the one below to ask an agent to run this for you:

    Create the next 10 Architecture Sprints in Azure DevOps using the
    create_sprints function from ~/git/general/shell/parts/60-azure-devops.zsh
    (also exposed as the `create-sprints` alias and via
    ~/git/general/scripts/azdo-create-sprints.sh).

    1. Source the module (or call the wrapper script directly).
    2. Find the highest existing "Architecture Sprint N" iteration under
       \Youlend-Infrastructure\Iteration and compute --next as N+1.
       Compute --start as (finish_date of sprint N) + 1 day.
       Cadence is 14 days; do not override unless asked.
    3. Run with --dry-run first and show me the preview.
    4. Wait for my explicit "go" before running for real.
    5. After creation, verify each new sprint has:
         - iteration at \Youlend-Infrastructure\Iteration\Architecture Sprint M
         - team assignment on "Architecture Team"
         - two User Story work items: "BAU Sprint M" and "Training Sprint M"
         - work-item area = "Youlend-Infrastructure\Architecture Team"
       Report the work item IDs and any failures.

    Defaults already baked into the function — do NOT override unless I ask:
      --team   "Architecture Team"
      --root   "Youlend-Infrastructure\Iteration"
      --area   "Architecture Team"   (becomes "<project>\Architecture Team")
      --prefix "Architecture Sprint"
      --cadence 14

    Required env: AZDO_ORG, AZDO_PROJECT (or `az devops configure --defaults`).
    AZURE_DEVOPS_EXT_PAT must be set for non-interactive auth.
EOF
  }

  # ── log helper ────────────────────────────────────────────────────────────
  _cs_log() {
    local level="$1"; shift
    local ts; ts=$(date '+%Y-%m-%dT%H:%M:%S')
    case "$level" in
      INFO)  echo "  [${ts}] ℹ️  $*" ;;
      OK)    echo "  [${ts}] ✅ $*" ;;
      DRY)   echo "  [${ts}] 🧪 [DRY-RUN] $*" ;;
      WARN)  echo "  [${ts}] ⚠️  $*" >&2 ;;
      ERROR) echo "  [${ts}] ❌ $*" >&2 ;;
    esac
  }

  # ── arg parsing ───────────────────────────────────────────────────────────
  while (( $# )); do
    case "$1" in
      -h|--help)    _cs_help; return 0 ;;
      --org)        ORG="$2";          shift 2 ;;
      --project)    PROJECT="$2";      shift 2 ;;
      --team)       TEAM="$2";         shift 2 ;;
      --root)       ITER_ROOT="$2";    shift 2 ;;
      --area)       AREA="$2";         shift 2 ;;
      --prefix)     PREFIX="$2";       shift 2 ;;
      --next)       NEXT_SPRINT="$2";  shift 2 ;;
      --count)      COUNT="$2";        shift 2 ;;
      --start)      START="$2";        shift 2 ;;
      --cadence)    CADENCE="$2";      shift 2 ;;
      -n|--dry-run) DRY_RUN=1;         shift ;;
      -v|--verbose) VERBOSE=1;         shift ;;
      *) echo "Unknown option: $1. Use --help for usage." >&2; return 1 ;;
    esac
  done

  # ── validate required tools ───────────────────────────────────────────────
  if ! command -v az &>/dev/null; then
    _cs_log ERROR "'az' CLI not found. Install with: brew install azure-cli"
    return 1
  fi
  if ! az extension show --name azure-devops &>/dev/null; then
    _cs_log ERROR "azure-devops extension missing. Run: az extension add --name azure-devops"
    return 1
  fi

  # ── validate PAT ──────────────────────────────────────────────────────────
  if [[ -z "${AZURE_DEVOPS_EXT_PAT:-}" ]]; then
    _cs_log WARN "AZURE_DEVOPS_EXT_PAT is not set — az devops may prompt for credentials."
  fi

  # ── validate / default org + project ─────────────────────────────────────
  if [[ -z "$ORG" ]]; then
    # try to read from az devops defaults
    ORG=$(az devops configure --list 2>/dev/null | awk -F= '/^organization/{gsub(/ /,"",$2); print $2}')
  fi
  if [[ -z "$PROJECT" ]]; then
    PROJECT=$(az devops configure --list 2>/dev/null | awk -F= '/^project/{gsub(/ /,"",$2); print $2}')
  fi
  if [[ -z "$ORG" || -z "$PROJECT" ]]; then
    _cs_log ERROR "Cannot determine org/project. Pass --org and --project, set AZDO_ORG/AZDO_PROJECT, or run: az devops configure --defaults organization=URL project=NAME"
    return 1
  fi

  # ── validate numeric inputs ────────────────────────────────────────────────
  if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || (( COUNT < 1 )); then
    _cs_log ERROR "--count must be a positive integer (got: $COUNT)"
    return 1
  fi
  if ! [[ "$CADENCE" =~ ^[0-9]+$ ]] || (( CADENCE < 1 )); then
    _cs_log ERROR "--cadence must be a positive integer (got: $CADENCE)"
    return 1
  fi
  if ! [[ "$NEXT_SPRINT" =~ ^[0-9]+$ ]]; then
    _cs_log ERROR "--next must be an integer (got: $NEXT_SPRINT)"
    return 1
  fi

  # ── default start date: today if not set ─────────────────────────────────
  if [[ -z "$START" ]]; then
    START=$(date '+%Y-%m-%d')
    _cs_log WARN "--start not provided; defaulting to today ($START)"
  fi
  # validate date format
  if ! date -j -f '%Y-%m-%d' "$START" '+%Y-%m-%d' &>/dev/null 2>&1 && \
     ! date -d "$START" '+%Y-%m-%d' &>/dev/null 2>&1; then
    _cs_log ERROR "--start '$START' is not a valid YYYY-MM-DD date"
    return 1
  fi

  # ── portable date arithmetic (macOS vs Linux) ─────────────────────────────
  _cs_add_days() {
    local base="$1" days="$2"
    if date -v+0d &>/dev/null 2>&1; then
      # macOS BSD date
      date -j -v+"${days}"d -f '%Y-%m-%d' "$base" '+%Y-%m-%d'
    else
      # GNU date
      date -I -d "$base +${days} days"
    fi
  }

  # Default area path to the team name when not provided.
  [[ -z "$AREA" ]] && AREA="$TEAM"
  local WI_AREA="${PROJECT}\\${AREA}"

  # ── summary ───────────────────────────────────────────────────────────────
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Azure DevOps Sprint Bootstrap"
  [[ "$DRY_RUN" = "1" ]] && echo "  MODE: DRY-RUN (no changes will be made)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Org:          $ORG"
  echo "  Project:      $PROJECT"
  echo "  Team:         $TEAM"
  echo "  Iter root:    $ITER_ROOT"
  echo "  Area path:    $WI_AREA"
  echo "  Prefix:       $PREFIX"
  echo "  Sprints:      $NEXT_SPRINT → $((NEXT_SPRINT + COUNT - 1))  ($COUNT total)"
  echo "  Cadence:      ${CADENCE} days"
  echo "  Start date:   $START"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  local -a AZ_GLOBAL
  AZ_GLOBAL=(--org "$ORG" --project "$PROJECT")

  local CREATED=0 FAILED=0
  local n sd ed NAME ITER_PATH TITLE
  for (( i=0; i<COUNT; i++ )); do
    n=$(( NEXT_SPRINT + i ))
    sd=$(_cs_add_days "$START" $(( i * CADENCE )))
    ed=$(_cs_add_days "$sd"    $(( CADENCE - 1 )))
    NAME="${PREFIX} ${n}"
    ITER_PATH="\\${ITER_ROOT}\\${NAME}"

    echo "  🌀  $NAME   $sd → $ed"

    if [[ "$DRY_RUN" = "1" ]]; then
      _cs_log DRY "Would create iteration: $NAME ($sd → $ed)"
      _cs_log DRY "Would add to team '$TEAM' at path: $ITER_PATH"
      _cs_log DRY "Would seed: 'BAU Sprint $n'  +  'Training Sprint $n'"
      echo ""
      continue
    fi

    # 1) Create project-level iteration (capture identifier for later steps)
    [[ "$VERBOSE" = "1" ]] && _cs_log INFO "Creating project iteration..."
    local ITER_JSON ITER_ID
    if ! ITER_JSON=$(az boards iteration project create \
        "${AZ_GLOBAL[@]}"        \
        --name "$NAME"           \
        --path "\\${ITER_ROOT}"  \
        --start-date "$sd"       \
        --finish-date "$ed"      \
        --output json 2>/tmp/_cs_err); then
      _cs_log ERROR "Failed to create iteration '$NAME': $(cat /tmp/_cs_err)"
      (( FAILED++ )) || true
      continue
    fi
    ITER_ID=$(printf '%s' "$ITER_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("identifier",""))' 2>/dev/null)
    [[ "$VERBOSE" = "1" ]] && _cs_log OK "Iteration created (id: ${ITER_ID:-unknown})"

    if [[ -z "$ITER_ID" ]]; then
      _cs_log WARN "Could not parse iteration id; skipping team add / work-item seeding for '$NAME'"
      (( CREATED++ )) || true
      echo ""
      continue
    fi

    # 2) Add to team backlog
    [[ "$VERBOSE" = "1" ]] && _cs_log INFO "Adding to team backlog..."
    if ! az boards iteration team add \
        "${AZ_GLOBAL[@]}"             \
        --team "$TEAM"                \
        --id "$ITER_ID"               \
        --output none 2>/tmp/_cs_err; then
      _cs_log WARN "Could not add '$NAME' to team '$TEAM': $(cat /tmp/_cs_err)"
    fi

    # 3) Set as default iteration for the team
    [[ "$VERBOSE" = "1" ]] && _cs_log INFO "Setting as default iteration..."
    az boards iteration team set-default-iteration \
        "${AZ_GLOBAL[@]}"        \
        --team "$TEAM"           \
        --id "$ITER_ID"          \
        --output none 2>/dev/null || true

    # 4) Seed default work items.
    # Work-item --iteration expects "<project>\<iteration_name>" (no leading
    # backslash, no \Iteration\ tier), distinct from the classification path
    # used for iteration management above.
    local WI_ITERATION="${PROJECT}\\${NAME}"
    for TITLE in "BAU Sprint $n" "Training Sprint $n"; do
      [[ "$VERBOSE" = "1" ]] && _cs_log INFO "Seeding work item: $TITLE"
      if ! az boards work-item create      \
          "${AZ_GLOBAL[@]}"                \
          --type "User Story"              \
          --title "$TITLE"                 \
          --iteration "$WI_ITERATION"      \
          --area "$WI_AREA"                \
          --description "Auto-seeded by sprint bootstrap script" \
          --output none 2>/tmp/_cs_err; then
        _cs_log WARN "Could not seed '$TITLE': $(cat /tmp/_cs_err)"
      fi
    done

    _cs_log OK "$NAME created and seeded."
    (( CREATED++ )) || true
    echo ""
  done

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if [[ "$DRY_RUN" = "1" ]]; then
    echo "  🧪 Dry-run complete — $COUNT sprint(s) previewed, none created."
  else
    echo "  ✅ Done: $CREATED created, $FAILED failed."
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  rm -f /tmp/_cs_err
  [[ "$FAILED" -gt 0 ]] && return 1 || return 0
}

# Convenience alias
alias create-sprints='create_sprints'
