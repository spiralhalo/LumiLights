#include frex:shaders/lib/math.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/view.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/common/lighting.glsl
#include lumi:shaders/common/lightsource.glsl
#include lumi:shaders/lib/pbr.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/block_dir.glsl

/*******************************************************
 *  lumi:shaders/func/pbr_shading.glsl                 *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

const float PBR_SPECULAR_BLOOM_ADD = 0.01;
const float PBR_SPECULAR_ALPHA_ADD = 0.01;

vec3 pbr_fakeMetallicDiffuseMultiplier(vec3 albedo, float metallic, vec3 radiance)
{
    return mix(vec3(1.0), albedo * frx_luminance(clamp(radiance, 0.0, 1.0)) * 0.25, metallic);
}

vec3 pbr_nonDirectional(vec3 albedo, float metallic, vec3 radiance)
{
    return albedo * pbr_fakeMetallicDiffuseMultiplier(albedo, metallic, radiance) / PI * radiance;
}

vec3 pbr_lightCalc(vec3 albedo, float roughness, float metallic, vec3 pbr_f0, vec3 radiance, vec3 lightDir, vec3 viewDir, vec3 normal, float translucency, bool diffuseOn, inout vec3 specularAccu)
{
    vec3 halfway = normalize(viewDir + lightDir);
    // disableDiffuse hack
    if (!diffuseOn) {
        return albedo / PI * radiance * pbr_dot(lightDir, vec3(.0, 1.0, .0));
    }
    vec3 fresnel = pbr_fresnelSchlick(pbr_dot(viewDir, halfway), pbr_f0);
    float NdotL = pbr_dot(normal, lightDir);
    vec3 specularRadiance = pbr_specularBRDF(roughness, radiance, halfway, lightDir, viewDir, normal, fresnel, NdotL);
    //Fake metallic diffuse applied
    float diffuseNdotL = mix(NdotL, 1.0, translucency); // let more light pass through translucent objects
    vec3 diffuse = (1.0 - fresnel);
    vec3 diffuseRadiance = albedo * pbr_fakeMetallicDiffuseMultiplier(albedo, metallic, radiance) / PI * radiance * diffuseNdotL;
    specularAccu += specularRadiance;
    return specularRadiance + diffuseRadiance;
}

struct light_data{
    bool diffuse;
    vec3 albedo;
    float roughness;
    float metallic;
    vec3 f0;
    vec3 light;
    vec3 normal;
    vec3 viewDir;
    vec3 viewPos;
    vec3 specularAccu;
    float translucency;
};

vec3 hdr_calcBlockLight(inout light_data data, vec3 radiance)
{
    bool useFancySpecular = data.diffuse;
    #if BLOCKLIGHT_SPECULAR_MODE == BLOCKLIGHT_SPECULAR_MODE_FAST
        useFancySpecular = useFancySpecular && data.metallic > 0.0;
    #endif
    
    if (!useFancySpecular) return pbr_nonDirectional(data.albedo, data.metallic, radiance);
    
    #if BLOCKLIGHT_SPECULAR_MODE == BLOCKLIGHT_SPECULAR_MODE_FANTASTIC
        vec3 lightDir = preCalc_blockDir;
    #else
        vec3 lightDir = data.normal;
    #endif

    // low fancy specular smoothness for metals
    float roughness = mix(data.roughness, max(0.4, data.roughness), data.metallic);
    // harshly lower f0 the further away from light source for non-metal
    vec3 f0 = data.f0 * mix(l2_clampScale(0.5, 0.96875, data.light.x), 1.0, data.metallic);
    
    return pbr_lightCalc(data.albedo, roughness, data.metallic, f0, radiance, lightDir, data.viewDir, data.normal, data.translucency, true, data.specularAccu);
}

vec3 hdr_calcHeldLight(inout light_data data)
{
#if HANDHELD_LIGHT_RADIUS != 0
    if (frx_heldLight().w > 0) {
        vec3 handHeldDir = data.viewDir;
        vec3 handHeldRadiance = l2_handHeldRadiance(data.viewPos);
        if (handHeldRadiance.x + handHeldRadiance.y + handHeldRadiance.z > 0) {
            vec3 adjustedNormal = data.diffuse ? data.normal : data.viewDir;
            return pbr_lightCalc(data.albedo, data.roughness, data.metallic, data.f0, handHeldRadiance, handHeldDir, data.viewDir, adjustedNormal, data.translucency, true, data.specularAccu);
        }
    }
#endif
    return vec3(0.0);
}

vec3 hdr_calcSkyLight(inout light_data data)
{
    if (frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT)) {
        vec3 celestialRad = data.light.z * atmos_hdrCelestialRadiance() * (1. - frx_rainGradient()); // no direct sunlight during rain
        return pbr_lightCalc(data.albedo, data.roughness, data.metallic, data.f0, celestialRad, frx_skyLightVector(), data.viewDir, data.normal, data.translucency, data.diffuse, data.specularAccu);
    } else {
        vec3 skylessRadiance = l2_skylessRadiance();
        vec3 skylessDir = l2_skylessDir();
        vec3 skylessLight = pbr_lightCalc(data.albedo, data.roughness, data.metallic, data.f0, skylessRadiance, skylessDir, data.viewDir, data.normal, data.translucency, data.diffuse, data.specularAccu);
        if (frx_isSkyDarkened()) {
            vec3 skylessDarkenedDir = l2_skylessDarkenedDir();
            skylessLight += pbr_lightCalc(data.albedo, data.roughness, data.metallic, data.f0, skylessRadiance, skylessDarkenedDir, data.viewDir, data.normal, data.translucency, data.diffuse, data.specularAccu);
        }
        return skylessLight;
    }
}

void pbr_shading(inout vec4 a, inout float bloom, vec3 viewPos, vec3 light, vec3 normal, float roughness, float metallic, float pbr_f0, bool isDiffuse, bool translucent)
{
    vec3 albedo = hdr_gammaAdjust(a.rgb);
    light_data data = light_data(
        isDiffuse,
        albedo,
        roughness,
        metallic,
        mix(vec3(pbr_f0), albedo, metallic),
        light,
        normal,
        normalize(-viewPos) * frx_normalModelMatrix(),
        viewPos,
        vec3(0.0),
        (translucent && a.a > 0.) ? (1.0 - min(a.a, 1.0)) : 0.0
    );

    vec3 held_light  = hdr_calcHeldLight(data);
    vec3 block_light = hdr_calcBlockLight(data, l2_blockRadiance(data.light.x));
    vec3 sky_light   = hdr_calcSkyLight(data) * CELESTIAL_LIGHT_MULTIPLIER;

    vec3 ndRadiance = l2_baseAmbientRadiance();
    ndRadiance += atmos_hdrSkyAmbientRadiance() * l2_lightmapRemap(data.light.y) * SKY_AMBIENT_MULTIPLIER;
    ndRadiance += l2_emissiveRadiance(data.albedo, bloom);
    
    vec3 nd_light = pbr_nonDirectional(data.albedo, data.metallic, ndRadiance);
    
    a.rgb = held_light + block_light + sky_light + nd_light;

    float specularLuminance = frx_luminance(data.specularAccu);
    float smoothness = 1 - data.roughness;
    bloom += specularLuminance * PBR_SPECULAR_BLOOM_ADD * smoothness * smoothness; 
    if (translucent && data.diffuse) {
        a.a = a.a > 0.0 ? mix(a.a, 1.0, pow(1.0 - pbr_dot(data.viewDir, data.normal), 5.0)) : 0.0;
        a.a += specularLuminance * PBR_SPECULAR_ALPHA_ADD;
    }
}
