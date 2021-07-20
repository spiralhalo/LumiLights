#include frex:shaders/api/world.glsl
#include lumi:shaders/common/shadow.glsl
#include lumi:shaders/lib/caustics.glsl

/*******************************************************
 *  lumi:shaders/func/volumetrics.glsl                 *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

vec4 underwaterLightRays(sampler2DArrayShadow sshadow, vec3 modelPos, float tileJitter, float translucentDepth, float depth)
{
    bool doUnderwaterRays = frx_viewFlag(FRX_CAMERA_IN_WATER) && translucentDepth >= depth && frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT);
    vec3 unit = normalize(modelPos);
    float scatter = dot(unit, frx_skyLightVector());

    scatter = 0.5 - abs(scatter - 0.5);
    scatter *= 2.0;

    if (!doUnderwaterRays || scatter <= 0.0) {
        return vec4(0.0);
    }

    const float sample = 2.0;
    const int maxSteps = 10;
    const float range = 10.0;
    const float beamL = 3.;
    const float basePower = 1.0;
    const float deadRadius = 4.0;

    vec3 ray = frx_cameraPos();
    vec3 march = unit * sample;
    float maxDist = length(modelPos);

    ray += tileJitter * march + unit * deadRadius;

    float power = 0.0;
    float traveled = tileJitter * sample + deadRadius;
    int steps = 0;

    while (traveled < maxDist && steps < maxSteps) {
        float e = 0.0;

        e = caustics(ray);
        e = pow(e, 30.0);
        // e *= traveled / range;

    #ifdef SHADOW_MAP_PRESENT
        vec4 ray_shadow = (frx_shadowViewMatrix() * vec4(ray - frx_cameraPos(), 1.0));
        e *= simpleShadowFactor(sshadow, ray_shadow);
    #endif

        power += e;
        ray += march;
        traveled += sample;
        steps ++;
    }

    power = power * sample / float(maxSteps) * scatter * basePower;

    vec3 scatterColor = atmos_hdrFogColorRadiance(unit);

    scatterColor /= l2_max3(scatterColor);

    float scatterLuminance = frx_luminance(scatterColor);

    scatterColor = scatterLuminance == 0.0 ? vec3(1.0) : scatterColor / scatterLuminance;

    return vec4(atmos_hdrCelestialRadiance() * scatterColor, power);
}
