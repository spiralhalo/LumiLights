#include frex:shaders/lib/math.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/view.glsl
#include lumi:shaders/lib/lightsource.glsl
#include lumi:shaders/lib/pbr.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/lib/pbr_shading.glsl                  *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

const float pbr_specularBloomStr = 0.01;
const float pbr_specularAlphaStr = 0.1;

vec3 pbr_specularBRDF(float roughness, vec3 radiance, vec3 halfway, vec3 lightDir, vec3 viewDir, vec3 normal, vec3 fresnel, float NdotL)
{
	// cook-torrance brdf
	float distribution = pbr_distributionGGX(normal, halfway, roughness);
	float geometry     = pbr_geometrySmith(normal, viewDir, lightDir, roughness);

	vec3  num   = distribution * geometry * fresnel;
	float denom = 4.0 * pbr_dot(normal, viewDir) * NdotL;

	vec3  specular = num / max(denom, 0.001);
	return specular * radiance * NdotL;
}

vec3 pbr_lightCalc(vec3 albedo, float pbr_roughness, float pbr_metallic, vec3 pbr_f0, vec3 radiance, vec3 lightDir, vec3 viewDir, vec3 normal, bool diffuseOn, bool isAmbiance, float haloBlur, inout vec3 specularAccu)
{
	vec3 halfway = normalize(viewDir + lightDir);
	float roughness = pbr_roughness;

	// ambiance hack
	if (isAmbiance) {
		roughness = min(1.0, roughness + 0.5 * (1 - pbr_metallic));
	}
	
	// disableDiffuse hack
	if (!diffuseOn) {
		return albedo / PI * radiance * pbr_dot(lightDir, vec3(.0, 1.0, .0));
	}

	vec3 specularRadiance;
	vec3 fresnel = pbr_fresnelSchlick(pbr_dot(viewDir, halfway), pbr_f0);
	float NdotL = pbr_dot(normal, lightDir);

	if (haloBlur > roughness) {
		// sun halo hack
		specularRadiance = pbr_specularBRDF(roughness, radiance * 0.75, halfway, lightDir, viewDir, normal, fresnel, NdotL);
		specularRadiance += pbr_specularBRDF(haloBlur, radiance * 0.25, halfway, lightDir, viewDir, normal, fresnel, NdotL);
	} else {
		specularRadiance = pbr_specularBRDF(roughness, radiance, halfway, lightDir, viewDir, normal, fresnel, NdotL);
	}

	vec3 diffuse = (1.0 - fresnel) * (1.0 - pbr_metallic);
	vec3 diffuseRadiance = albedo * diffuse / PI * radiance * NdotL;
	specularAccu += specularRadiance;

	return specularRadiance + diffuseRadiance;
}

void pbr_shading(inout vec4 a, inout float bloom, vec3 viewPos, vec2 light, vec3 normal, float pbr_roughness, float pbr_metallic, float pbr_f0, bool isDiffuse, bool translucent)
{
    // I can't begin to explain how this even fix a major bug with held light and brightness setting
    pbr_roughness = clamp(pbr_roughness, 0.6, 1.0);
	vec3 albedo = hdr_gammaAdjust(a.rgb);
	vec3 dielectricF0 = vec3(0.1) * frx_luminance(albedo);
	vec3 f0 = pbr_f0 <= 0.0 ? mix(dielectricF0, albedo, pbr_metallic) : vec3(pbr_f0);
    vec3 viewDir = normalize(-viewPos) * frx_normalModelMatrix();
    vec3 emissive = l2_emissiveRadiance(bloom);
    vec3 specularAccu = vec3(0.0);
#if LUMI_LightingMode == LUMI_LightingMode_Dramatic
    float dramaticBloom = 0;
#endif

    a.rgb = albedo;
    a.rgb *= emissive;

#if HANDHELD_LIGHT_RADIUS != 0
    if (frx_heldLight().w > 0) {
        vec3 handHeldDir = viewDir;
        vec3 handHeldRadiance = l2_handHeldRadiance(viewPos);
        if (handHeldRadiance.x + handHeldRadiance.y + handHeldRadiance.z > 0) {
            vec3 adjustedNormal = isDiffuse ? normal : viewDir;
            a.rgb += pbr_lightCalc(albedo, pbr_roughness, pbr_metallic, f0, handHeldRadiance, handHeldDir, viewDir, adjustedNormal, true, false, 0.0, specularAccu);
        }
    }
#endif

    float perceivedBl = light.x;
// #if LUMI_LightingMode == LUMI_LightingMode_Dramatic
// 	if (frx_modelOriginType() != MODEL_ORIGIN_REGION) {
// 		perceivedBl = max(0, perceivedBl - light.y * 0.1);
// 	}
// #endif
    vec3 blockRadiance = l2_blockRadiance(perceivedBl);
    vec3 baseAmbientRadiance = l2_baseAmbient();
    vec3 ambientDir = normalize(vec3(0.1, 0.9, 0.1) + normal);

    a.rgb += pbr_lightCalc(albedo, pbr_roughness, pbr_metallic, f0, blockRadiance, ambientDir, viewDir, normal, isDiffuse, true, 0.0, specularAccu);
    a.rgb += pbr_lightCalc(albedo, pbr_roughness, pbr_metallic, f0, baseAmbientRadiance, ambientDir, viewDir, normal, isDiffuse, true, 0.0, specularAccu);

    if (frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT) && light.y > 0.03125) {
        if (!frx_worldFlag(FRX_WORLD_IS_MOONLIT)) {
            vec3 sunRadiance = l2_sunRadiance(light.y, frx_worldTime(), frx_ambientIntensity(), frx_rainGradient());
            vec3 sunIrradiance = pbr_lightCalc(albedo, pbr_roughness, pbr_metallic, f0, sunRadiance, frx_skyLightVector(), viewDir, normal, isDiffuse, false, 0.15, specularAccu);
            a.rgb += sunIrradiance;
            #if LUMI_LightingMode == LUMI_LightingMode_Dramatic
                dramaticBloom = frx_luminance(sunIrradiance);
            #endif
        } else {
            #ifndef LUMI_TrueDarkness_DisableMoonlight
                vec3 moonRadiance = l2_moonRadiance(light.y, frx_worldTime(), frx_ambientIntensity());
                a.rgb += pbr_lightCalc(albedo, pbr_roughness, pbr_metallic, f0, moonRadiance, frx_skyLightVector(), viewDir, normal, isDiffuse, false, 0.15, specularAccu);
            #endif
        }
        vec3 skyRadiance = l2_skyAmbient(light.y, frx_worldTime(), frx_ambientIntensity());
        a.rgb += pbr_lightCalc(albedo, pbr_roughness, pbr_metallic, f0, skyRadiance, ambientDir, viewDir, normal, isDiffuse, true, 0.0, specularAccu);
    } else {
        vec3 skylessRadiance = l2_skylessRadiance();
        vec3 skylessDir = l2_skylessDir();

        if (skylessRadiance.r + skylessRadiance.g + skylessRadiance.b > 0) {
            a.rgb += pbr_lightCalc(albedo, pbr_roughness, pbr_metallic, f0, skylessRadiance, skylessDir, viewDir, normal, isDiffuse, false, 0.0, specularAccu);
            if (frx_isSkyDarkened()) {
                vec3 skylessDarkenedDir = l2_skylessDarkenedDir();
                a.rgb += pbr_lightCalc(albedo, pbr_roughness, pbr_metallic, f0, skylessRadiance, skylessDarkenedDir, viewDir, normal, isDiffuse, false, 0.0, specularAccu);
            }
        }
    }
    float specularLuminance = frx_luminance(specularAccu);
    float smoothness = (1-pbr_roughness);
    bloom += specularLuminance * pbr_specularBloomStr * smoothness * smoothness;
#if LUMI_LightingMode == LUMI_LightingMode_Dramatic
    bloom += dramaticBloom * l2_sunHorizonScale(frx_worldTime()) * hdr_dramaticStr * clamp(LUMI_DramaticLighting_DramaticBloomIntensity * 0.1, 0.0, 1.0);
#endif
    if (translucent) {
        a.a += specularLuminance * pbr_specularBloomStr;
    }
}
