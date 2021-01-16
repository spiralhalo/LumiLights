#include lumi:shaders/pipeline/post/common.glsl
#include lumi:shaders/lib/tonemap.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/fast_gaussian_blur.glsl

/*******************************************************
 *  lumi:shaders/pipeline/post/shading_combine.frag    *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_hdr_solid;
uniform sampler2D u_hdr_solid_swap;
uniform sampler2D u_solid_depth;
uniform sampler2D u_hdr_translucent;
uniform sampler2D u_hdr_translucent_swap;
uniform sampler2D u_translucent_depth;

// arbitrary chosen depth threshold
#define blurDepthThreshold 0.01
vec4 ldr_combine(sampler2D a, sampler2D b, sampler2D sdepth, vec2 uv)
{
    vec4 a1 = texture2D(a, uv);
    float roughness = texture2D(b, uv).a;
    if (roughness == 0.0) return vec4(ldr_tonemap3(hdr_gammaAdjust(a1.rgb)), a1.a); // unmanaged draw
    float depth = texture2D(sdepth, uv).r;
    vec2 variable_blur = vec2(roughness) * (1.0 - ldepth(depth));
    vec4 b1 = blur13withDepth(b, sdepth, blurDepthThreshold, uv, frxu_size, variable_blur);
    return ldr_tonemap(vec4(a1.rgb + b1.rgb, a1.a));
}

void main()
{
    gl_FragData[0] = ldr_combine(u_hdr_solid, u_hdr_solid_swap, u_solid_depth, v_texcoord);
    gl_FragData[1] = ldr_combine(u_hdr_translucent, u_hdr_translucent_swap, u_translucent_depth, v_texcoord);
}
