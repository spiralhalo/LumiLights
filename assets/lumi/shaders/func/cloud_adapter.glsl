#include lumi:shaders/func/flat_cloud.glsl
#include lumi:shaders/func/parallax_cloud.glsl
#include lumi:shaders/func/tonemap.glsl
#include lumi:shaders/func/volumetric_cloud.glsl
#include lumi:shaders/lib/fast_gaussian_blur.glsl

/*******************************************************
 *  lumi:shaders/func/cloud_adapter.glsl               *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_clouds;
uniform sampler2D u_clouds_texture;

#if CLOUD_RENDERING == CLOUD_RENDERING_FLAT && !defined(VERTEX_SHADER)
frag_in mat4 v_cloud_rotator;
#endif

vec4 cloudColor(in sampler2D ssolidDepth, in sampler2D stranslucentDepth, in sampler2D sbluenoise, in vec3 worldVec)
{
    vec4 cloudPos = vec4(worldVec * 1024., 1.0);
    
    cloudPos = frx_viewProjectionMatrix() * cloudPos;
    cloudPos.xyz /= cloudPos.w;

#if CLOUD_RENDERING == CLOUD_RENDERING_VOLUMETRIC
    // WIP: use worldVec directly instead of fade, except for vanilla of course
    cloudPos.y = clamp(cloudPos.y, -1.0, 1.0);

    float fade = smoothstep(1.0, 0.9, abs(cloudPos.y));

#elif CLOUD_RENDERING == CLOUD_RENDERING_VANILLA
    cloudPos.xy = clamp(cloudPos.xy, -1.0, 1.0);

    vec2 fadeUv = smoothstep(1.0, 0.9, abs(cloudPos.xy));
    float fade = min(fadeUv.x, fadeUv.y);
#endif

    vec2 texcoord = cloudPos.xy * 0.5 + 0.5;

    #if CLOUD_RENDERING == CLOUD_RENDERING_FLAT
        return flatCloud(texcoord, v_cloud_rotator, v_up);
    #elif CLOUD_RENDERING == CLOUD_RENDERING_PARALLAX
        return parallaxCloud(sbluenoise, texcoord);
    #elif CLOUD_RENDERING == CLOUD_RENDERING_VOLUMETRIC
        float unused = 1.0;
        return volumetricCloud(u_clouds_texture, ssolidDepth, stranslucentDepth, sbluenoise, texcoord, unused) * fade;
    #else
        return blur13(u_clouds, texcoord, frxu_size, vec2(1.0, 1.0)) * fade;
    #endif
}
