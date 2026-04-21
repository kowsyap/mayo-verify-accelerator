// SPDX-License-Identifier: Apache-2.0

#include <stdio.h>
#include <string.h>

#include "aes.h"
#include "fips202.h"
#include "mayo_helper.h"

/* ── MAYO-2 parameter instance ──────────────────────────────────────────── */

const mayo_params_t MAYO_R1_2 = {
    .round          = 1,
    .m              = MAYO_R1S2_m,
    .m_bytes        = MAYO_R1S2_m_bytes,
    .pk_seed_bytes  = MAYO_R1S2_pk_seed_bytes,
    .P1_bytes       = MAYO_R1S2_P1_bytes,
    .P2_bytes       = MAYO_R1S2_P2_bytes,
    .P3_bytes       = MAYO_R1S2_P3_bytes,
    .cpk_bytes      = MAYO_R1S2_cpk_bytes,
    .epk_bytes      = MAYO_R1S2_epk_bytes,
    .sig_bytes      = MAYO_R1S2_sig_bytes,
    .salt_bytes     = MAYO_R1S2_salt_bytes,
    .digest_bytes   = MAYO_R1S2_digest_bytes,
};

const mayo_params_t MAYO_R2_2 = {
    .round          = 2,
    .m              = MAYO_R2S2_m,
    .m_bytes        = MAYO_R2S2_m_bytes,
    .pk_seed_bytes  = MAYO_R2S2_pk_seed_bytes,
    .P1_bytes       = MAYO_R2S2_P1_bytes,
    .P2_bytes       = MAYO_R2S2_P2_bytes,
    .P3_bytes       = MAYO_R2S2_P3_bytes,
    .cpk_bytes      = MAYO_R2S2_cpk_bytes,
    .epk_bytes      = MAYO_R2S2_epk_bytes,
    .sig_bytes      = MAYO_R2S2_sig_bytes,
    .salt_bytes     = MAYO_R2S2_salt_bytes,
    .digest_bytes   = MAYO_R2S2_digest_bytes,
};

/* ── Helper ─────────────────────────────────────────────────────────────── */

/* Unpacks packed nibbles into one element per byte.
   Used by getT to expand the m_bytes SHAKE output into m GF(16) elements. */
static void decode(const unsigned char *in, unsigned char *out, int len) {
    int i;
    for (i = 0; i < len / 2; ++i) {
        *out++ = in[i] & 0x0f;
        *out++ = in[i] >> 4;
    }
    if (len % 2 == 1) {
        *out++ = in[i] & 0x0f;
    }
}

/* ── mayo_expand_pk ─────────────────────────────────────────────────────── */

int mayo_expand_pk(const mayo_params_t *p, const unsigned char *cpk,
                   unsigned char *epk) {
    /* Derive P1 || P2 from seed_pk using AES-128-CTR */
    AES_128_CTR(epk, p->P1_bytes + p->P2_bytes, cpk);

    /* Copy P3 verbatim from cpk */
    memmove(epk + p->P1_bytes + p->P2_bytes,
            cpk + p->pk_seed_bytes,
            p->P3_bytes);

    return 0;
}

/* ── getT ───────────────────────────────────────────────────────────────── */

int deriveT(const mayo_params_t *p, const unsigned char *m,
         unsigned long long mlen, const unsigned char *sig,
         unsigned char *t) {
    unsigned char tEnc[MAYO_MAX_m_bytes];
    unsigned char tmp[MAYO_MAX_m_bytes + MAYO_R1S2_salt_bytes]; /* digest_bytes + salt_bytes */

    /* Hash the message */
    SHAKE256(tmp, p->digest_bytes, m, mlen);

    /* Append salt (last salt_bytes of sig) */
    memcpy(tmp + p->digest_bytes,
           sig + p->sig_bytes - p->salt_bytes,
           p->salt_bytes);

    /* Derive packed target vector */
    SHAKE256(tEnc, p->m_bytes, tmp, p->digest_bytes + p->salt_bytes);

    /* Unpack nibbles into t, then apply nibble swap */
    decode(tEnc, t, p->m);
    for (int i = 0; i < p->m_bytes; ++i) {
        t[i] = ((tEnc[i] & 0x0F) << 4) | ((tEnc[i] & 0xF0) >> 4);
    }

    return 0;
}
