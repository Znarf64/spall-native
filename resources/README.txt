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
`sudo apt install libc++abi-14-dev`

On OSX:
`brew install sdl2`


What am I looking at?
--------------------
Spall has a handful of useful tools, each of which have ups and downs, and examples.

- Manual Tracing
- Auto Tracing
- Native Auto Tracing

The Manual Tracer -- spall.h
---------------------------
With the manual tracer, you add begin and end logging to functions you want to see timed and graphed, and get out a trace file that you can plop into Spall.
Manual tracing graphs only the things you want to see, which is great for high-accuracy, clean graphs.

--------------------------------------------------------------------------------------------------------------------
! Auto-Tracing only officially works with Clang and GCC; The MSVC compiler's auto-instrumentation feature is buggy !
--------------------------------------------------------------------------------------------------------------------

The Auto-Tracer -- spall.h + examples/auto_tracing
--------------------------------------------------
This is built using spall.h. It graphs every function in your code, using clang and gcc auto-instrumentation features.
The files it spits out are large, but it's fairly flexible, working in places spall_native_auto.h can't be used because it doesn't need access to the binary after profiling.

The Native Auto-Tracer -- spall_native_auto.h + examples/native_auto_tracing
---------------------------------------------------------------------------
This one does a little magic. It also graphs every function in your code, using the same auto-instrumentation features, but with dramatically smaller trace sizes and less overhead.
It reads your binary when you load your trace into Spall to pull symbols and line info out of the PDB and DWARF data.
It's a little inflexible, it can't auto-trace hot-reloaded code, but for projects like GDB or Python, it's invaluable to be able to dump millions of functions per second
and get a full picture of how the code runs.


How to Use
----------
For info on how to use the UI, check out the gif-scrapbook tutorial for the web-version at https://gravitymoth.com/spall/spall-web.html, the web version and the native version are similar

If you're using C/C++, the examples folder has some usage examples and explainers for how the tools work
If you're using Odin, check out prof/spall for examples in the Odin docs, import `core:prof/spall`, and you should be good to go.
