#include lumi:shaders/lib/pbr.glsl

/*******************************************************
 *  lumi:shaders/prog/reflection.glsl
 *******************************************************/

vec3 reflectionPbr(vec3 albedo, vec3 material, vec3 radiance, vec3 toLight, vec3 toEye)
{
	vec3 f0 = mix(vec3(material.z), albedo, material.y);
	vec3 halfway = normalize(toEye + toLight);
	vec3 fresnel = pbr_fresnelSchlick(pbr_dot(toEye, halfway), f0);
	float smoothness = (1. - material.x);

	return clamp(fresnel * radiance * smoothness * smoothness, 0.0, 1.0);
}
