#!/usr/bin/env bash
# Test helper for keys — sets up isolated GPG home and the keys() wrapper

if [ -z "${MISE_CONFIG_ROOT:-}" ]; then
  echo "MISE_CONFIG_ROOT not set — run tests via: mise run test" >&2
  exit 1
fi

# Each test gets its own GPG home — fully isolated from the real keyring
setup_gpg_home() {
  export GNUPGHOME="$BATS_TEST_TMPDIR/gnupg"
  mkdir -p "$GNUPGHOME"
  chmod 700 "$GNUPGHOME"
}

# Kill any gpg-agent/dirmngr spawned into this test's GNUPGHOME.
#
# gpg auto-spawns a gpg-agent daemon in $GNUPGHOME on first use. If we let BATS
# wipe $BATS_TEST_TMPDIR with the agent still running, we leak a zombie daemon
# (socket gone, process still alive) for every test. Under load that exhausts
# fds/process limits and subsequent runs hang waiting for an agent to bind a
# socket — the "hangs partway through" flakiness.
#
# Called automatically by BATS after each test that loads this helper.
# Individual .bats files can override teardown() if they need custom behavior,
# but should call teardown_gpg_home themselves in that case.
teardown_gpg_home() {
  if [ -n "${GNUPGHOME:-}" ] && [ -d "$GNUPGHOME" ]; then
    gpgconf --homedir "$GNUPGHOME" --kill all 2>/dev/null || true
  fi
}

# Create an additional isolated GPG home and register it for agent+dir cleanup
# in teardown. Prints the path on stdout. Use this instead of a bare
# `mktemp -d` when a test needs a second keyring — otherwise the gpg-agent
# spawned there leaks (homedir isn't under $BATS_TEST_TMPDIR, so BATS doesn't
# wipe it, and nothing kills the daemon).
#
# Uses mktemp rather than a path under $BATS_TEST_TMPDIR because the BATS
# tmpdir is already ~70 chars deep, and gpg-agent's AF_UNIX socket path is
# capped at 104 chars on macOS — anything longer makes gpg-agent fail to bind.
#
# Tracks registered homes in a file (not a shell var) because callers use this
# via `home=$(setup_extra_gpg_home)`, which runs in a subshell — a var set
# there wouldn't survive back to teardown().
setup_extra_gpg_home() {
  local home
  home=$(mktemp -d)
  chmod 700 "$home"
  echo "$home" >> "$BATS_TEST_TMPDIR/.extra-gpg-homes"
  echo "$home"
}

# Kill gpg-agents and remove every home registered via setup_extra_gpg_home.
teardown_extra_gpg_homes() {
  local registry="$BATS_TEST_TMPDIR/.extra-gpg-homes"
  [ -f "$registry" ] || return 0
  local h
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    gpgconf --homedir "$h" --kill all 2>/dev/null || true
    rm -rf "$h" 2>/dev/null || true
  done < "$registry"
  rm -f "$registry"
}

teardown() {
  teardown_gpg_home
  teardown_extra_gpg_homes
}

# Generate a test key (no passphrase, no interaction)
generate_test_key() {
  local name="${1:-Test User}"
  local email="${2:-test@example.com}"

  gpg --batch --pinentry-mode loopback --passphrase '' --quick-gen-key "$name <$email>" default default never 2>/dev/null

  # Return the fingerprint
  gpg --batch --with-colons --list-keys "$email" 2>/dev/null \
    | awk -F: '/^fpr:/ { print $10; exit }'
}

# Generate a test key with a passphrase
generate_test_key_with_passphrase() {
  local name="${1:-Test User}"
  local email="${2:-test@example.com}"
  local passphrase="${3:-correct-horse-battery-staple}"

  gpg --batch --pinentry-mode loopback --passphrase "$passphrase" \
    --quick-gen-key "$name <$email>" default default never 2>/dev/null

  gpg --batch --with-colons --list-keys "$email" 2>/dev/null \
    | awk -F: '/^fpr:/ { print $10; exit }'
}

# Export a test key to a file
export_test_key() {
  local email="$1"
  local outfile="$2"
  gpg --batch --armor --export "$email" > "$outfile"
}

# The wrapper — calls keys tasks through mise
keys() {
  cd "$MISE_CONFIG_ROOT" && mise run -q "$@"
}
export -f keys
