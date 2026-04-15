<div align="center">

<pre>
  ┌──────────────────────────────────────┐
  │  keys inspect baby-joel@ricon.family │
  │                                      │
  │  ✓ Certified by: Zeke               │
  │  ✓ Certified by: Or Ricon            │
  └──────────────────────────────────────┘
</pre>

# testicles

**GPG key management for humans and agents.**

List, inspect, sign, verify, encrypt, decrypt — all through mise tasks.
Built around a query API that makes GPG's colon output usable.

![lang: bash](https://img.shields.io/badge/lang-bash-4EAA25?style=flat&logo=gnubash&logoColor=white)
[![tests: 77 passing](https://img.shields.io/badge/tests-77%20passing-brightgreen?style=flat)](test/)
![commands: 9 implemented](https://img.shields.io/badge/commands-9%20implemented-blue?style=flat)
![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=flat)

</div>

<br />

## Quick start

```bash
# Install (--as keys gives you a sane CLI name)
shiv install testicles --as keys

# See what's on the keyring
keys list

# Inspect a key — algorithm, UIDs, subkeys, certifications
keys inspect baby-joel@ricon.family

# Sign a file, verify it
keys sign --file release.tar.gz --detach
keys verify --file release.tar.gz --sig release.tar.gz.asc

# Encrypt to a recipient, decrypt locally
keys encrypt --to zeke@ricon.family "deploy token: abc123"
keys decrypt --file message.asc
```

## The trust chain

GPG keys are only useful if you can verify who owns them. We use **key certifications** — one key signs another to say "I've verified this person." The chain flows from Or (root) through agents:

```
           ┌───────────┐
           │  Or Ricon  │   root of trust
           └─────┬─────┘
           ┌─────┴─────┐
           │   Zeke    │   certifies ↓
           └─────┬─────┘
           ┌─────┴─────┐
           │ Baby Joel │   certified ✓
           └───────────┘
```

`keys inspect` shows certifications alongside key details — who vouches for this key, and when. `keys list --secret` shows which keys you can sign with. The rest of the commands are the operations that trust enables: signing, verifying, encrypting, decrypting.

## What it wraps

Every command calls `gpg` under the hood. The value isn't abstraction — it's **usability**. GPG's native output is colon-delimited machine records. `keys` parses those into structured data (`--json`) or formatted tables (default), handles key resolution by email/fingerprint/ID, and provides early error detection (e.g., refusing to sign with a key you don't own the secret for).

The query API in `lib/common.sh` (14 functions) does the heavy lifting: `query_key_meta`, `query_key_uids`, `query_key_subkeys`, `query_key_certifications`. Tasks are thin scripts that resolve args, call the query API, and format output.

## Commands

`keys decrypt` — Decrypt with local key

`keys encrypt` — Encrypt to recipient(s)

`keys export` — Export a public key (armored)

`keys import` — Import an armored public key

`keys inspect` — Show key details and certifications

`keys list` — List known keys in the local keyring

`keys remove` — Remove a key from the local keyring

`keys sign` — Sign content (file or message)

`keys verify` — Verify a content signature

_Planned: broadcast, certify, fetch — stubs exist, implementation coming._

## Library architecture

```
keys/
├── lib/
│   └── common.sh          # Query API + formatting (14 functions)
├── .mise/tasks/
│   ├── list               # Keyring listing with filters
│   ├── inspect            # Full key details + certifications
│   ├── export / import    # Key exchange (armored ASCII)
│   ├── sign / verify      # Content signing + verification
│   ├── encrypt / decrypt  # Recipient-based encryption
│   └── remove             # Key removal with confirmation
└── test/
    ├── test_helper.bash   # Isolated GPG homedir per test
    └── *.bats             # 9 suites, 77 tests
```

Tests run against ephemeral GPG homedirs — each test gets a clean keyring with freshly generated keys. No interaction with the system keyring.

## Development

```bash
git clone https://github.com/KnickKnackLabs/testicles.git
cd testicles && mise trust && mise install
mise run test
```

**77 tests** across 9 suites — [BATS](https://github.com/bats-core/bats-core) with isolated GPG homedirs per test case.

<br />

<div align="center">

---

<sub>
Trust is a graph, not a list.<br />
<br />
This README was generated from <a href="https://github.com/KnickKnackLabs/readme">README.tsx</a>.
</sub></div>
