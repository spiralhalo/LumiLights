#include lumi:shaders/pipeline/post/common.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/pbr_shading.glsl
#include lumi:reflection_config

/*******************************************************
 *  lumi:shaders/pipeline/post/reflection.frag         *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_solid_color;
uniform sampler2D u_solid_albedo;
uniform sampler2D u_solid_depth;
uniform sampler2D u_light_solid;
uniform sampler2D u_normal_solid;
uniform sampler2D u_material_solid;

uniform sampler2D u_translucent_color;
uniform sampler2D u_translucent_albedo;
uniform sampler2D u_translucent_depth;
uniform sampler2D u_light_translucent;
uniform sampler2D u_normal_translucent;
uniform sampler2D u_material_translucent;

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
};

rt_Result rt_reflection(
    vec3 ray_view, vec3 unit_view, vec3 normal, vec3 unit_march,
    vec2 start_uv, float init_ray_length, float max_ray_length, float length_multiplier, int constant_steps, int max_steps,
    mat3 normal_matrix, mat4 projection, mat4 inv_projection,
    in sampler2D reflector_depth, in sampler2D reflector_normal, in sampler2D reflected_depth, in sampler2D reflected_normal
);

vec4 work_on_pair(
    in vec4 base_color,
    in vec3 albedo,
    in sampler2D reflector_depth,
    in sampler2D reflector_light,
    in sampler2D reflector_normal,
    in sampler2D reflector_material,

    in sampler2D reflected_color,
    in sampler2D reflected_depth,
    in sampler2D reflected_normal,
    float fallback
);

bool diffuseCheck(vec3 normal)
{
    return (normal.x + normal.y + normal.z < 2.5);
}

void main()
{
    vec4 solid_base = texture2D(u_solid_color, v_texcoord);
    vec3 solid_albedo = texture2D(u_solid_albedo, v_texcoord).rgb;
    vec4 translucent_base = texture2D(u_translucent_color, v_texcoord);
    vec3 translucent_albedo = texture2D(u_translucent_albedo, v_texcoord).rgb;
    vec4 solid_solid       = work_on_pair(solid_base, solid_albedo, u_solid_depth, u_light_solid, u_normal_solid, u_material_solid, u_solid_color, u_solid_depth, u_normal_solid, 1.0);
    vec4 solid_translucent = work_on_pair(solid_base, solid_albedo, u_solid_depth, u_light_solid, u_normal_solid, u_material_solid, u_translucent_color, u_translucent_depth, u_normal_translucent, 0.0);
    vec4 translucent_solid       = work_on_pair(translucent_base, translucent_albedo, u_translucent_depth, u_light_translucent, u_normal_translucent, u_material_translucent, u_solid_color, u_solid_depth, u_normal_solid, 1.0);
    vec4 translucent_translucent = work_on_pair(translucent_base, translucent_albedo, u_translucent_depth, u_light_translucent, u_normal_translucent, u_material_translucent, u_translucent_color, u_translucent_depth, u_normal_translucent, 0.0);
    float roughness1 = texture2DLod(u_material_solid, v_texcoord, 0).x;
    float roughness2 = texture2DLod(u_material_translucent, v_texcoord, 0).x;
    gl_FragData[0] = vec4(solid_solid.rgb * (1.0 - solid_translucent.a) + solid_translucent.rgb, roughness1);
    gl_FragData[1] = vec4(translucent_solid.rgb * (1.0 - translucent_translucent.a) + translucent_translucent.rgb, roughness2);
}

const float JITTER_STRENGTH = 0.2;

vec4 work_on_pair(
    in vec4 base_color,
    in vec3 albedo,
    in sampler2D reflector_depth,
    in sampler2D reflector_light,
    in sampler2D reflector_normal,
    in sampler2D reflector_material,

    in sampler2D reflected_color,
    in sampler2D reflected_depth,
    in sampler2D reflected_normal,
    float fallback
)
{
    vec4 noreturn = vec4(0.0);
    vec3 dummy    = vec3(0.0);
    vec4 material = texture2DLod(reflector_material, v_texcoord, 0);
    vec3 worldNormal = coords_normal(v_texcoord, reflector_normal);
    float gloss   = 1.0 - material.x;
    if (gloss > 0.01 && material.a > 0.0 && diffuseCheck(worldNormal)) {
        vec3 ray_view  = coords_view(v_texcoord, frx_inverseProjectionMatrix(), reflector_depth);
        vec3 ray_world = coords_world(ray_view, frx_inverseViewMatrix());
        vec3 jitter    = 2.0 * vec3(frx_noise2d(ray_world.yz), frx_noise2d(ray_world.zx), frx_noise2d(ray_world.xy)) - 1.0;
        vec3 normal    = frx_normalModelMatrix() * normalize(worldNormal);
        float roughness2 = material.x * material.x;
        // if (ray_view.y < normal.y) return noreturn;
        vec3 unit_view  = normalize(-ray_view);
        vec3 unit_march = normalize(reflect(-unit_view, normal) + mix(vec3(0.0, 0.0, 0.0), jitter * JITTER_STRENGTH, roughness2));
        float sky_light = texture2DLod(reflector_light, v_texcoord, 0).y;
        vec3 reg_f0     = vec3(material.y < 0.7 ? material.y : 0.0);
        vec3 f0         = mix(reg_f0, albedo, material.y);
        rt_Result result = rt_reflection(ray_view, unit_view, normal, unit_march, v_texcoord, REFLECTION_RAY_INITIAL_LENGTH, 128.0, REFLECTION_RAY_MULTIPLIER, CONSTANT_REFLECTION_STEPS, CONSTANT_REFLECTION_STEPS + MULTIPLICATIVE_REFLECTION_STEPS, frx_normalModelMatrix(), frx_projectionMatrix(), frx_inverseProjectionMatrix(), reflector_depth, reflector_normal, reflected_depth, reflected_normal);
        vec4 reflected;
        float reflected_depth_value = coords_depth(result.reflected_uv, reflected_depth);
        if (reflected_depth_value == 1.0 || !result.hit || result.reflected_uv.x < 0.0 || result.reflected_uv.y < 0.0 || result.reflected_uv.x > 1.0 || result.reflected_uv.y > 1.0) {
            if (frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT)) {
                reflected.rgb = v_skycolor * smoothstep(-0.05, 0.0, dot(unit_march, v_up)) * skylight_adjust(sky_light, frx_ambientIntensity());
            } else {
                reflected.rgb = v_skycolor;
            }
            reflected.rgb *= fallback;
            reflected.a = fallback;
        } else {
            reflected = texture2D(reflected_color, result.reflected_uv);
        }
        // mysterious roughness hax
        return vec4(pbr_lightCalc(albedo, 0.4 + material.x * 0.6, material.y, f0, reflected.rgb * base_color.a * gloss, unit_march * frx_normalModelMatrix(), unit_view * frx_normalModelMatrix(), worldNormal, true, false, 0.0, dummy), reflected.a);
    } else return noreturn;
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
        if (delta_z > 0 && delta_z < hitbox_z && (!backface || !diffuseCheck(reflectedNormal))) {
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
            return rt_Result(current_uv, /*fresnel,*/ true);
        }
        if (steps > constant_steps && current_ray_length < max_ray_length) {
            ray *= length_multiplier;
            current_ray_length *= length_multiplier;
        }
        steps ++;
    }
    // Sky reflection
    // if (sky(current_uv) && ray_view.z < 0) return current_uv;
    return rt_Result(current_uv, /*fresnel,*/ false);
}
