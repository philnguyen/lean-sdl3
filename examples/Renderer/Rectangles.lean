import Common

/-!
# renderer/05-rectangles

Creates an SDL window and renderer, then draws some rectangles to it every
frame.

Port of the official example `examples/renderer/05-rectangles/rectangles.c`
(https://examples.libsdl.org/SDL3/renderer/05-rectangles/).

## Deviations

* `quit` is omitted: SDL cleans up the window/renderer at process exit (see
  `examples/Common.lean`).
-/

open Sdl

def windowWidth : Float32 := 640
def windowHeight : Float32 := 480

structure State where
  window : Window
  renderer : Renderer

def app : App State where
  init _ := do
    setAppMetadata "Example Renderer Rectangles" "1.0" "com.example.renderer-rectangles"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/renderer/rectangles" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    return (.continue, some { window, renderer })
  event _ e := do
    if let .quit _ := e then return .success
    return .continue
  iterate s := do
    let now ← getTicks
    -- we'll have the rectangles grow and shrink over a few seconds.
    let direction : Float32 := if now % 2000 >= 1000 then 1.0 else -1.0
    let scale : Float32 := (((now % 1000).toFloat - 500.0) / 500.0).toFloat32 * direction
    -- as you can see from this, rendering draws over whatever was drawn before it.
    s.renderer.setDrawColor 0 0 0 255        -- black, full alpha
    s.renderer.clear                          -- start with a blank canvas.
    -- Rectangles are comprised of set of X and Y coordinates, plus width and
    -- height. (0, 0) is the top left of the window, and larger numbers go
    -- down and to the right. This isn't how geometry works, but this is
    -- pretty standard in 2D graphics.

    -- Let's draw a single rectangle (square, really).
    let side := 100 + 100 * scale
    s.renderer.setDrawColor 255 0 0 255      -- red, full alpha
    s.renderer.rect (some { x := 100, y := 100, w := side, h := side })
    -- Now let's draw several rectangles with one function call.
    let mut rects : Array FRect := #[]
    for i in [0:3] do
      let size := (i + 1).toFloat.toFloat32 * 50.0
      let wh := size + size * scale
      rects := rects.push {
        x := (windowWidth - wh) / 2,   -- center it.
        y := (windowHeight - wh) / 2,  -- center it.
        w := wh, h := wh }
    s.renderer.setDrawColor 0 255 0 255      -- green, full alpha
    s.renderer.rects rects                    -- draw three rectangles at once
    -- those were rectangle _outlines_, really. You can also draw _filled_ rectangles!
    s.renderer.setDrawColor 0 0 255 255      -- blue, full alpha
    s.renderer.fillRect (some { x := 400, y := 50, w := 100 + 100 * scale, h := 50 + 50 * scale })
    -- ...and also fill a bunch of rectangles at once...
    let mut fills : Array FRect := #[]
    for i in [0:16] do
      let w := windowWidth / 16.0
      let h := i.toFloat.toFloat32 * 8.0
      fills := fills.push { x := i.toFloat.toFloat32 * w, y := windowHeight - h, w, h }
    s.renderer.setDrawColor 255 255 255 255  -- white, full alpha
    s.renderer.fillRects fills
    s.renderer.present                        -- put it all on the screen!
    return .continue

def main : IO UInt32 := Examples.runApp app
