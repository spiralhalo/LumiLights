#include lumi:shaders/pipeline/post/common.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/lib/rt_v1.glsl

uniform sampler2D u_composite;
uniform sampler2D u_solid_depth;
uniform sampler2D u_translucent_depth;
uniform sampler2D u_entity_depth;
uniform sampler2D u_particles_depth;
uniform sampler2D u_normal;
uniform sampler2D u_material;

vec2 coords_uv(vec3 view, mat4 projection)
{
	vec4 clip = projection * vec4(view, 1.0);
	clip.xyz /= clip.w;
	return clip.xy * 0.5 + 0.5;
}

float coords_depth_source(vec2 uv)
{
    float solid_depth = texture2DLod(u_solid_depth, uv, 0).r;
    float translucent_depth = texture2DLod(u_translucent_depth, uv, 0).r;
    float entity_depth = texture2DLod(u_entity_depth, uv, 0).r;
    return min(solid_depth, min(translucent_depth, entity_depth));
}

float coords_depth(vec2 uv)
{
    float solid_depth = texture2DLod(u_solid_depth, uv, 0).r;
    float translucent_depth = texture2DLod(u_translucent_depth, uv, 0).r;
    float entity_depth = texture2DLod(u_entity_depth, uv, 0).r;
    float particles_depth = texture2DLod(u_particles_depth, uv, 0).r;
    return min(solid_depth, min(translucent_depth, min(entity_depth, particles_depth)));
}

vec3 coords_view_source(vec2 uv, mat4 inv_projection)
{
    float depth = coords_depth_source(uv);
	vec3 clip = vec3(2.0 * uv - 1.0, 2.0 * depth - 1.0);
	vec4 view = inv_projection * vec4(clip, 1.0);
	return view.xyz / view.w;
}

vec3 coords_view(vec2 uv, mat4 inv_projection)
{
    float depth = coords_depth(uv);
	vec3 clip = vec3(2.0 * uv - 1.0, 2.0 * depth - 1.0);
	vec4 view = inv_projection * vec4(clip, 1.0);
	return view.xyz / view.w;
}

vec3 coords_normal(vec2 uv)
{
	return 2.0 * texture2DLod(u_normal, uv, 0).xyz - 1.0;
}

vec4 rt_reflection(vec2 start_uv, float init_ray_length, float max_ray_length, float length_multiplier, int max_steps,
                   mat4 projection, mat4 inv_projection);

/*******************************************************
 *  lumi:shaders/pipeline/post/reflection.frag         *
 *******************************************************/

void main()
{
    vec4 material = texture2DLod(u_material, v_texcoord, 0);
    vec3 base_color = texture2D(u_composite, v_texcoord).rgb;
    float gloss = 1.0 - material.r;
    if (gloss > 0.01 && material.a > 0.0) {
        vec4 reflected_uv = rt_reflection(v_texcoord, 0.25, 128.0, 1.2, 20, frx_projectionMatrix(), frx_inverseProjectionMatrix());
        vec3 reflected;
        if (reflected_uv.w <= 0.0 || reflected_uv.x < 0.0 || reflected_uv.y < 0.0 || reflected_uv.x > 1.0 || reflected_uv.y > 1.0) {
            reflected = v_skycolor;
        } else {
            reflected = texture2D(u_composite, reflected_uv.xy).rgb;
        }
        float metal   = material.g;
        float fresnel = reflected_uv.z;
        vec3 tinted_base  = reflected * base_color;
        vec3 blended_base = mix(base_color, tinted_base, metal);
        gl_FragData[0] = vec4(mix(blended_base, reflected, fresnel), 1.0);
    } else {
        gl_FragData[0] = vec4(base_color, 1.0);
    }
}

vec4 rt_reflection(vec2 start_uv, float init_ray_length, float max_ray_length, float length_multiplier, int max_steps,
                   mat4 projection, mat4 inv_projection)
{
    float length_divisor = 1.0 / length_multiplier;
    vec3 ray_view = coords_view_source(start_uv, inv_projection);
    vec3 unit_view = normalize(-ray_view);
    vec3 unit_march = reflect(-unit_view, coords_normal(start_uv));
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
    while (current_ray_length < max_ray_length && steps < max_steps) {
        ray_view += ray;
        current_uv = coords_uv(ray_view, projection);
        current_view = coords_view(current_uv, inv_projection);
        delta_z = current_view.z - ray_view.z;
        hitbox_z = current_ray_length;
        backface = dot(unit_march, coords_normal(current_uv)) > 0;
        if (delta_z > 0 && delta_z < hitbox_z && !backface) {
            //refine
            while (current_ray_length > init_ray_length) {
                current_uv = coords_uv(ray_view, projection);
                current_view = coords_view(current_uv, inv_projection);
                ray *= length_divisor;
                current_ray_length *= length_divisor;
                if (ray_view.z > current_view.z) ray_view += ray;
                else ray_view -= ray;
            }
            return vec4(current_uv, fresnel, 1.0);
        }
        // if (steps > constantSteps) {
        ray *= length_multiplier;
        current_ray_length *= length_multiplier;
        // }
        steps ++;
    }
    // Sky reflection
    // if (sky(current_uv) && ray_view.z < 0) return current_uv;
    return vec4(current_uv, fresnel, 0.0);
}
