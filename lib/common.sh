#!/usr/bin/env bash
# Shared helpers for keys tasks

# Default keyserver (configurable via KEYS_KEYSERVER env var)
KEYS_KEYSERVER="${KEYS_KEYSERVER:-keys.openpgp.org}"

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------

require_gpg() {
  if ! command -v gpg &>/dev/null; then
    echo "Error: gpg not found on PATH" >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Formatting helpers
# ---------------------------------------------------------------------------

# Format a fingerprint for display (groups of 4)
format_fingerprint() {
  local fpr="$1"
  echo "$fpr" | sed 's/.\{4\}/& /g' | sed 's/ $//'
}

# Parse a UID into name and email components.
# Sets PARSED_NAME and PARSED_EMAIL.
parse_uid() {
  local uid="$1"
  PARSED_NAME=""
  PARSED_EMAIL=""

  if [[ "$uid" == *'<'*'>'* ]]; then
    PARSED_NAME=$(echo "$uid" | sed 's/ *<.*>$//')
    PARSED_EMAIL=$(echo "$uid" | sed 's/.*<\(.*\)>/\1/')
  elif [[ "$uid" == *'@'* ]]; then
    PARSED_EMAIL="$uid"
  else
    PARSED_NAME="$uid"
  fi
}

# Map GPG algorithm number to human-readable name
# See https://www.rfc-editor.org/rfc/rfc4880#section-9.1
format_algorithm() {
  local algo_num="$1"
  local bits="$2"
  case "$algo_num" in
    1|2|3)   echo "RSA $bits" ;;
    16)      echo "Elgamal $bits" ;;
    17)      echo "DSA $bits" ;;
    18)      echo "ECDH $bits" ;;
    19)      echo "ECDSA $bits" ;;
    22)      echo "EdDSA $bits" ;;
    *)       echo "algo:$algo_num $bits" ;;
  esac
}

# Map GPG capability flags to human-readable labels
format_capabilities() {
  local caps="$1"
  local labels=()
  [[ "$caps" == *s* ]] && labels+=("sign")
  [[ "$caps" == *e* ]] && labels+=("encrypt")
  [[ "$caps" == *c* ]] && labels+=("certify")
  [[ "$caps" == *a* ]] && labels+=("auth")
  local IFS=','
  echo "${labels[*]}"
}

# Format an expiry timestamp — "never", date, or "date (expired)"
format_expiry() {
  local expires_ts="$1"
  if [ -z "$expires_ts" ] || [ "$expires_ts" = "0" ]; then
    echo "never"
    return
  fi
  local expires_date
  expires_date=$(date -r "$expires_ts" "+%Y-%m-%d" 2>/dev/null || date -d "@$expires_ts" "+%Y-%m-%d" 2>/dev/null || echo "unknown")
  local now
  now=$(date +%s)
  if [ "$expires_ts" -lt "$now" ]; then
    echo "$expires_date (expired)"
  else
    echo "$expires_date"
  fi
}

# Truncate a string to a max length, adding ellipsis if truncated
truncate_str() {
  local str="$1"
  local max="${2:-30}"
  if [ ${#str} -gt "$max" ]; then
    echo "${str:0:$((max - 1))}…"
  else
    echo "$str"
  fi
}

# Format a creation timestamp
format_created() {
  local created_ts="$1"
  if [ -z "$created_ts" ] || [ "$created_ts" = "0" ]; then
    echo "unknown"
    return
  fi
  date -r "$created_ts" "+%Y-%m-%d" 2>/dev/null || date -d "@$created_ts" "+%Y-%m-%d" 2>/dev/null || echo "unknown"
}

# ---------------------------------------------------------------------------
# Passphrase handling
# ---------------------------------------------------------------------------

# Build GPG args for passphrase input based on caller's flags/env.
# Sets the global array PASSPHRASE_ARGS for the caller to splat into gpg args.
#
# Resolution order:
#   1. TESTICLES_PASSPHRASE env var (used in tests and scripts)
#   2. --passphrase-file <path> (usage_passphrase_file)
#   3. TTY prompt via gum (if available and stdin is a terminal)
#   4. Empty passphrase (default, works for passwordless keys)
build_passphrase_args() {
  PASSPHRASE_ARGS=(--pinentry-mode loopback)

  if [ -n "${TESTICLES_PASSPHRASE:-}" ]; then
    PASSPHRASE_ARGS+=(--passphrase "$TESTICLES_PASSPHRASE")
    return 0
  fi

  if [ -n "${usage_passphrase_file:-}" ]; then
    if [ ! -f "$usage_passphrase_file" ]; then
      echo "Error: passphrase file not found: $usage_passphrase_file" >&2
      return 1
    fi
    PASSPHRASE_ARGS+=(--passphrase-file "$usage_passphrase_file")
    return 0
  fi

  # Interactive: prompt via gum
  if [ -t 0 ] && command -v gum &>/dev/null; then
    local pass
    pass=$(gum input --password --placeholder "Passphrase (empty for unprotected keys)")
    PASSPHRASE_ARGS+=(--passphrase "$pass")
    return 0
  fi

  # Fallback: empty passphrase (works for keys without passwords)
  PASSPHRASE_ARGS+=(--passphrase "")
}

# ---------------------------------------------------------------------------
# Key resolution
# ---------------------------------------------------------------------------

# Resolve a key identifier (email, fingerprint, or partial ID) to a fingerprint.
# Returns the full fingerprint on stdout, exits 1 if not found or ambiguous.
#
# When multiple keys match:
#   - If RESOLVE_FIRST=true, picks the first match
#   - If a TTY is available, presents an interactive picker (gum choose)
#   - Otherwise, errors with the list of matches
#
# Callers set RESOLVE_FIRST=true based on their --first flag.
resolve_key() {
  local identifier="$1"
  local fingerprints

  fingerprints=$(gpg --batch --with-colons --list-keys "$identifier" 2>/dev/null \
    | awk -F: '/^pub:/ { getfpr=1; next } /^fpr:/ && getfpr { print $10; getfpr=0 }')

  if [ -z "$fingerprints" ]; then
    echo "Error: no key found for '$identifier'" >&2
    return 1
  fi

  local count
  count=$(echo "$fingerprints" | wc -l | tr -d ' ')

  if [ "$count" -gt 1 ]; then
    # --first: pick the first match
    if [ "${RESOLVE_FIRST:-}" = "true" ]; then
      echo "$fingerprints" | head -1
      return 0
    fi

    # Interactive: let the user pick via gum choose
    if [ -t 0 ] && command -v gum &>/dev/null; then
      local options=()
      while IFS= read -r fpr; do
        local uid
        uid=$(gpg --batch --with-colons --list-keys "$fpr" 2>/dev/null \
          | awk -F: '/^uid:/ { print $10; exit }')
        options+=("$fpr  $uid")
      done <<< "$fingerprints"

      echo "Multiple keys match '$identifier':" >&2
      local choice
      choice=$(printf '%s\n' "${options[@]}" | gum choose)
      if [ -z "$choice" ]; then
        echo "Cancelled." >&2
        return 1
      fi
      # Extract fingerprint (first field)
      echo "$choice" | awk '{ print $1 }'
      return 0
    fi

    # Non-interactive, no --first: error
    echo "Error: multiple keys match '$identifier' — use a fingerprint or --first:" >&2
    while IFS= read -r fpr; do
      local uid
      uid=$(gpg --batch --with-colons --list-keys "$fpr" 2>/dev/null \
        | awk -F: '/^uid:/ { print $10; exit }')
      echo "  $fpr  $uid" >&2
    done <<< "$fingerprints"
    return 1
  fi

  echo "$fingerprints"
}

# ---------------------------------------------------------------------------
# Key query functions
#
# These parse GPG colon output and set shell variables/arrays for callers.
# Each function takes a fingerprint and populates well-known variable names.
# ---------------------------------------------------------------------------

# Query primary key metadata.
# Sets: KEY_ALGO, KEY_BITS, KEY_ALGO_NUM, KEY_CREATED_TS, KEY_EXPIRES_TS,
#       KEY_CREATED, KEY_EXPIRES
query_key_meta() {
  local fpr="$1"
  KEY_ALGO_NUM=""
  KEY_BITS=""
  KEY_CREATED_TS=""
  KEY_EXPIRES_TS=""
  KEY_ALGO=""
  KEY_CREATED=""
  KEY_EXPIRES=""

  local line type
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    type=$(echo "$line" | awk -F: '{ print $1 }')
    if [ "$type" = "pub" ]; then
      KEY_BITS=$(echo "$line" | awk -F: '{ print $3 }')
      KEY_ALGO_NUM=$(echo "$line" | awk -F: '{ print $4 }')
      KEY_CREATED_TS=$(echo "$line" | awk -F: '{ print $6 }')
      KEY_EXPIRES_TS=$(echo "$line" | awk -F: '{ print $7 }')
      break
    fi
  done < <(gpg --batch --with-colons --list-keys "$fpr" 2>/dev/null)

  KEY_ALGO=$(format_algorithm "$KEY_ALGO_NUM" "$KEY_BITS")
  KEY_CREATED=$(format_created "$KEY_CREATED_TS")
  KEY_EXPIRES=$(format_expiry "$KEY_EXPIRES_TS")
}

# Query all UIDs for a key.
# Sets: KEY_UIDS (array of raw UID strings)
query_key_uids() {
  local fpr="$1"
  KEY_UIDS=()

  local line type
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    type=$(echo "$line" | awk -F: '{ print $1 }')
    if [ "$type" = "uid" ]; then
      KEY_UIDS+=("$(echo "$line" | awk -F: '{ print $10 }')")
    fi
  done < <(gpg --batch --with-colons --list-keys "$fpr" 2>/dev/null)
}

# Query subkeys for a key.
# Sets: KEY_SUBKEYS (array of tab-delimited: id\talgorithm\tusage\tcreated\texpires)
query_key_subkeys() {
  local fpr="$1"
  KEY_SUBKEYS=()

  local line type in_sub=false
  local sub_bits="" sub_algo_num="" sub_created_ts="" sub_expires_ts="" sub_caps=""

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    type=$(echo "$line" | awk -F: '{ print $1 }')
    case "$type" in
      sub)
        sub_bits=$(echo "$line" | awk -F: '{ print $3 }')
        sub_algo_num=$(echo "$line" | awk -F: '{ print $4 }')
        sub_created_ts=$(echo "$line" | awk -F: '{ print $6 }')
        sub_expires_ts=$(echo "$line" | awk -F: '{ print $7 }')
        sub_caps=$(echo "$line" | awk -F: '{ print $12 }')
        in_sub=true
        ;;
      fpr)
        if $in_sub; then
          local sub_fpr sub_short sub_algo sub_usage sub_created sub_expires
          sub_fpr=$(echo "$line" | awk -F: '{ print $10 }')
          sub_short="${sub_fpr: -16}"
          sub_algo=$(format_algorithm "$sub_algo_num" "$sub_bits")
          sub_usage=$(format_capabilities "$sub_caps")
          sub_created=$(format_created "$sub_created_ts")
          sub_expires=$(format_expiry "$sub_expires_ts")
          KEY_SUBKEYS+=("$sub_short"$'\t'"$sub_algo"$'\t'"$sub_usage"$'\t'"$sub_created"$'\t'"$sub_expires")
          in_sub=false
        fi
        ;;
    esac
  done < <(gpg --batch --with-colons --list-keys "$fpr" 2>/dev/null)
}

# Query certifications for a key (excludes self-signatures).
# Sets: KEY_CERTS (array of tab-delimited: signer_uid\tdate)
query_key_certifications() {
  local fpr="$1"
  KEY_CERTS=()

  local line type
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    type=$(echo "$line" | awk -F: '{ print $1 }')
    if [ "$type" = "sig" ]; then
      local sig_keyid sig_ts sig_uid sig_date
      sig_keyid=$(echo "$line" | awk -F: '{ print $5 }')
      sig_ts=$(echo "$line" | awk -F: '{ print $6 }')
      sig_uid=$(echo "$line" | awk -F: '{ print $10 }')

      # Skip self-signatures
      if [ "${fpr: -16}" = "$sig_keyid" ]; then
        continue
      fi
      [ -z "$sig_uid" ] && sig_uid="[unknown key $sig_keyid]"

      sig_date=$(format_created "$sig_ts")
      KEY_CERTS+=("$sig_uid"$'\t'"$sig_date")
    fi
  done < <(gpg --batch --with-colons --check-sigs "$fpr" 2>/dev/null)
}

# Check if a fingerprint has a secret (private) key.
# Returns 0 (true) or 1 (false).
has_secret_key() {
  local fpr="$1"
  local count
  count=$(gpg --batch --with-colons --list-secret-keys "$fpr" 2>/dev/null \
    | grep -c '^sec:' || true)
  [ "$count" -gt 0 ]
}
