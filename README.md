# Lumi Lights
Aesthetic shader for [Canvas](https://github.com/grondag/canvas) that adds directional sky light and ambient light. Lumi Lights aims to replace vanilla lighting as much as possible.

**Made for the latest\* Canvas build (new pipeline).**

\*) As Canvas is undergoing a major refactor, Lumi Lights code might not always catch up to it.

## Features

### Ambient colors
Ambient lighting changes colors based on the time of day.

### Wavy water
Adds a reflection of the sun on water, complete with wavy wobbly effect.

### Higher dynamic range
The sunlight is now much brighter than vanilla, giving a more realistic feel.

### Brightness support
"Bright" setting works similarly to vanilla. "Moody" setting makes it closer to true darkness in the overworld.

### Dimension colors
The End and the Nether has ambient light colors that matches the surrounding fog or sky. 

## How to use

### Branch

There are several (subtly) different versions:
- [`hdr`](../../tree/hdr) the default branch
- [`vibrant`](../../tree/vibrant) alternative version with more vibrant colors
- [`film`](../../tree/film) alternative version that uses ACES filmic tone mapping

### Download and installation

In the right branch, press the green dropdown button that says `Code` on the upper right corner. Select `Download ZIP`. You will get a ZIP file containing a folder. Put this folder inside your Resource Packs folder. Don't put the ZIP file directly as it wouldn't work.

## License

Lumi Lights is released under the terms of the GNU Lesser General Public License version 3.0. See the files `COPYING` and `COPYING.LESSER` for more information.

Parts of its source code is derived from Canvas which is released under the Apache License version 2.0.

## Notes

### Note on diffuse
Vanilla objects has a property called "diffuse", which determines if they should have directional shading or not. In Lumi Lights, objects that had their diffuse set to false are treated as if they are facing up, so that they always have the same brightness as the top face of the block that they are on.

