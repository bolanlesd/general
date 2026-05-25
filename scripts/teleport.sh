#!/usr/bin/env bash
# teleport.sh — promoted teleport helpers (formerly notes-only)
# Source this OR call individual functions directly.
#
# Functions:
#   tlogin <proxy>          tsh login to a teleport cluster
#   tlogout                 tsh logout from current cluster
#   tservers [filter]       list ssh nodes, optionally grep-filtered
#   tkubes                  list available kube contexts via tsh
#   tdb [filter]            list available db connections
set -euo pipefail

tlogin()   { tsh login --proxy="${1:?proxy required}"; }
tlogout()  { tsh logout; }
tservers() {
  if [ -n "${1:-}" ]; then tsh ls | grep -i "$1"; else tsh ls; fi
}
tkubes()   { tsh kube ls; }
tdb()      {
  if [ -n "${1:-}" ]; then tsh db ls | grep -i "$1"; else tsh db ls; fi
}

# If invoked directly with a subcommand, dispatch
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  fn="${1:-}"; shift || true
  case "$fn" in
    login)    tlogin    "$@" ;;
    logout)   tlogout   "$@" ;;
    servers)  tservers  "$@" ;;
    kubes)    tkubes    "$@" ;;
    db)       tdb       "$@" ;;
    *)        echo "Usage: teleport.sh {login|logout|servers|kubes|db} [args]" >&2; exit 1 ;;
  esac
fi
