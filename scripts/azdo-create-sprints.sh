#!/usr/bin/env zsh
# azdo-create-sprints.sh — standalone wrapper around the create_sprints function
#
# This script sources the shared Azure DevOps zsh module and invokes the
# create_sprints function. All flags are forwarded. Run with --help for usage.
#
# Examples:
#   ./azdo-create-sprints.sh --help
#   ./azdo-create-sprints.sh --next 18 --count 3 --start 2025-09-03 --dry-run
#   ./azdo-create-sprints.sh --org https://dev.azure.com/myorg --project MyProj

set -euo pipefail

GENERAL_PARTS_DIR="${GENERAL_PARTS_DIR:-$HOME/git/general/shell/parts}"
MODULE="${GENERAL_PARTS_DIR}/60-azure-devops.zsh"

if [[ ! -r "$MODULE" ]]; then
  echo "❌ Cannot find azure-devops module at: $MODULE" >&2
  echo "   Set GENERAL_PARTS_DIR or clone the general repo to ~/git/general" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$MODULE"

create_sprints "$@"
