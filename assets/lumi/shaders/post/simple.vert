#include lumi:shaders/post/common/header.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/simple.vert                      *
 *******************************************************/

vert_out vec2 v_invSize;

void main()
{
    v_invSize = 1.0 / frxu_size;
    basicFrameSetup();
}
