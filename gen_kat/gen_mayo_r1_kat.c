// SPDX-License-Identifier: Apache-2.0

#include <mayo.h>
#include <rng.h>

#include <ctype.h>
#include <errno.h>
#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef ENABLE_PARAMS_DYNAMIC
static const char *PARAM_SETS[] = {"mayo_1", "mayo_2", "mayo_3", "mayo_5"};
static const int PARAM_SET_COUNT = sizeof(PARAM_SETS) / sizeof(PARAM_SETS[0]);
#endif

#ifdef ENABLE_PARAMS_DYNAMIC
static const mayo_params_t *resolve_variant(const char *arg) {
    if (strcmp(arg, "mayo_1") == 0 || strcmp(arg, "MAYO_1") == 0) return &MAYO_1;
    if (strcmp(arg, "mayo_2") == 0 || strcmp(arg, "MAYO_2") == 0) return &MAYO_2;
    if (strcmp(arg, "mayo_3") == 0 || strcmp(arg, "MAYO_3") == 0) return &MAYO_3;
    if (strcmp(arg, "mayo_5") == 0 || strcmp(arg, "MAYO_5") == 0) return &MAYO_5;
    return NULL;
}
#else
static const mayo_params_t *resolve_variant(const char *arg) {
    (void)arg;
    return &MAYO_VARIANT;
}
#endif

static int resolve_set_number(const char *param_set) {
    if (strcmp(param_set, "mayo_1") == 0) return 1;
    if (strcmp(param_set, "mayo_2") == 0) return 2;
    if (strcmp(param_set, "mayo_3") == 0) return 3;
    if (strcmp(param_set, "mayo_5") == 0) return 5;
    return -1;
}

static int write_hex(FILE *f, const unsigned char *buf, size_t len) {
    for (size_t i = 0; i < len; ++i) {
        if (fprintf(f, "%02X", buf[i]) < 0) {
            return -1;
        }
    }
    return 0;
}

static int resolve_message_lengths(int limit, int min_len, int max_len, int **out) {
    if (limit <= 0) {
        *out = NULL;
        return 0;
    }
    if (min_len < 0) {
        fprintf(stderr, "min_len must be non-negative\n");
        return -1;
    }
    if (max_len < min_len) {
        fprintf(stderr, "max_len must be greater than or equal to min_len\n");
        return -1;
    }

    int *lens = calloc((size_t)limit, sizeof(int));
    if (!lens) {
        perror("calloc");
        return -1;
    }

    for (int i = 0; i < limit; ++i) {
        unsigned char buf[4];
        if (randombytes(buf, sizeof(buf)) != 0) {
            fprintf(stderr, "randombytes failed\n");
            free(lens);
            return -1;
        }
        unsigned int r = ((unsigned int)buf[0] << 24) | ((unsigned int)buf[1] << 16) |
                         ((unsigned int)buf[2] << 8) | (unsigned int)buf[3];
        int range = max_len - min_len + 1;
        lens[i] = min_len + (int)(r % (unsigned int)range);
    }

    *out = lens;
    return 0;
}

static int write_cases(const char *path, const mayo_params_t *p, int *msg_lens, int count, int min_len, int max_len) {
    FILE *f = fopen(path, "w");
    if (!f) {
        perror("fopen");
        return -1;
    }

    unsigned char *msg = NULL;
    unsigned char *csk = NULL;
    unsigned char *cpk = NULL;
    unsigned char *esk = NULL;
    unsigned char *sm = NULL;

    msg = calloc((size_t)max_len, 1);
    csk = calloc((size_t)p->csk_bytes, 1);
    cpk = calloc((size_t)p->cpk_bytes, 1);
    esk = calloc((size_t)p->esk_bytes, 1);
    /* mayo_sign outputs sig || msg, so allocate enough space for both */
    sm = calloc((size_t)p->sig_bytes + (size_t)max_len, 1);

    if (!msg || !csk || !cpk || !esk || !sm) {
        fprintf(stderr, "Allocation failure\n");
        goto err;
    }

    for (int i = 0; i < count; ++i) {
        int msg_len = msg_lens[i];
        if (randombytes(msg, (unsigned long long)msg_len) != 0) {
            fprintf(stderr, "randombytes failed\n");
            goto err;
        }

        if (mayo_keypair_compact(p, cpk, csk) != MAYO_OK) {
            fprintf(stderr, "mayo_keypair_compact failed\n");
            goto err;
        }

        if (mayo_expand_sk(p, csk, esk) != MAYO_OK) {
            fprintf(stderr, "mayo_expand_sk failed\n");
            goto err;
        }

        unsigned long long smlen = (unsigned long long)p->sig_bytes + (unsigned long long)msg_len;
        if (mayo_sign(p, sm, &smlen, msg, (unsigned long long)msg_len, csk) != MAYO_OK) {
            fprintf(stderr, "mayo_sign failed\n");
            goto err;
        }
        if (smlen != (unsigned long long)p->sig_bytes + (unsigned long long)msg_len) {
            fprintf(stderr, "unexpected signed output length %llu (expected %d + %d)\n", smlen, p->sig_bytes, msg_len);
            goto err;
        }

        fprintf(f, "# Case %d\n", i + 1);
        fprintf(f, "LENGTH=%d\n", msg_len);
        fprintf(f, "MSG=");
        if (write_hex(f, msg, (size_t)msg_len) != 0) goto err;
        fprintf(f, "\n");
        fprintf(f, "CSK=");
        if (write_hex(f, csk, (size_t)p->csk_bytes) != 0) goto err;
        fprintf(f, "\n");
        fprintf(f, "CPK=");
        if (write_hex(f, cpk, (size_t)p->cpk_bytes) != 0) goto err;
        fprintf(f, "\n");
        fprintf(f, "SIGNATURE=");
        if (write_hex(f, sm, (size_t)p->sig_bytes) != 0) goto err;
        fprintf(f, "\n");

        if (i != count - 1) {
            fprintf(f, "\n");
        }
    }

    fclose(f);
    free(msg);
    free(csk);
    free(cpk);
    free(esk);
    free(sm);
    return 0;

err:
    if (f)
        fclose(f);
    free(msg);
    free(csk);
    free(cpk);
    free(esk);
    free(sm);
    return -1;
}

static void print_usage(const char *prog) {
    printf("Usage: %s --limit <N> [--param <mayo_1|mayo_2|mayo_3|mayo_5>] [--min-msg-len <N>] [--max-msg-len <N>]\n", prog);
    printf("Generate KAT_R1_S<set>.kat files in the current directory.\n");
}

int main(int argc, char **argv) {
    int limit = 0;
    int min_msg_len = 8;
    int max_msg_len = 65535;
    const char *param_arg = NULL;

    struct option longopts[] = {
        {"limit", required_argument, NULL, 'l'},
        {"param", required_argument, NULL, 'p'},
        {"min-msg-len", required_argument, NULL, 'm'},
        {"max-msg-len", required_argument, NULL, 'x'},
        {"help", no_argument, NULL, 'h'},
        {NULL, 0, NULL, 0}};

    int opt;
    while ((opt = getopt_long(argc, argv, "l:p:m:x:h", longopts, NULL)) != -1) {
        switch (opt) {
            case 'l':
                limit = atoi(optarg);
                break;
            case 'p':
                param_arg = optarg;
                break;
            case 'm':
                min_msg_len = atoi(optarg);
                break;
            case 'x':
                max_msg_len = atoi(optarg);
                break;
            case 'h':
            default:
                print_usage(argv[0]);
                return (opt == 'h') ? 0 : 1;
        }
    }

    if (limit <= 0) {
        fprintf(stderr, "Provide --limit > 0 to generate random cases.\n");
        return 1;
    }

    unsigned char entropy_input[48];
    memset(entropy_input, 0, sizeof(entropy_input));
    randombytes_init(entropy_input, NULL, 256);

    int *msg_lens = NULL;
    if (resolve_message_lengths(limit, min_msg_len, max_msg_len, &msg_lens) != 0) {
        return 1;
    }

    const char **param_sets = NULL;
    int param_count = 0;

#ifdef ENABLE_PARAMS_DYNAMIC
    if (param_arg) {
        const mayo_params_t *p = resolve_variant(param_arg);
        if (!p) {
            fprintf(stderr, "Unknown param set '%s'\n", param_arg);
            free(msg_lens);
            return 1;
        }
        param_sets = &param_arg;
        param_count = 1;
    } else {
        param_sets = PARAM_SETS;
        param_count = PARAM_SET_COUNT;
    }
#else
    /* When not built with dynamic variant support, the binary is tied to a single
       MAYO_VARIANT via the build system. Only that variant can be generated. */
    const mayo_params_t *compiled_p = &MAYO_VARIANT;
    const char *compiled_variant = "mayo_1";

    if (compiled_p == &MAYO_1) {
        compiled_variant = "mayo_1";
    } else if (compiled_p == &MAYO_2) {
        compiled_variant = "mayo_2";
    } else if (compiled_p == &MAYO_3) {
        compiled_variant = "mayo_3";
    } else if (compiled_p == &MAYO_5) {
        compiled_variant = "mayo_5";
    }

    if (param_arg && strcmp(param_arg, compiled_variant) != 0) {
        fprintf(stderr, "This binary was built for %s; use that variant or rebuild with ENABLE_PARAMS_DYNAMIC.\n", compiled_variant);
        free(msg_lens);
        return 1;
    }

    param_sets = &compiled_variant;
    param_count = 1;
#endif

    for (int i = 0; i < param_count; ++i) {
        const char *param_set = param_sets[i];
        const mayo_params_t *p = resolve_variant(param_set);
        if (!p) {
            fprintf(stderr, "Unknown param set '%s'\n", param_set);
            continue;
        }
        int set_num = resolve_set_number(param_set);
        if (set_num < 0) {
            fprintf(stderr, "Unknown set number for param set '%s'\n", param_set);
            continue;
        }

        char path[64];
        snprintf(path, sizeof(path), "KAT_R1_S%d.kat", set_num);

        if (write_cases(path, p, msg_lens, limit, min_msg_len, max_msg_len) != 0) {
            fprintf(stderr, "Failed to write cases for %s\n", param_set);
            continue;
        }

        printf("Wrote %d case(s) to %s\n", limit, path);
    }

    free(msg_lens);
    return 0;
}
