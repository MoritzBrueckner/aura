#pragma once

#include <hl.h>

#include <aura/types/_ComplexArray/HL_ComplexArrayImpl.h>

#include "hl/aura/aurahl.h"
#include "common_c/math/fft.h"
#include "common_c/types/complex_t.h"

HL_PRIM void AURA_HL_FUNC(ditfft2)(aura__types___ComplexArray__HL_ComplexArrayImpl time_array, int t, aura__types___ComplexArray__HL_ComplexArrayImpl freq_array, int f, int n, int step, bool inverse) {
	const aura_complex_t *times = (aura_complex_t*) time_array->self;
	aura_complex_t *freqs = (aura_complex_t*) freq_array->self;

	aura_ditfft2(times, t, freqs, f, n, step, inverse);
}

HL_PRIM void AURA_HL_FUNC(ditfft2_iterative)(aura__types___ComplexArray__HL_ComplexArrayImpl time_array, aura__types___ComplexArray__HL_ComplexArrayImpl freq_array, int n, bool inverse, aura__types___ComplexArray__HL_ComplexArrayImpl exp_rotation_step_table) {
	const aura_complex_t *times = (aura_complex_t*) time_array->self;
	aura_complex_t *freqs = (aura_complex_t*) freq_array->self;

	const aura_complex_t *exp_lut = (aura_complex_t*) exp_rotation_step_table->self;

	aura_ditfft2_iterative(times, freqs, n, inverse, exp_lut);
}

DEFINE_PRIM(_VOID, ditfft2, _BYTES _I32 _BYTES _I32 _I32 _I32 _BOOL)
DEFINE_PRIM(_VOID, ditfft2_iterative, _BYTES _BYTES _I32 _BOOL _BYTES)
