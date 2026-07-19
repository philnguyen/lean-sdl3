import Common

/-!
# pen/drawing-lines

Reads pen/stylus input and draws lines into a render-target texture: darker
lines for harder pressure (the pressure is used as the stroke's alpha). SDL can
track multiple pens; for simplicity this assumes any pen input is from one device.

Port of the official example `examples/pen/drawing-lines/drawing-lines.c`
(https://examples.libsdl.org/SDL3/pen/drawing-lines/).

## Deviations
- None. (Headless there are no pen events, so nothing is drawn to the target,
  but the demo still clears, blits the target, renders debug text, and exits 0
  under the frame cap.)

The persistent strokes live on a target-access texture so a frame is a single
texture draw rather than a replay of every stroke.
-/

open Sdl

structure State where
  renderer : Renderer
  /-- Persistent stroke canvas (target-access RGBA8888, output-sized). -/
  renderTarget : Texture
  pressure : IO.Ref Float32
  /-- Previous touch point; `< 0` means "pen not currently down". -/
  prevX : IO.Ref Float32
  prevY : IO.Ref Float32
  tiltX : IO.Ref Float32
  tiltY : IO.Ref Float32

def app : App State where
  init _ := do
    setAppMetadata "Example Pen Drawing Lines" "1.0" "com.example.pen-drawing-lines"
    Sdl.init .video
    let (_window, renderer) ←
      createWindowAndRenderer "examples/pen/drawing-lines" 640 480
    -- Match the render target to the output size (for hidpi displays, etc.) so
    -- drawing matches the pen's position on a tablet display.
    let (w, h) ← renderer.getOutputSize
    let renderTarget ← renderer.createTexture .rgba8888 .target w h
    -- Blank the render target to gray to start.
    renderer.setTarget (some renderTarget)
    renderer.setDrawColor 100 100 100 255
    renderer.clear
    renderer.setTarget none
    renderer.setDrawBlendMode .blend
    let pressure ← IO.mkRef (0.0 : Float32)
    let prevX ← IO.mkRef (-1.0 : Float32)
    let prevY ← IO.mkRef (-1.0 : Float32)
    let tiltX ← IO.mkRef (0.0 : Float32)
    let tiltY ← IO.mkRef (0.0 : Float32)
    return (.continue, some { renderer, renderTarget, pressure, prevX, prevY, tiltX, tiltY })
  event s e := do
    match e with
    | .quit _ => return .success
    -- We only look at motion and pressure, for simplicity.
    | .penMotion pm =>
      -- pressure > 0 ⇒ the pen is definitely touching.
      if (← s.pressure.get) > 0.0 then
        if (← s.prevX.get) ≥ 0.0 then  -- only draw while moving *and* touching
          -- Draw with alpha = pressure: fainter lines for lighter presses.
          s.renderer.setTarget (some s.renderTarget)
          s.renderer.setDrawColorFloat 0 0 0 (← s.pressure.get)
          s.renderer.line (← s.prevX.get) (← s.prevY.get) pm.x pm.y
        s.prevX.set pm.x
        s.prevY.set pm.y
      else
        s.prevX.set (-1.0)
        s.prevY.set (-1.0)
      return .continue
    | .penAxis pa =>
      -- PenAxis is version-open, so the match needs a catch-all arm.
      match pa.axis with
      | .pressure => s.pressure.set pa.value  -- remember for later draws
      | .xTilt => s.tiltX.set pa.value
      | .yTilt => s.tiltY.set pa.value
      | _ => pure ()
      return .continue
    | _ => return .continue
  iterate s := do
    -- Make sure we're drawing to the window and not the render target.
    s.renderer.setTarget none
    s.renderer.setDrawColor 0 0 0 255
    s.renderer.clear                              -- just in case
    s.renderer.texture s.renderTarget none none
    s.renderer.debugText 0 8 s!"Tilt: {← s.tiltX.get} {← s.tiltY.get}"
    s.renderer.present
    return .continue

def main : IO UInt32 := Examples.runApp app
