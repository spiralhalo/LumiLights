#version 130
#extension GL_EXT_gpu_shader4 : enable

#define POST_SHADER

#include lumi:shaders/lib/util.glsl
#include lumi:shaders/func/tonemap.glsl
#include lumi:shaders/common/lighting.glsl
#include lumi:shaders/common/userconfig.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/player.glsl
#include frex:shaders/api/view.glsl

#define VERTEX_SHADER

/*******************************************************
 *  lumi:shaders/post/common/header.glsl               *
 *******************************************************/

uniform ivec2 frxu_size;
uniform int frxu_lod;
varying vec2 v_texcoord;
varying vec3 v_skycolor;
varying vec3 v_up;

#ifdef VERTEX_SHADER
// const vec3 day_sky = vec3(0.52, 0.69, 1.0);
// const vec3 day_fog = vec3(0.75, 0.84375, 1.0);

vec3 hdr_skyColor()
{
    vec3 skyColor;
     //TODO: blindness transition still broken with custom sky / orange
    bool customOverworldColor =
        frx_worldFlag(FRX_WORLD_IS_OVERWORLD)
        && !frx_viewFlag(FRX_CAMERA_IN_FLUID)
        && !frx_playerHasEffect(FRX_EFFECT_BLINDNESS);

    if (customOverworldColor) {
        #ifdef TRUE_DARKNESS_MOONLIGHT
            const vec3 ngtc = vec3(0.0);
        #else
            const vec3 ngtc = NIGHT_SKY_COLOR;
        #endif
        const vec3 dayc = DAY_SKY_COLOR;

        const int len = 4;
        const vec3 colors[len] =  vec3[]( ngtc, dayc, dayc, ngtc);
        const float times[len] = float[](-0.03, 0.01, 0.49, 0.53);

        float horizonTime = frx_worldTime() < 0.75 ? frx_worldTime():frx_worldTime() - 1.0; // [-0.25, 0.75]

        if (horizonTime <= times[0]) {
            skyColor = colors[0];
        } else {
            int i = 1;
            while (horizonTime > times[i] && i < len) i++;
            skyColor = mix(colors[i-1], colors[i], l2_clampScale(times[i-1], times[i], horizonTime));
        }

        vec3 grayScale = vec3(frx_luminance(skyColor));
        skyColor = mix(skyColor, grayScale, frx_rainGradient());
        skyColor *= 1.0 - frx_thunderGradient() * 0.5;
    } else {
        skyColor = hdr_gammaAdjust(frx_vanillaClearColor());
    }

    // vec3 grayScale = vec3(frx_luminance(skyColor));
    // skyColor = mix(skyColor, grayScale, frx_viewFlag(FRX_CAMERA_IN_WATER) ? 0.5 : 0.0);
    
    return skyColor;
}

vec3 ldr_skyColor()
{
    return ldr_tonemap3(hdr_skyColor());
}
#else
vec3 hdr_orangeSkyColor(vec3 original, vec3 viewDir) {
    bool customOverworldOrange =
        frx_worldFlag(FRX_WORLD_IS_OVERWORLD)
        && !frx_viewFlag(FRX_CAMERA_IN_FLUID)
        && !frx_worldFlag(FRX_WORLD_IS_MOONLIT)
        && !frx_playerHasEffect(FRX_EFFECT_BLINDNESS);
    if (customOverworldOrange) {

        //NB: only works if sun always rise from dead east instead of north/southeast etc.
        float vDotHorizon = max(0.0, dot(-viewDir, frx_normalModelMatrix()*vec3(sign(frx_skyLightVector().x), 0.0, 0.0)));

        float sunHorizonFactor = sqrt(l2_clampScale(0.25 /*BRUTE FORCED NUMBER*/, 0.0, frx_skyLightVector().y));
        sunHorizonFactor *= frx_skyLightTransitionFactor();

        float rainUnFactor = 1.0 - frx_rainGradient();

        return mix(original, ORANGE_SKY_COLOR, sunHorizonFactor * vDotHorizon * vDotHorizon * rainUnFactor);
    } else {
        return original;
    }
}
#endif
