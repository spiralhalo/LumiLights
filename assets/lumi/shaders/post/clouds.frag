#include lumi:shaders/post/common/header.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/lighting.glsl
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

/*******************************************************
    vertexShader: lumi:shaders/post/clouds.vert
 *******************************************************/

#if CLOUD_RENDERING == CLOUD_RENDERING_FLAT
in mat4 v_cloud_rotator;
#endif
in float v_blindness;

out vec4[2] fragColor;

void doCloudStuff()
{
    // float brightnessMult = mix(1.0, BRIGHT_FINAL_MULT, frx_viewBrightness());
    #if CLOUD_RENDERING == CLOUD_RENDERING_FLAT
        vec4 cloudColor = flatCloud(v_texcoord, v_cloud_rotator, v_up);
        fragColor[0] = mix(cloudColor, vec4(0.0), v_blindness);
        fragColor[1] = vec4(cloudColor.a > 0. ? 0.99999 : 1.0);
    #elif CLOUD_RENDERING == CLOUD_RENDERING_PARALLAX
        vec4 cloudColor = parallaxCloud(v_texcoord);
        fragColor[0] = mix(cloudColor, vec4(0.0), v_blindness);
        fragColor[1] = vec4(cloudColor.a > 0. ? 0.99999 : 1.0);
    #elif CLOUD_RENDERING == CLOUD_RENDERING_VOLUMETRIC
        #if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
          cloud_result volumetric = rayMarchCloud(u_clouds_texture, u_solid_depth, v_texcoord);
        #else
          cloud_result volumetric = frx_viewFlag(FRX_CAMERA_IN_FLUID)
                                    ? rayMarchCloud(u_clouds_texture, u_solid_depth, v_texcoord)
                                    : rayMarchCloud(u_clouds_texture, u_translucent_depth, v_texcoord);
        #endif

        vec4 worldPos = frx_inverseViewProjectionMatrix() * vec4(2.0 * v_texcoord - 1.0, 1.0, 1.0);
        worldPos.xyz /= worldPos.w;
        vec3 skyVec = normalize(worldPos.xyz);

        float alpha = 1.0 - volumetric.transmittance;
        //  * l2_clampScale(-2.0, 1.0, dot(skyVec, frx_skyLightVector()))
        vec3 color = ldr_tonemap3(atmos_hdrCelestialRadiance() * 0.05) * volumetric.lightEnergy + ldr_tonemap3(atmos_hdrSkyColorRadiance(skyVec) * 0.4) * alpha;
        fragColor[0] = mix(vec4(color, alpha), vec4(0.0), v_blindness);
        #if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
            fragColor[1] = vec4(alpha > 0. ? 0.9999 : 1.0);
        #else
            vec3 reverseModelPos = volumetric.worldPos - frx_cameraPos();
            vec4 reverseClipPos = frx_viewProjectionMatrix() * vec4(reverseModelPos, 1.0);
            reverseClipPos.z /= reverseClipPos.w;
            // fragColor[1] = vec4(alpha > 0.0 ? 0.0 : 1.0);
            float backgroundDepth = texture(u_translucent_depth, v_texcoord).r;
            float alphaThreshold = backgroundDepth == 1. ? 0.5 : 0.; 
            fragColor[1] = vec4(alpha > alphaThreshold ? reverseClipPos.z : 1.0);
        #endif
    #else
        vec4 clouds = blur13(u_clouds, v_texcoord, frxu_size, vec2(1.0, 1.0));
        fragColor[0] = clouds;
        fragColor[1] = texture(u_clouds_depth, v_texcoord);
        // Thanks to Lomo for the inspiration on depth copying
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
