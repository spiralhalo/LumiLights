#include lumi:shaders/pipeline/post/common.glsl

/******************************************************
  lumi:shaders/pipeline/post/fabulous.frag
******************************************************/

// taken from Canvas code
// a slightly cleaned up version of Mojang's transparency.fsh
uniform sampler2D diffuseColor;
uniform sampler2D diffuseDepth;
uniform sampler2D translucentColor;
uniform sampler2D translucentDepth;

#define NUM_LAYERS 2

vec4 color_layers[NUM_LAYERS];
float depth_layers[NUM_LAYERS];
int active_layers = 0;

void try_insert(vec4 color, float depth) {
    if (color.a == 0.0) {
        return;
    }

    color_layers[active_layers] = color;
    depth_layers[active_layers] = depth;

    int target = active_layers++;
    int probe = target - 1;

    while (target > 0 && depth_layers[target] > depth_layers[probe]) {
        float probeDepth = depth_layers[probe];
        depth_layers[probe] = depth_layers[target];
        depth_layers[target] = probeDepth;

        vec4 probeColor = color_layers[probe];
        color_layers[probe] = color_layers[target];
        color_layers[target] = probeColor;

        target = probe--;
    }
}

vec3 blend(vec3 dst, vec4 src) {
    return (dst * (1.0 - src.a)) + src.rgb;
}

void main() {
    color_layers[0] = vec4(texture2D(diffuseColor, v_texcoord).rgb, 1.0);
    depth_layers[0] = texture2D(diffuseDepth, v_texcoord).r;
    active_layers = 1;

    try_insert(texture2D(translucentColor, v_texcoord), texture2D(translucentDepth, v_texcoord).r);

    vec3 texelAccum = color_layers[0].rgb;

    for (int i = 1; i < active_layers; ++i) {
        texelAccum = blend(texelAccum, color_layers[i]);
    }

    gl_FragData[0] = vec4(texelAccum.rgb, 1.0);
}


