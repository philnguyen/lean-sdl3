import Common

/-!
# input/05-gamepad-rumble

Rumbles gamepads on button presses: the "south" face button triggers a
high-frequency rumble, "east" a low-frequency one, and releasing any button
stops the rumble. Reports each connected gamepad and its current action.

Port of the official MAIN-branch example
`examples/input/gamepad-rumble/gamepad-rumble.c`
(https://examples.libsdl.org/SDL3/input/05-gamepad-rumble/). It is not present in
the 3.4.10 source tree, but every API it uses exists in 3.4.10.

## Deviations
- **Slot handles**: the C `GamepadInfo[16]` table stores an id + action string and
  re-fetches the gamepad with `SDL_GetGamepadFromID` for rumble. In this binding a
  discarded `Gamepad` handle would be closed by its finalizer immediately, so we
  retain the opened handle *in its slot* and reuse it for rumble. A slot is
  therefore filled only when the open succeeds (the C fills it regardless and would
  rumble a NULL handle — a no-op — on failure). Empty slots still render as blank
  lines, keeping the fixed 16-row display.
- `rumble` returns `IO Bool`; we discard it with `let _ ←`, as the C ignores it.
- `quit` calls `Sdl.quit`, mirroring the C's `SDL_AppQuit` (`SDL_Quit()`).
-/

open Sdl

/-- One display row: the gamepad id, its retained handle, and its current action. -/
abbrev Slot := JoystickId × Gamepad × String

structure State where
  window : Window
  renderer : Renderer
  /-- 16 fixed rows; `none` is an empty slot. C: `gamepads_info[16]`. -/
  slots : IO.Ref (Array (Option Slot))

/-- The slot for gamepad `which`, if any. C: `FindGamepadInfo`. -/
def findSlot (arr : Array (Option Slot)) (which : JoystickId) : Option Slot :=
  (arr.filterMap id).find? (·.1 == which)

/-- Fill the first empty slot with `v` (ignored if all 16 are full). -/
def fillFirstEmpty (arr : Array (Option Slot)) (v : Slot) : Array (Option Slot) :=
  match arr.findIdx? (·.isNone) with
  | some i => arr.set! i (some v)
  | none   => arr

/-- Set the action string of the slot with id `which`. -/
def setAction (arr : Array (Option Slot)) (which : JoystickId) (action : String) :
    Array (Option Slot) :=
  arr.map fun
    | some (id, g, a) => some (id, g, if id == which then action else a)
    | none            => none

/-- Clear (empty) the slot with id `which`. -/
def clearSlot (arr : Array (Option Slot)) (which : JoystickId) : Array (Option Slot) :=
  arr.map fun
    | some (id, g, a) => if id == which then none else some (id, g, a)
    | none            => none

/-- Center a line of text and advance `y` by two character rows (blank strings
still advance, leaving a blank line). C: `draw_centered_text`. -/
def drawCenteredText (r : Renderer) (rw y : Int32) (str : String) : IO Int32 := do
  let x := (rw - (Int32.ofNat str.length * debugTextFontCharacterSize)) / 2
  if str != "" then
    r.debugText x.toFloat.toFloat32 y.toFloat.toFloat32 str
  return y + debugTextFontCharacterSize * 2

def app : App State where
  init := fun _args => do
    setAppMetadata "Example Input Gamepad Rumble" "1.0"
      "com.example.input-gamepad-rumble"
    Sdl.init (.video ||| .gamepad)
    let (window, renderer) ←
      createWindowAndRenderer "examples/input/gamepad-rumble" 640 480 .resizable
    let slots ← IO.mkRef (Array.replicate 16 none)
    return (.continue, some { window, renderer, slots })
  event := fun s e => do
    match e with
    | .quit _ => return .success
    | .gamepadAdded e =>
      -- sent for each hotplugged stick, but also each already-connected one at init.
      try
        let g ← openGamepad e.which
        s.slots.modify (fillFirstEmpty · (e.which, g, "idle"))
      catch _ => pure ()
      return .continue
    | .gamepadRemoved e =>
      if let some (_, g, _) := findSlot (← s.slots.get) e.which then
        g.close
      s.slots.modify (clearSlot · e.which)
      return .continue
    | .gamepadButtonDown e =>
      if let some (_, g, _) := findSlot (← s.slots.get) e.which then
        match GamepadButton.ofVal e.button with
        | .south =>
          let _ ← g.rumble 0xFFFF 0x0000 5000
          s.slots.modify (setAction · e.which "rumble high frequency")
        | .east =>
          let _ ← g.rumble 0x0000 0xFFFF 5000
          s.slots.modify (setAction · e.which "rumble low frequency")
        | _ => pure ()
      return .continue
    | .gamepadButtonUp e =>
      if let some (_, g, _) := findSlot (← s.slots.get) e.which then
        let _ ← g.rumble 0x0000 0x0000 0
        s.slots.modify (setAction · e.which "idle")
      return .continue
    | _ => return .continue
  iterate := fun s => do
    let r := s.renderer
    let (rw, _rh) ← r.getCurrentOutputSize
    r.setDrawColor 0 0 0 255  -- clear to black
    r.clear
    let mut y : Int32 := debugTextFontCharacterSize * 8
    r.setDrawColor 255 255 0 255  -- yellow text
    y ← drawCenteredText r rw y "Connect gamepads and press buttons to rumble."
    y := y + debugTextFontCharacterSize * 3
    -- report all the visible gamepads and what they are doing at the moment.
    r.setDrawColor 255 255 255 255  -- white text
    for slot in (← s.slots.get) do
      match slot with
      | none => y ← drawCenteredText r rw y ""  -- just leave a blank line.
      | some (id, _, action) => y ← drawCenteredText r rw y s!"{← id.gamepadName}: {action}"
    r.present
    return .continue
  quit := fun _ _ => Sdl.quit

def main : IO UInt32 := Examples.runApp app
