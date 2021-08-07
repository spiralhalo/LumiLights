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
uniform sampler2D u_misc_solid;

uniform sampler2D u_normal_translucent0;
uniform sampler2D u_normal_micro_translucent0;
uniform sampler2D u_misc_translucent;
uniform sampler2D u_depth_translucent;

out vec4 fragColor[6];

const float smol_waveSpeed = 1;
const float smol_scale = 1.5;
const float smol_amplitude = 0.01;
const float beeg_waveSpeed = 0.8;
const float beeg_scale = 10.0;
const float beeg_amplitude = 0.25;

void processNormalMap(in vec3 normal, in vec3 tangent, inout vec3 microNormal) {
	// normal map processing requires tangent to be set
	bool useNormalMap = dot(tangent, tangent) > 0.1;

	// TODO: actually apply normal map or whatever
}

void main()
{
	vec3 solidNormal, solidTangent, translucentNormal, translucentTangent;

	unpackNormal(texture(u_normal_solid0, v_texcoord).rgb, solidNormal, solidTangent);
	unpackNormal(texture(u_normal_translucent0, v_texcoord).rgb, translucentNormal, translucentTangent);

	vec3 solidMicroNormal = 2.0 * texture(u_normal_micro_solid0, v_texcoord).rgb - 1.0;
	vec3 translucentMicroNormal = 2.0 * texture(u_normal_micro_translucent0, v_texcoord).rgb - 1.0;

	// TODO: implement when supported
	// processNormalMap(solidNormal, solidTangent, solidMicroNormal);
	// processNormalMap(translucentNormal, translucentTangent, translucentMicroNormal);

	bool translucentIsWater = bit_unpack(texture(u_misc_translucent, v_texcoord).b, 7) == 1.;

	if (translucentIsWater) {
		/* WAVY NORMALS */
		// wave movement doesn't necessarily follow flow direction for the time being
		const float stretch = 1.2;
		float waveSpeed = mix(smol_waveSpeed, beeg_waveSpeed, abs(translucentNormal.y));
		float scale = mix(smol_scale, beeg_scale, abs(translucentNormal.y));
		float amplitude = mix(smol_amplitude, beeg_amplitude, abs(translucentNormal.y));

		float depth = texture(u_depth_translucent, v_texcoord).r;
		vec4 worldPos = frx_inverseViewProjectionMatrix() * vec4(2. * v_texcoord - 1., 2. * depth - 1., 1.);
		worldPos.xyz /= worldPos.w;
		worldPos.xyz += frx_cameraPos();

		vec3 moveSpeed = vec3(0.5, 3.0, -1.0) * (0.5 + 0.5 - translucentNormal * 0.5) * waveSpeed;
		vec3 up = translucentNormal;
		vec3 samplePos = worldPos.xyz;
		vec3 noisyNormal = ww_normals(up, translucentTangent, cross(up, translucentTangent), samplePos, waveSpeed, scale, amplitude, stretch, moveSpeed);

		translucentMicroNormal = noisyNormal;
	}

	// TODO: apply rain normals

	fragColor[0] = vec4(0.5 + 0.5 * solidNormal, 1.0);
	fragColor[1] = vec4(0.5 + 0.5 * solidTangent, 1.0);
	fragColor[2] = vec4(0.5 + 0.5 * solidMicroNormal, 1.0);
	fragColor[3] = vec4(0.5 + 0.5 * translucentNormal, 1.0);
	fragColor[4] = vec4(0.5 + 0.5 * translucentTangent, 1.0);
	fragColor[5] = vec4(0.5 + 0.5 * translucentMicroNormal, 1.0);
}
