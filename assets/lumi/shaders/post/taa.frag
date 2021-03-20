#include lumi:shaders/context/post/header.glsl
#include lumi:shaders/lib/util.glsl

/******************************************************
 *    lumi:shaders/post/taa.frag                      *
 ******************************************************/

uniform sampler2D u_current;
uniform sampler2D u_history0;
uniform sampler2D u_depthCurrent;
uniform sampler2D u_depthHistory0;
uniform sampler2D u_velocity;

#define currentColorTex u_current
#define previousColorTex u_history0
#define currentDepthTex u_depthCurrent
#define previousDepthTex u_depthHistory0
#define velocityTex u_velocity
#define resolution frxu_size

#define feedbackFactor 0.5
#define velocityScale 1.0
#define maxDepthFalloff 1.0

#include lumi:shaders/lib/taa.glsl

void main()
{
    // gl_FragData[0] = texture2D(u_velocity, v_texcoord);

    // PROGRESS:
    // [o] velocity buffer works fine
    // [o] camera motion rejection (velocity reprojection) is decent
    // [o] ghosting reduction is decent
    // [x] there was a weird distortion while moving (??)

    gl_FragData[0] = TAA();
}
