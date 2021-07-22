#include frex:shaders/api/view.glsl

/*******************************************************
 *  lumi:shaders/lib/block_dir.glsl
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

// UNUSED BECAUSE IT'S EXPERIMENTAL AND BROKEN
#define BLOCKLIGHT_SPECULAR_MODE_FANTASTIC -1

#if BLOCKLIGHT_SPECULAR_MODE == BLOCKLIGHT_SPECULAR_MODE_FANTASTIC
vec3 preCalc_blockDir;
const int BLOCK_DIR_N = 24;
// Circle test
const vec2[BLOCK_DIR_N] BLOCK_DIR_TEST = vec2[](
	vec2(1., 0.), 
	vec2(0.78867513, 0.21132487), 
	vec2(0.6339746, 0.3660254), 
	vec2(0.5, 0.5), 
	vec2(0.3660254, 0.6339746), 
	vec2(0.21132487, 0.78867513), 
	vec2(2.83276945e-16, 1.00000000e+00), 
	vec2(-0.21132487,  0.78867513), 
	vec2(-0.3660254,  0.6339746), 
	vec2(-0.5,  0.5), 
	vec2(-0.6339746,  0.3660254), 
	vec2(-0.78867513,  0.21132487), 
	vec2(-1.0000000e+00, -3.2162453e-16), 
	vec2(-0.78867513, -0.21132487), 
	vec2(-0.6339746, -0.3660254), 
	vec2(-0.5, -0.5), 
	vec2(-0.3660254, -0.6339746), 
	vec2(-0.21132487, -0.78867513), 
	vec2(-1.8369702e-16, -1.0000000e+00), 
	vec2( 0.21132487, -0.78867513), 
	vec2( 0.3660254, -0.6339746), 
	vec2( 0.5, -0.5), 
	vec2( 0.6339746, -0.3660254), 
	vec2( 0.78867513, -0.21132487)
);

vec3 calcBlockDir(in sampler2D slight, in vec2 uv, vec2 inv_size, in vec3 normal, in vec3 viewPos, in sampler2D sdepth) {
	int m = -1;
	vec2 pixel_size = inv_size * 4.0;
	float brightest = texture(slight, uv).x;
	for(int i = 0; i < BLOCK_DIR_N; i++) {
		float current = texture(slight, uv + BLOCK_DIR_TEST[i] * pixel_size).x;
		if (current > brightest) {
			m = i;
			brightest = current;
		}
	}
	if (m == -1) {
		return normal;
	} else {
		vec2 mUV = uv + BLOCK_DIR_TEST[m] * pixel_size;
		vec4 mViewPos = frx_inverseProjectionMatrix() * vec4(2.0 * mUV - 1.0, 2.0 * texture(sdepth, mUV).r - 1.0, 1.0);
		mViewPos.xyz /= mViewPos.w;
		vec3 mDir = normalize(mViewPos.xyz - viewPos) * frx_normalModelMatrix();
		return normalize(normal+mDir);
	}
}
#endif
