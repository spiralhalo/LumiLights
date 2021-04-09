#include lumi:shaders/lib/util.glsl
#include lumi:shaders/common/userconfig.glsl

/*******************************************************
 *  lumi:shaders/common/lighting.glsl                  *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo, Contributors   *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

// STRENGTHS
#ifdef HIGH_CONTRAST
const float SUNLIGHT_STR = 12.0;
const float MOONLIGHT_STR = 0.8;
const float SKY_AMBIENT_STR = 1.2;
#else
const float SUNLIGHT_STR = 6.0;
const float MOONLIGHT_STR = 0.4;
const float SKY_AMBIENT_STR = 0.6;
#endif
const float SKYLESS_AMBIENT_STR = 0.8;
const float SKYLESS_LIGHT_STR = 2.0;
const float BLOCK_LIGHT_STR = 3.0;
const float BASE_AMBIENT_STR = 0.02;
const float HELD_LIGHT_STR = 1.5;
const float EMISSIVE_LIGHT_STR = 1.0;
const float NIGHT_VISION_STR = 3.0;

// MULTIPLIERS
const float BRIGHT_FINAL_MULT = 2.0;
const float SKY_LIGHT_RAINING_MULT = 0.1;
const float SKY_LIGHT_THUNDERING_MULT = 0.01;

// ADJUSTERS
const float BLOCK_LIGHT_ADJUSTER = 6.0;

// PREFERENCE
const float DEFAULT_Z_WOBBLE = 0.1;

// LIGHT COLORS
#if BLOCK_LIGHT_MODE == BLOCK_LIGHT_MODE_NEUTRAL
 // Not 1-triplet for balance. Is this necessary though?
const vec3 BLOCK_LIGHT_COLOR = vec3(0.74152, 0.74152, 0.74152);
#else
const vec3 BLOCK_LIGHT_COLOR = vec3(1.0, 0.7, 0.4);
#endif
const vec3 DAY_SUNLIGHT_COLOR = vec3(1.0, 1.0, 1.0);
const vec3 SUNRISE_LIGHT_COLOR = vec3(1.0, 0.8, 0.4);
const vec3 SUNSET_LIGHT_COLOR = vec3(1.0, 0.6, 0.4);
const vec3 NIGHT_VISION_COLOR = vec3(0.63, 0.55, 0.64);
const vec3 SKYLESS_LIGHT_COLOR = vec3(1.0, 1.0, 1.0);
const vec3 NETHER_SKYLESS_LIGHT_COLOR = vec3(1.0, 0.5, 0.3);

// SKY COLORS
// const vec3 SUNRISE_SKY_COLOR = vec3(0.5, 0.3, 0.1);
const vec3 ORANGE_SKY_COLOR = hdr_gammaAdjust(vec3(1.0, 0.7, 0.0));
#if SKY_MODE == SKY_MODE_LUMI
#if LUMI_SKY_COLOR == LUMI_SKY_COLOR_BRIGHT_CYAN
const vec3 DAY_SKY_COLOR = hdr_gammaAdjust(vec3(0.33, 0.7, 1.0));
#else
const vec3 DAY_SKY_COLOR = hdr_gammaAdjust(vec3(0.3, 0.5, 1.0));
#endif
const vec3 NIGHT_SKY_COLOR = hdr_gammaAdjust(vec3(0.03, 0.05, 0.15));
const vec3 NEBULAE_COLOR = hdr_gammaAdjust(vec3(0.8, 0.3, 0.6));
#else
const vec3 DAY_SKY_COLOR = hdr_gammaAdjust(vec3(0.52, 0.69, 1.0));
const vec3 NIGHT_SKY_COLOR = hdr_gammaAdjust(vec3(0.01, 0.01, 0.01));
const vec3 NEBULAE_COLOR = vec3(0.9, 0.75, 1.0);
#endif

// GAMMA-ADJUSTED AMBIENT
const vec3 HDR_NOON_AMBIENT = hdr_gammaAdjust(vec3(0.8550322));
const vec3 HDR_BLUE_AMBIENT = hdr_gammaAdjust(vec3(0.6, 0.9, 1.0));
const vec3 HDR_SUNRISE_AMBIENT = hdr_gammaAdjust(vec3(0.5, 0.3, 0.1));
const vec3 HDR_SUNSET_AMBIENT = hdr_gammaAdjust(vec3(0.5, 0.2, 0.0));
const vec3 HDR_NIGHT_AMBIENT = hdr_gammaAdjust(vec3(0.4, 0.7, 1.0));
