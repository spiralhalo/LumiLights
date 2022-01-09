#include lumi:shaders/pass/header.glsl

#include frex:shaders/lib/sample.glsl

/******************************************************
  lumi:shaders/pass/ao1.frag
******************************************************/

uniform sampler2D u_depth;
uniform sampler2D u_ao;

out float ao_value;

// float sample13(sampler2D tex, vec2 uv, vec2 distance, int lod) {
// 	float dG = texture(u_depth, uv, lod).r;
// 	float dA = abs(texture(u_depth, uv + distance * vec2(-1.0, -1.0), lod).r - dG)	< 0.01 ? 0.0 : 1.0;
// 	float dB = abs(texture(u_depth, uv + distance * vec2(0.0, -1.0), lod).r - dG)	< 0.01 ? 0.0 : 1.0;
// 	float dC = abs(texture(u_depth, uv + distance * vec2(1.0, -1.0), lod).r - dG)	< 0.01 ? 0.0 : 1.0;
// 	float dD = abs(texture(u_depth, uv + distance * vec2(-0.5, -0.5), lod).r - dG)	< 0.01 ? 0.0 : 1.0;
// 	float dE = abs(texture(u_depth, uv + distance * vec2(0.5, -0.5), lod).r - dG)	< 0.01 ? 0.0 : 1.0;
// 	float dF = abs(texture(u_depth, uv + distance * vec2(-1.0, 0.0), lod).r - dG)	< 0.01 ? 0.0 : 1.0;
// 	float dH = abs(texture(u_depth, uv + distance * vec2(1.0, 0.0), lod).r - dG)	< 0.01 ? 0.0 : 1.0;
// 	float dI = abs(texture(u_depth, uv + distance * vec2(-0.5, 0.5), lod).r - dG)	< 0.01 ? 0.0 : 1.0;
// 	float dJ = abs(texture(u_depth, uv + distance * vec2(0.5, 0.5), lod).r - dG)	< 0.01 ? 0.0 : 1.0;
// 	float dK = abs(texture(u_depth, uv + distance * vec2(-1.0, 1.0), lod).r - dG)	< 0.01 ? 0.0 : 1.0;
// 	float dL = abs(texture(u_depth, uv + distance * vec2(0.0, 1.0), lod).r - dG)	< 0.01 ? 0.0 : 1.0;
// 	float dM = abs(texture(u_depth, uv + distance * vec2(1.0, 1.0), lod).r - dG)	< 0.01 ? 0.0 : 1.0;

// 	float g = textureLod(tex, uv, lod).r;
// 	float a = max(textureLod(tex, uv + distance * vec2(-1.0, -1.0), lod).r, dA);
// 	float b = max(textureLod(tex, uv + distance * vec2(0.0, -1.0), lod).r, dB);
// 	float c = max(textureLod(tex, uv + distance * vec2(1.0, -1.0), lod).r, dC);
// 	float d = max(textureLod(tex, uv + distance * vec2(-0.5, -0.5), lod).r, dD);
// 	float e = max(textureLod(tex, uv + distance * vec2(0.5, -0.5), lod).r, dE);
// 	float f = max(textureLod(tex, uv + distance * vec2(-1.0, 0.0), lod).r, dF);
// 	float h = max(textureLod(tex, uv + distance * vec2(1.0, 0.0), lod).r, dH);
// 	float i = max(textureLod(tex, uv + distance * vec2(-0.5, 0.5), lod).r, dI);
// 	float j = max(textureLod(tex, uv + distance * vec2(0.5, 0.5), lod).r, dJ);
// 	float k = max(textureLod(tex, uv + distance * vec2(-1.0, 1.0), lod).r, dK);
// 	float l = max(textureLod(tex, uv + distance * vec2(0.0, 1.0), lod).r, dL);
// 	float m = max(textureLod(tex, uv + distance * vec2(1.0, 1.0), lod).r, dM);

// 	vec2 div = vec2(0.5, 0.125);

// 	float o = (d + e + i + j) * div.x * (1.0 / (4.0 - dD - dE - dI - dJ));
// 	o += (a + b + g + f) * div.y * (1.0 / (4.0 - dA - dB - 0.0 - dF));
// 	o += (b + c + h + g) * div.y * (1.0 / (4.0 - dB - dC - dH - 0.0));
// 	o += (f + g + l + k) * div.y * (1.0 / (4.0 - dF - 0.0 - dL - dK));
// 	o += (g + h + m + l) * div.y * (1.0 / (4.0 - 0.0 - dH - dM - dL));

// 	return o;
// }

float sample13(sampler2D tex, vec2 uv, vec2 distance, int lod) {
	float a = textureLod(tex, uv + distance * vec2(-1.0, -1.0), lod).r;
	float b = textureLod(tex, uv + distance * vec2(0.0, -1.0), lod).r;
	float c = textureLod(tex, uv + distance * vec2(1.0, -1.0), lod).r;
	float d = textureLod(tex, uv + distance * vec2(-0.5, -0.5), lod).r;
	float e = textureLod(tex, uv + distance * vec2(0.5, -0.5), lod).r;
	float f = textureLod(tex, uv + distance * vec2(-1.0, 0.0), lod).r;
	float g = textureLod(tex, uv, lod).r;
	float h = textureLod(tex, uv + distance * vec2(1.0, 0.0), lod).r;
	float i = textureLod(tex, uv + distance * vec2(-0.5, 0.5), lod).r;
	float j = textureLod(tex, uv + distance * vec2(0.5, 0.5), lod).r;
	float k = textureLod(tex, uv + distance * vec2(-1.0, 1.0), lod).r;
	float l = textureLod(tex, uv + distance * vec2(0.0, 1.0), lod).r;
	float m = textureLod(tex, uv + distance * vec2(1.0, 1.0), lod).r;

	vec2 div = (1.0 / 4.0) * vec2(0.5, 0.125);

	float o = (d + e + i + j) * div.x;
	o += (a + b + g + f) * div.y;
	o += (b + c + h + g) * div.y;
	o += (f + g + l + k) * div.y;
	o += (g + h + m + l) * div.y;

	return o;
}


void main()
{
	ao_value = sample13(u_ao, v_texcoord, v_invSize, max(0, frxu_lod - 1));
	// 	vec4 prior = frxu_lod == 3 ? vec4(0.0) : textureLod(u_ao_up, v_texcoord, frxu_lod + 1);
	// 	vec4 tent = frx_sampleTent(u_ao, v_texcoord, vec2(0.1) / frxu_size, frxu_lod + 1);
	// 	ao_value = prior.r + tent.r;
	// 	ao_value *= 0.5;
}
