#include frex:shaders/lib/math.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/tile_noise.glsl
#include lumi:shaders/context/global/experimental.glsl

/*******************************************************
 *  lumi:shaders/lib/volumetric_cloud.glsl             *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

#if CLOUD_RENDERING == CLOUD_RENDERING_VOLUMETRIC

struct cloud_result {
    float lightEnergy;
    float transmittance;
    vec3 lastWorldPos;
};

// const float CLOUD_MARCH_JITTER_STRENGTH = 0.01;
const float TEXTURE_RCP = 1.0 / 256.0;
const int NUM_SAMPLE = 512;
const float SAMPLE_SIZE = 0.25;
const int LIGHT_SAMPLE = 5;
const float LIGHT_SAMPLE_SIZE = 0.25;
const float LIGHT_ABSORPTION_SKYLIGHT = 0.9;
const float LIGHT_ABSORPTION_CLOUD = 0.7;
const float DARKNESS_THRESHOLD = 0.2;
const float DARKNESS_THRESHOLD_INV = 1.0 - DARKNESS_THRESHOLD;
const float CLOUD_MAX_Y = 20.0;
const float CLOUD_MIN_Y = 15.0;
const float CLOUD_Y = (CLOUD_MAX_Y + CLOUD_MIN_Y) * 0.5;
const float CLOUD_THICKNESS_H = (CLOUD_MAX_Y - CLOUD_MIN_Y) * 0.5;

float sampleCloud(in vec3 worldPos, in sampler2D texture)
{
    vec2 uv = (worldPos.xz/* - frx_cameraPos().xz*/) * TEXTURE_RCP + 0.5;
    vec2 edge = smoothstep(0.5, 0.4, abs(uv - 0.5));
    float eF = edge.x * edge.y;
    float tF = texture2D(texture, uv).r;
    float yF = l2_clampScale(CLOUD_THICKNESS_H * tF, CLOUD_THICKNESS_H * tF * 0.5, abs(CLOUD_Y - worldPos.y));
    return eF * yF * tF * 2.0;
}

cloud_result rayMarchCloud(in sampler2D texture, in sampler2D sdepth, in vec2 texcoord)
{
    // vec3 tileJitter = 2.0 * tile_noise_3d(v_texcoord, frxu_size, 4) - 1.0;
    // tileJitter *= CLOUD_MARCH_JITTER_STRENGTH;
    float rainFactor = frx_rainGradient() * 0.67 + frx_thunderGradient() * 0.33; // TODO: optimize
    float depth = texture2D(sdepth, texcoord).r;
    vec3 worldPos;
    vec3 worldVec;
    float worldDist;

    cloud_result placeholder = cloud_result(0.0, 1.0, vec3(0.0));
    if (depth == 1.0) {
        vec4 viewPos = frx_inverseProjectionMatrix() * vec4(2.0 * texcoord - 1.0, 1.0, 1.0);
        viewPos.xyz /= viewPos.w;
        vec3 viewVec = normalize(viewPos.xyz);
        worldVec = viewVec * frx_normalModelMatrix();
        worldDist = 256.0;
        worldPos = /*frx_cameraPos() +*/ worldVec * worldDist;
    } else {
        return placeholder;
        vec4 modelPos = frx_inverseViewProjectionMatrix() * vec4(2.0 * texcoord - 1.0, 2.0 * depth - 1.0, 1.0);
        modelPos.xyz /= modelPos.w;
        worldVec = normalize(modelPos.xyz);
        worldDist = length(modelPos.xyz);
        worldPos = /*frx_cameraPos() +*/ modelPos.xyz;
    }

    vec3 sampleDir = worldVec * SAMPLE_SIZE;
    vec3 toLight = frx_skyLightVector() * LIGHT_SAMPLE_SIZE;

    // Adapted from Sebastian Lague's code (technically not the same, but just in case his code was MIT Licensed)
    vec3 currentWorldPos = vec3(0.0)/*frx_cameraPos()*/;
    vec3 lastWorldPos = worldPos - worldVec;
    bool hit = false;
    float lightEnergy = 0.0;
    float transmittance = 1.0;
    float maxdist = min(worldDist, NUM_SAMPLE * SAMPLE_SIZE);
    float travelled = 0.0;

    /* This performance saver only works with the fixed cloud position */
    if (worldVec.y <= 0) return placeholder;
    float gotoBottom = CLOUD_MIN_Y / worldVec.y;
    float gotoTop = CLOUD_MAX_Y / worldVec.y;
    travelled += gotoBottom;
    currentWorldPos += worldVec * travelled;
    maxdist = min(maxdist, gotoTop);
    /**/

    while (travelled < maxdist) {
        travelled += SAMPLE_SIZE;
        currentWorldPos += sampleDir;
        float sampledDensity = sampleCloud(currentWorldPos, texture);
        if (sampledDensity > 0) {
            vec3 occlusionWorldPos = currentWorldPos;
            // vec3 lightPos = frx_skyLightVector() * 512.0 + frx_cameraPos();
            float occlusionDensity = 0.0;
            int j = 0;
            while (j < LIGHT_SAMPLE && occlusionWorldPos.y < CLOUD_MAX_Y && occlusionWorldPos.y > CLOUD_MIN_Y) {
                j ++;
                occlusionWorldPos += toLight;
                occlusionDensity += sampleCloud(occlusionWorldPos, texture);
            }
            occlusionDensity *= LIGHT_SAMPLE_SIZE; // this is what *stepSize means
            float lightTransmittance = DARKNESS_THRESHOLD + DARKNESS_THRESHOLD_INV * exp(-occlusionDensity * LIGHT_ABSORPTION_SKYLIGHT);
            lightEnergy += sampledDensity * transmittance * lightTransmittance * SAMPLE_SIZE; // * phaseVal;
            transmittance *= exp(-sampledDensity * LIGHT_ABSORPTION_CLOUD * SAMPLE_SIZE);
            if (transmittance < 0.01) break;
        }
    }
    return cloud_result(lightEnergy, transmittance, lastWorldPos);
}
#endif
