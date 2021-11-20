#include lumi:shaders/pass/header.glsl

#include lumi:shaders/prog/shading.glsl
#include lumi:shaders/prog/sky.glsl
#include lumi:shaders/prog/tonemap.glsl

/*******************************************************
 *  lumi:shaders/pass/hand.frag
 *******************************************************/

uniform sampler2D u_vanilla_color;
uniform sampler2D u_vanilla_depth;

uniform sampler2DArray u_gbuffer_main_etc;
uniform sampler2DArray u_gbuffer_normal;

uniform sampler2D u_tex_glint;
uniform sampler2D u_tex_sun;
uniform sampler2D u_tex_moon;

out vec4 fragColor;

void main()
{
	float dSolid = texture(u_vanilla_depth, v_texcoord).r;
	vec4  cSolid = texture(u_vanilla_color, v_texcoord);

	if (dSolid == 1.0) {
		fragColor = cSolid;
	} else {
		vec4 tempPos = frx_inverseViewProjectionMatrix * vec4(2.0 * v_texcoord - 1.0, 2.0 * dSolid - 1.0, 1.0);
		vec3 eyePos  = tempPos.xyz / tempPos.w;

		vec4 light    = texture(u_gbuffer_main_etc, vec3(v_texcoord, ID_SOLID_LIGT));
		vec3 material = texture(u_gbuffer_main_etc, vec3(v_texcoord, ID_SOLID_MATS)).xyz;
		vec3 normal   = texture(u_gbuffer_normal, vec3(v_texcoord, 1.)).xyz * 2.0 - 1.0;

		light.w = lightmapRemap(light.y);
		normal = normal * frx_normalModelMatrix;

		fragColor = shading(cSolid, light, material, eyePos, normal, false);
		fragColor += skyReflection(u_tex_sun, u_tex_moon, cSolid.rgb, material, normalize(eyePos), normal, light.yy);

		fragColor = ldr_tonemap(fragColor);
	}
}
