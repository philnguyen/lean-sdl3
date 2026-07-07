import Common

/-!
# input/03-gamepad-polling

Looks for the current gamepad state once per frame and draws a visual
representation over a picture of a gamepad: green boxes on pressed buttons,
yellow boxes for the thumbsticks, and bars for the triggers. See
01-joystick-polling for the equivalent lower-level joystick example.

Port of the official example `examples/input/gamepad-polling/gamepad-polling.c`
(https://examples.libsdl.org/SDL3/input/03-gamepad-polling/).

## Deviations
- **Asset path**: the C builds the PNG path from `SDL_GetBasePath()`; we load the
  vendored `examples/assets/gamepad_front.png` via `Examples.assetPath`.
- **Open failure**: C's `SDL_OpenGamepad` returns `NULL`; the Lean `openGamepad`
  throws, so we `try`/`catch` it and log like the C does.
- Surfaces are finalizer-only in this binding, so the C `SDL_DestroySurface`
  after `createTextureFromSurface` becomes letting the surface go out of scope.
- No `Sdl.quit`; the C's `SDL_AppQuit` destroys the texture and closes the
  gamepad. Here those externals are released by finalizers at process exit (the
  video subsystem must outlive them).
-/

open Sdl

def windowWidth : Float := 640.0
def windowHeight : Float := 480.0

/-- Build an `FRect` from `Float` components. -/
private def fr (x y w h : Float) : FRect :=
  ⟨x.toFloat32, y.toFloat32, w.toFloat32, h.toFloat32⟩

/-- Where to draw each button, paired with its `SDL_GamepadButton` (the C's
`buttons[]` table, one row per enum member in order). -/
def buttonRects : Array (GamepadButton × FRect) := #[
  (.south,         ⟨497, 266, 38,  38⟩),
  (.east,          ⟨550, 217, 38,  38⟩),
  (.west,          ⟨445, 221, 38,  38⟩),
  (.north,         ⟨499, 173, 38,  38⟩),
  (.back,          ⟨235, 228, 32,  29⟩),
  (.guide,         ⟨287, 195, 69,  69⟩),
  (.start,         ⟨377, 228, 32,  29⟩),
  (.leftStick,     ⟨91,  234, 63,  63⟩),
  (.rightStick,    ⟨381, 354, 63,  63⟩),
  (.leftShoulder,  ⟨74,  73,  102, 29⟩),
  (.rightShoulder, ⟨468, 73,  102, 29⟩),
  (.dpadUp,        ⟨207, 316, 32,  32⟩),
  (.dpadDown,      ⟨207, 384, 32,  32⟩),
  (.dpadLeft,      ⟨173, 351, 32,  32⟩),
  (.dpadRight,     ⟨242, 351, 32,  32⟩),
  (.misc1,         ⟨310, 286, 23,  27⟩)]

structure State where
  window : Window
  renderer : Renderer
  texture : Texture
  gamepad : IO.Ref (Option Gamepad)
  /-- Last time each thumbstick moved (C: the two `static Uint64`s). -/
  leftThumbLast : IO.Ref UInt64
  rightThumbLast : IO.Ref UInt64

/-- Yellow box for a thumbstick, drawn only if it moved in the last half-second.
`base*` is the box origin at rest. -/
def drawThumb (r : Renderer) (g : Gamepad) (now : UInt64) (last : IO.Ref UInt64)
    (ax ay : GamepadAxis) (baseX baseY : Float) : IO Unit := do
  let axisX ← g.getAxis ax
  let axisY ← g.getAxis ay
  -- zero means centered, but it might be a little off zero...
  if axisX.toInt.natAbs > 1000 || axisY.toInt.natAbs > 1000 then
    last.set now  -- keep drawing, we're still moving.
  if (now - (← last.get)) < 500 then
    let boxX := baseX + ((axisX.toFloat / 32767.0) * 30.0)
    let boxY := baseY + ((axisY.toFloat / 32767.0) * 30.0)
    r.fillRect (some (fr boxX boxY 30.0 30.0))

/-- Yellow bar for a trigger. -/
def drawTrigger (r : Renderer) (g : Gamepad) (axis : GamepadAxis) (x : Float) : IO Unit := do
  let axisY ← g.getAxis axis
  if axisY > 1000 then  -- zero means unpressed, but it might be a little off zero...
    let height := (axisY.toFloat / 32767.0) * 65.0
    r.fillRect (some (fr x (1.0 + (65.0 - height)) 37.0 height))

/-- Draw the whole gamepad picture with the live state on top. -/
def drawGamepad (r : Renderer) (texture : Texture) (g : Gamepad) (now : UInt64)
    (leftThumbLast rightThumbLast : IO.Ref UInt64) : IO Unit := do
  -- draw the gamepad picture to the whole window.
  r.texture texture none none
  -- green boxes over buttons that are currently pressed.
  r.setDrawColor 0x00 0xFF 0x00 0xFF
  for (btn, rect) in buttonRects do
    if (← g.getButton btn) then
      r.fillRect (some rect)
  r.setDrawColor 0xFF 0xFF 0x00 0xFF  -- yellow
  drawThumb r g now leftThumbLast .leftx .lefty 107.0 252.0
  drawThumb r g now rightThumbLast .rightx .righty 397.0 370.0
  drawTrigger r g .leftTrigger 127.0
  drawTrigger r g .rightTrigger 481.0

def app : App State where
  init := fun _args => do
    setAppMetadata "Example Input Gamepad Polling" "1.0"
      "com.example.input-gamepad-polling"
    Sdl.init (.video ||| .gamepad)
    let (window, renderer) ←
      createWindowAndRenderer "examples/input/gamepad-polling" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .stretch
    -- Load the .png into a surface, then move it to a texture.
    let surface ← loadPNG (← Examples.assetPath "gamepad_front.png").toString
    let texture ← renderer.createTextureFromSurface surface
    let gamepad ← IO.mkRef none
    let leftThumbLast ← IO.mkRef 0xFFFFFFFF
    let rightThumbLast ← IO.mkRef 0xFFFFFFFF
    return (.continue, some { window, renderer, texture, gamepad, leftThumbLast, rightThumbLast })
  event := fun s e => do
    match e with
    | .quit _ => return .success
    | .gamepadAdded e =>
      -- sent for each hotplugged gamepad, but also each already-connected one at init.
      if (← s.gamepad.get).isNone then  -- we don't have one yet, open it!
        try
          s.gamepad.set (some (← openGamepad e.which))
        catch ex =>
          Sdl.log s!"Failed to open gamepad ID {e.which.val}: {ex}"
      return .continue
    | .gamepadRemoved e =>
      if let some g ← s.gamepad.get then
        if (← g.getID) == e.which then
          g.close  -- our controller was unplugged.
          s.gamepad.set none
      return .continue
    | _ => return .continue
  iterate := fun s => do
    let r := s.renderer
    let now ← getTicks
    let gamepad? ← s.gamepad.get
    let text ← match gamepad? with
      | some g => g.name
      | none   => pure "Plug in a gamepad, please."
    r.setDrawColor 0xFF 0xFF 0xFF 0xFF  -- white
    r.clear
    if let some g := gamepad? then
      drawGamepad r s.texture g now s.leftThumbLast s.rightThumbLast
    let cs := debugTextFontCharacterSize.toFloat
    let x := (windowWidth - (text.length.toFloat * cs)) / 2.0
    let y := if gamepad?.isSome then windowHeight - (cs + 2.0) else (windowHeight - cs) / 2.0
    r.setDrawColor 0x00 0x00 0xFF 0xFF  -- blue
    r.debugText x.toFloat32 y.toFloat32 text
    r.present
    return .continue

def main : IO UInt32 := Examples.runApp app
