#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include frex:shaders/lib/noise/cellular2x2x2.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/player.glsl
#include frex:shaders/api/material.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/fog.glsl
#include lumi:shaders/lib/tonemap.glsl
#include lumi:shaders/lib/pbr_shading.glsl
#include lumi:shaders/lib/puddle.glsl
#include lumi:shaders/lib/noise_glint.glsl
#include lumi:shaders/lib/tile_noise.glsl
#include lumi:shaders/context/post/bloom.glsl
#include lumi:shaders/context/post/fog.glsl
#include lumi:shaders/context/global/lighting.glsl
#include lumi:shaders/context/global/shadow.glsl
#include lumi:shaders/context/global/experimental.glsl

/*******************************************************
 *  lumi:shaders/context/post/shading.frag             *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

/*******************************************************
    vertexShader: lumi:shaders/post/hdr.vert
 *******************************************************/

varying mat4 v_star_rotator;
varying mat4 v_cloud_rotator;
varying float v_fov;
varying float v_night;
varying float v_not_in_void;
varying float v_near_void_core;
varying float v_blindness;
varying vec3 v_sky_radiance;

const vec3 VOID_CORE_COLOR = hdr_gammaAdjust(vec3(1.0, 0.7, 0.5));

// const float JITTER_STRENGTH = 0.4;
float tileJitter;

vec3 coords_view(vec2 uv, mat4 inv_projection, float depth)
{
    vec3 clip = vec3(2.0 * uv - 1.0, 2.0 * depth - 1.0);
    vec4 view = inv_projection * vec4(clip, 1.0);
    return view.xyz / view.w;
}

vec2 coords_uv(vec3 view, mat4 projection)
{
    vec4 clip = projection * vec4(view, 1.0);
    clip.xyz /= clip.w;
    return clip.xy * 0.5 + 0.5;
}

float raymarched_fog_density(vec3 viewPos, vec3 worldPos, /*float fogNear,*/ float fogFar)
{
    // vec3 unitMarch_view = normalize(-viewPos);
    // vec3 ray_view = viewPos + tileJitter * unitMarch_view;

    vec3 modelPos = worldPos - frx_cameraPos();
    float distToCamera = length(modelPos);
    vec3 unitMarch_model = (-modelPos) / distToCamera;
    vec3 ray_model = modelPos + tileJitter * unitMarch_model;

    float distTraveled = tileJitter;
    float maxDist = min(distToCamera, 128.0); // why 128 again ?

    // March in shadow space for performance boost
    // vec3 shadowPos = (frx_shadowViewMatrix() * vec4(modelPos, 1.0)).xyz;
    //nb: camera pos in shadow view space is zero, but is non-zero in shadow view-projection space
    // vec3 cameraPos_shadow = (frx_shadowViewMatrix() * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    // vec3 unitMarch_shadow = (/*cameraPos_shadow*/ - shadowPos) / distToCamera;
    // shadowPos = shadowPos * 0.5 + 0.5; // Transform from screen coordinates to texture coordinates
    vec4 ray_shadow;// = vec4(shadowPos + tileJitter * unitMarch_shadow, 1.0);

    float illuminated = 0.0;
    while (distTraveled < maxDist) {
        #if defined(SHADOW_MAP_PRESENT) && defined(DEFERRED_SHADOW)
            ray_shadow = (frx_shadowViewMatrix() * vec4(ray_model, 1.0));
            illuminated += simpleShadowFactor(u_shadow, ray_shadow);
        #else
            illuminated += 1.0;
        #endif
        distTraveled += 1.0;
        // ray_shadow.xyz += unitMarch_shadow;
        ray_model += unitMarch_model;
        // ray_view += unitMarch_view;
    }

    return illuminated / max(1.0, fogFar/* - fogNear*/);
}

vec4 fog (float skylightFactor, vec4 a, vec3 viewPos, vec3 worldPos, inout float bloom)
{

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
    heightFactor = frx_viewFlag(FRX_CAMERA_IN_FLUID) ? 1.0 : (heightFactor * heightFactor);

    #if defined(VOLUMETRIC_FOG)
    float fogFactor = fogDensity * heightFactor;
    #else
    float fogFactor = fogDensity * heightFactor * (frx_viewFlag(FRX_CAMERA_IN_FLUID) ? 1.0 : skylightFactor);
    #endif

    if (frx_playerHasEffect(FRX_EFFECT_BLINDNESS)) {
        fogFar = mix(fogFar, 3.0, v_blindness);
        fogNear = mix(fogNear, 0.0, v_blindness);
        fogFactor = mix(fogFactor, 1.0, v_blindness);
    }

    if (frx_viewFlag(FRX_CAMERA_IN_LAVA)) {
        fogFar = frx_playerHasEffect(FRX_EFFECT_FIRE_RESISTANCE) ? 2.5 : 0.5;
        fogNear = 0.0;
        fogFactor = 1.0;
    }

    // TODO: retrieve fog distance from render distance ?
    float distFactor;
    #if defined(VOLUMETRIC_FOG)
        bool useVolumetric = !frx_playerHasEffect(FRX_EFFECT_BLINDNESS)
            && !frx_viewFlag(FRX_CAMERA_IN_LAVA);
        if (useVolumetric) { //TODO: blindness transition still broken
            distFactor = raymarched_fog_density(viewPos, worldPos, /*fogNear,*/ fogFar);
        } else {
    #endif

    distFactor = l2_clampScale(fogNear, fogFar, length(viewPos));
    distFactor *= distFactor;

    #if defined(VOLUMETRIC_FOG)
        }
    #endif

    fogFactor = clamp(fogFactor * distFactor, 0.0, 1.0);
    
    vec4 fogColor = vec4(hdr_orangeSkyColor(v_skycolor, normalize(-viewPos)), 1.0);
    bloom = mix(bloom, 0.0, fogFactor);
    return mix(a, fogColor, fogFactor);
}

float caustics(vec3 worldPos)
{
    if (!frx_worldFlag(FRX_WORLD_IS_OVERWORLD)) return 0.0;
    // turns out, to get accurate coords, a global y-coordinate of water surface is required :S
    // 64 is used for the time being..
    // TODO: might need to prevent division by 0 ?
    return 1.0 - abs(cellular2x2x2(vec3(worldPos.xz + (64.0-worldPos.y) * frx_skyLightVector().xz / frx_skyLightVector().y, frx_renderSeconds())).x);
}

float volumetric_caustics_beam(vec3 worldPos)
{
    // const float stepSize = 0.125;
    // const float maxDist = 16.0;
    const float stepSize = 0.25;
    const float maxDist = 8.0;
    const float stepLimit = maxDist / stepSize;
    const int iStepLimit = int(stepLimit);

    vec3 unitMarch = normalize(frx_cameraPos()-worldPos);
    vec3 stepMarch = unitMarch * stepSize;
    vec3 ray_world = worldPos;

    float distToCamera = distance(worldPos, frx_cameraPos());
    int maxSteps = min(iStepLimit, int(distToCamera / stepSize));

    if (distToCamera >= maxDist) {
        ray_world += unitMarch * (distToCamera - maxDist);
    }

    int stepCount = 0;
    float power = 0.0;
    while (stepCount < maxSteps) {
        power += smoothstep(0.3, 0.1, caustics(ray_world));
        // power += 1.0-1.5*caustics(ray_world);
        stepCount ++;
        ray_world += stepMarch;
    }

    return max(0.0, float(power) / stepLimit);
}

void custom_sky(in vec3 viewPos, in float blindnessFactor, inout vec4 a, inout float bloom_out)
{
    vec3 skyVec = normalize(viewPos);
    vec3 worldSkyVec = skyVec * frx_normalModelMatrix();
    float skyDotUp = dot(skyVec, v_up);
    bloom_out = 0.0;

    if (frx_worldFlag(FRX_WORLD_IS_OVERWORLD) && v_not_in_void > 0.0) {
        float celestialObject = l2_clampScale(0.999, 0.9992, dot(worldSkyVec, frx_skyLightVector())) * frx_skyLightTransitionFactor();
        #ifdef CUSTOM_SKY
            a.rgb = hdr_orangeSkyColor(v_skycolor, -skyVec) * 2.0;
            if (frx_worldFlag(FRX_WORLD_IS_MOONLIT)) {
                a.rgb = mix(a.rgb, vec3(0.25 + frx_moonSize()), celestialObject);
            } else {
                a.rgb += vec3(10.0) * celestialObject;
            }
            a.rgb *= 1 + pow(l2_clampScale(0.5, -0.1, skyDotUp), 2.0);
        #else
            a.rgb = hdr_gammaAdjust(a.rgb) * 2.0;
        #endif

        float rainFactor = frx_rainGradient() * 0.67 + frx_thunderGradient() * 0.33;

        // stars
        float starry = l2_clampScale(0.4, 0.0, frx_luminance(a.rgb)) * v_night;
        starry *= l2_clampScale(-0.6, -0.5, skyDotUp); //prevent star near the void core
        float occlusion = (1.0 - rainFactor);
        vec4 starVec = v_star_rotator * vec4(worldSkyVec, 0.0);
        vec3 nonMilkyAxis = vec3(-0.598964, 0.531492, 0.598964);
        float milkyness = l2_clampScale(0.5, 0.0, abs(dot(nonMilkyAxis, worldSkyVec.xyz)));
        float star = starry * smoothstep(0.75 - milkyness * 0.3, 0.9, snoise(starVec.xyz * 100));
        // zoom sharpening
        float zoomFactor = l2_clampScale(90, 30, v_fov);
        star = l2_clampScale(0.3 * zoomFactor, 1.0 - 0.6 * zoomFactor, star) * occlusion;
        star = max(0.0, star - celestialObject);
        float milkyHaze = starry * occlusion * (1.0-frx_ambientIntensity()) * milkyness * 0.4 * l2_clampScale(-1.0, 1.0, snoise(starVec.xyz * 2.0));
        vec3 starRadiance = vec3(star) + vec3(0.9, 0.75, 1.0) * milkyHaze;
        a.rgb += starRadiance;
        bloom_out += (star + milkyHaze);
    }

    //prevent sky in the void for extra immersion
    if (frx_worldFlag(FRX_WORLD_IS_OVERWORLD)) {
        // VOID CORE
        float voidCore = l2_clampScale(-0.8 + v_near_void_core, -1.0 + v_near_void_core, skyDotUp); 
        vec3 voidColor = mix(vec3(0.0), VOID_CORE_COLOR, voidCore);
        bloom_out = voidCore;
        a.rgb = mix(voidColor, a.rgb, v_not_in_void);
    }

    bloom_out += l2_skyBloom();
    bloom_out *= blindnessFactor;

    // vec3 skyDownColor = vec3(frx_ambientIntensity());
    // starRadiance + mix(skyDownColor, v_skycolor, l2_clampScale(-1.0, 1.0, dot(skyVec, v_up)))
}

const float RADIUS = 0.4;
const float BIAS = 0.4;
const float INTENSITY = 10.0;

vec4 hdr_shaded_color(
    vec2 uv,
    sampler2D scolor, sampler2D sdepth, sampler2D slight, sampler2D snormal, sampler2D smaterial, sampler2D smisc,
    float aoval, bool translucent, float translucentDepth, out float bloom_out)
{
    vec4  a       = texture2D(scolor, uv);
    float depth   = texture2D(sdepth, uv).r;
    vec3  viewPos = coords_view(uv, frx_inverseProjectionMatrix(), depth);

    if (depth == 1.0 && !translucent) {
        // the sky
        if (v_blindness == 1.0) return vec4(0.0);
        custom_sky(viewPos, 1.0 - v_blindness, a, bloom_out);
        return vec4(a.rgb * 1.0 - v_blindness, 0.0);
        // vec3 worldPos = (128.0 / length(modelPos)) * modelPos + frx_cameraPos(); // doesn't help
        // return a + fog(frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) ? frx_ambientIntensity() : 1.0, vec4(0.0), viewPos, worldPos, bloom_out);
    }

    vec4  light     = texture2D(slight, uv);
    if (light.x == 0.0) {
        // bypass unmanaged translucent draw (LITEMATICA WORKAROUND)
        // bypass unmanaged solid sky draw (fix debug rendering color)
        // rationale: light.x is always at least 0.03125 for managed draws
        //            this might not always hold up in the future.
        #if OVERLAY_DEBUG == OVERLAY_DEBUG_NEON || OVERLAY_DEBUG == OVERLAY_DEBUG_DISCO
            bloom_out = step(0.01, a.a);
            a.r += a.g * 0.25;
            a.b += a.g * 0.5;
            a.g *= 0.25;
        #endif
        #if OVERLAY_DEBUG == OVERLAY_DEBUG_DISCO
            a.rgb *= 0.25 + 0.75 * fract(frx_renderSeconds()*2.0);
        #endif
        return a;
    }
    vec3  normal    = texture2D(snormal, uv).xyz * 2.0 - 1.0;
    vec3  material  = texture2D(smaterial, uv).xyz;
    float roughness = material.x == 0.0 ? 1.0 : min(1.0, 1.0203 * material.x - 0.01);
    float metallic  = material.y;
    vec3  worldPos  = frx_cameraPos() + (frx_inverseViewMatrix() * vec4(viewPos, 1.0)).xyz;
    float f0        = material.z;
    float bloom_raw = light.z * 2.0 - 1.0;
    bool  diffuse   = material.x < 1.0;
    bool  matflash  = f0 > 0.95;
    bool  mathurt   = f0 > 0.85 && !matflash;
    // return vec4(coords_view(uv, frx_inverseProjectionMatrix(), depth), 1.0);

    #if defined(SHADOW_MAP_PRESENT) && defined(DEFERRED_SHADOW)
        vec4 shadowViewPos = frx_shadowViewMatrix() * vec4(worldPos - frx_cameraPos(), 1.0);
        float shadowFactor = calcShadowFactor(u_shadow, shadowViewPos);  
        light.z = shadowFactor;
    #else
        light.z = light.y;
    #endif

    #if CAUSTICS_MODE == CAUSTICS_MODE_TEXTURE
        if (!translucent) {
            if ((translucentDepth >= depth && frx_viewFlag(FRX_CAMERA_IN_WATER))
                || (translucentDepth < depth && !frx_viewFlag(FRX_CAMERA_IN_WATER))) {
                #if defined(SHADOW_MAP_PRESENT)
                    light.z = mix(light.z, 0.0, min(1.0, 0.25 * caustics(worldPos)));
                #else
                    light.z = mix(1.0, light.z, (1.0-light.z) * min(1.0, 1.5 * caustics(worldPos)));
                #endif
            }
        }
    #endif

    bloom_out = max(0.0, bloom_raw);
    #ifdef RAIN_PUDDLES
        ww_puddle_pbr(a, roughness, light.y, normal, worldPos);
    #endif
    pbr_shading(a, bloom_out, viewPos, light.xyz, normal, roughness, metallic, f0 > 0.7 ? 0.0 : material.z, diffuse, translucent);


#if AMBIENT_OCCLUSION != AMBIENT_OCCLUSION_NONE
    float ao_shaded = 1.0 + min(0.0, bloom_raw);
    float ssao = mix(aoval, 1.0, min(bloom_out, 1.0));
    a.rgb *= ao_shaded * ssao;
#endif
    if (matflash) a.rgb += 1.0;
    if (mathurt) a.r += 0.5;

    a.a = min(1.0, a.a);

    vec3 misc = texture2D(smisc, uv).xyz;
    a.rgb += hdr_gammaAdjust(noise_glint(misc.xy, misc.z));

    if (a.a != 0.0 && (translucent || translucentDepth >= depth) && depth != 1.0) {
        a = fog(frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) ? light.y * frx_ambientIntensity() : 1.0, a, viewPos, worldPos, bloom_out);
    }

    #if CAUSTICS_MODE == CAUSTICS_MODE_TEXTURE
        if (frx_viewFlag(FRX_CAMERA_IN_WATER) && translucentDepth >= depth) {
            a.rgb += light.y * light.y * 0.1 * v_sky_radiance * volumetric_caustics_beam(worldPos);
        }
    #endif

    return a;
}
