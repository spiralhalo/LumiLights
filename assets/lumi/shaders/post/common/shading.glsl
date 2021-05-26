#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/noise/cellular2x2x2.glsl
#include frex:shaders/lib/noise/noise2d.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include frex:shaders/api/material.glsl
#include frex:shaders/api/player.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/lighting.glsl
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

frag_in vec3 v_celest1;
frag_in vec3 v_celest2;
frag_in vec3 v_celest3;
frag_in vec2 v_invSize;
frag_in mat4 v_star_rotator;
frag_in float v_fov;
frag_in float v_night;
frag_in float v_not_in_void;
frag_in float v_near_void_core;
frag_in float v_blindness;

const vec3 VOID_CORE_COLOR = hdr_gammaAdjust(vec3(1.0, 0.7, 0.5));

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
float raymarched_fog_density(vec3 viewPos, vec3 worldPos, float pFogFar)
{
    // vec3 unitMarch_view = normalize(-viewPos);
    // vec3 ray_view = viewPos + tileJitter * unitMarch_view;

    vec3 modelPos = worldPos - frx_cameraPos();
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

vec4 fog (float skyLight, vec4 a, vec3 viewPos, vec3 worldPos, inout float bloom)
{
    float pfSkyLight = 1.0;
    if (frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT)) {
        pfSkyLight = mix(skyLight, 1.0, l2_clampScale(0., SEA_LEVEL, frx_cameraPos().y));
        pfSkyLight *= pfSkyLight;
    }

    float pFogDensity = frx_viewFlag(FRX_CAMERA_IN_FLUID) ? UNDERWATER_FOG_DENSITY : FOG_DENSITY;
    float pFogFar     = frx_viewFlag(FRX_CAMERA_IN_FLUID) ? UNDERWATER_FOG_FAR     : FOG_FAR;
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

    // TODO: retrieve fog distance from render distance as an option especially for the nether
    float distFactor;
    float distToCamera = length(viewPos);
    float pfCave = 1.0;
    distFactor = min(1.0, distToCamera / pFogFar);
    #ifdef USE_VOLUMETRIC_FOG
    if (useVolFog) { //TODO: blindness transition still broken?
        float fRaymarch = raymarched_fog_density(viewPos, worldPos, pFogFar);
        distFactor = distFactor * VOLUMETRIC_FOG_SOFTNESS + (1. - VOLUMETRIC_FOG_SOFTNESS) * fRaymarch;
        pfCave -= fRaymarch;
    }
    #endif
    distFactor *= distFactor;

    fogFactor = clamp(fogFactor * distFactor, 0.0, 1.0);

    // TODO: separate fog from sky color
    vec4 fogColor = vec4(atmos_hdrSkyColorRadiance(normalize(worldPos-frx_cameraPos())), 1.0);

    if (useAdditive) {
        #ifdef RGB_CAVES
            float darkness = (1.0 - skyLight);
        #else
            float darkness = l2_clampScale(0.1, 0.0, skyLight);
        #endif
        pfCave *= min(1.0, distToCamera / FOG_FAR) * darkness;
        pfCave *= pfCave;
        vec3 caveFog = atmos_hdrCaveFogRadiance() * pfCave;
        return vec4(a.rgb + fogColor.rgb * fogFactor + caveFog, a.a);
    }

    // no need to reduce bloom with additive blending
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
        #if SKY_MODE == SKY_MODE_LUMI
            float starEraser = 0.;
            vec2 celestUV = rect_innerUV(Rect(v_celest1, v_celest2, v_celest3), skyVec * 1024.);
            vec3 celestialObjectColor = vec3(0.);
            bool isMoon = dot(worldSkyVec, frx_skyLightVector()) < 0. ? !frx_worldFlag(FRX_WORLD_IS_MOONLIT) : frx_worldFlag(FRX_WORLD_IS_MOONLIT);
            if (celestUV == clamp(celestUV, 0.0, 1.0)) {
                if (isMoon){
                    vec2 fullMoonUV = celestUV * vec2(0.25, 0.5);
                    vec3 fullMoonColor = texture(u_moon, fullMoonUV).rgb;
                    starEraser = l2_max3(fullMoonColor);
                    starEraser = min(1.0, starEraser * 3.0);
                    celestUV.x *= 0.25;
                    celestUV.y *= 0.5;
                    celestUV.x += mod(frx_worldDay(), 4.) * 0.25;
                    celestUV.y += (mod(frx_worldDay(), 8.) >= 4.) ? 0.5 : 0.0;
                    celestialObjectColor = hdr_gammaAdjust(texture(u_moon, celestUV).rgb) * 3.0;
                    celestialObjectColor += vec3(0.01) * hdr_gammaAdjust(fullMoonColor);
                    celestialObjectColor *= DEF_NIGHT_SKY_MULTIPLIER;
                } else {
                    celestialObjectColor = hdr_gammaAdjust(texture(u_sun, celestUV).rgb) * 2.0;
                }
            }
            // horizonBrightening can't be used on reflections yet due to clamping I think
            float horizonBrightening = 1. + 3. * pow(l2_clampScale(.5, -.1, skyDotUp), 2.) * (1. - frx_rainGradient() * .6);
            a.rgb = atmos_hdrSkyColorRadiance(worldSkyVec) * horizonBrightening;
            a.rgb += celestialObjectColor * (1. - frx_rainGradient());
        #else
            // a.rgb = hdr_gammaAdjust(a.rgb) * 2.0; // Don't gamma-correct vanilla sky
        #endif

        #if SKY_MODE == SKY_MODE_LUMI || SKY_MODE == SKY_MODE_VANILLA_STARRY
            // stars
            const vec3  nonMilkyAxis  = vec3(-0.598964, 0.531492, 0.598964);
            
            float starry;
            starry = l2_clampScale(0.4, 0.0, frx_luminance(a.rgb)) * v_night;
            starry *= l2_clampScale(-0.6, -0.5, skyDotUp); //prevent star near the void core

            float milkyness = l2_clampScale(0.5, 0.0, abs(dot(nonMilkyAxis, worldSkyVec.xyz)));

            float rainOcclusion = (1.0 - frx_rainGradient());
            vec4  starVec       = v_star_rotator * vec4(worldSkyVec, 0.0);
            float zoomFactor    = l2_clampScale(90, 30, v_fov); // zoom sharpening
            float star;
            star = starry * smoothstep(0.75 - milkyness * 0.3, 0.9, snoise(starVec.xyz * 100));
            star = l2_clampScale(0.3 * zoomFactor, 1.0 - 0.6 * zoomFactor, star) * rainOcclusion;

            float milkyHaze = starry * rainOcclusion * milkyness * 0.4 * l2_clampScale(-1.0, 1.0, snoise(starVec.xyz * 2.0));

            #if SKY_MODE == SKY_MODE_LUMI
                star -= star * starEraser;
                milkyHaze -= milkyHaze * starEraser;
                milkyHaze *= milkyHaze;
            #endif

            vec3 starRadiance = vec3(star) + NEBULAE_COLOR * milkyHaze;

            a.rgb += starRadiance * DEF_NIGHT_SKY_MULTIPLIER;;
            bloom_out += (star + milkyHaze);
        #endif
    }

    //prevent sky in the void for extra immersion
    if (frx_worldFlag(FRX_WORLD_IS_OVERWORLD)) {
        // VOID CORE
        float voidCore = l2_clampScale(-0.8 + v_near_void_core, -1.0 + v_near_void_core, skyDotUp); 
        vec3 voidColor = mix(vec3(0.0), VOID_CORE_COLOR, voidCore);
        bloom_out = voidCore * (1. - v_not_in_void);
        a.rgb = mix(voidColor, a.rgb, v_not_in_void);
    }

    bloom_out += l2_skyBloom();
    bloom_out *= blindnessFactor;
}

const float RADIUS = 0.4;
const float BIAS = 0.4;
const float INTENSITY = 10.0;

vec4 hdr_shaded_color(
    vec2 uv,
    sampler2D scolor, sampler2D sdepth, sampler2D slight, sampler2D snormal, sampler2D smaterial, sampler2D smisc,
    float aoval, bool translucent, float translucentDepth, out float bloom_out)
{
    vec4  a       = texture(scolor, uv);
    if (translucent && a.a == 0.) return vec4(0.);
    
    float depth   = texture(sdepth, uv).r;
    vec3  viewPos = coords_view(uv, frx_inverseProjectionMatrix(), depth);

    if (depth == 1.0 && !translucent) {
        // the sky
        if (v_blindness == 1.0) return vec4(0.0);
        custom_sky(viewPos, 1.0 - v_blindness, a, bloom_out);
        // mark as managed draw, vanilla sky is an exception
        return vec4(a.rgb * 1.0 - v_blindness, 1.0);
        // vec3 worldPos = (128.0 / length(modelPos)) * modelPos + frx_cameraPos(); // doesn't help
        // return a + fog(frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) ? frx_ambientIntensity() : 1.0, vec4(0.0), viewPos, worldPos, bloom_out);
    }

    vec4  light     = texture(slight, uv);
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
        // marker for unmanaged draw
        a.a = translucent ? a.a : 0.0;
        return a;
    }
    vec3  normal    = texture(snormal, uv).xyz * 2.0 - 1.0;
    vec3  material  = texture(smaterial, uv).xyz;
    float roughness = material.x == 0.0 ? 1.0 : min(1.0, 1.0203 * material.x - 0.01);
    float metallic  = material.y;
    vec3  worldPos  = frx_cameraPos() + (frx_inverseViewMatrix() * vec4(viewPos, 1.0)).xyz;
    float f0        = material.z;
    float bloom_raw = light.z * 2.0 - 1.0;
    bool  diffuse   = material.x < 1.0;
    vec3  misc      = texture(smisc, uv).xyz;
    float matflash  = bit_unpack(misc.z, 0);
    float mathurt   = bit_unpack(misc.z, 1);
    // return vec4(coords_view(uv, frx_inverseProjectionMatrix(), depth), 1.0);

    bool maybeUnderwater = (!translucent && translucentDepth >= depth && frx_viewFlag(FRX_CAMERA_IN_WATER))
        || (translucentDepth < depth && !frx_viewFlag(FRX_CAMERA_IN_WATER));

    #if defined(SHADOW_MAP_PRESENT)
        #ifdef TAA_ENABLED
            vec2 uvJitter = taa_jitter(v_invSize);
            vec4 unjitteredModelPos = frx_inverseViewProjectionMatrix() * vec4(2.0 * uv - uvJitter - 1.0, 2.0 * depth - 1.0, 1.0);
            vec4 shadowViewPos = frx_shadowViewMatrix() * vec4(unjitteredModelPos.xyz/unjitteredModelPos.w, 1.0);
        #else
            vec4 shadowViewPos = frx_shadowViewMatrix() * vec4(worldPos - frx_cameraPos(), 1.0);
        #endif
        // PCF broke on translucent possibly because it wasn't included in shadow pass ?
        float shadowFactor = translucent ? simpleShadowFactor(u_shadow, shadowViewPos) : calcShadowFactor(u_shadow, shadowViewPos);  
        light.z = shadowFactor;
        // Workaround before shadow occlusion culling to make caves playable
        light.z *= l2_clampScale(0.03125, 0.04, light.y);
        // This can be improved with translucent layer shadow when it's available
        if (maybeUnderwater) {
            light.z *= pow(light.y, 6.0);
        }
    #else
        light.z = l2_lightmapRemap(light.y);
        // Prevent full direct light underwater
        if (maybeUnderwater) {
            light.z *= pow(light.y, 6.0);
        }
    #endif

    #if CAUSTICS_MODE == CAUSTICS_MODE_TEXTURE
        if (maybeUnderwater) {
            #if defined(SHADOW_MAP_PRESENT)
                light.z = mix(light.z, 0.0, min(1.0, 0.25 * caustics(worldPos)));
            #else
                light.z = mix(1.0, light.z, (1.0-light.z) * min(1.0, 1.5 * caustics(worldPos)));
            #endif
        }
    #endif

    bloom_out = max(0.0, bloom_raw);
    #ifdef RAIN_PUDDLES
        ww_puddle_pbr(a, roughness, light.y, normal, worldPos);
    #endif
    #if BLOCKLIGHT_SPECULAR_MODE == BLOCKLIGHT_SPECULAR_MODE_FANTASTIC
        preCalc_blockDir = calcBlockDir(slight, uv, v_invSize, normal, viewPos, sdepth);
    #endif
    pbr_shading(a, bloom_out, viewPos, light.xyz, normal, roughness, metallic, f0, diffuse, translucent);


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
    a.rgb *= ao_shaded * ssao;
#endif
    if (matflash == 1.0) a.rgb += 1.0;
    if (mathurt == 1.0) a.r += 0.5;

    a.a = min(1.0, a.a);

    #if GLINT_MODE == GLINT_MODE_GLINT_SHADER
        a.rgb += hdr_gammaAdjust(noise_glint(misc.xy, bit_unpack(misc.z, 2)));
    #else
        a.rgb += hdr_gammaAdjust(texture_glint(u_glint, misc.xy, bit_unpack(misc.z, 2)));
    #endif

    if (a.a != 0.0 && (translucent || translucentDepth >= depth) && depth != 1.0) {
        a = fog(l2_lightmapRemap(light.y), a, viewPos, worldPos, bloom_out);
    }

    #if CAUSTICS_MODE == CAUSTICS_MODE_TEXTURE
        if (frx_viewFlag(FRX_CAMERA_IN_WATER) && translucentDepth >= depth) {
            a.rgb += light.y * light.y * 0.1 * atmos_hdrCelestialRadiance() * volumetric_caustics_beam(worldPos);
        }
    #endif

    return a;
}
