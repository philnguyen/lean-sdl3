import Common

/-!
# asyncio/load-bitmaps

Loads four `.png` files with SDL's asynchronous I/O and renders each once its
bytes arrive. A single `AsyncIOQueue` collects the completed loads; the renderer
(single-threaded) turns each finished buffer into a texture on the main thread,
in whatever order the loads happen to finish.

Port of the official example `examples/asyncio/load-bitmaps/load-bitmaps.c`
(https://examples.libsdl.org/SDL3/asyncio/load-bitmaps/).

## Deviations
- **Integer tag instead of a filename pointer**: the C original passes each
  `pngs[i]` string pointer as the load's `userdata` and, on completion, scans
  the array for the pointer that came back to recover the slot index. Lean's
  `loadFileAsync` takes a `UInt64` `userdata`, so we pass the loop index `i`
  directly and read it back as `outcome.userdata.toNat` — no pointer scan
  needed. Same effect, simpler.
- **`Examples.assetPath` instead of `SDL_GetBasePath`**: the C example builds
  each path from `SDL_GetBasePath()` (the directory the executable was run
  from, where its assets live). This repo vendors demo assets under
  `examples/assets/` and resolves them with `Examples.assetPath`, matching every
  other demo here (and giving an actionable error if run from the wrong dir).
- **Buffer freeing**: C `SDL_free(outcome.buffer)`s each load's bytes and
  `SDL_DestroySurface`s the surface. Both are GC-managed here — no explicit free.
- **Self-check gate**: under `SDL_LEAN_MAX_FRAMES` (headless smoke), `main`
  inspects a shared "loaded" counter after the run and prints `loaded 4/4 pngs`
  (exit 0) or a failure line (exit 1). The refs are created in `main` before the
  `App` is built and closed over, following `Demo/BytePusher`'s post-run-check
  shape. No such gate exists in the C original.
-/

open Sdl

/-- The four PNGs to load, in the same order as the C `pngs[]` array — the load
index is used as the async `userdata` tag. -/
def pngs : Array String :=
  #["sample.png", "gamepad_front.png", "speaker.png", "icon2x.png"]

/-- Destination rectangles for each loaded texture. C: `texture_rects[]`. -/
def textureRects : Array FRect :=
  #[ { x := 116, y := 156, w := 408, h := 167 },
     { x := 20,  y := 200, w := 96,  h := 60  },
     { x := 525, y := 180, w := 96,  h := 96  },
     { x := 288, y := 375, w := 64,  h := 64  } ]

structure State where
  window : Window
  renderer : Renderer
  queue : AsyncIOQueue
  /-- One slot per PNG; `none` until that load finishes and its texture is made. -/
  textures : IO.Ref (Array (Option Texture))
  /-- Count of successfully loaded textures, for the headless self-check. -/
  loaded : IO.Ref Nat

def app (textures : IO.Ref (Array (Option Texture))) (loaded : IO.Ref Nat) :
    App State where
  init _ := do
    setAppMetadata "Example Async IO Load Bitmaps" "1.0"
      "com.example.asyncio-load-bitmaps"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/asyncio/load-bitmaps" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    let queue ← AsyncIOQueue.create
    -- Kick off all four loads into the one queue; the index is the userdata tag.
    for i in [0:pngs.size] do
      let path ← Examples.assetPath pngs[i]!
      Sdl.loadFileAsync path.toString queue (userdata := i.toUInt64)
    return (.continue, some { window, renderer, queue, textures, loaded })
  event _ e := do
    match e with
    | .quit _ => return .success
    | _ => return .continue
  iterate s := do
    -- One completed load per frame, like the C original.
    if let some outcome ← s.queue.getResult then
      if outcome.result == .complete then
        if let some bytes := outcome.buffer then
          let surface ← Sdl.loadPNGIO (← Sdl.ioFromConstMem bytes)
          let tex ← s.renderer.createTextureFromSurface surface
          let i := outcome.userdata.toNat
          s.textures.modify (·.set! i (some tex))
          s.loaded.modify (· + 1)
      -- Non-complete outcomes (failure/cancel) are ignored, as in C.
    s.renderer.setDrawColor 0 0 0 255
    s.renderer.clear
    let texs ← s.textures.get
    for i in [0:pngs.size] do
      if let some tex := texs[i]! then
        s.renderer.texture tex none (some textureRects[i]!)
    s.renderer.present
    return .continue

def main : IO UInt32 := do
  -- Refs live in `main` so the self-check can inspect them after the run
  -- (BytePusher's post-run-check shape).
  let textures ← IO.mkRef (Array.replicate 4 (none : Option Texture))
  let loaded ← IO.mkRef 0
  let code ← Examples.runApp (app textures loaded)
  if (← IO.getEnv "SDL_LEAN_MAX_FRAMES").isSome then
    let n ← loaded.get
    if n < 4 then
      IO.eprintln s!"asyncio self-check FAILED: loaded {n}/4 pngs"
      return 1
    IO.println "loaded 4/4 pngs"
  return code
