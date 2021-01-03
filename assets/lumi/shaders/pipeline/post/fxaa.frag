#include lumi:shaders/pipeline/post/common.glsl
#include fraex:shaders/api/world.glsl

/*******************************************************
 *  lumi:shaders/pipeline/post/fxaa.frag               *
 *******************************************************/

uniform sampler2D u_color;

#define FXAA_REDUCE_MIN (1.0/128.0)
#define FXAA_REDUCE_MUL (1.0/8.0)
#define FXAA_SPAN_MAX 8.0
#define FxaaInt2 ivec2

//https://www.geeks3d.com/20110405/fxaa-fast-approximate-anti-aliasing-demo-glsl-opengl-test-radeon-geforce/
vec3 FxaaPixelShader(vec2 texcoord, sampler2D tex, vec2 invWH)
{   
    vec3 rgbNW = texture2DLod(tex, (texcoord + vec2(-1.0, -1.0) * invWH), 0.0).xyz;
    vec3 rgbNE = texture2DLod(tex, (texcoord + vec2(1.0, -1.0) * invWH), 0.0).xyz;
    vec3 rgbSW = texture2DLod(tex, (texcoord + vec2(-1.0, 1.0) * invWH), 0.0).xyz;
    vec3 rgbSE = texture2DLod(tex, (texcoord + vec2(1.0, 1.0) * invWH), 0.0).xyz;
    vec3 rgbM  = texture2DLod(tex, texcoord, 0.0).xyz;
    
    vec3 luma = vec3(0.299, 0.587, 0.114);
    float lumaNW = dot(rgbNW, luma);
    float lumaNE = dot(rgbNE, luma);
    float lumaSW = dot(rgbSW, luma);
    float lumaSE = dot(rgbSE, luma);
    float lumaM  = dot(rgbM,  luma);
    
    float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
    float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
    
    vec2 dir; 
    dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
    dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));
    
    float dirReduce = max(
        (lumaNW + lumaNE + lumaSW + lumaSE) * (0.25 * FXAA_REDUCE_MUL),
        FXAA_REDUCE_MIN);
    float rcpDirMin = 1.0/(min(abs(dir.x), abs(dir.y)) + dirReduce);
    dir = min(vec2( FXAA_SPAN_MAX,  FXAA_SPAN_MAX), 
          max(vec2(-FXAA_SPAN_MAX, -FXAA_SPAN_MAX), 
          dir * rcpDirMin)) * invWH.xy;
    
    vec3 rgbA = (1.0/2.0) * (
        texture2DLod(tex, texcoord + dir * (1.0/3.0 - 0.5), 0.0).xyz +
        texture2DLod(tex, texcoord + dir * (2.0/3.0 - 0.5), 0.0).xyz);
    vec3 rgbB = rgbA * (1.0/2.0) + (1.0/4.0) * (
        texture2DLod(tex, texcoord + dir * (0.0/3.0 - 0.5), 0.0).xyz +
        texture2DLod(tex, texcoord + dir * (3.0/3.0 - 0.5), 0.0).xyz);
    float lumaB = dot(rgbB, luma);
    if((lumaB < lumaMin) || (lumaB > lumaMax)) return rgbA;
    return rgbB;
}

vec4 PostFX(sampler2D tex, vec2 uv)
{
    vec4 c = vec4(0.0);
    vec2 invWH = vec2(1.0) / frxu_size;
    c.rgb = FxaaPixelShader(uv, tex, invWH);
    //c.rgb = 1.0 - texture2D(tex, uv.xy).rgb;
    c.a = 1.0;
    return c;
}
    
void main() 
{ 
    gl_FragColor = PostFX(u_color, v_texcoord);
}
