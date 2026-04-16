#!/usr/bin/env bats
# Tests for resolve_key() ambiguity handling: --first flag and error messages

setup() {
  load test_helper
  setup_gpg_home

  # Create two keys with the same domain to simulate ambiguity
  generate_test_key "Alice Smith" "alice@example.com"
  generate_test_key "Alice Jones" "alice-j@example.com"
}

# --- --first flag ---

@test "inspect --first picks first match on ambiguous query" {
  # Both keys match "example.com"
  run keys inspect --first "example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Key Details"* ]]
}

@test "export --first picks first match on ambiguous query" {
  run keys export --first "example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BEGIN PGP PUBLIC KEY BLOCK"* ]]
}

@test "certify --first picks first match on ambiguous query" {
  run keys certify --first --yes "example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Certified"* ]]
}

@test "sign --first picks first match on ambiguous query" {
  run keys sign --first --key "example.com" --clear "hello"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BEGIN PGP SIGNED MESSAGE"* ]]
}

@test "encrypt --first picks first match on ambiguous query" {
  run keys encrypt --first --to "example.com" "secret message"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BEGIN PGP MESSAGE"* ]]
}

@test "remove --first picks first match on ambiguous query" {
  run keys remove --first --yes "example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed"* ]]
}

# --- Error message without --first ---

@test "ambiguous match without --first shows error and suggests --first" {
  run keys inspect "example.com"
  [ "$status" -ne 0 ]
  [[ "$output" == *"multiple keys match"* ]]
  [[ "$output" == *"--first"* ]]
}

@test "single match works without --first" {
  run keys inspect "alice@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Key Details"* ]]
  [[ "$output" == *"Alice Smith"* ]]
}
