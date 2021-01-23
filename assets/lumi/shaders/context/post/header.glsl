#version 130
#extension GL_EXT_gpu_shader4 : enable

#define POST_SHADER

#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/tonemap.glsl
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
        // TODO: better color calc instead of using camera-based overworld fog color
        vec3 clear = frx_vanillaClearColor();
        float distanceToFog = distance(normalize(clear), normalize(day_fog));
        skyColor = mix(clear, day_sky, l2_clampScale(0.1, 0.05, distanceToFog));
    } else skyColor = frx_vanillaClearColor();

    vec3 grayScale = vec3(frx_luminance(skyColor));
    // skyColor = mix(skyColor, grayScale, frx_playerFlag(FRX_PLAYER_EYE_IN_WATER) ? 0.5 : 0.0);
    
    return hdr_gammaAdjust(skyColor);
}

vec3 ldr_skyColor()
{
    return ldr_tonemap3(hdr_skyColor());
}
#endif
