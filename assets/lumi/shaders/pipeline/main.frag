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
#include lumi:shaders/internal/context.glsl
#include lumi:shaders/api/pbr_frag.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/pbr.glsl

/*******************************************************
 *  lumi:shaders/pipeline/main.frag                    *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

#define hdr_finalMult 1

float l2_ao(frx_FragmentData fragData) {
    #if AO_SHADING_MODE != AO_MODE_NONE
    #if LUMI_LightingMode == LUMI_LightingMode_SystemUnused
        float aoInv = 1.0 - (fragData.ao ? _cvv_ao : 1.0);
        return 1.0 - 0.8 * smoothstep(0.0, 0.3, aoInv * (0.5 + 0.5 * abs((_cvv_normal * frx_normalModelMatrix()).y)));
    #else
        float ao = fragData.ao ? _cvv_ao : 1.0;
        return hdr_gammaAdjustf(min(1.0, ao + fragData.emissivity));
    #endif
    #else
        return 1.0;
    #endif
}

// this is literally just Grondag's magic diffuse function and I shall take no credit for it
float l2_diffuseGui(vec3 normal) {
	normal = normalize(gl_NormalMatrix * normal);
	float light = 0.4
	+ 0.6 * clamp(dot(normal.xyz, vec3(-0.96104145, -0.078606814, -0.2593495)), 0.0, 1.0)
	+ 0.6 * clamp(dot(normal.xyz, vec3(-0.26765957, -0.95667744, 0.100838766)), 0.0, 1.0);
	return min(light, 1.0);
}

#include lumi:shaders/internal/varying.glsl
#include lumi:shaders/internal/main_frag.glsl
#include lumi:shaders/internal/lightsource.glsl
#include lumi:shaders/internal/tonemap.glsl
#include lumi:shaders/internal/pbr_shading.glsl
#include lumi:shaders/internal/phong_shading.glsl
#include lumi:shaders/internal/debug_shading.glsl
#include lumi:shaders/internal/skybloom.glsl

void frx_startPipelineFragment(inout frx_FragmentData fragData)
{
    vec4 a = clamp(fragData.spriteColor * fragData.vertexColor, 0.0, 1.0);
    float bloom = fragData.emissivity; // separate bloom from emissivity
    bool translucent = _cv_getFlag(_CV_FLAG_CUTOUT) == 0.0 && a.a < 0.99;
    if(frx_isGui()){
        #if DIFFUSE_SHADING_MODE != DIFFUSE_MODE_NONE
            if (fragData.diffuse) {
                float diffuse = mix(l2_diffuseGui(fragData.vertexNormal), 1, fragData.emissivity);
                vec3 shading = mix(vec3(0.5, 0.4, 0.8) * diffuse * diffuse, vec3(1.0), diffuse);
                a.rgb *= shading;
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
	gl_FragData[0] = _cp_fog(a);
	gl_FragDepth = gl_FragCoord.z;

    translucent = translucent && a.a < 0.99;
    gl_FragData[1] = vec4(bloom * a.a, 1.0, 0.0, translucent ? step(l2_skyBloom(), bloom) : 1.0);

    vec3 normal = fragData.vertexNormal * frx_normalModelMatrix();
    gl_FragData[2] = vec4(normal * 0.5 + 0.5, 1.0);

    // TODO: f0, albedo
    #ifdef LUMI_PBRX
        gl_FragData[3] = vec4(pbr_roughness, pbr_metallic, 0.0, 0.0);
    #else
        gl_FragData[3] = vec4(1.0, 0.0, 0.0, 0.0);
    #endif
}
