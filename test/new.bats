#!/usr/bin/env bats

setup() {
  load test_helper
  setup_gpg_home
}

@test "new creates a key with --no-passphrase" {
  run keys new --no-passphrase "Alice <alice@example.com>"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Generated key"* ]]
  [[ "$output" == *"alice@example.com"* ]]

  # Verify key exists
  run gpg --batch --list-keys alice@example.com
  [ "$status" -eq 0 ]
}

@test "new creates a passphrase-protected key via TESTICLES_PASSPHRASE" {
  TESTICLES_PASSPHRASE="hunter2" run keys new "Bob <bob@example.com>"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Generated key"* ]]

  # Verify the key requires the passphrase — export should fail without it
  run keys export --secret "bob@example.com"
  [ "$status" -ne 0 ]

  # And succeed with it
  TESTICLES_PASSPHRASE="hunter2" run keys export --secret "bob@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BEGIN PGP PRIVATE KEY BLOCK"* ]]
}

@test "new respects --passphrase-file" {
  local pf="$BATS_TEST_TMPDIR/pass.txt"
  echo -n "s3cr3t" > "$pf"

  run keys new --passphrase-file "$pf" "Carol <carol@example.com>"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Generated key"* ]]

  TESTICLES_PASSPHRASE="s3cr3t" run keys export --secret "carol@example.com"
  [ "$status" -eq 0 ]
}

@test "new respects --algorithm" {
  run keys new --no-passphrase --algorithm rsa2048 "Dave <dave@example.com>"
  [ "$status" -eq 0 ]

  run keys inspect --json "dave@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"RSA 2048"* ]]
}

@test "new requires a UID" {
  run keys new --no-passphrase ""
  [ "$status" -ne 0 ]
}

@test "new --passphrase-file fails if file missing" {
  run keys new --passphrase-file "/nonexistent/file" "Eve <eve@example.com>"
  [ "$status" -ne 0 ]
  [[ "$output" == *"passphrase file not found"* ]]
}

@test "new fails with helpful message when key already exists" {
  run keys new --no-passphrase "Frank <frank@example.com>"
  [ "$status" -eq 0 ]

  # Second attempt should fail with a meaningful error
  run keys new --no-passphrase "Frank <frank@example.com>"
  [ "$status" -ne 0 ]
  [[ "$output" == *"key generation failed"* ]]
  [[ "$output" == *"already exists"* ]]
}
