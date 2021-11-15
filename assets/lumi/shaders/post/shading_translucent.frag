#include lumi:shaders/post/common/header.glsl

#include lumi:shaders/post/common/shading_includes.glsl
#include lumi:shaders/lib/pack_normal.glsl

/*******************************************************
 *  lumi:shaders/post/shading_translucent.frag
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

uniform sampler2D u_translucent_color;
uniform sampler2D u_translucent_depth;
uniform sampler2D u_light_translucent;
uniform sampler2D u_normal_translucent;
uniform sampler2D u_material_translucent;
uniform sampler2D u_misc_translucent;

uniform sampler2D u_albedo_translucent;
uniform sampler2D u_solid_depth;
uniform sampler2D u_light_solid;

uniform sampler2D u_refraction_uv;

out vec4[2] fragColor;

void custom_sky(in vec3 modelPos, in float blindnessFactor, in bool maybeUnderwater, inout vec4 a, inout float bloom_out)
{

}

#include lumi:shaders/post/common/shading.glsl

vec4 advancedTranslucentShading(float ec, out float bloom_out) {
	vec4 light	= texture(u_light_translucent, v_texcoord);
	vec3 normal	= texture(u_normal_translucent, v_texcoord).xyz;
	vec3 misc	= texture(u_misc_translucent, v_texcoord).xyz;
	vec4 albedo	= texture(u_translucent_color, v_texcoord);

	bool isUnmanaged = light.x == 0.0;

	// workaround for end portal glitch
	// do two checks for false positve prevention
	isUnmanaged = isUnmanaged || distance(light.rgb + misc.rgb, albedo.rgb * 2) < 0.015;

	if (isUnmanaged) {
	// fake TAA that just makes things blurry
	// #ifdef TAA_ENABLED
	//	 vec2 taaJitter = taa_jitter(v_invSize);
	// #else
	//	 vec2 taaJitter = vec2(0.0);
	// #endif
		vec4 color = texture(u_translucent_color, v_texcoord);
		 color.rgb = hdr_fromGamma(color.rgb);
		return unmanaged(color, bloom_out, true);
	}

	albedo.rgb /= albedo.a;
	albedo.a = pow(albedo.a, 1. / 10.);

	vec2 prime		 = texture(u_albedo_translucent, v_texcoord).rg;
	vec4 truePrime	 = vec4(unpackVec2(prime.r), unpackVec2(prime.g));
		 truePrime.a = sqrt(truePrime.a); // I have no idea why this is needed; is there a sqrt somewhere in composite someone please tell me

	albedo.rgb = albedo.rgb * (1.0 - truePrime.a) + truePrime.rgb * truePrime.a;
	albedo.a  *= albedo.a; // like cheap gamma correction or something

#ifdef GELATIN_MATERIAL
	// gelatin material (tentative name)
	// OBSOLETE: marked for removal. similar effect can be achieved better with reflection-based transmittance reduction
	bool isWater = bit_unpack(misc.z, 7) == 1.;

	if (isWater && !frx_viewFlag(FRX_CAMERA_IN_WATER)) {
		// TODO: use same algorithm as the one used in composite
		vec2 uvSolid = v_texcoord + (texture(u_refraction_uv, v_texcoord).rg * 2.0 - 1.0);
			 uvSolid = clamp(uvSolid, 0.0, 1.0);

		float solidDepthRaw  = texture(u_solid_depth, uvSolid).r;
		float solidDepth     = ldepth(solidDepthRaw);
		float transDepth     = ldepth(texture(u_translucent_depth, v_texcoord).r);
		float gelatinOpacity = solidDepthRaw == 1.0 ? 0.0 : l2_clampScale(0.0, 0.1, solidDepth - transDepth);

		albedo.a += gelatinOpacity * (1.0 - albedo.a);
	}
#endif

	return hdr_shaded_color(
		v_texcoord, u_translucent_depth, u_light_translucent, u_normal_translucent, u_material_translucent, u_misc_translucent,
		albedo, vec3(0.0), 1.0, true, true, 1.0, ec, bloom_out);
}

void main()
{
	tileJitter = getRandomFloat(u_blue_noise, v_texcoord, frxu_size);

	float ec = exposureCompensation();
	float bloom1;
	vec4 a1 = advancedTranslucentShading(ec, bloom1);

	fragColor[0] = a1;
	fragColor[1] = vec4(bloom1, 0.0, 0.0, 1.0);
}
