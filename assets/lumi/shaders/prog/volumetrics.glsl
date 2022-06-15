#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/prog/shadow.glsl
#include lumi:shaders/prog/water.glsl

/*******************************************************
 *  lumi:shaders/prog/volumetrics.glsl
 *******************************************************/

#define RAYS_MIN_DIST 32

#ifndef VERTEX_SHADER
float celestialLightRays(sampler2DArrayShadow shadowBuffer, sampler2D natureTexture, float distToEye, vec3 toFrag, float lighty, float tileJitter, float depth, bool isUnderwater)
{
	if (frx_worldHasSkylight == 0) return 1.0;

	bool doUnderwaterRays = frx_cameraInWater == 1 && isUnderwater;

#if !defined(SHADOW_MAP_PRESENT) || !defined(VOLUMETRIC_FOG)
	// there is no point
	// if (!doUnderwaterRays) {
		return 1.0;
	// }
#endif

	float scatter = 1.0;

// #ifdef SHADOW_WORKAROUND
	// This is very awkward.. I hope shadows will get better soon
	float maximize = step(1.0, depth);
	maximize = max(maximize, float(isUnderwater));
	maximize = max(maximize, frx_smoothedEyeBrightness.y);
	scatter *= max(maximize, lightmapRemap(lighty));
	// shadow workaround is dead. long live shadow workaround
	// scatter *= max(maximize, l2_clampScale(0.03125, 0.0625, lighty));
// #endif

	if (scatter <= 0.0) {
		return 0.0;
	}

	const int MAX_STEPS = 6;
	// TODO: perhaps reintroduce deadRadius once caustic light shafts are added
	float sample = doUnderwaterRays ? 2.0 : max(1.0, distToEye) / float(MAX_STEPS);

	vec3 ray   = vec3(0.);
	vec3 march = toFrag * sample;

	ray += tileJitter * march;
	// sideways blurring
	// ray += (tileJitter * 2.0 - 1.0) * normalize(vec3(frx_skyLightVector.x, 0.0, frx_skyLightVector.z));

	float energy = 0.0;
	int steps = 0;

	while (steps < MAX_STEPS) {
		float e = 1.0;

		// DISABLED because need a different caustics function that respects light direction
		// and also because it was for caustic light shafts not fog (?) 
		// if (doUnderwaterRays) {
		// 	e *= pow(caustics(natureTexture, ray + frx_cameraPos, 1.0), 30.0);
		// }

		#ifdef SHADOW_MAP_PRESENT
		vec4 shadowRay = (frx_shadowViewMatrix * vec4(ray, 1.0));
		e *= simpleShadowFactor(shadowBuffer, shadowRay);
		#endif

		energy += e;
		ray += march;

		steps ++;
	}

	energy = (energy / float(MAX_STEPS)) * scatter;

	return energy;
}
#endif
