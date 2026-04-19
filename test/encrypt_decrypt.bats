#!/usr/bin/env bats

setup() {
  load test_helper
  setup_gpg_home
}

@test "encrypt and decrypt a message" {
  fpr=$(generate_test_key "Alice" "alice@example.com")

  run keys encrypt --to "alice@example.com" "hello secret world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BEGIN PGP MESSAGE"* ]]

  # Decrypt it
  run bash -c 'echo "$1" | keys decrypt' -- "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hello secret world"* ]]
}

@test "encrypt to multiple recipients" {
  generate_test_key "Alice" "alice@example.com"
  generate_test_key "Bob" "bob@example.com"

  run keys encrypt --to "alice@example.com" --to "bob@example.com" "shared secret"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BEGIN PGP MESSAGE"* ]]

  # Either recipient can decrypt
  run bash -c 'echo "$1" | keys decrypt' -- "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"shared secret"* ]]
}

@test "encrypt from file" {
  generate_test_key "Alice" "alice@example.com"
  echo "file contents here" > "$BATS_TEST_TMPDIR/secret.txt"

  run keys encrypt --to "alice@example.com" --file "$BATS_TEST_TMPDIR/secret.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BEGIN PGP MESSAGE"* ]]

  run bash -c 'echo "$1" | keys decrypt' -- "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"file contents here"* ]]
}

@test "decrypt from file" {
  generate_test_key "Alice" "alice@example.com"

  # Encrypt to a file
  echo "decrypt me" | gpg --batch --armor --trust-model always \
    --encrypt --recipient "alice@example.com" > "$BATS_TEST_TMPDIR/encrypted.asc" 2>/dev/null

  run keys decrypt --file "$BATS_TEST_TMPDIR/encrypted.asc"
  [ "$status" -eq 0 ]
  [[ "$output" == *"decrypt me"* ]]
}

@test "encrypt fails without --to" {
  run keys encrypt "hello"
  [ "$status" -ne 0 ]
  [[ "$output" == *"at least one --to"* ]]
}

@test "encrypt fails for unknown recipient" {
  run keys encrypt --to "nobody@example.com" "hello"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no key found"* ]]
}

@test "decrypt fails on non-encrypted input" {
  run bash -c 'echo "not encrypted" | keys decrypt'
  [ "$status" -ne 0 ]
}

@test "decrypt fails for wrong recipient" {
  generate_test_key "Alice" "alice@example.com"

  # Create Bob in a separate keyring and encrypt to him
  local bob_home
  bob_home=$(setup_extra_gpg_home)
  GNUPGHOME="$bob_home" gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-gen-key "Bob <bob@example.com>" default default never 2>/dev/null
  ciphertext=$(echo "for bob only" | GNUPGHOME="$bob_home" gpg --batch --armor --trust-model always \
    --encrypt --recipient "bob@example.com" 2>/dev/null)

  # Alice can't decrypt Bob's message
  run bash -c 'echo "$1" | keys decrypt' -- "$ciphertext"
  [ "$status" -ne 0 ]
}
