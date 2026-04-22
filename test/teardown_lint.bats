#!/usr/bin/env bats
# Lint — catches .bats files that override teardown() without calling the
# gpg-agent cleanup helpers from test_helper.bash.
#
# Background: PR #2 centralized gpg-agent cleanup in a default teardown()
# in test_helper.bash. BATS lets a file's own teardown() shadow the helper's,
# which silently re-introduces the agent leak. This test fails CI if any
# .bats file defines teardown() without calling both helpers.
# See: https://github.com/KnickKnackLabs/testicles/issues/3

# Returns 0 if all .bats files in $1 are clean; 1 otherwise (with offenders on stderr).
lint_teardown_overrides() {
  local dir=$1
  local offenders=()
  shopt -s nullglob
  local f
  for f in "$dir"/*.bats; do
    grep -qE '^teardown\(\)' "$f" || continue
    if ! grep -q 'teardown_gpg_home' "$f" || ! grep -q 'teardown_extra_gpg_homes' "$f"; then
      offenders+=("$f")
    fi
  done
  if [ "${#offenders[@]}" -gt 0 ]; then
    local o
    for o in "${offenders[@]}"; do
      echo "$o overrides teardown() without calling teardown_gpg_home/teardown_extra_gpg_homes" >&2
    done
    return 1
  fi
}

@test "no real .bats file overrides teardown() without helpers" {
  run lint_teardown_overrides "$BATS_TEST_DIRNAME"
  [ "$status" -eq 0 ]
}

@test "lint detects a .bats file that overrides teardown() without helpers" {
  local tmp
  tmp=$(mktemp -d)
  cat > "$tmp/bad.bats" <<'BATS'
#!/usr/bin/env bats
teardown() {
  echo "dangerous: no helper calls"
}
@test "noop" { :; }
BATS
  run lint_teardown_overrides "$tmp"
  [ "$status" -eq 1 ]
  [[ "$output" == *"bad.bats"* ]]
  [[ "$output" == *"teardown_gpg_home"* ]]
  rm -rf "$tmp"
}

@test "lint accepts a .bats file that overrides teardown() and calls both helpers" {
  local tmp
  tmp=$(mktemp -d)
  cat > "$tmp/good.bats" <<'BATS'
#!/usr/bin/env bats
teardown() {
  echo "cleaning up before helpers"
  teardown_gpg_home
  teardown_extra_gpg_homes
}
@test "noop" { :; }
BATS
  run lint_teardown_overrides "$tmp"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "lint accepts a .bats file with no teardown() override at all" {
  local tmp
  tmp=$(mktemp -d)
  cat > "$tmp/fine.bats" <<'BATS'
#!/usr/bin/env bats
@test "noop" { :; }
BATS
  run lint_teardown_overrides "$tmp"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "lint flags a file calling only one of the two helpers" {
  local tmp
  tmp=$(mktemp -d)
  cat > "$tmp/partial.bats" <<'BATS'
#!/usr/bin/env bats
teardown() {
  teardown_gpg_home
}
@test "noop" { :; }
BATS
  run lint_teardown_overrides "$tmp"
  [ "$status" -eq 1 ]
  [[ "$output" == *"partial.bats"* ]]
  rm -rf "$tmp"
}
