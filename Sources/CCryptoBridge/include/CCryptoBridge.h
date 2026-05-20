#ifndef CCryptoBridge_h
#define CCryptoBridge_h

#include <CommonCrypto/CommonCryptor.h>
#include <CommonCrypto/CommonKeyDerivation.h>

int cc_aes128cbc_decrypt(
    const void *key, const void *iv,
    const void *ct, size_t ctLen,
    void *pt, size_t *ptLen);

int cc_pbkdf2_sha1(
    const char *pw, size_t pwLen,
    const uint8_t *salt, size_t saltLen,
    int rounds,
    uint8_t *dk, size_t dkLen);

#endif /* CCryptoBridge_h */
