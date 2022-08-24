#pragma once

#include <stdbool.h>

#include "common_c/types/complex_t.h"

#ifdef __cplusplus
extern "C" {
#endif

void aura_ditfft2(const aura_complex_t * times, int t, aura_complex_t * freqs, int f, int n, int step, bool inverse);
void aura_ditfft2_iterative(const aura_complex_t * times, aura_complex_t * freqs, int n, bool inverse, const aura_complex_t * exp_lut);

#ifdef __cplusplus
}
#endif
