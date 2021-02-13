#version 130
#extension GL_EXT_gpu_shader4 : enable

#define POST_SHADER

#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/tonemap.glsl
#include lumi:shaders/context/global/lighting.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/player.glsl

#define VERTEX_SHADER

/*******************************************************
 *  lumi:shaders/context/post/header.glsl              *
 *******************************************************/

uniform ivec2 frxu_size;
uniform int frxu_lod;
varying vec2 v_texcoord;
varying vec3 v_skycolor;
varying vec3 v_up;

#ifdef VERTEX_SHADER
const vec3 day_sky = vec3(0.52, 0.69, 1.0);
const vec3 day_fog = vec3(0.75, 0.84375, 1.0);

vec3 hdr_skyColor()
{
    vec3 skyColor;
    bool customOverworldColor =
        frx_isWorldTheOverworld()
        && !frx_playerFlag(FRX_PLAYER_EYE_IN_WATER);

    if (customOverworldColor) {
        #ifdef TRUE_DARKNESS_MOONLIGHT
            const vec3 ngtc = vec3(0.0);
        #else
            const vec3 ngtc = NIGHT_SKY_COLOR;
        #endif
        const vec3 dayc = DAY_SKY_COLOR;

        const int len = 4;
        const vec3 colors[len] =  vec3[](ngtc, dayc, dayc, ngtc);
        const float times[len] = float[](0.00, 0.02, 0.48, 0.50);

        int i = 1;
        while (frx_worldTime() > times[i] && i < len) i++;
        skyColor = mix(colors[i-1], colors[i], l2_clampScale(times[i-1], times[i], frx_worldTime()));
    } else {
        skyColor = frx_vanillaClearColor();
    }

    vec3 grayScale = vec3(frx_luminance(skyColor));
    // skyColor = mix(skyColor, grayScale, frx_playerFlag(FRX_PLAYER_EYE_IN_WATER) ? 0.5 : 0.0);
    
    return hdr_gammaAdjust(skyColor);
}

vec3 ldr_skyColor()
{
    return ldr_tonemap3(hdr_skyColor());
}
#endif
