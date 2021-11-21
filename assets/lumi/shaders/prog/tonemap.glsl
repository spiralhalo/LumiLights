#include frex:shaders/lib/color.glsl
#include lumi:shaders/common/contrast.glsl

/*******************************************************
 *  lumi:shaders/prog/tonemap.glsl
 *******************************************************/

// Narkowicz 2015, "ACES Filmic Tone Mapping Curve"
vec3 acesNarkowicz(vec3 x) {
	const float a = 2.51;
	const float b = 0.03;
	const float c = 2.43;
	const float d = 0.59;
	const float e = 0.14;
	return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

vec3 inverse_acesNarkowicz(vec3 x) {
	const float a = 2.51;
	const float b = 0.03;
	const float c = 2.43;
	const float d = 0.59;
	const float e = 0.14;
	return (-0.59 * x + 0.03 - sqrt(-1.0127 * x*x + 1.3702 * x + 0.0009)) / (2.0 * (2.43*x - 2.51));
}

vec3 acesHillModified(vec3 x) {
	const float exposure_bias = 2.0;
	return frx_toneMap(x * exposure_bias);
}

vec3 Hable_Fit(vec3 x) {
	const float A = 0.15; //Shoulder Strength
	const float B = 0.50; //Linear Strength
	const float C = 0.10; //Linear Angle
	const float D = 0.20; //Toe Strength
	const float E = 0.02; //Toe Numerator
	const float F = 0.30; // Toe Denominator
	return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

vec3 Hable(vec3 x) {
	const float W = 11.2; // Whitepoint
	return Hable_Fit(x) / Hable_Fit(vec3(W));
}

vec3 inverse_Hable_Fit(vec3 x) {
	const float A = 0.15; //Shoulder Strength
	const float B = 0.50; //Linear Strength
	const float C = 0.10; //Linear Angle
	const float D = 0.20; //Toe Strength
	const float E = 0.02; //Toe Numerator
	const float F = 0.30; // Toe Denominator
	return (sqrt((vec3(4.0) * x - 4.0 * x * x) * A * D * F * F * F + (-4.0 * x * A * D * E + B * B * C * C - 2.0 * x * B * B * C + x * x * B * B) * F * F + (2.0 * x * B * B - 2.0 * B * B * C) * E * F + B * B * E * E) + (B * C - x * B) * F - B * E) / ((2.0 * x - 2.0) * A * F + 2.0 * A * E);
}

vec3 inverse_Hable(vec3 x) {
	return inverse_Hable_Fit(x) ;
}

#define l2_tmo(x) acesNarkowicz(x)
#define l2_inverse_tmo(x) inverse_acesNarkowicz(x)

vec3 ldr_tonemap(vec3 color)
{
	return hdr_toSRGB(l2_tmo(color));
}

vec4 ldr_tonemap(vec4 color)
{
	return vec4(ldr_tonemap(color.rgb), color.a);
}

vec3 hdr_inverseTonemap(vec3 color)
{
	return l2_inverse_tmo(hdr_fromGamma(color));
}

vec4 hdr_inverseTonemap(vec4 color)
{
	return vec4(hdr_inverseTonemap(color.rgb), color.a);
}
