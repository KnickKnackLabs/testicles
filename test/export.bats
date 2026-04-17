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
