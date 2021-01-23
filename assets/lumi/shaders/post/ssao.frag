#include lumi:shaders/post/common.glsl
#include lumi:shaders/lib/ssao.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/context/global/lighting.glsl

/*******************************************************
 *  lumi:shaders/post/ssao.frag               *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

#if AMBIENT_OCCLUSION == AMBIENT_OCCLUSION_SSAO
uniform sampler2D u_normal;
uniform sampler2D u_depth;

const float RADIUS = 1.0;
const float BIAS = 0.5;
const float INTENSITY = 5.0;

void main()
{
    // Modest performance saving by skipping the sky
    if (texture2D(u_depth, v_texcoord).r == 1.0) {
        gl_FragData[0] = vec4(1.0, 0.0, 0.0, 1.0);
    } else {
        float random = v_texcoord.x*v_texcoord.y;
        float ssao = calc_ssao(
            u_normal, u_depth, frx_normalModelMatrix(), frx_inverseProjectionMatrix(), frx_inverseViewProjectionMatrix(), frxu_size, 4,
            v_texcoord, RADIUS, BIAS, INTENSITY);
        gl_FragData[0] = vec4(ssao, 0.0, 0.0, 1.0);
    }
}
#else
void main()
{
    gl_FragData[0] = vec4(1.0, 0.0, 0.0, 1.0);
}
#endif
