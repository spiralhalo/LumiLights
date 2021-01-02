#include lumi:shaders/pipeline/post/common.glsl
#include lumi:shaders/lib/rt_v1.glsl

sampler2D u_composite;
sampler2D u_depth;
sampler2D u_normal;
sampler2D u_material;

/*******************************************************
 *  lumi:shaders/pipeline/post/reflection.frag         *
 *******************************************************/

#define near 0.0001
#define far 1.0

mat4 InverseOf(mat4 m) {
	float
		a00 = m[0][0], a01 = m[0][1], a02 = m[0][2], a03 = m[0][3],
		a10 = m[1][0], a11 = m[1][1], a12 = m[1][2], a13 = m[1][3],
		a20 = m[2][0], a21 = m[2][1], a22 = m[2][2], a23 = m[2][3],
		a30 = m[3][0], a31 = m[3][1], a32 = m[3][2], a33 = m[3][3],

		b00 = a00 * a11 - a01 * a10,
		b01 = a00 * a12 - a02 * a10,
		b02 = a00 * a13 - a03 * a10,
		b03 = a01 * a12 - a02 * a11,
		b04 = a01 * a13 - a03 * a11,
		b05 = a02 * a13 - a03 * a12,
		b06 = a20 * a31 - a21 * a30,
		b07 = a20 * a32 - a22 * a30,
		b08 = a20 * a33 - a23 * a30,
		b09 = a21 * a32 - a22 * a31,
		b10 = a21 * a33 - a23 * a31,
		b11 = a22 * a33 - a23 * a32,

		det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;

	return mat4(
		a11 * b11 - a12 * b10 + a13 * b09,
		a02 * b10 - a01 * b11 - a03 * b09,
		a31 * b05 - a32 * b04 + a33 * b03,
		a22 * b04 - a21 * b05 - a23 * b03,
		a12 * b08 - a10 * b11 - a13 * b07,
		a00 * b11 - a02 * b08 + a03 * b07,
		a32 * b02 - a30 * b05 - a33 * b01,
		a20 * b05 - a22 * b02 + a23 * b01,
		a10 * b10 - a11 * b08 + a13 * b06,
		a01 * b08 - a00 * b10 - a03 * b06,
		a30 * b04 - a31 * b02 + a33 * b00,
		a21 * b02 - a20 * b04 - a23 * b00,
		a11 * b07 - a10 * b09 - a12 * b06,
		a00 * b09 - a01 * b07 + a02 * b06,
		a31 * b01 - a30 * b03 - a32 * b00,
		a20 * b03 - a21 * b01 + a22 * b00) / det;
}

 //https://stackoverflow.com/questions/18404890/how-to-build-perspective-projection-matrix-no-api
void ComputeFOVProjection( inout mat4 result, float fov, float aspect, float nearDist, float farDist, bool leftHanded /* = true */ )
{
    //
    // General form of the Projection Matrix
    //
    // uh = Cot( fov/2 ) == 1/Tan(fov/2)
    // uw / uh = 1/aspect
    // 
    //   uw         0       0       0
    //    0        uh       0       0
    //    0         0      f/(f-n)  1
    //    0         0    -fn/(f-n)  0
    //
    // Make result to be identity first

    // check for bad parameters to avoid divide by zero:
    // if found, assert and return an identity matrix.
    if ( fov <= 0 || aspect == 0 )
    {
        Assert( fov > 0 && aspect != 0 );
        return;
    }

    float frustumDepth = farDist - nearDist;
    float oneOverDepth = 1 / frustumDepth;

    result[1][1] = 1 / tan(0.5f * fov);
    result[0][0] = (leftHanded ? 1 : -1 ) * result[1][1] / aspect;
    result[2][2] = farDist * oneOverDepth;
    result[3][2] = (-farDist * nearDist) * oneOverDepth;
    result[2][3] = 1;
    result[3][3] = 0;
}

void main()
{
    vec4 material = texture2DLod(u_material, v_texcoord, 0);
    vec4 base_color = texture2D(u_composite, v_texcoord);
    float gloss = 1.0 - material.r;

    mat4 u_projection = mat4(
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0
    );
    ComputeFOVProjection(u_projection, 70, frx_viewAspectRatio(), near, far, true);
    mat4 u_inv_projection = InverseOf(u_projection);

    gl_FragData[0] = texture2D(u_normal, v_texcoord);
    // if (gloss > 0.01) {
    //     // TODO: replace matrices with real frx uniforms
    //     vec3 reflected_uv = rt_march(v_texcoord, 0.25, 128.0, u_projection, u_inv_projection, u_composite, u_depth, u_normal);
    //     if (reflected_uv.z <= 0.0) {
    //         gl_FragData[0] = vec4(base_color.rgb, 1.0);
    //     } else {
    //         vec4 metal = vec4(base_color.rgb, 1.0) + texture2D(u_composite, reflected_uv) * gloss;
    //         vec4 diffuse = max(base_color, texture2D(u_composite, reflected_uv) * gloss);
    //         gl_FragData[0] = mix(diffuse, metal, material.g);
    //     }
    // } else {
    //     gl_FragData[0] = vec4(base_color.rgb, 1.0);
    // }
}
