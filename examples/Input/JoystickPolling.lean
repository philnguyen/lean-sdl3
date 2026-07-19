import Common

/-!
# input/01-joystick-polling

Looks for the current joystick state once per frame and draws a visual
representation of it (axes as bars across the middle, buttons as blocks across
the top, hats as crosses along the bottom). SDL can handle multiple joysticks,
but for simplicity this program only deals with the first stick it sees.

Port of the official example `examples/input/joystick-polling/joystick-polling.c`
(https://examples.libsdl.org/SDL3/input/01-joystick-polling/).

## Deviations
- **Colors**: the C fills `colors[64]` with `SDL_rand(255)`. We use `IO.rand`;
  the palette is cosmetic and the exact values do not affect behavior.
- **Open failure**: C's `SDL_OpenJoystick` returns `NULL` on failure; the Lean
  `openJoystick` throws, so we `try`/`catch` it and log like the C does.
- No `Sdl.quit`; the C's `SDL_AppQuit` closes the joystick. Here the opened
  `Joystick` is released by its finalizer at process exit (same policy as the
  other demos — the video subsystem must outlive the render externals).
-/

open Sdl

/-- Build an `FRect` from `Float` components (renderer rects are `Float32`). -/
private def fr (x y w h : Float) : FRect :=
  ⟨x.toFloat32, y.toFloat32, w.toFloat32, h.toFloat32⟩

/-- A random opaque color (C: four `SDL_rand(255)` calls, `a = 255`). -/
private def randomColor : IO Color := do
  return ⟨(← IO.rand 0 255).toUInt8, (← IO.rand 0 255).toUInt8,
          (← IO.rand 0 255).toUInt8, 255⟩

/-- Size of each drawn element (C: `const float size = 30.0f`). -/
private def size : Float := 30.0

structure State where
  window : Window
  renderer : Renderer
  /-- The one opened joystick (C: the global `joystick`). -/
  joystick : IO.Ref (Option Joystick)
  /-- 64 random colors, indexed by axis/button/hat number. -/
  colors : Array Color

/-- Draw axes as bars going across the middle of the screen. We don't know if
it's an X or Y or whatever axis, so we can't do more than this. -/
def drawAxes (r : Renderer) (j : Joystick) (colors : Array Color)
    (winw winh : Float) : IO Unit := do
  let total ← j.numAxes
  let mut y := (winh - total.toFloat * size) / 2.0
  let x := winw / 2.0
  for i in [0:total.toNatClampNeg] do
    let c := colors[i % 64]!
    -- make it -1.0f to 1.0f
    let val := (← j.getAxis (Int32.ofNat i)).toFloat / 32767.0
    let dx := x + (val * x)
    r.setDrawColor c.r c.g c.b c.a
    r.fillRect (some (fr dx y (x - Float.abs dx) size))
    y := y + size

/-- Draw buttons as blocks across the top of the window. We only know the
button numbers, but not where they are on the device. -/
def drawButtons (r : Renderer) (j : Joystick) (colors : Array Color)
    (winw : Float) : IO Unit := do
  let total ← j.numButtons
  let mut x := (winw - total.toFloat * size) / 2.0
  for i in [0:total.toNatClampNeg] do
    let c := colors[i % 64]!
    let dst := fr x 0.0 size size
    if (← j.getButton (Int32.ofNat i)) then
      r.setDrawColor c.r c.g c.b c.a
    else
      r.setDrawColor 0 0 0 255
    r.fillRect (some dst)
    r.setDrawColor 255 255 255 c.a
    r.rect (some dst)  -- outline it
    x := x + size

/-- Draw hats across the bottom of the screen (a grey cross with a coloured
square lit for each active direction). -/
def drawHats (r : Renderer) (j : Joystick) (colors : Array Color)
    (winw winh : Float) : IO Unit := do
  let total ← j.numHats
  let mut x := ((winw - total.toFloat * (size * 2.0)) / 2.0) + (size / 2.0)
  let y := winh - size
  for i in [0:total.toNatClampNeg] do
    let c := colors[i % 64]!
    let thirdsize := size / 3.0
    let cross := #[fr x (y + thirdsize) size thirdsize, fr (x + thirdsize) y thirdsize size]
    let hat ← j.getHat (Int32.ofNat i)
    r.setDrawColor 90 90 90 255
    r.fillRects cross
    r.setDrawColor c.r c.g c.b c.a
    if hat.has .up then
      r.fillRect (some (fr (x + thirdsize) y thirdsize thirdsize))
    if hat.has .right then
      r.fillRect (some (fr (x + (thirdsize * 2.0)) (y + thirdsize) thirdsize thirdsize))
    if hat.has .down then
      r.fillRect (some (fr (x + thirdsize) (y + (thirdsize * 2.0)) thirdsize thirdsize))
    if hat.has .left then
      r.fillRect (some (fr x (y + thirdsize) thirdsize thirdsize))
    x := x + (size * 2.0)

def app : App State where
  init _ := do
    setAppMetadata "Example Input Joystick Polling" "1.0"
      "com.example.input-joystick-polling"
    Sdl.init (.video ||| .joystick)
    let (window, renderer) ←
      createWindowAndRenderer "examples/input/joystick-polling" 640 480 .resizable
    let mut colors : Array Color := #[]
    for _ in [0:64] do
      colors := colors.push (← randomColor)
    let joystick ← IO.mkRef none
    return (.continue, some { window, renderer, joystick, colors })
  event s e := do
    match e with
    | .quit _ => return .success
    | .joystickAdded e =>
      -- this event is sent for each hotplugged stick, but also each
      -- already-connected joystick during SDL_Init().
      if (← s.joystick.get).isNone then  -- we don't have a stick yet, open it!
        try
          s.joystick.set (some (← openJoystick e.which))
        catch ex =>
          Sdl.log s!"Failed to open joystick ID {e.which.val}: {ex}"
      return .continue
    | .joystickRemoved e =>
      if let some j ← s.joystick.get then
        if (← j.getID) == e.which then
          j.close  -- our joystick was unplugged.
          s.joystick.set none
      return .continue
    | _ => return .continue
  iterate s := do
    let r := s.renderer
    let mut text := "Plug in a joystick, please."
    let joy? ← s.joystick.get
    if let some j := joy? then  -- we have a stick opened?
      text ← j.name
    r.setDrawColor 0 0 0 255
    r.clear
    let (winw, winh) ← s.window.getSize
    let winwF := winw.toFloat
    let winhF := winh.toFloat
    -- note that you can get input as events, instead of polling, which is better
    -- since it won't miss button presses if the system is lagging, but often
    -- times checking the current state per-frame is good enough.
    if let some j := joy? then
      drawAxes r j s.colors winwF winhF
      drawButtons r j s.colors winwF
      drawHats r j s.colors winwF winhF
    let cs := debugTextFontCharacterSize.toFloat
    let x := (winwF - (text.length.toFloat * cs)) / 2.0
    let y := (winhF - cs) / 2.0
    r.setDrawColor 255 255 255 255
    r.debugText x.toFloat32 y.toFloat32 text
    r.present
    return .continue

def main : IO UInt32 := Examples.runApp app
