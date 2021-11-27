#include lumi:shaders/common/atmosphere.glsl

/*******************************************************
 *  lumi:shaders/post/common/fog.glsl
 *******************************************************/

const float FOG_FAR				   = FOG_FAR_CHUNKS * 16.0;
const float FOG_DENSITY			   = FOG_DENSITY_RELATIVE / 20.0;
const float UNDERWATER_FOG_FAR	   = UNDERWATER_FOG_FAR_CHUNKS * 16.0;
const float UNDERWATER_FOG_DENSITY = UNDERWATER_FOG_DENSITY_RELATIVE / 20.0;

float fogFactor(float distToEye)
{
	float pFogDensity = frx_cameraInFluid == 1 ? UNDERWATER_FOG_DENSITY : FOG_DENSITY;
	float pFogFar     = frx_cameraInFluid == 1 ? UNDERWATER_FOG_FAR     : FOG_FAR;

	pFogFar = min(frx_viewDistance, pFogFar);

	if (frx_cameraInFluid == 0 && frx_worldHasSkylight == 1) {
		float inverseThickener = 1.0;

		inverseThickener -= 0.5 * inverseThickener * frx_rainGradient;
		inverseThickener -= 0.5 * inverseThickener * frx_thunderGradient;

		pFogFar *= inverseThickener;
		pFogDensity = mix(min(1.0, pFogDensity * 2.0), min(0.8, pFogDensity), inverseThickener);
	}

	float fogFactor = pFogDensity;

	if (frx_cameraInLava == 1) {
		pFogFar   = float(frx_effectFireResistance) * 2.0 + 0.5;
		fogFactor = 1.0;
	}

	float distFactor = min(1.0, distToEye / pFogFar);

	return clamp(fogFactor * distFactor, 0.0, 1.0);
}

vec4 fog(vec4 color, vec3 eyePos, vec3 toFrag)
{
	float distToEye = length(eyePos);
	float fogFactor = fogFactor(distToEye);

	// resolve horizon blend
	float skyBlend	  = frx_cameraInFluid == 1 ? 0.0 : min(distToEye, frx_viewDistance) / frx_viewDistance;
	vec3  toFragMod	  = toFrag;
		  toFragMod.y = mix(1.0, toFrag.y, pow(skyBlend, 0.3)); // ??
	vec3  fogColor	  = mix(atmos_hdrFogColorRadiance(toFrag), atmos_hdrSkyGradientRadiance(toFragMod), skyBlend);

	// resolve cave fog
	float aboveGround = frx_smoothedEyeBrightness.y;
	fogColor = mix(atmos_hdrCaveFogRadiance(), fogColor, aboveGround);

	vec4 blended = mix(color, vec4(fogColor, 1.0), fogFactor);

	return blended;
}
