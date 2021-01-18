#include lumi:shaders/pipeline/post/common.glsl
#include lumi:shaders/internal/context.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include frex:shaders/api/sampler.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/player.glsl
#include frex:shaders/api/material.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/fog.glsl
#include lumi:shaders/lib/tonemap.glsl
#include lumi:shaders/lib/pbr_shading.glsl
#include lumi:shaders/lib/ssao.glsl
#include lumi:shaders/internal/skybloom.glsl
#include lumi:fog_config

/*******************************************************
 *  lumi:shaders/pipeline/post/shading.frag            *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_solid_color;
uniform sampler2D u_solid_depth;
uniform sampler2D u_light_solid;
uniform sampler2D u_normal_solid;
uniform sampler2D u_material_solid;

uniform sampler2D u_translucent_color;
uniform sampler2D u_translucent_depth;
uniform sampler2D u_light_translucent;
uniform sampler2D u_normal_translucent;
uniform sampler2D u_material_translucent;

uniform sampler2D u_ao;

vec3 coords_view(vec2 uv, mat4 inv_projection, float depth)
{
	vec3 clip = vec3(2.0 * uv - 1.0, 2.0 * depth - 1.0);
	vec4 view = inv_projection * vec4(clip, 1.0);
	return view.xyz / view.w;
}

vec2 coords_uv(vec3 view, mat4 projection)
{
	vec4 clip = projection * vec4(view, 1.0);
	clip.xyz /= clip.w;
	return clip.xy * 0.5 + 0.5;
}

/* DEVNOTE: on high skyscrapers, high fog look good
 * on low forests however, the high fog looks atrocious.
 * the ideal solution would be a fog that is "highest block-conscious"
 * but how is that possible? Make sky bloom cancel out the fog, perhaps?
 *
 * There is also the idea of making the fog depend on where
 * you look vertically, but that would be NAUSEATINGLY BAD.
 */

#define WATER_LEVEL 62.0
#define FOG_NOISE_SCALE 0.125
#define FOG_NOISE_SPEED 0.25
#define FOG_NOISE_HEIGHT 4.0
#define FOG_TOP WATER_LEVEL + FOG_ABOVE_WATER_LEVEL_CHUNKS * 16.0
#define FOG_BOTTOM WATER_LEVEL - FOG_BELOW_WATER_LEVEL_CHUNKS * 16.0
#define FOG_FAR FOG_FAR_CHUNKS * 16.0
#define FOG_NEAR FOG_NEAR_CHUNKS * 16.0
#define FOG_DENSITY FOG_DENSITY_RELATIVE / 20.0
#define UNDERWATER_FOG_FAR UNDERWATER_FOG_FAR_CHUNKS * 16.0
#define UNDERWATER_FOG_NEAR UNDERWATER_FOG_NEAR_CHUNKS * 16.0
#define UNDERWATER_FOG_DENSITY UNDERWATER_FOG_DENSITY_RELATIVE / 20.0

vec4 fog (float skylightFactor, vec4 a, vec3 viewPos, vec3 worldPos, bool translucent, inout float bloom)
{
    float zigZagTime = abs(frx_worldTime()-0.5);
    float timeFactor = (l2_clampScale(0.45, 0.5, zigZagTime) + l2_clampScale(0.05, 0.0, zigZagTime));
    timeFactor = frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) ? timeFactor : 1.0;

    // TODO: blindness fog
    // TODO: lava fog
    float fogDensity = frx_playerFlag(FRX_PLAYER_EYE_IN_FLUID) ? UNDERWATER_FOG_DENSITY : FOG_DENSITY;
    float fogFar = frx_playerFlag(FRX_PLAYER_EYE_IN_FLUID) ? UNDERWATER_FOG_FAR : FOG_FAR;
    float fogNear = frx_playerFlag(FRX_PLAYER_EYE_IN_FLUID) ? UNDERWATER_FOG_NEAR : FOG_NEAR;
    fogFar = max(fogNear, fogFar);

    float fogTop = FOG_TOP * 0.5 + 0.5 * FOG_TOP * timeFactor;
    
    // float fog_noise = snoise(worldPos.xz * FOG_NOISE_SCALE + frx_renderSeconds() * FOG_NOISE_SPEED) * FOG_NOISE_HEIGHT;
    float heightFactor = l2_clampScale(FOG_TOP /*+ fog_noise*/, FOG_BOTTOM, worldPos.y);
    heightFactor = frx_playerFlag(FRX_PLAYER_EYE_IN_FLUID) ? 1.0 : heightFactor;

    float fogFactor = fogDensity * heightFactor * skylightFactor;

    if (frx_playerHasEffect(FRX_EFFECT_BLINDNESS)) {
        float blindnessModifier = l2_clampScale(0.5, 1.0, 1.0 - frx_luminance(v_skycolor));
        fogFar = mix(fogFar, 3.0, blindnessModifier);
        fogNear = mix(fogNear, 0.0, blindnessModifier);
        fogFactor = mix(fogFactor, 1.0, blindnessModifier);
    }

    if (frx_playerFlag(FRX_PLAYER_EYE_IN_LAVA)) {
        fogFar = frx_playerHasEffect(FRX_EFFECT_FIRE_RESISTANCE) ? 2.5 : 0.5;
        fogNear = 0.0;
        fogFactor = 1.0;
    }

    // TODO: retrieve fog distance from render distance ?
    // PERF: use projection z (linear depth) instead of length(viewPos)
    float distFactor = l2_clampScale(fogNear, fogFar, length(viewPos));
    distFactor *= distFactor;

    fogFactor = clamp(fogFactor * distFactor, 0.0, 1.0);
    
    vec4 fogColor = vec4(v_skycolor, 1.0);
    bloom = mix(bloom, 0.0, fogFactor);
    return mix(a, fogColor, fogFactor);
}

const float RADIUS = 0.4;
const float BIAS = 0.4;
const float INTENSITY = 10.0;

vec4 hdr_shaded_color(vec2 uv, sampler2D scolor, sampler2D sdepth, sampler2D slight, sampler2D snormal, sampler2D smaterial, float aoval, bool translucent, out float bloom_out)
{
    vec4 a = texture2DLod(scolor, uv, 0.0);
    float depth = texture2DLod(sdepth, uv, 0.0).r;
    if (depth == 1.0) {
        float blindnessFactor = frx_playerHasEffect(FRX_EFFECT_BLINDNESS) ? 0.0 : 1.0;
        // the sky
        bloom_out = l2_skyBloom() * blindnessFactor;
        return vec4(a.rgb * blindnessFactor, 0.0);
    }

    vec3  normal    = texture2DLod(snormal, uv, 0.0).xyz * 2.0 - 1.0;
    vec4  light     = texture2DLod(slight, uv, 0.0);
    vec3  material  = texture2DLod(smaterial, uv, 0.0).xyz;
    float roughness = material.x == 0.0 ? 1.0 : min(1.0, 1.02 * material.x);
    float metallic  = material.y;
    vec3  viewPos   = coords_view(uv, frx_inverseProjectionMatrix(), depth);
    vec3  worldPos  = frx_cameraPos() + (frx_inverseViewMatrix() * vec4(viewPos, 1.0)).xyz;
    float f0        = material.z;
    float bloom_raw = light.z * 2.0 - 1.0;
    bool  diffuse   = material.x < 1.0;
    bool  matflash  = f0 > 0.95;
    bool  mathurt   = f0 > 0.85 && !matflash;
    // return vec4(coords_view(uv, frx_inverseProjectionMatrix(), depth), 1.0);

    bloom_out = max(0.0, bloom_raw);
    pbr_shading(a, bloom_out, viewPos, light.xy, normal, roughness, metallic, f0 > 0.7 ? 0.0 : material.z, diffuse, translucent);

    float ao_shaded = 1.0 + min(0.0, bloom_raw);
    float ssao = mix(aoval, 1.0, min(bloom_out, 1.0));
    a.rgb *= ao_shaded * ssao;
    if (matflash) a.rgb += 1.0;
    if (mathurt) a.r += 0.5;

    a.a = min(1.0, a.a);

    // PERF: don't shade past max fog distance
    return fog(frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) ? light.y * frx_ambientIntensity() : 1.0, a, viewPos, worldPos, translucent, bloom_out);
}

void main()
{
    float bloom1;
    float bloom2;
    float ssao = texture2D(u_ao, v_texcoord).r;
    vec4 a1 = hdr_shaded_color(v_texcoord, u_solid_color, u_solid_depth, u_light_solid, u_normal_solid, u_material_solid, ssao, false, bloom1);
    vec4 a2 = hdr_shaded_color(v_texcoord, u_translucent_color, u_translucent_depth, u_light_translucent, u_normal_translucent, u_material_translucent, 1.0, true, bloom2);
    gl_FragData[0] = a1;
    gl_FragData[1] = a2;
    gl_FragData[2] = vec4(bloom1 + bloom2, 0.0, 0.0, 1.0);
}


