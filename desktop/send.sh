#!/usr/bin/env bash
# Encrypt a secret for a saved contact or supplied QPE public key.

set -euo pipefail
umask 077

die() {
    echo "Error: $*" >&2
    exit 1
}

usage() {
    cat >&2 <<EOF
Usage: $0 [--qr PNG_FILE] [CONTACT_OR_PUBLIC_KEY]

CONTACT_OR_PUBLIC_KEY may be a saved contact name, a QPE public-key file, or
literal QPE.1.PUB text. With no argument, an interactive contact list is shown.
The encrypted QPE text is printed to stdout.
EOF
}

qpe_home="${QPE_HOME:-$HOME/.qr-password-exchanger}"
contacts_dir="$qpe_home/contacts"
qr_path=""
recipient=""

while (( $# > 0 )); do
    case "$1" in
        --qr)
            (( $# >= 2 )) || die "--qr requires an output file"
            qr_path="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            (( $# <= 1 )) || die "Expected at most one recipient"
            recipient="${1:-}"
            shift $(( $# ))
            ;;
        -*) die "Unknown option: $1" ;;
        *)
            [[ -z "$recipient" ]] || die "Expected at most one recipient"
            recipient="$1"
            shift
            ;;
    esac
done

for command in openssl jq base64; do
    command -v "$command" >/dev/null 2>&1 || die "Required command not found: $command"
done

if [[ -z "$recipient" ]]; then
    [[ -d "$contacts_dir" ]] || die "No contacts yet; import a public key with desktop/receive.sh"
    shopt -s nullglob
    contact_files=("$contacts_dir"/*.pub)
    (( ${#contact_files[@]} > 0 )) || die "No contacts yet; import a public key with desktop/receive.sh"
    echo "Contacts:" >&2
    for i in "${!contact_files[@]}"; do
        contact_file=${contact_files[$i]}
        contact_label=$(basename "$contact_file" .pub)
        printf '  %d) %s\n' "$(( i + 1 ))" "$contact_label" >&2
    done
    printf 'Choose a contact: ' >&2
    IFS= read -r selection </dev/tty || die "Could not read contact selection"
    [[ "$selection" =~ ^[0-9]+$ ]] || die "Contact selection must be a number"
    (( selection >= 1 && selection <= ${#contact_files[@]} )) || die "Contact selection is out of range"
    public_key_path="${contact_files[$(( selection - 1 ))]}"
elif [[ -f "$recipient" ]]; then
    public_key_path="$recipient"
elif [[ -f "$contacts_dir/$recipient.pub" ]]; then
    public_key_path="$contacts_dir/$recipient.pub"
else
    public_key_path=""
    qpe_pub="$recipient"
fi

if [[ -n "${public_key_path:-}" ]]; then
    [[ -r "$public_key_path" ]] || die "Public key file is not readable: $public_key_path"
    qpe_pub=$(tr -d '\r\n' < "$public_key_path")
fi
[[ "$qpe_pub" == QPE.1.PUB.* ]] || die "Input does not contain a QPE.1.PUB public key"

payload_b64url="${qpe_pub#QPE.1.PUB.}"
[[ "$payload_b64url" =~ ^[A-Za-z0-9_-]+$ ]] || die "Public key contains invalid Base64url data"
case $(( ${#payload_b64url} % 4 )) in
    0) payload_b64="$payload_b64url" ;;
    2) payload_b64="${payload_b64url}==" ;;
    3) payload_b64="${payload_b64url}=" ;;
    *) die "Public key contains invalid Base64url data" ;;
esac
payload_b64=$(printf '%s' "$payload_b64" | tr '_-' '/+')
json=$(printf '%s' "$payload_b64" | base64 -d 2>/dev/null) || die "Public key contains invalid Base64url data"
algorithm=$(printf '%s' "$json" | jq -er '.a | select(type == "string")' 2>/dev/null) || die "Public key contains invalid JSON"
[[ "$algorithm" == "rsa2048" ]] || die "Unsupported public key algorithm: $algorithm"
pubkey_b64=$(printf '%s' "$json" | jq -er '.k | select(type == "string" and length > 0)' 2>/dev/null) || die "Public key data is missing"
canonical_pubkey_b64=$(printf '%s' "$pubkey_b64" | base64 -d 2>/dev/null | base64 -w 0) || \
    die "Public key data is not valid Base64"
[[ "$canonical_pubkey_b64" == "$pubkey_b64" ]] || die "Public key data is not canonical Base64"

printf 'Enter secret: ' >&2
IFS= read -r -s message </dev/tty || die "Could not read secret"
printf '\n' >&2

[[ -n "$message" ]] || die "Secret must not be empty"
message_bytes=$(LC_ALL=C printf '%s' "$message" | wc -c)
(( message_bytes <= 245 )) || die "Secret is too long: $message_bytes bytes (maximum 245)"

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

ct_b64=$(printf '%s' "$message" | openssl pkeyutl -encrypt \
    -pubin -inkey "$temp_pem" \
    -pkeyopt rsa_padding_mode:pkcs1 | base64 -w 0)
unset message

msg_json=$(jq -cn --arg ct "$ct_b64" '{"a":"rsa2048-pkcs1","ct":$ct}')
msg_b64url=$(printf '%s' "$msg_json" | base64 -w 0 | tr '/+' '_-' | tr -d '=')
encrypted_message="QPE.1.MSG.${msg_b64url}"

printf '%s\n' "$encrypted_message"

if [[ -n "$qr_path" ]]; then
    command -v qrencode >/dev/null 2>&1 || die "qrencode is required to write a QR image"
    [[ ! -e "$qr_path" ]] || die "QR output file already exists: $qr_path"
    qrencode -o "$qr_path" "$encrypted_message"
    echo "Encrypted QR code written to $qr_path" >&2
elif [[ -t 1 ]]; then
    if command -v qrencode >/dev/null 2>&1; then
        echo "Scan this encrypted message:" >&2
        qrencode -t ANSIUTF8 "$encrypted_message" >&2
    else
        echo "Tip: install qrencode to display the encrypted message as an inline QR code." >&2
    fi
fi
