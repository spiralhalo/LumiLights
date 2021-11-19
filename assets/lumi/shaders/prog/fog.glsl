#include lumi:shaders/common/atmosphere.glsl

/*******************************************************
 *  lumi:shaders/post/common/fog.glsl
 *******************************************************/

const float FOG_FAR				   = FOG_FAR_CHUNKS * 16.0;
const float FOG_DENSITY			   = FOG_DENSITY_RELATIVE / 20.0;
const float UNDERWATER_FOG_FAR	   = UNDERWATER_FOG_FAR_CHUNKS * 16.0;
const float UNDERWATER_FOG_DENSITY = UNDERWATER_FOG_DENSITY_RELATIVE / 20.0;

vec4 fog(vec4 color, vec3 eyePos, float lighty)
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

	float distToCamera = length(eyePos);
	float distFactor   = min(1.0, distToCamera / pFogFar);

	fogFactor = clamp(fogFactor * distFactor, 0.0, 1.0);

	float aboveGround	 = l2_clampScale(0.0, 0.2, max(lighty, frx_smoothedEyeBrightness.y));
	vec3  worldVec		 = normalize(eyePos);
	vec3  fogColor		 = mix(atmos_hdrCaveFogRadiance(), atmos_hdrFogColorRadiance(worldVec), aboveGround);
	float smoothSkyBlend = frx_cameraInFluid == 1 ? 0.0 : min(distToCamera, frx_viewDistance) / frx_viewDistance * aboveGround;
	vec3  worldVecMod	 = worldVec;
		  worldVecMod.y	 = mix(1.0, worldVecMod.y, pow(smoothSkyBlend, 0.3));
		  fogColor		 = mix(fogColor, atmos_hdrSkyGradientRadiance(worldVecMod), smoothSkyBlend);

	vec4 blended;

	blended = mix(color, vec4(fogColor, 1.0), fogFactor);

	return blended;
}
