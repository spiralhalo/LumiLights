/*******************************************************
 *  lumi:shaders/lib/pbr.glsl
 *******************************************************/

#define pbr_dot(a, b) clamp(dot(a, b), 0.0, 1.0)

float pbr_distributionGGX(vec3 N, vec3 H, float roughness)
{
	float a	  = roughness*roughness;
	float a2	 = a*a;
	float NdotH  = pbr_dot(N, H);
	float NdotH2 = NdotH*NdotH;
	
	float num   = a2;
	float denom = (NdotH2 * (a2 - 1.0) + 1.0);
	denom = PI * denom * denom;
	
	return max(0.0, num / denom);
}

float pbr_geometrySchlickGGX(float NdotV, float roughness)
{
	float r = (roughness + 1.0);
	float k = (r*r) / 8.0;

	float num   = NdotV;
	float denom = NdotV * (1.0 - k) + k;
	
	return num / denom;
}

float pbr_geometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
	float NdotV = pbr_dot(N, V);
	float NdotL = pbr_dot(N, L);
	float ggx2  = pbr_geometrySchlickGGX(NdotV, roughness);
	float ggx1  = pbr_geometrySchlickGGX(NdotL, roughness);
	
	return ggx1 * ggx2;
}

vec3 pbr_fresnelSchlick(float cosTheta, vec3 F0)
{
	return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 pbr_specularBRDF(float roughness, vec3 radiance, vec3 halfway, vec3 lightDir, vec3 viewDir, vec3 normal, vec3 fresnel, float NdotL)
{
	// cook-torrance brdf
	float distribution = pbr_distributionGGX(normal, halfway, roughness);
	float geometry	 = pbr_geometrySmith(normal, viewDir, lightDir, roughness);

	vec3  num   = distribution * geometry * fresnel;
	float denom = 4.0 * pbr_dot(normal, viewDir) * NdotL;

	vec3  specular = num / max(denom, 0.001);
	return specular * radiance * NdotL;
}
