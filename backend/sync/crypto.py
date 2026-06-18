"""Client-side encryption for sync (Technical Architecture §9.3).

  passphrase --Argon2id--> 256-bit key --AES-256-GCM--> ciphertext blob

The blob is self-describing: a version tag + the random salt + the GCM nonce +
ciphertext (which includes the authentication tag). Decryption with the wrong
passphrase fails loudly (GCM tag mismatch) rather than returning garbage.
"""

from __future__ import annotations

import hashlib
import os

from argon2.low_level import Type, hash_secret_raw
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

_MAGIC = b"KAIRO1"
_SALT_LEN = 16
_NONCE_LEN = 12
_KEY_LEN = 32  # AES-256

# Argon2id parameters (memory-hard; tune up over time as devices allow).
_TIME_COST = 3
_MEMORY_COST = 64 * 1024  # 64 MB
_PARALLELISM = 4


def derive_key(passphrase: str, salt: bytes) -> bytes:
    return hash_secret_raw(
        secret=passphrase.encode("utf-8"),
        salt=salt,
        time_cost=_TIME_COST,
        memory_cost=_MEMORY_COST,
        parallelism=_PARALLELISM,
        hash_len=_KEY_LEN,
        type=Type.ID,  # Argon2id
    )


def encrypt(plaintext: bytes, passphrase: str) -> bytes:
    salt = os.urandom(_SALT_LEN)
    nonce = os.urandom(_NONCE_LEN)
    key = derive_key(passphrase, salt)
    ciphertext = AESGCM(key).encrypt(nonce, plaintext, None)
    return _MAGIC + salt + nonce + ciphertext


def decrypt(blob: bytes, passphrase: str) -> bytes:
    """Decrypt a blob; raises on wrong passphrase or tampering."""
    if blob[: len(_MAGIC)] != _MAGIC:
        raise ValueError("Not a Kairō encrypted blob")
    off = len(_MAGIC)
    salt = blob[off : off + _SALT_LEN]
    nonce = blob[off + _SALT_LEN : off + _SALT_LEN + _NONCE_LEN]
    ciphertext = blob[off + _SALT_LEN + _NONCE_LEN :]
    key = derive_key(passphrase, salt)
    return AESGCM(key).decrypt(nonce, ciphertext, None)


def sync_id_for(passphrase: str) -> str:
    """A stable, opaque blob id derived from the passphrase.

    Lets a user sync across devices with only their passphrase. It's a one-way
    hash with a domain-separation prefix — the server can't recover the passphrase
    or read the data. (A production design would separate account from passphrase.)
    """
    digest = hashlib.sha256(("kairo-sync-id:v1:" + passphrase).encode("utf-8")).hexdigest()
    return digest[:32]
