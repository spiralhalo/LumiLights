#include lumi:shaders/common/contrast.glsl
#include lumi:shaders/lib/tmo.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/prog/tonemap.glsl
 *******************************************************/

uniform sampler2D u_exposure;

float exposureCompensation() {
	return texture(u_exposure, vec2(0.0)).r;
}

#ifdef POST_SHADER

vec3 ldr_tonemap3noGamma(vec3 a)
{
	float exposure = 1.0;

#ifdef HIGH_CONTRAST_ENABLED
	float eyeBrightness = exposureCompensation();
	exposure = getExposure(eyeBrightness);
#endif

	vec3 c = a.rgb;
		 c = acesNarkowicz(c * exposure);
		 c = clamp(c, 0.0, 1.0); // In the past ACES requires clamping for some reason

	return c;
}

vec3 ldr_tonemap3(vec3 a)
{
	float brightness = min(1.5, frx_viewBrightness);
	float viewGamma  = hdr_gamma + brightness;

	vec3 c = ldr_tonemap3noGamma(a);
		 c = pow(c, vec3(1.0 / viewGamma));

	return c;
}

vec4 ldr_tonemap(vec4 a)
{
	vec3 c = ldr_tonemap3(a.rgb);

	return vec4(c, a.a);
}

#endif
