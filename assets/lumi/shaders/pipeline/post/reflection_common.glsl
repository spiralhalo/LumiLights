#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/pbr.glsl
#include lumi:reflection_config

/*******************************************************
 *  lumi:shaders/pipeline/post/reflection_common.frag  *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

vec2 coords_uv(vec3 view, mat4 projection)
{
	vec4 clip = projection * vec4(view, 1.0);
	clip.xyz /= clip.w;
	return clip.xy * 0.5 + 0.5;
}

float coords_depth(vec2 uv, in sampler2D target)
{
    return texture2DLod(target, uv, 0).r;
}

vec3 coords_view(vec2 uv, mat4 inv_projection, in sampler2D target)
{
    float depth = coords_depth(uv, target);
	vec3 clip = vec3(2.0 * uv - 1.0, 2.0 * depth - 1.0);
	vec4 view = inv_projection * vec4(clip, 1.0);
	return view.xyz / view.w;
}

vec3 coords_world(vec3 view, mat4 inv_view)
{
    return frx_cameraPos() + (inv_view * vec4(view, 1.0)).xyz;
}

vec3 coords_normal(vec2 uv, in sampler2D target)
{
	return 2.0 * texture2DLod(target, uv, 0).xyz - 1.0;
}

float skylight_adjust(float skyLight, float intensity)
{
    return l2_clampScale(0.03125, 1.0, skyLight) * intensity;
}

struct rt_Result
{
    vec2 reflected_uv;
    bool hit;
    int hits;
};

vec3 pbr_lightCalc(float roughness, vec3 f0, vec3 radiance, vec3 lightDir, vec3 viewDir, vec3 normal)
{
	vec3 halfway = normalize(viewDir + lightDir);
	vec3 fresnel = pbr_fresnelSchlick(pbr_dot(viewDir, halfway), f0);
	float NdotL = pbr_dot(normal, lightDir);

	return pbr_specularBRDF(roughness, radiance, halfway, lightDir, viewDir, normal, fresnel, NdotL);
}

rt_Result rt_reflection(
    vec3 ray_view, vec3 unit_view, vec3 normal, vec3 unit_march,
    vec2 start_uv, float init_ray_length, float max_ray_length, float length_multiplier, int constant_steps, int max_steps,
    mat3 normal_matrix, mat4 projection, mat4 inv_projection,
    in sampler2D reflector_depth, in sampler2D reflector_normal, in sampler2D reflected_depth, in sampler2D reflected_normal
)
{
    // float length_divisor = 1.0 / length_multiplier;

    vec3 ray = unit_march * init_ray_length;
    float current_ray_length = init_ray_length;
    vec2 current_uv;
    vec3 current_view;
    float delta_z;
    float hitbox_z;
    bool backface;
    vec3 reflectedNormal;
    
    int hits = 0;
    int steps = 0;
    int refine_steps = 0;
    while (steps < max_steps) {
        ray_view += ray;
        current_uv = coords_uv(ray_view, projection);
        current_view = coords_view(current_uv, inv_projection, reflected_depth);
        delta_z = current_view.z - ray_view.z;
        hitbox_z = current_ray_length;
        // TODO: handle diffuse (normal = 1.0, 1.0, 1.0) PROPERLY
        reflectedNormal = coords_normal(current_uv, reflected_normal);
        backface = dot(unit_march, normal_matrix * normalize(reflectedNormal)) > 0;
        if (delta_z > 0 && !backface) {
            hits ++;
            
            #ifdef REFLECTION_USE_HITBOX
                if (delta_z < hitbox_z) {
            #endif

            //refine
            while (current_ray_length > init_ray_length * init_ray_length && refine_steps < max_steps) {
                ray = abs(delta_z) * unit_march;
                current_ray_length = abs(delta_z);
                if (ray_view.z > current_view.z) ray_view += ray;
                else ray_view -= ray;
                current_uv = coords_uv(ray_view, projection);
                current_view = coords_view(current_uv, inv_projection, reflected_depth);
                delta_z = current_view.z - ray_view.z;
                refine_steps ++;
            }
            return rt_Result(current_uv, true, hits);

            #ifdef REFLECTION_USE_HITBOX
                }
            #endif
        }
        if (steps > constant_steps && current_ray_length < max_ray_length) {
            ray *= length_multiplier;
            current_ray_length *= length_multiplier;
        }
        steps ++;
    }
    return rt_Result(current_uv, false, hits);
}
