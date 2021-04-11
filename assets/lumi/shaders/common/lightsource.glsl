#include frex:shaders/lib/math.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/player.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/common/lighting.glsl

/*******************************************************
 *  lumi:shaders/common/lightsource.glsl               *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo, Contributors   *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

/*  DIRECTIONS
 *******************************************************/

#define l2_skylessDarkenedDir() vec3(0, -0.977358, 0.211593)
#define l2_skylessDir() vec3(0, 0.977358, 0.211593)

/*  MULTIPLIERS
 *******************************************************/

float l2_skyLightRemap(float skyLight)
{
    float sl = l2_clampScale(0.03125, 1.0, skyLight);
    return hdr_gammaAdjustf(sl);
}

float l2_sunHorizonScale(float time)
{
    if(time > 0.94) return frx_smootherstep(0.94, 0.96, time);
    else if(time > 0.5) return frx_smootherstep(0.56, 0.54, time);
    else if(time > 0.48) return frx_smootherstep(0.48, 0.5, time);
    else if(time < 0.02) return frx_smootherstep(0.02, 0, time);
    else return 0.0;
}

/*  COLOR VARYINGS
 *******************************************************/

#ifdef VERTEX_SHADER
out vec3 vhdr_ambientColor;
out vec3 vhdr_dimensionColor;
out vec3 vldr_sunColor;
#else
in vec3 vhdr_ambientColor;
in vec3 vhdr_dimensionColor;
in vec3 vldr_sunColor;
#endif

/*  COLORS
 *******************************************************/

#ifdef VERTEX_SHADER
vec3 hdr_ambientColor(float time)
{
    #ifdef TRUE_DARKNESS_MOONLIGHT
        vec3 nightAmbient = vec3(0.0);
    #else
        vec3 nightAmbient = HDR_NIGHT_AMBIENT;
    #endif
    if (time == 0.0) return HDR_SUNRISE_AMBIENT * SKY_AMBIENT_STR;
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
    return mix(colors[i-1], colors[i], l2_clampScale(times[i-1], times[i], time)) * SKY_AMBIENT_STR;
}

vec3 hdr_dimensionColor()
{
    // THE NETHER
    if (frx_isWorldTheNether()) {
        float min_col = l2_min3(frx_vanillaClearColor());
        float max_col = l2_max3(frx_vanillaClearColor());
        float sat = 0.0;
        if (max_col != 0.0) sat = (max_col-min_col)/max_col;
        return hdr_gammaAdjust(clamp((frx_vanillaClearColor()*(1/max_col))+pow(sat,2)/2, 0.0, 1.0));
    }
    // THE END
    return hdr_gammaAdjust(vec3(0.8, 0.7, 1.0));
}

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

void lightsource_setVars()
{
    vhdr_ambientColor = hdr_ambientColor(frx_worldTime());
    vhdr_dimensionColor = hdr_dimensionColor();
    vldr_sunColor = ldr_sunColor(frx_worldTime());
}
#else
vec3 hdr_ambientColor(float time) {return vhdr_ambientColor;}
vec3 hdr_dimensionColor() {return vhdr_dimensionColor;}
vec3 ldr_sunColor(float time) {return vldr_sunColor;}
#endif

/*  RADIANCE
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

vec3 l2_emissiveRadiance(vec3 hdrFragColor, float emissivity)
{
    return hdrFragColor * hdr_gammaAdjustf(emissivity) * EMISSIVE_LIGHT_STR;
}

vec3 l2_baseAmbientRadiance()
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
        return hdr_dimensionColor() * SKYLESS_AMBIENT_STR;
    }
}

vec3 l2_skyAmbientRadiance(float skyLight, float time, float intensity)
{
    float sl = l2_skyLightRemap(skyLight);
    sl = smoothstep(0.1, 0.9, sl); // STEEP SKY LIGHT (PSEUDO SHADOW)
    float sa = sl * 2.5;
    return sa * hdr_ambientColor(time);
}

vec3 l2_sunRadiance(float skyLight, in float time, float rainGradient, float thunderGradient)
{
    // PERF: single weather factor everywhere
    float weatherFactor = min(mix(1.0, SKY_LIGHT_RAINING_MULT, rainGradient), mix(1.0, SKY_LIGHT_THUNDERING_MULT, thunderGradient));
    #ifdef SHADOW_MAP_PRESENT
        float sl = skyLight;
    #else
        float sl = l2_skyLightRemap(skyLight);
        // direct sun light doesn't reach into dark spot as much as sky ambient // TODO: WAT
        sl = l2_clampScale(0.7, 0.97, sl);
    #endif
    return sl * SUNLIGHT_STR * hdr_gammaAdjust(ldr_sunColor(time)) * weatherFactor;
}

vec3 l2_moonRadiance(float skyLight, float time, float rainGradient, float thunderGradient)
{
    #ifdef TRUE_DARKNESS_MOONLIGHT
        return vec3(0.0);
    #else
    // PERF: single weather factor everywhere
    float weatherFactor = min(mix(1.0, SKY_LIGHT_RAINING_MULT, rainGradient), mix(1.0, SKY_LIGHT_THUNDERING_MULT, thunderGradient));
    float moonsizeFactor = 0.5 + 0.5 * frx_moonSize();
    #ifdef SHADOW_MAP_PRESENT
        float ml = skyLight;
    #else
        float ml = l2_skyLightRemap(skyLight);
    #endif
    // aren't these code just the transition factor ?
    // if(time < 0.58) ml *= l2_clampScale(0.54, 0.58, time);
    // else if(time > 0.92) ml *= l2_clampScale(0.96, 0.92, time);
    return vec3(ml * weatherFactor * moonsizeFactor * MOONLIGHT_STR);
    #endif
}

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
        return darkenedFactor * SKYLESS_LIGHT_STR * hdr_gammaAdjust(color);
    }
}
