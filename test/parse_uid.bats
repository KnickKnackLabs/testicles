#!/usr/bin/env bats

setup() {
  load test_helper
  source "$MISE_CONFIG_ROOT/lib/common.sh"
}

@test "parse_uid: standard Name <email> format" {
  parse_uid "Alice <alice@example.com>"
  [ "$PARSED_NAME" = "Alice" ]
  [ "$PARSED_EMAIL" = "alice@example.com" ]
}

@test "parse_uid: name with spaces" {
  parse_uid "Alice Smith <alice@example.com>"
  [ "$PARSED_NAME" = "Alice Smith" ]
  [ "$PARSED_EMAIL" = "alice@example.com" ]
}

@test "parse_uid: name with comment" {
  parse_uid "Alice (work) <alice@corp.com>"
  [ "$PARSED_NAME" = "Alice (work)" ]
  [ "$PARSED_EMAIL" = "alice@corp.com" ]
}

@test "parse_uid: bare email without angle brackets" {
  parse_uid "alice@example.com"
  [ "$PARSED_NAME" = "" ]
  [ "$PARSED_EMAIL" = "alice@example.com" ]
}

@test "parse_uid: name only, no email" {
  parse_uid "Alice"
  [ "$PARSED_NAME" = "Alice" ]
  [ "$PARSED_EMAIL" = "" ]
}

@test "parse_uid: empty string" {
  parse_uid ""
  [ "$PARSED_NAME" = "" ]
  [ "$PARSED_EMAIL" = "" ]
}

@test "parse_uid: keybase-style URI with email" {
  parse_uid "keybase.io/jasnell <jasnell@keybase.io>"
  [ "$PARSED_NAME" = "keybase.io/jasnell" ]
  [ "$PARSED_EMAIL" = "jasnell@keybase.io" ]
}

@test "parse_uid: security notation in name" {
  parse_uid "Shelley Vohr (security is major key) <shelley.vohr@gmail.com>"
  [ "$PARSED_NAME" = "Shelley Vohr (security is major key)" ]
  [ "$PARSED_EMAIL" = "shelley.vohr@gmail.com" ]
}
