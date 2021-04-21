#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/post/reflection_common.glsl
#include lumi:shaders/post/common/reflection.glsl
#include lumi:shaders/common/lighting.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/lib/tile_noise.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include lumi:shaders/lib/puddle.glsl

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

#ifndef USE_LEGACY_FREX_COMPAT
out vec4[1] fragColor;
#endif

const float JITTER_STRENGTH = 0.2;

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
    in sampler2D reflector_micro_normal,
    in sampler2D reflector_material,

    in sampler2D reflected_color,
    in sampler2D reflected_combine,
    in sampler2D reflected_depth,
    in sampler2D reflected_normal,
    float fallback
)
{
    rt_color_depth noreturn = rt_color_depth(vec4(0.0), 1.0);
    vec4 material = texture(reflector_material, v_texcoord);
    vec3 worldNormal = sample_worldNormal(v_texcoord, reflector_micro_normal);
    float roughness = material.x == 0.0 ? 1.0 : min(1.0, 1.0203 * material.x - 0.01); //prevent gloss on unmanaged draw
    vec3 ray_view  = uv2view(v_texcoord, frx_inverseProjectionMatrix(), reflector_depth);
    vec3 ray_world = view2world(ray_view, frx_inverseViewMatrix());
    // TODO: optimize puddle by NOT calling it twice in shading and in reflection
    vec2 light = texture(reflector_light, v_texcoord).xy;
    vec4 fake = vec4(0.0);
    #ifdef RAIN_PUDDLES
        ww_puddle_pbr(fake, roughness, light.y, worldNormal, ray_world);
    #endif
    if (roughness <= REFLECTION_MAXIMUM_ROUGHNESS) {
        vec3 unit_view  = normalize(-ray_view);
        // bad
        // vec3 origNormal = sample_worldNormal(v_texcoord, reflector_normal);
        // if (dot(origNormal, unit_view) > dot(worldNormal, unit_view)) {
        //     worldNormal = origNormal;
        // }
        vec3 jitter    = 2.0 * getRandomVec(v_texcoord, frxu_size) - 1.0;
        vec3 normal    = frx_normalModelMatrix() * normalize(worldNormal);
        float roughness2 = roughness * roughness;
        // if (ray_view.y < normal.y) return noreturn;
        vec3 reg_f0     = vec3(material.z);
        vec3 f0         = mix(reg_f0, albedo, material.y);

        vec3 unit_march = normalize(reflect(-unit_view, normal) + mix(vec3(0.0, 0.0, 0.0), jitter * JITTER_STRENGTH, roughness2));

        #if REFLECTION_PROFILE != REFLECTION_PROFILE_NONE
        rt_Result result;
        vec3 origNormal_view = frx_normalModelMatrix() * sample_worldNormal(v_texcoord, reflector_normal);
        if (dot(origNormal_view, unit_march) < 0) {
            // Eliminate impossible rays
            result.hit = false;
        } else {
            result = rt_reflection(ray_view, unit_view, normal, unit_march, frx_normalModelMatrix(), frx_projectionMatrix(), frx_inverseProjectionMatrix(), reflected_depth, reflected_normal);
        }
        #endif

        vec4 reflected;
        float reflected_depth_value;

        vec4 fallbackColor;
        if (fallback > 0.0) {
            fallbackColor = vec4(calcFallbackColor(unit_view, unit_march, light), fallback);
        } else {
            fallbackColor = vec4(0.0);
        }

        #if REFLECTION_PROFILE != REFLECTION_PROFILE_NONE
        reflected_depth_value = sample_depth(result.reflected_uv, reflected_depth);
        if (reflected_depth_value == 1.0 || !result.hit || result.reflected_uv != clamp(result.reflected_uv, 0.0, 1.0)) {
            float occlusionFactor = result.hits > 1 ? 0.1 : 1.0;
        #else
            float occlusionFactor = 1.0;
        #endif
            // reflected.rgb = mix(vec3(0.0), hdr_gammaAdjust(BLOCK_LIGHT_COLOR), pow(light.x, 6.0) * material.y);
            reflected = fallbackColor * occlusionFactor;
            reflected_depth_value = 1.0;

        #if REFLECTION_PROFILE != REFLECTION_PROFILE_NONE
        } else {
            #ifdef MULTI_BOUNCE_REFLECTION
                // TODO: velocity reprojection. this method creates reflection that lags behind and somehow I overlooked this :/
                vec4 reflectedShaded = texture(reflected_color, result.reflected_uv);
                vec4 reflectedCombine = texture(reflected_combine, result.reflected_uv);
                vec3 reflectedNormal = sample_worldNormal(result.reflected_uv, reflected_normal);
                reflected = mix(reflectedShaded, reflectedCombine, l2_clampScale(0.5, 1.0, -dot(worldNormal, reflectedNormal)));
            #else
                reflected = texture(reflected_color, result.reflected_uv);
            #endif
            // fade to fallback on edges
            vec2 uvFade = smoothstep(0.5, 0.45, abs(result.reflected_uv - 0.5));
            reflected = mix(fallbackColor, reflected, min(uvFade.x, uvFade.y));
        }
        #endif

        // more useful in worldspace after rt computation is done
        unit_view *= frx_normalModelMatrix();
        unit_march *= frx_normalModelMatrix();
        vec4 pbr_color = vec4(pbr_lightCalc(roughness, f0, reflected.rgb * base_color.a, unit_march, unit_view), reflected.a);
        return rt_color_depth(pbr_color, reflected_depth_value);
    } else return noreturn;
}

void main()
{
    vec4 source_base = texture(u_source_color, v_texcoord);
    vec3 source_albedo = texture(u_source_albedo, v_texcoord).rgb;
    float source_roughness = texture(u_material_source, v_texcoord).x;
    rt_color_depth source_source = work_on_pair(source_base, source_albedo, u_source_depth, u_light_source, u_normal_source, u_normal_micro_source, u_material_source, u_source_color, u_source_combine, u_source_depth, u_normal_source, 1.0);
    #if REFLECTION_PROFILE != REFLECTION_PROFILE_NONE
        rt_color_depth source_target = work_on_pair(source_base, source_albedo, u_source_depth, u_light_source, u_normal_source, u_normal_micro_source, u_material_source, u_target_color, u_target_combine, u_target_depth, u_normal_target, 0.0);
        // blend
        vec3 reflection_color = (source_source.depth < source_target.depth)
            ? source_source.color.rgb * source_source.color.a
            : (source_source.color.rgb * (1.0 - source_target.color.a) + source_target.color.rgb * source_target.color.a);
        fragColor[0] = vec4(reflection_color, source_roughness);
    #else
        fragColor[0] = vec4(source_source.color.rgb, source_roughness);
    #endif
}
