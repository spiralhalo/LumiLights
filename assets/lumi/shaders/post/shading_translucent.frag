#include lumi:shaders/post/common/header.glsl

#include lumi:shaders/post/common/shading_includes.glsl
#include lumi:shaders/lib/translucent_layering.glsl

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
uniform sampler2D u_alpha_translucent;
uniform sampler2D u_solid_depth;
uniform sampler2D u_light_solid;

uniform sampler2D u_refraction_uv;

out vec4[2] fragColor;

void custom_sky(in vec3 modelPos, in float blindnessFactor, in bool maybeUnderwater, inout vec4 a, inout float bloom_out)
{

}

#include lumi:shaders/post/common/shading.glsl

vec4 advancedTranslucentShading(float ec, out float bloom_out) {
	vec4 frontAlbedo = vec4(texture(u_albedo_translucent, v_texcoord).rgb, texture(u_alpha_translucent, v_texcoord).r);
	vec4 light       = texture(u_light_translucent, v_texcoord);
	vec3 normal      = texture(u_normal_translucent, v_texcoord).xyz;
	vec4 backColor   = texture(u_translucent_color, v_texcoord);

	bool isUnmanaged = light.x == 0.0;

	// workaround for end portal glitch
	// do two checks for false positve prevention
	isUnmanaged = isUnmanaged || distance(light.rgb + frontAlbedo.rgb, backColor.rgb * 2) < 0.015;

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

	normal = 2.0 * normal - 1.0;

	vec4 frontColor = hdr_shaded_color(
		v_texcoord, u_translucent_depth, u_light_translucent, u_normal_translucent, u_material_translucent, u_misc_translucent,
		frontAlbedo, vec3(0.0), 1.0, true, true, 1.0, ec, bloom_out);

	// reverse forward gl_blend with foreground layer (lossy if clipping)
	vec3 unblend = frontAlbedo.rgb * frontAlbedo.a;

#if TRANSLUCENT_LAYERING == TRANSLUCENT_LAYERING_FANCY
	float luminosity2 = calcLuminosity(normal, light.xy, frontAlbedo.a);
	unblend *= luminosity2 * luminosity2;
#endif

	backColor.rgb = max(vec3(0.0), backColor.rgb - unblend);
	// backColor.rgb /= (frontAlbedo.a < 1.0) ? (1.0 - frontAlbedo.a) : 1.0;

#if TRANSLUCENT_LAYERING == TRANSLUCENT_LAYERING_FAST
	// fake shading for back color
	vec2 fakeLight = texture(u_light_solid, v_texcoord).xy;
		 fakeLight = fakeLight * 0.25 + texture(u_light_translucent, v_texcoord).xy * 0.75;
	float luminosity = hdr_fromGammaf(max(lightmapRemap(fakeLight.x), lightmapRemap(fakeLight.y) * atmosv_celestIntensity));
		  luminosity = luminosity * (1.0 - BASE_AMBIENT_STR) + BASE_AMBIENT_STR;
	backColor.rgb = backColor.rgb * luminosity * 0.5;
#endif

	float finalAlpha = max(frontColor.a, backColor.a);
	float excess = sqrt(finalAlpha - frontColor.a); //hacks

#ifdef GELATIN_MATERIAL
	// gelatin material (tentative name)
	// OBSOLETE: marked for removal. similar effect can be achieved better with reflection-based transmittance reduction
	bool isWater = bit_unpack(texture(u_misc_translucent, v_texcoord).z, 7) == 1.;

	if (isWater && !frx_viewFlag(FRX_CAMERA_IN_WATER)) {
		// TODO: use same algorithm as the one used in composite
		vec2 uvSolid = v_texcoord + (texture(u_refraction_uv, v_texcoord).rg * 2.0 - 1.0);
			 uvSolid = clamp(uvSolid, 0.0, 1.0);

		float solidDepthRaw  = texture(u_solid_depth, uvSolid).r;
		float solidDepth     = ldepth(solidDepthRaw);
		float transDepth     = ldepth(texture(u_translucent_depth, v_texcoord).r);
		float gelatinOpacity = solidDepthRaw == 1.0 ? 0.0 : l2_clampScale(0.0, 0.1, solidDepth - transDepth);

		backColor.rgb = mix(backColor.rgb, frontColor.rgb, gelatinOpacity);
		finalAlpha   += gelatinOpacity * (1.0 - finalAlpha);
	}
#endif

	// exposure cancellation ???
	backColor.rgb *= (EXPOSURE_CANCELLATION, 1.0, ec);

	// blend front and back
	frontColor.rgb = backColor.rgb * (1.0 - frontColor.a) + frontColor.rgb * frontColor.a * (1.0 - excess);
	frontColor.a   = finalAlpha;

	return frontColor;
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
