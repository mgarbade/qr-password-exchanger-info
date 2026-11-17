# Changelog

All notable changes to the desktop CLI and documentation in this repository
are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-11-17

First tagged release of the desktop CLI.

### Added

- `qpe` command-line tool for exchanging secrets with the Android and iOS apps
  using the compatible `QPE.1.PUB.…` and `QPE.1.MSG.…` formats:
  - `qpe key` creates the desktop identity when needed and prints the public
    key, with an inline QR code when `qrencode` is installed.
  - `qpe send` encrypts a secret for a saved contact, a public-key file, or
    literal public-key text, and can write the result as a PNG QR code
    (`--qr`).
  - `qpe receive` decrypts messages, or saves public keys as contacts, from
    text, a file, a QR image (requires `zbarimg`), or stdin.
  - `qpe contacts` lists saved contacts.
  - `qpe help COMMAND` shows the options of a command.
- Keys and contacts are stored under `~/.qr-password-exchanger/`, which can be
  overridden with `QPE_HOME`.
- Strict validation of public keys and ciphertexts: RSA-2048 only, canonical
  Base64, and exactly 256-byte ciphertexts.
- `Makefile` with `install` (default `PREFIX=~/.local`, no sudo), `link` (for
  development), `uninstall`, and `check` targets.
- Bash tab completion for commands, options, files, and contact names.
- Documentation: QPE v1 wire format, security model, CLI interoperability
  guide, and desktop quickstart.

### Changed

- Before this release, the desktop tools were the scripts `desktop/my-key.sh`,
  `desktop/send.sh`, and `desktop/receive.sh`. They are now `qpe key`,
  `qpe send`, and `qpe receive`; the old script paths no longer exist. Run
  `desktop/bin/qpe` from a checkout to use the tool without installing it.

[Unreleased]: https://github.com/mgarbade/qr-password-exchanger-info/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/mgarbade/qr-password-exchanger-info/releases/tag/v0.1.0
