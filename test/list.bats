#!/usr/bin/env bats

setup() {
  load test_helper
  setup_gpg_home
}

@test "list with empty keyring shows no keys message" {
  run keys list
  [ "$status" -eq 0 ]
  [[ "$output" == *"No keys found"* ]]
}

@test "list shows imported key" {
  generate_test_key "Alice" "alice@example.com"

  run keys list
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice@example.com"* ]]
}

@test "list shows multiple keys" {
  generate_test_key "Alice" "alice@example.com"
  generate_test_key "Bob" "bob@example.com"

  run keys list
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice@example.com"* ]]
  [[ "$output" == *"bob@example.com"* ]]
}

@test "list shows Secret column with checkmark for own keys" {
  generate_test_key "Alice" "alice@example.com"

  run keys list
  [ "$status" -eq 0 ]
  [[ "$output" == *"Secret"* ]]
  [[ "$output" == *"✓"* ]]
}

@test "list shows Created and Expires columns" {
  generate_test_key "Alice" "alice@example.com"

  run keys list
  [ "$status" -eq 0 ]
  [[ "$output" == *"Created"* ]]
  [[ "$output" == *"Expires"* ]]
  [[ "$output" == *"never"* ]]
}

# -- Filtering --

@test "list filters by pattern" {
  generate_test_key "Alice" "alice@example.com"
  generate_test_key "Bob" "bob@other.org"

  run keys list "alice"
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice@example.com"* ]]
  [[ "$output" != *"bob@other.org"* ]]
}

@test "list filters by domain" {
  generate_test_key "Alice" "alice@example.com"
  generate_test_key "Bob" "bob@other.org"

  run keys list "other.org"
  [ "$status" -eq 0 ]
  [[ "$output" != *"alice@example.com"* ]]
  [[ "$output" == *"bob@other.org"* ]]
}

@test "list pattern filter is case-insensitive" {
  generate_test_key "Alice" "alice@example.com"

  run keys list "ALICE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice@example.com"* ]]
}

@test "list pattern with no matches shows no keys" {
  generate_test_key "Alice" "alice@example.com"

  run keys list "nobody"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No keys found"* ]]
}

@test "list pattern matches full fingerprint" {
  local fpr
  fpr=$(generate_test_key "Alice" "alice@example.com")

  run keys list "$fpr"
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice@example.com"* ]]
}

@test "list pattern matches short key ID (last 16 chars)" {
  local fpr
  fpr=$(generate_test_key "Alice" "alice@example.com")
  local short="${fpr: -16}"

  run keys list "$short"
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice@example.com"* ]]
}

@test "list pattern matches partial fingerprint" {
  local fpr
  fpr=$(generate_test_key "Alice" "alice@example.com")
  # Middle slice of the fingerprint
  local middle="${fpr:16:8}"

  run keys list "$middle"
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice@example.com"* ]]
}

@test "list fingerprint match is case-insensitive" {
  local fpr
  fpr=$(generate_test_key "Alice" "alice@example.com")
  # Convert fingerprint to lowercase
  local lower
  lower=$(echo "$fpr" | tr '[:upper:]' '[:lower:]')

  run keys list "$lower"
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice@example.com"* ]]
}

# -- Secret/Public filters --

@test "list --secret shows only keys with private key" {
  generate_test_key "Alice" "alice@example.com"
  # Import a public-only key
  local other_home
  other_home=$(setup_extra_gpg_home)
  GNUPGHOME="$other_home" gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-gen-key "External <ext@example.com>" default default never 2>/dev/null
  GNUPGHOME="$other_home" gpg --batch --armor --export "ext@example.com" \
    | gpg --batch --import 2>/dev/null

  run keys list --secret
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice@example.com"* ]]
  [[ "$output" != *"ext@example.com"* ]]
}

@test "list --public shows only keys without private key" {
  generate_test_key "Alice" "alice@example.com"
  local other_home
  other_home=$(setup_extra_gpg_home)
  GNUPGHOME="$other_home" gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-gen-key "External <ext@example.com>" default default never 2>/dev/null
  GNUPGHOME="$other_home" gpg --batch --armor --export "ext@example.com" \
    | gpg --batch --import 2>/dev/null

  run keys list --public
  [ "$status" -eq 0 ]
  [[ "$output" != *"alice@example.com"* ]]
  [[ "$output" == *"ext@example.com"* ]]
}

# -- JSON --

@test "list --json returns valid JSON with all fields" {
  generate_test_key "Alice" "alice@example.com"

  run keys list --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert isinstance(data, list), 'expected array'
assert len(data) == 1, f'expected 1 key, got {len(data)}'
key = data[0]
assert 'fingerprint' in key
assert 'name' in key
assert 'email' in key
assert 'secret' in key
assert 'created' in key
assert 'expires' in key
assert key['secret'] is True
assert key['name'] == 'Alice', f'expected Alice, got {key[\"name\"]}'
assert key['email'] == 'alice@example.com'
"
}

@test "list --json with empty keyring returns empty array" {
  run keys list --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert data == [], f'expected empty array, got {data}'
"
}

@test "list --json respects pattern filter" {
  generate_test_key "Alice" "alice@example.com"
  generate_test_key "Bob" "bob@other.org"

  run keys list --json "alice"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert len(data) == 1
assert data[0]['email'] == 'alice@example.com'
"
}
