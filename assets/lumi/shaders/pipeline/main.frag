// Borrowing them for now
#include canvas:shaders/pipeline/fog.glsl

#include frex:shaders/api/world.glsl
#include frex:shaders/api/camera.glsl
#include frex:shaders/api/player.glsl
#include frex:shaders/api/material.glsl
#include frex:shaders/api/fragment.glsl
#include frex:shaders/api/sampler.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/color.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/pbr.glsl
#include lumi:shaders/api/pbr_frag.glsl
#include lumi:shaders/internal/context.glsl
#include lumi:shaders/internal/skybloom.glsl

/*******************************************************
 *  lumi:shaders/pipeline/main.frag                    *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

#define hdr_finalMult 1

#include lumi:shaders/pipeline/varying.glsl
#include lumi:shaders/pipeline/vanilla.glsl
#include lumi:shaders/pipeline/tonemap.glsl
#include lumi:shaders/pipeline/lightsource.glsl
#include lumi:shaders/pipeline/pbr_shading.glsl
#include lumi:shaders/pipeline/phong_shading.glsl
#include lumi:shaders/pipeline/debug_shading.glsl

frx_FragmentData frx_createPipelineFragment() {
#ifdef VANILLA_LIGHTING
	return frx_FragmentData (
		texture2D(frxs_spriteAltas, frx_texcoord, frx_matUnmippedFactor() * -4.0),
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
		texture2D(frxs_spriteAltas, frx_texcoord, frx_matUnmippedFactor() * -4.0),
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
    float bloom = fragData.emissivity; // separate bloom from emissivity
    bool translucent = _cv_getFlag(_CV_FLAG_CUTOUT) == 0.0 && a.a < 0.99;
    if(frx_isGui()){
        #if DIFFUSE_SHADING_MODE != DIFFUSE_MODE_NONE
            if (fragData.diffuse) {
                float diffuse = mix(pv_diffuse, 1, fragData.emissivity);
                a.rgb *= diffuse;
            }
        #endif
    } else {
        #if LUMI_DebugMode != LUMI_DebugMode_Disabled
            debug_shading(fragData, a);
        #else
            #ifdef LUMI_PBRX
                pbr_shading(fragData, a, bloom, translucent);
            #else
                phong_shading(fragData, a, bloom, translucent);
            #endif
            a.rgb *= hdr_finalMult;
            tonemap(a);
        #endif
    }

    if (frx_matFlash()) {
        a = a * 0.25 + 0.75;
    } else if (frx_matHurt()) {
        a = vec4(0.25 + a.r * 0.75, a.g * 0.75, a.b * 0.75, a.a);
    }

    // TODO: need a separate fog pass?
	gl_FragData[0] = p_fog(a);
	gl_FragDepth = gl_FragCoord.z;

    translucent = translucent && a.a < 0.99;
    gl_FragData[1] = vec4(bloom * a.a, 1.0, 0.0, translucent ? step(l2_skyBloom(), bloom) : 1.0);

    vec3 normal = frx_normalModelMatrix() * fragData.vertexNormal;
    gl_FragData[2] = vec4(normal * 0.5 + 0.5, 1.0);

    // TODO: f0, albedo
    #ifdef LUMI_PBRX
        gl_FragData[3] = vec4(pbr_roughness, pbr_metallic, 0.0, 1.0);
    #else
        gl_FragData[3] = vec4(1.0, 0.0, 0.0, 1.0);
    #endif
}
