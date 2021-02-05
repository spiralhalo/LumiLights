/*******************************************************
 *  lumi:shaders/internal/pbr_shading.glsl             *
 *******************************************************
 *  Copyright (c) 2020 spiralhalo and Contributors.    *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/
 
const float PBR_SPECULAR_BLOOM_ADD = 0.01;
const float PBR_SPECULAR_ALPHA_ADD = 0.01;

vec3 pbr_specularBRDF(float roughness, vec3 radiance, vec3 halfway, vec3 lightDir, vec3 viewDir, vec3 normal, vec3 fresnel, float NdotL) {
	// cook-torrance brdf
	float distribution = pbr_distributionGGX(normal, halfway, roughness);
	float geometry     = pbr_geometrySmith(normal, viewDir, lightDir, roughness);

	vec3  num   = distribution * geometry * fresnel;
	float denom = 4.0 * pbr_dot(normal, viewDir) * NdotL;

	vec3  specular = num / max(denom, 0.001);
	return specular * radiance * NdotL;
}

vec3 pbr_fakeMetallicDiffuseMultiplier(vec3 albedo, float metallic, vec3 radiance)
{
    return mix(vec3(1.0), albedo * frx_luminance(clamp(radiance, 0.0, 1.0)) * 0.25, metallic);
}

vec3 pbr_nonDirectional(vec3 albedo, float metallic, vec3 radiance)
{
    return albedo * pbr_fakeMetallicDiffuseMultiplier(albedo, metallic, radiance) / PI * radiance;
}

vec3 pbr_lightCalc(vec3 albedo, float roughness, float metallic, vec3 pbr_f0, vec3 radiance, vec3 lightDir, vec3 viewDir, vec3 normal, bool diffuseOn, inout vec3 specularAccu)
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
    vec3 diffuse = (1.0 - fresnel);
    vec3 diffuseRadiance = albedo * pbr_fakeMetallicDiffuseMultiplier(albedo, metallic, radiance) / PI * radiance * NdotL;
    specularAccu += specularRadiance;
    return specularRadiance + diffuseRadiance;
}

struct light_data{
    bool diffuse;
    vec3 albedo;
    float roughness;
    float metallic;
    vec3 f0;
    vec2 light;
    vec3 normal;
    vec3 viewDir;
    vec3 viewPos;
    vec3 specularAccu;
};

vec3 hdr_calcAmbientLight(inout light_data data, vec3 radiance)
{
    vec3 ambientReflection = pbr_fresnelSchlick(pbr_dot(data.viewDir, data.normal), data.f0 * data.metallic) * (1.0 - data.roughness);
    return data.albedo * pbr_fakeMetallicDiffuseMultiplier(data.albedo, data.metallic, radiance) / PI * radiance * (1.0 - ambientReflection) + ambientReflection * radiance;
}

vec3 hdr_calcBlockLight(inout light_data data, vec3 radiance)
{
    if (data.diffuse) {
        return pbr_lightCalc(data.albedo, max(data.roughness, 0.4), data.metallic, data.f0, radiance, data.normal, data.viewDir, data.normal, true, data.specularAccu);
    } else {
        return pbr_nonDirectional(data.albedo, data.metallic, radiance);
    }
}

vec3 hdr_calcHeldLight(inout light_data data)
{
#if HANDHELD_LIGHT_RADIUS != 0
    if (frx_heldLight().w > 0) {
        vec3 handHeldDir = data.viewDir;
        vec3 handHeldRadiance = l2_handHeldRadiance();
        if (handHeldRadiance.x + handHeldRadiance.y + handHeldRadiance.z > 0) {
            vec3 adjustedNormal = data.diffuse ? data.normal : data.viewDir;
            return pbr_lightCalc(data.albedo, data.roughness, data.metallic, data.f0, handHeldRadiance, handHeldDir, data.viewDir, adjustedNormal, true, data.specularAccu);
        }
    }
#endif
    return vec3(0.0);
}

vec3 hdr_calcSkyAmbientLight(inout light_data data)
{
    if (frx_worldHasSkylight())
    {
        vec3 skyRadiance = l2_skyAmbient(data.light.y, frx_worldTime(), frx_ambientIntensity());
        return hdr_calcAmbientLight(data, skyRadiance);
    }
    return vec3(0.0);
}

vec3 hdr_calcSkyLight(inout light_data data)
{
    if (frx_worldHasSkylight()) {
        vec3 sunLightRadiance = l2_sunRadiance(data.light.y, frx_worldTime(), frx_ambientIntensity(), frx_rainGradient());
        #ifdef TRUE_DARKNESS_MOONLIGHT
            vec3 moonLightRadiance = vec3(0.0);
            if (frx_luminance(sunLightRadiance) == 0.0) return moonLightRadiance;
        #else
            vec3 moonLightRadiance = l2_moonRadiance(data.light.y, frx_worldTime(), frx_ambientIntensity());
        #endif
        vec3 irradiance;
        vec3 skylightRadiance;
        vec3 skylightDir;
        if (frx_luminance(sunLightRadiance) > frx_luminance(moonLightRadiance)) {
            skylightRadiance = sunLightRadiance;
            skylightDir = l2_vanillaSunDir(frx_worldTime(), 0.0);
        } else {
            skylightRadiance = moonLightRadiance;
            skylightDir = l2_moonDir(frx_worldTime());
        }
        irradiance = pbr_lightCalc(data.albedo, data.roughness, data.metallic, data.f0, skylightRadiance, skylightDir, data.viewDir, data.normal, data.diffuse, data.specularAccu);
        float haloBlur = 0.15;
        if (data.roughness < haloBlur) {
            irradiance *= 0.75;
            irradiance += 0.25 * pbr_lightCalc(data.albedo, haloBlur, data.metallic, data.f0, skylightRadiance, skylightDir, data.viewDir, data.normal, data.diffuse, data.specularAccu);
        }
        return irradiance;
    } else {
        vec3 skylessRadiance = l2_skylessRadiance();
        vec3 skylessDir = l2_skylessDir();
        vec3 skylessLight = pbr_lightCalc(data.albedo, data.roughness, data.metallic, data.f0, skylessRadiance, skylessDir, data.viewDir, data.normal, data.diffuse, data.specularAccu);
        if (frx_isSkyDarkened()) {
            vec3 skylessDarkenedDir = l2_skylessDarkenedDir();
            skylessLight += pbr_lightCalc(data.albedo, data.roughness, data.metallic, data.f0, skylessRadiance, skylessDarkenedDir, data.viewDir, data.normal, data.diffuse, data.specularAccu);
        }
        return skylessLight;
    }
}

void pbr_shading(in frx_FragmentData fragData, inout vec4 a, inout float bloom, in float userBrightness, in bool translucent)
{
    vec3 albedo = hdr_gammaAdjust(a.rgb);
    light_data data = light_data(
        fragData.diffuse,
        albedo,
        pbr_roughness,
        pbr_metallic,
        mix(pbr_f0, albedo, pbr_metallic),
        fragData.light,
        fragData.vertexNormal * frx_normalModelMatrix(),
        normalize(-l2_viewPos) * frx_normalModelMatrix() * gl_NormalMatrix,
        l2_viewPos,
        vec3(0.0)
    );

    float perceivedBl = fragData.light.x;
#if LUMI_LightingMode == LUMI_LightingMode_Dramatic
	if (frx_modelOriginType() != MODEL_ORIGIN_REGION) {
		perceivedBl = max(0, perceivedBl - fragData.light.y * 0.1);
	}
#endif
    data.light.x = perceivedBl;
    
    float ao = l2_ao(fragData);
    vec3 held_light = hdr_calcHeldLight(data);
    vec3 block_light = hdr_calcBlockLight(data, l2_blockRadiance(data.light.x));
    vec3 base_ambient_light = hdr_calcAmbientLight(data, l2_baseAmbient());
    vec3 sky_ambient_light = hdr_calcSkyAmbientLight(data);
    vec3 sky_light = hdr_calcSkyLight(data);
    vec3 emissive_light = pbr_nonDirectional(data.albedo, data.metallic, l2_emissiveRadiance(data.albedo, bloom));
    
    a.rgb = (held_light + block_light + base_ambient_light + sky_ambient_light + sky_light) * ao + emissive_light;
    a.rgb *= mix(1.0, 2.0, userBrightness);

    float specularLuminance = frx_luminance(data.specularAccu);
    float smoothness = 1 - data.roughness;
    bloom += specularLuminance * PBR_SPECULAR_BLOOM_ADD * smoothness * smoothness;
    if (translucent) a.a += specularLuminance * PBR_SPECULAR_ALPHA_ADD;
}


