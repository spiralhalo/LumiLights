#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/lib/ssao.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/common/userconfig.glsl

/*******************************************************
 *  lumi:shaders/post/ssao.frag
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

uniform sampler2D u_normal;
uniform sampler2D u_depth;
uniform sampler2D u_light;
uniform sampler2D u_color;
uniform sampler2D u_blue_noise;

in mat2 v_deltaRotator;

out vec4 fragColor;

#ifdef SSAO_ENABLED
const int STEPS = clamp(SSAO_NUM_STEPS, 1, 10);
const int DIRECTIONS = clamp(SSAO_NUM_DIRECTIONS, 1, 10);
const float RADIUS = SSAO_RADIUS;
const float BIAS = SSAO_BIAS;
const float INTENSITY = SSAO_INTENSITY;
#endif

void main()
{
#ifdef SSAO_ENABLED
	#ifdef SSAO_USE_ATTENUATION
		const bool useAttenuation = true;
	#else
		const bool useAttenuation = false;
	#endif

	#ifdef SSAO_GLOW
		const bool glowOcclusion = true;
	#else
		const bool glowOcclusion = false;
	#endif

	// Modest performance saving by skipping the sky
	if (texture(u_depth, v_texcoord).r == 1.0) {
		fragColor = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		fragColor = calcSSAO(
			u_normal, u_depth, u_light, u_color, u_blue_noise,
			frx_normalModelMatrix(), frx_inverseProjectionMatrix(), v_deltaRotator, frxu_size, 
			v_texcoord, STEPS, DIRECTIONS, RADIUS, RADIUS, BIAS, INTENSITY,
			useAttenuation, glowOcclusion);
	}
#else
	fragColor = vec4(0.0, 0.0, 0.0, 1.0);
#endif
}
