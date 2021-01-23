/*******************************************************
 *  lumi:shaders/post/layers.glsl             *
 *******************************************************/

uniform sampler2D diffuseColor;
uniform sampler2D diffuseDepth;
uniform sampler2D translucentColor;
uniform sampler2D translucentDepth;
uniform sampler2D entityColor;
uniform sampler2D entityDepth;
uniform sampler2D particleColor;
uniform sampler2D particleDepth;
uniform sampler2D weatherColor;
uniform sampler2D weatherDepth;
uniform sampler2D cloudsColor;
uniform sampler2D cloudsDepth;

#define NUM_LAYERS 6

// can I even do this ??
sampler2D[] colors[NUM_LAYERS] = sampler2D[](
    diffuseColor,
    translucentColor,
    entityColor,
    particleColor,
    weatherColor,
    cloudsColor);
sampler2D[] depths[NUM_LAYERS] = sampler2D[](
    diffuseDepth,
    translucentDepth,
    entityDepth,
    particleDepth,
    weatherDepth,
    cloudsDepth);

#define color(i, uv) texture2D(colors[i], uv)
#define depth(i, uv) texture2D(depths[i], uv).r
#define i2f(i) floor(i * 1.0 / NUM_LAYERS)
#define f2i(f) floor(f * NUM_LAYERS)
