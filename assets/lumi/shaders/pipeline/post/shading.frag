#include lumi:shaders/pipeline/post/common.glsl
#include lumi:shaders/internal/context.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include frex:shaders/api/sampler.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/material.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/fog.glsl
#include lumi:shaders/lib/tonemap.glsl
#include lumi:shaders/lib/pbr_shading.glsl
#include lumi:shaders/internal/skybloom.glsl

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

#define WATER_LEVEL 62.0
#define FOG_NOISE_SCALE 0.125
#define FOG_NOISE_SPEED 0.25
#define FOG_NOISE_HEIGHT 4.0
#define FOG_TOP WATER_LEVEL + 32.0
#define FOG_BOTTOM WATER_LEVEL - 32.0
#define FOG_FAR 256.0
#define FOG_NEAR 64.0
#define FOG_DENSITY 0.5

vec4 fog (float skylightFactor, vec4 a, vec3 viewPos, vec3 worldPos)
{
    float zigZagTime = abs(frx_worldTime()-0.5);
    float timeFactor = l2_clampScale(0.45, 0.5, zigZagTime) + l2_clampScale(0.05, 0.0, zigZagTime);

    // TODO: retrieve fog distance from render distance ?
    // TODO: use projection z (linear depth) instead of viewPos.z ?
    float distFactor = l2_clampScale(FOG_NEAR, FOG_FAR, -viewPos.z);
    distFactor *= distFactor;
    
    // float fog_noise = snoise(worldPos.xz * FOG_NOISE_SCALE + frx_renderSeconds() * FOG_NOISE_SPEED) * FOG_NOISE_HEIGHT;
    float heightFactor = l2_clampScale(FOG_TOP /*+ fog_noise*/, FOG_BOTTOM, worldPos.y);

    float fogFactor = FOG_DENSITY * distFactor * heightFactor * timeFactor * skylightFactor;
    return vec4(mix(a.rgb, frx_vanillaClearColor(), fogFactor), a.a);
}

vec4 hdr_shaded_color(vec2 uv, sampler2D scolor, sampler2D sdepth, sampler2D slight, sampler2D snormal, sampler2D smaterial, bool translucent, out float bloom_out)
{
    vec4 a = texture2DLod(scolor, uv, 0.0);
    float depth = texture2DLod(sdepth, uv, 0.0).r;
    if (depth == 1.0) {
        // the sky
        bloom_out = l2_skyBloom();
        return vec4(a.rgb, 0.0);
    }

    vec3  normal    = texture2DLod(snormal, uv, 0.0).xyz;
    vec4  light     = texture2DLod(slight, uv, 0.0);
    vec3  material  = texture2DLod(smaterial, uv, 0.0).xyz;
    vec3  viewPos   = coords_view(uv, frx_inverseProjectionMatrix(), depth);
    vec3  worldPos  = frx_cameraPos() + (frx_inverseViewMatrix() * vec4(viewPos, 1.0)).xyz;
    float f0        = material.z;
    float bloom_raw = light.z * 2.0 - 1.0;
    bool  diffuse   = normal.x + normal.y + normal.z < 2.5;
    bool  matflash  = f0 > 0.95;
    bool  mathurt   = f0 > 0.85 && !matflash;
    // return vec4(coords_view(uv, frx_inverseProjectionMatrix(), depth), 1.0);

    bloom_out = max(0.0, bloom_raw);
    normal = diffuse ? (normal * 2.0 - 1.0) : vec3(.0, 1.0, .0);
    pbr_shading(a, bloom_out, viewPos, light.xy, normal, material.x, material.y, f0 > 0.7 ? 0.0 : material.z, diffuse, translucent);

    float ao_shaded = 1.0 + min(0.0, bloom_raw);
    a.rgb *= ao_shaded * ao_shaded;
    if (matflash) a.rgb += 1.0;
    if (mathurt) a.r += 0.5;

    // PERF: don't shade past max fog distance
    return fog(frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) ? light.y : 1.0, a, viewPos, worldPos);
}

void main()
{
    float bloom1;
    float bloom2;
    vec4 a1 = hdr_shaded_color(v_texcoord, u_solid_color, u_solid_depth, u_light_solid, u_normal_solid, u_material_solid, false, bloom1);
    vec4 a2 = hdr_shaded_color(v_texcoord, u_translucent_color, u_translucent_depth, u_light_translucent, u_normal_translucent, u_material_translucent, true, bloom2);
    gl_FragData[0] = a1;
    gl_FragData[1] = a2;
    gl_FragData[2] = vec4(bloom1 + bloom2, 0.0, 0.0, 1.0);
}


