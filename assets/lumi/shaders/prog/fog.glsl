#include lumi:shaders/common/atmosphere.glsl

/*******************************************************
 *  lumi:shaders/post/prog/fog.glsl
 *******************************************************/

#ifdef VERTEX_SHADER
out float v_blindness;

void blindnessSetup() {
	// capture vanilla transition which happens when blindness happens/stops naturally (without milk, command, etc) 
	v_blindness = l2_clampScale(1.0, 0.0, frx_luminance(frx_vanillaClearColor)) * float(frx_effectBlindness);
}
#else
in float v_blindness;

vec4 blindnessFog(vec4 color, float distToEye)
{
	// unlike normal fog, this also applies to the sky and doesn't mess with atmospheric fog
	float blindFactor = min(1.0, distToEye / 2.0) * v_blindness;
	vec4 blended = mix(color, vec4(0.0, 0.0, 0.0, 1.0), blindFactor);
	return blended;
}

const float FOG_FAR				   = FOG_FAR_CHUNKS * 16.0;
const float FOG_DENSITY			   = FOG_DENSITY_RELATIVE / 20.0;
const float UNDERWATER_FOG_FAR	   = UNDERWATER_FOG_FAR_CHUNKS * 16.0;
const float UNDERWATER_FOG_DENSITY = UNDERWATER_FOG_DENSITY_RELATIVE / 20.0;

float fogFactor(float distToEye, bool isUnderwater)
{
	// only when absolutely underwater
	bool submerged = isUnderwater && frx_cameraInFluid == 1;

	float pFogDensity = submerged ? UNDERWATER_FOG_DENSITY : FOG_DENSITY;
	float pFogFar     = submerged ? UNDERWATER_FOG_FAR     : FOG_FAR;
	float invEyeY	  = (1.0 - frx_smoothedEyeBrightness.y);

	pFogFar = min(frx_viewDistance, pFogFar);

	if (!isUnderwater && frx_worldHasSkylight == 1) {
		float inverseThickener = 1.0;

		inverseThickener -= 0.5 * inverseThickener * frx_rainGradient;
		inverseThickener -= 0.5 * inverseThickener * frx_thunderGradient;
		inverseThickener = mix(inverseThickener, 1.0, invEyeY * invEyeY);

		pFogFar *= inverseThickener;
		pFogDensity = mix(min(1.0, pFogDensity * 2.0), min(0.8, pFogDensity), inverseThickener);
	}

	float fogFactor = pFogDensity;

	// resolve lava
	pFogFar = mix(pFogFar, float(frx_effectFireResistance) * 2.0 + 0.5, float(frx_cameraInLava));
	fogFactor = max(fogFactor, float(frx_cameraInLava));

	float distFactor = min(1.0, distToEye / pFogFar);

	return clamp(fogFactor * distFactor, 0.0, 1.0);
}

vec4 fog(vec4 color, float distToEye, vec3 toFrag, bool isUnderwater)
{
	float fogFactor = fogFactor(distToEye, isUnderwater);

	// resolve horizon blend
	float skyBlend	  = frx_cameraInFluid == 1 ? 0.0 : min(distToEye, frx_viewDistance) / frx_viewDistance;
	vec3  toFragMod	  = toFrag;
		  toFragMod.y = mix(1.0, toFrag.y, pow(skyBlend, 0.3)); // ??
	vec3  fogColor	  = mix(isUnderwater ? atmosv_ClearRadiance : atmos_OWFogRadiance(toFrag), atmos_SkyGradientRadiance(toFragMod), skyBlend);

	// resolve cave fog
	if (!isUnderwater || frx_cameraInFluid == 0) {
		float invEyeY = (1.0 - frx_smoothedEyeBrightness.y);
		fogColor = mix(fogColor, atmosv_CaveFogRadiance, invEyeY * invEyeY);
	}

	vec4 blended = mix(color, vec4(fogColor, 1.0), fogFactor);

	return blended;
}
#endif
