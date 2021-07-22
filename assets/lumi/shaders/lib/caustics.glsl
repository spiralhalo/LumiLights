#include frex:shaders/api/world.glsl
#include frex:shaders/lib/noise/cellular2x2x2.glsl

/*******************************************************
 *  lumi:shaders/lib/caustics.glsl
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

#define CAUSTICS_SEA_LEVEL 62.0

float caustics(vec3 worldPos)
{
	// turns out, to get accurate coords, a global y-coordinate of water surface is required :S
	// Sea level is used for the time being..
	// TODO: might need to prevent division by 0 ?
	float animator = frx_renderSeconds() * 0.5;
	vec2 animatonator = frx_renderSeconds() * vec2(0.5, -1.0);
	vec3 pos = vec3(worldPos.xz + animatonator, animator);

	pos.xy += (CAUSTICS_SEA_LEVEL - worldPos.y) * frx_skyLightVector().xz / frx_skyLightVector().y;

	float e = cellular2x2x2(pos).x;

	e = smoothstep(-1.0, 1.0, e);

	return e;
}
