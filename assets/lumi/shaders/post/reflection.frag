#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/common/userconfig.glsl

#define PASS_REFLECTION_PROFILE REFLECTION_PROFILE

#ifdef REFLECT_CLOUDS
	#define PASS_REFLECT_CLOUDS
#endif

#include lumi:shaders/post/common/reflection.glsl

/*******************************************************
 *  lumi:shaders/post/reflection.frag
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

uniform sampler2D u_source_color;
uniform sampler2D u_source_albedo;
uniform sampler2D u_source_depth;
uniform sampler2D u_light_source;
uniform sampler2D u_normal_source;
uniform sampler2D u_normal_micro_source;
uniform sampler2D u_material_source;

uniform sampler2D u_target_color;
uniform sampler2D u_target_depth;
uniform sampler2D u_light_target;
uniform sampler2D u_normal_target;

out vec4 fragColor[2];

void main()
{
	vec4 source_base = texture(u_source_color, v_texcoord);
	vec3 source_albedo = hdr_fromGamma(texture(u_source_albedo, v_texcoord).rgb);
	float source_roughness = texture(u_material_source, v_texcoord).x;
	rt_ColorDepthBloom source_source = work_on_pair(source_base, source_albedo, u_source_depth, u_light_source, u_normal_source, u_normal_micro_source, u_material_source, u_source_color, u_source_depth, u_light_source, u_normal_source, 1.0, true);
	#if REFLECTION_PROFILE != REFLECTION_PROFILE_NONE
		rt_ColorDepthBloom source_target = work_on_pair(source_base, source_albedo, u_source_depth, u_light_source, u_normal_source, u_normal_micro_source, u_material_source, u_target_color, u_target_depth, u_light_target, u_normal_target, 0.0, true);
		// blend
		vec4 reflection_color = (source_source.depth < source_target.depth)
			? (vec4(source_source.color.rgb, source_source.bloom) * source_source.color.a
				+ vec4(source_target.color.rgb, source_target.bloom) * (1.0 - source_source.color.a))
			: (vec4(source_source.color.rgb, source_source.bloom) * (1.0 - source_target.color.a)
				+ vec4(source_target.color.rgb, source_target.bloom) * source_target.color.a);
		// with anti-banding
		fragColor[0] = vec4(sqrt(clamp(reflection_color.rgb, 0., 1.)), source_roughness);
		fragColor[1] = vec4(reflection_color.a, 0.0, 0.0, 1.0);
	#else
		// with anti-banding
		fragColor[0] = vec4(sqrt(clamp(source_source.color.rgb, 0., 1.)), source_roughness);
		fragColor[1] = vec4(source_source.bloom, 0.0, 0.0, 1.0);
	#endif
}
