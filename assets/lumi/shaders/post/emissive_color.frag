#include lumi:shaders/context/post/header.glsl
#include lumi:shaders/context/post/bloom.glsl
#include frex:shaders/lib/color.glsl
#include frex:shaders/lib/sample.glsl
#include frex:shaders/lib/math.glsl

/******************************************************
  lumi:shaders/post/emissive_color.frag
******************************************************/
uniform sampler2D u_base;
uniform sampler2D u_emissive;
uniform sampler2D u_emissive_translucent;

void main()
{
    float s = texture2D(u_emissive, v_texcoord).r;
    float e = max(s, texture2D(u_emissive_translucent, v_texcoord).r);
    vec4 c = frx_fromGamma(texture2D(u_base, v_texcoord));
    gl_FragData[0] = vec4(c.rgb * e, e);
}
