#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef struct aura_complex_t {
	float real;
	float imag;
} aura_complex_t;

void aura_copy_complex_elem(aura_complex_t *to, const int toIndex, const aura_complex_t *from, const int fromIndex);
void aura_copy_complex(aura_complex_t *to, const aura_complex_t from);

aura_complex_t aura_cexp(const float w);

aura_complex_t aura_cadd(const aura_complex_t a, const aura_complex_t b);
aura_complex_t aura_csub(const aura_complex_t a, const aura_complex_t b);
aura_complex_t aura_cmult(const aura_complex_t a, const aura_complex_t b);
aura_complex_t aura_cconj(const aura_complex_t val);

#ifdef __cplusplus
}
#endif
