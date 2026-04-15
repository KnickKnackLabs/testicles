#!/usr/bin/env bats

setup() {
  load test_helper
  setup_gpg_home
}

# --- Sign ---

@test "sign a message" {
  generate_test_key "Alice" "alice@example.com"

  run keys sign "hello world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BEGIN PGP MESSAGE"* ]]
}

@test "sign --clear produces readable signed message" {
  generate_test_key "Alice" "alice@example.com"

  run keys sign --clear "hello world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BEGIN PGP SIGNED MESSAGE"* ]]
  [[ "$output" == *"hello world"* ]]
}

@test "sign --detach produces detached signature" {
  generate_test_key "Alice" "alice@example.com"

  run keys sign --detach "hello world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BEGIN PGP SIGNATURE"* ]]
}

@test "sign with specific key" {
  generate_test_key "Alice" "alice@example.com"
  generate_test_key "Bob" "bob@example.com"

  run keys sign --key "bob@example.com" --clear "signed by bob"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BEGIN PGP SIGNED MESSAGE"* ]]
}

@test "sign from file" {
  generate_test_key "Alice" "alice@example.com"
  echo "file to sign" > "$BATS_TEST_TMPDIR/doc.txt"

  run keys sign --clear --file "$BATS_TEST_TMPDIR/doc.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"file to sign"* ]]
  [[ "$output" == *"BEGIN PGP SIGNED MESSAGE"* ]]
}

@test "sign fails when key has no secret key" {
  # Import a public-only key
  local other_home
  other_home=$(mktemp -d)
  chmod 700 "$other_home"
  GNUPGHOME="$other_home" gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-gen-key "External <ext@example.com>" default default never 2>/dev/null
  GNUPGHOME="$other_home" gpg --batch --armor --export "ext@example.com" \
    | gpg --batch --import 2>/dev/null

  run keys sign --key "ext@example.com" "test"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no secret key"* ]]
}

@test "sign fails for nonexistent file" {
  generate_test_key "Alice" "alice@example.com"

  run keys sign --file "/nonexistent/file.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"file not found"* ]]
}

# --- Verify ---

@test "verify a cleartext signed message" {
  generate_test_key "Alice" "alice@example.com"

  signed=$(echo "verify me" | gpg --batch --armor --pinentry-mode loopback --passphrase '' --clear-sign 2>/dev/null)

  echo "$signed" > "$BATS_TEST_TMPDIR/signed.asc"
  run keys verify --file "$BATS_TEST_TMPDIR/signed.asc"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓"* ]]
  [[ "$output" == *"Alice"* ]]
}

@test "verify a detached signature" {
  generate_test_key "Alice" "alice@example.com"
  echo "original content" > "$BATS_TEST_TMPDIR/doc.txt"

  gpg --batch --armor --pinentry-mode loopback --passphrase '' \
    --detach-sign < "$BATS_TEST_TMPDIR/doc.txt" > "$BATS_TEST_TMPDIR/doc.txt.sig" 2>/dev/null

  run keys verify --sig "$BATS_TEST_TMPDIR/doc.txt.sig" --file "$BATS_TEST_TMPDIR/doc.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓"* ]]
}

@test "verify fails on tampered content" {
  generate_test_key "Alice" "alice@example.com"
  echo "original" > "$BATS_TEST_TMPDIR/doc.txt"

  gpg --batch --armor --pinentry-mode loopback --passphrase '' \
    --detach-sign < "$BATS_TEST_TMPDIR/doc.txt" > "$BATS_TEST_TMPDIR/doc.txt.sig" 2>/dev/null

  echo "tampered" > "$BATS_TEST_TMPDIR/doc.txt"

  run keys verify --sig "$BATS_TEST_TMPDIR/doc.txt.sig" --file "$BATS_TEST_TMPDIR/doc.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"BAD"* ]]
}

@test "verify --sig requires --file" {
  generate_test_key "Alice" "alice@example.com"

  # Create a real sig file so we get past the "file not found" check
  echo "fake sig" > "$BATS_TEST_TMPDIR/some.sig"
  run keys verify --sig "$BATS_TEST_TMPDIR/some.sig"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--file is required"* ]]
}

@test "sign then verify round-trip" {
  generate_test_key "Alice" "alice@example.com"

  # Sign
  run keys sign --clear "round trip test"
  [ "$status" -eq 0 ]
  echo "$output" > "$BATS_TEST_TMPDIR/signed.asc"

  # Verify
  run keys verify --file "$BATS_TEST_TMPDIR/signed.asc"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓"* ]]
  [[ "$output" == *"Alice"* ]]
}

@test "encrypt+sign then decrypt round-trip" {
  generate_test_key "Alice" "alice@example.com"

  # Sign and encrypt are separate operations — verify they compose
  signed=$(keys sign --clear "secret signed message")
  encrypted=$(echo "$signed" | keys encrypt --to "alice@example.com")
  decrypted=$(echo "$encrypted" | keys decrypt)

  [[ "$decrypted" == *"secret signed message"* ]]
  [[ "$decrypted" == *"BEGIN PGP SIGNED MESSAGE"* ]]
}
