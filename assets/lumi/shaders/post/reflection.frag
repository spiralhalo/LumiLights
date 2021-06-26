#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/post/common/reflection.glsl

/*******************************************************
 *  lumi:shaders/post/reflection.frag         *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_source_color;
uniform sampler2D u_source_combine;
uniform sampler2D u_source_albedo;
uniform sampler2D u_source_depth;
uniform sampler2D u_light_source;
uniform sampler2D u_normal_source;
uniform sampler2D u_normal_micro_source;
uniform sampler2D u_material_source;

uniform sampler2D u_target_color;
uniform sampler2D u_target_combine;
uniform sampler2D u_target_depth;
uniform sampler2D u_normal_target;

#ifndef USING_OLD_OPENGL
out vec4[1] fragColor;
#endif

void main()
{
    vec4 source_base = texture(u_source_color, v_texcoord);
    vec3 source_albedo = texture(u_source_albedo, v_texcoord).rgb;
    float source_roughness = texture(u_material_source, v_texcoord).x;
    rt_color_depth source_source = work_on_pair(source_base, source_albedo, u_source_depth, u_light_source, u_normal_source, u_normal_micro_source, u_material_source, u_source_color, u_source_combine, u_source_depth, u_normal_source, 1.0, true);
    #if REFLECTION_PROFILE != REFLECTION_PROFILE_NONE
        rt_color_depth source_target = work_on_pair(source_base, source_albedo, u_source_depth, u_light_source, u_normal_source, u_normal_micro_source, u_material_source, u_target_color, u_target_combine, u_target_depth, u_normal_target, 0.0, true);
        // blend
        vec3 reflection_color = (source_source.depth < source_target.depth)
            ? source_source.color.rgb * source_source.color.a
            : (source_source.color.rgb * (1.0 - source_target.color.a) + source_target.color.rgb * source_target.color.a);
        // with anti-banding
        fragColor[0] = vec4(sqrt(clamp(reflection_color, 0., 1.)), source_roughness);
    #else
        // with anti-banding
        fragColor[0] = vec4(sqrt(clamp(source_source.color.rgb, 0., 1.)), source_roughness);
    #endif
}
