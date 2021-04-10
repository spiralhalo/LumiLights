#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/lib/taa.glsl

/******************************************************
 *    lumi:shaders/post/taa.frag                      *
 ******************************************************/

uniform sampler2D u_current;
uniform sampler2D u_history0;
uniform sampler2D u_depthCurrent;

varying vec2 v_invSize;

vec2 calc_velocity() {
    float closestDepth = texture2D(u_depthCurrent, GetClosestUV(u_depthCurrent, v_texcoord, v_invSize)).r;
    vec4 currentModelPos = frx_inverseViewProjectionMatrix() * vec4(v_texcoord * 2.0 - 1.0, closestDepth * 2.0 - 1.0, 1.0);
    currentModelPos.xyz /= currentModelPos.w;
    currentModelPos.w = 1.0;

    #if ANTIALIASING == ANTIALIASING_TAA_BLURRY
        vec4 prevModelPos = currentModelPos;
    #else
        // This produces correct velocity?
        vec4 cameraToLastCamera = vec4(frx_cameraPos() - frx_lastCameraPos(), 0.0);
        vec4 prevModelPos = currentModelPos + cameraToLastCamera;
    #endif

    prevModelPos = frx_lastViewProjectionMatrix() * prevModelPos;
    prevModelPos.xy /= prevModelPos.w;
    vec2 prevPos = (prevModelPos.xy * 0.5 + 0.5);

    return vec2(v_texcoord - prevPos);
}

void main()
{
#if defined(TAA_ENABLED) && TAA_DEBUG_RENDER != TAA_DEBUG_RENDER_OFF
    #if TAA_DEBUG_RENDER == TAA_DEBUG_RENDER_DEPTH
        gl_FragData[0] = vec4(ldepth(texture2D(u_depthCurrent, v_texcoord).r));
    #elif TAA_DEBUG_RENDER == TAA_DEBUG_RENDER_FRAMES
        float d = ldepth(texture2D(u_depthCurrent, v_texcoord).r);
        int frames = int(mod(frx_renderFrames(), frxu_size.x)); 
        float on = frames == int(frxu_size.x * v_texcoord.x) ? 1.0 : 0.0;
        gl_FragData[0] = vec4(on, 0.0, 0.25 + d * 0.5, 1.0);
    #else
        vec2 velocity = 0.5 + calc_velocity() * 50.0;
        gl_FragData[0] = vec4(velocity, 0.0, 1.0);
    #endif
#else

    // PROGRESS:
    // [o] velocity buffer works fine
    // [o] camera motion rejection (velocity reprojection) is decent
    // [o] ghosting reduction is decent
    // [o] terrain distortion is reduced by reducing feedback factor when camera moves

    #ifdef TAA_ENABLED
        float cameraMove = length(frx_cameraPos() - frx_lastCameraPos());
        gl_FragData[0] = TAA(u_current, u_history0, u_depthCurrent, v_texcoord, calc_velocity(), v_invSize, cameraMove);
    #else
        gl_FragData[0] = texture2D(u_current, v_texcoord);
    #endif
#endif
}
