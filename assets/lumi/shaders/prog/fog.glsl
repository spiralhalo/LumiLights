#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/prog/volumetrics.glsl

/*******************************************************
 *  lumi:shaders/prog/fog.glsl
 *******************************************************/

#ifdef VERTEX_SHADER
out float v_blindness;

void blindnessSetup() {
	// capture vanilla transition which happens when blindness happens/stops naturally (without milk, command, etc) 
	v_blindness = l2_clampScale(1.0, 0.0, frx_luminance(frx_vanillaClearColor)) * float(max(frx_effectBlindness, frx_effectDarkness));
}
#else
in float v_blindness;

vec4 blindnessFog(vec4 color, float distToEye)
{
	// unlike normal fog, this also applies to the sky and doesn't mess with atmospheric fog
	float blindFactor = min(1.0, distToEye / mix(16.0, 2.0, float(frx_effectBlindness))) * v_blindness;
	vec4 blended = mix(color, vec4(0.0, 0.0, 0.0, 1.0), blindFactor);
	return blended;
}

const float VOLUMETRIC_RESIDUAL	   = 0.1;
const float HEIGHT_RESIDUAL		   = 0.05;
const float FOG_ABSOLUTE_LIMIT	   = 0.7;
const float FOG_FAR				   = FOG_FAR_CHUNKS * 16.0;
const float FOG_DENSITY			   = clamp(FOG_DENSITY_F, 0.01, 10.0);
const float UNDERWATER_FOG_FAR	   = UNDERWATER_FOG_FAR_CHUNKS * 16.0;

// a.k.a ground visibility
float invThickener(bool isUnderwater) {
	if (isUnderwater || frx_worldHasSkylight != 1) {
		return 1.0;
	}

	float invThickener = 1.0;
	// stronger night fog because it's darker
	float night = max(frx_worldIsMoonlit, 1.0 - frx_skyLightTransitionFactor);
	invThickener *= 1.0 - 0.6 * max(night, frx_smoothedRainGradient);
	invThickener *= 1.0 - 0.5 * frx_thunderGradient;
	invThickener = mix(1.0, invThickener, frx_smoothedEyeBrightness.y);

	return invThickener;
}

vec2 fullFogFactor(float distToEye, vec3 toFrag, bool isUnderwater, float invThickener)
{
	// only when absolutely underwater
	bool submerged = isUnderwater && frx_cameraInFluid == 1;

	float pFogDensity = submerged ? (FOG_DENSITY * 2.0) : FOG_DENSITY;
	float pFogFar     = submerged ? UNDERWATER_FOG_FAR  : FOG_FAR;

	if (!isUnderwater && frx_worldHasSkylight == 1) {
		pFogFar *= invThickener;
		pFogDensity = mix(max(1.0, pFogDensity * 2.0), pFogDensity, invThickener);
	}

	// resolve lava and snow
	pFogFar = mix(pFogFar, max(0, frx_effectFireResistance - frx_playerIsFreezing) * 4.0 + 1.0, max(frx_cameraInSnow, frx_cameraInLava));
	pFogDensity = max(pFogDensity, max(frx_cameraInSnow, frx_cameraInLava));

	float distFactor = min(1.0, distToEye / pFogFar);
	distFactor = l2_softenUp(distFactor, pFogDensity * 2.0);

	float fogFactor = clamp(distFactor, 0.0, 1.0);

	// resolve height fog
	// more accurate in volumetrics, but it's cheaper and simpler this way
	float isSky  = 0.0;
	float invSky = 0.0;

	if (!isUnderwater && (frx_cameraInSnow + frx_cameraInLava) < 1) {
		float eyeY = toFrag.y * distToEye;
		// for terrain
		float yFactor = l2_clampScale(-128.0, 164.0, eyeY);
		yFactor = HEIGHT_RESIDUAL + pow(1.0 - yFactor, 3.0) * (1.0 - HEIGHT_RESIDUAL);

		// for sky, has curve... 1.0 is equivalent to y=1024
		float rdMult   = min(1.0, frx_viewDistance / 512.0);
		float cameraAt = mix(0.0, -0.75, l2_clampScale(64.0 + 256.0 * rdMult, 256.0 + 256.0 * rdMult, frx_cameraPos.y));
		isSky   = step(frx_viewDistance * 2.0, distToEye);
		invSky  = pow(l2_clampScale(0.625 + cameraAt, -0.125 + cameraAt, toFrag.y), 3.0);
		yFactor = mix(yFactor, invSky, isSky);

		fogFactor *= yFactor;
	}

	// resolve fog limit
	float fogLimit = FOG_ABSOLUTE_LIMIT + (1.0 - FOG_ABSOLUTE_LIMIT) * max(frx_cameraInSnow, frx_cameraInLava);
	fogFactor *= fogLimit;

	// resolve edge blend
	float blendStart = max(0.0, frx_viewDistance - 16.0);
	float blendEnd	 = max(1.0, frx_viewDistance - 8.0);
	float edgeBlend	 = frx_cameraInFluid == 1 ? 0.0 : l2_clampScale(blendStart, blendEnd, distToEye);
	edgeBlend *= 1.0 - isSky;
	edgeBlend *= frx_worldIsOverworld; //it wont behave without custom sky idk
	fogFactor += (1.0 - fogFactor) * edgeBlend;

	return vec2(fogFactor, mix((1.0 - invSky * fogLimit) * edgeBlend, pow(distFactor, 10.0), frx_worldIsNether));
}

float fogFactor(float distToEye, vec3 toFrag, bool isUnderwater) {
	return fullFogFactor(distToEye, toFrag, isUnderwater, invThickener(isUnderwater)).x;
}

vec4 fog(vec4 color, float distToEye, vec3 toFrag, bool isUnderwater, float volumetric)
{
	float invThickener = invThickener(isUnderwater);
	vec2 fullFactor = fullFogFactor(distToEye, toFrag, isUnderwater, invThickener);
	float fogFactor = fullFactor.x;

	bool submerged = isUnderwater && frx_cameraInFluid == 1;
	vec3 OWFog = atmos_OWFogRadiance(toFrag);
	vec3 fogColor = submerged ? atmosv_ClearRadiance : OWFog;//mix(OWFog, vec3(lightLuminanceUnclamped(OWFog)), fullFactor.z * atmosv_OWTwilightFactor);

	// resolve sky blend color
	fogColor = mix(fogColor, atmosv_SkyRadiance, fullFactor.y);

	// resolve cave fog
	float cave = 0.0;
	if (frx_cameraInFluid == 0 && frx_worldHasSkylight == 1) {
		float invEyeY = 1.0 - frx_smoothedEyeBrightness.y;
		cave = invEyeY * invEyeY;
		fogColor = mix(fogColor, atmosv_CaveFogRadiance, cave);
	}

	// resolve volumetric
	float residual = VOLUMETRIC_RESIDUAL + frx_cameraInWater * VOLUMETRIC_RESIDUAL;
	residual = max(residual, frx_smoothedRainGradient);
	residual = max(residual, max(frx_cameraInSnow, frx_cameraInLava));
	residual = max(residual, cave);
	residual = max(residual, l2_clampScale(0.5, 0.1, frx_skyLightTransitionFactor));
	residual = max(residual, l2_softenUp(fogFactor) * l2_clampScale(0.4, -0.4, dot(toFrag, frx_skyLightVector))); // reduce batman sign effect
	volumetric  += max(0.0, 1.0 - volumetric) * residual;
	float excess = max(0.0, volumetric - 1.0);
	fogFactor   *= min(1.0, volumetric);

	vec4 blended = mix(color, vec4(fogColor, 1.0), fogFactor);
	blended.rgb += fogColor * excess * lightLuminance(atmosv_CelestialRadiance * 0.5) * 0.5;

	return blended;
}

vec4 fog(vec4 color, float distToEye, vec3 toFrag, bool isUnderwater) {
	return fog(color, distToEye, toFrag, isUnderwater, 1.0);
}

vec4 volumetricFog(sampler2DArrayShadow shadowBuffer, sampler2D natureTexture, vec4 color, float distToEye, vec3 toFrag, float yLightmap, float tileJitter, float depth, bool isUnderwater) {
	return fog(color, distToEye, toFrag, isUnderwater, celestialLightRays(shadowBuffer, natureTexture, distToEye, toFrag, yLightmap, tileJitter, depth, isUnderwater));
}
#endif
