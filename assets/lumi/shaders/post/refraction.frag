#include lumi:shaders/post/common/header.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/refraction.frag
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

uniform sampler2D u_solid_color;
uniform sampler2D u_solid_depth;
uniform sampler2D u_normal_solid;

uniform sampler2D u_translucent_depth;
uniform sampler2D u_light_translucent;
uniform sampler2D u_normal_translucent;

out vec4 fragColor;

vec2 coords_uv(vec3 view, mat4 projection)
{
	vec4 clip = projection * vec4(view, 1.0);
	clip.xyz /= clip.w;
	return clip.xy * 0.5 + 0.5;
}

vec3 coords_view_source(vec2 uv, mat4 inv_projection)
{
	float depth = texture(u_translucent_depth, uv).r;
	vec3 clip = vec3(2.0 * uv - 1.0, 2.0 * depth - 1.0);
	vec4 view = inv_projection * vec4(clip, 1.0);
	return view.xyz / view.w;
}

vec3 coords_view(vec2 uv, mat4 inv_projection)
{
	float depth = texture(u_solid_depth, uv).r;
	vec3 clip = vec3(2.0 * uv - 1.0, 2.0 * depth - 1.0);
	vec4 view = inv_projection * vec4(clip, 1.0);
	return view.xyz / view.w;
}

vec3 coords_normal_source(vec2 uv)
{
	return frx_normalModelMatrix() * (2.0 * texture(u_normal_translucent, uv).xyz - 1.0);
}

vec3 coords_normal(vec2 uv)
{
	return frx_normalModelMatrix() * (2.0 * texture(u_normal_solid, uv).xyz - 1.0);
}

float skylight_adjust(float skyLight, float intensity)
{
	return l2_clampScale(0.03125, 1.0, skyLight) * intensity;
}

struct rt_Result
{
	vec2 refracted_uv;
	float fresnel;
	bool hit;
	vec3 unit_march;
};

rt_Result rt_refraction(vec2 start_uv, float init_ray_length, float max_ray_length, float length_multiplier, int max_steps,
				   mat4 projection, mat4 inv_projection);
				   
float blendScreen(float base, float blend) {
	return 1.0-((1.0-base)*(1.0-blend));
}

vec3 blendScreen(vec3 base, vec3 blend) {
	return vec3(blendScreen(base.r,blend.r),blendScreen(base.g,blend.g),blendScreen(base.b,blend.b));
}

void main()
{
	float solid_depth = texture(u_solid_depth, v_texcoord).r;
	float translucent_depth = texture(u_translucent_depth, v_texcoord).r;
	float sky_light = texture(u_light_translucent, v_texcoord).z;
	if (translucent_depth < solid_depth) {
		rt_Result result = rt_refraction(v_texcoord, 0.25, 256.0, 2.0, 20, frx_projectionMatrix, frx_inverseProjectionMatrix);
		if (result.refracted_uv.x < 0.0 || result.refracted_uv.y < 0.0 || result.refracted_uv.x > 1.0 || result.refracted_uv.y > 1.0) {
			fragColor = texture(u_solid_color, v_texcoord);
		} else if (!result.hit) {
			vec4 refracted = texture(u_solid_color, result.refracted_uv);
			if (refracted.a == 0.0) {
				fragColor = refracted;
			} else {
				fragColor = texture(u_solid_color, v_texcoord);
			}
		} else {
			fragColor = texture(u_solid_color, result.refracted_uv);
		}
	} else {
		fragColor = texture(u_solid_color, v_texcoord);
	}
}

rt_Result rt_refraction(vec2 start_uv, float init_ray_length, float max_ray_length, float length_multiplier, int max_steps,
				   mat4 projection, mat4 inv_projection)
{
	// float length_divisor = 1.0 / length_multiplier;
	vec3 ray_view = coords_view_source(start_uv, inv_projection);
	vec3 unit_view = normalize(-ray_view);
	vec3 unit_march = refract(-unit_view, coords_normal_source(start_uv), 0.8);
	vec3 halfway = normalize(unit_view + unit_march);
	float fresnel = pow(1.0 - clamp(dot(unit_view, halfway), 0.0, 1.0), 5.0);

	vec3 ray = unit_march * init_ray_length;
	float current_ray_length = init_ray_length;
	vec2 current_uv;
	vec3 current_view;
	float delta_z;
	float hitbox_z;
	bool backface;
	
	int steps = 0;
	int refine_steps = 0;
	while (current_ray_length < max_ray_length && steps < max_steps) {
		ray_view += ray;
		current_uv = coords_uv(ray_view, projection);
		current_view = coords_view(current_uv, inv_projection);
		delta_z = current_view.z - ray_view.z;
		hitbox_z = current_ray_length;
		// backface = dot(unit_march, coords_normal(current_uv)) > 0;
		if (delta_z > 0 && delta_z < hitbox_z /*&& !backface*/) {
			//refine
			while (current_ray_length > init_ray_length && refine_steps < max_steps) {
				ray = abs(delta_z) * unit_march;
				current_ray_length = abs(delta_z);
				if (ray_view.z > current_view.z) ray_view += ray;
				else ray_view -= ray;
				current_uv = coords_uv(ray_view, projection);
				current_view = coords_view(current_uv, inv_projection);
				delta_z = current_view.z - ray_view.z;
				refine_steps ++;
			}
			return rt_Result(current_uv, fresnel, true, unit_march);
		}
		// if (steps > constantSteps) {
		ray *= length_multiplier;
		current_ray_length *= length_multiplier;
		// }
		steps ++;
	}
	// Sky reflection
	// if (sky(current_uv) && ray_view.z < 0) return current_uv;
	return rt_Result(current_uv, fresnel, false, unit_march);
}
