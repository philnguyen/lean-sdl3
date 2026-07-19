import Common

/-!
# renderer/03-lines

Creates an SDL window and renderer, then draws some lines to it every frame.

Port of the official example `examples/renderer/03-lines/lines.c`
(https://examples.libsdl.org/SDL3/renderer/03-lines/).

## Deviations

* Randomness: the per-line colors of the circle animation use `IO.rand`
  instead of `SDL_rand` (SDL's stdinc RNG is unbound by design). Statistical
  quality is irrelevant here.
* `quit` is omitted: SDL cleans up the window/renderer at process exit (see
  `examples/Common.lean`).
-/

open Sdl

structure State where
  window : Window
  renderer : Renderer

/-- Lines (line segments, really) are drawn in terms of points: a set of
X and Y coordinates, one set for each end of the line.
(0, 0) is the top left of the window, and larger numbers go down
and to the right. This isn't how geometry works, but this is pretty
standard in 2D graphics. -/
def linePoints : Array FPoint := #[
  { x := 100, y := 354 }, { x := 220, y := 230 }, { x := 140, y := 230 },
  { x := 320, y := 100 }, { x := 500, y := 230 }, { x := 420, y := 230 },
  { x := 540, y := 354 }, { x := 400, y := 354 }, { x := 100, y := 354 }
]

def app : App State where
  init _ := do
    setAppMetadata "Example Renderer Lines" "1.0" "com.example.renderer-lines"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/renderer/lines" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    return (.continue, some { window, renderer })
  event _ e := do
    if let .quit _ := e then return .success
    return .continue
  iterate s := do
    -- as you can see from this, rendering draws over whatever was drawn before it.
    s.renderer.setDrawColor 100 100 100 255  -- grey, full alpha
    s.renderer.clear                          -- start with a blank canvas.
    -- You can draw lines, one at a time, like these brown ones...
    s.renderer.setDrawColor 127 49 32 255
    s.renderer.line 240 450 400 450
    s.renderer.line 240 356 400 356
    s.renderer.line 240 356 240 450
    s.renderer.line 400 356 400 450
    -- You can also draw a series of connected lines in a single batch...
    s.renderer.setDrawColor 0 255 0 255
    s.renderer.lines linePoints
    -- here's a bunch of lines drawn out from a center point in a circle.
    -- we randomize the color of each line, so it functions as animation.
    for i in [0:360] do
      let size := 30.0
      let x := 320.0
      let y := 95.0 - size / 2.0
      let r := i.toFloat * (Examples.pi / 180.0)
      let cr := (← IO.rand 0 255).toUInt8
      let cg := (← IO.rand 0 255).toUInt8
      let cb := (← IO.rand 0 255).toUInt8
      s.renderer.setDrawColor cr cg cb 255
      s.renderer.line x.toFloat32 y.toFloat32
        (x + Float.cos r * size).toFloat32 (y + Float.sin r * size).toFloat32
    s.renderer.present                        -- put it all on the screen!
    return .continue

def main : IO UInt32 := Examples.runApp app
