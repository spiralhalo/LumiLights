#include lumi:shaders/pass/header.glsl

#include lumi:shaders/prog/overlay.glsl
#include lumi:shaders/prog/shading.glsl
#include lumi:shaders/prog/sky.glsl
#include lumi:shaders/prog/tonemap.glsl

/*******************************************************
 *  lumi:shaders/pass/hand.frag
 *******************************************************/

uniform sampler2D u_vanilla_color;
uniform sampler2D u_vanilla_depth;

uniform sampler2DArray u_gbuffer_main_etc;
uniform sampler2DArray u_gbuffer_light;
uniform sampler2DArray u_gbuffer_normal;

uniform sampler2D u_tex_sun;
uniform sampler2D u_tex_moon;
uniform sampler2D u_tex_nature;
uniform sampler2D u_tex_glint;
uniform sampler2D u_tex_noise;

out vec4 fragColor;

void main()
{
	float dSolid = texture(u_vanilla_depth, v_texcoord).r;
	vec4  cSolid = texture(u_vanilla_color, v_texcoord);

	bool f1Pressed = texture(u_vanilla_depth, vec2(0.5, 1.0)).r != 1.0;

	if (dSolid == 1.0 || f1Pressed) {
		fragColor = cSolid;
	} else {
		vec4 tempPos = frx_inverseViewProjectionMatrix * vec4(2.0 * v_texcoord - 1.0, 2.0 * dSolid - 1.0, 1.0);
		vec3 eyePos  = tempPos.xyz / tempPos.w;

		vec4 light	= texture(u_gbuffer_light, vec3(v_texcoord, ID_SOLID_LIGT));
		vec3 rawMat = texture(u_gbuffer_main_etc, vec3(v_texcoord, ID_SOLID_MATS)).xyz;
		vec3 normal	= texture(u_gbuffer_normal, vec3(v_texcoord, 1.)).xyz * 2.0 - 1.0;
		vec3 misc	= texture(u_gbuffer_main_etc, vec3(v_texcoord, ID_SOLID_MISC)).xyz;
		float disableDiffuse = bit_unpack(misc.z, 4);
		float vertexNormaly = texture(u_gbuffer_normal, vec3(v_texcoord, ID_SOLID_NORM)).y * 2.0 - 1.0;

		light.w = lightmapRemap(light.y);
		normal = normal * frx_normalModelMatrix;

		fragColor = shading(cSolid, u_tex_nature, light, rawMat, eyePos, normal, vertexNormaly, frx_cameraInWater == 1., disableDiffuse);
		fragColor += skyReflection(u_tex_sun, u_tex_moon, u_tex_noise, cSolid.rgb, rawMat.xy, normalize(eyePos), normal, light.yy);

		fragColor = overlay(fragColor, u_tex_glint, misc);

		fragColor = ldr_tonemap(fragColor);
	}
}
