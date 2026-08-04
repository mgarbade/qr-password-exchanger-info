# Security Model and Limitations

QR Password Exchanger is designed to exchange short secrets without sending
plaintext to a project-operated server. Encryption and decryption happen on
the user's device, and encrypted QPE messages can be carried by an untrusted
messaging service, email provider, file transfer, or QR code.

This document describes the current design boundaries. It is not a claim of
formal verification or an independent security audit.

## What the design protects

- A message is encrypted for one recipient public key. Decryption requires the
  corresponding private key.
- The project does not require an account, central server, cloud storage,
  analytics, advertising, or tracking.
- Mobile private keys are managed by the operating system's protected key
  storage. The desktop CLI instead stores its private key as a local PEM file.
- The transport receives ciphertext rather than the plaintext entered into the
  app, unless the user separately shares or exposes that plaintext.

## What the design does not prove

### Contact identity

A public key does not contain a verified identity. If an attacker substitutes
their key before it is saved, a user could encrypt a secret for the attacker
while believing the contact belongs to someone else.

Exchange or verify public keys through a trusted channel. Scanning the key
directly from the intended recipient's device is preferable when practical.

### Sender identity

QPE v1 messages are encrypted but not signed. A successfully decrypted message
was encrypted for the recipient's key, but the app cannot prove who created
it. Anyone with the public key can create a message for that recipient.

### Integrity, freshness, and delivery

QPE v1 provides no cryptographic integrity, freshness, ordering, or replay
guarantee. An untrusted transport can replace, drop, delay, or replay an
envelope. Decryption failure can reveal that a message was damaged or was meant
for another key, but successful decryption does not authenticate its sender or
establish when it was created.

### Compromised endpoints

Encryption cannot protect plaintext on a compromised or unlocked endpoint.
Someone with sufficient access to a device may be able to read screen content,
observe keyboard input, inspect the clipboard, or invoke cryptographic
operations while the app and key are available.

Operating-system key storage improves isolation but is not an absolute
hardware-security guarantee on every supported device. Device capabilities and
security state vary.

## Current cryptography

QPE v1 uses RSA-2048 with PKCS#1 v1.5 encryption. The maximum plaintext is 245
UTF-8 bytes. RSA-2048 remains resistant to direct brute-force attacks with
current public capabilities, but PKCS#1 v1.5 encryption is a legacy,
unauthenticated construction and should not be used as the basis for a new
protocol.

Implementations must not expose QPE v1 decryption as an automated remote
service and should present cryptographic decryption failures in an externally
indistinguishable way. A future protocol revision should use a reviewed hybrid
construction with authenticated encryption while preserving an explicit
migration path for existing messages.

See the [QPE v1 wire-format specification](protocol/qpe-v1.md) for exact
encoding and algorithm details.

## Key storage and loss

- Mobile keys are tied to operating-system-managed app storage. They may be
  lost when the app is removed, its data is cleared, the identity is reset, or
  the device is lost or replaced.
- Desktop keys are stored under `~/.qr-password-exchanger/` by default. The
  private PEM file relies on filesystem permissions, account security, and any
  disk encryption configured by the user.
- Losing a private key prevents decryption of messages sent to that identity.
  A newly generated identity requires contacts to obtain and verify the new
  public key.

Never share a private key. Protect device backups and local copies if any are
created outside the app.

## Plaintext exposure

Secrets can still be exposed through normal device features, including:

- screenshots, screen recording, and app-switcher previews;
- clipboard history or another app reading clipboard content;
- third-party keyboards or accessibility services;
- a recipient copying the decrypted value elsewhere;
- notifications, backups, or logs created by another app in the sharing flow.

Use device access controls, keep the operating system updated, and clear
sensitive clipboard content when it is no longer needed.

## Project assurance

The project is early-stage and has not undergone a published independent
security audit. The protocol documentation and desktop implementation are
public to support interoperability and review, but publication is not itself a
security certification.

To report a suspected vulnerability, do not open a public issue. Send the
details privately to **martx.labs@gmail.com** so the issue can be investigated
before disclosure.
