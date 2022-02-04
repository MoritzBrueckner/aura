#include <math.h>

#include "complex_t.h"

void aura_copy_complex_elem(aura_complex_t *to, const int toIndex, const aura_complex_t *from, const int fromIndex) {
	to[toIndex].real = from[fromIndex].real;
	to[toIndex].imag = from[fromIndex].imag;
}

void aura_copy_complex(aura_complex_t *to, const aura_complex_t from) {
	to->real = from.real;
	to->imag = from.imag;
}

aura_complex_t aura_cexp(const float w) {
	const aura_complex_t out = {.real = cosf(w), .imag = sinf(w)};
	return out;
}

aura_complex_t aura_cadd(const aura_complex_t a, const aura_complex_t b) {
	const aura_complex_t out = {.real = a.real + b.real, .imag = a.imag + b.imag};
	return out;
}

aura_complex_t aura_csub(const aura_complex_t a, const aura_complex_t b) {
	const aura_complex_t out = {.real = a.real - b.real, .imag = a.imag - b.imag};
	return out;
}

aura_complex_t aura_cmult(const aura_complex_t a, const aura_complex_t b) {
	const aura_complex_t out = {
 		.real = a.real * b.real - a.imag * b.imag,
 		.imag = a.real * b.imag + a.imag * b.real
	};
	return out;
}
