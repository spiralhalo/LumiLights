#include frex:shaders/api/view.glsl
#include frex:shaders/api/player.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/tile_noise.glsl
#include lumi:shaders/context/post/fog.glsl

/*******************************************************
 *  lumi:shaders/lib/fog2.glsl                  *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

float raymarched_fog_density(float jitter, vec3 viewPos, vec3 worldPos, float fogFar)
{
    vec3 unitMarch = normalize(-viewPos);
    vec3 ray_view = viewPos + unitMarch * jitter;
    float distToCamera = distance(worldPos, frx_cameraPos());
    int stepCount = 0;
    while (ray_view.z < 0 && stepCount < 128) {
        stepCount ++;
        ray_view += unitMarch;
    }
    return float(stepCount) / fogFar;
}

void fog (inout vec3 a, vec2 texcoord, float depth/*, inout float bloom*/)
{
    vec4 _view = frx_inverseProjectionMatrix() * vec4(2.0 * texcoord - 1.0, 2.0 * depth - 1.0, 1.0);
    _view.xyz /= _view.w;
    vec3  viewPos = _view.xyz;
    vec3  worldPos = frx_cameraPos() + (frx_inverseViewMatrix() * vec4(viewPos, 1.0)).xyz;
    float tileJitter = tile_noise_1d(texcoord, frxu_size, 3);
    float fogDensity = frx_viewFlag(FRX_CAMERA_IN_FLUID) ? UNDERWATER_FOG_DENSITY : FOG_DENSITY;
    float fogFar = frx_viewFlag(FRX_CAMERA_IN_FLUID) ? UNDERWATER_FOG_FAR : FOG_FAR;
    float fogNear = frx_viewFlag(FRX_CAMERA_IN_FLUID) ? UNDERWATER_FOG_NEAR : FOG_NEAR;
    fogFar = max(fogNear, fogFar);

    // float fog_noise = snoise(worldPos.xz * FOG_NOISE_SCALE + frx_renderSeconds() * FOG_NOISE_SPEED) * FOG_NOISE_HEIGHT;
    float fogTop = FOG_TOP /*+ fog_noise*/;
    
    if (!frx_viewFlag(FRX_CAMERA_IN_FLUID) && frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT)) {
        float zigZagTime = abs(frx_worldTime()-0.5);
        float timeFactor = (l2_clampScale(0.45, 0.5, zigZagTime) + l2_clampScale(0.05, 0.0, zigZagTime));
        float thickener = 1.0;
        thickener -= 0.25 * timeFactor;
        thickener -= 0.5 * thickener * frx_rainGradient();
        thickener -= 0.5 * thickener * frx_thunderGradient();
        fogNear *= thickener;
        fogFar *= thickener;
        fogTop = mix(fogTop, max(FOG_TOP, 128.0), (1.0 - thickener));
        fogDensity = mix(fogDensity, 1.0, (1.0 - thickener));
    }
    
    float heightFactor = l2_clampScale(fogTop, FOG_BOTTOM, worldPos.y);
    heightFactor = frx_viewFlag(FRX_CAMERA_IN_FLUID) ? 1.0 : heightFactor;

    // #if defined(VOLUMETRIC_FOG)
    float fogFactor = fogDensity * heightFactor;
    // #else
    // float fogFactor = fogDensity * heightFactor * (frx_viewFlag(FRX_CAMERA_IN_FLUID) ? 1.0 : skylightFactor);
    // #endif

    if (frx_playerHasEffect(FRX_EFFECT_BLINDNESS)) {
        float blindnessModifier = l2_clampScale(0.5, 1.0, 1.0 - frx_luminance(v_skycolor));
        fogFar = mix(fogFar, 3.0, blindnessModifier);
        fogNear = mix(fogNear, 0.0, blindnessModifier);
        fogFactor = mix(fogFactor, 1.0, blindnessModifier);
    }

    if (frx_viewFlag(FRX_CAMERA_IN_LAVA)) {
        fogFar = frx_playerHasEffect(FRX_EFFECT_FIRE_RESISTANCE) ? 2.5 : 0.5;
        fogNear = 0.0;
        fogFactor = 1.0;
    }

    // TODO: retrieve fog distance from render distance ?
    // PERF: use projection z (linear depth) instead of length(viewPos)

    #if defined(VOLUMETRIC_FOG)
    float distFactor = raymarched_fog_density(viewPos, worldPos, fogFar);
    #else
    float distFactor = l2_clampScale(fogNear, fogFar, length(viewPos));
    distFactor *= distFactor;
    #endif

    fogFactor = clamp(fogFactor * distFactor, 0.0, 1.0);
    
    vec3 fogColor = hdr_orangeSkyColor(v_skycolor, normalize(-viewPos));
    // bloom = mix(bloom, 0.0, fogFactor);
    a = mix(a, fogColor, fogFactor);
}
