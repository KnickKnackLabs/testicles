#!/usr/bin/env bats
# Static analysis — catches bugs like 'local' outside functions that runtime-only
# tests miss because the buggy path isn't exercised.

setup() {
  load test_helper
}

@test "all tasks pass shellcheck (excluding harmless warnings)" {
  # Exclude codes that conflict with our conventions:
  #   SC1091 — not following sourced files (MISE_CONFIG_ROOT resolves at runtime)
  #   SC2034 — unused vars (mise sets usage_* globals the linter can't see)
  #   SC2154 — referenced but not assigned (same — mise provides usage_*)
  #   SC2162 — 'read without -r' (we sometimes want escape interpretation)
  local excludes="SC1091,SC2034,SC2154,SC2162"

  local failed=0
  for task in "$MISE_CONFIG_ROOT"/.mise/tasks/*; do
    [ -d "$task" ] && continue
    run shellcheck --exclude="$excludes" --shell=bash "$task"
    if [ "$status" -ne 0 ]; then
      echo "shellcheck failed on: $task"
      echo "$output"
      failed=1
    fi
  done
  [ "$failed" -eq 0 ]
}

@test "lib files pass shellcheck" {
  # SC2001 — style suggestion to use parameter expansion instead of sed
  local excludes="SC1091,SC2034,SC2154,SC2001"

  local failed=0
  for libfile in "$MISE_CONFIG_ROOT"/lib/*.sh; do
    run shellcheck --exclude="$excludes" --shell=bash "$libfile"
    if [ "$status" -ne 0 ]; then
      echo "shellcheck failed on: $libfile"
      echo "$output"
      failed=1
    fi
  done
  [ "$failed" -eq 0 ]
}
