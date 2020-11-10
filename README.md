# Lumi Lights
Aesthetic shader for [Canvas](https://github.com/grondag/canvas) that adds directional sky light and ambient light. Lumi Lights aims to replace vanilla lighting as much as possible.

**Written for the latest Canvas build (new pipeline).**

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
The End in particular has a different ambient lighting that gives it a unique feel.

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

