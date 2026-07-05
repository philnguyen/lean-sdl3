## Overview

This project declares Lean's FFI for [SDL3](https://wiki.libsdl.org/SDL3/FrontPage).

## Building
- build: `lake build`
- run: `lake exe <target-name>`
- clean: `lake clean`
- display a graceful, actionable error message if SDL3 cannot be found on the user's machine

## Bindings
- Derive names mechanically from the C API: drop the `SDL_` prefix and lowerCamelCase functions (`SDL_CreateWindow` → `createWindow`; `SDL_GetIOSize` → `getIOSize`); the `TTF_` prefix and the GPU API's `GPU` marker become the `Sdl.Ttf` / `Sdl.Gpu` namespaces; enum constants become lowerCamelCase members (`SDL_BLENDMODE_BLEND` → `BlendMode.blend`). Cite the exact C name in every binding's doc comment so it is greppable.
- Bindings should be in `IO` monad if they are effectful
- Look for opportunities to rule out mistakes on Lean's end over the raw C API, if runtime overhead is minimal and client side use is uncomplicated. For example:
  * Define `inductive` or 1-field `structure` to provide proper abstractions for enums, bit flags, or opaque IDs, instead of C's raw integers.
  * Possibly use a dependent tuple to represent one like `SDL_Event`.
  * Enforce protocol/typestate such as the command buffer in the GPU API.
- For common declaration patterns (such as above, and more), generate helper macros or functions to ensure consistency and reduce boilerplates and mistakes. The bindings will be maintained and extended by both AI and humans.

## Testing
- For definitions on Lean's end, write plenty of tests, on edge and common cases.
- Prefer `#guard`/`#guard_expr`/`#guard_msg` commands or `example` with proofs for pure, compile-time tests. Such tests should be written as early as possible, right below the definition(s) they refer to (i.e. don't defer compile-time tests towards the end).
- Use run-time tests under `test/` when correctness depends on the linked SDL at runtime (e.g. cross-validation, the event poll/decode pipeline, callback bridges, things `#guard` cannot verify).

## Version control
- Make small, self-contained commits
- Keep commit messages concise
