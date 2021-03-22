#include lumi:shaders/context/post/header.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/context/global/userconfig.glsl

/******************************************************
 *    lumi:shaders/post/taa.frag                      *
 ******************************************************/

uniform sampler2D u_current;
uniform sampler2D u_history0;
uniform sampler2D u_depthCurrent;
uniform sampler2D u_depthHistory0; //unused, can be removed
uniform sampler2D u_velocity;

#define currentColorTex u_current
#define previousColorTex u_history0
#define currentDepthTex u_depthCurrent
#define previousDepthTex u_depthHistory0
#define velocityTex u_velocity
#define resolution frxu_size

#define feedbackFactor 0.9
#define velocityRejectionScale 100.0
#define maxDepthFalloff 1.0

#include lumi:shaders/lib/taa.glsl

void main()
{
    #if ANTIALIASING == ANTIALIASING_TAA_DEBUG
        gl_FragData[0] = 0.5 + texture2D(u_velocity, v_texcoord) * 50.0;
    #else

    // PROGRESS:
    // [o] velocity buffer works fine
    // [o] camera motion rejection (velocity reprojection) is decent
    // [o] ghosting reduction is decent
    // [~] terrain distortion is reduced by using clean matrices and can be controlled with velocityRejectionScale

    #ifdef TAA_ENABLED
        gl_FragData[0] = TAA();
    #else
        gl_FragData[0] = texture2D(u_current, v_texcoord);
    #endif
    #endif
}
