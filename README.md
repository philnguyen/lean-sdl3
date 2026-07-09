# lean-sdl3

[![CI](https://github.com/philnguyen/lean-sdl3/actions/workflows/lean_action_ci.yml/badge.svg)](https://github.com/philnguyen/lean-sdl3/actions/workflows/lean_action_ci.yml)

Comprehensive [Lean 4](https://lean-lang.org) bindings for
[SDL3](https://wiki.libsdl.org/SDL3/FrontPage) and
[SDL3_ttf](https://wiki.libsdl.org/SDL3_ttf/FrontPage), plus Lean ports of the
[official SDL3 examples](https://examples.libsdl.org/SDL3/) as runnable demos.

- **~1,050 bound functions** across every functional SDL3 subsystem: video,
  rendering, events, input (keyboard/mouse/joystick/gamepad/sensor/haptic/pen/touch),
  audio, camera, GPU (SDL_gpu), surfaces/pixels, properties, IO streams,
  async IO, storage, process, dialogs, clipboard, tray, timers, and more —
  plus all 117 SDL_ttf functions (`Sdl.Ttf`).
- **Typed throughout**: enums are inductives with exhaustive `match`, bit
  flags and IDs are dedicated structs, handles are opaque types with
  GC-managed lifetimes, failures are `IO` exceptions carrying `SDL_GetError()`.
- **40 demos**, one `lake exe` per official example, all smoke-tested headless
  in CI.

Developed against SDL 3.4.10 / SDL_ttf 3.2.2 on macOS (Apple Silicon), Lean
toolchain `v4.31.0`. CI builds and tests on both macOS and Linux (see
[Portability](#portability)). Windows is untested — reports and PRs welcome.

## Quick start

```sh
# Prerequisites: elan (Lean toolchain manager) and SDL3
brew install sdl3 sdl3_ttf     # macOS. Linux: no distro packages yet — build
                               # SDL3/SDL3_ttf from source (recipe: the Linux
                               # job in .github/workflows/lean_action_ci.yml)

lake build                     # builds the library, C shims, tests, and demos
lake exe sdl                   # prints the linked SDL version — a smoke test
lake exe renderer-01-clear     # opens a window fading through colors
```

Run any demo from the repository root (assets are resolved relative to it).
Close the window or press Ctrl-C to quit.

## A taste

Demos mirror SDL3's callback-style app shape (`SDL_AppInit`/`Event`/`Iterate`/`Quit`)
via `Sdl.App`, driven by an ordinary Lean `main` — SDL never owns process
entry. This is [`examples/Renderer/Clear.lean`](examples/Renderer/Clear.lean),
lightly trimmed:

```lean
import Sdl
open Sdl

structure State where
  window : Window
  renderer : Renderer

def app : App State where
  init := fun _args => do
    Sdl.init .video
    let (window, renderer) ← createWindowAndRenderer "clear" 640 480 .resizable
    return (.continue, some { window, renderer })
  event := fun _ e => do
    if let .quit _ := e then return .success
    return .continue
  iterate := fun s => do
    let now := (← getTicks).toFloat / 1000.0
    s.renderer.setDrawColorFloat (0.5 + 0.5 * Float.sin now).toFloat32 0.3 0.6 1.0
    s.renderer.clear
    s.renderer.present
    return .continue

def main : IO UInt32 := app.run
```

Direct imperative style works too — every binding is an ordinary `IO` action.
One rule: call video/event/render APIs from `main` (the OS main thread), never
from a `Task`.

## Demos

One `lean_exe` per official example, named after the upstream directory
(`lake exe <name>`). Gaps in renderer numbering (12, 13, 16) exist upstream too.

| Demo | Shows |
|---|---|
| `renderer-01-clear` | clear the window to a color each frame |
| `renderer-02-primitives` | points, lines, rects, fills |
| `renderer-03-lines` · `renderer-04-points` · `renderer-05-rectangles` | each primitive in depth |
| `renderer-06-textures` | PNG → `Surface` → `Texture` → draw |
| `renderer-07-streaming-textures` | per-frame pixel upload via texture lock |
| `renderer-08-rotating-textures` · `renderer-09-scaling-textures` | `renderTextureRotated`, scaled draws |
| `renderer-10-geometry` | raw vertex geometry (`renderGeometry`) |
| `renderer-11-color-mods` | per-texture color modulation |
| `renderer-14-viewport` · `renderer-15-cliprect` | viewports and clip rectangles |
| `renderer-17-read-pixels` | render-target readback into a surface |
| `renderer-18-debug-text` | built-in debug-text drawing |
| `renderer-19-affine-textures` | affine (3-point) texture mapping |
| `renderer-20-blending` | blend modes, incl. custom composed ones |
| `audio-01-simple-playback` | sine wave pushed to an audio stream |
| `audio-02-simple-playback-callback` | stream feed via audio-thread callback |
| `audio-03-load-wav` | WAV loading and playback |
| `audio-04-multiple-streams` | several streams mixed on one device |
| `audio-05-planar-data` | planar (non-interleaved) stream input |
| `input-01-joystick-polling` · `input-02-joystick-events` | joystick state / event handling |
| `input-03-gamepad-polling` · `input-04-gamepad-events` | gamepad state / event handling |
| `input-05-gamepad-rumble` | rumble effects |
| `camera-01-read-and-draw` | webcam frames drawn to the window |
| `pen-01-drawing-lines` | pressure-sensitive pen drawing |
| `misc-01-power` · `misc-02-clipboard` · `misc-03-locale` | power status, clipboard, locales |
| `asyncio-01-load-bitmaps` | async file loading via an AsyncIO queue |
| `storage-01-user` | user-storage save/load round-trip |
| `demo-01-snake` | the classic, on a grid |
| `demo-02-woodeneye-008` | minimal split-screen FPS |
| `demo-03-infinite-monkeys` | text generation with debug text |
| `demo-04-bytepusher <rom>` | BytePusher VM (try `examples/assets/hello.BytePusher`) |
| `gpu-01-clear` | SDL_gpu swapchain clear (Metal on macOS) |
| `ttf-01-hello` | SDL_ttf text rendering via a renderer text engine |

All demos honor `SDL_LEAN_MAX_FRAMES=<n>` (exit successfully after n frames),
which is how CI smoke-runs them windowless:

```sh
scripts/smoke-examples.sh        # every demo, 60 frames, dummy drivers
```

## Tests

```sh
SDL_VIDEO_DRIVER=dummy SDL_AUDIO_DRIVER=dummy SDL_CAMERA_DRIVER=dummy lake exe test
```

800+ runtime checks (event decode round-trips, callback bridges, ownership
stress, renderer pixel checks, …), all passing headless — this is what CI
runs on macOS and Linux. Groups that need real hardware (GPU/Metal, camera)
detect the dummy driver and assert the skip path instead.

- `SDL_LEAN_TEST_GROUP=<Name>` runs a single group (e.g. `Render`, `Ttf`).
- Omitting the dummy drivers exercises real backends: windows will flash by,
  and **without `SDL_CAMERA_DRIVER=dummy` the camera tests trigger the macOS
  camera-permission prompt**.

Pure-logic properties are tested at compile time with `#guard` right next to
their definitions; C-side ABI facts (enum values, struct sizes) are pinned by
`_Static_assert`s in `ffi/consts_check.c`, so a mismatch is a build error.

## Binding conventions (the short version)

Names are derived mechanically from C: drop `SDL_`, lowerCamelCase
(`SDL_CreateWindow` → `createWindow`); `TTF_`/`GPU` become the `Sdl.Ttf` /
`Sdl.Gpu` namespaces; constants become enum members (`SDL_BLENDMODE_BLEND` →
`BlendMode.blend`). **Every binding's doc comment cites the exact C name**, so
`grep -r SDL_CreateWindow Sdl/` finds the Lean equivalent.

- Fallible C functions throw `IO` errors carrying `SDL_GetError()` — no bool
  returns to check.
- Closed C enums are `inductive`s (exhaustive `match`); version-open enums add
  an `other (raw)` constructor; bit flags and open ID domains are one-field
  structs with named constants. All generated by the macro kit in
  `Sdl/Core/Macros.lean` (`sdl_enum`, `sdl_enum_open`, `sdl_flags`, `sdl_id`,
  `sdl_opaque`).
- Handles (`Window`, `Renderer`, `Texture`, `Font`, …) are opaque types freed
  by the GC in dependency order (a `Texture` keeps its `Renderer` alive, a
  `Ttf.Text` keeps its engine and font alive). Where prompt disposal matters a
  manual `destroy` exists and later use throws instead of crashing.
- Callbacks (timers, audio streams, dialogs, …) are plain Lean closures;
  trampolines handle cross-thread invocation safely.

The full architecture — ownership archetypes, the event-decode scheme, the
three callback primitives, GPU typestate, threading rules — is in
[`docs/DESIGN.md`](docs/DESIGN.md).

### What is deliberately not bound

libc clones from `SDL_stdinc.h` (use Lean's stdlib), SDL threads/mutexes/atomics
(use `Task`/`IO.Ref`), hidapi, the vendored GL/EGL/Vulkan headers, `SDL_test`,
and non-macOS parts of `SDL_system.h`.

## Portability

Header and link-flag discovery are both dynamic (pkg-config →
`brew --prefix` → standard prefixes, with an actionable error if headers are
nowhere to be found); discovered library dirs get an rpath, so binaries run
without `LD_LIBRARY_PATH`. CI exercises macOS (Homebrew SDL) and Linux
(Ubuntu, SDL3 + SDL3_ttf built from source since no distro package exists
yet): full build, the 800+ tests, and all-40-demo headless smoke on both.
Windows is not supported yet — the C shims are portable C11, but the build
discovery and the `LEAN_MAIN_USE_THREAD` constructor are POSIX-only.

## Contributing

Read [`AGENTS.md`](AGENTS.md) (project conventions) and
[`docs/DESIGN.md`](docs/DESIGN.md) (architecture) first. The layout:

```
Sdl/<Module>.lean   Lean API for one SDL_<module>.h  (types, docs, @[extern] decls)
ffi/<module>.c      its C shim (error → IO exception, handle wrap/unwrap)
ffi/classes.h       shared external-class declarations
ffi/consts_check.c  _Static_asserts pinning every mirrored C constant
test/Tests/<Module>.lean  runtime checks, registered in test/Tests.lean
examples/<Category>/<Name>.lean  demos (exe targets in lakefile.lean)
```

To add or extend a binding: follow an existing module of the same shape, use
the macro kit rather than hand-rolling enum/flag boilerplate, put `#guard`
tests directly below pure definitions, cite the C name in every doc comment,
and add runtime tests for anything that depends on the linked SDL. Keep
commits small and self-contained.

## License

Apache-2.0 (see [`LICENSE`](LICENSE)). The files under `examples/assets/` are
copied from the SDL repository's `test/` directory and remain under SDL's
zlib license (see `examples/assets/README.md`).
