#include frex:shaders/lib/world.glsl

/*******************************************************
 *  lumi:shaders/lib/translucent_layering.glsl
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

 float calcLuminosity(vec3 normal, vec2 light, float alpha) {
	const float sAmbient = 0.5;
	const float bAmbient = 0.2;
	float fakeCelest = frx_worldFlag(FRX_WORLD_IS_MOONLIT) ? 0.1 : 1.0;
	float NdotL = mix(1.0, max(0.0, dot(normal, frx_skyLightVector())), alpha);

	light.y = light.y * (NdotL * fakeCelest * (1.0 - sAmbient) + sAmbient);
	light.x = light.x * (1.0 - bAmbient) + bAmbient;

	float luminosity2 = max(light.x * 0.5, light.y);

	return luminosity2 * luminosity2;
 }
