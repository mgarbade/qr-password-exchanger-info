# QPE v1 Wire Format

## Status

QPE v1 is the format currently implemented by QR Password Exchanger and its
desktop tools. This document defines the interoperable public-key and encrypted
message envelopes. Keywords such as **MUST**, **SHOULD**, and **MAY** are to be
interpreted as described in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

QPE v1 defines a versioned envelope and the two algorithm identifiers listed
below. Other identifiers are not part of this specification.

## Envelope

Every QPE v1 value is ASCII text with four dot-separated segments:

```text
QPE.<version>.<type>.<payload>
```

| Segment | QPE v1 value | Meaning |
|---|---|---|
| Identifier | `QPE` | QR Password Exchanger content |
| Version | `1` | Envelope version |
| Type | `PUB` or `MSG` | Public key or encrypted message |
| Payload | Base64url text | UTF-8 JSON encoded with RFC 4648 §5 Base64url |

The payload MUST use Base64url without `=` padding. The decoded payload MUST be
a JSON object. Standard Base64 as defined by RFC 4648 §4, including required
canonical `=` padding, is used inside the JSON fields.

Implementations MUST reject unsupported versions, types, algorithms, malformed
Base64/Base64url, malformed JSON, and invalid key or ciphertext data. They MAY
ignore unrecognized JSON fields for forward compatibility, but MUST enforce
the required fields and exact algorithm/type combinations defined here.
Producers MUST NOT emit duplicate JSON member names; consumers SHOULD reject
them to avoid parser-dependent interpretations.

Implementations SHOULD reject an envelope larger than 10 KiB before decoding
it. Valid QPE v1 values produced by this specification are substantially
smaller.

## Public Key (`PUB`)

```text
QPE.1.PUB.<base64url-json>
```

The decoded JSON object has this form:

```json
{
  "a": "rsa2048",
  "k": "MIIBIjANBg..."
}
```

| Field | Type | Required | Meaning |
|---|---|---|---|
| `a` | string | yes | Exactly `rsa2048` |
| `k` | string | yes | Standard-Base64-encoded DER SubjectPublicKeyInfo |

The decoded `k` value MUST be a valid RSA public key in X.509
SubjectPublicKeyInfo (SPKI) form with a 2048-bit modulus. Implementations MUST
validate the key before storing or using it.

The payload intentionally contains no contact name or assertion about the key
owner. A recipient chooses a local contact name. Users who need assurance about
key ownership must verify the key through a trusted channel, such as scanning
it directly from the intended recipient's device.

## Encrypted Message (`MSG`)

```text
QPE.1.MSG.<base64url-json>
```

The decoded JSON object has this form:

```json
{
  "a": "rsa2048-pkcs1",
  "ct": "ciphertext-base64..."
}
```

| Field | Type | Required | Meaning |
|---|---|---|---|
| `a` | string | yes | Exactly `rsa2048-pkcs1` |
| `ct` | string | yes | Standard-Base64-encoded RSA ciphertext |

The plaintext MUST be valid UTF-8 and contain between 1 and 245 bytes. It is
encrypted with the recipient's RSA-2048 public key using RSAES-PKCS1-v1_5
padding. The decoded ciphertext MUST be exactly 256 bytes. After decryption,
receivers SHOULD reject an empty plaintext or bytes that are not valid UTF-8.

Implementations MUST use a cryptographically secure random source through an
established cryptographic library. Encrypting the same plaintext more than
once should therefore produce different ciphertexts.

## Registered QPE v1 combinations

| Type | Algorithm | Purpose |
|---|---|---|
| `PUB` | `rsa2048` | RSA-2048 SPKI public key |
| `MSG` | `rsa2048-pkcs1` | RSAES-PKCS1-v1_5 encrypted message |

The version identifies the envelope structure, while `a` identifies the key or
cryptographic construction. A future specification may register additional
algorithms or define a new envelope version. Implementations MUST NOT infer the
meaning of an unrecognized identifier.

## Encoding example

For illustration, this payload uses a shortened ciphertext that is not a valid
256-byte QPE v1 ciphertext:

```json
{"a":"rsa2048-pkcs1","ct":"AA=="}
```

an implementation:

1. serializes the object as UTF-8 JSON;
2. encodes those bytes using unpadded Base64url;
3. prefixes the result with `QPE.1.MSG.`.

JSON whitespace and object-member order are not significant. Producers SHOULD
emit compact JSON to keep QR codes small.

## Security properties and limitations

QPE v1 provides confidentiality to the holder of the private key corresponding
to the selected public key, subject to the security of the endpoint devices and
RSA implementation. It does **not**:

- authenticate who owns a public key;
- authenticate the sender or sign messages;
- provide a modern authenticated-encryption construction;
- support messages larger than 245 UTF-8 bytes.

RSA PKCS#1 v1.5 encryption is retained for QPE v1 interoperability but is a
legacy construction. New protocol work should use a reviewed authenticated
hybrid-encryption design rather than extending this construction. See the
[security model](../security-model.md) for the application-level boundaries.

## Legacy formats

Pre-1.0 alpha releases used `PEER:<name>|KEY:<base64PublicKey>` public keys and
raw Base64 ciphertexts. Those formats are not QPE v1 and are not supported.
