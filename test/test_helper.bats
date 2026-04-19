#!/usr/bin/env bats
#
# Tests for test_helper.bash itself — specifically teardown_gpg_home, which
# prevents gpg-agent process leaks between tests. See commit for context.

setup() {
  load test_helper
  setup_gpg_home
}

# Find the gpg-agent PID for a given GNUPGHOME, or empty if none.
agent_pid_for() {
  pgrep -f "gpg-agent --homedir $1" | head -n1
}

# Wait for a PID to exit (up to ~1s).
wait_gone() {
  local pid="$1"
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    kill -0 "$pid" 2>/dev/null || return 0
    sleep 0.1
  done
  return 1
}

@test "teardown_gpg_home is a no-op when GNUPGHOME is unset" {
  unset GNUPGHOME
  run teardown_gpg_home
  [ "$status" -eq 0 ]
}

@test "teardown_gpg_home is a no-op when GNUPGHOME dir does not exist" {
  export GNUPGHOME="$BATS_TEST_TMPDIR/does-not-exist"
  run teardown_gpg_home
  [ "$status" -eq 0 ]
}

@test "teardown_gpg_home kills gpg-agent spawned in GNUPGHOME" {
  # generate_test_key reliably spawns an agent (same path real tests take).
  generate_test_key "Teardown Test" "teardown@example.com" >/dev/null
  pid=$(agent_pid_for "$GNUPGHOME")
  [ -n "$pid" ]
  kill -0 "$pid"

  teardown_gpg_home

  wait_gone "$pid"
}

@test "setup_extra_gpg_home registers the home for teardown (survives subshell)" {
  # Typical caller pattern: extra=$(setup_extra_gpg_home). The assignment
  # happens in a subshell, so variable-based registration would be lost —
  # test_helper uses a file-backed registry to survive this.
  local extra
  extra=$(setup_extra_gpg_home)
  [ -d "$extra" ]
  grep -qxF "$extra" "$BATS_TEST_TMPDIR/.extra-gpg-homes"

  # Spawn an agent in the extra home.
  GNUPGHOME="$extra" gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-gen-key "Extra <extra@example.com>" default default never 2>/dev/null
  pid=$(agent_pid_for "$extra")
  [ -n "$pid" ]

  teardown_extra_gpg_homes

  wait_gone "$pid"
  [ ! -d "$extra" ]
  [ ! -f "$BATS_TEST_TMPDIR/.extra-gpg-homes" ]
}

