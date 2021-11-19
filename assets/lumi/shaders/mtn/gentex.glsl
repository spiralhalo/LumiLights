#include lumi:shaders/pass/header.glsl

#include frex:shaders/lib/noise/noise2d.glsl

const float TEXSIZE = 1024;

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
const float CLOUD_TEXTURE_ZOOM = 0.25;

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
		noiseVal += multiplier * (snoise((cloudCoord * 0.015) * noisePos));
		sum += multiplier;
		multiplier *= 0.6;
	}
	noiseVal /= sum;

	return noiseVal * 0.5 + 0.5;// l2_clampScale(0.35 * (1.0 - rainFactor), 1.0, noiseVal);
}

void main()
{
	// vec2 texcoordX1 = v_texcoord.x < 0.5 ? v_texcoord : vec2(1.0 - v_texcoord.x, v_texcoord.y);
	// float cloudX1 = genClouds(texcoordX1);

	// vec2 v_texcoordX2 = fract(v_texcoord + vec2(0.25, 0.0));
	// vec2 texcoordX2 = v_texcoordX2.x > 0.5 ? v_texcoordX2 : vec2(1.0 - v_texcoordX2.x, v_texcoordX2.y);
	// float cloudX2 = genClouds(texcoordX2);

	
	// vec2 texcoordY1 = v_texcoord.y < 0.5 ? v_texcoord : vec2(v_texcoord.x, 1.0 - v_texcoord.y);
	// float cloudY1 = genClouds(texcoordY1);

	// vec2 v_texcoordY2 = fract(v_texcoord + vec2(0.0, 0.25));
	// vec2 texcoordY2 = v_texcoordY2.y > 0.5 ? v_texcoordY2 : vec2(v_texcoordY2.x, 1.0 - v_texcoordY2.y);
	// float cloudY2 = genClouds(texcoordY2);

	// vec2 edge = abs(v_texcoord - 0.5);
	// edge.x = l2_clampScale(0.5, 0.4, edge.x);
	// edge.y = l2_clampScale(0.5, 0.4, edge.y);
	// float cloud = (cloudX1 + cloudX2) * edge.y + (cloudY1 + cloudY2) * edge.x;

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

	fragColor = vec4(cloud);
}
#endif
