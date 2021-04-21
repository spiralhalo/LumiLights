#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/lib/ssao.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/common/lighting.glsl
#include lumi:shaders/common/userconfig.glsl

/*******************************************************
 *  lumi:shaders/post/ssao.frag               *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_normal;
uniform sampler2D u_depth;

#ifndef USING_OLD_OPENGL
out vec4[1] fragColor;
#endif

#if AMBIENT_OCCLUSION == AMBIENT_OCCLUSION_SSAO
const float RADIUS = 1.0;
const float BIAS = 0.5;
const float INTENSITY = 5.0;
#endif

void main()
{
#if AMBIENT_OCCLUSION == AMBIENT_OCCLUSION_SSAO
    // Modest performance saving by skipping the sky
    if (texture(u_depth, v_texcoord).r == 1.0) {
        fragColor[0] = vec4(1.0, 0.0, 0.0, 1.0);
    } else {
        float random = v_texcoord.x*v_texcoord.y;
        float ssao = calc_ssao(
            u_normal, u_depth, frx_normalModelMatrix(), frx_inverseProjectionMatrix(), frxu_size, 
            v_texcoord, RADIUS, BIAS, INTENSITY);
        fragColor[0] = vec4(ssao, 0.0, 0.0, 1.0);
    }
#else
    fragColor[0] = vec4(1.0, 0.0, 0.0, 1.0);
#endif
}
