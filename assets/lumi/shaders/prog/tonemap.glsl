#include lumi:shaders/common/contrast.glsl
#include lumi:shaders/lib/tmo.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/prog/tonemap.glsl
 *******************************************************/

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
