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
    float dist = (1.001 - min(l2_clampScale(0.03125, 0.95, blockLight), 0.93)) * 15;
    float bl = BLOCK_LIGHT_ADJUSTER / (dist * dist);
    // CLAMP DOWN TO ZERO
    if (bl <= 0.01 * BLOCK_LIGHT_ADJUSTER) {
        bl *= l2_clampScale(0.0045 * BLOCK_LIGHT_ADJUSTER, 0.01 * BLOCK_LIGHT_ADJUSTER, bl);
    }
    bl *= BLOCK_LIGHT_STR;
    return bl * hdr_gammaAdjust(BLOCK_LIGHT_COLOR);
}

/*  HELD LIGHT
 *******************************************************/

#if HANDHELD_LIGHT_RADIUS != 0
vec3 l2_handHeldRadiance(vec3 viewPos)
{
    vec4 heldLight = frx_heldLight();
    float dist = (1.001 - l2_clampScale(heldLight.w * HANDHELD_LIGHT_RADIUS, 0.0, -viewPos.z+0.5)) * 15;
    float hl = BLOCK_LIGHT_ADJUSTER / (dist * dist);
    // CLAMP DOWN TO ZERO
    if (hl <= 0.01 * BLOCK_LIGHT_ADJUSTER) {
        hl *= l2_clampScale(0.0045 * BLOCK_LIGHT_ADJUSTER, 0.01 * BLOCK_LIGHT_ADJUSTER, hl);
    }
    hl *= BLOCK_LIGHT_STR;
    return hl * hdr_gammaAdjust(heldLight.rgb);
}
#endif

/*  EMISSIVE LIGHT
 *******************************************************/

vec3 l2_emissiveRadiance(vec3 hdrFragColor, float emissivity)
{
    return hdrFragColor * hdr_gammaAdjustf(emissivity) * EMISSIVE_LIGHT_STR;
}

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
        vec3 nightAmbient = HDR_NIGHT_AMBIENT;
    #endif
    if (time == 0.0) return HDR_SUNRISE_AMBIENT * SKY_AMBIENT_MULT;
    const int len = 11;
    vec3 colors[len] = vec3[](
        HDR_SUNRISE_AMBIENT,
        HDR_BLUE_AMBIENT,
        HDR_NOON_AMBIENT,
        HDR_NOON_AMBIENT,
        HDR_BLUE_AMBIENT,
        HDR_SUNSET_AMBIENT,
        HDR_BLUE_AMBIENT,
        nightAmbient,
        nightAmbient,
        HDR_BLUE_AMBIENT,
        HDR_SUNRISE_AMBIENT);
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
    return mix(colors[i-1], colors[i], l2_clampScale(times[i-1], times[i], time)) * SKY_AMBIENT_MULT;
}

vec3 l2_skyAmbient(float skyLight, float time, float intensity)
{
    float sl = l2_skyLight(skyLight, intensity);
    sl = smoothstep(0.1, 0.9, sl); // STEEP SKY LIGHT (PSEUDO SHADOW)
    float sa = sl * 2.5;
    return sa * l2_ambientColor(time);
}

/*  SKYLESS LIGHT
 *******************************************************/

vec3 l2_dimensionColor()
{
    // THE NETHER
    if (frx_isWorldTheNether()) {
        float min_col = l2_min3(gl_Fog.color.rgb);
        float max_col = l2_max3(gl_Fog.color.rgb);
        float sat = 0.0;
        if (max_col != 0.0) sat = (max_col-min_col)/max_col;
        return hdr_gammaAdjust(clamp((gl_Fog.color.rgb*(1/max_col))+pow(sat,2)/2, 0.0, 1.0));
    }
    // THE END
    return hdr_gammaAdjust(vec3(0.8, 0.7, 1.0));
}

#define l2_skylessDarkenedDir() vec3(0, -0.977358, 0.211593)
#define l2_skylessDir() vec3(0, 0.977358, 0.211593)

vec3 l2_skylessRadiance()
{
    #ifdef TRUE_DARKNESS_NETHER
        if (frx_isSkyDarkened()) return vec3(0.0);
    #endif
    #ifdef TRUE_DARKNESS_END
        if (!frx_isSkyDarkened()) return vec3(0.0);
    #endif
    if (frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT)) return vec3(0);
    else {
        vec3 color = frx_worldFlag(FRX_WORLD_IS_NETHER) ? NETHER_SKYLESS_LIGHT_COLOR : SKYLESS_LIGHT_COLOR;
        float darkenedFactor = frx_isSkyDarkened() ? 0.5 : 1.0;
        return darkenedFactor * SKYLESS_LIGHT_STR * color;
    }
}

/*  BASE AMBIENT LIGHT
 *******************************************************/

vec3 l2_baseAmbient()
{
    //frx_viewBrightness() is maxed out by night vision so it's useless here
    if (frx_playerHasNightVision()) return hdr_gammaAdjust(NIGHT_VISION_COLOR) * NIGHT_VISION_STR;
    if (frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT)) {
        #ifdef TRUE_DARKNESS_DEFAULT
            return vec3(0.0);
        #else
            return vec3(0.1) * BASE_AMBIENT_STR;
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
        return l2_dimensionColor() * SKYLESS_AMBIENT_STR;
    }
}

/*  SUN LIGHT
 *******************************************************/

vec3 ldr_sunColor(float time)
{
    vec3 sunColor;
    if(time > 0.94) sunColor = mix(SUNRISE_LIGHT_COLOR, vec3(0), l2_clampScale(0.96, 0.94, time));
    else if(time > 0.5) sunColor = mix(SUNSET_LIGHT_COLOR, vec3(0), l2_clampScale(0.54, 0.56, time));
    else if(time > 0.48) sunColor = mix(DAY_SUNLIGHT_COLOR, SUNSET_LIGHT_COLOR, l2_clampScale(0.48, 0.5, time));
    else if(time < 0.02) sunColor = mix(DAY_SUNLIGHT_COLOR, SUNRISE_LIGHT_COLOR, l2_clampScale(0.02, 0, time));
    else sunColor = DAY_SUNLIGHT_COLOR;
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

vec3 l2_sunRadiance(float skyLight, in float time, float intensity, float rainGradient)
{
    // wrap time to account for sunrise
    float customTime = (time >= 0.75) ? (time - 1.0) : time;
    float customIntensity = (customTime >= 0.25) ? l2_clampScale(0.56, 0.52, customTime) : l2_clampScale(-0.06, -0.02, customTime);
    customIntensity *= mix(1.0, 0.0, rainGradient);
    float sl = l2_skyLight(skyLight, max(customIntensity, intensity));
    // direct sun light doesn't reach into dark spot as much as sky ambient
    sl = frx_smootherstep(0.7, 0.97, sl);
    return sl * SUNLIGHT_STR * hdr_gammaAdjust(ldr_sunColor(time));
}

/*  MOON LIGHT
 *******************************************************/

vec3 l2_moonRadiance(float skyLight, float time, float intensity)
{
    #ifdef TRUE_DARKNESS_MOONLIGHT
        return vec3(0.0);
    #else
    float ml = l2_skyLight(skyLight, intensity) * frx_moonSize() * MOONLIGHT_STR;
    if(time < 0.58) ml *= l2_clampScale(0.54, 0.58, time);
    else if(time > 0.92) ml *= l2_clampScale(0.96, 0.92, time);
    return vec3(ml);
    #endif
}
