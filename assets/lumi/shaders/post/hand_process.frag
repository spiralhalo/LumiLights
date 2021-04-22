#include lumi:shaders/post/common/header.glsl

#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/func/glintify2.glsl
#include lumi:shaders/func/pbr_shading.glsl
#include lumi:shaders/func/tonemap.glsl
#include lumi:shaders/lib/bitpack.glsl

/******************************************************
 * lumi:shaders/post/hand_process.frag                *
 ******************************************************/

uniform sampler2D u_color;
uniform sampler2D u_depth;
uniform sampler2D u_light;
uniform sampler2D u_normal;
uniform sampler2D u_material;
uniform sampler2D u_misc;
                
uniform sampler2D u_translucent_depth;

uniform sampler2D u_glint;
uniform sampler2D u_shadow;

out vec4 fragColor[3];

void main()
{
    float depth = texture(u_depth, v_texcoord).r;
    if (depth == 1.0) {
        discard;
    }

    vec4  a = texture(u_color, v_texcoord);

    vec4 temp    = frx_inverseProjectionMatrix() * vec4(2.0 * v_texcoord - 1.0, 2.0 * depth - 1.0, 1.0);
    vec3 viewPos = temp.xyz / temp.w;

    vec3 light  = texture(u_light, v_texcoord).xyz;
    vec3 normal = (2.0 * texture(u_normal, v_texcoord).xyz - 1.0);
    vec3 mat    = texture(u_material, v_texcoord).xyz;
    
    float roughness = mat.x == 0.0 ? 1.0 : min(1.0, 1.0203 * mat.x - 0.01);
    float bloom_out = light.z;
    //TODO: apply shadowmap perhaps
    pbr_shading(a, bloom_out, viewPos, light.xyy, normal, roughness, mat.y, mat.z, /*diffuse=*/true, true);

    vec3 misc = texture(u_misc, v_texcoord).xyz;

    #if GLINT_MODE == GLINT_MODE_SHADER
        a.rgb += hdr_gammaAdjust(noise_glint(misc.xy, bit_unpack(misc.z, 2)));
    #else
        a.rgb += hdr_gammaAdjust(texture_glint(u_glint, misc.xy, bit_unpack(misc.z, 2)));
    #endif

    fragColor[0] = ldr_tonemap(a);
    fragColor[1] = vec4(bloom_out, 0.0, 0.0, 1.0);
    fragColor[2] = vec4(depth, 0.0, 0.0, 1.0);
}
