#include lumi:shaders/context/post/header.glsl
#include lumi:shaders/context/post/bloom.glsl
#include frex:shaders/lib/color.glsl
#include frex:shaders/lib/sample.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/api/world.glsl

/******************************************************
  lumi:shaders/post/bloom.frag
******************************************************/

uniform sampler2D u_base;
uniform sampler2D u_bloom;

// Based on approach described by Jorge Jiminez, 2014
// http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
void main()
{
    vec4 base = frx_fromGamma(texture2D(u_base, v_texcoord));
    vec4 bloom = texture2DLod(u_bloom, v_texcoord, 0) * BLOOM_INTENSITY_FLOAT;

    // ramp down the very low end to avoid halo banding
    vec3 cutoff = min(bloom.rgb, vec3(BLOOM_CUTOFF_FLOAT));
    vec3 ramp = cutoff / BLOOM_CUTOFF_FLOAT;
    ramp = ramp * ramp * BLOOM_CUTOFF_FLOAT;
    vec3 color = base.rgb + bloom.rgb - cutoff + ramp;

    gl_FragData[0] = clamp(frx_toGamma(vec4(color, 1.0)), 0.0, 1.0);
}
