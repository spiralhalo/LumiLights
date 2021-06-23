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
uniform sampler2D u_light;
uniform sampler2D u_color;
uniform sampler2D u_blue_noise;

out vec4 fragColor;

#ifdef SSAO_ENABLED
const float RADIUS = 2.0;
const float BIAS = 0.3;
const float INTENSITY = 2.5;
#endif

void main()
{
#ifdef SSAO_ENABLED
    // Modest performance saving by skipping the sky
    if (texture(u_depth, v_texcoord).r == 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        fragColor = calcSSAO(
            u_normal, u_depth, u_light, u_color, u_blue_noise,
            frx_normalModelMatrix(), frx_inverseProjectionMatrix(), frxu_size, 
            v_texcoord, RADIUS, RADIUS * 0.5, BIAS, INTENSITY);
    }
#else
    fragColor = vec4(0.0, 0.0, 0.0, 1.0);
#endif
}
