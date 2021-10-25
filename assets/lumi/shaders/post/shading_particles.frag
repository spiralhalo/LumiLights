#include lumi:shaders/post/common/header.glsl

#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/func/pbr_shading.glsl
#include lumi:shaders/func/tonemap.glsl
#include lumi:shaders/post/common/fog.glsl

/*******************************************************
 *  lumi:shaders/post/shading_particles.frag
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

uniform sampler2D u_particles_color;
uniform sampler2D u_particles_depth;
uniform sampler2D u_light_particles;

in float v_blindness;
out vec4 fragColor;

vec4 ldr_shaded_particle(vec2 uv, sampler2D scolor, sampler2D sdepth, sampler2D slight, float ec)
{
	vec4 a = texture(scolor, uv);

	if (a.a == 0.) return vec4(0.);

	float depth = texture(sdepth, uv).r;

	vec4  viewPos = frx_inverseProjectionMatrix() * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	viewPos.xyz /= viewPos.w;
	viewPos.w = 1.0;

	vec3  normal   = normalize(-viewPos.xyz) * frx_normalModelMatrix();
	vec4  light    = texture(slight, uv);
	vec3  modelPos = (frx_inverseViewMatrix() * viewPos).xyz;
	float bloom_ignored = 0.0;

	pbr_shading(a, bloom_ignored, viewPos.xyz, light.xyy, normal, 1.0, 0.0, 0.0, false, false);

	a.a = min(1.0, a.a);

	if (a.a != 0.0 && depth != 1.0) {
		a = fog(lightmapRemap(light.y), ec, v_blindness, a, modelPos, bloom_ignored);
	}

	return ldr_tonemap(a);
}

void main()
{
	float ec = exposureCompensation();
	vec4 a2  = ldr_shaded_particle(v_texcoord, u_particles_color, u_particles_depth, u_light_particles, ec);

	fragColor = a2;
}
