#include lumi:shaders/post/common/header.glsl

#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/bitpack.glsl
#include lumi:shaders/lib/pack_normal.glsl
#include lumi:shaders/lib/puddle.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/water.glsl

/*******************************************************
 *  lumi:shaders/post/normal_preprocess.frag
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo
 *  Released WITHOUT WARRANTY under the terms of the
 *  GNU Lesser General Public License version 3 as
 *  published by the Free Software Foundation, Inc.
 *******************************************************/

uniform sampler2D u_normal_solid0;
uniform sampler2D u_normal_micro_solid0;
uniform sampler2D u_light_solid;
uniform sampler2D u_depth_solid;

uniform sampler2D u_normal_translucent0;
uniform sampler2D u_normal_micro_translucent0;
uniform sampler2D u_light_translucent;
uniform sampler2D u_depth_translucent;
uniform sampler2D u_misc_translucent;

out vec4 fragColor[7];

const float smol_waveSpeed = 1;
const float smol_scale = 1.5;
const float smol_amplitude = 0.01;
const float beeg_waveSpeed = 0.8;
const float beeg_scale = 6.0;
const float beeg_amplitude = 0.25;

const float REFRACTION_STR = .1;

bool testTranslucentUnmanaged()
{
	vec4 misc   = texture(u_misc_translucent, v_texcoord);
	vec4 mnorm0 = texture(u_normal_micro_translucent0, v_texcoord);
	vec4 norm0  = texture(u_normal_translucent0, v_texcoord);

	return (norm0.x + norm0.y + norm0.z == 0.0) || distance(mnorm0.rgb + misc.rgb, norm0.rgb * 2) < 0.015;
}

void processNormalMap(sampler2D slight, in float depth, inout vec3 normal, inout vec3 tangent, bool isWater, inout vec3 microNormal, out float packedPuddle)
{
	normal      = normalize(normal);
	microNormal = normalize(microNormal);

	// normal map processing requires tangent to be set
	bool useNormalMap = dot(tangent, tangent) > 0.1;

	vec4 worldPos = frx_inverseViewProjectionMatrix * vec4(2. * v_texcoord - 1., 2. * depth - 1., 1.);
	worldPos.xyz /= worldPos.w;
	worldPos.xyz += frx_cameraPos;

	if (useNormalMap) {
		tangent = normalize(tangent);

		if (isWater) {
			/* WAVY NORMALS */
			// wave movement doesn't necessarily follow flow direction for the time being
			const float stretch = 1.2;
			float waveSpeed = mix(smol_waveSpeed, beeg_waveSpeed, abs(normal.y));
			float scale     = mix(smol_scale, beeg_scale, abs(normal.y));
			float amplitude = mix(smol_amplitude, beeg_amplitude, abs(normal.y));

			vec3 moveSpeed = vec3(0.5, 3.0, -1.0) * (0.5 + 0.5 - normal * 0.5) * waveSpeed;
			vec3 samplePos = worldPos.xyz;
			vec3 noisyNormal = ww_normals(normal, tangent, cross(normal, tangent), samplePos, waveSpeed, scale, amplitude, stretch, moveSpeed);

			microNormal = normalize(mix(noisyNormal, normal, pow(depth, 500.0)));
		}
		// else
		// TODO: actually apply normal map or whatever
	}

	float lightY = texture(slight, v_texcoord).y;

	ww_puddle(lightY, normal, worldPos.xyz, microNormal, packedPuddle);
}

void main()
{
	vec3 solidNormal, solidTangent, solidMicroNormal, translucentNormal, translucentTangent, translucentMicroNormal;
	float solidPackedPuddle, translucentPackedPuddle, solidDepth, translucentDepth;

	unpackNormal(texture(u_normal_solid0, v_texcoord).rgb, solidNormal, solidTangent);

	solidMicroNormal = 2.0 * texture(u_normal_micro_solid0, v_texcoord).rgb - 1.0;
	translucentMicroNormal = 2.0 * texture(u_normal_micro_translucent0, v_texcoord).rgb - 1.0;

	solidDepth = texture(u_depth_solid, v_texcoord).r;
	processNormalMap(u_light_solid, solidDepth, solidNormal, solidTangent, false, solidMicroNormal, solidPackedPuddle);

	if (testTranslucentUnmanaged()) {
		translucentPackedPuddle = 0.;
		translucentDepth = 1.0;
	} else {
		unpackNormal(texture(u_normal_translucent0, v_texcoord).rgb, translucentNormal, translucentTangent);

		bool translucentIsWater = bit_unpack(texture(u_misc_translucent, v_texcoord).b, 7) == 1.;
		translucentDepth = texture(u_depth_translucent, v_texcoord).r;
		processNormalMap(u_light_translucent, translucentDepth, translucentNormal, translucentTangent, translucentIsWater, translucentMicroNormal, translucentPackedPuddle);
	}

	vec2 refraction_uv = vec2(0.5);

#ifdef REFRACTION_EFFECT
	if (translucentDepth < solidDepth) {
		float ldepth_range = ldepth(solidDepth) - ldepth(translucentDepth);

		vec3 viewVNormal = _cv_aDirtyHackModelMatrix * translucentNormal;
		vec3 viewMNormal = _cv_aDirtyHackModelMatrix * translucentMicroNormal;

		refraction_uv = REFRACTION_STR * l2_clampScale(0.0, 0.005, ldepth_range) * (viewMNormal.xy - viewVNormal.xy);
		refraction_uv = clamp(refraction_uv, -1.0, 1.0) * 0.5 + 0.5;
	}
#endif

	fragColor[0] = vec4(0.5 + 0.5 * solidNormal, 1.0);
	fragColor[1] = vec4(0.5 + 0.5 * solidTangent, 1.0);
	fragColor[2] = vec4(0.5 + 0.5 * solidMicroNormal, solidPackedPuddle);
	fragColor[3] = vec4(0.5 + 0.5 * translucentNormal, 1.0);
	fragColor[4] = vec4(0.5 + 0.5 * translucentTangent, 1.0);
	fragColor[5] = vec4(0.5 + 0.5 * translucentMicroNormal, translucentPackedPuddle);
	fragColor[6] = vec4(refraction_uv, 0.0, 1.0);
}
