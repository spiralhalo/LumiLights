#include lumi:shaders/post/common/header.glsl

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
uniform sampler2D u_translucent_color;

uniform sampler2D u_ao;
uniform sampler2D u_glint;
uniform sampler2DArrayShadow u_shadow;

out vec4[2] fragColor;

#include lumi:shaders/post/common/shading.glsl

void main()
{
    tileJitter = getRandomFloat(v_texcoord, frxu_size); //JITTER_STRENGTH;
    float bloom1;
    float ssao = texture(u_ao, v_texcoord).r;
    float translucentDepth = texture(u_translucent_depth, v_texcoord).r;
    vec4 a1 = hdr_shaded_color(v_texcoord, u_solid_color, u_solid_depth, u_light_solid, u_normal_solid, u_material_solid, u_misc_solid, ssao, false, translucentDepth, bloom1);
    fragColor[0] = a1;
    
    float bloomTransmittance = translucentDepth < texture(u_solid_depth, v_texcoord).r
        ? (1.0 - texture(u_translucent_color, v_texcoord).a)
        : 1.0;
    bloom1 *= bloomTransmittance;

    fragColor[1] = vec4(bloom1, 0.0, 0.0, 1.0);
}


