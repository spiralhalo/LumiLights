#include frex:shaders/api/fragment.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include frex:shaders/lib/color.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/forward/common.glsl
#include lumi:shaders/api/param_frag.glsl
#include lumi:shaders/lib/water.glsl

const float stretch = 1.2;

void frx_startFragment(inout frx_FragmentData fragData) {

    /* SWAMP WATER, BLOOD, OR MUSTARD ARE CONSIDERED MURKY */
    float murky = 1.0 - fragData.vertexColor.b;

    #ifdef LUMI_PBRX
        /* PBR PARAMS */
        pbr_f0 = 0.02;
        pbr_roughness = 0.05;// + murky * 0.5;
    #else
        /* HACK */
        fragData.light.y += 0.077 * smoothstep(1.0, 0.99, fragData.vertexNormal.y);
        fragData.light.y = min(0.96875, fragData.light.y);

        /* LUMI PARAMS */
        phong_specular = 500.0;
    #endif
    
    /* WATER RECOLOR */
    #ifdef LUMI_NoWaterTexture
        fragData.spriteColor.rgb = vec3(1.0);
        fragData.spriteColor.a = 0.3 + 0.7 * fragData.spriteColor.a * murky;
    #else
        fragData.spriteColor.rgb *= fragData.spriteColor.rgb;
        fragData.spriteColor.a *= 0.5 + 0.5 * murky;
    #endif
    #ifdef LUMI_NoWaterColor
        fragData.vertexColor.rgb = vec3(0.0);
        fragData.spriteColor.a = 0.1;
    #endif
    
    /* WAVY NORMALS */
    // wave movement doesn't necessarily follow flow direction for the time being
    float waveSpeed = frx_var2.x;
    float scale = frx_var2.y;
    float amplitude = frx_var2.z;
    vec3 moveSpeed = frx_var1.xyz * waveSpeed;
    vec3 up = fragData.vertexNormal.xyz;
    vec3 samplePos = frx_var0.xyz;
    vec3 noisyNormal = ww_normals(up, l2_tangent, cross(up, l2_tangent), samplePos, waveSpeed, scale, amplitude, stretch, moveSpeed);
    fragData.vertexNormal = mix(noisyNormal, fragData.vertexNormal, pow(gl_FragCoord.z, 500.0));
}
