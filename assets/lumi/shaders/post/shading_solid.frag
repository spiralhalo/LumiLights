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

/* More samplers in /common/shading.glsl */

out vec4[2] fragColor;

#include lumi:shaders/post/common/shading.glsl

void main()
{
    tileJitter = getRandomFloat(u_blue_noise, v_texcoord, frxu_size); //JITTER_STRENGTH;
    float bloom1;
#ifdef SSAO_ENABLED
    vec4 ssao = texture(u_ao, v_texcoord);
#else
    vec4 ssao = vec4(0.0, 0.0, 0.0, 1.0);
#endif
    float translucentDepth = texture(u_translucent_depth, v_texcoord).r;
    vec4 a1 = hdr_shaded_color(v_texcoord, u_solid_color, u_solid_depth, u_light_solid, u_normal_solid, u_material_solid, u_misc_solid, ssao.rgb, ssao.a, false, translucentDepth, bloom1);
    fragColor[0] = a1;
    
    float translucentAlpha = texture(u_translucent_color, v_texcoord).a;
    float bloomTransmittance = translucentDepth < texture(u_solid_depth, v_texcoord).r
          ? (1.0 - translucentAlpha * translucentAlpha)
          : 1.0;

    fragColor[1] = vec4(bloom1 * bloomTransmittance, 0.0, 0.0, 1.0);
}


