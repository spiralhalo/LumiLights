#include frex:shaders/lib/math.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/player.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/context/global/lighting.glsl

/*******************************************************
 *  lumi:shaders/lib/lightsource.glsl                  *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo, Contributors   *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

/*  BLOCK LIGHT
 *******************************************************/

vec3 l2_blockRadiance(float blockLight)
{
    #if LIGHTING_PROFILE == LIGHTING_PROFILE_MOODY
        float dist = (1.001 - min(l2_clampScale(0.03125, 0.95, blockLight), 0.93)) * 15;
        float bl = hdr_dramaticMagicNumber / (dist * dist);
        if (bl <= 0.01 * hdr_dramaticMagicNumber) {
            bl *= l2_clampScale(0.0045 * hdr_dramaticMagicNumber, 0.01 * hdr_dramaticMagicNumber, bl);
        }
        return bl * hdr_gammaAdjust(dramaticBlockColor) * mix(hdr_blockMinStr, hdr_blockMaxStr, frx_viewBrightness());
    #else
        float bl = l2_clampScale(0.03125, 1.0, blockLight);
        bl *= bl * mix(hdr_blockMinStr, hdr_blockMaxStr, frx_viewBrightness());
        return hdr_gammaAdjust(bl * blockColor);
    #endif
}

/*  HELD LIGHT
 *******************************************************/

#if HANDHELD_LIGHT_RADIUS != 0
    vec3 l2_handHeldRadiance(vec3 viewPos)
    {
        #if LIGHTING_PROFILE == LIGHTING_PROFILE_MOODY
            vec4 held = frx_heldLight();
            float dist = (1.001 - l2_clampScale(held.w * HANDHELD_LIGHT_RADIUS, 0.0, -viewPos.z+0.5)) * 15;
            float hl = hdr_dramaticMagicNumber / (dist * dist);
            if (hl <= 0.01 * hdr_dramaticMagicNumber) {
                hl *= l2_clampScale(0.0045 * hdr_dramaticMagicNumber, 0.01 * hdr_dramaticMagicNumber, hl);
            }
            vec3 heldColor = held.rgb;
            if (heldColor == blockColor) heldColor = dramaticBlockColor;
            return hl * hdr_gammaAdjust(heldColor) * hdr_handHeldStr;
        #else
            vec4 held = frx_heldLight();
            float hl = l2_clampScale(held.w * HANDHELD_LIGHT_RADIUS, 0.0, -viewPos.z+0.5);
            hl *= hl * hdr_handHeldStr;
            return hdr_gammaAdjust(held.rgb * hl);
        #endif
    }
#endif

/*  EMISSIVE LIGHT
 *******************************************************/

#define l2_emissiveRadiance(emissivity) vec3(hdr_gammaAdjustf(emissivity) * hdr_emissiveStr)

/*  SKY AMBIENT LIGHT
 *******************************************************/

float l2_skyLight(float skyLight, float intensity)
{
    float sl = l2_clampScale(0.03125, 1.0, skyLight);
    return hdr_gammaAdjustf(sl) * intensity;
}

vec3 l2_ambientColor(float time)
{
    #ifdef TRUE_DARKNESS_MOONLIGHT
        vec3 nightAmbient = vec3(0.0);
    #else
        vec3 nightAmbient = preNightAmbient;
    #endif
    if (time == 0.0) return preSunriseAmbient * hdr_relAmbient;
    const int len = 11;
    vec3 colors[len] = vec3[](
        preSunriseAmbient,
        preAmbient,
        preDayAmbient,
        preDayAmbient,
        preAmbient,
        preSunsetAmbient,
        preAmbient,
        nightAmbient,
        nightAmbient,
        preAmbient,
        preSunriseAmbient);
    float times[len] = float[](
        0.0,
        0.02,
        0.06,
        0.44,
        0.48,
        0.5,
        0.52,
        0.56,
        0.94,
        0.98,
        1.0);
    int i = 1;
    while (time > times[i] && i < len - 1) i++;
    return mix(colors[i-1], colors[i], l2_clampScale(times[i-1], times[i], time)) * hdr_relAmbient;
}

vec3 l2_skyAmbient(float skyLight, float time, float intensity)
{
    float sl = l2_skyLight(skyLight, intensity);
    #if LIGHTING_PROFILE == LIGHTING_PROFILE_MOODY
        sl = smoothstep(0.1, 0.9, sl);
    #endif
    float sa = sl * 2.5;
    return sa * l2_ambientColor(time);
}

/*  SKYLESS LIGHT
 *******************************************************/

#define l2_skylessLightColor() vec3(1.0)

vec3 l2_dimensionColor()
{
#if LIGHTING_PROFILE == LIGHTING_PROFILE_MOODY
    if (frx_isWorldTheNether()) {
        float min_col = l2_min3(gl_Fog.color.rgb);
        float max_col = l2_max3(gl_Fog.color.rgb);
        float sat = 0.0;
        if (max_col != 0.0) sat = (max_col-min_col)/max_col;
        return hdr_gammaAdjust(clamp((gl_Fog.color.rgb*(1/max_col))+pow(sat,2)/2, 0.0, 1.0));
    }
    return hdr_gammaAdjust(vec3(0.8, 0.7, 1.0));
#else
    return vec3(1.0, 1.0, 1.0);
#endif
}

#define l2_skylessDarkenedDir() vec3(0, -0.977358, 0.211593)
#define l2_skylessDir() vec3(0, 0.977358, 0.211593)

vec3 l2_skylessRadiance() {
    #ifdef TRUE_DARKNESS_NETHER
        if (frx_isSkyDarkened()) return vec3(0.0);
    #endif
    #ifdef TRUE_DARKNESS_END
        if (!frx_isSkyDarkened()) return vec3(0.0);
    #endif
    if (frx_worldHasSkylight()) return vec3(0);
    else return (frx_isSkyDarkened() ? 0.5 : 1.0) * hdr_skylessStr * l2_skylessLightColor() * frx_viewBrightness();
}

/*  BASE AMBIENT LIGHT
 *******************************************************/

vec3 l2_baseAmbient(){
    //frx_viewBrightness() is maxed out by night vision so it's useless here
    if (frx_playerHasNightVision()) return hdr_gammaAdjust(nvColor) * hdr_blockMaxStr;
    if (frx_worldHasSkylight()) {
        #ifdef TRUE_DARKNESS_DEFAULT
            return vec3(0.0);
        #else
            return vec3(0.1) * mix(hdr_baseMinStr, hdr_baseMaxStr, frx_viewBrightness());
        #endif
    } else {
        #ifdef TRUE_DARKNESS_NETHER
            if(frx_isSkyDarkened()){
                return vec3(0.0);
            }
        #endif
        #ifdef TRUE_DARKNESS_END
            if(!frx_isSkyDarkened()){
                return vec3(0.0);
            }
        #endif
        return l2_dimensionColor() * hdr_skylessRelStr * mix(hdr_skylessBaseMinStr, hdr_skylessBaseMaxStr, frx_viewBrightness());
    }
}

/*  SUN LIGHT
 *******************************************************/

vec3 ldr_sunColor(float time)
{
    vec3 sunColor;
    if(time > 0.94) sunColor = mix(preSunriseColor, vec3(0), l2_clampScale(0.96, 0.94, time));
    else if(time > 0.5) sunColor = mix(preSunsetColor, vec3(0), l2_clampScale(0.54, 0.56, time));
    else if(time > 0.48) sunColor = mix(preSunColor, preSunsetColor, l2_clampScale(0.48, 0.5, time));
    else if(time < 0.02) sunColor = mix(preSunColor, preSunriseColor, l2_clampScale(0.02, 0, time));
    else sunColor = preSunColor;
    return sunColor;
}

float l2_sunHorizonScale(float time)
{
    if(time > 0.94) return frx_smootherstep(0.94, 0.96, time);
    else if(time > 0.5) return frx_smootherstep(0.56, 0.54, time);
    else if(time > 0.48) return frx_smootherstep(0.48, 0.5, time);
    else if(time < 0.02) return frx_smootherstep(0.02, 0, time);
    else return 0.0;
}

vec3 l2_vanillaSunDir(in float time, float zWobble)
{
    // wrap time to account for sunrise
    time -= (time >= 0.75) ? 1.0 : 0.0;
    // supposed offset of sunset/sunrise from 0/12000 daytime. might get better result with datamining?
    float sunHorizonDur = 0.04;
    // angle of sun in radians
    float angleRad = l2_clampScale(-sunHorizonDur, 0.5+sunHorizonDur, time) * PI;
    return normalize(vec3(cos(angleRad), sin(angleRad), zWobble));
}

vec3 l2_sunRadiance(float skyLight, in float time, float intensity, float rainGradient)
{
    // wrap time to account for sunrise
    float customTime = (time >= 0.75) ? (time - 1.0) : time;
    float customIntensity = (customTime >= 0.25) ? l2_clampScale(0.56, 0.52, customTime) : l2_clampScale(-0.06, -0.02, customTime);
    customIntensity *= mix(1.0, 0.0, rainGradient);
    float sl = l2_skyLight(skyLight, max(customIntensity, intensity));
    // direct sun light doesn't reach into dark spot as much as sky ambient
    #if LIGHTING_PROFILE == LIGHTING_PROFILE_MOODY
        sl = frx_smootherstep(0.7, 0.97, sl);
    #else
        sl = frx_smootherstep(0.5, 0.97, sl);
    #endif
    #if LIGHTING_PROFILE == LIGHTING_PROFILE_SystemUnused
        return sl * hdr_sunStr * hdr_gammaAdjust(ldr_sunColor(time)) * (0.5 - 0.5 * dot(frx_cameraView(), vec3(0.0, 1.0, 0.0)));
    #else
        return sl * hdr_sunStr * hdr_gammaAdjust(ldr_sunColor(time));
    #endif
}

/*  MOON LIGHT
 *******************************************************/

vec3 l2_moonDir(float time){
    float aRad = l2_clampScale(0.56, 0.94, time) * PI;
    return normalize(vec3(cos(aRad), sin(aRad), 0));
}

vec3 l2_moonRadiance(float skyLight, float time, float intensity){
    #ifdef TRUE_DARKNESS_MOONLIGHT
        return vec3(0.0);
    #else
    float ml = l2_skyLight(skyLight, intensity) * frx_moonSize() * hdr_moonStr;
    if(time < 0.58) ml *= l2_clampScale(0.54, 0.58, time);
    else if(time > 0.92) ml *= l2_clampScale(0.96, 0.92, time);
    return vec3(ml);
    #endif
}
