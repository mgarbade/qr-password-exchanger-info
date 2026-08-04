# CLI Interoperability Guide

QR Password Exchanger uses the **QPE v1** wire format (see [`qpe-v1.md`](qpe-v1.md)).
This format is plain text and can be parsed with standard Unix tools. Below
are examples for encrypting and decrypting on a desktop using `openssl`,
`jq`, and `base64`.

## Prerequisites

- Bash
- OpenSSL
- `jq` (JSON processor)
- `base64` (coreutils)
- `qrencode` (optional, for inline and PNG QR codes)
- `zbarimg` from `zbar-tools` (for reading QR image files)

## QPE Envelope

All content follows this structure:

```
QPE.1.PUB.<base64url-encoded-json>   — public key
QPE.1.MSG.<base64url-encoded-json>   — encrypted message
```

The fourth segment is Base64url-encoded JSON (RFC 4648 §5, no padding).

---

## My Key

Create a desktop identity and display its copyable public key and inline QR:

```bash
bash desktop/my-key.sh
```

The command creates a key only when one does not already exist. Files are kept
under `~/.qr-password-exchanger/`:

```
private.pem   — private RSA key; do not share
public.pub    — copyable QPE.1.PUB public key
contacts/     — public keys imported with receive.sh
```

Status is written to stderr. The inline QR is displayed only when stdout is a
terminal, so redirecting stdout writes just the public key:

```bash
bash desktop/my-key.sh > my-public-key.txt
```

## Receive

`receive.sh` accepts literal QPE text, a text file, a QR image, or stdin:

```bash
bash desktop/receive.sh 'QPE.1.MSG.…'
bash desktop/receive.sh received.qpe
bash desktop/receive.sh received.png
cat received.qpe | bash desktop/receive.sh
```

An encrypted message is decrypted using the desktop identity and the secret is
printed to stdout. A public key instead prompts for a local contact name and is
saved under `~/.qr-password-exchanger/contacts/`:

```bash
bash desktop/receive.sh 'QPE.1.PUB.…'
bash desktop/receive.sh --name Alice alice-key.png
```

Use `--private-key FILE` to decrypt with a key outside the default identity.

## Send

Select a saved contact and enter the secret using hidden input:

```bash
bash desktop/send.sh
bash desktop/send.sh Alice
```

The recipient can also be a public-key file or literal `QPE.1.PUB.…` text:

```bash
bash desktop/send.sh recipient.pub
bash desktop/send.sh 'QPE.1.PUB.…'
```

The copyable encrypted `QPE.1.MSG.…` text is printed to stdout. On a terminal,
an inline QR is also displayed when `qrencode` is installed. Use `--qr` to
write a PNG instead:

```bash
bash desktop/send.sh --qr message.png Alice
bash desktop/send.sh Alice > message.qpe
```

> **Note:** Desktop-generated keys are regular local PEM files rather than keys
> managed by a mobile operating system's protected keystore or keychain.
> Protect `private.pem` accordingly.

---

## Python envelope examples

```python
import json, base64

def parse_qpe(qpe_string):
    """Parse a QPE envelope, return (type, payload_dict)."""
    identifier, version, typ, b64url = qpe_string.split(".", 3)
    if identifier != "QPE" or version != "1" or typ not in {"PUB", "MSG"}:
        raise ValueError("unsupported QPE envelope")
    padding = "=" * (4 - len(b64url) % 4) if len(b64url) % 4 else ""
    payload = json.loads(base64.urlsafe_b64decode(b64url + padding))
    return typ, payload

def make_qpe(typ, payload):
    """Build a QPE envelope from type and payload dict."""
    if typ not in {"PUB", "MSG"}:
        raise ValueError("unsupported QPE type")
    b64url = base64.urlsafe_b64encode(
        json.dumps(payload).encode()
    ).decode().rstrip("=")
    return f"QPE.1.{typ}.{b64url}"
```

## Limitations

- **RSA 2048 / PKCS#1 padding** limits plaintext to **245 bytes**. This is
  sufficient for passwords but not for large files.
- The app does not sign messages — there is no sender authentication.
- Desktop keys are regular files rather than keys managed by a mobile
  operating system's protected keystore or keychain. Protect the account and
  storage containing `private.pem`.
- These Python examples only parse and create QPE envelopes; they do not
  perform encryption, decryption, or the full validation required by the
  [wire-format specification](qpe-v1.md).
