#include lumi:shaders/context/post/header.glsl
#include lumi:shaders/post/reflection_common.glsl
#include lumi:shaders/context/post/reflection.glsl
#include lumi:shaders/context/global/lighting.glsl
#include lumi:shaders/lib/tile_noise.glsl

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
uniform sampler2D u_material_source;

uniform sampler2D u_target_color;
uniform sampler2D u_target_combine;
uniform sampler2D u_target_depth;
uniform sampler2D u_normal_target;

#if REFLECTION_PROFILE != REFLECTION_PROFILE_NONE
const float JITTER_STRENGTH = 0.2;
const vec3 UP_VECTOR = vec3(0.0, 1.0, 0.0);

struct rt_color_depth
{
    vec4 color;
    float depth;
};

rt_color_depth work_on_pair(
    in vec4 base_color,
    in vec3 albedo,
    in sampler2D reflector_depth,
    in sampler2D reflector_light,
    in sampler2D reflector_normal,
    in sampler2D reflector_material,

    in sampler2D reflected_color,
    in sampler2D reflected_combine,
    in sampler2D reflected_depth,
    in sampler2D reflected_normal,
    float fallback
)
{
    rt_color_depth noreturn = rt_color_depth(vec4(0.0), 1.0);
    vec4 material = texture2DLod(reflector_material, v_texcoord, 0);
    vec3 worldNormal = coords_normal(v_texcoord, reflector_normal);
    float roughness = material.x == 0.0 ? 1.0 : min(1.0, 1.0203 * material.x - 0.01); //prevent gloss on unmanaged draw
    if (roughness <= REFLECTION_MINIMUM_ROUGHNESS && material.a > 0.0) {
        float gloss    = 1.0 - roughness;
        vec3 ray_view  = coords_view(v_texcoord, frx_inverseProjectionMatrix(), reflector_depth);
        vec3 ray_world = coords_world(ray_view, frx_inverseViewMatrix());
        vec3 jitter    = 2.0 * tile_noise_3d(v_texcoord, frxu_size, 4) - 1.0;
        vec3 normal    = frx_normalModelMatrix() * normalize(worldNormal);
        float roughness2 = roughness * roughness;
        // if (ray_view.y < normal.y) return noreturn;
        vec3 unit_view  = normalize(-ray_view);
        vec3 unit_march = normalize(reflect(-unit_view, normal) + mix(vec3(0.0, 0.0, 0.0), jitter * JITTER_STRENGTH, roughness2));
        vec3 reg_f0     = vec3(material.y < 0.7 ? material.y : 0.0);
        vec3 f0         = mix(reg_f0, albedo, material.y);
        rt_Result result = rt_reflection(ray_view, unit_view, normal, unit_march, frx_normalModelMatrix(), frx_projectionMatrix(), frx_inverseProjectionMatrix(), reflector_depth, reflector_normal, reflected_depth, reflected_normal);
        // more useful in worldspace after rt computation is done
        unit_view *= frx_normalModelMatrix();
        unit_march *= frx_normalModelMatrix();
        vec4 reflected;
        float reflected_depth_value = coords_depth(result.reflected_uv, reflected_depth);
        if (reflected_depth_value == 1.0 || !result.hit || result.reflected_uv.x < 0.0 || result.reflected_uv.y < 0.0 || result.reflected_uv.x > 1.0 || result.reflected_uv.y > 1.0) {
            vec2 light = texture2D(reflector_light, v_texcoord).xy;
            float occlusionFactor = result.hits > 1 ? 0.1 : 1.0;
            float upFactor = frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) ? l2_clampScale(-0.1, 0.1, dot(unit_march, UP_VECTOR)) : 1.0;
            float skyLightFactor = frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) ? hdr_gammaAdjustf(light.y * frx_ambientIntensity()) : 0.5; // 0.5 = arbitrary skyless factor. TODO: make constant
            // reflected.rgb = mix(vec3(0.0), hdr_gammaAdjust(BLOCK_LIGHT_COLOR), pow(light.x, 6.0) * material.y);
            reflected.rgb = v_skycolor * skyLightFactor * occlusionFactor * upFactor;
            reflected.rgb *= fallback;
            reflected.a = fallback;
            reflected_depth_value = 1.0;
        } else {
            vec4 reflectedShaded = texture2D(reflected_color, result.reflected_uv);
            vec4 reflectedCombine = texture2D(reflected_combine, result.reflected_uv);
            vec3 reflectedNormal = coords_normal(result.reflected_uv, reflected_normal);
            reflected = mix(reflectedShaded, reflectedCombine, l2_clampScale(0.5, 1.0, -dot(worldNormal, reflectedNormal)));
        }
        vec4 pbr_color = vec4(pbr_lightCalc(roughness, f0, reflected.rgb * base_color.a, unit_march, unit_view), reflected.a);
        return rt_color_depth(pbr_color, reflected_depth_value);
    } else return noreturn;
}

void main()
{
    vec4 source_base = texture2D(u_source_color, v_texcoord);
    vec3 source_albedo = texture2D(u_source_albedo, v_texcoord).rgb;
    rt_color_depth source_source = work_on_pair(source_base, source_albedo, u_source_depth, u_light_source, u_normal_source, u_material_source, u_source_color, u_source_combine, u_source_depth, u_normal_source, 1.0);
    rt_color_depth source_target = work_on_pair(source_base, source_albedo, u_source_depth, u_light_source, u_normal_source, u_material_source, u_target_color, u_target_combine, u_target_depth, u_normal_target, 0.0);
    float roughness1 = texture2DLod(u_material_source, v_texcoord, 0).x;
    vec3 reflection_color1 = (source_source.depth < source_target.depth)
        ? source_source.color.rgb
        : (source_source.color.rgb * (1.0 - source_target.color.a) + source_target.color.rgb);
    gl_FragData[0] = vec4(reflection_color1, roughness1);
}
#else
void main()
{ 
    float roughness1 = texture2D(u_material_source, v_texcoord).x;
    gl_FragData[0] = vec4(0.0, 0.0, 0.0, roughness1);
}
#endif
