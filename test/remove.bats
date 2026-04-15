#!/usr/bin/env bats

setup() {
  load test_helper
  setup_gpg_home
}

@test "remove deletes a public-only key" {
  # Create a key in a separate home and import just the public part
  local other_home
  other_home=$(mktemp -d)
  chmod 700 "$other_home"
  GNUPGHOME="$other_home" gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-gen-key "External <ext@example.com>" default default never 2>/dev/null
  GNUPGHOME="$other_home" gpg --batch --armor --export "ext@example.com" \
    | gpg --batch --import 2>/dev/null

  run keys remove "ext@example.com" --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed"* ]]

  # Verify it's gone
  run gpg --batch --list-keys "ext@example.com"
  [ "$status" -ne 0 ]
}

@test "remove deletes a key with private key" {
  fpr=$(generate_test_key "Alice" "alice@example.com")

  run keys remove "alice@example.com" --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING"* ]]
  [[ "$output" == *"Removed"* ]]

  # Verify it's gone
  run gpg --batch --list-keys "alice@example.com"
  [ "$status" -ne 0 ]
}

@test "remove fails for unknown key" {
  run keys remove "nobody@example.com" --yes
  [ "$status" -ne 0 ]
  [[ "$output" == *"no key found"* ]]
}

@test "remove shows key details before removing" {
  generate_test_key "Alice" "alice@example.com"

  run keys remove "alice@example.com" --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice@example.com"* ]]
  [[ "$output" == *"Fingerprint"* ]]
}
