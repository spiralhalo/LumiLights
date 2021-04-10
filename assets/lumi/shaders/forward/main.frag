#include frex:shaders/api/sampler.glsl
#include frex:shaders/api/fragment.glsl
#include frex:shaders/api/material.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/api/pbr_ext.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/api/param_frag.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/func/tonemap.glsl
#include lumi:shaders/func/pbr_shading.glsl
#include lumi:shaders/func/glintify2.glsl
#include lumi:shaders/lib/bitpack.glsl

/*******************************************************
 *  lumi:shaders/forward/main.frag                    *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_glint;

in vec3 l2_viewpos;
in vec2 pv_lightcoord;
in float pv_ao;
in float pv_diffuse;

out vec4[7] fragColor;

frx_FragmentData frx_createPipelineFragment()
{
#ifdef VANILLA_LIGHTING
    return frx_FragmentData (
        texture(frxs_baseColor, frx_texcoord, frx_matUnmippedFactor() * -4.0),
        frx_color,
        frx_matEmissive() ? 1.0 : 0.0,
        !frx_matDisableDiffuse(),
        !frx_matDisableAo(),
        frx_normal,
        pv_lightcoord,
        pv_ao
    );
#else
    return frx_FragmentData (
        texture(frxs_baseColor, frx_texcoord, frx_matUnmippedFactor() * -4.0),
        frx_color,
        frx_matEmissive() ? 1.0 : 0.0,
        !frx_matDisableDiffuse(),
        !frx_matDisableAo(),
        frx_normal
    );
#endif
}

void frx_writePipelineFragment(in frx_FragmentData fragData)
{
    vec4 a = clamp(fragData.spriteColor * fragData.vertexColor, 0.0, 1.0);

    if (pbr_f0 < 0.0) {
        pbr_f0 = frx_luminance(hdr_gammaAdjust(a.rgb)) * 0.1;
    }
    pbr_f0 = clamp(pbr_f0, 0.0, 1.0);
    pbr_roughness = clamp(pbr_roughness, 0.0, 1.0);
    pbr_metallic = clamp(pbr_metallic, 0.0, 1.0);

    if (frx_modelOriginType() == MODEL_ORIGIN_SCREEN) {
        if (gl_FragCoord.z <= 0.6) { // hack to exclude hand but include bedrockify doll
            float diffuse = mix(pv_diffuse, 1, fragData.emissivity);
            diffuse = frx_isGui() ? diffuse : min(1.0, 1.5 - diffuse);
            diffuse = fragData.diffuse ? diffuse : 1.0;
            a.rgb *= diffuse;
            #if GLINT_MODE == GLINT_MODE_SHADER
                a.rgb += noise_glint(frx_normalizeMappedUV(frx_texcoord), frx_matGlint());
            #else
                a.rgb += texture_glint(u_glint, frx_normalizeMappedUV(frx_texcoord), frx_matGlint());
            #endif
        } else {
            float bloom_out = fragData.emissivity * a.a;
            vec3 normal = fragData.vertexNormal * frx_normalModelMatrix();
            //TODO: apply shadowmap perhaps (is the hand even included in depth pass ??)
            pbr_shading(a, bloom_out, l2_viewpos, fragData.light.xyy, normal, pbr_roughness, pbr_metallic, pbr_f0, fragData.diffuse, true);
            #if GLINT_MODE == GLINT_MODE_SHADER
                a.rgb += hdr_gammaAdjust(noise_glint(frx_normalizeMappedUV(frx_texcoord), frx_matGlint()));
            #else
                a.rgb += hdr_gammaAdjust(texture_glint(u_glint, frx_normalizeMappedUV(frx_texcoord), frx_matGlint()));
            #endif
            a = ldr_tonemap(a);
            fragColor[6] = vec4(bloom_out, 0.0, 0.0, 1.0);
        }
        gl_FragDepth = gl_FragCoord.z;
        fragColor[0] = a;
    } else {
        vec2 light = fragData.light.xy;
        vec3 normal = normalize(fragData.vertexNormal) * 0.5 + 0.5;
        vec3 normal_micro = pbr_normalMicro.x > 90. ? normal : normalize(pbr_normalMicro) * 0.5 + 0.5;
        float bloom = fragData.emissivity * a.a;
        float ao = fragData.ao ? (1.0 - fragData.aoShade) * a.a : 0.0;
        float normalizedBloom = (bloom - ao) * 0.5 + 0.5;
        //pad with 0.01 to prevent conflation with unmanaged draw
        float roughness = fragData.diffuse ? 0.01 + pbr_roughness * 0.98 : 1.0;

        float bitFlags = bit_pack(frx_matFlash()?1.:0., frx_matHurt()?1.:0., frx_matGlint(), 0., 0., 0., 0., 0.);

        // PERF: view normal, more useful than world normal
        gl_FragDepth = gl_FragCoord.z;
        fragColor[0] = a;
        fragColor[1] = vec4(light.x, light.y, (frx_renderTarget() == TARGET_PARTICLES) ? bloom : normalizedBloom, 1.0);
        fragColor[2] = vec4(normal, 1.0);
        fragColor[3] = vec4(normal_micro, 1.0);
        fragColor[4] = vec4(roughness, pbr_metallic, pbr_f0, 1.0);
        fragColor[5] = vec4(frx_normalizeMappedUV(frx_texcoord), bitFlags, 1.0);

    }
}
