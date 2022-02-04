#pragma once

#include <hl.h>

#include "hl/aura/aurahl.h"

#include "common_c/types/complex_array.h"
#include "common_c/types/complex_t.h"

HL_PRIM vbyte* AURA_HL_FUNC(complex_array_alloc)(int length) {
	return (vbyte*) aura_complex_array_alloc(length);
}

HL_PRIM void AURA_HL_FUNC(complex_array_free)(vbyte* complex_array) {
	aura_complex_array_free((aura_complex_t*) complex_array);
}

HL_PRIM aura_complex_t* AURA_HL_FUNC(complex_array_set)(vbyte* complex_array, int index, float real, float imag) {
	return aura_complex_array_set((aura_complex_t *) complex_array, index, real, imag);
}
HL_PRIM aura_complex_t* AURA_HL_FUNC(complex_array_get)(vbyte* complex_array, int index) {
	return aura_complex_array_get((aura_complex_t*) complex_array, index);
}

DEFINE_PRIM(_BYTES, complex_array_alloc, _I32)
DEFINE_PRIM(_VOID, complex_array_free, _BYTES)

DEFINE_PRIM(_REF(_aura__types___Complex__ComplexImpl), complex_array_set, _BYTES _I32 _F32 _F32)
DEFINE_PRIM(_REF(_aura__types___Complex__ComplexImpl), complex_array_get, _BYTES _I32)
