#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/common/userconfig.glsl

/*******************************************************
 *  lumi:shaders/common/contrast.glsl
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

const float USER_CELESTIAL_MULTIPLIER      = clamp(OUTDOORS_BRIGHTNESS, 10, 50) / 10.;
const float USER_SKY_AMBIENT_MULTIPLIER    = clamp(SKY_AMBIENT_BRIGHTNESS, 10, 50) / 10.;
const float USER_BLOCK_MULTIPLIER          = clamp(INDOORS_BRIGHTNESS, 10, 50) / 10.;
const float USER_AMBIENT_MULTIPLIER        = clamp(AMBIENT_BRIGHTNESS, 0, 50) / 10.;
const float USER_NETHER_AMBIENT_MULTIPLIER = clamp(NETHER_AMBIENT_BRIGHTNESS, 0, 50) / 10.;
const float USER_END_AMBIENT_MULTIPLIER    = clamp(END_AMBIENT_BRIGHTNESS, 0, 50) / 10.;
const float USER_NIGHT_AMBIENT_MULTIPLIER  = clamp(NIGHT_AMBIENT_BRIGHTNESS, 0, 50) / 10.;
const float USER_ALBEDO_BRIGHTENING		   = clamp(ALBEDO_BRIGHTENING, 0, 20) / 500.;

// PROFILE-AGNOSTIC
// ******************************

	// STRENGTHS
	#define DEF_BASE_AMBIENT_STR	0.1
	#define DEF_SKYLESS_AMBIENT_STR	0.5
	#define DEF_SKYLESS_LIGHT_STR	1.0
	#define DEF_BLOCK_LIGHT_STR		1.5 * USER_BLOCK_MULTIPLIER
	#define DEF_EMISSIVE_LIGHT_STR	10.0 // want decent lava bloom
	const float NIGHT_VISION_STR =	1.5;
	#define STARS_STR				1.0
	#define LIGHT_RAYS_STR			1.0 // this was never meant to go above 1.0 due to sdr blending

	// ATMOS STRENGTHS
	#define DEF_SUNLIGHT_STR		1.5 * USER_CELESTIAL_MULTIPLIER
	#define DEF_SKY_STR				1.0
	#define DEF_SKY_AMBIENT_STR		1.0 * USER_SKY_AMBIENT_MULTIPLIER
	#define DEF_MOONLIGHT_STR		1.0 * USER_NIGHT_AMBIENT_MULTIPLIER
	#define HORIZON_MULT			6.0

	// LIGHT COLORS
	const vec3 BLOCK_LIGHT_NEUTRAL = hdr_fromGamma(vec3(0.7555)); // luminance of warm BL color
#if BLOCK_LIGHT_MODE == BLOCK_LIGHT_MODE_NEUTRAL
	const vec3 BLOCK_LIGHT_COLOR = BLOCK_LIGHT_NEUTRAL;
#else
	const vec3 BLOCK_LIGHT_COLOR = hdr_fromGamma(vec3(1.0, 0.7, 0.4));
#endif
	const vec3 NIGHT_VISION_COLOR		= hdr_fromGamma(vec3(1.0, 0.95, 1.0));
	const vec3 SKYLESS_LIGHT_COLOR		= hdr_fromGamma(vec3(1.0, 1.0, 1.0));
	const vec3 NETHER_LIGHT_COLOR		= hdr_fromGamma(vec3(1.0, 0.6, 0.4));

	// SKY COLORS
	#define DEF_VANILLA_DAY_SKY_COLOR	hdr_fromGamma(vec3(0.52, 0.69, 1.0))
	#define DEF_LUMI_AZURE				vec3(0.425, 0.623333, 0.85)

#if SKY_MODE == SKY_MODE_LUMI

	#define DEF_NEBULAE_COLOR			vec3(0.8, 0.3, 0.6)
	#define _0_DEF_NIGHT_SKY_COLOR		vec3(0.15, 0.175, 0.3)

	#if LUMI_SKY_COLOR == LUMI_SKY_COLOR_NATURAL_AZURE
		#define DEF_DAY_SKY_COLOR		hdr_fromGamma(DEF_LUMI_AZURE)
	#elif LUMI_SKY_COLOR == LUMI_SKY_COLOR_BRIGHT_CYAN
		#define DEF_DAY_SKY_COLOR		hdr_fromGamma(vec3(0.40, 0.69, 1.0))
	#elif LUMI_SKY_COLOR == LUMI_SKY_COLOR_DEEP_CERULEAN
		#define DEF_DAY_SKY_COLOR		hdr_fromGamma(vec3(0.3, 0.5, 1.0))
	#else
		// spaghetti
		#define DEF_DAY_SKY_COLOR		hdr_fromGamma(max(vec3(1.0 / 255.0), vec3(LUMI_SKY_RED, LUMI_SKY_GREEN, LUMI_SKY_BLUE))) * max(1.0, (lightLuminance(DEF_NIGHT_SKY_COLOR) + 0.1) / lightLuminance(hdr_fromGamma(max(vec3(1.0 / 255.0), vec3(LUMI_SKY_RED, LUMI_SKY_GREEN, LUMI_SKY_BLUE)))))
	#endif

#else

	#define DEF_NEBULAE_COLOR		vec3(0.4, 0.15, 0.3)
	#define _0_DEF_NIGHT_SKY_COLOR	vec3(0.11, 0.13, 0.225)
	#define DEF_DAY_SKY_COLOR		DEF_VANILLA_DAY_SKY_COLOR

#endif

	// SKY_COLORS
	#define DEF_NIGHT_SKY_COLOR		hdr_fromGamma(_0_DEF_NIGHT_SKY_COLOR)
	const vec3 NEBULAE_COLOR	=	hdr_fromGamma(DEF_NEBULAE_COLOR);

	// STRENGTHS
	const float BASE_AMBIENT_STR	= DEF_BASE_AMBIENT_STR;
	const float SKYLESS_AMBIENT_STR	= DEF_SKYLESS_AMBIENT_STR;
	const float SKYLESS_LIGHT_STR	= DEF_SKYLESS_LIGHT_STR;
	const float BLOCK_LIGHT_STR		= DEF_BLOCK_LIGHT_STR;
	const float EMISSIVE_LIGHT_STR	= DEF_EMISSIVE_LIGHT_STR;
	// spaghetti
	const float STAR_LUMIGATE_HIGH	= max(lightLuminance(DEF_DAY_SKY_COLOR) * 0.8, lightLuminance(DEF_NIGHT_SKY_COLOR) + 0.1) * DEF_SKY_STR;
	const float STAR_LUMIGATE_LOW	= max(STAR_LUMIGATE_HIGH * 0.26, lightLuminance(DEF_NIGHT_SKY_COLOR)) * DEF_SKY_STR;
