// SPDX-License-Identifier: Apache-2.0

#ifndef AES_H
#define AES_H

#include <stddef.h>
#include <stdint.h>

int AES_128_CTR(unsigned char *output, size_t outputByteLen,
                const unsigned char *input);

#endif
