#include lumi:shaders/post/common/header.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/reflection_halfmerge.vert        *
 *******************************************************/

vert_out vec2 v_invSize;

void main()
{
    basicFrameSetup();

#ifdef HALF_REFLECTION_RESOLUTION
    gl_Position.xy -= (gl_Position.xy - vec2(-1., -1.)) * .5;
#else
    gl_Position.xy = vec2(0.);
#endif
    v_invSize = 1.0 / frxu_size;
}
