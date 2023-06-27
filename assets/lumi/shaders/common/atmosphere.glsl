#include frex:shaders/api/world.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/common/contrast.glsl
#include lumi:shaders/common/userconfig.glsl

/*******************************************************
 *  lumi:shaders/common/atmosphere.glsl
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

#define ATMOS_SEA_LEVEL		62.0
#define ATMOS_STRATOSPHERE	512.0 // directly proportional to render distance. this setup is best for 32 rd

#ifdef VERTEX_SHADER

	out vec3 atmosv_CelestialRadiance;
	out vec3 atmosv_SkyAmbientRadiance;
	out float atmosv_eyeAdaptation;

	#ifdef POST_SHADER
	out float atmosv_CaveFog;
	out vec3 atmosv_FogRadiance;
	out vec3 atmosv_WaterFogRadiance;
	out vec3 atmosv_SkyRadiance;
	out float atmosv_OWTwilightFactor;
	#endif

	void atmos_generateAtmosphereModel();

#else

	in vec3 atmosv_CelestialRadiance;
	in vec3 atmosv_SkyAmbientRadiance;
	in float atmosv_eyeAdaptation;

	#ifdef POST_SHADER
	in float atmosv_CaveFog;
	in vec3 atmosv_FogRadiance;
	in vec3 atmosv_WaterFogRadiance;
	in vec3 atmosv_SkyRadiance;
	in float atmosv_OWTwilightFactor;
	#endif

#endif

#ifdef POST_SHADER
#define calcHorizon(worldVec) pow(l2_clampScale(1.0, -l2_clampScale(ATMOS_SEA_LEVEL, ATMOS_STRATOSPHERE, frx_cameraPos.y), worldVec.y), 0.25)
#define waterHorizon(isUnderwater, skyHorizon) float(isUnderwater) * l2_clampScale(0.9, 1.0, skyHorizon) // kinda hacky
#endif



#ifdef VERTEX_SHADER

#define DEF_MOONLIGHT_COLOR	hdr_fromGamma(vec3(0.6 , 0.6 , 1.0 ))
#define DEF_SUNLIGHT_COLOR	hdr_fromGamma(vec3(1.0 , 0.9 , 0.8 ))
#define DEF_NOON_AMBIENT	vec3(1.0)

const vec3 MOONLIGHT_COLOR	   = DEF_MOONLIGHT_COLOR / lightLuminanceUnclamped(DEF_MOONLIGHT_COLOR);
const vec3 NOON_SUNLIGHT_COLOR = DEF_SUNLIGHT_COLOR / lightLuminanceUnclamped(DEF_SUNLIGHT_COLOR);
const vec3 SUNRISE_LIGHT_COLOR = hdr_fromGamma(vec3(0.9, 0.4, 0.1));

const vec3 DAY_SKY_COLOR   = DEF_DAY_SKY_COLOR;
const vec3 NIGHT_SKY_COLOR = DEF_NIGHT_SKY_COLOR;
const vec3 TWILIGHT_COLOR  = SUNRISE_LIGHT_COLOR;

const vec3 NOON_AMBIENT  = DEF_NOON_AMBIENT_STR * (DEF_NOON_AMBIENT / lightLuminanceUnclamped(DEF_NOON_AMBIENT));
const vec3 NIGHT_AMBIENT = DEF_NIGHT_AMBIENT_STR * MOONLIGHT_COLOR;

const vec3	CAVEFOG_C	  = DEF_LUMI_AZURE / lightLuminanceUnclamped(DEF_LUMI_AZURE);
const vec3	CAVEFOG_DEEPC = SUNRISE_LIGHT_COLOR / lightLuminanceUnclamped(SUNRISE_LIGHT_COLOR);
const float CAVEFOG_MAXY = 16.0;
const float CAVEFOG_MINY = 0.0;
const float CAVEFOG_STR	 = 0.7;


const int SRISC = 0;
const int SNONC = 1;
const int SMONC = 2;
const vec3[3] SUN_COLOR =  vec3[](SUNRISE_LIGHT_COLOR, NOON_SUNLIGHT_COLOR, MOONLIGHT_COLOR);
const float[3] TWG_FACTOR  = float[](1.0, 0.0, 0.0); // maps celest color to twilight factor
const int SUN_LEN = 8;
const int[SUN_LEN] SUN_COL_ID  = int[]  (SMONC, SRISC, SRISC, SNONC, SNONC, SRISC, SRISC, SMONC);
const float[SUN_LEN] SUN_TIMES = float[](-0.045, -0.035, -0.02,  0.02,  0.48,  0.52,  0.535,  0.545);

const int SKY_LEN = 4;
const float[SKY_LEN] SKY_NIGHT = float[]( 1.0 , 0.0 , 0.0 , 1.0);
const float[SKY_LEN] SKY_TIMES = float[](-0.05, 0.05, 0.45, 0.55);

void atmos_generateAtmosphereModel()
{
	float moonlightSize = 0.3 + 0.7 * frx_moonSize;
	float moonlightStrength = DEF_MOONLIGHT_STR * moonlightSize;


	vec3 sunColor;
	
	// Respect dimension setting. Not accurate but better than nothing
	float dimTime = fract(frx_skyAngleRadians / TAU + 0.25);
	float dayTime = mix(dimTime, frx_worldTime, frx_worldIsOverworld);
	float horizonTime = dayTime < 0.75 ? dayTime : (dayTime - 1.0); // [-0.25, 0.75)

	if (horizonTime <= SUN_TIMES[0]) {
		sunColor = SUN_COLOR[SUN_COL_ID[0]];

		#ifdef POST_SHADER
		atmosv_OWTwilightFactor = TWG_FACTOR[SUN_COL_ID[0]];
		#endif
	} else {
		int sunI = 1;
		while (horizonTime > SUN_TIMES[sunI] && sunI < SUN_LEN - 1) sunI++;
		float sunTransition = l2_clampScale(SUN_TIMES[sunI-1], SUN_TIMES[sunI], horizonTime);
		sunColor = mix(SUN_COLOR[SUN_COL_ID[sunI-1]], SUN_COLOR[SUN_COL_ID[sunI]], sunTransition);

		#ifdef POST_SHADER
		atmosv_OWTwilightFactor = mix(TWG_FACTOR[SUN_COL_ID[sunI-1]], TWG_FACTOR[SUN_COL_ID[sunI]], sunTransition);
		#endif
	}

	atmosv_OWTwilightFactor *= float(frx_worldHasSkylight);// * (1.0 - frx_worldIsMoonlit);

	sunColor.gb *= vec2(frx_skyLightTransitionFactor * frx_skyLightTransitionFactor);

	// if editing this, also edit nightFogLuminance for cave fog
	atmosv_CelestialRadiance = mix(sunColor * DEF_SUNLIGHT_STR, MOONLIGHT_COLOR * moonlightStrength, frx_worldIsMoonlit) * frx_skyLightTransitionFactor;


	float nightFactor = SKY_NIGHT[0];

	if (horizonTime > SKY_TIMES[0]) {
		int skyI = 1;
		while (horizonTime > SKY_TIMES[skyI] && skyI < SKY_LEN - 1) skyI++;
		float skyTransition = l2_clampScale(SKY_TIMES[skyI-1], SKY_TIMES[skyI], horizonTime);
		nightFactor = mix(SKY_NIGHT[skyI-1], SKY_NIGHT[skyI], skyTransition);
	}

	atmosv_SkyAmbientRadiance = mix(NOON_AMBIENT, NIGHT_AMBIENT * moonlightSize, nightFactor) * (frx_worldHasSkylight == 1 ? 1.0 : 0.0);

	#ifdef POST_SHADER
	// if editing this, also edit nightFogLuminance for cave fog
	atmosv_SkyRadiance = mix(DAY_SKY_COLOR, NIGHT_SKY_COLOR, nightFactor) * DEF_SKY_STR;
	float skyLuminance = lightLuminanceUnclamped(atmosv_SkyRadiance);
	atmosv_SkyRadiance = mix(atmosv_SkyRadiance, vec3(skyLuminance), atmosv_OWTwilightFactor);
	#endif

	#ifdef POST_SHADER
	/** FOG **/
	vec3 twilightRadiance = TWILIGHT_COLOR * 2.0;
	twilightRadiance.gb *= vec2(max(frx_skyLightTransitionFactor, 0.3), frx_skyLightTransitionFactor * frx_skyLightTransitionFactor);

	// vanilla clear color is unreliable, we want to control its brightness
	vec3 clearRadiance = hdr_fromGamma(frx_vanillaClearColor);

	bool customOWFog	 = frx_worldIsOverworld == 1 && max(frx_cameraInSnow, frx_cameraInLava) < 1;
	bool customEndFog	 = frx_worldIsEnd == 1 && max(frx_cameraInSnow, frx_cameraInLava) < 1;
	bool customNetherFog = frx_worldIsNether == 1 && max(frx_cameraInSnow, frx_cameraInLava) < 1;

	if (customOWFog) {
		atmosv_FogRadiance = (atmosv_SkyRadiance / skyLuminance) * max(skyLuminance, mix(lightLuminanceUnclamped(atmosv_CelestialRadiance * 0.4), 0.1 - frx_smoothedRainGradient * 0.05, nightFactor));
		atmosv_FogRadiance = mix(atmosv_FogRadiance, vec3(lightLuminance(atmosv_FogRadiance)), 0.25);
		atmosv_FogRadiance = mix(atmosv_FogRadiance, twilightRadiance, atmosv_OWTwilightFactor);
	} else if (customEndFog) {
		atmosv_FogRadiance = mix(clearRadiance, hdr_fromGamma(vec3(1.0, 0.7, 1.0)), float(frx_cameraInFluid)) * 0.1;
	} else if (customNetherFog) {
		atmosv_FogRadiance = clearRadiance; // controllable overall brightness
	} else {
		atmosv_FogRadiance = hdr_fromGamma(frx_vanillaClearColor);
	}

	atmosv_WaterFogRadiance = clearRadiance;
	atmosv_WaterFogRadiance.g = max(atmosv_WaterFogRadiance.g, atmosv_WaterFogRadiance.b * 0.15);

	// prevent custom overworld sky reflection in non-overworld dimension or when the sky mode is not Lumi
	bool customOWSkyAndFallback = frx_worldIsOverworld == 1;

	if (frx_worldIsNether == 1) {
		atmosv_SkyRadiance = atmosv_FogRadiance;
	}

	#endif



	/** RAIN **/
	float rainBrightness = 1.0 - 0.5 * frx_thunderGradient * (1.0 - frx_worldIsMoonlit);

	vec3 grayCelestial  = vec3(lightLuminance(atmosv_CelestialRadiance));
	vec3 graySkyAmbient = vec3(lightLuminance(atmosv_SkyAmbientRadiance));
	#ifdef POST_SHADER
	vec3 graySky = vec3(lightLuminance(atmosv_SkyRadiance));
	vec3 grayFog = vec3(lightLuminance(atmosv_FogRadiance));
	#endif

	float toGray = frx_smoothedRainGradient * 0.8 + frx_thunderGradient * 0.2;

	atmosv_CelestialRadiance  = mix(atmosv_CelestialRadiance, grayCelestial, toGray) * rainBrightness; // only used for cloud shading during rain
	atmosv_SkyAmbientRadiance = mix(atmosv_SkyAmbientRadiance, graySkyAmbient, toGray) * rainBrightness;

	#ifdef POST_SHADER
	atmosv_SkyRadiance = mix(atmosv_SkyRadiance, graySky, toGray) * rainBrightness;

	if (customOWFog) {
		atmosv_FogRadiance = mix(atmosv_FogRadiance, grayFog, toGray) * rainBrightness;
		// twilightRadiance = mix(twilightRadiance, graySky, toGray) * rainBrightness;
	}
	#endif
	/**********/


	/** EYE ADAPTATION **/
	atmosv_eyeAdaptation = frx_smoothedEyeBrightness.y * lightLuminance(atmosv_CelestialRadiance) * (1. - frx_rainGradient);

	//  NB: mustn't affect cave fog
	if (frx_worldHasSkylight == 1) {
		float skyAdaptor = 1.0 / (0.33 + 0.67 * max(frx_smoothedEyeBrightness.y, max(frx_rainGradient, 1.0 - lightLuminance(atmosv_CelestialRadiance))));
		atmosv_SkyRadiance *= skyAdaptor;
		atmosv_CelestialRadiance *= skyAdaptor;
		atmosv_SkyAmbientRadiance *= skyAdaptor;
		atmosv_FogRadiance *= skyAdaptor;
	}

	/** CAVE FOG **/
	atmosv_CaveFog = 0.0;

	if (frx_worldIsOverworld == 1 && frx_cameraInFluid == 0) {
		vec3 caveFogRadiance = mix(CAVEFOG_C, CAVEFOG_DEEPC, l2_clampScale(CAVEFOG_MAXY, CAVEFOG_MINY, frx_cameraPos.y));

		// night fog luminance (always max moon phase)
		float nightFogLuminance = lightLuminance(MOONLIGHT_COLOR * DEF_MOONLIGHT_RAW_STR * 0.4);

		// cave fog strength is adjusted to dimmest night fog strength so it doesn't make the outdoors look jarring or misleading
		caveFogRadiance *= nightFogLuminance;

		float invEyeY = 1.0 - frx_smoothedEyeBrightness.y;
		atmosv_CaveFog = invEyeY * invEyeY;
		atmosv_FogRadiance = mix(atmosv_FogRadiance, caveFogRadiance, atmosv_CaveFog);
	}
	/**********/
}
#endif
