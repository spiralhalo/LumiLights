#include frex:shaders/lib/math.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/lib/util.glsl
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

const float TEXTURE_RCP = 1.0 / 512.0;
const int NUM_SAMPLE = 512;
const float SAMPLE_SIZE = 1.0;
const int LIGHT_SAMPLE = 30;
const float LIGHT_SAMPLE_RCP = 1.0 / float(LIGHT_SAMPLE);
const float LIGHT_ABSORPTION_SKYLIGHT = 0.9;
const float LIGHT_ABSORPTION_CLOUD = 0.9;
const float DARKNESS_THRESHOLD = 0.2;
const float DARKNESS_THRESHOLD_INV = 1.0 - DARKNESS_THRESHOLD;
const float CLOUD_MAX_Y = 130.0;
const float CLOUD_MIN_Y = 120.0;
const float CLOUD_Y = (CLOUD_MAX_Y + CLOUD_MIN_Y) * 0.5;
const float CLOUD_THICKNESS_H = (CLOUD_MAX_Y - CLOUD_MIN_Y) * 0.5;

float sampleCloud(in vec3 worldPos, in sampler2D texture)
{
    vec2 uv = (worldPos.xz - frx_cameraPos().xz) * TEXTURE_RCP + 0.5;
    vec2 edge = smoothstep(0.5, 0.4, abs(uv - 0.5));
    float eF = edge.x * edge.y;
    float yF = smoothstep(CLOUD_THICKNESS_H, 0.0, abs(CLOUD_Y - worldPos.y));
    float tF = texture2D(texture, uv).r;
    return eF * yF * tF * 2.0;
}

cloud_result rayMarchCloud(in sampler2D texture, in sampler2D sdepth, in vec2 texcoord)
{
    float rainFactor = frx_rainGradient() * 0.67 + frx_thunderGradient() * 0.33; // TODO: optimize
    float depth = texture2D(sdepth, texcoord).r;
    vec3 worldPos;
    vec3 worldVec;
    float worldDist;
    if (depth == 1.0) {
        vec4 viewPos = frx_inverseProjectionMatrix() * vec4(2.0 * texcoord - 1.0, 1.0, 1.0);
        viewPos.xyz /= viewPos.w;
        vec3 viewVec = normalize(viewPos.xyz);
        worldVec = viewVec * frx_normalModelMatrix();
        worldDist = 512.0;
        worldPos = frx_cameraPos() + worldVec * worldDist;
    } else {
        vec4 modelPos = frx_inverseViewProjectionMatrix() * vec4(2.0 * texcoord - 1.0, 2.0 * depth - 1.0, 1.0);
        modelPos.xyz /= modelPos.w;
        worldVec = normalize(modelPos.xyz);
        worldDist = length(modelPos.xyz);
        worldPos = frx_cameraPos() + modelPos.xyz;
    }

    vec3 sampleDir = worldVec * SAMPLE_SIZE;

    // Adapted from Sebastian Lague's code (technically not the same, but just in case his code was MIT Licensed)
    vec3 currentWorldPos = frx_cameraPos();
    vec3 lastWorldPos = worldPos;
    bool hit = false;
    float lightEnergy = 0.0;
    float transmittance = 1.0;
    float maxdist = min(worldDist, NUM_SAMPLE * SAMPLE_SIZE);
    float travelled = 0.0;
    while (travelled < maxdist) {
        travelled += SAMPLE_SIZE;
        currentWorldPos += sampleDir;
        float sampledDensity = sampleCloud(currentWorldPos, texture);
        if (sampledDensity > 0) {
            vec3 occlusionWorldPos = currentWorldPos;
            if (!hit) {
                lastWorldPos = currentWorldPos;
                hit = true;
            }
            // vec3 lightPos = frx_skyLightVector() * 512.0 + frx_cameraPos();
            vec3 toLight = frx_skyLightVector() * LIGHT_SAMPLE_RCP;
            float occlusionDensity = 0.0;
            int j = 0;
            while (j < LIGHT_SAMPLE) {
                j ++;
                occlusionWorldPos += toLight;
                occlusionDensity += sampleCloud(occlusionWorldPos, texture);
            }
            occlusionDensity *= LIGHT_SAMPLE_RCP; // this is what *stepSize means
            float lightTransmittance = DARKNESS_THRESHOLD + DARKNESS_THRESHOLD_INV * exp(-occlusionDensity * LIGHT_ABSORPTION_SKYLIGHT);
            lightEnergy += sampledDensity * transmittance * lightTransmittance * SAMPLE_SIZE; // * phaseVal;
            transmittance *= exp(-sampledDensity * LIGHT_ABSORPTION_CLOUD);
            if (transmittance < 0.01) break;
        }
    }
    return cloud_result(lightEnergy, transmittance, lastWorldPos);
}
#endif
