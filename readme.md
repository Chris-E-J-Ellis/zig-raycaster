# A Raycaster in Zig =D

My crack at a simple raycaster, trying to use a similar approach to the Wolfenstein 3D engine (hence some odd design choices).

Using inspiration from a few sources:
- https://fabiensanglard.net/gebbwolf3d/
- https://www.permadi.com/tutorial/raycast/rayc1.html
- https://lodev.org/cgtutor/raycasting.html
- https://www.playfuljs.com/a-first-person-engine-in-265-lines/

## Notes
- SDL2 seems fairly straightforward to use via C interop.
- I'm still new to Zig, there's some stuff in there that probably isn't best practice.
- I don't write many games, so I wouldn't use this as basis for an engine =D
- This is very much a test of a few things, so there's likely to be a bunch of loose ends, don't pull too hard.
- Linux - you should be fine if you have a development version of SDL2 installed. 
- Windows - I was using the MinGW version of SDL2 (see build.zig)
    - Headers in "deps/include"
    - Libs in "deps/lib"
    - This seems fine on Zig 0.6.0, but in 0.7.0+ trying to link the mingw SDL2 library seems to fall over while trying to locate SDL2.lib, it seems my gnu target is not being respected and it's attempting to use msvc.
        - Reported as [this bug](https://github.com/ziglang/zig/issues/7799). Until it's fixed you can link against the `SDL2-devel-x-VC.zip` packages, and ensure `SDL2.dll` is present.
- Wolf3D Textures aren't distributed with this repo, a default error texture will be used if they can't be loaded.
- Textures with the following names should exist in the `data` folder:
    - bluestone.bmp
    - wood.bmp
    - eagle.bmp
    - greystone.bmp
    - colorstone.bmp
    - redbrick.bmp
    - mossy.bmp
    - purplestone.bmp
- Enjoy!

![Small demo](/demo-small.gif)
![Small Textured demo](/demo-small-textured.gif)
![Small Wolf3D Textured demo](/demo-small-wolf3d-textured.gif)
