#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/prog/volumetrics.glsl

/*******************************************************
 *  lumi:shaders/prog/fog.glsl
 *******************************************************/

#ifdef VERTEX_SHADER
out float v_blindness;
out float v_visibility;

void fogVarsSetup() {
	// capture vanilla transition which happens when blindness happens/stops naturally (without milk, command, etc) 
	v_blindness = l2_clampScale(1.0, 0.0, frx_luminance(frx_vanillaClearColor)) * float(max(frx_effectBlindness, frx_effectDarkness));

	// ground visibility
	float invThickener = 1.0;
	// stronger night fog because it's darker
	float night = max(frx_worldIsMoonlit, 1.0 - frx_skyLightTransitionFactor);
	invThickener *= 1.0 - 0.6 * max(night, frx_smoothedRainGradient);
	invThickener *= 1.0 - 0.5 * frx_thunderGradient;
	invThickener = mix(1.0, invThickener, frx_smoothedEyeBrightness.y);
	v_visibility = max(invThickener, frx_worldHasSkylight);
}
#else
in float v_blindness;
in float v_visibility;

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

float getVisibility(bool isUnderwater)
{
	return isUnderwater ? 1.0 : v_visibility;
}

float edgeBlendFactor(float distToEye)
{
	float blendStart = max(0.0, frx_viewDistance - 16.0);
	float blendEnd	 = max(1.0, frx_viewDistance - 8.0);

	return frx_cameraInFluid == 1 ? 0.0 : l2_clampScale(blendStart, blendEnd, distToEye);
	// edgeBlend *= frx_worldIsOverworld; //it wont behave without custom sky idk
}

float fullFogFactor(float distToEye, vec3 toFrag, bool isUnderwater, float visibility)
{
	// only when absolutely underwater
	bool submerged = isUnderwater && frx_cameraInFluid == 1;

	float pFogDensity = submerged ? (FOG_DENSITY * 2.0) : FOG_DENSITY;
	float pFogFar     = submerged ? UNDERWATER_FOG_FAR  : FOG_FAR;

	if (!isUnderwater && frx_worldHasSkylight == 1) {
		pFogFar *= visibility;
		pFogDensity = mix(max(1.0, pFogDensity * 2.0), pFogDensity, visibility);
	}

	// resolve lava and snow
	pFogFar = mix(pFogFar, max(0, frx_effectFireResistance - frx_playerIsFreezing) * 4.0 + 1.0, max(frx_cameraInSnow, frx_cameraInLava));
	pFogDensity = max(pFogDensity, max(frx_cameraInSnow, frx_cameraInLava));

	float distFactor = min(1.0, distToEye / pFogFar);
	distFactor = l2_softenUp(distFactor, pFogDensity * 2.0);

	float fogFactor = clamp(distFactor, 0.0, 1.0);

	// resolve height fog
	// more accurate in volumetrics, but it's cheaper and simpler this way
	if (!isUnderwater && (frx_cameraInSnow + frx_cameraInLava) < 1) {
		float eyeY = toFrag.y * distToEye;
		float yFactor = l2_clampScale(-128.0, 164.0, eyeY);

		yFactor = HEIGHT_RESIDUAL + pow(1.0 - yFactor, 3.0) * (1.0 - HEIGHT_RESIDUAL);

		fogFactor *= yFactor;
	}

	// resolve fog limit
	float fogLimit = FOG_ABSOLUTE_LIMIT + (1.0 - FOG_ABSOLUTE_LIMIT) * max(frx_cameraInSnow, frx_cameraInLava);
	fogFactor *= fogLimit;

	return fogFactor;
}

float fogFactor(float distToEye, vec3 toFrag, bool isUnderwater) {
	return fullFogFactor(distToEye, toFrag, isUnderwater, getVisibility(isUnderwater));
}

vec3 fogColor(bool submerged, vec3 toFrag) {
	//NB: only works if sun always rise from dead East instead of NE/SE etc.
	float twGray = l2_clampScale(1.0, -1.0, toFrag.x * sign(frx_skyLightVector.x) * (1.0 - frx_worldIsMoonlit * 2.0));
	twGray = l2_softenUp(twGray) * atmosv_OWTwilightFactor;

	vec3 result = submerged ? atmosv_ClearRadiance : atmosv_FogRadiance;
	result = mix(result, atmosv_SkyRadiance, twGray);
	return result;
}

vec4 fog(vec4 color, float distToEye, vec3 toFrag, bool isUnderwater, float volumetric)
{
	float visibility = getVisibility(isUnderwater);
	float fogFactor = fullFogFactor(distToEye, toFrag, isUnderwater, visibility);

	vec3 fogColor = fogColor(isUnderwater && frx_cameraInFluid == 1, toFrag);

	// resolve volumetric
	float residual = VOLUMETRIC_RESIDUAL + frx_cameraInWater * VOLUMETRIC_RESIDUAL;
	residual = max(residual, frx_smoothedRainGradient);
	residual = max(residual, max(frx_cameraInSnow, frx_cameraInLava));
	residual = max(residual, atmosv_CaveFog);
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
