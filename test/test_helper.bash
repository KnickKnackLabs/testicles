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
