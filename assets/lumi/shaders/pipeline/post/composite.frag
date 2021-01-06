#include lumi:shaders/pipeline/post/common.glsl
#include lumi:shaders/lib/tonemap.glsl

/******************************************************
  lumi:shaders/pipeline/post/composite.frag
******************************************************/

// taken from Canvas code
// a slightly cleaned up version of Mojang's transparency.fsh
uniform sampler2D u_hdr_solid;
uniform sampler2D u_solid_depth;
uniform sampler2D u_hdr_translucent;
uniform sampler2D u_translucent_depth;

void main() {
    vec4 solid = texture2D(u_hdr_solid, v_texcoord);
    if (solid.a > 0.01) {
        solid = ldr_tonemap(solid);
    }
    float depth_solid = texture2D(u_solid_depth, v_texcoord).r;
    
    vec4 translucent = ldr_tonemap(texture2D(u_hdr_translucent, v_texcoord));
    float depth_translucent = texture2D(u_translucent_depth, v_texcoord).r;
 
    if (depth_solid < depth_translucent) {
        gl_FragData[0] = solid;
    } else {
        gl_FragData[0] = translucent + solid * max(0.0, 1.0 - translucent.a);
    }
}


