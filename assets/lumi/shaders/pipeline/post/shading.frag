#include lumi:shaders/pipeline/post/common.glsl
#include lumi:shaders/internal/context.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/material.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/fog.glsl
#include lumi:shaders/lib/tonemap.glsl
#include lumi:shaders/lib/pbr_shading.glsl

// #define sampleKernelSize 16
// #include lumi:shaders/lib/ao.glsl

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

// varying vec3[sampleKernelSize] v_kernel;

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

// float ambient_occlusion(vec3 origin, vec3 normal, float radius, mat4 projectionMat, mat4 invProjectionMat, sampler2D sdepth, sampler2D snormal)
// {
//     float occlusion = 0.0;
//     const int size = 2;
//     vec3 sample;
//     vec3 sample_view;
//     vec2 hit_uv;
//     float hit_depth;
//     vec3 hit_view;
//     vec3 hit_normal;
//     float rangeCheck;
//     float normalCheck;
//     for (int i = 0; i < size; i++) {
//         for (int j = 0; j < size; j++) {
//             for (int k = 0; k < size; k++) {
//                 sample = normalize(vec3(i, j, k));
//                 // sample = normalize(sample+normal);
//                 sample_view = origin + sample * radius;
//                 hit_uv = coords_uv(sample_view, projectionMat);
//                 hit_depth = texture2DLod(sdepth, hit_uv, 0.0).r;
//                 hit_view = coords_view(hit_uv, invProjectionMat, hit_depth);
//                 hit_normal = texture2DLod(snormal, hit_uv, 0.0).xyz * 2.0 - 1.0;
//                 rangeCheck = abs(origin.z - hit_view.z) < radius ? 1.0 : 0.0;
//                 normalCheck = dot(hit_normal, normal) < 0.5 ? 1.0 : 0.0;
//                 normalCheck *= dot(sample, normal) < 0.5 ? 1.0 : 0.0;
//                 occlusion += (hit_view.z > sample_view.z ? 1.0 : 0.0) * rangeCheck * normalCheck;
//             }
//         }
//     }
//     return clamp(1.0 - occlusion/(size*size*size), 0.0, 1.0);
// }

// float ambient_occlusion(vec3 origin, vec3 normal, float radius, mat4 projectionMat, mat4 invProjectionMat, sampler2D sdepth)
// {
//     float occlusion = 0.0;
//     const int size = 2;
//     vec3 sample;
//     vec3 sample_view;
//     vec2 hit_uv;
//     float hit_depth;
//     vec3 hit_view;
//     float rangeCheck;
//     float normalCheck;
//     float uvCheck;
//     for (int i = 0; i < size; i++) {
//         for (int j = 0; j < size; j++) {
//             for (int k = 0; k < size; k++) {
//                 sample = normalize(vec3(i, j, k));
//                 sample = normalize(sample+normal);
//                 sample_view = origin + sample * radius;
//                 hit_uv = coords_uv(sample_view, projectionMat);
//                 hit_depth = texture2DLod(sdepth, hit_uv, 0.0).r;
//                 hit_view = coords_view(hit_uv, invProjectionMat, hit_depth);
//                 rangeCheck = abs(origin.z - hit_view.z) < radius ? 1.0 : 0.0;
//                 normalCheck = dot(sample, normal) > 0.5 ? 1.0 : 0.0;
//                 uvCheck = (hit_uv.x > 1.0 || hit_uv.x < 0.0 || hit_uv.y > 1.0 || hit_uv.y < 0.0) ? 0.0 : 1.0;
//                 occlusion += (hit_view.z > sample_view.z ? 1.0 : 0.0) * rangeCheck * normalCheck * uvCheck;
//             }
//         }
//     }
//     return clamp(1.0 - occlusion/(size*size*size), 0.0, 1.0);
// }

vec4 hdr_shaded_color(vec2 uv, sampler2D scolor, sampler2D sdepth, sampler2D slight, sampler2D snormal, sampler2D smaterial, bool translucent, out float bloom_out)
{
    vec4 a = texture2DLod(scolor, uv, 0.0);
    vec3 normal = texture2DLod(snormal, uv, 0.0).xyz;
    if (normal.x + normal.y + normal.z <= 0.01) return vec4(a.rgb, 0.0);

    float depth     = texture2DLod(sdepth, uv, 0.0).r;
    vec4  light     = texture2DLod(slight, uv, 0.0);
    vec3  material  = texture2DLod(smaterial, uv, 0.0).xyz;
    vec3  viewPos   = coords_view(uv, frx_inverseProjectionMatrix(), depth);
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
    // float ao = ambient_occlusion(viewPos, normal, 1.0, v_kernel, frx_projectionMatrix(), frx_inverseProjectionMatrix(), sdepth);
    // float ao = min(1.0, bloom_out + ambient_occlusion(viewPos, normal, 0.25, frx_projectionMatrix(), frx_inverseProjectionMatrix(), sdepth, snormal));
    // a.rgb *= ao * ao * ao * ao;
    // TODO: white flash ???
    // if (frx_matFlash()) a = a * 0.25 + 0.75;
    // TODO: do fog in shading
    // PERF: don't bother shade past max fog distance
    return a;//p_fog(a);
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


