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
uniform sampler2D u_solid_depth;

void main()
{
    // TODO: elaborate hand bloom blending? (requires more image = more vram)
    float t = texture2D(u_solid_depth, v_texcoord).r == 1.0
        ? texture2D(u_emissive_translucent, v_texcoord).r
        : 0.0;
    float e = max(texture2D(u_emissive, v_texcoord).r, t);
    vec4 c = frx_fromGamma(texture2D(u_base, v_texcoord));
    gl_FragData[0] = vec4(c.rgb * e, e);
}
