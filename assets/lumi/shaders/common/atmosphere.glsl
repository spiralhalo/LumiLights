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

	#ifdef POST_SHADER
	out vec3 atmosv_CaveFogRadiance;
	out vec3 atmosv_CloudRadiance;
	out vec3 atmosv_FogRadiance;
	out vec3 atmosv_ClearRadiance;
	out vec3 atmosv_SkyRadiance;
	out float atmosv_OWTwilightFactor;
	out vec3 atmosv_OWTwilightRadiance;
	#endif

	void atmos_generateAtmosphereModel();

#else

	in vec3 atmosv_CelestialRadiance;
	in vec3 atmosv_SkyAmbientRadiance;

	#ifdef POST_SHADER
	in vec3 atmosv_CaveFogRadiance;
	in vec3 atmosv_CloudRadiance;
	in vec3 atmosv_FogRadiance;
	in vec3 atmosv_ClearRadiance;
	in vec3 atmosv_SkyRadiance;
	in float atmosv_OWTwilightFactor;
	in vec3 atmosv_OWTwilightRadiance;
	#endif

#endif

float lightLuminance(vec3 radiance) {
	return min(1.0, dot(radiance, vec3(0.2126, 0.7152, 0.0722)));
}

float lightLuminanceUnclamped(vec3 radiance) {
	return dot(radiance, vec3(0.2126, 0.7152, 0.0722));
}

#ifdef POST_SHADER
#define calcHorizon(worldVec) pow(l2_clampScale(1.0, -l2_clampScale(ATMOS_SEA_LEVEL, ATMOS_STRATOSPHERE, frx_cameraPos.y), worldVec.y), 0.25)
#define waterHorizon(isUnderwater, skyHorizon) float(isUnderwater) * l2_clampScale(0.9, 1.0, skyHorizon) // kinda hacky

float twilightCalc(vec3 world_toSky, float skyHorizon) {
	//NB: only works if sun always rise from dead East instead of NE/SE etc.
	float isTwilight = l2_clampScale(-1.0, 1.0, world_toSky.x * sign(frx_skyLightVector.x) * (1.0 - frx_worldIsMoonlit * 2.0));
	float result = isTwilight * pow(skyHorizon, 5.0) * atmosv_OWTwilightFactor;

	return frx_smootherstep(0., 1., result);
}

#define twilightCalc2(world_toSky) twilightCalc(world_toSky, calcHorizon(world_toSky))

vec3 atmos_OWFogRadiance(vec3 world_toSky)
{
	return mix(atmosv_FogRadiance, atmosv_OWTwilightRadiance, 0.4 * twilightCalc2(world_toSky) * atmosv_OWTwilightFactor);
}

vec3 atmos_HorizonColor(vec3 world_toSky, float skyHorizon) {
	float brighteningCancel = min(1., atmosv_OWTwilightFactor * .6 + frx_rainGradient * .6);
	float brightenFactor = pow(skyHorizon, 20.) * (1. - brighteningCancel);
	float horizonBrightening = mix(1., HORIZON_MULT, brightenFactor);

	return mix(atmosv_SkyRadiance * horizonBrightening, atmosv_OWTwilightRadiance, twilightCalc(world_toSky, skyHorizon));
}

// Not for OW only, also used in sky reflection fallback and cloud fade
vec3 atmos_SkyGradientRadiance(vec3 world_toSky)
{
	// This is for overworld but maybe any skylight dimension would work better than no gradient (TODO: need example)
	if (frx_worldHasSkylight == 0) return atmosv_SkyRadiance;

	float skyHorizon = calcHorizon(world_toSky);
	vec3 horizonColor = atmos_HorizonColor(world_toSky, skyHorizon);

	return mix(atmosv_SkyRadiance, horizonColor, skyHorizon);
}

float atmos_eyeAdaptation() {
	return frx_smoothedEyeBrightness.y * lightLuminance(atmosv_CelestialRadiance) * (1. - frx_rainGradient);
}
#endif



#ifdef VERTEX_SHADER

const float SKY_LIGHT_RAINING_MULT    = 0.5;
const float SKY_LIGHT_THUNDERING_MULT = 0.2;

const float SUNLIGHT_STR	= DEF_SUNLIGHT_STR;
const float MOONLIGHT_STR	= DEF_MOONLIGHT_STR;
const float SKY_STR			= DEF_SKY_STR;
const float SKY_AMBIENT_STR	= DEF_SKY_AMBIENT_STR;

const vec3 DAY_SKY_COLOR	 = DEF_DAY_SKY_COLOR;
const vec3 NIGHT_SKY_COLOR	 = DEF_NIGHT_SKY_COLOR;
const vec3 NIGHT_CLOUD_COLOR = DEF_NIGHT_CLOUD_COLOR;
const vec3 DAY_CLOUD_COLOR	 = DEF_DAY_CLOUD_COLOR;

const vec3 NOON_SUNLIGHT_COLOR = hdr_fromGamma(vec3(1.0, 1.0, 1.0));
const vec3 SUNRISE_LIGHT_COLOR = hdr_fromGamma(vec3(1.0, 0.7, 0.4));

const vec3 NOON_AMBIENT  = hdr_fromGamma(vec3(1.0));
const vec3 NIGHT_AMBIENT = hdr_fromGamma(DEF_NIGHT_AMBIENT);

const vec3 CAVEFOG_C	 = hdr_fromGamma(DEF_LUMI_AZURE);
const vec3 CAVEFOG_DEEPC = SUNRISE_LIGHT_COLOR;
const float CAVEFOG_MAXY = 16.0;
const float CAVEFOG_MINY = 0.0;
const float CAVEFOG_STR	 = 1.0;


const int SRISC = 0;
const int SNONC = 1;
const int SMONC = 2;
const vec3[3] SUN_COLOR =  vec3[](SUNRISE_LIGHT_COLOR, NOON_SUNLIGHT_COLOR, vec3(1.0));
const float[3] TWG_FACTOR  = float[](1.0, 0.0, 0.0); // maps celest color to twilight factor
const int SUN_LEN = 8;
const int[SUN_LEN] SUN_COL_ID = int[]  (SMONC, SRISC, SRISC, SNONC, SNONC, SRISC, SRISC, SMONC);
const float[SUN_LEN] SUN_TIMES = float[](-0.05, -0.04,  0.00,  0.01,  0.49,   0.5,  0.54,  0.55);

const int DAYC = 0;
const int NGTC = 1;
const int TWGC = 2;
const int CLDC = 3;
const int NCLC = 4;
#ifdef POST_SHADER
const vec3[5] SKY_COLOR   = vec3[](DAY_SKY_COLOR, NIGHT_SKY_COLOR, SUNRISE_LIGHT_COLOR, DAY_CLOUD_COLOR, NIGHT_CLOUD_COLOR);
#endif
const vec3[2] SKY_AMBIENT = vec3[](NOON_AMBIENT,  NIGHT_AMBIENT * USER_NIGHT_AMBIENT_MULTIPLIER);
const int SKY_LEN = 4;
const int[SKY_LEN] SKY_INDICES = int[]  ( NGTC, DAYC, DAYC, NGTC);
const int[SKY_LEN] CLOUD_INDICES = int[]( NCLC, CLDC, CLDC, NCLC);
const float[SKY_LEN] SKY_TIMES = float[](-0.05, -0.01, 0.51, 0.55);

void atmos_generateAtmosphereModel()
{
	float moonlightStrength = MOONLIGHT_STR * USER_NIGHT_AMBIENT_MULTIPLIER * (0.5 + 0.5 * frx_moonSize);
	// SKY_AMBIENT[NGTC] *= 0.5 + 0.5 * frx_moonSize;


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

	atmosv_OWTwilightFactor *= float(frx_worldHasSkylight);

	sunColor.gb *= vec2(frx_skyLightTransitionFactor * frx_skyLightTransitionFactor);

	atmosv_CelestialRadiance = mix(sunColor * SUNLIGHT_STR, vec3(moonlightStrength), frx_worldIsMoonlit) * frx_skyLightTransitionFactor;



	if (horizonTime <= SKY_TIMES[0]) {
		atmosv_SkyAmbientRadiance = SKY_AMBIENT[SKY_INDICES[0]] * SKY_AMBIENT_STR * (frx_worldHasSkylight == 1 ? 1.0 : 0.0);
		#ifdef POST_SHADER
		atmosv_SkyRadiance   = SKY_COLOR  [SKY_INDICES[0]] * SKY_STR;
		atmosv_CloudRadiance = SKY_COLOR[CLOUD_INDICES[0]] * SKY_STR;
		#endif
	} else {
		int skyI = 1;
		while (horizonTime > SKY_TIMES[skyI] && skyI < SKY_LEN - 1) skyI++;
		float skyTransition = l2_clampScale(SKY_TIMES[skyI-1], SKY_TIMES[skyI], horizonTime);

		atmosv_SkyAmbientRadiance = mix(SKY_AMBIENT[SKY_INDICES[skyI-1]], SKY_AMBIENT[SKY_INDICES[skyI]], skyTransition)
									   * SKY_AMBIENT_STR * (frx_worldHasSkylight == 1 ? 1.0 : 0.0);
		#ifdef POST_SHADER
		atmosv_SkyRadiance   = mix(SKY_COLOR[SKY_INDICES[skyI-1]], SKY_COLOR[SKY_INDICES[skyI]], skyTransition) * SKY_STR;
		atmosv_CloudRadiance = mix(SKY_COLOR[CLOUD_INDICES[skyI-1]], SKY_COLOR[CLOUD_INDICES[skyI]], skyTransition) * SKY_STR;
		#endif
	}



	#ifdef POST_SHADER
	/** FOG **/
	// vanilla clear color is unreliable, we want to control its brightness
	atmosv_ClearRadiance = hdr_fromGamma(frx_vanillaClearColor);
	float lClearRadiance = dot(atmosv_ClearRadiance, vec3(1./3.));
	atmosv_ClearRadiance = atmosv_ClearRadiance / (lClearRadiance == 0.0 ? 1.0 : lClearRadiance);

	bool customOWFog = frx_worldIsOverworld == 1 && frx_cameraInLava == 0;
	bool customEndFog = frx_worldIsEnd == 1 && frx_cameraInLava == 0;

	if (customOWFog) {
		atmosv_FogRadiance = atmosv_SkyRadiance;
	} else if (customEndFog) {
		atmosv_FogRadiance = mix(atmosv_ClearRadiance, hdr_fromGamma(vec3(1.0, 0.7, 1.0)), float(frx_cameraInFluid)) * 0.1;
	} else {
		// controllable overall brightness
		atmosv_FogRadiance = atmosv_ClearRadiance * 0.1;
	}

	// ClearRadiance is mostly used for water
	atmosv_ClearRadiance = mix(atmosv_FogRadiance, atmosv_ClearRadiance * 0.3, float(frx_cameraInWater));


	atmosv_OWTwilightRadiance = SKY_COLOR[TWGC];
	atmosv_OWTwilightRadiance.gb *= vec2(max(frx_skyLightTransitionFactor, 0.3), frx_skyLightTransitionFactor * frx_skyLightTransitionFactor);

	// prevent custom overworld sky reflection in non-overworld dimension or when the sky mode is not Lumi
	bool customOWSkyAndFallback = frx_worldIsOverworld == 1;

	if (!customOWSkyAndFallback) {
		atmosv_SkyRadiance = atmosv_FogRadiance;
	}

	#endif



	/** RAIN **/
	float rainBrightness = min(mix(1.0, SKY_LIGHT_RAINING_MULT, frx_rainGradient), mix(1.0, SKY_LIGHT_THUNDERING_MULT, frx_thunderGradient));

	vec3 grayCelestial  = vec3(frx_luminance(atmosv_CelestialRadiance));
	vec3 graySkyAmbient = vec3(frx_luminance(atmosv_SkyAmbientRadiance));
	#ifdef POST_SHADER
	vec3 graySky = vec3(frx_luminance(atmosv_SkyRadiance));
	vec3 grayFog = vec3(frx_luminance(atmosv_FogRadiance));
	#endif

	float toGray = frx_rainGradient * 0.6 + frx_thunderGradient * 0.35;

	atmosv_CelestialRadiance  = mix(atmosv_CelestialRadiance, grayCelestial, toGray) * rainBrightness; // only used for cloud shading during rain
	atmosv_SkyAmbientRadiance = mix(atmosv_SkyAmbientRadiance, graySkyAmbient, toGray) * mix(1., .5, frx_thunderGradient);

	#ifdef POST_SHADER
	atmosv_CloudRadiance = mix(atmosv_CloudRadiance, graySky, 0.2); // ACES adjustment

	atmosv_SkyRadiance   = mix(atmosv_SkyRadiance, graySky, toGray) * rainBrightness;
	atmosv_CloudRadiance = mix(atmosv_CloudRadiance, graySky, toGray) * rainBrightness;

	if (customOWFog) {
		atmosv_FogRadiance		  = mix(atmosv_FogRadiance, grayFog, toGray) * rainBrightness;
		atmosv_OWTwilightRadiance = mix(atmosv_OWTwilightRadiance, graySky, toGray) * rainBrightness;
	}
	#endif
	/**********/


	/** CAVE FOG **/
	if (frx_worldIsOverworld == 1) {
		atmosv_CaveFogRadiance = mix(CAVEFOG_C, CAVEFOG_DEEPC, l2_clampScale(CAVEFOG_MAXY, CAVEFOG_MINY, frx_cameraPos.y)) * CAVEFOG_STR;

		/* adjust cave fog brightness to outdoors fog's brightness.
		   this means cave fog is affected by the daylight cycle, which sucks, but 
		   it's better than having cave fog affect the outdoors in a jarring way. */
		float fogLuminance = lightLuminance(atmosv_FogRadiance);
		float caveFogLuminance = lightLuminance(atmosv_CaveFogRadiance);
		atmosv_CaveFogRadiance *= fogLuminance / caveFogLuminance;
	} else {
		atmosv_CaveFogRadiance = atmosv_FogRadiance;
	}
	/**********/
}
#endif
