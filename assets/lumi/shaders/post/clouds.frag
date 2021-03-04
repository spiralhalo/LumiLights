#include lumi:shaders/context/post/header.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/tonemap.glsl
#include lumi:shaders/lib/fast_gaussian_blur.glsl
#include lumi:shaders/lib/volumetric_cloud.glsl
#include lumi:shaders/context/global/lighting.glsl
#include lumi:shaders/context/global/clouds.glsl

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
uniform sampler2D u_translucent_depth;

/*******************************************************
    vertexShader: lumi:shaders/post/hdr.vert
 *******************************************************/

varying mat4 v_cloud_rotator;
varying float v_fov;
varying float v_night;
varying vec3 v_sky_radiance;
varying vec3 v_fogcolor;

void main()
{
    if (!frx_worldFlag(FRX_WORLD_IS_OVERWORLD)) return;
    // float brightnessMult = mix(1.0, BRIGHT_FINAL_MULT, frx_viewBrightness());
    #if CLOUD_RENDERING == CLOUD_RENDERING_FLAT
        float rainFactor = frx_rainGradient() * 0.67 + frx_thunderGradient() * 0.33;
        float cloud = 0.0;

        vec4 viewPos = frx_inverseProjectionMatrix() * vec4(2.0 * v_texcoord - 1.0, 1.0, 1.0);
        viewPos.xyz /= viewPos.w;
        vec3 skyVec = normalize(viewPos.xyz);
        vec3 worldSkyVec = skyVec * frx_normalModelMatrix();
        float skyDotUp = dot(skyVec, v_up);
        
        // convert hemisphere to plane centered around cameraPos
        vec2 cloudPlane = worldSkyVec.xz / (0.1 + worldSkyVec.y) * 100.0
            + frx_cameraPos().xz + vec2(4.0) * frx_renderSeconds();//(frx_worldDay() + frx_worldTime());
        vec2 rotatedCloudPlane = (v_cloud_rotator * vec4(cloudPlane.x, 0.0, cloudPlane.y, 0.0)).xz;
        cloudPlane *= 0.1;

        float cloudBase = 1.0
            * l2_clampScale(0.0, 0.1, skyDotUp)
            * l2_clampScale(-0.5 - rainFactor * 0.5, 1.0 - rainFactor, snoise(rotatedCloudPlane * 0.005));
        float cloud1 = cloudBase * l2_clampScale(-1.0, 1.0, snoise(rotatedCloudPlane * 0.015));
        float cloud2 = cloud1 * l2_clampScale(-1.0, 1.0, snoise(rotatedCloudPlane * 0.04));
        float cloud3 = cloud2 * l2_clampScale(-1.0, 1.0, snoise(rotatedCloudPlane * 0.1));

        cloud = cloud1 * 0.5 + cloud2 * 0.75 + cloud3;
        cloud = l2_clampScale(0.1, 0.4, cloud);
        
        float cloudColor = frx_ambientIntensity() * frx_ambientIntensity() * (1.0 - 0.3 * rainFactor);

        vec4 clouds = vec4(hdr_orangeSkyColor(vec3(cloudColor), -skyVec), 1.0) * cloud;
        gl_FragData[0] = clouds;
        gl_FragData[1] = vec4(cloud > 0.5 ? 0.99999 : 1.0);
    #elif CLOUD_RENDERING == CLOUD_RENDERING_VOLUMETRIC
        cloud_result volumetric = rayMarchCloud(u_clouds_texture, u_translucent_depth, v_texcoord);
        vec3 color = ldr_tonemap3(v_sky_radiance) * volumetric.lightEnergy;
        float alpha = 1.0 - volumetric.transmittance;
        gl_FragData[0] = vec4(color, alpha);
        #if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
            gl_FragData[1] = vec4(alpha > 0.0 ? 0.9999 : 1.0);
        #else
            vec3 reverseModelPos = volumetric.lastWorldPos - frx_cameraView();
            vec4 reverseClipPos = frx_viewProjectionMatrix() * vec4(reverseModelPos, 1.0);
            reverseClipPos.z /= reverseClipPos.w;
            gl_FragData[1] = vec4(alpha > 0.0 ? reverseClipPos.z : 1.0);
        #endif
    #else
        vec4 clouds = blur13(u_clouds, v_texcoord, frxu_size, vec2(1.0, 1.0));
        gl_FragData[0] = clouds;
        gl_FragData[1] = texture2D(u_clouds_depth, v_texcoord);
        // Thanks to Lomo for the inspiration on depth copying
    #endif
}


