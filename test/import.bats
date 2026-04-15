#!/usr/bin/env bats

setup() {
  load test_helper
  setup_gpg_home
}

@test "import a key from file" {
  # Generate a key and export it
  fpr=$(generate_test_key "Alice" "alice@example.com")
  export_test_key "alice@example.com" "$BATS_TEST_TMPDIR/alice.asc"

  # Delete from keyring, then reimport
  gpg --batch --yes --delete-secret-and-public-key "$fpr" 2>/dev/null

  run keys import "$BATS_TEST_TMPDIR/alice.asc"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Imported"* ]]
  [[ "$output" == *"alice@example.com"* ]]

  # Verify it's actually in the keyring now
  run gpg --batch --list-keys "alice@example.com"
  [ "$status" -eq 0 ]
}

@test "import from stdin" {
  fpr=$(generate_test_key "Bob" "bob@example.com")
  export_test_key "bob@example.com" "$BATS_TEST_TMPDIR/bob.asc"
  gpg --batch --yes --delete-secret-and-public-key "$fpr" 2>/dev/null

  run bash -c 'keys import < "$BATS_TEST_TMPDIR/bob.asc"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Imported"* ]]
}

@test "import fails for nonexistent file" {
  run keys import "/nonexistent/key.asc"
  [ "$status" -ne 0 ]
  [[ "$output" == *"file not found"* ]]
}

@test "import is idempotent" {
  generate_test_key "Alice" "alice@example.com"
  export_test_key "alice@example.com" "$BATS_TEST_TMPDIR/alice.asc"

  # Import the same key again — should succeed, not error
  run keys import "$BATS_TEST_TMPDIR/alice.asc"
  [ "$status" -eq 0 ]
}
