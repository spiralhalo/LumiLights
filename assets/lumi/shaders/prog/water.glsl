#include lumi:shaders/common/texconst.glsl

/*******************************************************
 *  lumi:shaders/prog/water.glsl
 *******************************************************/

#ifndef VERTEX_SHADER
float textureWater(sampler2D natureTexture, vec4 uvuv, vec2 uvMove)
{
	uvuv *= WATER_SAMPLING_ZOOM * WATER_BLOCK_RES / WATER_TEXSIZE;

	float A = texture(natureTexture, uvuv.xy + uvMove).g;
	float B = texture(natureTexture, uvuv.zw + uvMove).b;

	return A * 0.75 + B * 0.25;
}

#ifdef POST_SHADER
bool decideUnderwater(float depth, float dTrans, bool transIsWater, bool translucent) {
	if (frx_cameraInWater == 1) {
		if (translucent) {
			return true;
		} else {
			return dTrans >= depth;
		}
	} else {
		return dTrans < depth && transIsWater; 
	}
}

vec2 refractSolidUV(sampler2DArray normalBuffer, sampler2D solidDepthBuffer, float dSolid, float dTrans) {
#ifdef REFRACTION_EFFECT
	if (dTrans < dSolid) {
		const float refractStr = .1;

		float ldepth_range = ldepth(dSolid) - ldepth(dTrans);

		vec3 viewVNormal = frx_normalModelMatrix * (texture(normalBuffer, vec3(v_texcoord, ID_TRANS_NORM)).xyz);
		vec3 viewMNormal = frx_normalModelMatrix * (texture(normalBuffer, vec3(v_texcoord, ID_TRANS_MNORM)).xyz);

		vec2 refractUV = refractStr * l2_clampScale(0.0, 0.005, ldepth_range) * (viewMNormal.xy - viewVNormal.xy);
		refractUV = clamp(v_texcoord + refractUV, 0.0, 1.0);

		float newDepth = texture(solidDepthBuffer, refractUV).r;

		if (newDepth < dTrans) refractUV = v_texcoord;

		return refractUV;
	} else {
		return v_texcoord;
	}
#else
	return v_texcoord;
#endif
}

float caustics(sampler2D natureTexture, vec3 worldPos, float vertexNormaly)
{
	float yMove = 1.0 - vertexNormaly;
	vec2 moveA = vec2(1. + yMove, 1. - yMove) * frx_renderSeconds;
	vec2 moveB = vec2(1. + yMove, -1. - yMove) * frx_renderSeconds;

	vec2 uv = worldPos.xz + vec2(-1.0, 1.0) * worldPos.y;

	vec4 uvuv = vec4(uv + moveA, uv + moveB);

	float e = textureWater(natureTexture, uvuv, vec2(0.0));
		  e = smoothstep(-1.0, 1.0, e);

	return e;
}

void foamPreprocess(inout vec4 albedo, sampler2D natureTexture, vec3 worldPos, float vertexNormaly, float dSolid, float dTrans)
{
	vec2 moveA = vec2(1., 1.) * frx_renderSeconds;
	vec2 moveB = vec2(1., -1.) * frx_renderSeconds;

	vec2 uv = worldPos.xz + vec2(-1.0, 1.0) * worldPos.y;
	uv *= vec2(4.0);

	vec4 uvuv = vec4(uv + moveA, uv + moveB);

	float tex = textureWater(natureTexture, uvuv, vec2(0.0));
	tex = smoothstep(0.3, 1.0, tex);

	vec4 foamAlbedo = vec4(1.0);

	// float viewCorrection = pow(viewVertexNormal.y, 5.0); // kinda breaks things near the camera
	float dZ = (ldepth(dSolid) - ldepth(dTrans)) * frx_viewDistance;
	float foam = l2_clampScale(0.8, 0.0, dZ);

	foam = mix(tex, 1.0, pow(foam, 10.0)) * foam;
	foam *= 0.6;
	foam *= abs(vertexNormaly);

	albedo = mix(albedo, vec4(1.0), foam);
}
#else

float sampleWaterNoise(sampler2D natureTexture, vec3 worldPos, vec2 uvMove, vec3 absVertexNormal)
{
	vec3 yMove = 1.0 - absVertexNormal;
	vec2 moveA = vec2(1. + yMove.y * 5., 1. - yMove.y) * frx_renderSeconds;
	vec2 moveB = vec2(1. + yMove.y * 5., -1. + yMove.y) * frx_renderSeconds;

	vec2 uv = worldPos.xz * absVertexNormal.y + yMove.y * vec2(worldPos.y, worldPos.x * yMove.x + worldPos.z * yMove.z);

	vec4 uvuv = vec4(uv + moveA, uv + moveB);

	return textureWater(natureTexture, uvuv, uvMove);
}

vec3 sampleWaterNormal(sampler2D natureTexture, vec3 fragWorldPos, vec3 absVertexNormal)
{
	const vec3 normal = vec3(0.0, 0.0, 1.0);
	const vec3 tangent = vec3(1.0, 0.0, 0.0);
	const vec3 bitangent = vec3(0.0, 1.0, 0.0);

	const float slope = 1. / 32.;
	const float oneBlock = WATER_BLOCK_RES / WATER_TEXSIZE;
	const float amplitude = 0.02;

	vec3 tmove = tangent * slope;
	vec3 bmove = bitangent * slope;
	vec2 uvMove = vec2(0.0, oneBlock * slope);

	vec3 origin = amplitude * sampleWaterNoise(natureTexture, fragWorldPos, uvMove.xx, absVertexNormal) * normal;
	vec3 tside  = amplitude * sampleWaterNoise(natureTexture, fragWorldPos, uvMove.yx, absVertexNormal) * normal + tmove - origin;
	vec3 bside  = amplitude * sampleWaterNoise(natureTexture, fragWorldPos, uvMove.xy, absVertexNormal) * normal + bmove - origin;

	vec3 eyePos = fragWorldPos - frx_cameraPos;
	float farBlend = l2_clampScale(0., 1024. * 1024., dot(eyePos, eyePos));
	vec3 noisyNormal = normalize(mix(cross(tside, bside), normal, farBlend));

	return noisyNormal;
}
#endif
#endif
