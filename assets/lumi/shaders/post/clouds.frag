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
#include lumi:shaders/context/global/experimental.glsl

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

const float CLOUD_RCP = 1.0 / 128.0;

void main()
{
    // float brightnessMult = mix(1.0, BRIGHT_FINAL_MULT, frx_viewBrightness());
    #if CLOUD_RENDERING == CLOUD_RENDERING_FLAT
        if (frx_worldFlag(FRX_WORLD_IS_OVERWORLD)) {
            float rainFactor = frx_rainGradient() * 0.67 + frx_thunderGradient() * 0.33;
            vec4 viewPos = frx_inverseProjectionMatrix() * vec4(2.0 * v_texcoord - 1.0, 1.0, 1.0);
            viewPos.xyz /= viewPos.w;
            vec3 skyVec = normalize(viewPos.xyz);
            vec3 worldSkyVec = skyVec * frx_normalModelMatrix();
            float skyDotUp = dot(skyVec, v_up);
            
            // convert hemisphere to plane centered around cameraPos
            vec2 cloudPlane = worldSkyVec.xz / (0.1 + worldSkyVec.y) * 40.0;
            cloudPlane *= CLOUD_RCP;
            cloudPlane += 0.5;

            vec2 edgeFactor = smoothstep(0.5, 0.4, abs(cloudPlane - 0.5));
            float e = edgeFactor.x * edgeFactor.y;
            float cloud = e * l2_clampScale(0.0, 0.1, skyDotUp) * texture2D(u_clouds_texture, cloudPlane).r;
            
            float cloudColor = frx_ambientIntensity() * frx_ambientIntensity() * (1.0 - 0.3 * rainFactor);

            vec4 clouds = vec4(hdr_orangeSkyColor(vec3(cloudColor), -skyVec), 1.0) * cloud;
            gl_FragData[0] = clouds;
            gl_FragData[1] = vec4(cloud > 0.5 ? 0.99999 : 1.0);
        }
    #elif CLOUD_RENDERING == CLOUD_RENDERING_VOLUMETRIC
        if (frx_worldFlag(FRX_WORLD_IS_OVERWORLD)) {
            cloud_result volumetric = rayMarchCloud(u_clouds_texture, u_translucent_depth, v_texcoord);
            vec3 color = ldr_tonemap3(v_sky_radiance) * volumetric.lightEnergy;
            vec3 reverseModelPos = volumetric.lastWorldPos - frx_cameraView();
            vec4 reverseClipPos = frx_viewProjectionMatrix() * vec4(reverseModelPos, 1.0);
            reverseClipPos.xyz /= reverseClipPos.w;
            float alpha = 1.0 - volumetric.transmittance;
            gl_FragData[0] = vec4(color, alpha);
            gl_FragData[1] = vec4(alpha > 0.0 ? 0.9999 : 1.0);
        }
    #else
        vec4 clouds = blur13(u_clouds, v_texcoord, frxu_size, vec2(1.0, 1.0));
        gl_FragData[0] = clouds;
        gl_FragData[1] = texture2D(u_clouds_depth, v_texcoord);
        // Thanks to Lomo for the inspiration on depth copying
    #endif
}


