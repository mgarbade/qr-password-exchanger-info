# Desktop Quickstart

The `qpe` command follows the same workflow as the app: **My Key**
(`qpe key`), **Receive** (`qpe receive`), and **Send** (`qpe send`). They use the compatible `QPE.1.PUB.…` and `QPE.1.MSG.…` text
formats, so public keys and encrypted messages can be copied directly between
the terminal and the app.

## Requirements

`qpe` requires Bash, OpenSSL, `jq`, and GNU `base64`.

Install the optional QR tools to display QR codes and read QR images:

```bash
# Debian/Ubuntu
sudo apt install openssl jq coreutils qrencode zbar-tools
```

- `qrencode` displays inline QR codes and writes PNG files.
- `zbarimg` (from `zbar-tools`) reads QR codes from image files.

## Install

From the repository root:

```bash
make install                         # per user: ~/.local/bin/qpe (no sudo)
sudo make install PREFIX=/usr/local  # or system-wide
```

Make sure `~/.local/bin` is on your `PATH`. Bash tab completion for commands
and contact names is installed too and is picked up by new shells when the
`bash-completion` package is present.

For development, `make link` symlinks `qpe` to this checkout instead of copying
it, and `make uninstall` removes either kind of install. Without installing,
you can also run `desktop/bin/qpe` directly.

```text
qpe key        Create your identity if needed and print your public key
qpe send       Encrypt a secret for a contact or public key
qpe receive    Decrypt a message, or save a public key as a contact
qpe contacts   List saved contacts
qpe help CMD   Show options for a command
```

## 1. My Key

Create your desktop identity if it does not exist, then print its public key:

```bash
qpe key
```

When `qrencode` is installed, the command also displays an inline QR code that
can be scanned by the app. To save only the copyable public-key text:

```bash
qpe key > my-public-key.txt
```

The keypair is reused on future runs. It is stored under:

```text
~/.qr-password-exchanger/
├── private.pem    # Keep private; required to decrypt your messages
├── public.pub     # Safe to share
└── contacts/      # Public keys received from other people
```

## 2. Receive

`qpe receive` automatically detects encrypted messages and public keys. It can
read literal text, a text file, a QR image, or standard input:

```bash
qpe receive 'QPE.1.MSG.…'
qpe receive received.txt
qpe receive received.png
cat received.txt | qpe receive
```

For an encrypted message, the decrypted secret is printed to the terminal.

For a public key, the script asks you to choose a local contact name and saves
it under `~/.qr-password-exchanger/contacts/`:

```bash
qpe receive 'QPE.1.PUB.…'
```

You can provide the name directly when importing a file or QR image:

```bash
qpe receive --name Alice alice-public-key.png
```

## 3. Send

Choose from your saved contacts, then enter the secret using the hidden prompt:

```bash
qpe send
```

Or select a contact directly:

```bash
qpe send Alice
```

The copyable `QPE.1.MSG.…` encrypted message is printed to the terminal. When
`qrencode` is installed, an inline QR code is displayed too.

Save the encrypted text or create a PNG QR code:

```bash
qpe send Alice > message.txt
qpe send --qr message.png Alice
```

You can also send without saving a contact first:

```bash
qpe send recipient-public-key.txt
qpe send 'QPE.1.PUB.…'
```

## Example exchange

```bash
# 1. Alice displays her public key; Bob scans it with the app.
qpe key

# 2. Alice imports Bob's public-key QR as a contact.
qpe receive --name Bob bob-public-key.png

# 3. Alice encrypts a secret for Bob and creates a QR image.
qpe send --qr message-for-bob.png Bob

# 4. Alice sends message-for-bob.png to Bob. Only Bob's private key can
#    decrypt it.
```

## Security notes

- Never share or delete `private.pem` while you still need to decrypt messages
  sent to the current public key.
- Desktop keys are regular files rather than keys managed by a mobile
  operating system's protected keystore or keychain. Protect your home
  directory with appropriate permissions and disk encryption.
- RSA-2048 with PKCS#1 padding limits secrets to 245 UTF-8 bytes.
- Messages are encrypted but not signed; the format does not authenticate the
  sender.

For format details and advanced examples, see
[`../docs/protocol/cli-interop.md`](../docs/protocol/cli-interop.md) and
[`../docs/protocol/qpe-v1.md`](../docs/protocol/qpe-v1.md).
