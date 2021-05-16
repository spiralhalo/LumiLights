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

#if CLOUD_RENDERING == CLOUD_RENDERING_PARALLAX
#define wnoise3(a) cellular2x2x2(a).x
vec4 parallaxCloud(in sampler2D sbluenoise, in vec2 texcoord)
{
    float rainFactor = frx_rainGradient() * 0.67 + frx_thunderGradient() * 0.33;

    vec4 worldPos = frx_inverseViewProjectionMatrix() * vec4(2.0 * texcoord - 1.0, 1.0, 1.0);
    worldPos.xyz /= worldPos.w;
    vec3 worldSkyVec = normalize(worldPos.xyz);
    float skyDotUp = dot(worldSkyVec, vec3(0., 1., 0.));

    if (skyDotUp <= 0.05) {
        return vec4(0.);
    }
    
    const int flatLoop = 3;
    const float flatMult = 1./float(flatLoop);
    const float CLOUD_ALTITUDE  = PARALLAX_CLOUD_ALTITUDE;
    const float CLOUD_THICKNESS = PARALLAX_CLOUD_THICKNESS;
    
    vec3 start  = worldSkyVec * ((CLOUD_ALTITUDE + CLOUD_THICKNESS) / worldSkyVec.y);
    vec3 finish = worldSkyVec * (CLOUD_ALTITUDE / worldSkyVec.y);
    vec3 move   = (finish - start) * flatMult;

    float tileJitter = getRandomFloat(sbluenoise, texcoord + frx_renderSeconds() * 0.1, frxu_size);
    
    vec3  color  = vec3 (0.0);
    float cloud  = 0.0;
    vec3 current = start + move * tileJitter;

    current.xz += frx_cameraPos().xz + vec2(4.0) * frx_renderSeconds();

    for (int i = flatLoop; i > 0; i --) {
        vec3 cloudBox = current;
        current += move;

        float cloudBase = l2_clampScale(-0.5 - rainFactor * 0.5, 1.0 - rainFactor, snoise(cloudBox * 0.005));
        float cloudFluff = snoise(cloudBox * 0.015);
        float cloud1 = cloudBase * l2_clampScale(-1.0, 1.0, cloudFluff);
        float localCloud;
        localCloud = l2_clampScale(0.15, 0.45, cloud1);
        localCloud *= flatMult * PARALLAX_CLOUD_DENSITY;

        float topness = float(i) * flatMult;

        vec3 localColor = ldr_tonemap3(atmos_hdrCelestialRadiance() * 0.2) * topness + ldr_tonemap3(atmos_hdrSkyColorRadiance(worldSkyVec) * 0.3);
        if (i == flatLoop) {
            color = localColor;
        } else {
            color = color * (1.0 - cloud) + localColor * cloud;
        }
        cloud += localCloud;
    }

    cloud = min(1., cloud);
    cloud *= l2_clampScale(0.05, 0.15, skyDotUp);
    color *= cloud;
    return vec4(color, cloud);
}
#endif
