#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/post/common/bloom.glsl
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

#ifndef USING_OLD_OPENGL
out vec4[1] fragColor;
#endif

void main()
{
    // Couldn't unjitter bloom :-?
    // vec2 unjitteredTexcoord = v_texcoord - taa_jitter(v_invSize) * 0.5;
    
    // TODO: elaborate hand bloom blending? (requires more image = more vram)
    float t = texture(u_solid_depth, v_texcoord).r == 1.0
        ? texture(u_emissive_translucent, v_texcoord).r
        : 0.0;
    float e = max(texture(u_emissive, v_texcoord).r, t);
    vec4 c = frx_fromGamma(texture(u_base, v_texcoord));
    fragColor[0] = vec4(c.rgb * e, e);
}
