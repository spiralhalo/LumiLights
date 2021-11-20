#include lumi:shaders/pass/header.glsl

#include frex:shaders/lib/noise/noise2d.glsl
#include lumi:shaders/common/texconst.glsl

const float TEXSIZE = CLOUDS_TEXSIZE;

#ifdef VERTEX_SHADER

void main()
{
	basicFrameSetup();

	vec2 scale = vec2(TEXSIZE) / frxu_size;

	gl_Position.xy *= scale;
}
#else
const vec2 OFFSET = vec2(10.);
const float TEXTURE_RADIUS = TEXSIZE / 2.;

out vec4 fragColor;

vec2 uv2worldXz(vec2 uv)
{
	vec2 ndc = uv * 2.0 - 1.0;
	return ndc * TEXTURE_RADIUS;
}

float genClouds(vec2 texcoord)
{
	vec2 worldXz = uv2worldXz(texcoord + OFFSET);

	vec2 cloudCoord = worldXz;
	cloudCoord *= CLOUD_TEXTURE_ZOOM;

	const int ITERATIONS = 7;
	float noiseVal = 0.0;
	float sum = 0.0;
	float multiplier = 1.0;
	for (int i = 0; i < ITERATIONS; i++) {
		vec2 noisePos = vec2((1 + i * 0.1)/multiplier);
		noiseVal += multiplier * abs(snoise((cloudCoord * 0.015) * noisePos));
		sum += multiplier;
		multiplier *= 0.6;
	}
	noiseVal /= sum;

	return noiseVal;// l2_clampScale(0.35 * (1.0 - rainFactor), 1.0, noiseVal);
}

vec4 genCloudsTexture1()
{
	vec2 texcoordX1 = v_texcoord.x < 0.5 ? v_texcoord : vec2(1.0 - v_texcoord.x, v_texcoord.y);
	float cloudX1 = genClouds(texcoordX1);

	vec2 v_texcoordX2 = fract(v_texcoord + vec2(0.25, 0.0));
	vec2 texcoordX2 = v_texcoordX2.x > 0.5 ? v_texcoordX2 : vec2(1.0 - v_texcoordX2.x, v_texcoordX2.y);
	float cloudX2 = genClouds(texcoordX2);

	
	vec2 texcoordY1 = v_texcoord.y < 0.5 ? v_texcoord : vec2(v_texcoord.x, 1.0 - v_texcoord.y);
	float cloudY1 = genClouds(texcoordY1);

	vec2 v_texcoordY2 = fract(v_texcoord + vec2(0.0, 0.25));
	vec2 texcoordY2 = v_texcoordY2.y > 0.5 ? v_texcoordY2 : vec2(v_texcoordY2.x, 1.0 - v_texcoordY2.y);
	float cloudY2 = genClouds(texcoordY2);

	vec2 edge = abs(v_texcoord - 0.5);
	edge.x = l2_clampScale(0.5, 0.4, edge.x);
	edge.y = l2_clampScale(0.5, 0.4, edge.y);
	float cloud = (cloudX1 + cloudX2) * edge.y + (cloudY1 + cloudY2) * edge.x;

	return vec4(cloud);
}

vec4 genCloudsTexture2()
{
	float cloud1 = genClouds(v_texcoord);
	float cloudX = genClouds(vec2(1.0 - v_texcoord.x, v_texcoord.y - (1.0 - v_texcoord.x) * 0.4));
	float cloudY = genClouds(vec2(v_texcoord.x - (1.0 - v_texcoord.y) * 0.4, 1.0 - v_texcoord.y));
	float cloudXY = genClouds(1.0 - v_texcoord);

	vec2 edge = v_texcoord - 0.5;
	edge.x = l2_clampScale(0.5, 0.4, edge.x);
	edge.y = l2_clampScale(0.5, 0.4, edge.y);
	float eF = edge.x * edge.y;

	cloudX *= (1.0 - edge.x) * edge.y;
	cloudY *= (1.0 - edge.y) * edge.x;
	cloud1 *= eF;
	cloudXY *= (1.0 - edge.x) * (1.0 - edge.y);

	float cloud = cloud1 + cloudX + cloudY + cloudXY;

	return vec4(cloud);
}

float ww_noise(vec2 pos, float stretch, int iterations, float startMult)
{
	vec2 hh  = vec2(pos.x, pos.y * stretch);
	float noiseVal = 0.0;
	float sum = 0.0;
	float multiplier = startMult;
	for (int i = 0; i < iterations; i++) {
		vec2 noisePos = hh / multiplier;
		noiseVal += multiplier * snoise(noisePos);
		sum += multiplier;
		multiplier *= 0.6;
	}
	noiseVal /= sum;
	return noiseVal * 0.5 + 0.5;
	// vec2 hh  = vec2(pos.x, pos.y * stretch);
	// vec2 pp1 = hh;
	// vec2 pp2 = hh * 5.0;
	// float xx1 = (snoise(pp1) * 0.5 + 0.5) * 0.9;
	// float xx2 = (snoise(pp2) * 0.5 + 0.5) * 0.1;
	// return xx1 + xx2;
}

const float WATER_BLOCK_RES = 128.0;

float genWaterNoise(vec2 texcoord, float stretch, int iterations, float startMult) 
{
	vec2 worldXz = uv2worldXz(texcoord + OFFSET);

	return ww_noise(worldXz / WATER_BLOCK_RES, stretch, iterations, startMult);
}

vec4 genWaterTexture1()
{
	return vec4(genWaterNoise(v_texcoord, 1.2, 7, 1.0));
}

float genWaterTexture2Sub(int iter1, float mult1)
{
	const float stretch1 = 1.5;

	float water1 = genWaterNoise(v_texcoord, stretch1, iter1, mult1);
	float waterX = genWaterNoise(vec2(1.0 - v_texcoord.x, v_texcoord.y), stretch1, iter1, mult1);
	float waterY = genWaterNoise(vec2(v_texcoord.x, 1.0 - v_texcoord.y), stretch1, iter1, mult1);
	float waterXY = genWaterNoise(1.0 - v_texcoord, stretch1, iter1, mult1);

	vec2 edge = v_texcoord - 0.5;
	edge.x = l2_clampScale(0.5, 0.4, edge.x);
	edge.y = l2_clampScale(0.5, 0.4, edge.y);
	float eF = edge.x * edge.y;

	waterX *= (1.0 - edge.x) * edge.y;
	waterY *= (1.0 - edge.y) * edge.x;
	water1 *= eF;
	waterXY *= (1.0 - edge.x) * (1.0 - edge.y);

	float water = water1 + waterX + waterY + waterXY;

	return water;
}

vec4 genWaterTexture2()
{
	vec4 result = vec4(0.0);
	result.r = genWaterTexture2Sub(3, 1.0);
	result.g = genWaterTexture2Sub(3, 0.5);
	return result;
}

void main()
{
	vec4 generated = genCloudsTexture2();

	fragColor = vec4(generated);
}
#endif
