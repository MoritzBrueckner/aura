#include <stdlib.h>

#include "complex_array.h"

aura_complex_t* aura_complex_array_alloc(int length) {
	return calloc(length, sizeof(aura_complex_t));
}

void aura_complex_array_free(aura_complex_t* complex_array) {
	free(complex_array);
}

aura_complex_t* aura_complex_array_set(aura_complex_t* complex_array, int index, float real, float imag) {
	complex_array[index].real = real;
	complex_array[index].imag = imag;
	return &(complex_array[index]);
}

aura_complex_t* aura_complex_array_get(aura_complex_t* complex_array, int index/*, float* real, float* imag*/) {
	return &(complex_array[index]);
}
