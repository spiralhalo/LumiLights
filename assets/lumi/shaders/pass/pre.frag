#include lumi:shaders/pass/header.glsl

#include lumi:shaders/lib/bitpack.glsl

/*******************************************************
 *  lumi:shaders/post/pre.frag
 *******************************************************/

uniform sampler2D u_vanilla_depth;
uniform sampler2DArray u_gbuffer_light;
uniform sampler2DArray u_gbuffer_normal;

layout(location = 0) out vec3 lightDirection;

void calcLightDir()
{
	float lightO = texture(u_gbuffer_light, vec3(v_texcoord, ID_SOLID_LIGT)).x;

	if (lightO == 0.0) discard;

	vec3 move = vec3(v_invSize, 0.0);

	float zO  = texture(u_vanilla_depth, v_texcoord).r;
	float zT  = texture(u_vanilla_depth, v_texcoord + move.xz).r;
	float zB  = texture(u_vanilla_depth, v_texcoord + move.zy).r;

	// Overzealous direction chooser
	// float zTp = texture(u_vanilla_depth, v_texcoord - move.xz).r;
	// float zBp = texture(u_vanilla_depth, v_texcoord - move.zy).r;
	// float mulT = 1.0;
	// float mulB = 1.0;

	// if (abs(zT - zO) >= abs(zTp - zO)) {
	// 	move.x *= -1.0;
	// 	zT = zTp;
	// 	mulT = -1.0;
	// }

	// if (abs(zB - zO) >= abs(zBp - zO)) {
	// 	move.y *= -1.0;
	// 	zB = zBp;
	// 	mulB = -1.0;
	// }

	float dLightdT = texture(u_gbuffer_light, vec3(v_texcoord + move.xz, ID_SOLID_LIGT)).x - lightO;
	float dLightdB = texture(u_gbuffer_light, vec3(v_texcoord + move.zy, ID_SOLID_LIGT)).x - lightO;

	vec4 posO = frx_inverseViewProjectionMatrix() * vec4(v_texcoord * 2.0 - 1.0, zO * 2.0 - 1.0, 1.0);
	vec4 posT = frx_inverseViewProjectionMatrix() * vec4((v_texcoord + move.xz) * 2.0 - 1.0, zT * 2.0 - 1.0, 1.0);
	vec4 posB = frx_inverseViewProjectionMatrix() * vec4((v_texcoord + move.zy) * 2.0 - 1.0, zB * 2.0 - 1.0, 1.0);

	vec3 normal = normalize(texture(u_gbuffer_normal, vec3(v_texcoord, ID_SOLID_NORM)).xyz * 2.0 - 1.0);
	vec3 tangent = normalize(posT.xyz - posO.xyz)/* * mulT*/;
	vec3 bitangent = normalize(posB.xyz - posO.xyz)/* * mulB*/;

	mat3 tbn = mat3(tangent, bitangent, normal);

	const float EMPHASIS = 10.0;

	vec3 lightDir = tbn * normalize(vec3(dLightdT/* * mulT*/, dLightdB/* * mulB*/, lightO * (1. / EMPHASIS)));

	lightDirection = lightDir * 0.5 + 0.5;
}

// A smidge faster (like 0.01 ms at 1080p) but more artifact lol
void calcLightDirDF()
{
	float lightO = texture(u_gbuffer_light, vec3(v_texcoord, ID_SOLID_LIGT)).x;

	if (lightO == 0.0) discard;

	float zO  = texture(u_vanilla_depth, v_texcoord).r;
	vec4 posO = frx_inverseViewProjectionMatrix() * vec4(v_texcoord * 2.0 - 1.0, zO * 2.0 - 1.0, 1.0);

	vec3 normal = normalize(texture(u_gbuffer_normal, vec3(v_texcoord, ID_SOLID_NORM)).xyz * 2.0 - 1.0);
	vec3 tangent = normalize(dFdx(posO).xyz);
	vec3 bitangent = normalize(dFdy(posO).xyz);

	mat3 tbn = mat3(tangent, bitangent, normal);

	const float EMPHASIS = 10.0;

	vec3 lightDir = tbn * normalize(vec3(dFdx(lightO), dFdy(lightO), lightO * (1. / EMPHASIS)));

	lightDirection = lightDir * 0.5 + 0.5;
}

void main()
{
	calcLightDir();
}
