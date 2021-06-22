#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/post/common/bloom.glsl
#include frex:shaders/lib/color.glsl
#include frex:shaders/lib/sample.glsl
#include frex:shaders/lib/math.glsl

/******************************************************
  lumi:shaders/post/emissive_color.frag
******************************************************/
uniform sampler2D u_base_composite;
uniform sampler2D u_emissive_solid;
uniform sampler2D u_emissive_composite;
uniform sampler2D u_solid_depth;

#ifndef USING_OLD_OPENGL
out vec4[1] fragColor;
#endif

void main()
{
    // Couldn't unjitter bloom :-?
    // vec2 unjitteredTexcoord = v_texcoord - taa_jitter(v_invSize) * 0.5;

    // TODO: elaborate hand blending? (requires hand alpha)
    float solidDepth = texture(u_solid_depth, v_texcoord).r;
    float e = solidDepth == 1.0 ? texture(u_emissive_composite, v_texcoord).r : texture(u_emissive_solid, v_texcoord).r;
    vec4 c = frx_fromGamma(texture(u_base_composite, v_texcoord));

    fragColor[0] = vec4(c.rgb * e, e);
}
