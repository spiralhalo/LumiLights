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

vec3 atmos_FogRadiance(vec3 world_toSky, bool isUnderwater)
{
	//TODO: test non-overworld has_sky_light custom dimension and broaden if fits
	if (frx_worldIsOverworld == 0) return atmosv_FogRadiance;
	return isUnderwater ? atmosv_ClearRadiance : mix(atmosv_FogRadiance, atmosv_OWTwilightRadiance, 0.8 * twilightCalc2(world_toSky) * atmosv_OWTwilightFactor);
}

vec3 atmos_SkyRadiance(vec3 world_toSky)
{
	//TODO: test non-overworld has_sky_light custom dimension and broaden if fits
	if (frx_worldIsOverworld == 0) return atmosv_SkyRadiance;
	return mix(atmosv_SkyRadiance, atmosv_OWTwilightRadiance, twilightCalc2(world_toSky));
}

vec3 atmos_HorizonColor(vec3 world_toSky, float skyHorizon) {
	float brighteningCancel = min(1., atmosv_OWTwilightFactor * .6 + frx_rainGradient * .6);
	float brightenFactor = pow(skyHorizon, 20.) * (1. - brighteningCancel);
	float horizonBrightening = mix(1., HORIZON_MULT, brightenFactor);

	return mix(atmosv_SkyRadiance * horizonBrightening, atmosv_OWTwilightRadiance, twilightCalc(world_toSky, skyHorizon));
}

vec3 atmos_SkyGradientRadiance(vec3 world_toSky)
{
	//TODO: test non-overworld has_sky_light custom dimension and broaden if fits
	if (frx_worldIsOverworld == 0) return atmosv_SkyRadiance;

	float skyHorizon = calcHorizon(world_toSky);
	vec3 horizonColor = atmos_HorizonColor(world_toSky, skyHorizon);

	return mix(atmosv_SkyRadiance, horizonColor, skyHorizon);
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
const float CAVEFOG_STR	 = 0.05;


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
	float horizonTime = frx_worldTime < 0.75 ? frx_worldTime : (frx_worldTime - 1.0); // [-0.25, 0.75)

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
	bool customOWFog = frx_worldIsOverworld == 1 && frx_effectBlindness == 0;
	vec3 vanillaFog = frx_vanillaClearColor;

	if (customOWFog) {
		atmosv_FogRadiance = atmosv_SkyRadiance;
		// night fog are as bright as the horizon unless it's raining
		atmosv_FogRadiance *= mix(1.0, HORIZON_MULT, frx_worldIsMoonlit * frx_skyLightTransitionFactor * (1.0 - frx_rainGradient));

		// vanilla clear color is unreliable in overworld, sometimes orange above water, or dark immediately underwater
		vec3 underwaterFog = hdr_fromGamma(vanillaFog);
		float lUwFog = dot(underwaterFog, vec3(0.33));
		underwaterFog /= (lUwFog == 0.0) ? 1.0 : lUwFog;

		atmosv_ClearRadiance = mix(atmosv_FogRadiance, underwaterFog * 0.3, frx_cameraInWater);
	} else {
		atmosv_ClearRadiance = atmosv_FogRadiance = hdr_fromGamma(vanillaFog);
	}

	atmosv_OWTwilightRadiance = SKY_COLOR[TWGC];
	atmosv_OWTwilightRadiance.gb *= vec2(max(frx_skyLightTransitionFactor, 0.3), frx_skyLightTransitionFactor * frx_skyLightTransitionFactor);

	// prevent custom overworld sky reflection in non-overworld dimension or when the sky mode is not Lumi
	bool customOWSkyAndFallback = frx_worldIsOverworld == 1 && frx_effectBlindness == 0;

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
	if (frx_worldIsOverworld == 1 && frx_cameraInFluid == 0) {
		atmosv_CaveFogRadiance = mix(CAVEFOG_C, CAVEFOG_DEEPC, l2_clampScale(CAVEFOG_MAXY, CAVEFOG_MINY, frx_cameraPos.y));

		float fogL  = frx_luminance(atmosv_FogRadiance);
		float caveL = frx_luminance(atmosv_CaveFogRadiance);

		atmosv_CaveFogRadiance *= max(fogL, CAVEFOG_STR) / caveL;
	} else {
		atmosv_CaveFogRadiance = atmosv_FogRadiance;
	}
	/**********/
}
#endif
