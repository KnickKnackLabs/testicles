#!/usr/bin/env bats
# Tests for fetch/publish — mocks gpg to verify correct invocation
# without requiring a live keyserver.

setup() {
  load test_helper
  setup_gpg_home

  # Create a mock gpg that records arguments and impersonates the real one
  # just enough for resolve_key() and query_key_uids() to work.
  MOCK_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$MOCK_BIN"

  GPG_LOG="$BATS_TEST_TMPDIR/gpg.log"
  export GPG_LOG

  # The mock: delegates read-only queries to the real gpg but records
  # any keyserver operations (--send-keys, --recv-keys, --locate-external-keys).
  cat > "$MOCK_BIN/gpg" <<'MOCK'
#!/usr/bin/env bash
# Record the full invocation
printf '%s\n' "$*" >> "$GPG_LOG"

# Detect keyserver operations and short-circuit (don't hit the network)
for arg in "$@"; do
  case "$arg" in
    --send-keys|--recv-keys|--locate-external-keys)
      echo "[mock-gpg] would perform: $arg"
      exit 0
      ;;
  esac
done

# Everything else: delegate to the real gpg
exec /usr/bin/env -u PATH PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin gpg "$@"
MOCK
  chmod +x "$MOCK_BIN/gpg"
  export PATH="$MOCK_BIN:$PATH"
}

# Helper: check that the last gpg invocation contained all given args
assert_gpg_called_with() {
  local expected="$1"
  grep -qF -- "$expected" "$GPG_LOG"
}

# --- fetch ---

@test "fetch calls gpg --recv-keys for fingerprint identifier" {
  run keys fetch "ABCDEF1234567890ABCDEF1234567890ABCDEF12"
  [ "$status" -eq 0 ]
  assert_gpg_called_with "--recv-keys ABCDEF1234567890ABCDEF1234567890ABCDEF12"
}

@test "fetch calls gpg --locate-external-keys for email identifier" {
  run keys fetch "alice@example.com"
  [ "$status" -eq 0 ]
  assert_gpg_called_with "--locate-external-keys alice@example.com"
}

@test "fetch passes --keyserver flag through" {
  run keys fetch --keyserver "hkps://keys.example.com" "ABCDEF1234567890ABCDEF1234567890ABCDEF12"
  [ "$status" -eq 0 ]
  assert_gpg_called_with "--keyserver hkps://keys.example.com"
}

@test "fetch uses KEYS_KEYSERVER default when no --keyserver given" {
  KEYS_KEYSERVER="hkps://default.example.com" run keys fetch "ABCDEF1234567890ABCDEF1234567890ABCDEF12"
  [ "$status" -eq 0 ]
  assert_gpg_called_with "--keyserver hkps://default.example.com"
}

@test "fetch prepends hkps:// when keyserver has no scheme" {
  run keys fetch --keyserver "keys.example.com" "ABCDEF1234567890ABCDEF1234567890ABCDEF12"
  [ "$status" -eq 0 ]
  assert_gpg_called_with "--keyserver hkps://keys.example.com"
}

# --- publish ---

@test "publish calls gpg --send-keys with resolved fingerprint" {
  local fpr
  fpr=$(generate_test_key "Alice" "alice@example.com")

  run keys publish --yes "alice@example.com"
  [ "$status" -eq 0 ]
  assert_gpg_called_with "--send-keys $fpr"
}

@test "publish fails for unknown key" {
  run keys publish --yes "nobody@example.com"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no key found"* ]]
}

@test "publish passes --keyserver flag through" {
  generate_test_key "Alice" "alice@example.com"

  run keys publish --yes --keyserver "hkps://keys.example.com" "alice@example.com"
  [ "$status" -eq 0 ]
  assert_gpg_called_with "--keyserver hkps://keys.example.com"
}

@test "publish shows fingerprint and UID before uploading" {
  generate_test_key "Alice" "alice@example.com"

  run keys publish --yes "alice@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Publishing key to"* ]]
  [[ "$output" == *"alice@example.com"* ]]
  [[ "$output" == *"✓ Published"* ]]
}

@test "publish --first works with ambiguous matches" {
  generate_test_key "Alice Smith" "alice@example.com"
  generate_test_key "Alice Jones" "alice-j@example.com"

  run keys publish --yes --first "example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Published"* ]]
}
