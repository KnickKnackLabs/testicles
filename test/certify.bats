#!/usr/bin/env bats

setup() {
  load test_helper
  setup_gpg_home
}

# --- Happy path ---

@test "certify a key adds certification" {
  local signer_fpr target_fpr
  signer_fpr=$(generate_test_key "Alice" "alice@example.com")
  target_fpr=$(generate_test_key "Bob" "bob@example.com")

  run keys certify --yes "bob@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Certified"* ]]

  # Verify the certification exists
  local certs
  certs=$(gpg --batch --with-colons --check-sigs "$target_fpr" 2>/dev/null \
    | awk -F: -v signer="${signer_fpr: -16}" '/^sig:/ && $5 == signer { print "found" }')
  [ "$certs" = "found" ]
}

@test "certify with specific --key" {
  generate_test_key "Alice" "alice@example.com"
  local bob_fpr target_fpr
  bob_fpr=$(generate_test_key "Bob" "bob@example.com")
  target_fpr=$(generate_test_key "Charlie" "charlie@example.com")

  run keys certify --yes --key "bob@example.com" "charlie@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Certified"* ]]

  # Verify Bob (not Alice) signed Charlie's key
  local certs
  certs=$(gpg --batch --with-colons --check-sigs "$target_fpr" 2>/dev/null \
    | awk -F: -v signer="${bob_fpr: -16}" '/^sig:/ && $5 == signer { print "found" }')
  [ "$certs" = "found" ]
}

@test "certify shows certifications after signing" {
  generate_test_key "Alice" "alice@example.com"
  generate_test_key "Bob" "bob@example.com"

  run keys certify --yes "bob@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Certifications:"* ]]
  [[ "$output" == *"Alice"* ]]
}

# --- Error cases ---

@test "certify fails for unknown key" {
  generate_test_key "Alice" "alice@example.com"

  run keys certify --yes "nobody@example.com"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no key found"* ]]
}

@test "certify --key fails when signing key has no secret" {
  generate_test_key "Alice" "alice@example.com"
  local bob_fpr
  bob_fpr=$(generate_test_key "Bob" "bob@example.com")

  # Export Bob's public key, delete secret, re-import public only
  local pubkey="$BATS_TEST_TMPDIR/bob.pub"
  gpg --batch --armor --export "bob@example.com" > "$pubkey"
  gpg --batch --yes --delete-secret-keys "$bob_fpr" 2>/dev/null
  gpg --batch --import "$pubkey" 2>/dev/null

  run keys certify --yes --key "bob@example.com" "alice@example.com"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no secret key"* ]]
}

@test "certify shows key details before signing" {
  generate_test_key "Alice" "alice@example.com"
  generate_test_key "Bob" "bob@example.com"

  run keys certify --yes "bob@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Certifying key:"* ]]
  [[ "$output" == *"Bob"* ]]
}
