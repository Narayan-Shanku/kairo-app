"""Encrypted sync (Technical Architecture §9.3).

Client-side, zero-knowledge sync: the local store is exported, encrypted with a
key derived from the user's passphrase (Argon2id) using AES-256-GCM, and only the
resulting ciphertext blob is uploaded. The sync server never sees the passphrase,
the key, or any plaintext — lose the passphrase and the data is unrecoverable.
"""
