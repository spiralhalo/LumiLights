#include frex:shaders/api/world.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/func/tile_noise.glsl                  *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

const vec3 tile_randomVec[16] = vec3[16](
    vec3(0.5, 0.3333333333333333, 0.25), 
    vec3(0.25, 0.6666666666666666, 0.5), 
    vec3(0.75, 0.1111111111111111, 0.75),
    vec3(0.125, 0.4444444444444444, 0.0625),
    vec3(0.625, 0.7777777777777777, 0.3125),
    vec3(0.375, 0.2222222222222222, 0.5625),
    vec3(0.875, 0.5555555555555556, 0.8125),
    vec3(0.0625, 0.8888888888888888, 0.125),
    vec3(0.5625, 0.037037037037037035, 0.375),
    vec3(0.3125, 0.37037037037037035, 0.625),
    vec3(0.8125, 0.7037037037037037, 0.875),
    vec3(0.1875, 0.14814814814814814, 0.1875),
    vec3(0.6875, 0.48148148148148145, 0.4375),
    vec3(0.4375, 0.8148148148148147, 0.6875),
    vec3(0.9375, 0.25925925925925924, 0.9375),
    vec3(0.03125, 0.5925925925925926, 0.015625)
);

#define BLUE_NOISE_RES 256.
const float BLUE_NOISE_SPEED = BLUE_NOISE_RES * BLUE_NOISE_RES;
const float BLUE_NOISE_RES_RCP = 1. / BLUE_NOISE_RES;

vec3 getRandomVec(sampler2D blueNoiseTex, vec2 uv, vec2 texSize)
{
#ifdef TAA_ENABLED
    uv += frx_renderSeconds();
#endif
#if NOISE_MODE == NOISE_MODE_HALTON
    ivec2 texelPos = ivec2(mod(uv * texSize, 4.0));
    return tile_randomVec[texelPos.x + texelPos.y * 4];
#else
#if __VERSION__ < 130
    vec2 noiseUv = mod(uv * texSize, BLUE_NOISE_RES) * BLUE_NOISE_RES_RCP;
    return texture2D(blueNoiseTex, noiseUv).rgb;
#else
    ivec2 texelPos = ivec2(mod(uv * texSize, BLUE_NOISE_RES));
    return texelFetch(blueNoiseTex, texelPos, 0).rgb;
#endif
#endif
}

float getRandomFloat(sampler2D blueNoiseTex, vec2 uv, vec2 texSize)
{
#ifdef TAA_ENABLED
    uv += frx_renderSeconds();
#endif
#if NOISE_MODE == NOISE_MODE_HALTON
    ivec2 texelPos = ivec2(mod(uv * texSize, 4.0));
    return tile_randomVec[texelPos.x + texelPos.y * 4].x;
#else
#if __VERSION__ < 130
    vec2 noiseUv = mod(uv * texSize, BLUE_NOISE_RES) * BLUE_NOISE_RES_RCP;
    return texture2D(blueNoiseTex, noiseUv).r;
#else
    ivec2 texelPos = ivec2(mod(uv * texSize, BLUE_NOISE_RES));
    return texelFetch(blueNoiseTex, texelPos, 0).r;
#endif
#endif
}

vec4 tile_denoise(vec2 uv, sampler2D scolor, vec2 inv_size, int noise_size)
{
    vec4 accum = vec4(0.0);

    vec2 target_uv;

    int count = 0;
    for (int i = -noise_size; i <= noise_size; i++) {
        for (int j = -noise_size; j <= noise_size; j++) {
            target_uv = uv + vec2(i, j) * inv_size;
            accum += texture(scolor, target_uv);
            count ++;
        }
    }
    return accum / float(count);
}

const float depth_threshold = 0.0001;
vec4 tile_denoise_depth_alpha(vec2 uv, sampler2D scolor, sampler2D sdepth, vec2 inv_size, int noise_size)
{
    vec4 accum = vec4(0.0);
    float origin_depth = ldepth(texture(sdepth, uv).r);
    float origin_a = texture(scolor, uv).a;

    float target_depth;
    vec4 target_color;
    float delta_depth;
    vec2 target_uv;

    int count = 0;
    for (int i = -noise_size; i <= noise_size; i++) {
        for (int j = -noise_size; j <= noise_size; j++) {
            target_uv = uv + vec2(i, j) * inv_size;
            target_depth = ldepth(texture(sdepth, target_uv).r);
            target_color = texture(scolor, target_uv);
            delta_depth = abs(target_depth - origin_depth);
            if (delta_depth <= depth_threshold && origin_a == target_color.a) {
                accum += target_color;
                count ++;
            }
        }
    }
    return accum / float(count);
}

float tile_denoise1_depth(vec2 uv, sampler2D scolor, sampler2D sdepth, vec2 inv_size, int noise_size)
{
    float accum = 0.0;
    float origin_depth = ldepth(texture(sdepth, uv).r);

    float target_depth;
    float delta_depth;
    vec2 target_uv;

    int count = 0;
    for (int i = -noise_size; i <= noise_size; i++) {
        for (int j = -noise_size; j <= noise_size; j++) {
            target_uv = uv + vec2(i, j) * inv_size;
            target_depth = ldepth(texture(sdepth, target_uv).r);
            delta_depth = abs(target_depth - origin_depth);
            if (delta_depth <= depth_threshold) {
                accum += texture(scolor, target_uv).r;
                count ++;
            }
        }
    }
    return accum / float(count);
}
