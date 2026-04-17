#!/usr/bin/env bats

setup() {
  load test_helper
  setup_gpg_home
}

@test "export outputs armored public key" {
  generate_test_key "Alice" "alice@example.com"

  run keys export "alice@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BEGIN PGP PUBLIC KEY BLOCK"* ]]
  [[ "$output" == *"END PGP PUBLIC KEY BLOCK"* ]]
}

@test "export by fingerprint works" {
  fpr=$(generate_test_key "Alice" "alice@example.com")

  run keys export "$fpr"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BEGIN PGP PUBLIC KEY BLOCK"* ]]
}

@test "export fails for unknown key" {
  run keys export "nobody@example.com"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no key found"* ]] || [[ "$output" == *"Error"* ]]
}

@test "export --secret outputs armored secret key" {
  generate_test_key "Alice" "alice@example.com"

  run keys export --secret "alice@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BEGIN PGP PRIVATE KEY BLOCK"* ]]
  [[ "$output" == *"END PGP PRIVATE KEY BLOCK"* ]]
}

@test "export --public is same as default" {
  generate_test_key "Alice" "alice@example.com"

  run keys export --public "alice@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BEGIN PGP PUBLIC KEY BLOCK"* ]]
}

@test "export --secret fails when no private key" {
  local fpr
  fpr=$(generate_test_key "Alice" "alice@example.com")

  # Delete secret, keep public
  local pubkey="$BATS_TEST_TMPDIR/alice.pub"
  gpg --batch --armor --export "alice@example.com" > "$pubkey"
  gpg --batch --yes --delete-secret-keys "$fpr" 2>/dev/null

  run keys export --secret "alice@example.com"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no secret key"* ]]
}

@test "export --secret and --public are mutually exclusive" {
  generate_test_key "Alice" "alice@example.com"

  run keys export --secret --public "alice@example.com"
  [ "$status" -ne 0 ]
  [[ "$output" == *"mutually exclusive"* ]]
}

# --- Passphrase-protected keys ---

@test "export --secret on passphrase-protected key with TESTICLES_PASSPHRASE env var" {
  generate_test_key_with_passphrase "Alice" "alice@example.com" "hunter2"

  TESTICLES_PASSPHRASE="hunter2" run keys export --secret "alice@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BEGIN PGP PRIVATE KEY BLOCK"* ]]
}

@test "export --secret on passphrase-protected key with --passphrase-file" {
  generate_test_key_with_passphrase "Alice" "alice@example.com" "hunter2"

  local pf="$BATS_TEST_TMPDIR/pass.txt"
  echo -n "hunter2" > "$pf"

  run keys export --secret --passphrase-file "$pf" "alice@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BEGIN PGP PRIVATE KEY BLOCK"* ]]
}

@test "export --secret fails with wrong passphrase" {
  generate_test_key_with_passphrase "Alice" "alice@example.com" "hunter2"

  TESTICLES_PASSPHRASE="wrong" run keys export --secret "alice@example.com"
  [ "$status" -ne 0 ]
}

@test "export --secret --passphrase-file fails if file missing" {
  generate_test_key "Alice" "alice@example.com"

  run keys export --secret --passphrase-file "/nonexistent/file" "alice@example.com"
  [ "$status" -ne 0 ]
  [[ "$output" == *"passphrase file not found"* ]]
}
