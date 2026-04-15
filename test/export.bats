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
