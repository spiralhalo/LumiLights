#include frex:shaders/lib/math.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/tile_noise.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include frex:shaders/lib/noise/cellular2x2.glsl
#include lumi:shaders/post/common/clouds.glsl

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
    const float CLOUD_ALTITUDE = 55.0;
#else
    const float CLOUD_ALTITUDE = 115.5;
#endif
const float CLOUD_HEIGHT = 20.0;
const float CLOUD_MID_HEIGHT = 5.0;
const float CLOUD_TOP_HEIGHT = CLOUD_HEIGHT - CLOUD_MID_HEIGHT;
const float CLOUD_MID_ALTITUDE = CLOUD_ALTITUDE + CLOUD_MID_HEIGHT;
const float CLOUD_MIN_Y = CLOUD_ALTITUDE;
const float CLOUD_MAX_Y = CLOUD_ALTITUDE + CLOUD_HEIGHT;

float sampleCloud(in vec3 worldPos, in sampler2D texture)
{
    #if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
        vec2 uv = modelXz2Uv(worldPos.xz);
    #else
        vec2 uv = worldXz2Uv(worldPos.xz);
    #endif

    vec2 edge = smoothstep(0.5, 0.4, abs(uv - 0.5));
    float eF = edge.x * edge.y;

    vec2 tex = texture2D(texture, uv).rg; 
    float tF = tex.r;
    float hF = tex.g;
    float yF = smoothstep(CLOUD_MID_ALTITUDE + CLOUD_TOP_HEIGHT * hF, CLOUD_MID_ALTITUDE, worldPos.y) * smoothstep(CLOUD_ALTITUDE, CLOUD_MID_ALTITUDE, worldPos.y);

    return smoothstep(0.1, 0.2, yF * tF * eF);
    // return smoothstep(0.1, 0.11, yF * tF * eF);
}

cloud_result rayMarchCloud(in sampler2D texture, in sampler2D sdepth, in vec2 texcoord)
{
    float rainFactor = frx_rainGradient() * 0.67 + frx_thunderGradient() * 0.33; // TODO: optimize
    float depth = texture2D(sdepth, texcoord).r;
    float maxDist;
    vec3 worldVec;

    cloud_result placeholder = cloud_result(0.0, 1.0, vec3(0.0));
    if (depth == 1.0) {
        vec4 viewPos = frx_inverseProjectionMatrix() * vec4(2.0 * texcoord - 1.0, 1.0, 1.0);
        viewPos.xyz /= viewPos.w;
        vec3 viewVec = normalize(viewPos.xyz);
        worldVec = viewVec * frx_normalModelMatrix();
        maxDist = 1024.0;
    } else {
        #if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
            return placeholder; // Some sort of culling
        #else
            vec4 viewPos = frx_inverseProjectionMatrix() * vec4(2.0 * texcoord - 1.0, 2.0 * depth - 1.0, 1.0);
            viewPos.xyz /= viewPos.w;
            maxDist = length(viewPos.xyz);
            worldVec = normalize(viewPos.xyz) * frx_normalModelMatrix();
        #endif
    }

    vec3 unitSample = worldVec * SAMPLE_SIZE;
    vec3 toLight = frx_skyLightVector() * LIGHT_SAMPLE_SIZE;

    // Adapted from Sebastian Lague's code (technically not the same, but just in case his code was MIT Licensed)

    float tileJitter = tile_noise_1d(v_texcoord, frxu_size, 3); //CLOUD_MARCH_JITTER_STRENGTH;
    float traveled = SAMPLE_SIZE * tileJitter;

    // Optimization block
    #if VOLUMETRIC_CLOUD_MODE == VOLUMETRIC_CLOUD_MODE_SKYBOX
        if (worldVec.y <= 0) return placeholder;
        float gotoBottom = CLOUD_MIN_Y / worldVec.y;
        vec3 currentWorldPos = worldVec * gotoBottom;/*frx_cameraPos()*/
        traveled += gotoBottom;
    #else
        vec3 currentWorldPos = frx_cameraPos();
        float gotoBorder = 0.0;
        if (currentWorldPos.y >= CLOUD_MAX_Y) {
            if (worldVec.y >= 0) return placeholder;
            gotoBorder = (currentWorldPos.y - CLOUD_MAX_Y) / -worldVec.y;
        } else if (currentWorldPos.y <= CLOUD_MIN_Y) {
            if (worldVec.y <= 0) return placeholder;
            gotoBorder = (CLOUD_MIN_Y - currentWorldPos.y) / worldVec.y;
        }
        currentWorldPos += worldVec * gotoBorder;
        traveled += gotoBorder;
    #endif
    
    currentWorldPos += unitSample * tileJitter;

    float lightEnergy = 0.0;
    float transmittance = 1.0;

    // ATTEMPT 1
    bool first = true;
    vec3 firstHitPos = currentWorldPos + worldVec * 1024.0;
    // ATTEMPT 2
    // float maxDensity = 0.0;
    // vec3 firstDensePos = worldPos - worldVec * 0.1;

    int i = 0;
    while (traveled < maxDist && currentWorldPos.y >= CLOUD_MIN_Y && currentWorldPos.y <= CLOUD_MAX_Y && i < NUM_SAMPLE) {
        i ++;
        traveled += SAMPLE_SIZE;
        currentWorldPos += unitSample;
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
     // TODO: optimize?
    float rainFactor = frx_rainGradient() * 0.67;// + frx_thunderGradient() * 0.33;
    vec2 cloudCoord = uv2worldXz(texcoord) + (frx_worldDay() + frx_worldTime()) * 800.0;
    cloudCoord *= 2.0;

    float cloudBase = l2_clampScale(0.0, 1.0 - rainFactor, snoise(cloudCoord * 0.005));
    float cloud1 = cloudBase * l2_clampScale(0.0, 1.0, wnoise2(cloudCoord * 0.015));
    float cloud2 = cloud1 * l2_clampScale(-1.0, 1.0, snoise(cloudCoord * 0.04));
    float cloud3 = cloud2 * l2_clampScale(-1.0, 1.0, snoise(cloudCoord * 0.1));

    float cloud = cloud1 * 0.5 + cloud2 * 0.75 + cloud3;

    cloud = l2_clampScale(0.1, 1.0, cloud);

    // cloud = sqrt(1.0 - pow(1.0 - cloud, 2.0));
    return vec4(cloud, sqrt(1.0 - pow(1.0 - cloud1 * cloud2, 2.0)), 0.0, 1.0);
}
#endif
