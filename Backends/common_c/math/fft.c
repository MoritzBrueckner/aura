#include "fft.h"

#define PI_FLOAT 3.14159265358979323846f

void aura_ditfft2(const aura_complex_t * times, int t, aura_complex_t * freqs, int f, int n, int step, bool inverse) {
	if (n == 1) {
		aura_copy_complex_elem(freqs, f, times, t);
	}
	else {
		const int halfLen = n >> 1;

		aura_ditfft2(times, t, freqs, f, halfLen, step << 1, inverse);
		aura_ditfft2(times, t + step, freqs, f + halfLen, halfLen, step << 1, inverse);

		const float t_exp = ((inverse ? 1.0f : -1.0f) * 2.0f * PI_FLOAT) / n;
		for (int k = 0; k < halfLen; k++) {
			aura_complex_t even = { 0 };
			aura_complex_t odd = { 0 };
			aura_copy_complex(&even, freqs[f + k]);
			aura_copy_complex(&odd, freqs[f + k + halfLen]);

			const aura_complex_t twiddle = aura_cmult(aura_cexp(t_exp * k), odd);

			aura_copy_complex(&(freqs[f + k]), aura_cadd(even, twiddle));
			aura_copy_complex(&(freqs[f + k + halfLen]), aura_csub(even, twiddle));
		}
	}
}
