#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/userconfig.glsl

/*******************************************************
 *  lumi:shaders/post/common/fog.glsl
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

/* DEVNOTE: on high skyscrapers, high fog look good
 * on low forests however, the high fog looks atrocious.
 * the ideal solution would be a fog that is "highest block-conscious"
 * but how is that possible? Make sky bloom cancel out the fog, perhaps?
 *
 * There is also the idea of making the fog depend on where
 * you look vertically, but that would be NAUSEATINGLY BAD.
 */

#define SEA_LEVEL 62.0

// #define FOG_NOISE_SCALE 0.125
// #define FOG_NOISE_SPEED 0.25
// #define FOG_NOISE_HEIGHT 4.0

const float FOG_TOP = SEA_LEVEL + 64.0;
const float FOG_TOP_THICK = SEA_LEVEL + 128.0;
const float FOG_FAR = FOG_FAR_CHUNKS * 16.0;
const float FOG_DENSITY = FOG_DENSITY_RELATIVE / 20.0;
const float UNDERWATER_FOG_FAR = UNDERWATER_FOG_FAR_CHUNKS * 16.0;
const float UNDERWATER_FOG_DENSITY = UNDERWATER_FOG_DENSITY_RELATIVE / 20.0;

vec4 fog(float skyLight, float ec, float vblindness, vec4 a, vec3 modelPos, inout float bloom)
{
	float pFogDensity = frx_viewFlag(FRX_CAMERA_IN_FLUID) ? UNDERWATER_FOG_DENSITY : FOG_DENSITY;
	float pFogFar	 = frx_viewFlag(FRX_CAMERA_IN_FLUID) ? UNDERWATER_FOG_FAR	 : FOG_FAR;

	pFogFar = min(frx_viewDistance(), pFogFar); // clamp to render distance

	// float fog_noise = snoise(worldPos.xz * FOG_NOISE_SCALE + frx_renderSeconds() * FOG_NOISE_SPEED) * FOG_NOISE_HEIGHT;

	if (!frx_viewFlag(FRX_CAMERA_IN_FLUID) && frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT)) {
		float zigZagTime = abs(frx_worldTime()-0.5);
		float timeFactor = (l2_clampScale(0.45, 0.5, zigZagTime) + l2_clampScale(0.05, 0.0, zigZagTime));
		float inverseThickener = 1.0;

		inverseThickener -= 0.25 * timeFactor;
		inverseThickener -= 0.5 * inverseThickener * frx_rainGradient();
		inverseThickener -= 0.5 * inverseThickener * frx_thunderGradient();

		pFogFar *= inverseThickener;
		pFogDensity = mix(min(1.0, pFogDensity * 2.0), min(0.8, pFogDensity), inverseThickener);
	}


	float fogFactor = pFogDensity;

	// additive fog when it's not blindness or fluid related
	bool useAdditive = !frx_viewFlag(FRX_CAMERA_IN_WATER);

	if (frx_playerHasEffect(FRX_EFFECT_BLINDNESS)) {
		useAdditive = false;
		pFogFar = mix(pFogFar, 3.0, vblindness);
		fogFactor = mix(fogFactor, 1.0, vblindness);
	}

	if (frx_viewFlag(FRX_CAMERA_IN_LAVA)) {
		useAdditive = false;
		pFogFar = frx_playerHasEffect(FRX_EFFECT_FIRE_RESISTANCE) ? 2.5 : 0.5;
		fogFactor = 1.0;
	}

	float distToCamera = length(modelPos);
	float pfCave = 1.0;

	float distFactor;

	distFactor = min(1.0, distToCamera / pFogFar);
	distFactor *= distFactor;

	fogFactor = clamp(fogFactor * distFactor, 0.0, 1.0);
	fogFactor *= (EXPOSURE_CANCELLATION, 1.0, ec);

	vec3 worldVec = normalize(modelPos);
	vec4 fogColor = vec4(atmos_hdrFogColorRadiance(worldVec), 1.0);

	vec4 blended;

	if (useAdditive) {
		float darkenFactor = 1.0;

		if (frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) && !frx_viewFlag(FRX_CAMERA_IN_FLUID)) {
			darkenFactor = 1.0 - abs(worldVec.y) * 0.7;
		}

		fogFactor *= darkenFactor;

		float darkness = frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) ? l2_clampScale(0.1, 0.0, skyLight) : 0.0;

		darkness *= smoothstep(0.5, 0.25, ec);

		fogColor.rgb = mix(fogColor.rgb, atmos_hdrCaveFogRadiance(), darkness);

		blended = vec4(a.rgb + fogColor.rgb * fogFactor, a.a + max(0.0, 1.0 - a.a) * fogFactor);
	} else {
		blended = mix(a, fogColor, fogFactor);
	}

	bloom = mix(bloom, 0.0, fogFactor);

	return blended;
}
