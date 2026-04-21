#ifndef MAYO_HELPER
#define MAYO_HELPER

/* ── MAYO Set-2 Round-1 parameters (m=64, n=78, o=18, k=4, d=60) ─────────── */

#define MAYO_R1S2_m              64
#define MAYO_R1S2_n              78
#define MAYO_R1S2_o              18
#define MAYO_R1S2_k               4
#define MAYO_R1S2_m_bytes        32   /* m/2                           */
#define MAYO_R1S2_pk_seed_bytes  16
#define MAYO_R1S2_P1_bytes       58560 /* d*(d+1)/2 * m/2, d=60        */
#define MAYO_R1S2_P2_bytes       34560 /* d*o * m/2                    */
#define MAYO_R1S2_P3_bytes        5472 /* o*(o+1)/2 * m/2              */
#define MAYO_R1S2_cpk_bytes      (MAYO_R1S2_pk_seed_bytes + MAYO_R1S2_P3_bytes)             /* 5488   */
#define MAYO_R1S2_epk_bytes      (MAYO_R1S2_P1_bytes + MAYO_R1S2_P2_bytes + MAYO_R1S2_P3_bytes) /* 98592 */
#define MAYO_R1S2_sig_bytes      180  /* n*k/2 + salt_bytes = 156+24  */
#define MAYO_R1S2_salt_bytes     24
#define MAYO_R1S2_digest_bytes   32

/* ── MAYO Set-2 Round-2 parameters (m=64, n=81, o=17, k=4, d=64) ─────────── */

#define MAYO_R2S2_m              64
#define MAYO_R2S2_n              81
#define MAYO_R2S2_o              17
#define MAYO_R2S2_k               4
#define MAYO_R2S2_m_bytes        32   /* m/2                           */
#define MAYO_R2S2_pk_seed_bytes  16
#define MAYO_R2S2_P1_bytes       66560 /* d*(d+1)/2 * m/2, d=64        */
#define MAYO_R2S2_P2_bytes       34816 /* d*o * m/2                    */
#define MAYO_R2S2_P3_bytes        4896 /* o*(o+1)/2 * m/2              */
#define MAYO_R2S2_cpk_bytes      (MAYO_R2S2_pk_seed_bytes + MAYO_R2S2_P3_bytes)             /* 4912   */
#define MAYO_R2S2_epk_bytes      (MAYO_R2S2_P1_bytes + MAYO_R2S2_P2_bytes + MAYO_R2S2_P3_bytes) /* 106272 */
#define MAYO_R2S2_sig_bytes      186  /* n*k/2 + salt_bytes = 162+24  */
#define MAYO_R2S2_salt_bytes     24
#define MAYO_R2S2_digest_bytes   32

/* Largest cpk/epk/sig sizes across both rounds — used to size static buffers */
#define MAYO_MAX_cpk_bytes       MAYO_R1S2_cpk_bytes   /* 5488  */
#define MAYO_MAX_epk_bytes       MAYO_R2S2_epk_bytes   /* 106272 */
#define MAYO_MAX_sig_bytes       MAYO_R2S2_sig_bytes   /* 186   */
#define MAYO_MAX_m_bytes         MAYO_R2S2_m_bytes     /* 32    */

/* ── Params struct ──────────────────────────────────────────────────────── */

typedef struct {
    int round;
    int m;
    int m_bytes;
    int pk_seed_bytes;
    int P1_bytes;
    int P2_bytes;
    int P3_bytes;
    int cpk_bytes;
    int epk_bytes;
    int sig_bytes;
    int salt_bytes;
    int digest_bytes;
} mayo_params_t;

/* Parameter instances (defined in mayo2_verify_support.c) */
extern const mayo_params_t MAYO_R1_2;   /* Round 1, Set 2 */
extern const mayo_params_t MAYO_R2_2;   /* Round 2, Set 2 */

/* ── Function declarations ──────────────────────────────────────────────── */

/*
 * Expands a compact public key (cpk) into a full expanded public key (epk).
 *   cpk layout : [ seed_pk (pk_seed_bytes) | P3 (P3_bytes) ]
 *   epk layout : [ P1 (P1_bytes) | P2 (P2_bytes) | P3 (P3_bytes) ]
 */
int mayo_expand_pk(const mayo_params_t *p, const unsigned char *cpk,
                   unsigned char *epk);

/*
 * Derives the target vector t from the message and signature.
 * Output t has m_bytes bytes (nibble-swapped packed GF(16) elements).
 */
int deriveT(const mayo_params_t *p, const unsigned char *m,
         unsigned long long mlen, const unsigned char *sig,
         unsigned char *t);

#endif /* MAYO_HELPER */
