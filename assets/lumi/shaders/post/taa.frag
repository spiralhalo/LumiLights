#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/lib/taa.glsl
#include lumi:shaders/lib/taa_velocity.glsl

/******************************************************
 *    lumi:shaders/post/taa.frag                      *
 ******************************************************/

uniform sampler2D u_current;
uniform sampler2D u_history0;
uniform sampler2D u_depthCurrent;

in vec2 v_invSize;

out vec4 fragColor;

void main()
{
#if defined(TAA_ENABLED) && TAA_DEBUG_RENDER != TAA_DEBUG_RENDER_OFF
    #if TAA_DEBUG_RENDER == TAA_DEBUG_RENDER_DEPTH
        fragColor = vec4(ldepth(texture(u_depthCurrent, v_texcoord).r));
    #elif TAA_DEBUG_RENDER == TAA_DEBUG_RENDER_FRAMES
        float d = ldepth(texture(u_depthCurrent, v_texcoord).r);
        uint frames = frx_renderFrames() % uint(frxu_size.x); 
        float on = frames == uint(frxu_size.x * v_texcoord.x) ? 1.0 : 0.0;
        fragColor = vec4(on, 0.0, 0.25 + d * 0.5, 1.0);
    #else
        vec2 velocity = 0.5 + calcVelocity(u_depthCurrent, v_texcoord, v_invSize) * 50.0;
        fragColor = vec4(velocity, 0.0, 1.0);
    #endif
#else

    // PROGRESS:
    // [o] velocity buffer works fine
    // [o] camera motion rejection (velocity reprojection) is decent
    // [o] ghosting reduction is decent
    // [o] terrain distortion is reduced by reducing feedback factor when camera moves

    #ifdef TAA_ENABLED
        #if ANTIALIASING == ANTIALIASING_TAA_BLURRY
            float cameraMove = 0.0;
            vec2 velocity = vec2(0.0);
        #else
            float cameraMove = length(frx_cameraPos() - frx_lastCameraPos());
            vec2 velocity = fastVelocity(u_depthCurrent, v_texcoord);
        #endif
        float depth = texture(u_depthCurrent, v_texcoord).r;
        if (depth == 1. && frx_worldFlag(FRX_WORLD_IS_END)) {
            fragColor = texture(u_current, v_texcoord); // the end sky is noisy so don't apply TAA (note: true for vanilla)
        } else {
            fragColor = TAA(u_current, u_history0, u_depthCurrent, v_texcoord, velocity, v_invSize, cameraMove);
        }
    #else
        fragColor = texture(u_current, v_texcoord);
    #endif
#endif
}
