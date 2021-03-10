#include lumi:shaders/context/post/header.glsl

/*******************************************************
 *  lumi:shaders/post/shading.frag                     *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_solid_color;
uniform sampler2D u_solid_depth;
uniform sampler2D u_light_solid;
uniform sampler2D u_normal_solid;
uniform sampler2D u_material_solid;
uniform sampler2D u_misc_solid;

uniform sampler2D u_translucent_depth;

uniform sampler2D u_ao;
uniform sampler2DArrayShadow u_shadow;

#include lumi:shaders/context/post/shading.glsl

void main()
{
    tileJitter = tile_noise_1d(v_texcoord, frxu_size, 3); //CLOUD_MARCH_JITTER_STRENGTH;
    float bloom1;
    float ssao = texture2D(u_ao, v_texcoord).r;
    float translucentDepth = texture2D(u_translucent_depth, v_texcoord).r;
    vec4 a1 = hdr_shaded_color(v_texcoord, u_solid_color, u_solid_depth, u_light_solid, u_normal_solid, u_material_solid, u_misc_solid, ssao, false, translucentDepth, bloom1);
    gl_FragData[0] = a1;
    gl_FragData[3] = vec4(bloom1, 0.0, 0.0, 1.0);
}


