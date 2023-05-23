Spall : fast, portable profiling

Contact Information
-------------------
Colin Davidson
https://gravitymoth.com/spall
https://gravitymoth.itch.io/spall
https://github.com/colrdavidson/spall-native-issues/issues
https://discord.gg/hmn : handmade.network Discord server (happy to respond to issues there)
https://discord.gg/MkAPHSWPZZ : Spall Discord server

Acknowledgments
---------------
Thank you for purchasing a copy of Spall and supporting its continued development.

Big thanks to pmttavara for major early help getting the look-and-feel right for the initial launch, working through
early performance issues, and designing the first c library for tracing native code.

Thanks to Ben Visness and Abner Coimbre for the push to make, ship, and demo a profiler to help
fill some big shoes in the wake of chrome://tracing's deprecation.

More thanks to Demetri Spanos, simp, NeGate, and many others for the continued gentle nudges to make this a proper product,
serious beta-testing efforts, and the occasional well-deserved kick in the rear over bad design choices along the way.

I welcome any and all bug reports, feature requests, cheers and jeers.
If you run into issues, please use the Github issue tracker,
listed above or contact me via discord, to report any problems you might bump into.

Attribution
-----------
Spall would not be possible without the following pieces of software and fonts:
 * Odin: https://github.com/odin-lang/Odin
 * SDL2: https://github.com/libsdl-org/SDL
 * FontAwesome by Dave Gandy - https://fontawesome.com/
 * FiraCode: https://github.com/tonsky/FiraCode

demo_trace.json comes courtesy of NeGate, from his Cuik C compiler

Runtime Dependencies
--------------------
If you're on Ubuntu, you'll need:
`sudo apt install libsdl2-2.0-0 libsdl2-ttf-2.0-0 libc++abi-14-dev`

On OSX:
`brew install sdl2 sdl2_ttf`

How to Use
----------
For info on how to use the UI, check out the gif-scrapbook tutorial for the web-version at https://gravitymoth.com/spall/spall-web.html, the two are pretty similar
To integrate into your C/C++ project, https://github.com/colrdavidson/spall/blob/master/spall.h has the latest manual tracing header, and there are usage examples at:
	https://github.com/colrdavidson/spall-web/tree/master/examples

If you're a developer using Odin, import `core:prof/spall`, and you should be good to go.

For auto-tracing with the native version, you can either use the slower, spall.h reference auto-tracer:
	https://github.com/colrdavidson/spall-web/tree/master/examples/auto_tracing

or the new native-only lightweight one:
	https://github.com/colrdavidson/spall-web/tree/master/examples/native_auto_tracing
