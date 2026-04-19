#!/usr/bin/env bats
# Tests for lib/common.sh query functions

setup() {
  load test_helper
  setup_gpg_home
  source "$MISE_CONFIG_ROOT/lib/common.sh"
}

# --- query_key_meta ---

@test "query_key_meta sets algorithm and dates" {
  fpr=$(generate_test_key "Alice" "alice@example.com")

  query_key_meta "$fpr"
  [ -n "$KEY_ALGO" ]
  [[ "$KEY_ALGO" == *"255"* ]] || [[ "$KEY_ALGO" == *"4096"* ]] || [[ "$KEY_ALGO" == *"256"* ]]
  [ "$KEY_CREATED" != "unknown" ]
  [ "$KEY_EXPIRES" = "never" ]
  [ -n "$KEY_ALGO_NUM" ]
  [ -n "$KEY_BITS" ]
  [ -n "$KEY_CREATED_TS" ]
}

@test "query_key_meta sets raw timestamps" {
  fpr=$(generate_test_key "Alice" "alice@example.com")

  query_key_meta "$fpr"
  # Timestamp should be a number
  [[ "$KEY_CREATED_TS" =~ ^[0-9]+$ ]]
}

# --- query_key_uids ---

@test "query_key_uids returns single UID" {
  fpr=$(generate_test_key "Alice" "alice@example.com")

  query_key_uids "$fpr"
  [ ${#KEY_UIDS[@]} -eq 1 ]
  [[ "${KEY_UIDS[0]}" == *"alice@example.com"* ]]
}

@test "query_key_uids returns multiple UIDs" {
  fpr=$(generate_test_key "Alice" "alice@example.com")
  gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-add-uid "$fpr" "Alice Work <alice@work.com>" 2>/dev/null

  query_key_uids "$fpr"
  [ ${#KEY_UIDS[@]} -eq 2 ]
}

@test "query_key_uids is empty for nonexistent key" {
  query_key_uids "0000000000000000000000000000000000000000"
  [ ${#KEY_UIDS[@]} -eq 0 ]
}

# --- query_key_subkeys ---

@test "query_key_subkeys returns subkey with algorithm and usage" {
  fpr=$(generate_test_key "Alice" "alice@example.com")

  query_key_subkeys "$fpr"
  [ ${#KEY_SUBKEYS[@]} -ge 1 ]

  # Each entry is tab-delimited: id\talgorithm\tusage\tcreated\texpires
  local first="${KEY_SUBKEYS[0]}"
  local algo usage
  algo=$(echo "$first" | cut -f2)
  usage=$(echo "$first" | cut -f3)
  [ -n "$algo" ]
  [ -n "$usage" ]
}

@test "query_key_subkeys shows correct usage flags" {
  fpr=$(generate_test_key "Alice" "alice@example.com")

  query_key_subkeys "$fpr"
  # Default key gen creates at least an encryption subkey
  local all_usage=""
  for sk in "${KEY_SUBKEYS[@]}"; do
    all_usage="$all_usage $(echo "$sk" | cut -f3)"
  done
  # Should have at least one of sign or encrypt
  [[ "$all_usage" == *"sign"* ]] || [[ "$all_usage" == *"encrypt"* ]]
}

# --- query_key_certifications ---

@test "query_key_certifications is empty for uncertified key" {
  fpr=$(generate_test_key "Alice" "alice@example.com")

  query_key_certifications "$fpr"
  [ ${#KEY_CERTS[@]} -eq 0 ]
}

@test "query_key_certifications finds cross-signature" {
  fpr_alice=$(generate_test_key "Alice" "alice@example.com")
  fpr_bob=$(generate_test_key "Bob" "bob@example.com")

  echo -e "y\n" | gpg --batch --pinentry-mode loopback --passphrase '' \
    --command-fd 0 --local-user "$fpr_bob" --sign-key "$fpr_alice" 2>/dev/null

  query_key_certifications "$fpr_alice"
  [ ${#KEY_CERTS[@]} -ge 1 ]
  # Should include Bob's UID
  local first="${KEY_CERTS[0]}"
  [[ "$first" == *"bob@example.com"* ]]
}

@test "query_key_certifications excludes self-signatures" {
  fpr=$(generate_test_key "Alice" "alice@example.com")

  query_key_certifications "$fpr"
  # Self-sigs should be filtered out
  for cert in ${KEY_CERTS[@]+"${KEY_CERTS[@]}"}; do
    [[ "$cert" != *"alice@example.com"* ]]
  done
}

# --- has_secret_key ---

@test "has_secret_key returns true for generated key" {
  fpr=$(generate_test_key "Alice" "alice@example.com")

  has_secret_key "$fpr"
}

@test "has_secret_key returns false for public-only key" {
  local other_home
  other_home=$(setup_extra_gpg_home)
  GNUPGHOME="$other_home" gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-gen-key "External <ext@example.com>" default default never 2>/dev/null
  GNUPGHOME="$other_home" gpg --batch --armor --export "ext@example.com" \
    | gpg --batch --import 2>/dev/null

  local fpr
  fpr=$(gpg --batch --with-colons --list-keys "ext@example.com" 2>/dev/null \
    | awk -F: '/^pub:/{g=1;next} /^fpr:/&&g{print $10;g=0}')

  ! has_secret_key "$fpr"
}
