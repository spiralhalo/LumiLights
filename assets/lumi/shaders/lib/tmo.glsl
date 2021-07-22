#include frex:shaders/lib/color.glsl

/**********************************************************
 *  lumi:shaders/lib/tmo.glsl
 **********************************************************/

// Narkowicz 2015, "ACES Filmic Tone Mapping Curve"
vec3 acesNarkowicz(vec3 x) {
  const float a = 2.51;
  const float b = 0.03;
  const float c = 2.43;
  const float d = 0.59;
  const float e = 0.14;
  return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

vec3 acesHillModified(vec3 x) {
	return frx_toneMap(x * 2.);
}

vec3 ldr_reinhardJodieTonemap(in vec3 v) {
	float l = frx_luminance(v);
	vec3 tv = v / (1.0f + v);
	return mix(v / (1.0f + l), tv, tv);
}

vec3 ldr_vibrantTonemap(in vec3 hdrColor){
	return hdrColor / (frx_luminance(hdrColor) + vec3(1.0));
}

vec3 hable_tonemap_partial(vec3 x)
{
	float A = 0.15f;
	float B = 0.50f;
	float C = 0.10f;
	float D = 0.20f;
	float E = 0.02f;
	float F = 0.30f;
	return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

vec3 hable_filmic(vec3 v)
{
	float exposure_bias = 2.0f;
	vec3 curr = hable_tonemap_partial(v * exposure_bias);

	vec3 W = vec3(11.2f);
	vec3 white_scale = vec3(1.0f) / hable_tonemap_partial(W);
	return curr * white_scale;
}
