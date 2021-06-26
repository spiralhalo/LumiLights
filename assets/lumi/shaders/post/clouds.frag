#include lumi:shaders/post/common/header.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/func/flat_cloud.glsl
#include lumi:shaders/func/parallax_cloud.glsl
#include lumi:shaders/func/tonemap.glsl
#include lumi:shaders/func/volumetric_cloud.glsl
#include lumi:shaders/lib/fast_gaussian_blur.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/clouds.frag                      *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_clouds;
uniform sampler2D u_clouds_texture;
uniform sampler2D u_clouds_depth;
uniform sampler2D u_solid_depth;
uniform sampler2D u_translucent_depth;
uniform sampler2D u_blue_noise;

/*******************************************************
    vertexShader: lumi:shaders/post/clouds.vert
 *******************************************************/

#if CLOUD_RENDERING == CLOUD_RENDERING_FLAT
frag_in mat4 v_cloud_rotator;
#endif

frag_in float v_blindness;

#ifndef USING_OLD_OPENGL
out vec4[2] fragColor;
#endif

void doCloudStuff()
{
    vec4 modelPos = frx_inverseViewProjectionMatrix() * vec4(2.0 * v_texcoord - 1.0, 1.0, 1.0);
    modelPos.xyz /= modelPos.w;
    vec3 worldVec = normalize(modelPos.xyz);

    #if CLOUD_RENDERING == CLOUD_RENDERING_FLAT
        vec4 cloudColor = flatCloud(worldVec, v_cloud_rotator, v_up);

        cloudColor.rgb = ldr_tonemap3(cloudColor.rgb) * cloudColor.a;

        fragColor[0] = mix(cloudColor, vec4(0.0), v_blindness);
        fragColor[1] = vec4(cloudColor.a > 0. ? 0.99999 : 1.0);

    #elif CLOUD_RENDERING == CLOUD_RENDERING_PARALLAX
        vec4 cloudColor = parallaxCloud(u_blue_noise, v_texcoord, worldVec);

        cloudColor.rgb = ldr_tonemap3(cloudColor.rgb) * cloudColor.a;

        fragColor[0] = mix(cloudColor, vec4(0.0), v_blindness);
        fragColor[1] = vec4(cloudColor.a > 0. ? 0.99999 : 1.0);

    #elif CLOUD_RENDERING == CLOUD_RENDERING_VOLUMETRIC
        float out_depth = 1.0;
        vec4 cloudColor = volumetricCloud(u_clouds_texture, u_solid_depth, u_translucent_depth, u_blue_noise, v_texcoord, worldVec, NUM_SAMPLE, out_depth);

        cloudColor.rgb = ldr_tonemap3(cloudColor.rgb) * cloudColor.a;

        fragColor[0] = mix(cloudColor, vec4(0.0), v_blindness);
        fragColor[1] = vec4(out_depth);

    #else
        vec4 clouds = blur13(u_clouds, v_texcoord, frxu_size, vec2(1.0, 1.0));

        fragColor[0] = clouds;
        fragColor[1] = texture(u_clouds_depth, v_texcoord);
        // Thanks to fewizz for the inspiration on depth copying in Lomo
    #endif
}

void main()
{
    if (!frx_worldFlag(FRX_WORLD_IS_OVERWORLD) || v_blindness == 1.0) {
        fragColor[0] = vec4(0.);
        fragColor[1] = vec4(1.);
    } else {
        doCloudStuff();
    }
}
