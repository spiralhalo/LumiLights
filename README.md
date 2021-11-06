# Lumi Lights 
![Lumi Lights](https://github.com/spiralhalo/spiralhalo.github.io/raw/main/img/screen2.jpg)

A custom rendering pipeline for Canvas for improved visual fidelity.

## Features

- Animated reflective water
- Bloom effect
- Customizable colors
- Directional sun lighting
- PBR/HDR shading
- Procedural sky
- Refraction and caustics effect
- Screenspace AO
- Screenspace reflections
- Temporal AA
- Toon outline and other novelty effects
- Volumetric clouds
- Volumetric light rays

## Downloads

**[=> View Latest Releases <=](https://github.com/spiralhalo/LumiLights/releases)**

## How to Install Lumi Lights

1. Put `LumiLights-vX.XX.zip` in resource packs and activate the resource pack(s), and make sure it is above the `canvas_standard` pack.
2. Go to Video Settings → Canvas → Change the `Pipeline` to `Lumi Lights` (no shadow) or `Lumi Shadow xx` (with shadow)

## PBR Extension

- [Lumi PBR Ext](https://github.com/spiralhalo/LumiPBRExt) vanilla PBR materials.
- [Lumi PBR Compat](https://github.com/spiralhalo/LumiPBRCompat) materials for modded objects.

Lumi Lights PBR Extension brings its own spin of roughness/metalness material models to life.

## Acknowledgement & Special Thanks

- [Antonio Hernández Bejarano's LWJGL Game Dev Gitbook](https://ahbejarano.gitbook.io/lwjglgamedev/) Helping me learn OpenGL
- [LearnOpenGL.com](https://learnopengl.com/) Taught me about PBR
- [Sebastian Lague's Coding Adventure](https://www.youtube.com/watch?v=4QOcCGI6xOU) Amazing exploration and explanation for volumetric clouds
- [Volumetric lights by Alexandre Pestana](https://www.alexandre-pestana.com/volumetric-lights/) Opened my eye about dithering
- [Temporal Reprojection Anti-Aliasing in INSIDE](https://www.youtube.com/watch?v=2XXS5UyNjjU) Inspiration and explanation for TAA
- [Temporal Anti Aliasing – Step by Step](https://ziyadbarakat.wordpress.com/2020/07/28/temporal-anti-aliasing-step-by-step/) Another inspiration for TAA and introduced me to Halton sequences
- Lumi Lights discord members - testing and reporting countless bugs!

## Source Credits

- [Canvas Standard by Grondag](https://github.com/grondag/canvas) for Bloom
- [Erkaman/glsl-godrays](https://github.com/Erkaman/glsl-godrays) for Godrays
- [TheRealMJP/Shadows](https://github.com/TheRealMJP/Shadows) for Shadow PCF (thanks to Grondag for isolating the code)
- [ziacko/Temporal-AA](https://github.com/ziacko/Temporal-AA) for TAA (based on Playdead's implementation)
- [WebGL GLSL HBAO](https://gist.github.com/transitive-bullshit/6770346) for SSAO

## License

Lumi Lights is released **without any warranty** under the GNU Lesser General Public License version 3 as published by the Free Software Foundation. See the files `COPYING` and `COPYING.LESSER` for license terms. You may also obtain a copy of the license at https://www.gnu.org/licenses/lgpl-3.0.html.

Have some questions? [Join the Lumi Lights discord.](https://discord.gg/qcyBfhxkgk) [Or check our FAQ.](https://gist.github.com/Reeses-Puffs/15a7a093c3144fa8eadfdc7a255ef220)
