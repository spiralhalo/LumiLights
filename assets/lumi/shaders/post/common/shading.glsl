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
#include lumi:shaders/func/pbr_shading.glsl
#include lumi:shaders/func/tile_noise.glsl
#include lumi:shaders/func/tonemap.glsl
#include lumi:shaders/func/volumetrics.glsl
#include lumi:shaders/lib/bitpack.glsl
#include lumi:shaders/lib/block_dir.glsl
#include lumi:shaders/lib/caustics.glsl
#include lumi:shaders/lib/celest_adapter.glsl
#include lumi:shaders/lib/puddle.glsl
#include lumi:shaders/lib/rectangle.glsl
#include lumi:shaders/lib/taa_jitter.glsl
#include lumi:shaders/lib/util.glsl
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

vec4 fog(float skyLight, vec4 a, vec3 modelPos, vec3 worldPos, inout float bloom)
{
    float pFogDensity = frx_viewFlag(FRX_CAMERA_IN_FLUID) ? UNDERWATER_FOG_DENSITY : FOG_DENSITY;
    float pFogFar     = frx_viewFlag(FRX_CAMERA_IN_FLUID) ? UNDERWATER_FOG_FAR     : FOG_FAR;

    pFogFar = min(frx_viewDistance(), pFogFar); // clamp to render distance


    // float fog_noise = snoise(worldPos.xz * FOG_NOISE_SCALE + frx_renderSeconds() * FOG_NOISE_SPEED) * FOG_NOISE_HEIGHT;

    if (!frx_viewFlag(FRX_CAMERA_IN_FLUID) && frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT)) {
        float zigZagTime = abs(frx_worldTime()-0.5);
        float timeFactor = (l2_clampScale(0.45, 0.5, zigZagTime) + l2_clampScale(0.05, 0.0, zigZagTime));
        float inverseThickener = 1.0;

        inverseThickener -= 0.25 * timeFactor;
        inverseThickener -= 0.5 * inverseThickener * frx_rainGradient();
        inverseThickener -= 0.5 * inverseThickener * frx_thunderGradient();

        pFogFar *= inverseThickener;
        pFogDensity = mix(min(1.0, pFogDensity * 2.0), min(0.8, pFogDensity), inverseThickener);
    }


    float fogFactor = pFogDensity;

    // additive fog when it's not blindness or fluid related
    bool useAdditive = !frx_viewFlag(FRX_CAMERA_IN_WATER);

    if (frx_playerHasEffect(FRX_EFFECT_BLINDNESS)) {
        useAdditive = false;
        pFogFar = mix(pFogFar, 3.0, v_blindness);
        fogFactor = mix(fogFactor, 1.0, v_blindness);
    }

    if (frx_viewFlag(FRX_CAMERA_IN_LAVA)) {
        useAdditive = false;
        pFogFar = frx_playerHasEffect(FRX_EFFECT_FIRE_RESISTANCE) ? 2.5 : 0.5;
        fogFactor = 1.0;
    }

    float distToCamera = length(modelPos);
    float pfCave = 1.0;

    float distFactor;

    distFactor = min(1.0, distToCamera / pFogFar);
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

void custom_sky(in vec3 modelPos, in float blindnessFactor, in bool maybeUnderwater, inout vec4 a, inout float bloom_out)
{
    vec3 worldSkyVec = normalize(modelPos);
    float skyDotUp = dot(worldSkyVec, vec3(0.0, 1.0, 0.0));

    bloom_out = 0.0;

    if ((frx_viewFlag(FRX_CAMERA_IN_WATER) && maybeUnderwater) || frx_worldFlag(FRX_WORLD_IS_NETHER)) {
        a.rgb = atmosv_hdrFogColorRadiance;
    } else if (frx_worldFlag(FRX_WORLD_IS_OVERWORLD) && v_not_in_void > 0.0) {
        #if SKY_MODE == SKY_MODE_LUMI
            vec4 celestColor = celestFrag(Rect(v_celest1, v_celest2, v_celest3), u_sun, u_moon, worldSkyVec);
            float starEraser = celestColor.a;

            bloom_out += celestColor.a;
            a.rgb = atmos_hdrSkyGradientRadiance(worldSkyVec);
            a.rgb += celestColor.rgb * (1. - frx_rainGradient());
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

            vec3 starRadiance = vec3(star) * STARS_STR + NEBULAE_COLOR * milkyHaze;

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
    a.rgb += emissionRadiance * EMISSIVE_LIGHT_STR;
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

    return a;
}
