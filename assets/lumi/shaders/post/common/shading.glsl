#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/noise/cellular2x2x2.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include frex:shaders/api/material.glsl
#include frex:shaders/api/player.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/shadow.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/func/glintify2.glsl
#include lumi:shaders/func/tonemap.glsl
#include lumi:shaders/func/pbr_shading.glsl
#include lumi:shaders/lib/bitpack.glsl
#include lumi:shaders/lib/block_dir.glsl
#include lumi:shaders/lib/puddle.glsl
#include lumi:shaders/lib/rectangle.glsl
#include lumi:shaders/lib/taa_jitter.glsl
#include lumi:shaders/func/tile_noise.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/post/common/bloom.glsl
#include lumi:shaders/post/common/fog.glsl

/*******************************************************
 *  lumi:shaders/post/common/shading.frag              *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_glint;
uniform sampler2D u_sun;
uniform sampler2D u_moon;
uniform sampler2DArrayShadow u_shadow;
uniform sampler2D u_blue_noise;

/*******************************************************
    vertexShader: lumi:shaders/post/hdr.vert
 *******************************************************/

in vec3 v_celest1;
in vec3 v_celest2;
in vec3 v_celest3;
in vec2 v_invSize;
in mat4 v_star_rotator;
in float v_fov;
in float v_night;
in float v_not_in_void;
in float v_near_void_core;
in float v_blindness;

const vec3 VOID_CORE_COLOR = hdr_fromGamma(vec3(1.0, 0.7, 0.5));

// const float JITTER_STRENGTH = 0.4;
float tileJitter;

vec3 coords_view(vec2 uv, mat4 inv_projection, float depth)
{
    vec4 view = inv_projection * vec4(2.0 * uv - 1.0, 2.0 * depth - 1.0, 1.0);
    return view.xyz / view.w;
}

vec2 coords_uv(vec3 view, mat4 projection)
{
    vec4 clip = projection * vec4(view, 1.0);
    clip.xyz /= clip.w;
    return clip.xy * 0.5 + 0.5;
}

#ifdef USE_VOLUMETRIC_FOG
float raymarched_fog_density(vec3 modelPos, float pFogFar)
{
    float distToCamera = length(modelPos);
    float sampleSize = max(2.0, pFogFar / 8.0);
    vec3 unitMarch_model = sampleSize * ((-modelPos) / distToCamera);
    vec3 ray_model = modelPos + tileJitter * unitMarch_model;

    float distTraveled = tileJitter * sampleSize;
    float maxDist = min(distToCamera, pFogFar);

    // March in shadow space for performance boost
    // vec3 shadowPos = (frx_shadowViewMatrix() * vec4(modelPos, 1.0)).xyz;
    //nb: camera pos in shadow view space is zero, but is non-zero in shadow view-projection space
    // vec3 cameraPos_shadow = (frx_shadowViewMatrix() * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    // vec3 unitMarch_shadow = (/*cameraPos_shadow*/ - shadowPos) / distToCamera;
    // shadowPos = shadowPos * 0.5 + 0.5; // Transform from screen coordinates to texture coordinates
    vec4 ray_shadow;// = vec4(shadowPos + tileJitter * unitMarch_shadow, 1.0);

    float illuminated = 0.0;
    while (distTraveled < maxDist) {
        ray_shadow = (frx_shadowViewMatrix() * vec4(ray_model, 1.0));
        illuminated += simpleShadowFactor(u_shadow, ray_shadow) * sampleSize;
        distTraveled += sampleSize;
        // ray_shadow.xyz += unitMarch_shadow;
        ray_model += unitMarch_model;
        // ray_view += unitMarch_view;
    }

    return illuminated / max(1.0, pFogFar);
}
#endif

vec4 fog(float skyLight, vec4 a, vec3 modelPos, vec3 worldPos, inout float bloom)
{
    float pfSkyLight = 1.0;

    if (frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT)) {
        pfSkyLight = mix(skyLight, 1.0, l2_clampScale(0., SEA_LEVEL, frx_cameraPos().y));
        pfSkyLight *= pfSkyLight;
    }

    float pFogDensity = frx_viewFlag(FRX_CAMERA_IN_FLUID) ? UNDERWATER_FOG_DENSITY : FOG_DENSITY;
    float pFogFar     = frx_viewFlag(FRX_CAMERA_IN_FLUID) ? UNDERWATER_FOG_FAR     : FOG_FAR;

    pFogFar = min(frx_viewDistance(), pFogFar); // clamp to render distance


    // float fog_noise = snoise(worldPos.xz * FOG_NOISE_SCALE + frx_renderSeconds() * FOG_NOISE_SPEED) * FOG_NOISE_HEIGHT;

    float pfAltitude = 1.0;

    if (!frx_viewFlag(FRX_CAMERA_IN_FLUID) && frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT)) {
        float zigZagTime = abs(frx_worldTime()-0.5);
        float timeFactor = (l2_clampScale(0.45, 0.5, zigZagTime) + l2_clampScale(0.05, 0.0, zigZagTime));
        float inverseThickener = 1.0;

        inverseThickener -= 0.25 * timeFactor;
        inverseThickener -= 0.5 * inverseThickener * frx_rainGradient();
        inverseThickener -= 0.5 * inverseThickener * frx_thunderGradient();

        pFogFar *= inverseThickener;
        pFogDensity = mix(min(1.0, pFogDensity * 2.0), min(0.8, pFogDensity), inverseThickener);

        #ifdef OVERWORLD_FOG_ALTITUDE_AFFECTED
            // altitude fog in the overworld :) valley fog is better than mountain-engulfing fog
            if (frx_worldFlag(FRX_WORLD_IS_OVERWORLD)) {
                float fogTop = mix(FOG_TOP_THICK, FOG_TOP, inverseThickener);
                pfAltitude = l2_clampScale(fogTop, SEA_LEVEL, worldPos.y);
                pfAltitude *= pfAltitude;
            }
        #endif
    }

    bool useVolFog = false;

    #ifdef USE_VOLUMETRIC_FOG
    useVolFog = !frx_playerHasEffect(FRX_EFFECT_BLINDNESS)
                && !frx_viewFlag(FRX_CAMERA_IN_LAVA)
                && frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT);
    #endif


    float fogFactor = pFogDensity * pfAltitude * ((frx_viewFlag(FRX_CAMERA_IN_FLUID) || useVolFog) ? 1.0 : pfSkyLight);

    // additive fog when it's not blindness or lava related
    bool useAdditive = true;

    if (frx_playerHasEffect(FRX_EFFECT_BLINDNESS)) {
        useAdditive = false;
        useVolFog = false;
        pFogFar = mix(pFogFar, 3.0, v_blindness);
        fogFactor = mix(fogFactor, 1.0, v_blindness);
    }

    if (frx_viewFlag(FRX_CAMERA_IN_LAVA)) {
        useAdditive = false;
        useVolFog = false;
        pFogFar = frx_playerHasEffect(FRX_EFFECT_FIRE_RESISTANCE) ? 2.5 : 0.5;
        fogFactor = 1.0;
    }

    float distToCamera = length(modelPos);
    float pfCave = 1.0;

    // TODO: retrieve fog distance from render distance as an option especially for the nether
    float distFactor;

    distFactor = min(1.0, distToCamera / pFogFar);


    #ifdef USE_VOLUMETRIC_FOG
    if (useVolFog) { //TODO: blindness transition still broken?
        float fRaymarch = raymarched_fog_density(modelPos, pFogFar);
        distFactor = distFactor * VOLUMETRIC_FOG_SOFTNESS + (1. - VOLUMETRIC_FOG_SOFTNESS) * fRaymarch;
        pfCave -= fRaymarch;
    }
    #endif

    distFactor *= distFactor;

    fogFactor = clamp(fogFactor * distFactor, 0.0, 1.0);

    vec4 fogColor = vec4(atmos_hdrFogColorRadiance(normalize(modelPos)), 1.0);

    if (useAdditive) {
        #ifdef RGB_CAVES
            float darkness = (1.0 - skyLight);
        #else
            float darkness = l2_clampScale(0.1, 0.0, skyLight);
        #endif
        pfCave *= min(1.0, distToCamera / FOG_FAR) * darkness;
        pfCave *= pfCave;
        vec3 caveFog = atmos_hdrCaveFogRadiance() * pfCave;
        return vec4(a.rgb + fogColor.rgb * fogFactor + caveFog, a.a + max(0.0, 1.0 - a.a) * fogFactor);
    }

    // no need to reduce bloom with additive blending
    bloom = mix(bloom, 0.0, fogFactor);

    return mix(a, fogColor, fogFactor);
}

float caustics(vec3 worldPos)
{
    // turns out, to get accurate coords, a global y-coordinate of water surface is required :S
    // Sea level is used for the time being..
    // TODO: might need to prevent division by 0 ?
    float animator = frx_renderSeconds() * 0.5;
    vec2 animatonator = frx_renderSeconds() * vec2(0.5, -1.0);
    vec3 pos = vec3(worldPos.xz + animatonator, animator);

    pos.xy += (SEA_LEVEL - worldPos.y) * frx_skyLightVector().xz / frx_skyLightVector().y;

    float e = cellular2x2x2(pos).x;

    e = smoothstep(-1.0, 1.0, e);

    return e;
}

vec4 underwaterLightRays(vec4 a, vec3 modelPos, float translucentDepth, float depth)
{
    bool doUnderwaterRays = frx_viewFlag(FRX_CAMERA_IN_WATER) && translucentDepth >= depth && frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT);
    vec3 unit = normalize(modelPos);
    float scatter = dot(unit, frx_skyLightVector());

    scatter = 0.5 - abs(scatter - 0.5);
    scatter *= 2.0;

    if (!doUnderwaterRays || scatter <= 0.0) {
        return a;
    }

    const float sample = 2.0;
    const int maxSteps = 10;
    const float range = 10.0;
    const float beamL = 3.;
    const float basePower = 0.25;
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
        e *= simpleShadowFactor(u_shadow, ray_shadow);
    #endif

        power += e;
        ray += march;
        traveled += sample;
        steps ++;
    }

    power = power * sample / float(maxSteps) * scatter * basePower;
    a.rgb += atmos_hdrCelestialRadiance() * power;
    a.a += max(0.0, 1.0 - a.a) * power;

    return a;
}

void custom_sky(in vec3 modelPos, in float blindnessFactor, in bool maybeUnderwater, inout vec4 a, inout float bloom_out)
{
    vec3 worldSkyVec = normalize(modelPos);
    float skyDotUp = dot(worldSkyVec, vec3(0.0, 1.0, 0.0));

    bloom_out = 0.0;

    if ((frx_viewFlag(FRX_CAMERA_IN_WATER) && maybeUnderwater) || frx_worldFlag(FRX_WORLD_IS_NETHER)) {
        a.rgb = atmosv_hdrFogColorRadiance;
    } else if (frx_worldFlag(FRX_WORLD_IS_OVERWORLD) && v_not_in_void > 0.0) {
        #if SKY_MODE == SKY_MODE_LUMI
            float starEraser = 0.;
            vec2 celestUV = rect_innerUV(Rect(v_celest1, v_celest2, v_celest3), worldSkyVec * 1024.);
            vec3 celestialObjectColor = vec3(0.);
            bool isMoon = dot(worldSkyVec, frx_skyLightVector()) < 0. ? !frx_worldFlag(FRX_WORLD_IS_MOONLIT) : frx_worldFlag(FRX_WORLD_IS_MOONLIT);
            if (celestUV == clamp(celestUV, 0.0, 1.0)) {
                if (isMoon){
                    vec2 moonUv = clamp(celestUV, 0.25, 0.75);
                    if (celestUV == moonUv) {
                        celestUV = 2.0 * moonUv - 0.5;
                        vec2 fullMoonUV = celestUV * vec2(0.25, 0.5);
                        vec3 fullMoonColor = texture(u_moon, fullMoonUV).rgb;
                        starEraser = l2_max3(fullMoonColor);
                        starEraser = min(1.0, starEraser * 3.0);
                        celestUV.x *= 0.25;
                        celestUV.y *= 0.5;
                        celestUV.x += mod(frx_worldDay(), 4.) * 0.25;
                        celestUV.y += (mod(frx_worldDay(), 8.) >= 4.) ? 0.5 : 0.0;
                        celestialObjectColor = hdr_fromGamma(texture(u_moon, celestUV).rgb) * 3.0;
                        celestialObjectColor += vec3(0.01) * hdr_fromGamma(fullMoonColor);
                    }
                } else {
                    celestialObjectColor = hdr_fromGamma(texture(u_sun, celestUV).rgb) * 2.0;
                }
                bloom_out += frx_luminance(clamp(celestialObjectColor, 0.0, 1.0)) * 0.25;
            }
            a.rgb = atmos_hdrSkyGradientRadiance(worldSkyVec);
            a.rgb += celestialObjectColor * (1. - frx_rainGradient());
        #else
            // a.rgb = hdr_fromGamma(a.rgb) * 2.0; // Don't gamma-correct vanilla sky
        #endif

        #if SKY_MODE == SKY_MODE_LUMI || SKY_MODE == SKY_MODE_VANILLA_STARRY
            // stars
            const vec3 nonMilkyAxis = vec3(-0.598964, 0.531492, 0.598964);

            float starry = l2_clampScale(0.4, 0.0, frx_luminance(a.rgb)) * v_night;

            starry *= l2_clampScale(-0.6, -0.5, skyDotUp); //prevent star near the void core

            float milkyness = l2_clampScale(0.5, 0.0, abs(dot(nonMilkyAxis, worldSkyVec.xyz)));
            float rainOcclusion = (1.0 - frx_rainGradient());
            vec4  starVec = v_star_rotator * vec4(worldSkyVec, 0.0);
            float zoomFactor = l2_clampScale(90, 30, v_fov); // zoom sharpening
            float star = starry * smoothstep(0.12 + milkyness * 0.15, 0.0, cellular2x2x2(starVec.xyz * 100).x);

            star = l2_clampScale(0.3 * zoomFactor, 1.0 - 0.6 * zoomFactor, star) * rainOcclusion;

            float milkyHaze = starry * rainOcclusion * milkyness * 0.4 * l2_clampScale(-1.0, 1.0, snoise(starVec.xyz * 2.0));

            #if SKY_MODE == SKY_MODE_LUMI
                star -= star * starEraser;
                milkyHaze -= milkyHaze * starEraser;
                milkyHaze *= milkyHaze;
            #endif

            vec3 starRadiance = vec3(star) + NEBULAE_COLOR * milkyHaze;

            a.rgb += starRadiance;
            bloom_out += (star + milkyHaze);
        #endif
    }

    //prevent sky in the void for extra immersion
    if (frx_worldFlag(FRX_WORLD_IS_OVERWORLD)) {
        // VOID CORE
        float voidCore = l2_clampScale(-0.8 + v_near_void_core, -1.0 + v_near_void_core, skyDotUp); 
        vec3 voidColor = mix(vec3(0.0), VOID_CORE_COLOR, voidCore);
        bloom_out += voidCore * (1. - v_not_in_void);
        a.rgb = mix(voidColor, a.rgb, v_not_in_void);
    }

    bloom_out += l2_skyBloom();
    bloom_out *= blindnessFactor;
}

vec4 unmanaged(in vec4 a, out float bloom_out, bool translucent) {
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
    // marker for unmanaged draw
    a.a = translucent ? a.a : 0.0;
    return a;
}

const float RADIUS = 0.4;
const float BIAS = 0.4;
const float INTENSITY = 10.0;

vec4 hdr_shaded_color(
    vec2 uv, sampler2D sdepth, sampler2D slight, sampler2D snormal, sampler2D smaterial, sampler2D smisc,
    vec4 albedo_alpha, vec3 emissionRadiance, float aoval, bool translucent, bool translucentIsWater, float translucentDepth, out float bloom_out)
{
    vec4  a = albedo_alpha;

    if (translucent && a.a == 0.) return vec4(0.);

    float depth   = texture(sdepth, uv).r;
    vec3  viewPos = coords_view(uv, frx_inverseProjectionMatrix(), depth);
    vec3  modelPos = coords_view(uv, frx_inverseViewProjectionMatrix(), depth);
    vec3  worldPos  = frx_cameraPos() + modelPos;
    bool maybeUnderwater = false;
    bool mostlikelyUnderwater = false;
    
    if (frx_viewFlag(FRX_CAMERA_IN_WATER)) {
        if (translucent) {
            maybeUnderwater = true;
        } else {
            maybeUnderwater = translucentDepth >= depth;
        }
        mostlikelyUnderwater = maybeUnderwater;
    } else {
        maybeUnderwater = translucentDepth < depth;
        mostlikelyUnderwater = maybeUnderwater && translucentIsWater;
    }

    if (depth == 1.0 && !translucent) {
        // the sky
        if (v_blindness == 1.0) return vec4(0.0);
        custom_sky(modelPos, 1.0 - v_blindness, maybeUnderwater, a, bloom_out);
    #ifdef WATER_CAUSTICS
        a = underwaterLightRays(a, modelPos, translucentDepth, depth);
    #endif
        // mark as managed draw, vanilla sky is an exception
        return vec4(a.rgb * 1.0 - v_blindness, 1.0);
    }

    vec4  light = texture(slight, uv);

    if (light.x == 0.0) {
        return unmanaged(a, bloom_out, translucent);
    }

    vec3  normal    = texture(snormal, uv).xyz * 2.0 - 1.0;
    vec3  material  = texture(smaterial, uv).xyz;
    float roughness = material.x == 0.0 ? 1.0 : min(1.0, 1.0203 * material.x - 0.01);
    float metallic  = material.y;
    float f0        = material.z;
    float bloom_raw = light.z * 2.0 - 1.0;
    bool  diffuse   = material.x < 1.0;
    vec3  misc      = texture(smisc, uv).xyz;
    float matflash  = bit_unpack(misc.z, 0);
    float mathurt   = bit_unpack(misc.z, 1);
    // return vec4(coords_view(uv, frx_inverseProjectionMatrix(), depth), 1.0);

    light.y = lightmapRemap(light.y);

    #ifdef SHADOW_MAP_PRESENT
        #ifdef TAA_ENABLED
            vec2 uvJitter = taa_jitter(v_invSize);
            vec4 unjitteredModelPos = frx_inverseViewProjectionMatrix() * vec4(2.0 * uv - uvJitter - 1.0, 2.0 * depth - 1.0, 1.0);
            vec4 shadowViewPos = frx_shadowViewMatrix() * vec4(unjitteredModelPos.xyz/unjitteredModelPos.w, 1.0);
        #else
            vec4 shadowViewPos = frx_shadowViewMatrix() * vec4(worldPos - frx_cameraPos(), 1.0);
        #endif

        float shadowFactor = calcShadowFactor(u_shadow, shadowViewPos);
        // workaround for janky shadow on edges of things (hardly perfect, better than nothing)
        shadowFactor = mix(shadowFactor, simpleShadowFactor(u_shadow, shadowViewPos), step(0.99, shadowFactor));

        light.z = shadowFactor;
        // Workaround before shadow occlusion culling to make caves playable
        light.z *= l2_clampScale(0.03125, 0.04, light.y);
    #else
        light.z = hdr_fromGammaf(light.y);
    #endif

    float causticLight = 0.0;

    #ifdef WATER_CAUSTICS
        if (mostlikelyUnderwater && frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT)) {
            causticLight = caustics(worldPos);
            causticLight = pow(causticLight, 15.0);
            causticLight *= smoothstep(0.0, 1.0, light.y);
        }
    #endif

    #ifdef SHADOW_MAP_PRESENT
        causticLight *= light.z;

        if (maybeUnderwater || frx_viewFlag(FRX_CAMERA_IN_WATER)) {
            light.z *= hdr_fromGammaf(light.y);
        }
    #endif

    light.z += causticLight;

    bloom_out = max(0.0, bloom_raw);
    #ifdef RAIN_PUDDLES
        ww_puddle_pbr(a, roughness, light.y, normal, worldPos);
    #endif
    #if BLOCKLIGHT_SPECULAR_MODE == BLOCKLIGHT_SPECULAR_MODE_FANTASTIC
        preCalc_blockDir = calcBlockDir(slight, uv, v_invSize, normal, viewPos, sdepth);
    #endif
    pbr_shading(a, bloom_out, modelPos, light.xyz, normal, roughness, metallic, f0, diffuse, translucent);


#if AMBIENT_OCCLUSION != AMBIENT_OCCLUSION_NO_AO
    #if AMBIENT_OCCLUSION != AMBIENT_OCCLUSION_PURE_SSAO
        float ao_shaded = 1.0 + min(0.0, bloom_raw);
    #else
        float ao_shaded = 1.0;
    #endif
#ifdef SSAO_ENABLED
    float ssao = mix(aoval, 1.0, min(bloom_out, 1.0));
#else
    float ssao = 1.;
#endif
    a.rgb += emissionRadiance;
    a.rgb *= ao_shaded * ssao;
#endif
    if (matflash == 1.0) a.rgb += 1.0;
    if (mathurt == 1.0) a.r += 0.5;

    a.a = min(1.0, a.a);

    #if GLINT_MODE == GLINT_MODE_GLINT_SHADER
        a.rgb += hdr_fromGamma(noise_glint(misc.xy, bit_unpack(misc.z, 2)));
    #else
        a.rgb += hdr_fromGamma(texture_glint(u_glint, misc.xy, bit_unpack(misc.z, 2)));
    #endif

    if (a.a != 0.0 && depth != 1.0) {
        a = fog(light.y, a, modelPos, worldPos, bloom_out);
    }

#ifdef WATER_CAUSTICS
    a = underwaterLightRays(a, modelPos, translucentDepth, depth);
#endif

    return a;
}
