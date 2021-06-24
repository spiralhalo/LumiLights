#include lumi:shaders/post/common/header.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/func/tile_noise.glsl

/*******************************************************
 *  lumi:shaders/post/one_filter.frag         *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_source;
uniform sampler2D u_depth;

in vec2 v_invSize;

out vec4 fragColor;

#ifdef SSAO_ENABLED
const int size = 4;
void main()
{
    fragColor = vec4(tile_denoise1_depth(v_texcoord, u_source, u_depth, v_invSize, size), 0.0, 0.0, 1.0);
}
#else
void main()
{
    fragColor = texture(u_source, v_texcoord);
}
#endif
