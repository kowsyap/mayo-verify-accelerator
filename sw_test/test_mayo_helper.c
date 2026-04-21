#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "../mayo_helper.h"

#define KAT_R1 "../../kat/KAT_R1_S2.kat"
#define KAT_R2 "../../kat/KAT_R2_S2.kat"

/* Maximum line length: R1 CPK is 5488 B = 10976 hex chars */
#define MAX_LINE 12000
#define MAX_MSG  4096

static int hex_nibble(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

static int hex_to_bytes(const char *hex, unsigned char *out, int max_bytes) {
    int len = (int)strlen(hex);
    if (len % 2 != 0) return -1;
    int nbytes = len / 2;
    if (nbytes > max_bytes) return -1;
    for (int i = 0; i < nbytes; i++) {
        int hi = hex_nibble(hex[2*i]);
        int lo = hex_nibble(hex[2*i + 1]);
        if (hi < 0 || lo < 0) return -1;
        out[i] = (unsigned char)((hi << 4) | lo);
    }
    return nbytes;
}

static void strip_nl(char *s) {
    int n = (int)strlen(s);
    while (n > 0 && (s[n-1] == '\n' || s[n-1] == '\r' || s[n-1] == ' '))
        s[--n] = '\0';
}

static int run_kat(const mayo_params_t *p, const char *kat_path,
                   int *total_out, int *pass_out) {
    FILE *kat = fopen(kat_path, "r");
    if (!kat) {
        fprintf(stderr, "Cannot open KAT file: %s\n", kat_path);
        return -1;
    }

    unsigned char *cpk  = malloc(p->cpk_bytes);
    unsigned char *epk  = malloc(p->epk_bytes);
    unsigned char *msg  = malloc(MAX_MSG);
    char          *line = malloc(MAX_LINE);
    if (!cpk || !epk || !msg || !line) {
        fprintf(stderr, "malloc failed\n");
        fclose(kat);
        return -1;
    }

    int case_num = 0, total = 0, pk_pass = 0;
    int length = 0, msg_len = 0, cpk_len = 0;

    while (fgets(line, MAX_LINE, kat)) {
        strip_nl(line);

        if (strncmp(line, "# Case", 6) == 0) {
            case_num++;
            length = msg_len = cpk_len = 0;
            continue;
        }
        if (strncmp(line, "LENGTH=", 7) == 0) {
            length = atoi(line + 7);
            continue;
        }
        if (strncmp(line, "MSG=", 4) == 0) {
            msg_len = hex_to_bytes(line + 4, msg, MAX_MSG);
            if (msg_len < 0) { fprintf(stderr, "Case %d: bad MSG\n", case_num); msg_len = 0; }
            continue;
        }
        if (strncmp(line, "CSK=", 4) == 0)
            continue;

        if (strncmp(line, "CPK=", 4) == 0) {
            cpk_len = hex_to_bytes(line + 4, cpk, p->cpk_bytes);
            if (cpk_len != p->cpk_bytes) {
                fprintf(stderr, "Case %d: CPK size mismatch (got %d, expected %d)\n",
                        case_num, cpk_len, p->cpk_bytes);
                continue;
            }

            total++;
            printf("  Case %d (msg_len=%d)\n", case_num, length);

            /* ---- mayo_expand_pk ---- */
            int ret = mayo_expand_pk(p, cpk, epk);
            int ok  = (ret == 0);
            pk_pass += ok;
            printf("    mayo_expand_pk : %s\n", ok ? "OK" : "FAILED");

            int p3_ok = (memcmp(epk + p->P1_bytes + p->P2_bytes,
                                cpk + p->pk_seed_bytes, p->P3_bytes) == 0);
            printf("    P3 copy check  : %s\n", p3_ok ? "OK" : "MISMATCH");

            printf("    pk_seed[0..15] : ");
            for (int i = 0; i < p->pk_seed_bytes; i++) printf("%02x", cpk[i]);
            printf("\n");

            printf("    epk[0..15]     : ");
            for (int i = 0; i < 16; i++) printf("%02x", epk[i]);
            printf("\n");

            /* ---- deriveT (real MSG, zero sig) ---- */
            if (msg_len > 0) {
                unsigned char sig[MAYO_MAX_sig_bytes];
                unsigned char t[MAYO_MAX_m_bytes];
                memset(sig, 0x00, p->sig_bytes);

                ret = deriveT(p, msg, (unsigned long long)msg_len, sig, t);
                printf("    deriveT        : %s\n", ret == 0 ? "OK" : "FAILED");
                printf("    t[0..%2d]       : ", p->m_bytes - 1);
                for (int i = 0; i < p->m_bytes; i++) printf("%02x", t[i]);
                printf("\n");
            }
            printf("\n");
        }
    }

    *total_out = total;
    *pass_out  = pk_pass;

    fclose(kat);
    free(cpk); free(epk); free(msg); free(line);
    return 0;
}

int main(void) {
    printf("=== MAYO Set-2 verify support test ===\n\n");

    struct { const mayo_params_t *p; const char *kat; } runs[] = {
        { &MAYO_R1_2, KAT_R1 },
        { &MAYO_R2_2, KAT_R2 },
    };

    int grand_total = 0, grand_pass = 0;

    for (int r = 0; r < 2; r++) {
        const mayo_params_t *p = runs[r].p;
        printf("--- Round %d, Set 2  (cpk=%d B, epk=%d B, sig=%d B) ---\n",
               p->round, p->cpk_bytes, p->epk_bytes, p->sig_bytes);

        int total = 0, pass = 0;
        if (run_kat(p, runs[r].kat, &total, &pass) == 0) {
            printf("  Round %d summary: %d/%d passed mayo_expand_pk\n\n",
                   p->round, pass, total);
            grand_total += total;
            grand_pass  += pass;
        }
    }

    printf("=== Grand total: %d/%d cases passed ===\n", grand_pass, grand_total);
    return (grand_pass == grand_total && grand_total > 0) ? 0 : 1;
}
