#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/func/tonemap.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/tile_noise.glsl

/*******************************************************
 *  lumi:shaders/func/parallax_cloud.glsl              *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

#define wnoise3(a) cellular2x2x2(a).x
vec4 parallaxCloud(in vec2 texcoord, in vec3 up)
{
    float rainFactor = frx_rainGradient() * 0.67 + frx_thunderGradient() * 0.33;
    float cloud = 0.0;

    vec4 viewPos = frx_inverseProjectionMatrix() * vec4(2.0 * texcoord - 1.0, 1.0, 1.0);
    viewPos.xyz /= viewPos.w;
    vec3 skyVec = normalize(viewPos.xyz);
    vec3 worldSkyVec = skyVec * frx_normalModelMatrix();
    float skyDotUp = dot(skyVec, up);
    
    // convert hemisphere to plane centered around cameraPos
    vec3 color = vec3 (0.0);
    const int flatLoop = 6;
    const float flatMult = 1./float(flatLoop);
    const float flatThickness = 0.1;
    float tileJitter = getRandomFloat(texcoord, frxu_size);
    for (int i = flatLoop; i > 0; i --) {
        float cloudY = (float(i) - 1. + tileJitter) * flatThickness * flatMult;
        vec2 cloudPlane = worldSkyVec.xz / (0.1 + worldSkyVec.y + cloudY) * 100.0 + frx_cameraPos().xz + vec2(4.0) * frx_renderSeconds();
        cloudPlane *= 2.;
        vec3 cloudBox = vec3(cloudPlane.x, cloudY * 500., cloudPlane.y);

        float cloudBase = l2_clampScale(-0.5 - rainFactor * 0.5, 1.0 - rainFactor, snoise(cloudBox * 0.005));
        float cloudFluff = snoise(cloudBox * 0.015);
        float cloud1 = cloudBase * l2_clampScale(-1.0, 1.0, cloudFluff);
        float localCloud;
        localCloud = l2_clampScale(0.1, 0.4, cloud1);
        localCloud *= flatMult;

        float topness = float(i) * flatMult * 0.7 + 0.3;

        vec3 localColor = ldr_tonemap3(atmos_hdrCelestialRadiance() * 0.2) * topness + ldr_tonemap3(atmos_hdrSkyColorRadiance(worldSkyVec) * 0.3);
        if (i == flatLoop) {
            color = localColor;
        } else {
            color = color * (1.0 - cloud) + localColor * cloud;
        }
        cloud += localCloud;
    }

    cloud = min(1., cloud);
    cloud *= l2_clampScale(0.0, 0.1, skyDotUp);
    color *= cloud;
    return vec4(color, cloud);
}
