#include lumi:shaders/pipeline/post/common.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/color.glsl
#include lumi:shaders/lib/tonemap.glsl

/******************************************************
  lumi:shaders/pipeline/post/composite.frag
******************************************************/

uniform sampler2D u_hdr_solid;
uniform sampler2D u_solid_depth;
uniform sampler2D u_hdr_translucent;
uniform sampler2D u_translucent_depth;
uniform sampler2D u_clouds;
uniform sampler2D u_clouds_depth;

vec4 blur13(sampler2D image, vec2 uv, vec2 resolution, vec2 direction) {
  vec4 color = vec4(0.0);
  vec2 off1 = vec2(1.411764705882353) * direction;
  vec2 off2 = vec2(3.2941176470588234) * direction;
  vec2 off3 = vec2(5.176470588235294) * direction;
  color += texture2D(image, uv) * 0.1964825501511404;
  color += texture2D(image, uv + (off1 / resolution)) * 0.2969069646728344;
  color += texture2D(image, uv - (off1 / resolution)) * 0.2969069646728344;
  color += texture2D(image, uv + (off2 / resolution)) * 0.09447039785044732;
  color += texture2D(image, uv - (off2 / resolution)) * 0.09447039785044732;
  color += texture2D(image, uv + (off3 / resolution)) * 0.010381362401148057;
  color += texture2D(image, uv - (off3 / resolution)) * 0.010381362401148057;
  return color;
}

void main() {
    vec4 solid = texture2D(u_hdr_solid, v_texcoord);
    if (solid.a > 0.01) {
        solid = ldr_tonemap(solid);
    }
    float depth_solid = texture2D(u_solid_depth, v_texcoord).r;
    
    vec4 translucent = ldr_tonemap(texture2D(u_hdr_translucent, v_texcoord));
    float depth_translucent = texture2D(u_translucent_depth, v_texcoord).r;
 
    vec4 c;

    float depth;
    float clouds_depth = texture2D(u_clouds_depth, v_texcoord).r;
    if (clouds_depth <= depth_solid) {
        vec4 clouds = blur13(u_clouds, v_texcoord, frxu_size, vec2(1.0, 0.0));
        clouds.rgb = max(clouds.rgb * 1.4, v_skycolor);
        c.rgb = clouds.rgb * clouds.a + solid.rgb * max(0.0, 1.0 - clouds.a);
        depth = clouds_depth;
    } else {
        c.rgb = solid.rgb;
        depth = depth_solid;
    }

    if (depth < depth_translucent) {
        c.rgb = c.rgb;
    } else {
        c.rgb = translucent.rgb + c.rgb * max(0.0, 1.0 - translucent.a);
    }
    
    c.a = 1.0; // frx_luminance(c.rgb); // FXAA 3 would need this
    gl_FragData[0] = c;
}


