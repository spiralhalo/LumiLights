#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/func/tonemap.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/func/flat_cloud.glsl                  *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

mat4 computeCloudRotator() {
    return l2_rotationMatrix(vec3(0.0, 1.0, 0.0), PI * 0.25);
}

vec4 flatCloud(in vec3 worldVec, in mat4 cloudRotator, in vec3 up)
{
    float rainFactor = frx_rainGradient() * 0.67 + frx_thunderGradient() * 0.33;
    float cloud = 0.0;
    float skyDotUp = worldVec.y;

    // convert hemisphere to plane centered around cameraPos
    vec2 cloudPlane = worldVec.xz / (0.1 + worldVec.y) * 100.0
        + frx_cameraPos().xz + vec2(4.0) * frx_renderSeconds();//(frx_worldDay() + frx_worldTime());
    vec2 rotatedCloudPlane = (cloudRotator * vec4(cloudPlane.x, 0.0, cloudPlane.y, 0.0)).xz;
    cloudPlane *= 0.1;

    float cloudBase = 1.0
        * l2_clampScale(0.0, 0.1, skyDotUp)
        * l2_clampScale(-0.5 - rainFactor * 0.5, 1.0 - rainFactor, snoise(rotatedCloudPlane * 0.005));
    float cloud1 = cloudBase * l2_clampScale(-1.0, 1.0, snoise(rotatedCloudPlane * 0.015));
    float cloud2 = cloud1 * l2_clampScale(-1.0, 1.0, snoise(rotatedCloudPlane * 0.04));
    float cloud3 = cloud2 * l2_clampScale(-1.0, 1.0, snoise(rotatedCloudPlane * 0.1));

    cloud = cloud1 * 0.5 + cloud2 * 0.75 + cloud3;
    cloud = l2_clampScale(0.1, 0.4, cloud);

    vec3 color = (ldr_tonemap3(atmos_hdrCelestialRadiance() * 0.1) + ldr_tonemap3(atmos_hdrSkyColorRadiance(worldVec) * 0.2)) * cloud;
    return vec4(color, cloud);
}
