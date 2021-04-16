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

float l2_lightmapRemap(float lightMapCoords)
{
    return hdr_gammaAdjustf(l2_clampScale(0.03125, 0.96875, lightMapCoords));
}

/*  RADIANCE
 *******************************************************/

vec3 l2_blockRadiance(float blockLight)
{
    float dist = (1.001 - min(l2_clampScale(0.03125, 0.96875, blockLight), 0.93)) * 15;
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
        vec3 dimensionColor = hdr_gammaAdjust(vec3(0.8, 0.7, 1.0));
        // THE NETHER
        if (frx_isWorldTheNether()) {
            float min_col = l2_min3(frx_vanillaClearColor());
            float max_col = l2_max3(frx_vanillaClearColor());
            float sat = 0.0;
            if (max_col != 0.0) sat = (max_col-min_col)/max_col;
            dimensionColor = hdr_gammaAdjust(clamp((frx_vanillaClearColor()*(1/max_col))+pow(sat,2)/2, 0.0, 1.0));
        }
        return dimensionColor * SKYLESS_AMBIENT_STR;
    }
}

// vec3 l2_sunRadiance(float skyLight, in float time, float rainGradient, float thunderGradient)
// {
//         // direct sun light doesn't reach into dark spot as much as sky ambient // TODO: WAT
//         sl = l2_clampScale(0.7, 0.97, sl);
// }

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
        float darkenedFactor = frx_isSkyDarkened() ? 0.6 : 1.0;
        return darkenedFactor * SKYLESS_LIGHT_STR * hdr_gammaAdjust(color);
    }
}
