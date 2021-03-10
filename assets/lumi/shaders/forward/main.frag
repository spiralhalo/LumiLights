#include frex:shaders/api/sampler.glsl
#include frex:shaders/api/fragment.glsl
#include frex:shaders/api/material.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/context/forward/common.glsl
#include lumi:shaders/context/global/experimental.glsl
#include lumi:shaders/context/global/shadow.glsl
#include lumi:shaders/api/param_frag.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/tonemap.glsl
#include lumi:shaders/lib/pbr_shading.glsl
#include lumi:shaders/lib/noise_glint.glsl

/*******************************************************
 *  lumi:shaders/forward/main.frag                    *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

#include lumi:shaders/forward/varying.glsl

frx_FragmentData frx_createPipelineFragment()
{
#ifdef VANILLA_LIGHTING
    return frx_FragmentData (
        texture2D(frxs_baseColor, frx_texcoord, frx_matUnmippedFactor() * -4.0),
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
        texture2D(frxs_baseColor, frx_texcoord, frx_matUnmippedFactor() * -4.0),
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
        if (gl_FragCoord.z <= 0.88) { // hack to exclude hand
            float diffuse = mix(pv_diffuse, 1, fragData.emissivity);
            diffuse = frx_isGui() ? diffuse : min(1.0, 1.5 - diffuse);
            diffuse = fragData.diffuse ? diffuse : 1.0;
            a.rgb *= diffuse;
            a.rgb += noise_glint(frx_normalizeMappedUV(frx_texcoord), frx_matGlint());
        } else {
            float bloom_out = fragData.emissivity * a.a;
            vec3 normal = fragData.vertexNormal * frx_normalModelMatrix();
            //TODO: apply shadowmap perhaps
            pbr_shading(a, bloom_out, l2_viewpos, fragData.light.xyy, normal, pbr_roughness, pbr_metallic, pbr_f0, fragData.diffuse, true);
            a.rgb += hdr_gammaAdjust(noise_glint(frx_normalizeMappedUV(frx_texcoord), frx_matGlint()));
            a = ldr_tonemap(a);
            gl_FragData[5] = vec4(bloom_out, 0.0, 0.0, 1.0);
        }
        gl_FragDepth = gl_FragCoord.z;
        gl_FragData[0] = a;
    } else {
        vec2 light = fragData.light.xy;

        #if defined(SHADOW_MAP_PRESENT) && !defined(DEFERRED_SHADOW)
            float shadowFactor = calcShadowFactor(frxs_shadowMap, pv_shadowpos);
            // sunlight requires > 0.7 skylight (see lightsource.glsl) therefore the light.y is clamped to this
            light.y = mix(min(0.7, light.y), 1.0, shadowFactor);
        #endif
        
        // hijack f0 for matHurt and matflash because hurting things are not reflective I guess
        if (frx_matFlash()) pbr_f0 = 1.0;
        else if (frx_matHurt()) pbr_f0 = 0.9;
        else pbr_f0 = min(0.8, pbr_f0);

        vec3 normalizedNormal = normalize(fragData.vertexNormal) * 0.5 + 0.5;
        float bloom = fragData.emissivity * a.a;
        float ao = fragData.ao ? (1.0 - fragData.aoShade) * a.a : 0.0;
        float normalizedBloom = (bloom - ao) * 0.5 + 0.5;
        //pad with 0.01 to prevent conflation with unmanaged draw
        float roughness = fragData.diffuse ? 0.01 + pbr_roughness * 0.98 : 1.0;

        // PERF: view normal, more useful than world normal
        gl_FragDepth = gl_FragCoord.z;
        gl_FragData[0] = a;
        gl_FragData[1] = vec4(light.x, light.y, (frx_renderTarget() == TARGET_PARTICLES) ? bloom : normalizedBloom, 1.0);
        gl_FragData[2] = vec4(normalizedNormal, 1.0);
        gl_FragData[3] = vec4(roughness, pbr_metallic, pbr_f0, 1.0);
        gl_FragData[4] = vec4(frx_normalizeMappedUV(frx_texcoord), frx_matGlint(), 1.0);
    }
}
