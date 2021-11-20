/*******************************************************
 *  lumi:shaders/api/pbr_ext.glsl
 *******************************************************/

/*** API ***/

/** GENERAL INFORMATION **
 * Lumi Lights PBR Extension API.
 * 
 * DEPRECATION NOTICE
 * This API has been deprecated in favor of Frex release API which contains its own PBR implementation.
 * 
 * USAGE
 * Import this API in your fragment shader.
 * Guard every property assignment using `#ifdef LUMI_PBR_API >= {required version}` to ensure fail-safety.
 * Will fallback to Frex PBR properties if unassigned.
 */

/* API version */
#define LUMI_PBR_API 7

#ifndef VERTEX_SHADER

/* DEPRECATED. Use frx_fragRoughness instead. */
/* Roughness property -- Since version 1 */
float pbr_roughness = -1.0;

/* DEPRECATED. Use frx_fragMetalness instead. */
/* Metalness property -- Since version 1 */
float pbr_metallic = -1.0;

/* DEPRECATED. Use frx_fragReflectance instead. */
/* Initial reflectivity -- Since version 2 */
float pbr_f0 = -1.0;

/* DEPRECATED. Use frx_fragNormal instead.
 * Note that frx_fragNormal are always in tangent space. */
/* Microfacet normal in world space -- Since version 3 */
vec3  pbr_normalMicro = vec3(-2., -2., -2.);

/* Water flag. Lumi Lights handle water exceptionally -- Since version 4 */
bool  pbr_isWater = false;

#endif

/*** LEGACY API ***/

#ifdef VERTEX_SHADER

/* Usable tangent vector vertex output */
out vec3 l2_tangent;

#else

/* Usable tangent vector fragment input */
in vec3 l2_tangent;

#endif

/* Deprecated. Use LUMI_PBR_API instead */
#define LUMI_PBRX



/*** BACKWARDS COMPATIBILITY ***/

#include lumi:shaders/api/bump_ext.glsl

#ifdef VERTEX_SHADER
#define pbrExt_tangentSetup(normal) l2_tangent = bumpExt_computeTangent_v1(normal)
#endif



#ifndef VERTEX_SHADER
/*** FOR INTERNAL USE. DO NOT ACCESS ***/

bool pbrExt_doTBN = true;

void pbrExt_resolveProperties() {
	if (pbr_roughness >= 0.) frx_fragRoughness = pbr_roughness;
	// if (pbr_metallic >= 0.) frx_fragMetalness = pbr_metallic; // fragMetalness doesn't exist yet
	if (pbr_f0 >= 0.) frx_fragReflectance = pbr_f0;
	if (pbr_normalMicro.x >= 0) {
		frx_fragNormal = pbr_normalMicro;
		pbrExt_doTBN = false;
	}
}
#endif
