#include frex:shaders/lib/math.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/tile_noise.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include frex:shaders/lib/noise/cellular2x2.glsl
#include lumi:shaders/context/post/clouds.glsl

/*******************************************************
 *  lumi:shaders/lib/volumetric_cloud.glsl             *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

#if CLOUD_RENDERING == CLOUD_RENDERING_VOLUMETRIC
#define wnoise2(a) cellular2x2(a).x

struct cloud_result {
    float lightEnergy;
    float transmittance;
    vec3 worldPos;
};

// const float CLOUD_MARCH_JITTER_STRENGTH = 0.01;
const float TEXTURE_RADIUS = 256.0;
const float TEXTURE_RADIUS_RCP = 1.0 / TEXTURE_RADIUS;
const int NUM_SAMPLE = 512;
const float SAMPLE_SIZE = TEXTURE_RADIUS / float(NUM_SAMPLE);
const int LIGHT_SAMPLE = 5;
const float LIGHT_SAMPLE_SIZE = 0.2;
const float LIGHT_ABSORPTION_SKYLIGHT = 0.99;
const float LIGHT_ABSORPTION_CLOUD = 0.99;
const float DARKNESS_THRESHOLD = 0.2;
const float DARKNESS_THRESHOLD_INV = 1.0 - DARKNESS_THRESHOLD;

// coordinate helper functions because it won't work properly
vec2 uv2worldXz(vec2 uv)
{
    vec2 ndc = uv * 2.0 - 1.0;
    return frx_cameraPos().xz + ndc * TEXTURE_RADIUS;
}

vec2 worldXz2Uv(vec2 worldXz)
{
    vec2 modelXz = worldXz - frx_cameraPos().xz;
    vec2 ndc = modelXz * TEXTURE_RADIUS_RCP;
    return ndc * 0.5 + 0.5;
}

// model means relative to camera not world origin in this context
vec2 modelXz2Uv(vec2 modelXz)
{
    vec2 ndc = modelXz * TEXTURE_RADIUS_RCP;
    return ndc * 0.5 + 0.5;
}

#if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
    const float CLOUD_MAX_Y = 60.0;
    const float CLOUD_MIN_Y = 55.0;
#else
    const float CLOUD_MAX_Y = 120.5;
    const float CLOUD_MIN_Y = 115.5;
#endif
const float CLOUD_Y = (CLOUD_MAX_Y + CLOUD_MIN_Y) * 0.5;
const float CLOUD_THICKNESS_H = (CLOUD_MAX_Y - CLOUD_MIN_Y) * 0.5;

float sampleCloud(in vec3 worldPos, in sampler2D texture)
{
    #if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
        vec2 uv = modelXz2Uv(worldPos.xz);
    #else
        vec2 uv = worldXz2Uv(worldPos.xz);
    #endif

    // vec2 edge = smoothstep(0.5, 0.4, abs(uv - 0.5)); probably unecessary when texture radius <= max sample distance
    // float eF = edge.x * edge.y;

    float tF = texture2D(texture, uv).r;
    tF = sqrt(1.0 - pow(1.0 - tF, 2.0));
    #if VOLUMETRIC_CLOUD_SHAPE == VOLUMETRIC_CLOUD_SHAPE_MARSHMALLOW
        float yF = l2_clampScale(CLOUD_THICKNESS_H * tF, 0.0, abs(CLOUD_Y - worldPos.y));
        yF = sqrt(1.0 - pow(1.0 - yF, 2.0));
    #else // cotton clouds
        float yF = l2_clampScale(CLOUD_THICKNESS_H * tF, CLOUD_THICKNESS_H * tF * 0.5, abs(CLOUD_Y - worldPos.y));
    #endif

    return yF * tF * 2.0;
}

cloud_result rayMarchCloud(in sampler2D texture, in sampler2D sdepth, in vec2 texcoord)
{
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
        #if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
            worldPos = worldVec * worldDist;
        #else
            worldPos = frx_cameraPos() + worldVec * worldDist;
        #endif
    } else {
        #if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
            return placeholder; // Some sort of culling
        #else
            vec4 viewPos = frx_inverseProjectionMatrix() * vec4(2.0 * texcoord - 1.0, 2.0 * depth - 1.0, 1.0);
            viewPos.xyz /= viewPos.w;
            viewPos.w = 1.0;
            worldPos  = frx_cameraPos() + (frx_inverseViewMatrix() * viewPos).xyz;
            worldVec = normalize(viewPos.xyz) * frx_normalModelMatrix();
            if ((worldPos.y < CLOUD_MIN_Y && worldVec.y > 0.0)
            || (worldPos.y > CLOUD_MAX_Y && worldVec.y < 0.0)) {
                return placeholder; // Some sort of culling
            }
            worldDist = distance(worldPos, frx_cameraPos());
        #endif
    }

    vec3 sampleDir = worldVec * SAMPLE_SIZE;
    vec3 toLight = frx_skyLightVector() * LIGHT_SAMPLE_SIZE;

    #if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
        if (worldVec.y <= 0) return placeholder;
        float gotoBottom = CLOUD_MIN_Y / worldVec.y;
        float gotoTop = CLOUD_MAX_Y / worldVec.y;
    #endif

    // Adapted from Sebastian Lague's code (technically not the same, but just in case his code was MIT Licensed)
    #if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
        vec3 currentWorldPos = worldVec * gotoBottom;/*frx_cameraPos()*/;
    #else
        vec3 currentWorldPos = frx_cameraPos();
    #endif
    float lightEnergy = 0.0;
    float transmittance = 1.0;
    float maxdist = min(worldDist, NUM_SAMPLE * SAMPLE_SIZE);
    #if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
        float travelled = gotoBottom;
        maxdist = min(maxdist, gotoTop);
    #else
        float travelled = 0.0;
    #endif
    float tileJitter = tile_noise_1d(v_texcoord, frxu_size, 3); //CLOUD_MARCH_JITTER_STRENGTH;
    currentWorldPos += sampleDir * tileJitter;
    travelled += tileJitter * SAMPLE_SIZE;
    // ATTEMPT 1
    bool first = true;
    vec3 firstHitPos = worldPos - worldVec * 0.1;
    // ATTEMPT 2
    // float maxDensity = 0.0;
    // vec3 firstDensePos = worldPos - worldVec * 0.1;
    int i = 0;
    while (travelled < maxdist && i < NUM_SAMPLE) {
        i ++;
        travelled += SAMPLE_SIZE;
        currentWorldPos += sampleDir;
        float sampledDensity = sampleCloud(currentWorldPos, texture);
        if (sampledDensity > 0) {
            // ATTEMPT 1
            if (first) {
                first = false;
                firstHitPos = currentWorldPos;
            }
            // ATTEMPT 2
            // if (sampledDensity > maxDensity) {
            //     maxDensity = sampledDensity;
            //     firstDensePos = currentWorldPos;
            // }
            vec3 occlusionWorldPos = currentWorldPos;
            // vec3 lightPos = frx_skyLightVector() * 512.0 + frx_cameraPos();
            float occlusionDensity = 0.0;
            int j = 0;
            while (j < LIGHT_SAMPLE) {
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
    return cloud_result(lightEnergy, transmittance, firstHitPos);
}

vec4 generateCloudTexture(vec2 texcoord) {
    float rainFactor = frx_rainGradient() * 0.67 + frx_thunderGradient() * 0.33; // TODO: optimize
    vec2 cloudCoord = uv2worldXz(texcoord) + (frx_worldDay() + frx_worldTime()) * 800.0;
    cloudCoord *= 2.0;

    float cloudBase = l2_clampScale(0.0, 1.0 - rainFactor, snoise(cloudCoord * 0.005));
    float cloud1 = cloudBase * l2_clampScale(0.0, 1.0, wnoise2(cloudCoord * 0.015));
    float cloud2 = cloud1 * l2_clampScale(-1.0, 1.0, snoise(cloudCoord * 0.04));
    float cloud3 = cloud2 * l2_clampScale(-1.0, 1.0, snoise(cloudCoord * 0.1));

    float cloud = cloud1 * 0.5 + cloud2 * 0.75 + cloud3;

    #if VOLUMETRIC_CLOUD_SHAPE == VOLUMETRIC_CLOUD_SHAPE_MARSHMALLOW
        cloud = l2_clampScale(0.3, 0.5, cloud);
    #else // cotton clouds
        cloud = l2_clampScale(0.1, 1.0, cloud);
    #endif

    return vec4(cloud, 0.0, 0.0, 1.0);
}
#endif
