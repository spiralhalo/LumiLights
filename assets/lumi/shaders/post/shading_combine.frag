#include lumi:shaders/context/post/header.glsl
#include lumi:shaders/lib/tonemap.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/tile_noise.glsl
#include lumi:shaders/context/post/reflection.glsl

/*******************************************************
 *  lumi:shaders/post/shading_combine.frag    *
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
vec4 hdr_combine(sampler2D a, sampler2D b, sampler2D sdepth, vec2 uv, bool enableBlur)
{
    vec4 a1 = texture2D(a, uv);
    float roughness = texture2D(b, uv).a;
    if (roughness == 0.0) return vec4(hdr_gammaAdjust(a1.rgb), a1.a); // unmanaged draw
    vec4 b1;
    if (enableBlur) {
        float depth = texture2D(sdepth, uv).r;
        vec2 variable_blur = vec2(roughness) * (1.0 - ldepth(depth));
        b1 = tile_denoise_depth(uv, b, sdepth, 1.0/frxu_size, 4);
    } else {
        b1 = texture2D(b, uv);
    }
    return vec4(a1.rgb + b1.rgb, a1.a);
}

void main()
{
#if REFLECTION_PROFILE != REFLECTION_PROFILE_NONE
    gl_FragData[0] = hdr_combine(u_hdr_solid, u_hdr_solid_swap, u_solid_depth, v_texcoord, true);
    gl_FragData[1] = hdr_combine(u_hdr_translucent, u_hdr_translucent_swap, u_translucent_depth, v_texcoord, true);
#else
    gl_FragData[0] = hdr_combine(u_hdr_solid, u_hdr_solid_swap, u_solid_depth, v_texcoord, false);
    gl_FragData[1] = hdr_combine(u_hdr_translucent, u_hdr_translucent_swap, u_translucent_depth, v_texcoord, false);
#endif
}
