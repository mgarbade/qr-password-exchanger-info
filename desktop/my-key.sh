#!/usr/bin/env bash
# Create the desktop identity when needed and display its public key.

set -euo pipefail
umask 077

die() {
    echo "Error: $*" >&2
    exit 1
}

if (( $# > 0 )); then
    if (( $# == 1 )) && [[ "$1" == -h || "$1" == --help ]]; then
        echo "Usage: $0" >&2
        echo "Create the desktop identity when needed and display its public key." >&2
        exit 0
    fi
    die "This command does not accept arguments (use --help for usage)"
fi

for command in openssl jq base64; do
    command -v "$command" >/dev/null 2>&1 || die "Required command not found: $command"
done

qpe_home="${QPE_HOME:-$HOME/.qr-password-exchanger}"
private_key_path="$qpe_home/private.pem"
public_key_path="$qpe_home/public.pub"

mkdir -p "$qpe_home"
chmod 700 "$qpe_home"

if [[ ! -e "$private_key_path" ]]; then
    echo "Creating a new desktop identity in $qpe_home" >&2
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
        -out "$private_key_path"
    chmod 600 "$private_key_path"
else
    [[ -f "$private_key_path" && -r "$private_key_path" ]] || die "Private key is not readable: $private_key_path"
    openssl pkey -in "$private_key_path" -noout >/dev/null 2>&1 || die "Private key is invalid: $private_key_path"
fi

pubkey_b64=$(openssl pkey -in "$private_key_path" -pubout -outform DER | base64 -w 0)
pub_json=$(jq -cn --arg k "$pubkey_b64" '{"a":"rsa2048","k":$k}')
pub_b64url=$(printf '%s' "$pub_json" | base64 -w 0 | tr '/+' '_-' | tr -d '=')
public_key="QPE.1.PUB.${pub_b64url}"

if [[ ! -f "$public_key_path" ]] || [[ $(tr -d '\r\n' < "$public_key_path") != "$public_key" ]]; then
    printf '%s\n' "$public_key" > "$public_key_path"
    chmod 600 "$public_key_path"
    echo "Public key written to $public_key_path" >&2
fi

printf '%s\n' "$public_key"

if [[ -t 1 ]]; then
    if command -v qrencode >/dev/null 2>&1; then
        echo "Scan this public key:" >&2
        qrencode -t ANSIUTF8 "$public_key" >&2
    else
        echo "Tip: install qrencode to display this public key as an inline QR code." >&2
    fi
fi
