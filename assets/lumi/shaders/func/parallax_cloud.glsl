#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/func/tile_noise.glsl

/*******************************************************
 *  lumi:shaders/func/parallax_cloud.glsl              *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

#if CLOUD_RENDERING == CLOUD_RENDERING_PARALLAX
#define wnoise3(a) cellular2x2x2(a).x
vec4 parallaxCloud(in sampler2D sbluenoise, in vec2 texcoord, in vec3 worldVec)
{
    float rainFactor = frx_rainGradient() * 0.67 + frx_thunderGradient() * 0.33;
    float skyDotUp = worldVec.y;

    if (skyDotUp <= 0.05) {
        return vec4(0.);
    }
    
    const int parallaxSample = 3;
    const float parallaxAvg = 1. / float(parallaxSample);
    const float CLOUD_ALTITUDE  = PARALLAX_CLOUD_ALTITUDE;
    const float CLOUD_THICKNESS = PARALLAX_CLOUD_THICKNESS;
    
    vec3 start  = worldVec * ((CLOUD_ALTITUDE + CLOUD_THICKNESS) / worldVec.y);
    vec3 finish = worldVec * (CLOUD_ALTITUDE / worldVec.y);
    vec3 move   = (finish - start) * parallaxAvg;

    float tileJitter = getRandomFloat(sbluenoise, texcoord, frxu_size);
    float animatonator = frx_renderSeconds() * 0.1;

    vec3  globalColor  = vec3(0.0);
    float globalCloud  = 0.0;
    vec3 current = start + move * tileJitter;

    current.xz += frx_cameraPos().xz + frx_renderSeconds() * 2.0;

    for (int i = parallaxSample; i > 0; i --) {
        vec3 cloudBox = current;

        current += move;

        float cloudBase = l2_clampScale(-0.5 - rainFactor * 0.5, 1.0 - rainFactor, snoise(cloudBox * 0.005));
        float cloudFluff = snoise(cloudBox * 0.015 + animatonator);

        float cloud1 = cloudBase * l2_clampScale(-1.0, 1.0, cloudFluff);
        float localCloud = l2_clampScale(0.15, 0.35, cloud1);

        localCloud *= PARALLAX_CLOUD_DENSITY;

        float topness = float(i) * parallaxAvg;
        vec3 localColor = atmos_hdrCelestialRadiance() * topness * 0.1 + atmos_hdrCloudColorRadiance(worldVec);

        globalColor = globalColor * (1.0 - localCloud) + localColor;
        globalCloud += localCloud;
    }

    globalCloud = min(1., globalCloud * parallaxAvg);
    globalCloud *= l2_clampScale(0.05, 0.15, skyDotUp);

    return vec4(globalColor, globalCloud);
}
#endif
