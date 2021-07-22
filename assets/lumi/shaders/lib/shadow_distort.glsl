#include frex:shaders/api/view.glsl

/*******************************************************
 *  lumi:shaders/lib/shadow_distort.glsl
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

// Adapted from Builderb0y's shadow tutorial
// Unused in favor of Canvas's own cascaded shadow map
vec4 distortedShadowPos(vec4 shadowVertex, int cascade)
{
	vec4 shadow_ndc = frx_shadowViewProjectionMatrix(cascade) * shadowVertex;
	vec4 center = frx_shadowViewProjectionMatrix(cascade) * vec4(0.0, 0.0, 0.0, 1.0);
	vec2 translator = vec2(0.0, 0.0) - center.xy;
	shadow_ndc.xy += translator;
	float distortion_rate = 0.01 + length(shadow_ndc.xy) * 0.99;
	shadow_ndc.xy /= distortion_rate;
	shadow_ndc.xy -= translator;
	shadow_ndc.xy = clamp(shadow_ndc.xy, -1.0, 1.0);
	return shadow_ndc;
}
