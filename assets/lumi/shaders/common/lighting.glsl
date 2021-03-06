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
const float BASE_AMBIENT_STR = 0.1;
const float SKYLESS_AMBIENT_STR = 0.5;
const float SKYLESS_LIGHT_STR = 1.0;
const float BLOCK_LIGHT_STR = 1.5;
const float NIGHT_VISION_STR = 1.5;
const float EMISSIVE_LIGHT_STR = 1.0;

// LIGHT COLORS
#if BLOCK_LIGHT_MODE == BLOCK_LIGHT_MODE_NEUTRAL
 // Not 1-triplet for balance. Is this necessary though?
const vec3 BLOCK_LIGHT_COLOR = hdr_fromGamma(vec3(0.74152, 0.74152, 0.74152));
#else
const vec3 BLOCK_LIGHT_COLOR = hdr_fromGamma(vec3(1.0, 0.7, 0.4));
#endif
const vec3 NIGHT_VISION_COLOR = hdr_fromGamma(vec3(1.0, 0.95, 1.0));
const vec3 SKYLESS_LIGHT_COLOR = hdr_fromGamma(vec3(1.0, 1.0, 1.0));
const vec3 NETHER_SKYLESS_LIGHT_COLOR = hdr_fromGamma(vec3(1.0, 0.9, 0.8));

#if SKY_MODE == SKY_MODE_LUMI
const vec3 NEBULAE_COLOR = hdr_fromGamma(vec3(0.8, 0.3, 0.6));
#else
const vec3 NEBULAE_COLOR = vec3(0.9, 0.75, 1.0);
#endif
