#include <sodium.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char *argv[]) {
    if (sodium_init() < 0) {
        fprintf(stderr, "sodium_init failed\n");
        return 1;
    }

    if (argc < 2) {
        fprintf(stderr, "usage: bws_crypt <server_pub_hex>\n");
        return 1;
    }

    unsigned char server_pk[crypto_box_PUBLICKEYBYTES];
    size_t hex_len = strlen(argv[1]);
    if (hex_len != 64 || sodium_hex2bin(server_pk, sizeof(server_pk),
            argv[1], hex_len, NULL, NULL, NULL) != 0) {
        fprintf(stderr, "invalid server pubkey hex\n");
        return 1;
    }

    unsigned char ephemeral_pk[crypto_box_PUBLICKEYBYTES];
    unsigned char ephemeral_sk[crypto_box_SECRETKEYBYTES];
    crypto_box_keypair(ephemeral_pk, ephemeral_sk);

    unsigned char nonce[crypto_box_NONCEBYTES];
    randombytes_buf(nonce, sizeof nonce);

    size_t plaintext_len = 0;
    size_t buf_size = 65536;
    unsigned char *plaintext = malloc(buf_size);
    if (!plaintext) { fprintf(stderr, "malloc failed\n"); return 1; }

    int c;
    while ((c = getchar()) != EOF) {
        if (plaintext_len >= buf_size) {
            buf_size *= 2;
            unsigned char *tmp = realloc(plaintext, buf_size);
            if (!tmp) { free(plaintext); fprintf(stderr, "realloc failed\n"); return 1; }
            plaintext = tmp;
        }
        plaintext[plaintext_len++] = (unsigned char)c;
    }

    // Raw X25519: shared = ephemeral_sk * server_pk
    unsigned char shared[crypto_scalarmult_BYTES];
    if (crypto_scalarmult(shared, ephemeral_sk, server_pk) != 0) {
        fprintf(stderr, "crypto_scalarmult failed\n");
        free(plaintext);
        return 1;
    }

    // Use raw shared key for secretbox (XSalsa20-Poly1305)
    unsigned long long ciphertext_len = plaintext_len + crypto_secretbox_MACBYTES;
    unsigned char *ciphertext = malloc(ciphertext_len);
    if (!ciphertext) { free(plaintext); fprintf(stderr, "malloc failed\n"); return 1; }

    if (crypto_secretbox_easy(ciphertext, plaintext, (unsigned long long)plaintext_len,
            nonce, shared) != 0) {
        fprintf(stderr, "crypto_secretbox_easy failed\n");
        free(plaintext); free(ciphertext);
        return 1;
    }

    fwrite(ephemeral_pk, 1, sizeof ephemeral_pk, stdout);
    fwrite(nonce, 1, sizeof nonce, stdout);
    fwrite(ciphertext, 1, ciphertext_len, stdout);

    free(plaintext);
    free(ciphertext);
    return 0;
}
