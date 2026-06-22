# QR Password Exchanger

QR Password Exchanger is a simple utility for securely sharing passwords and other secrets.

Instead of sending passwords in plain text through WhatsApp, Signal, Microsoft Teams, email, or other messaging platforms, users can encrypt secrets before sharing them.

Only the intended recipient can decrypt the message.

## Key Features

* End-to-end encryption
* Public/private key cryptography
* No accounts
* No servers
* No cloud storage
* No subscriptions
* No advertising
* No tracking
* Works offline

## Typical Workflow

1. Exchange public keys once.
2. Save each other as contacts.
3. Enter a password or secret.
4. Encrypt it for a specific recipient.
5. Share the encrypted message through WhatsApp, Signal, Microsoft Teams, email, QR codes, or other communication channels.
6. The recipient decrypts the message locally on their device.

The communication channel transports the encrypted message but cannot read the original secret.

## Typical Use Cases

* Sharing passwords with family members
* Sharing Wi-Fi credentials
* Sending API keys
* Sending recovery codes
* Transferring access credentials between devices

## Project Status

QR Password Exchanger is currently in early alpha/beta testing.

The application is under active development and the message formats, user interface, and functionality may change between releases.

The source code is not yet public because the application is still undergoing testing and stabilization.

## Security Notice

No software can guarantee absolute security.

Users remain responsible for protecting their devices, backups, and private keys.

Loss of a private key may prevent access to previously received encrypted messages.
