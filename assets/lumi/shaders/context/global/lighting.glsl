#include lumi:shaders/lib/util.glsl
#include lumi:lighting_config

/*******************************************************
 *  lumi:shaders/context/global/lighting.glsl          *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo, Contributors   *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

#define hdr_sunStr 6
#define hdr_moonStr 0.4
#define hdr_blockMinStr 2
#define hdr_blockMaxStr 3
#define hdr_handHeldStr 1.5
#define hdr_skylessStr 0.1
#define hdr_baseMinStr 0.01
#define hdr_baseMaxStr 0.8
#define hdr_skylessBaseMinStr 0.2
#define hdr_skylessBaseMaxStr 1.0
#define hdr_emissiveStr 1
#define hdr_relAmbient 0.2
#define hdr_dramaticStr 1.0
#define hdr_dramaticMagicNumber 6.0

#define hdr_nightAmbientMult 2.0
#define hdr_skylessRelStr 0.5
#define hdr_zWobbleDefault 0.1

const vec3 blockColor = vec3(1.0, 0.875, 0.75);
const vec3 dramaticBlockColor = vec3(1.0, 0.7, 0.4);

const vec3 preSunColor = vec3(1.0, 1.0, 1.0);
const vec3 preSunriseColor = vec3(1.0, 0.8, 0.4);
const vec3 preSunsetColor = vec3(1.0, 0.6, 0.4);

const vec3 nvColor = vec3(0.63, 0.55, 0.64);

#ifndef LUMI_DayAmbientBlue
    #define LUMI_DayAmbientBlue 0
#endif

#define preDayAmbient hdr_gammaAdjust(mix(vec3(0.8550322), vec3(0.6, 0.9, 1.0), clamp(LUMI_DayAmbientBlue * 0.1, 0.0, 1.0))) * hdr_sunStr
#define preAmbient hdr_gammaAdjust(vec3(0.6, 0.9, 1.0)) * hdr_sunStr

#if LIGHTING_PROFILE == LIGHTING_PROFILE_MOODY
    #define preSunriseAmbient hdr_gammaAdjust(vec3(0.5, 0.3, 0.1)) * hdr_sunStr
    #define preSunsetAmbient hdr_gammaAdjust(vec3(0.5, 0.2, 0.0)) * hdr_sunStr
    #define preNightAmbient hdr_gammaAdjust(vec3(0.74, 0.4, 1.0)) * hdr_moonStr * hdr_nightAmbientMult
#else
    #define preSunriseAmbient hdr_gammaAdjust(vec3(1.0, 0.8, 0.4)) * hdr_sunStr
    #define preSunsetAmbient hdr_gammaAdjust(vec3(1.0, 0.6, 0.2)) * hdr_sunStr
    #define preNightAmbient hdr_gammaAdjust(vec3(0.5, 0.5, 1.0)) * hdr_moonStr * hdr_nightAmbientMult
#endif
