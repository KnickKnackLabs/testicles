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

@test "list --json returns valid JSON array" {
  generate_test_key "Alice" "alice@example.com"

  run keys list --json
  [ "$status" -eq 0 ]
  # Should be parseable JSON with expected fields
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert isinstance(data, list), 'expected array'
assert len(data) == 1, f'expected 1 key, got {len(data)}'
assert 'fingerprint' in data[0]
assert 'uid' in data[0]
assert 'alice@example.com' in data[0]['uid']
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
