import Common

/-!
# renderer/02-primitives

Creates an SDL window and renderer, then draws some lines, rectangles and
points to it every frame.

Port of the official example `examples/renderer/02-primitives/primitives.c`
(https://examples.libsdl.org/SDL3/renderer/02-primitives/).

## Deviations

* Randomness: the initial scatter of points uses `IO.rand` instead of
  `SDL_randf` (SDL's stdinc RNG is unbound by design). Statistical quality is
  irrelevant here.
* `quit` is omitted: SDL cleans up the window/renderer at process exit (see
  `examples/Common.lean`).
-/

open Sdl

structure State where
  window : Window
  renderer : Renderer
  /-- A fixed scatter of 500 random points, computed once at startup. -/
  points : Array FPoint

def app : App State where
  init _ := do
    setAppMetadata "Example Renderer Primitives" "1.0" "com.example.renderer-primitives"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/renderer/primitives" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    -- set up some random points
    let mut points := Array.emptyWithCapacity 500
    for _ in [0:500] do
      let rx := (← IO.rand 0 999999).toFloat / 1000000.0
      let ry := (← IO.rand 0 999999).toFloat / 1000000.0
      points := points.push { x := (rx * 440.0 + 100.0).toFloat32, y := (ry * 280.0 + 100.0).toFloat32 }
    return (.continue, some { window, renderer, points })
  event _ e := do
    if let .quit _ := e then return .success
    return .continue
  iterate s := do
    -- as you can see from this, rendering draws over whatever was drawn before it.
    s.renderer.setDrawColor 33 33 33 255  -- dark gray, full alpha
    s.renderer.clear                       -- start with a blank canvas.
    -- draw a filled rectangle in the middle of the canvas.
    s.renderer.setDrawColor 0 0 255 255    -- blue, full alpha
    s.renderer.fillRect (some { x := 100, y := 100, w := 440, h := 280 })
    -- draw some points across the canvas.
    s.renderer.setDrawColor 255 0 0 255    -- red, full alpha
    s.renderer.points s.points
    -- draw an unfilled rectangle in-set a little bit.
    s.renderer.setDrawColor 0 255 0 255    -- green, full alpha
    s.renderer.rect (some { x := 130, y := 130, w := 380, h := 220 })
    -- draw two lines in an X across the whole canvas.
    s.renderer.setDrawColor 255 255 0 255  -- yellow, full alpha
    s.renderer.line 0 0 640 480
    s.renderer.line 0 480 640 0
    s.renderer.present                     -- put it all on the screen!
    return .continue

def main : IO UInt32 := Examples.runApp app
