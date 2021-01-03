#include lumi:shaders/pipeline/post/common.glsl
#include frex:shaders/api/view.glsl
#include lumi:shaders/lib/rt_v1.glsl

uniform sampler2D u_composite;
uniform sampler2D u_depth;
uniform sampler2D u_normal;
uniform sampler2D u_material;

/*******************************************************
 *  lumi:shaders/pipeline/post/reflection.frag         *
 *******************************************************/

void main()
{
    vec4 material = texture2DLod(u_material, v_texcoord, 0);
    vec4 base_color = texture2D(u_composite, v_texcoord);
    float gloss = 1.0 - material.r;
    if (gloss > 0.01) {
        vec4 reflected_uv = rt_reflection(v_texcoord, 0.25, 128.0, frx_projectionMatrix(), v_inv_projection, u_depth, u_normal);
        if (reflected_uv.w <= 0.0) {
            // TODO: sky color
            gl_FragData[0] = vec4(base_color.rgb, 1.0);
        } else {
            float metal   = material.g;
            float fresnel = reflected_uv.z;
            vec4 reflected    = texture2D(u_composite, reflected_uv.xy);
            vec4 tinted_base  = vec4(reflected.rgb * base_color.rgb, 1.0);
            vec4 blended_base = mix(base_color, tinted_base, metal);
            gl_FragData[0] = mix(blended_base, reflected, fresnel);
        }
    } else {
        gl_FragData[0] = vec4(base_color.rgb, 1.0);
    }
}
