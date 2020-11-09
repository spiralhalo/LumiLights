# Lumi Lights
Aesthetic shader for [Canvas](https://github.com/grondag/canvas) that adds directional sky light and ambient light. Lumi Lights aims to replace vanilla lighting as much as possible.

**Written for the latest Canvas build (new pipeline).**

## Now with wavy water
Adds a reflection of the sun on water, complete with wavy wobbly effect.

## Now with higher dynamic range
The sunlight is now much brighter than vanilla, giving a more realistic feel.

## How to use

### Branch

There are two main branches:
- [`hdr`](../../tree/hdr) the default branch
- [`vibrant`](../../tree/vibrant) alternative version with more vibrant colors

### Download and installation

In the right branch, press the green dropdown button that says `Code` on the upper right corner. Select `Download ZIP`. You will get a ZIP file containing a folder. Put this folder inside your Resource Packs folder. Don't put the ZIP file directly as it wouldn't work.

## Notes

### Known issues
Due to a bug, water reflection effect might have "stitching" artifact on certain coordinates.

### Note on diffuse
Vanilla objects has a property called "diffuse", which determines if they should have directional shading or not. In Lumi Lights, objects that had their diffuse set to false are treated as if they are facing up, so that they always have the same brightness as the top face of the block that they are on.

### Note on dimensions
The visual effects provided by this shader are meant for the overworld, so there might be either no effect or wrong effect on other dimensions. In case the latter was observed, please open an issue.

