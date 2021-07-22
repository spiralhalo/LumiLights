#include lumi:shaders/post/common/header.glsl

#include frex:shaders/lib/color.glsl
#include frex:shaders/lib/sample.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/post/common/bloom.glsl
#include lumi:shaders/lib/util.glsl

/******************************************************
  lumi:shaders/post/bloom.frag
******************************************************/

uniform sampler2D u_base;
uniform sampler2D u_bloom;

out vec4 fragColor;

// Based on approach described by Jorge Jiminez, 2014
// http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
void main()
{
	vec4 base = texture(u_base, v_texcoord);
	vec4 bloom = textureLod(u_bloom, v_texcoord, 0) * BLOOM_INTENSITY_FLOAT;

	vec3 color = hdr_fromGamma(base.rgb) + bloom.rgb;

	fragColor = vec4(hdr_toSRGB(color), 1.0);
}
