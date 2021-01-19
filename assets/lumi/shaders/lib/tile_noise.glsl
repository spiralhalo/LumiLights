#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/lib/tile_noise.glsl                   *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

vec3 tile_noise_3d(vec2 uv, vec2 tex_size, int noise_size)
{
    float tile_size = noise_size * 2.0 + 1.0;
    vec2 seed = fract(uv * (tex_size / tile_size));
    return vec3(frx_noise2d(seed.xx * seed.yy), frx_noise2d(seed.xy), frx_noise2d(seed.yx));
}

const float depth_threshold = 0.0001;
vec4 tile_denoise_depth(vec2 uv, sampler2D scolor, sampler2D sdepth, vec2 inv_size, int noise_size)
{
    vec4 accum = vec4(0.0);
    float origin_depth = ldepth(texture2D(sdepth, uv).r);

    float target_depth;
    float delta_depth;
    vec2 target_uv;

    int count = 0;
    for (int i = -noise_size; i <= noise_size; i++) {
        for (int j = -noise_size; j <= noise_size; j++) {
            target_uv = uv + vec2(i, j) * inv_size;
            target_depth = ldepth(texture2D(sdepth, target_uv).r);
            delta_depth = abs(target_depth - origin_depth);
            if (delta_depth <= depth_threshold) {
                accum += texture2D(scolor, target_uv);
                count ++;
            }
        }
    }
    return accum / float(count);
}

float tile_denoise1_depth(vec2 uv, sampler2D scolor, sampler2D sdepth, vec2 inv_size, int noise_size)
{
    float accum = 0.0;
    float origin_depth = ldepth(texture2D(sdepth, uv).r);

    float target_depth;
    float delta_depth;
    vec2 target_uv;

    int count = 0;
    for (int i = -noise_size; i <= noise_size; i++) {
        for (int j = -noise_size; j <= noise_size; j++) {
            target_uv = uv + vec2(i, j) * inv_size;
            target_depth = ldepth(texture2D(sdepth, target_uv).r);
            delta_depth = abs(target_depth - origin_depth);
            if (delta_depth <= depth_threshold) {
                accum += texture2D(scolor, target_uv).r;
                count ++;
            }
        }
    }
    return accum / float(count);
}
