#include lumi:shaders/pipeline/post/common.glsl
#include lumi:shaders/pipeline/post/layers.glsl

/*******************************************************
 *  lumi:shaders/pipeline/post/closest.frag            *
 *******************************************************/

void main()
{
    float current_depth;
    float closest_depth = 1.0;
    int closest;
    for (int i = 0; i < NUM_LAYERS; i++) {
        current_depth = depth(i, v_texcoord);
        if (current_depth < closest_depth) {
            closest = i;
            closest_depth = current_depth;
        }
    }
    gl_FragData[0] = vec4(0.0, 0.0, 0.0, i2f(closest));
}
