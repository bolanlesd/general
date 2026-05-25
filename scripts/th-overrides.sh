# =============================================
# === th (Teleport Helper) overrides ===
# Added 2026-05-23. Lives in ~/git/general so it auto-syncs to all machines
# via the remote zshrc download. Survives `brew upgrade th` because it's
# sourced AFTER /opt/homebrew/share/th/th.sh.
#
# Adds:
#   - Stronger stale-session detection in th_login
#   - thr      one-shot refresh of current AWS account (+ kube re-login)
#   - thrl     same as thr but mkdir-locked, safe across concurrent shells
#   - ths      re-source creds another shell already refreshed (no proxy churn)
#   - th r     dispatcher alias for thr
# =============================================

# (A) Stronger stale-session detection. Original th_login only checks
# `tsh status | grep 'Logged in as:'`, which can still succeed after the
# apps cert has expired. We also require `tsh apps ls` to return a
# non-empty list — if not, force a clean re-login.
th_login() {
    printf "\033c"
    create_header "Login"
    printf "Checking login status...\n"

    local apps_ok=0
    if tsh status 2>/dev/null | grep -q 'Logged in as:'; then
        if tsh apps ls --format=json 2>/dev/null | grep -q '"name"'; then
            apps_ok=1
        fi
    fi

    if [ "$apps_ok" = "1" ]; then
        cprintf "\n✅ \033[1mAlready logged in to Teleport!\033[0m\n"
        sleep 1
        return 0
    fi

    printf "\nSession stale or missing — cleaning up and re-logging in...\n"
    th_kill > /dev/null 2>&1

    if [[ -n "$WSL_DISTRO_NAME" ]]; then
        tsh login --auth=ad --proxy=youlend.teleport.sh:443 2>&1 \
            | awk '/https?:\/\// {print $1; exit}' \
            | xargs -r /mnt/c/Windows/explorer.exe
    else
        tsh login --auth=ad --proxy=youlend.teleport.sh:443 > /dev/null 2>&1
    fi

    for i in {1..30}; do
        if tsh status 2>/dev/null | grep -q 'Logged in as:'; then
            printf "\n\033[1;32mLogged in successfully!\033[0m\n"
            sleep 1
            return 0
        fi
        sleep 0.5
    done

    printf "\n❌ \033[1;31mTimed out waiting for Teleport login.\033[0m\n"
    return 1
}

# (B-kube) Re-login any kubectl contexts that came from teleport.
# After tsh session refresh, those kube certs are stale; re-issuing them is
# cheap (~1s per cluster) and avoids the next kubectl call failing.
th_kube_sync() {
    local contexts cluster
    contexts=$(kubectl config get-contexts -o name 2>/dev/null | grep '^youlend\.teleport\.sh-')
    [ -z "$contexts" ] && return 0
    printf "\n🔁 Re-issuing teleport kube logins...\n"
    while IFS= read -r ctx; do
        # Strip "youlend.teleport.sh-" prefix and "-<region>-<account>" suffix.
        cluster=$(printf '%s\n' "$ctx" | sed -E 's/^youlend\.teleport\.sh-(.+)-(eu|us)-[a-z]+-[0-9]+-[0-9]+$/\1/')
        if [ -n "$cluster" ] && [ "$cluster" != "$ctx" ]; then
            if tsh kube login "$cluster" > /dev/null 2>&1; then
                printf "  ✓ %s\n" "$cluster"
            else
                printf "  ✗ %s (failed — may need fresh access)\n" "$cluster"
            fi
        fi
    done <<< "$contexts"
}

# (B) One-shot refresh of the currently-active AWS account.
# Replaces the manual ritual: th c -> th t -> th a -> pick -> th k.
# Also re-issues any teleport kube contexts found in ~/.kube/config.
# Usage: thr            (refresh current $ACCOUNT)
#        thr <env>      (refresh a specific env shortname, e.g. `thr prod`)
th_refresh() {
    local target="$1"
    if [ -z "$target" ]; then
        target="${ACCOUNT#yl-}"
    fi
    if [ -z "$target" ]; then
        printf "\n❌ No \$ACCOUNT set and no env arg given. Try: thr <env>\n"
        return 1
    fi
    printf "\n🔄 Refreshing AWS session for \033[1;32m%s\033[0m...\n" "$target"
    th_kill > /dev/null 2>&1
    th_login || return 1
    aws_quick_login "$target" || return 1
    th_kube_sync
}
alias thr='th_refresh'

# (B+) Lock-protected wrapper so two concurrent `thr` calls serialise
# instead of wiping each other's /tmp/tsh_proxy_* files. Uses mkdir as an
# atomic lock (works on macOS without flock(1)). Stale locks auto-cleared
# after 120s.
th_refresh_locked() {
    local lockdir=/tmp/th.refresh.lock.d
    local waited=0
    while ! mkdir "$lockdir" 2>/dev/null; do
        if [ -d "$lockdir" ]; then
            local age=$(( $(date +%s) - $(stat -f %m "$lockdir" 2>/dev/null || echo 0) ))
            if [ "$age" -gt 120 ]; then
                printf "\n⚠️  Removing stale th refresh lock (%ds old)\n" "$age"
                rmdir "$lockdir" 2>/dev/null
                continue
            fi
        fi
        if [ "$waited" -eq 0 ]; then
            printf "\n⏳ Another shell is refreshing — waiting...\n"
        fi
        sleep 1
        waited=$((waited + 1))
        if [ "$waited" -gt 90 ]; then
            printf "\n❌ Timed out waiting for th refresh lock. Run \`rmdir %s\` if you're sure no other shell is refreshing.\n" "$lockdir"
            return 1
        fi
    done
    trap 'rmdir "$lockdir" 2>/dev/null' EXIT INT TERM
    th_refresh "$@"
    local rc=$?
    rmdir "$lockdir" 2>/dev/null
    trap - EXIT INT TERM
    return $rc
}
alias thrl='th_refresh_locked'

# (C) Sync the CURRENT shell to creds another shell already refreshed.
# Re-sources /tmp/tsh_proxy_$ACCOUNT.log without killing or re-creating
# the background proxy. Use this in shell B after running `thr` in shell A.
# Usage: ths              (sync current $ACCOUNT)
#        ths <env>        (e.g. ths admin)
th_sync() {
    local target="$1"
    if [ -z "$target" ]; then
        target="${ACCOUNT#yl-}"
    fi
    if [ -z "$target" ]; then
        printf "\n❌ No \$ACCOUNT set and no env arg given. Try: ths <env>\n"
        return 1
    fi
    local app="yl-${target}"
    local log_file="/tmp/tsh_proxy_${app}.log"
    if [ ! -f "$log_file" ]; then
        printf "\n❌ No proxy log at %s. Run \`thr %s\` first.\n" "$log_file" "$target"
        return 1
    fi
    # shellcheck disable=SC1090
    source "$log_file"
    printf "\n✅ Synced creds for \033[1;32m%s\033[0m in this shell\n" "$app"
}
alias ths='th_sync'

# Extend `th` dispatcher with `th r|refresh <env>` and `th s|sync <env>`.
# In zsh, copy the original `th` function under a new name, then redefine.
if [ -n "$ZSH_VERSION" ] && (( ${+functions[th]} )) && (( ! ${+functions[_orig_th]} )); then
    functions[_orig_th]=$functions[th]
    th() {
        case "$1" in
            r|refresh)
                shift
                th_refresh "$@"
                ;;
            s|sync)
                shift
                th_sync "$@"
                ;;
            *)
                _orig_th "$@"
                ;;
        esac
    }
fi
