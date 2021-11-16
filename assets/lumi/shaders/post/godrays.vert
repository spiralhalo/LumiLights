#include lumi:shaders/post/common/header.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/godrays.vert
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

out float v_godray_intensity;
out vec2 v_invSize;
out vec2 v_skylightpos;

void main()
{
	basicFrameSetup();
	v_invSize = 1. / frxu_size;

	float weatherFactor    = frx_cameraInFluid == 1 ? 1.0 : (1.0 - frx_rainGradient);
	float dimensionFactor  = frx_worldHasSkylight == 1 ? 1.0 : 0.0;
	float blindnessFactor  = 1.0 - frx_effectBlindness;
	float notInVoidFactor  = l2_clampScale(-1.0, 0.0, frx_cameraPos.y);
	float notInFluidFactor = frx_cameraInFluid == 1 ? (frx_cameraInWater == 1 ? 1.0 : 0.0) : 1.0;
	float transitionFactor = smoothstep(0.25, 0.5, frx_skyLightTransitionFactor); // work in progress?

	v_godray_intensity = 1.0
						 * weatherFactor
						 * dimensionFactor
						 * blindnessFactor
						 * notInVoidFactor
						 * notInFluidFactor
						 * transitionFactor
						 * USER_GODRAYS_INTENSITY;

#if SKY_MODE == SKY_MODE_LUMI
	vec3 skyLightVector = frx_skyLightVector;
#else
	// Remove zenith angle tilt until Canvas implements it on vanilla celestial object
	vec3 skyLightVector = normalize(vec3(frx_skyLightVector.xy, 0.0));
#endif

	vec4 skylight_clip = frx_projectionMatrix * vec4(frx_normalModelMatrix * skyLightVector * 1000, 1.0);

	v_skylightpos = (skylight_clip.xy / skylight_clip.w) * 0.5 + 0.5;
}
