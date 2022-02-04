#pragma once

#include "common_c/types/complex_t.h"

#ifdef __cplusplus
extern "C" {
#endif

aura_complex_t* aura_complex_array_alloc(int length);
void aura_complex_array_free(aura_complex_t* complex_array);

aura_complex_t* aura_complex_array_set(aura_complex_t* complex_array, int index, float real, float imag);
aura_complex_t* aura_complex_array_get(aura_complex_t* complex_array, int index);

#ifdef __cplusplus
}
#endif
