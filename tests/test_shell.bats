#!/usr/bin/env bats
# Tests for the modular zsh parts. Loaded with `bats tests/`.
# Note: bats runs under bash; we test purely behavioural surface of helpers
# that don't depend on zsh-specific syntax (or we use `zsh -c` for those).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "all parts pass zsh syntax check" {
  for f in "$REPO_ROOT"/shell/parts/*.zsh; do
    run zsh -n "$f"
    [ "$status" -eq 0 ] || { echo "syntax error in $f"; return 1; }
  done
}

@test "loader sources every part" {
  run zsh -c "source $REPO_ROOT/shell/zshrc 2>&1; type tgfu awsp create_pr gco gg help g >/dev/null && echo OK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "dist/zshrc matches concatenated parts" {
  bash "$REPO_ROOT/scripts/build-zshrc.sh" >/dev/null
  run git -C "$REPO_ROOT" diff --quiet dist/zshrc
  [ "$status" -eq 0 ] || { echo "dist/zshrc is stale — run scripts/build-zshrc.sh"; return 1; }
}

@test "awsp exports AWS_PROFILE" {
  run zsh -c "source $REPO_ROOT/shell/parts/40-aws.zsh; awsp staging; echo \$AWS_PROFILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"staging"* ]]
}

@test "tgfu without args errors out" {
  run zsh -c "source $REPO_ROOT/shell/parts/50-terragrunt.zsh; tgfu"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage: tgfu"* ]]
}

@test "create_pr --help prints usage" {
  run zsh -c "source $REPO_ROOT/shell/parts/60-azure-devops.zsh; create_pr --help"
  [ "$status" -eq 0 ]
  [[ "$output" == *"create_pr"* ]]
  [[ "$output" == *"USAGE"* ]]
}

@test "g with no args lists scripts" {
  run zsh -c "source $REPO_ROOT/shell/parts/77-g-runner.zsh; g"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Available scripts"* ]]
}

@test "general doctor runs without crashing" {
  run bash "$REPO_ROOT/bin/general" doctor
  # may pass or fail depending on tools installed; just must not crash
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
  [[ "$output" == *"general doctor"* ]]
}
