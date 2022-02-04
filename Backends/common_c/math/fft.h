#pragma once

#include <stdbool.h>

#include "common_c/types/complex_t.h"

#ifdef __cplusplus
extern "C" {
#endif

void aura_ditfft2(const aura_complex_t * times, int t, aura_complex_t * freqs, int f, int n, int step, bool inverse);

#ifdef __cplusplus
}
#endif
