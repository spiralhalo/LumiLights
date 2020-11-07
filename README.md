# Lumi Lights
Aesthetic shader for [Canvas](https://github.com/grondag/canvas) that adds directional sky light and ambient light. Lumi Lights aims to replace vanilla lighting as much as possible.

Written for the latest Canvas build (new pipeline). 

## Now with wavy water
Wavy water effect is experimental and may cause artifact when: a block is mistakenly treated as water, or near the edge of 256x256 world regions due to a Canvas bug. Please report if you find other issues.

## Now with HDR (?)
HDR is a term that I'm vaguely using to a set of technique that *basically* allows the sun the be very bright. This means when you're inside a building or a cave, when you *look* outside it would look very bright, much brighter than your surrounding, *just like in real life*.

However, *this isn't real life*. In real life, when you *do* go outside your eye adapts to the new brightness. Lumi Lights can't do that, because that would be too convenient isn't it? Instead, what "HDR" does here is making the outside extra bright and the inside extra dark *forever*, making life more difficult for you. But hey, at least ravines and cave openings look more beautiful this way.

(If you want to go back to a life before the HDR menace, try the [water_effects](../../tree/water_effect) branch)
