# Desktop Quickstart

The desktop tools follow the same workflow as the app: **My Key**, **Receive**,
and **Send**. They use the compatible `QPE.1.PUB.…` and `QPE.1.MSG.…` text
formats, so public keys and encrypted messages can be copied directly between
the terminal and the app.

Run the commands below from the repository root.

## Requirements

The scripts require Bash, OpenSSL, `jq`, and GNU `base64`.

Install the optional QR tools to display QR codes and read QR images:

```bash
# Debian/Ubuntu
sudo apt install openssl jq coreutils qrencode zbar-tools
```

- `qrencode` displays inline QR codes and writes PNG files.
- `zbarimg` (from `zbar-tools`) reads QR codes from image files.

## 1. My Key

Create your desktop identity if it does not exist, then print its public key:

```bash
bash desktop/my-key.sh
```

When `qrencode` is installed, the command also displays an inline QR code that
can be scanned by the app. To save only the copyable public-key text:

```bash
bash desktop/my-key.sh > my-public-key.txt
```

The keypair is reused on future runs. It is stored under:

```text
~/.qr-password-exchanger/
├── private.pem    # Keep private; required to decrypt your messages
├── public.pub     # Safe to share
└── contacts/      # Public keys received from other people
```

## 2. Receive

`receive.sh` automatically detects encrypted messages and public keys. It can
read literal text, a text file, a QR image, or standard input:

```bash
bash desktop/receive.sh 'QPE.1.MSG.…'
bash desktop/receive.sh received.txt
bash desktop/receive.sh received.png
cat received.txt | bash desktop/receive.sh
```

For an encrypted message, the decrypted secret is printed to the terminal.

For a public key, the script asks you to choose a local contact name and saves
it under `~/.qr-password-exchanger/contacts/`:

```bash
bash desktop/receive.sh 'QPE.1.PUB.…'
```

You can provide the name directly when importing a file or QR image:

```bash
bash desktop/receive.sh --name Alice alice-public-key.png
```

## 3. Send

Choose from your saved contacts, then enter the secret using the hidden prompt:

```bash
bash desktop/send.sh
```

Or select a contact directly:

```bash
bash desktop/send.sh Alice
```

The copyable `QPE.1.MSG.…` encrypted message is printed to the terminal. When
`qrencode` is installed, an inline QR code is displayed too.

Save the encrypted text or create a PNG QR code:

```bash
bash desktop/send.sh Alice > message.txt
bash desktop/send.sh --qr message.png Alice
```

You can also send without saving a contact first:

```bash
bash desktop/send.sh recipient-public-key.txt
bash desktop/send.sh 'QPE.1.PUB.…'
```

## Example exchange

```bash
# 1. Alice displays her public key; Bob scans it with the app.
bash desktop/my-key.sh

# 2. Alice imports Bob's public-key QR as a contact.
bash desktop/receive.sh --name Bob bob-public-key.png

# 3. Alice encrypts a secret for Bob and creates a QR image.
bash desktop/send.sh --qr message-for-bob.png Bob

# 4. Alice sends message-for-bob.png to Bob. Only Bob's private key can
#    decrypt it.
```

## Security notes

- Never share or delete `private.pem` while you still need to decrypt messages
  sent to the current public key.
- Desktop keys are regular files, unlike hardware-backed Android Keystore
  keys. Protect your home directory with appropriate permissions and disk
  encryption.
- RSA-2048 with PKCS#1 padding limits secrets to 245 UTF-8 bytes.
- Messages are encrypted but not signed; the format does not authenticate the
  sender.

For format details and advanced examples, see
[`../docs/protocol/cli-interop.md`](../docs/protocol/cli-interop.md) and
[`../docs/protocol/qpe-v1.md`](../docs/protocol/qpe-v1.md).
