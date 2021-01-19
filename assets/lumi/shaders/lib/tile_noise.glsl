#include frex:shaders/lib/math.glsl

/*******************************************************
 *  lumi:shaders/lib/tile_noise.glsl                   *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

vec3 tile_noise_3d(vec2 uv, vec2 tex_size, float noise_size)
{
    float tile_size = noise_size * 2.0 + 1.0;
    vec2 seed = fract(uv * (tex_size / tile_size));
    return vec3(frx_noise2d(seed.xx * seed.yy), frx_noise2d(seed.xy), frx_noise2d(seed.yx));
}
