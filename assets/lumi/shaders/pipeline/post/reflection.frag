#include lumi:shaders/pipeline/post/common.glsl
#include lumi:shaders/lib/rt_v1.glsl

sampler2D u_composite;
sampler2D u_depth;
sampler2D u_normal;
sampler2D u_material;

/*******************************************************
 *  lumi:shaders/pipeline/post/reflection.frag         *
 *******************************************************/
 
void main()
{
    vec4 material = texture2DLod(u_material, v_texcoord, 0);
    vec4 base_color = texture2D(u_composite, v_texcoord);
    float gloss = 1.0 - material.r;

    if (gloss > 0.01) {
        // TODO: replace matrices with real frx uniforms
        vec3 reflected_uv = rt_march(v_texcoord, 0.25, 128.0, u_projection, u_inv_projection, u_view, u_inv_view, u_composite, u_depth, u_normal);
        if (reflected_uv.z <= 0.0) {
            gl_FragData[0] = vec4(base_color.rgb, 1.0);
        } else {
            vec4 metal = vec4(base_color.rgb, 1.0) + texture2D(u_composite, reflected_uv) * gloss;
            vec4 diffuse = max(base_color, texture2D(u_composite, reflected_uv) * gloss);
            gl_FragData[0] = mix(diffuse, metal, material.g);
        }
    } else {
        gl_FragData[0] = vec4(base_color.rgb, 1.0);
    }
}
