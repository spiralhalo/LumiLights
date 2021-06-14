#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/lib/pbr.glsl
#include lumi:shaders/lib/puddle.glsl
#include lumi:shaders/func/tile_noise.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/common/reflection.glsl           *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_blue_noise;

#if REFLECTION_PROFILE == REFLECTION_PROFILE_EXTREME
    const float HITBOX = 0.0625;
    const int MAXSTEPS = 109;
    const int PERIOD = 14;
    const int REFINE = 16;
#endif

#if REFLECTION_PROFILE == REFLECTION_PROFILE_HIGH
    const float HITBOX = 0.125;
    const int MAXSTEPS = 55;
    const int PERIOD = 7;
    const int REFINE = 16;
#endif

#if REFLECTION_PROFILE == REFLECTION_PROFILE_MEDIUM
    const float HITBOX = 0.125;
    const int MAXSTEPS = 35;
    const int PERIOD = 4;
    const int REFINE = 8;
#endif

#if REFLECTION_PROFILE == REFLECTION_PROFILE_LOW
    const float HITBOX = 0.125;
    const int MAXSTEPS = 20;
    const int PERIOD = 2;
    const int REFINE = 8;
#endif

const float REFLECTION_MAXIMUM_ROUGHNESS = REFLECTION_MAXIMUM_ROUGHNESS_RELATIVE / 10.0;


vec2 view2uv(vec3 view, mat4 projection)
{
    vec4 clip = projection * vec4(view, 1.0);
    clip.xyz /= clip.w;
    return clip.xy * 0.5 + 0.5;
}

float sample_depth(vec2 uv, in sampler2D sdepth)
{
    return texture(sdepth, uv).r;
}

vec3 uv2view(vec2 uv, mat4 inv_projection, in sampler2D sdepth)
{
    float depth = sample_depth(uv, sdepth);
    vec3 clip = vec3(2.0 * uv - 1.0, 2.0 * depth - 1.0);
    vec4 view = inv_projection * vec4(clip, 1.0);
    return view.xyz / view.w;
}

vec3 view2world(vec3 view, mat4 inv_view)
{
    return frx_cameraPos() + (inv_view * vec4(view, 1.0)).xyz;
}

vec3 sample_worldNormal(vec2 uv, in sampler2D snormal)
{
    return 2.0 * texture(snormal, uv).xyz - 1.0;
}

const float SKYLESS_FACTOR = 0.5;
vec3 calcFallbackColor(vec3 unit_view, vec3 unitMarch_view, vec2 light)
{
    float skyLight = l2_clampScale(0.03125, 0.96875, light.y);
    float upFactor = frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) ? l2_clampScale(-0.1, 0.1, dot(unitMarch_view, v_up)) : 1.0;
    float skyLightFactor = frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) ? (skyLight * skyLight) : SKYLESS_FACTOR;
    return atmos_hdrSkyColorRadiance(unitMarch_view * frx_normalModelMatrix()) * skyLightFactor * upFactor * 2.0;
}

vec3 pbr_lightCalc(float roughness, vec3 f0, vec3 radiance, vec3 lightDir, vec3 viewDir)
{
    vec3 halfway = normalize(viewDir + lightDir);
    vec3 fresnel = pbr_fresnelSchlick(pbr_dot(viewDir, halfway), f0);
    float smoothness = (1-roughness);

    return clamp(fresnel * radiance * smoothness * smoothness, 0.0, 1.0);
}

#if REFLECTION_PROFILE != REFLECTION_PROFILE_NONE
struct rt_Result
{
    vec2 reflected_uv;
    bool hit;
    int hits;
};

rt_Result rt_reflection(
    vec3 start_view, vec3 unit_view, vec3 normal, vec3 unitMarch_view,
    mat3 normal_matrix, mat4 projection, mat4 inv_projection,
    in sampler2D reflected_depth, in sampler2D reflected_normal
)
{
    start_view = start_view + unitMarch_view * -start_view.z / vec3(50.); // magic
    vec3 ray_view = start_view;
    float edge_z = start_view.z + 0.25;

    // float hitbox_z = mix(HITBOX, 1.0, sqrt(start_view.z/512.0));
    float hitbox_z = HITBOX;
    vec3 ray = unitMarch_view * hitbox_z;

    // limit hitbox size for inbound reflection
    bool inbound = unitMarch_view.z > 0.0;
    float hitboxLimit = inbound ? 1. : 1024000.;

    vec2 rayHit_uv;
    int hits = 0;
    int steps = 0;
    while (steps < MAXSTEPS && ray_view.z < 0.0) {

        ray_view += ray;
        rayHit_uv = view2uv(ray_view, projection);
        vec3 rayHit_view = uv2view(rayHit_uv, inv_projection, reflected_depth);

        float delta_z = rayHit_view.z - ray_view.z; 
        vec3 reflectedNormal   = normalize(normal_matrix * sample_worldNormal(rayHit_uv, reflected_normal));
        bool reflectsFrontFace = dot(unitMarch_view, reflectedNormal) < 0.;

        if (delta_z > 0 && ((reflectsFrontFace && rayHit_view.z < edge_z) || inbound)) {
            // Pad hitbox to reduce "stripes" artifact when surface is almost perpendicular to 
            float hitboxMult = 1. + 3. * (1. - dot(vec3(0., 0., 1.), reflectedNormal)); // dot is unclamped intentionally
            float hitboxNow = min(hitboxLimit, hitboxMult * hitbox_z);

            if (delta_z < hitboxNow) {
                //refine
                int refine_steps = 0;
                vec2 last_uv = rayHit_uv;
                float lastDelta_z = delta_z;
                float refineRayLength = 0.0625;
                ray = unitMarch_view * refineRayLength;

                // 0.01 is the delta_z at which no more detail will be achieved even for very nearby reflection
                // PERF: adapt based on initial z
                while (refine_steps < REFINE && abs(delta_z) > 0.01) {

                    if (abs(delta_z) < refineRayLength) {
                        refineRayLength = abs(delta_z);
                        ray = unitMarch_view * refineRayLength;
                    }

                    ray_view -= ray;
                    rayHit_uv = view2uv(ray_view, projection);
                    rayHit_view = uv2view(rayHit_uv, inv_projection, reflected_depth);

                    delta_z = rayHit_view.z - ray_view.z;
                    // Ensure delta_z never increases
                    if (abs(delta_z) > abs(lastDelta_z)) break;

                    last_uv = rayHit_uv;
                    lastDelta_z = delta_z;
                    refine_steps ++;
                }

                return rt_Result(last_uv, true, hits);
            }
        }
        if (mod(steps, PERIOD) == 0 && hitbox_z < hitboxLimit) {
            ray *= 2.;
            hitbox_z *= 2.;
        }
        steps ++;
    }
    return rt_Result(rayHit_uv, false, hits);
}
#endif

const float JITTER_STRENGTH = 0.6;

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
    float fallback,
    bool compute_colors
)
{
    vec4 material   = texture(reflector_material, v_texcoord);
    float roughness = material.x == 0.0 ? 1.0 : min(1.0, 1.0203 * material.x - 0.01);
    if (roughness == 1.0) return rt_color_depth(vec4(0.0), 1.0); // unmanaged draw

    vec3 worldNormal = sample_worldNormal(v_texcoord, reflector_micro_normal);
    vec3 ray_view    = uv2view(v_texcoord, frx_inverseProjectionMatrix(), reflector_depth);
    vec3 ray_world   = view2world(ray_view, frx_inverseViewMatrix());
    // TODO: optimize puddle by NOT calling it twice in shading and in reflection
    vec2 light       = texture(reflector_light, v_texcoord).xy;
    vec4 fake = vec4(0.0);
    #ifdef RAIN_PUDDLES
        ww_puddle_pbr(fake, roughness, light.y, worldNormal, ray_world);
    #endif

    vec3 unit_view = normalize(-ray_view);
    
    vec3 jitter    = 2.0 * getRandomVec(u_blue_noise, v_texcoord, frxu_size) - 1.0;
    vec3 normal    = frx_normalModelMatrix() * normalize(worldNormal);
    float roughness2 = roughness * roughness;
    // if (ray_view.y < normal.y) return noreturn;
    vec3 reg_f0     = vec3(material.z);
    vec3 f0         = mix(reg_f0, albedo, material.y);

    vec3 unitMarch_view = normalize(reflect(-unit_view, normal) + mix(vec3(0.0, 0.0, 0.0), jitter * JITTER_STRENGTH, roughness2));

    #if REFLECTION_PROFILE != REFLECTION_PROFILE_NONE
    rt_Result result;

    vec3 rawNormal_view   = frx_normalModelMatrix() * sample_worldNormal(v_texcoord, reflector_normal);
    bool impossibleRay    = dot(rawNormal_view, unitMarch_view) < 0;
    bool exceedsThreshold = roughness > REFLECTION_MAXIMUM_ROUGHNESS;

    if (impossibleRay || exceedsThreshold) {
        result.hit = false;
    } else {
        result = rt_reflection(ray_view + unitMarch_view * jitter.x * HITBOX, unit_view, normal, unitMarch_view, frx_normalModelMatrix(), frx_projectionMatrix(), frx_inverseProjectionMatrix(), reflected_depth, reflected_normal);
    }
    #endif

    vec4 reflected = vec4(0.);
    float reflected_depth_value;
    float fallbackMix = 0.;

    #if REFLECTION_PROFILE != REFLECTION_PROFILE_NONE
    reflected_depth_value = sample_depth(result.reflected_uv, reflected_depth);
    if (reflected_depth_value == 1.0 || !result.hit || result.reflected_uv != clamp(result.reflected_uv, 0.0, 1.0)) {
        float occlusionFactor = result.hits > 1 ? 0.1 : 1.0;
    #else
        float occlusionFactor = 1.0;
    #endif
        // reflected.rgb = mix(vec3(0.0), hdr_gammaAdjust(BLOCK_LIGHT_COLOR), pow(light.x, 6.0) * material.y);
        fallbackMix = occlusionFactor;
        reflected_depth_value = 1.0;

    #if REFLECTION_PROFILE != REFLECTION_PROFILE_NONE
    } else {
        if (compute_colors) {
        #ifdef KALEIDOSKOP
            reflected = texture(reflected_combine, result.reflected_uv);
        #elif defined(MULTI_BOUNCE_REFLECTION)
            // TODO: velocity reprojection. this method creates reflection that lags behind and somehow I overlooked this :/
            vec4 reflectedShaded = texture(reflected_color, result.reflected_uv);
            vec4 reflectedCombine = texture(reflected_combine, result.reflected_uv);
            vec3 reflectedNormal = sample_worldNormal(result.reflected_uv, reflected_normal);
            float combineFactor = l2_clampScale(0.5, 1.0, -dot(worldNormal, reflectedNormal));
            reflected = mix(reflectedShaded, reflectedCombine, combineFactor);
        #else
            reflected = texture(reflected_color, result.reflected_uv);
        #endif
        }
        // fade to fallback on edges
        vec2 uvFade = smoothstep(0.5, 0.45, abs(result.reflected_uv - 0.5));
        fallbackMix = 1.0 - min(uvFade.x, uvFade.y);
    }
    #endif

    // nb: compute_colors is currently unused as of the commmit it was added in ¯\_(ツ)_/¯
    if (compute_colors) {
        vec4 fallbackColor   = fallback > 0.0 ? vec4(calcFallbackColor(unit_view, unitMarch_view, light), fallback) : vec4(0.0);
        vec4 reflected_final = mix(reflected, fallbackColor, fallbackMix);
        vec3 unit_world      = unit_view * frx_normalModelMatrix();
        vec3 unitMarch_world = unitMarch_view * frx_normalModelMatrix();

        vec4 pbr_color = vec4(pbr_lightCalc(roughness, f0, reflected_final.rgb * base_color.a, unitMarch_world, unit_world), reflected_final.a);

        return rt_color_depth(pbr_color, reflected_depth_value);
    } else {
    #if REFLECTION_PROFILE != REFLECTION_PROFILE_NONE
        return rt_color_depth(vec4(result.reflected_uv, fallbackMix, 1.0), reflected_depth_value);
    #else
        return rt_color_depth(vec4(0., 0., fallbackMix, 1.0), reflected_depth_value);
    #endif
    }
}
