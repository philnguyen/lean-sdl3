import Common

/-!
# input/04-gamepad-events

Looks for gamepad input in the event handler and reports any changes as a flood
of on-screen info (the higher-level counterpart to 02-joystick-events).

Port of the official example `examples/input/gamepad-events/gamepad-events.c`
(https://examples.libsdl.org/SDL3/input/04-gamepad-events/).

## Deviations
- **Message list**: same `Array Message` model as 02-joystick-events (the C's
  intrusive linked list); helper code is duplicated on purpose — examples are
  self-contained and share no modules.
- **Removal & ownership**: C closes the gamepad via `SDL_GetGamepadFromID`, which
  in this binding hands back a *fresh* handle owning its own reference; so we
  track opened gamepads in `openedGamepads : IO.Ref (Array (JoystickId × Gamepad))`
  and close+drop the matching one on removal.
- **Open failure**: C's `SDL_OpenGamepad` returns `NULL`; the Lean `openGamepad`
  throws, so the "added but not opened" message comes from a `catch`.
- **Axis/button strings**: `getGamepadStringFor{Axis,Button}` returns `Option`; we
  fall back to `"unknown"` where the C would print SDL's raw result.
- `PowerState` has no `ERROR` member here, so the C's `"ERROR"` battery string is
  unreachable.
- `quit` calls `Sdl.quit`, mirroring the C's `SDL_AppQuit` (`SDL_Quit()`).
-/

open Sdl

private def msgLifetime : Float := 3500.0

/-- Spammy axis events only show every this-many milliseconds. C: `MOTION_EVENT_COOLDOWN`. -/
private def motionEventCooldown : UInt64 := 40

/-- One scrolling status line. C: `struct EventMessage`. -/
structure Message where
  text : String
  color : Color
  startTicks : UInt64
  deriving Inhabited

/-- C: `battery_state_string`. (`ERROR` is unreachable — see module Deviations.) -/
def batteryStateString : PowerState → String
  | .unknown   => "UNKNOWN"
  | .onBattery => "ON BATTERY"
  | .noBattery => "NO BATTERY"
  | .charging  => "CHARGING"
  | .charged   => "CHARGED"

structure State where
  window : Window
  renderer : Renderer
  messages : IO.Ref (Array Message)
  openedGamepads : IO.Ref (Array (JoystickId × Gamepad))
  colors : Array Color
  axisCooldown : IO.Ref UInt64

/-- Append a message coloured by joystick id. C: `add_message`. -/
def addMessage (s : State) (jid : JoystickId) (text : String) : IO Unit := do
  let color := s.colors[jid.val.toNat % 64]!
  let now ← getTicks
  s.messages.modify (·.push { text, color, startTicks := now })

/-- Draw the surviving messages front-to-back, returning the list to keep for the
next frame. Mirrors the C `while (msg)` loop. -/
partial def renderMessages (r : Renderer) (now : UInt64) (winw winh : Float)
    (prevY : Float) : List Message → IO (List Message)
  | [] => return []
  | m :: rest => do
    let cs := debugTextFontCharacterSize.toFloat
    let lifePercent := (now - m.startTicks).toFloat / msgLifetime
    if lifePercent ≥ 1.0 then
      renderMessages r now winw winh prevY rest
    else
      let x := (winw - (m.text.length.toFloat * cs)) / 2.0
      let y := winh * lifePercent
      if prevY != 0.0 && (prevY - y) < cs then
        return ({ m with startTicks := now } :: rest)
      let a := (m.color.a.toFloat * (1.0 - lifePercent)).toUInt8
      r.setDrawColor m.color.r m.color.g m.color.b a
      r.debugText x.toFloat32 y.toFloat32 m.text
      let keptRest ← renderMessages r now winw winh y rest
      return (m :: keptRest)

def app : App State where
  init := fun _args => do
    setAppMetadata "Example Input Gamepad Events" "1.0"
      "com.example.input-gamepad-events"
    Sdl.init (.video ||| .gamepad)
    let (window, renderer) ←
      createWindowAndRenderer "examples/input/gamepad-events" 640 480 .resizable
    let mut colors : Array Color := #[⟨255, 255, 255, 255⟩]
    for _ in [1:64] do
      colors := colors.push ⟨(← IO.rand 0 255).toUInt8, (← IO.rand 0 255).toUInt8,
        (← IO.rand 0 255).toUInt8, 255⟩
    let messages ← IO.mkRef #[]
    let openedGamepads ← IO.mkRef #[]
    let axisCooldown ← IO.mkRef 0
    let s := { window, renderer, messages, openedGamepads, colors, axisCooldown }
    addMessage s ⟨0⟩ "Please plug in a gamepad."
    return (.continue, some s)
  event := fun s e => do
    match e with
    | .quit _ => return .success
    | .gamepadAdded e =>
      -- sent for each hotplugged stick, but also each already-connected one at init.
      let which := e.which
      try
        let g ← openGamepad which
        addMessage s which s!"Gamepad #{which.val} ('{← g.name}') added"
        if let some mapping ← g.getMapping then
          addMessage s which s!"Gamepad #{which.val} mapping: {mapping}"
        s.openedGamepads.modify (·.push (which, g))
      catch ex =>
        addMessage s which s!"Gamepad #{which.val} add, but not opened: {ex}"
      return .continue
    | .gamepadRemoved e =>
      let which := e.which
      let opened ← s.openedGamepads.get
      if let some (_, g) := opened.find? (·.1 == which) then
        g.close  -- the gamepad was unplugged.
      s.openedGamepads.set (opened.filter (·.1 != which))
      addMessage s which s!"Gamepad #{which.val} removed"
      return .continue
    | .gamepadAxisMotion e =>
      let now ← getTicks
      if now ≥ (← s.axisCooldown.get) then
        s.axisCooldown.set (now + motionEventCooldown)
        let axis := (← getGamepadStringForAxis (GamepadAxis.ofVal e.axis)).getD "unknown"
        addMessage s e.which s!"Gamepad #{e.which.val} axis {axis} -> {e.value}"
      return .continue
    | .gamepadButtonDown e =>
      let button := (← getGamepadStringForButton (GamepadButton.ofVal e.button)).getD "unknown"
      addMessage s e.which s!"Gamepad #{e.which.val} button {button} -> PRESSED"
      return .continue
    | .gamepadButtonUp e =>
      let button := (← getGamepadStringForButton (GamepadButton.ofVal e.button)).getD "unknown"
      addMessage s e.which s!"Gamepad #{e.which.val} button {button} -> RELEASED"
      return .continue
    | .joystickBatteryUpdated e =>
      -- only reported for joysticks, so make sure this one is actually a gamepad.
      if (← isGamepad e.which) then
        addMessage s e.which
          s!"Gamepad #{e.which.val} battery -> {batteryStateString e.state} - {e.percent}%"
      return .continue
    | _ => return .continue
  iterate := fun s => do
    let r := s.renderer
    let now ← getTicks
    r.setDrawColor 0 0 0 255
    r.clear
    let (winw, winh) ← s.window.getSize
    let kept ← renderMessages r now winw.toFloat winh.toFloat 0.0 (← s.messages.get).toList
    s.messages.set kept.toArray
    r.present
    return .continue
  quit := fun _ _ => Sdl.quit

def main : IO UInt32 := Examples.runApp app
