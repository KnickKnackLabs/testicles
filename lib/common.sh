#!/usr/bin/env bash
# Shared helpers for keys tasks

# Default keyserver (configurable via KEYS_KEYSERVER env var)
KEYS_KEYSERVER="${KEYS_KEYSERVER:-keys.openpgp.org}"

# Require gpg on PATH
require_gpg() {
  if ! command -v gpg &>/dev/null; then
    echo "Error: gpg not found on PATH" >&2
    exit 1
  fi
}

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
    # "Name <email>" format
    PARSED_NAME=$(echo "$uid" | sed 's/ *<.*>$//')
    PARSED_EMAIL=$(echo "$uid" | sed 's/.*<\(.*\)>/\1/')
  elif [[ "$uid" == *'@'* ]]; then
    # Bare email, no angle brackets
    PARSED_EMAIL="$uid"
  else
    # Just a name, no email
    PARSED_NAME="$uid"
  fi
}

# Resolve a key identifier (email, fingerprint, or partial ID) to a fingerprint.
# Returns the full fingerprint on stdout, exits 1 if not found or ambiguous.
resolve_key() {
  local identifier="$1"
  local fingerprints

  # Only grab the primary key fingerprint (first fpr after each pub line)
  fingerprints=$(gpg --batch --with-colons --list-keys "$identifier" 2>/dev/null \
    | awk -F: '/^pub:/ { getfpr=1; next } /^fpr:/ && getfpr { print $10; getfpr=0 }')

  if [ -z "$fingerprints" ]; then
    echo "Error: no key found for '$identifier'" >&2
    return 1
  fi

  local count
  count=$(echo "$fingerprints" | wc -l | tr -d ' ')

  if [ "$count" -gt 1 ]; then
    echo "Error: multiple keys match '$identifier' — use a fingerprint to be specific" >&2
    return 1
  fi

  echo "$fingerprints"
}
