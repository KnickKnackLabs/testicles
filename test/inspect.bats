#!/usr/bin/env bats

setup() {
  load test_helper
  setup_gpg_home
}

@test "inspect shows fingerprint" {
  fpr=$(generate_test_key "Alice" "alice@example.com")

  run keys inspect "alice@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fingerprint"* ]]
  # Formatted fingerprint should be present (spaces between groups)
  [[ "$output" == *"$fpr"* ]] || [[ "$output" == *"$(echo "$fpr" | sed 's/.\{4\}/& /g' | sed 's/ $//')"* ]]
}

@test "inspect shows UID" {
  generate_test_key "Alice" "alice@example.com"

  run keys inspect "alice@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Alice"* ]]
  [[ "$output" == *"alice@example.com"* ]]
}

@test "inspect shows creation date" {
  generate_test_key "Alice" "alice@example.com"

  run keys inspect "alice@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Created"* ]]
}

@test "inspect shows expiration" {
  generate_test_key "Alice" "alice@example.com"

  run keys inspect "alice@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Expires"* ]]
  [[ "$output" == *"never"* ]]
}

@test "inspect shows secret key indicator for own key" {
  generate_test_key "Alice" "alice@example.com"

  run keys inspect "alice@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Secret"* ]]
  [[ "$output" == *"✓"* ]]
}

@test "inspect shows no secret for public-only key" {
  local other_home
  other_home=$(setup_extra_gpg_home)
  GNUPGHOME="$other_home" gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-gen-key "External <ext@example.com>" default default never 2>/dev/null
  GNUPGHOME="$other_home" gpg --batch --armor --export "ext@example.com" \
    | gpg --batch --import 2>/dev/null

  run keys inspect "ext@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Secret"* ]]
  # Should not have checkmark
  [[ "$output" != *"✓"* ]]
}

@test "inspect shows subkeys with algorithm and usage" {
  generate_test_key "Alice" "alice@example.com"

  run keys inspect "alice@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Subkeys"* ]]
  [[ "$output" == *"Algorithm"* ]]
  [[ "$output" == *"Usage"* ]]
}

@test "inspect shows multiple UIDs" {
  fpr=$(generate_test_key "Alice" "alice@example.com")
  # Add a second UID
  gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-add-uid "$fpr" "Alice Work <alice@work.com>" 2>/dev/null

  run keys inspect "alice@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice@example.com"* ]]
  [[ "$output" == *"alice@work.com"* ]]
}

@test "inspect shows certifications section" {
  fpr_alice=$(generate_test_key "Alice" "alice@example.com")
  fpr_bob=$(generate_test_key "Bob" "bob@example.com")

  # Bob certifies Alice's key
  echo -e "y\n" | gpg --batch --pinentry-mode loopback --passphrase '' \
    --command-fd 0 --local-user "$fpr_bob" --sign-key "$fpr_alice" 2>/dev/null

  run keys inspect "alice@example.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Certifications"* ]]
  [[ "$output" == *"bob@example.com"* ]]
}

@test "inspect fails for unknown key" {
  run keys inspect "nobody@example.com"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no key found"* ]]
}

@test "inspect --json returns valid JSON" {
  generate_test_key "Alice" "alice@example.com"

  run keys inspect --json "alice@example.com"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert 'fingerprint' in data
assert 'algorithm' in data
assert 'uids' in data
assert 'subkeys' in data
assert 'certifications' in data
assert 'secret' in data
assert 'created' in data
assert 'expires' in data
assert isinstance(data['uids'], list)
assert len(data['uids']) >= 1
assert data['uids'][0]['email'] == 'alice@example.com'
if data['subkeys']:
    sk = data['subkeys'][0]
    assert 'algorithm' in sk
    assert 'usage' in sk
"
}
