#pragma once

#include <hl.h>

#include <aura/types/ComplexArrayImpl.h>

#include "hl/aura/aurahl.h"
#include "common_c/math/fft.h"
#include "common_c/types/complex_t.h"

HL_PRIM void AURA_HL_FUNC(ditfft2)(aura__types__ComplexArrayImpl time_array, int t, aura__types__ComplexArrayImpl freq_array, int f, int n, int step, bool inverse) {
	const aura_complex_t *times = (aura_complex_t*) time_array->self;
	aura_complex_t *freqs = (aura_complex_t*) freq_array->self;

	aura_ditfft2(times, t, freqs, f, n, step, inverse);
}

DEFINE_PRIM(_VOID, ditfft2, _BYTES _I32 _BYTES _I32 _I32 _I32 _BOOL)
