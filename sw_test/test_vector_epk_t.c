// SPDX-License-Identifier: Apache-2.0

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../mayo_helper.h"

#define R1_CPK_PATH "../vectors/input_gen_r1_cpk_mayo_2_test.txt"
#define R1_MSG_PATH "../vectors/input_gen_r1_msg_mayo_2_test.txt"
#define R1_SIG_PATH "../vectors/input_gen_r1_sig_mayo_2_test.txt"
#define R1_EPK_PATH "../vectors/input_gen_r1_epk_mayo_2_test.txt"

#define R2_CPK_PATH "../vectors/input_gen_r2_cpk_mayo_2_test.txt"
#define R2_MSG_PATH "../vectors/input_gen_r2_msg_mayo_2_test.txt"
#define R2_SIG_PATH "../vectors/input_gen_r2_sig_mayo_2_test.txt"
#define R2_EPK_PATH "../vectors/input_gen_r2_epk_mayo_2_test.txt"

enum { MAX_HEX_FILE_BYTES = 220000 };

typedef struct {
    const mayo_params_t *params;
    const char *cpk_path;
    const char *msg_path;
    const char *sig_path;
    const char *epk_path;
} vector_case_t;

static int hex_nibble(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

static int read_hex_file(const char *path, unsigned char *out, int max_bytes) {
    FILE *fp = fopen(path, "r");
    int c;
    int high = -1;
    int count = 0;

    if (!fp) {
        fprintf(stderr, "Cannot open file: %s\n", path);
        return -1;
    }

    while ((c = fgetc(fp)) != EOF) {
        int nibble;

        if (isspace((unsigned char)c)) {
            continue;
        }

        nibble = hex_nibble((char)c);
        if (nibble < 0) {
            fprintf(stderr, "Invalid hex character '%c' in %s\n", c, path);
            fclose(fp);
            return -1;
        }

        if (high < 0) {
            high = nibble;
            continue;
        }

        if (count >= max_bytes) {
            fprintf(stderr, "File too large for buffer: %s\n", path);
            fclose(fp);
            return -1;
        }

        out[count++] = (unsigned char)((high << 4) | nibble);
        high = -1;
    }

    fclose(fp);

    if (high >= 0) {
        fprintf(stderr, "Odd number of hex digits in %s\n", path);
        return -1;
    }

    return count;
}

static void print_hex_block(const char *label, const unsigned char *buf, int len) {
    printf("%s (%d bytes)\n", label, len);
    for (int i = 0; i < len; ++i) {
        printf("%02X", buf[i]);
        if ((i + 1) % 32 == 0) {
            printf("\n");
        }
    }
    if (len % 32 != 0) {
        printf("\n");
    }
}

static int run_vector_case(const vector_case_t *tc) {
    const mayo_params_t *p = tc->params;
    unsigned char *cpk = NULL;
    unsigned char *msg = NULL;
    unsigned char *sig = NULL;
    unsigned char *epk = NULL;
    unsigned char *exp_epk = NULL;
    unsigned char t[MAYO_MAX_m_bytes];
    int cpk_len;
    int msg_len;
    int sig_len;
    int exp_epk_len;
    int epk_match;
    int ret = 1;

    cpk = malloc(p->cpk_bytes);
    msg = malloc(MAX_HEX_FILE_BYTES);
    sig = malloc(MAX_HEX_FILE_BYTES);
    epk = malloc(p->epk_bytes);
    exp_epk = malloc(p->epk_bytes);
    if (!cpk || !msg || !sig || !epk || !exp_epk) {
        fprintf(stderr, "malloc failed\n");
        goto cleanup;
    }

    cpk_len = read_hex_file(tc->cpk_path, cpk, p->cpk_bytes);
    msg_len = read_hex_file(tc->msg_path, msg, MAX_HEX_FILE_BYTES);
    sig_len = read_hex_file(tc->sig_path, sig, MAX_HEX_FILE_BYTES);
    exp_epk_len = read_hex_file(tc->epk_path, exp_epk, p->epk_bytes);
    if (cpk_len < 0 || msg_len < 0 || sig_len < 0 || exp_epk_len < 0) {
        goto cleanup;
    }

    if (cpk_len != p->cpk_bytes) {
        fprintf(stderr, "Round %d: CPK size mismatch: got %d bytes, expected %d\n",
                p->round, cpk_len, p->cpk_bytes);
        goto cleanup;
    }

    if (sig_len < p->salt_bytes) {
        fprintf(stderr, "Round %d: SIG too short: got %d bytes, need at least %d\n",
                p->round, sig_len, p->salt_bytes);
        goto cleanup;
    }

    if (exp_epk_len != p->epk_bytes) {
        fprintf(stderr, "Round %d: Expected EPK size mismatch: got %d bytes, expected %d\n",
                p->round, exp_epk_len, p->epk_bytes);
        goto cleanup;
    }

    if (mayo_expand_pk(p, cpk, epk) != 0) {
        fprintf(stderr, "Round %d: mayo_expand_pk failed\n", p->round);
        goto cleanup;
    }

    if (deriveT(p, msg, (unsigned long long)msg_len, sig, t) != 0) {
        fprintf(stderr, "Round %d: deriveT failed\n", p->round);
        goto cleanup;
    }

    epk_match = (memcmp(epk, exp_epk, p->epk_bytes) == 0);

    printf("MAYO Round %d Set 2 vector test\n", p->round);
    printf("CPK file: %s\n", tc->cpk_path);
    printf("MSG file: %s\n", tc->msg_path);
    printf("SIG file: %s\n", tc->sig_path);
    printf("Expected EPK file: %s\n", tc->epk_path);
    printf("EPK compare: %s\n\n", epk_match ? "PASS" : "FAIL");

    print_hex_block("T", t, p->m_bytes);
    printf("\n");
    print_hex_block("EPK", epk, p->epk_bytes);
    printf("\n");

    ret = epk_match ? 0 : 1;

cleanup:
    free(cpk);
    free(msg);
    free(sig);
    free(epk);
    free(exp_epk);
    return ret;
}

int main(void) {
    vector_case_t cases[] = {
        { &MAYO_R1_2, R1_CPK_PATH, R1_MSG_PATH, R1_SIG_PATH, R1_EPK_PATH },
        { &MAYO_R2_2, R2_CPK_PATH, R2_MSG_PATH, R2_SIG_PATH, R2_EPK_PATH },
    };
    int rc = 0;

    for (int i = 0; i < 2; ++i) {
        if (run_vector_case(&cases[i]) != 0) {
            rc = 1;
        }
    }

    return rc;
}
