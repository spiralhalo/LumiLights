#include frex:shaders/api/world.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include frex:shaders/lib/noise/noise3d.glsl

/*******************************************************
 *  lumi:shaders/lib/puddle.glsl
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

void ww_puddle(in float lightY, in vec3 normal, in vec3 worldPos, inout vec3 microNormal, out float wet) {
	float rainExposure = smoothstep(0.88, 0.94, lightY) * frx_rainGradient() * smoothstep(0.7, 1.0, normal.y);

	if (rainExposure == 0.0) return;

	wet = rainExposure * (0.5 + 0.5 * snoise(0.1 * worldPos.xz));
	wet = 0.5 * rainExposure + 0.5 * smoothstep(0.1, 0.7, wet);

	vec3 mov = vec3(0.0, frx_renderSeconds() * 6.0, 0.0);
	vec2 splashJitter = vec2(snoise(worldPos.xyz * 4.0 + mov), snoise(worldPos.zyx * 4.0 + mov));

	microNormal.xz += splashJitter * wet * 0.05;
	microNormal = normalize(microNormal);
}

void puddle_processRoughness(inout float roughness, float wet) {
	roughness = min(roughness, 1.0 - 0.9 * wet);
}

void puddle_processColor(inout vec4 color, float wet) {
	color.rgb *= 1.0 - 0.3 * pow(wet, 5.) * (1.0 - color.rgb);
}
