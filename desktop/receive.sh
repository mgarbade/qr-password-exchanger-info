#!/usr/bin/env bash
# Receive a QPE message or public key from text, a file, a QR image, or stdin.

set -euo pipefail
umask 077

die() {
    echo "Error: $*" >&2
    exit 1
}

usage() {
    cat >&2 <<EOF
Usage: $0 [--name CONTACT_NAME] [--private-key FILE] [TEXT_OR_FILE]

With no argument, input is read from stdin (or prompted for at a terminal).
QR image files require zbarimg. Public keys are saved as contacts; encrypted
messages are decrypted with ~/.qr-password-exchanger/private.pem by default.
EOF
}

qpe_home="${QPE_HOME:-$HOME/.qr-password-exchanger}"
private_key_path="$qpe_home/private.pem"
contact_name=""
input=""

while (( $# > 0 )); do
    case "$1" in
        --name)
            (( $# >= 2 )) || die "--name requires a contact name"
            contact_name="$2"
            shift 2
            ;;
        --private-key)
            (( $# >= 2 )) || die "--private-key requires a file"
            private_key_path="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            (( $# <= 1 )) || die "Expected at most one input"
            input="${1:-}"
            shift $(( $# ))
            ;;
        -*) die "Unknown option: $1" ;;
        *)
            [[ -z "$input" ]] || die "Expected at most one input"
            input="$1"
            shift
            ;;
    esac
done

for command in openssl jq base64; do
    command -v "$command" >/dev/null 2>&1 || die "Required command not found: $command"
done

if [[ -n "$input" && -e "$input" ]]; then
    [[ -f "$input" && -r "$input" ]] || die "Input file is not readable: $input"
    case "${input,,}" in
        *.png|*.jpg|*.jpeg|*.gif|*.webp|*.bmp)
            command -v zbarimg >/dev/null 2>&1 || die "zbarimg is required to read QR image files"
            qpe_string=$(zbarimg --quiet --raw "$input" 2>/dev/null) || die "No readable QR code found in: $input"
            ;;
        *) qpe_string=$(cat "$input") ;;
    esac
elif [[ -n "$input" ]]; then
    qpe_string="$input"
elif [[ ! -t 0 ]]; then
    qpe_string=$(cat)
else
    printf 'Paste QPE text: ' >&2
    IFS= read -r qpe_string || die "Could not read input"
fi

qpe_string=$(printf '%s' "$qpe_string" | tr -d '\r\n')
[[ "$qpe_string" == QPE.1.PUB.* || "$qpe_string" == QPE.1.MSG.* ]] || \
    die "Input is not a supported QPE.1 public key or encrypted message"

qpe_type="${qpe_string#QPE.1.}"
qpe_type="${qpe_type%%.*}"
payload_b64url="${qpe_string#QPE.1.${qpe_type}.}"
[[ "$payload_b64url" =~ ^[A-Za-z0-9_-]+$ ]] || die "Input contains invalid Base64url data"
case $(( ${#payload_b64url} % 4 )) in
    0) payload_b64="$payload_b64url" ;;
    2) payload_b64="${payload_b64url}==" ;;
    3) payload_b64="${payload_b64url}=" ;;
    *) die "Message contains invalid Base64url data" ;;
esac
payload_b64=$(printf '%s' "$payload_b64" | tr '_-' '/+')
json=$(printf '%s' "$payload_b64" | base64 -d 2>/dev/null) || die "Input contains invalid Base64url data"
algorithm=$(printf '%s' "$json" | jq -er '.a | select(type == "string")' 2>/dev/null) || die "Input contains invalid JSON"

if [[ "$qpe_type" == PUB ]]; then
    [[ "$algorithm" == "rsa2048" ]] || die "Unsupported public key algorithm: $algorithm"
    pubkey_b64=$(printf '%s' "$json" | jq -er '.k | select(type == "string" and length > 0)' 2>/dev/null) || die "Public key data is missing"
    canonical_pubkey_b64=$(printf '%s' "$pubkey_b64" | base64 -d 2>/dev/null | base64 -w 0) || \
        die "Public key data is not valid Base64"
    [[ "$canonical_pubkey_b64" == "$pubkey_b64" ]] || die "Public key data is not canonical Base64"

    temp_pem=$(mktemp "${TMPDIR:-/tmp}/qpe_pub.XXXXXX")
    trap 'rm -f "$temp_pem"' EXIT
    {
        echo "-----BEGIN PUBLIC KEY-----"
        printf '%s' "$pubkey_b64" | fold -w 64
        echo
        echo "-----END PUBLIC KEY-----"
    } > "$temp_pem"
    key_description=$(LC_ALL=C openssl rsa -pubin -in "$temp_pem" -text -noout 2>/dev/null) || \
        die "Public key data is not a valid RSA public key"
    grep -q '^Public-Key: (2048 bit)$' <<<"$key_description" || \
        die "Public key must be a 2048-bit RSA key"

    if [[ -z "$contact_name" ]]; then
        [[ -r /dev/tty ]] || die "Use --name CONTACT_NAME when importing a public key non-interactively"
        printf 'Name this contact: ' >&2
        IFS= read -r contact_name </dev/tty || die "Could not read contact name"
    fi
    [[ -n "$contact_name" ]] || die "Contact name must not be empty"
    [[ "$contact_name" != */* && "$contact_name" != "." && "$contact_name" != ".." ]] || die "Contact name must not contain '/' or equal '.' or '..'"
    [[ "$contact_name" != *$'\n'* && "$contact_name" != *$'\r'* ]] || die "Contact name must be one line"

    contacts_dir="$qpe_home/contacts"
    contact_path="$contacts_dir/$contact_name.pub"
    mkdir -p "$contacts_dir"
    chmod 700 "$qpe_home" "$contacts_dir"
    if [[ -e "$contact_path" ]]; then
        [[ -f "$contact_path" && $(tr -d '\r\n' < "$contact_path") == "$qpe_string" ]] && {
            echo "Contact already saved: $contact_name" >&2
            exit 0
        }
        die "A contact named '$contact_name' already exists"
    fi
    printf '%s\n' "$qpe_string" > "$contact_path"
    chmod 600 "$contact_path"
    echo "Saved contact '$contact_name' to $contact_path" >&2
    exit 0
fi

[[ "$algorithm" == "rsa2048-pkcs1" ]] || die "Unsupported message algorithm: $algorithm"
ct=$(printf '%s' "$json" | jq -er '.ct | select(type == "string" and length > 0)' 2>/dev/null) || die "Message ciphertext is missing"
[[ -f "$private_key_path" && -r "$private_key_path" ]] || die "Private key not found; run desktop/my-key.sh first"
openssl pkey -in "$private_key_path" -noout >/dev/null 2>&1 || die "Private key file is invalid: $private_key_path"

temp_ciphertext=$(mktemp "${TMPDIR:-/tmp}/qpe_ciphertext.XXXXXX")
trap 'rm -f "$temp_ciphertext"' EXIT
printf '%s' "$ct" | base64 -d > "$temp_ciphertext" 2>/dev/null || die "Message contains invalid ciphertext"
[[ $(base64 -w 0 < "$temp_ciphertext") == "$ct" ]] || die "Message ciphertext is not canonical Base64"
ciphertext_bytes=$(wc -c < "$temp_ciphertext")
(( ciphertext_bytes == 256 )) || die "Message ciphertext must be exactly 256 bytes"

openssl pkeyutl -decrypt -inkey "$private_key_path" \
    -in "$temp_ciphertext" \
    -pkeyopt rsa_padding_mode:pkcs1 2>/dev/null || \
    die "Decryption failed; the message may have been encrypted for a different key"
printf '\n'
