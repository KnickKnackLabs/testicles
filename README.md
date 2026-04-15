# keys

GPG key management — trust, encrypt, verify.

## Commands

| Command | Description |
|---------|-------------|
| `keys list` | List known keys in the local keyring |
| `keys export` | Export a public key (armored) |
| `keys import` | Import an armored public key |
| `keys sign` | Sign content (file or message) |
| `keys verify` | Verify a content signature |
| `keys encrypt` | Encrypt to recipient(s) |
| `keys decrypt` | Decrypt with local key |
| `keys certify` | Certify someone's key |
| `keys inspect` | Show key details and certifications |
| `keys broadcast` | Push key to keyserver |
| `keys fetch` | Pull key from keyserver |

## Setup

```bash
shiv install keys
```

## Development

```bash
mise trust && mise install
mise run test
```
