#include lumi:shaders/pipeline/post/common.glsl
#include lumi:shaders/internal/context.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/material.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/pbr_shading.glsl
#include lumi:shaders/lib/fog.glsl
#include lumi:shaders/lib/tonemap.glsl

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

#define NUM_LAYERS 2

vec3 coords_view(vec2 uv, mat4 inv_projection, float depth)
{
	vec3 clip = vec3(2.0 * uv - 1.0, 2.0 * depth - 1.0);
	vec4 view = inv_projection * vec4(clip, 1.0);
	return view.xyz / view.w;
}

vec4 hdr_shaded_color(vec2 uv, sampler2D scolor, sampler2D sdepth, sampler2D slight, sampler2D snormal, sampler2D smaterial, bool translucent, out float bloom_out)
{
    vec4 a = texture2DLod(scolor, uv, 0.0);
    vec3 normal = texture2DLod(snormal, uv, 0.0).xyz;
    if (normal.x + normal.y + normal.z <= 0.01) return a;
    normal = normal * 2.0 - 1.0;
    float depth = texture2DLod(sdepth, uv, 0.0).r;
    vec4 light = texture2DLod(slight, uv, 0.0);
    vec3 material = texture2DLod(smaterial, uv, 0.0).xyz;
    // return vec4(coords_view(uv, frx_inverseProjectionMatrix(), depth), 1.0);
    vec3 viewDir = normalize(-coords_view(uv, frx_inverseProjectionMatrix(), depth)) * frx_normalModelMatrix();
    bloom_out = light.z;
    pbr_shading(a, bloom_out, viewDir, light.xy, normal, material.x, material.y, material.z, translucent);
    // TODO: white / red flash
    // if (frx_matFlash()) a = a * 0.25 + 0.75;
    // else if (frx_matHurt()) a = vec4(0.25 + a.r * 0.75, a.g * 0.75, a.b * 0.75, a.a);
    // TODO: do fog in shading
    // PERF: don't bother shade past max fog distance
    return vec4(ldr_tonemap(a.rgb), a.a);//p_fog(a);
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


