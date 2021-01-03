#include lumi:shaders/pipeline/post/common.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/pipeline/post/simple.vert             *
 *******************************************************/

vec3 day_sky = vec3(0.52, 0.69, 1.0);
vec3 night_sky = vec3(0.004);

#define NUM_TIMES 6
vec3 calc_sky_color()
{
    float time = frx_worldTime();
    vec3 inbetween = mix(day_sky, night_sky, 0.5);
    float[] times = float[NUM_TIMES](
        0.0,
        0.8,
        0.42,
        0.58,
        0.92,
        1.0
    );
    vec3[] colors = vec3[NUM_TIMES](
        inbetween,
        day_sky,
        day_sky,
        night_sky,
        night_sky,
        inbetween
    );
    int i = 1;
    while (time > times[i] && i < NUM_TIMES - 1) i++;
    return mix(colors[i-1], colors[i], l2_clampScale(times[i-1], times[i], time));
}

attribute vec2 in_uv;
void main()
{
    // v_inv_projection = inverse(frx_projectionMatrix());
    vec4 screen = gl_ProjectionMatrix * vec4(gl_Vertex.xy * frxu_size, 0.0, 1.0);
    gl_Position = vec4(screen.xy, 0.2, 1.0);
    v_texcoord = in_uv;
    v_skycolor = calc_sky_color();
}

// mat4 inverse(mat4 m) {
// 	float
// 		a00 = m[0][0], a01 = m[0][1], a02 = m[0][2], a03 = m[0][3],
// 		a10 = m[1][0], a11 = m[1][1], a12 = m[1][2], a13 = m[1][3],
// 		a20 = m[2][0], a21 = m[2][1], a22 = m[2][2], a23 = m[2][3],
// 		a30 = m[3][0], a31 = m[3][1], a32 = m[3][2], a33 = m[3][3],

// 		b00 = a00 * a11 - a01 * a10,
// 		b01 = a00 * a12 - a02 * a10,
// 		b02 = a00 * a13 - a03 * a10,
// 		b03 = a01 * a12 - a02 * a11,
// 		b04 = a01 * a13 - a03 * a11,
// 		b05 = a02 * a13 - a03 * a12,
// 		b06 = a20 * a31 - a21 * a30,
// 		b07 = a20 * a32 - a22 * a30,
// 		b08 = a20 * a33 - a23 * a30,
// 		b09 = a21 * a32 - a22 * a31,
// 		b10 = a21 * a33 - a23 * a31,
// 		b11 = a22 * a33 - a23 * a32,

// 		det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;

// 	return mat4(
// 		a11 * b11 - a12 * b10 + a13 * b09,
// 		a02 * b10 - a01 * b11 - a03 * b09,
// 		a31 * b05 - a32 * b04 + a33 * b03,
// 		a22 * b04 - a21 * b05 - a23 * b03,
// 		a12 * b08 - a10 * b11 - a13 * b07,
// 		a00 * b11 - a02 * b08 + a03 * b07,
// 		a32 * b02 - a30 * b05 - a33 * b01,
// 		a20 * b05 - a22 * b02 + a23 * b01,
// 		a10 * b10 - a11 * b08 + a13 * b06,
// 		a01 * b08 - a00 * b10 - a03 * b06,
// 		a30 * b04 - a31 * b02 + a33 * b00,
// 		a21 * b02 - a20 * b04 - a23 * b00,
// 		a11 * b07 - a10 * b09 - a12 * b06,
// 		a00 * b09 - a01 * b07 + a02 * b06,
// 		a31 * b01 - a30 * b03 - a32 * b00,
// 		a20 * b03 - a21 * b01 + a22 * b00) / det;
// }
