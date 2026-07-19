import Common

/-!
# input/02-joystick-events

Looks for joystick input in the event handler and reports any changes as a
flood of on-screen info: each event appends a coloured message that scrolls down
the window and fades out over 3.5 seconds.

Port of the official example `examples/input/joystick-events/joystick-events.c`
(https://examples.libsdl.org/SDL3/input/02-joystick-events/).

## Deviations
- **Message list**: the C keeps an intrusive singly-linked list of `EventMessage`
  nodes with a sentinel head/tail. We keep an `Array Message` (oldest first) in
  an `IO.Ref`; a message's `startTicks` is mutated by rebuilding the array. The
  front-to-back "drop the expired prefix, draw until the next message would
  overlap the previous one" logic is preserved exactly.
- **Removal & ownership**: C closes the joystick via `SDL_GetJoystickFromID`,
  which in this binding hands back a *fresh* handle that owns its own reference —
  closing it would not release the handle we opened. So we additionally track the
  opened joysticks in `openedJoysticks : IO.Ref (Array (JoystickId × Joystick))`
  and close+drop the matching one on removal.
- **Open failure**: C's `SDL_OpenJoystick` returns `NULL`; the Lean `openJoystick`
  throws, so the "added but not opened" message comes from a `catch`.
- **Colors / RNG**: `IO.rand` instead of `SDL_rand` (cosmetic palette).
- `PowerState` has no `ERROR` member (SDL's `-1` sentinel is an `IO` error in this
  binding), so the C's `"ERROR"` battery string can never appear here.
- No `Sdl.quit`; the C's `SDL_AppQuit` is empty ("we let the joysticks leak").
  Opened joysticks are released by finalizers at process exit.
-/

open Sdl

/-- Milliseconds a message lives for. -/
private def msgLifetime : Float := 3500.0

/-- Spammy events (axis/ball motion) only show every this-many milliseconds.
C: `MOTION_EVENT_COOLDOWN`. -/
private def motionEventCooldown : UInt64 := 40

/-- One scrolling status line. C: `struct EventMessage`. -/
structure Message where
  text : String
  color : Color
  startTicks : UInt64
  deriving Inhabited

/-- C: `hat_state_string` — matches the raw `SDL_HAT_*` value exactly. -/
def hatStateString (h : Hat) : String :=
  match h.val with
  | 0x00 => "CENTERED"
  | 0x01 => "UP"
  | 0x02 => "RIGHT"
  | 0x04 => "DOWN"
  | 0x08 => "LEFT"
  | 0x03 => "RIGHT+UP"
  | 0x06 => "RIGHT+DOWN"
  | 0x09 => "LEFT+UP"
  | 0x0C => "LEFT+DOWN"
  | _    => "UNKNOWN"

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
  /-- Scrolling messages, oldest first. -/
  messages : IO.Ref (Array Message)
  /-- Every joystick we opened, so we can close the right handle on removal. -/
  openedJoysticks : IO.Ref (Array (JoystickId × Joystick))
  /-- 64 colors; index 0 is white, the rest random. -/
  colors : Array Color
  /-- Axis/ball motion cooldown timestamps (C: the two `static Uint64`s). -/
  axisCooldown : IO.Ref UInt64
  ballCooldown : IO.Ref UInt64

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
      -- msg is done; drop it (expired messages are always at the front).
      renderMessages r now winw winh prevY rest
    else
      let x := (winw - (m.text.length.toFloat * cs)) / 2.0
      let y := winh * lifePercent
      if prevY != 0.0 && (prevY - y) < cs then
        -- wait for the previous message to tick up a little.
        return ({ m with startTicks := now } :: rest)
      let a := (m.color.a.toFloat * (1.0 - lifePercent)).toUInt8
      r.setDrawColor m.color.r m.color.g m.color.b a
      r.debugText x.toFloat32 y.toFloat32 m.text
      let keptRest ← renderMessages r now winw winh y rest
      return (m :: keptRest)

def app : App State where
  init _ := do
    setAppMetadata "Example Input Joystick Events" "1.0"
      "com.example.input-joystick-events"
    Sdl.init (.video ||| .joystick)
    let (window, renderer) ←
      createWindowAndRenderer "examples/input/joystick-events" 640 480 .resizable
    let mut colors : Array Color := #[⟨255, 255, 255, 255⟩]
    for _ in [1:64] do
      colors := colors.push ⟨(← IO.rand 0 255).toUInt8, (← IO.rand 0 255).toUInt8,
        (← IO.rand 0 255).toUInt8, 255⟩
    let messages ← IO.mkRef #[]
    let openedJoysticks ← IO.mkRef #[]
    let axisCooldown ← IO.mkRef 0
    let ballCooldown ← IO.mkRef 0
    let s := { window, renderer, messages, openedJoysticks, colors, axisCooldown, ballCooldown }
    addMessage s ⟨0⟩ "Please plug in a joystick."
    return (.continue, some s)
  event s e := do
    match e with
    | .quit _ => return .success
    | .joystickAdded e =>
      -- sent for each hotplugged stick, but also each already-connected one at init.
      let which := e.which
      try
        let j ← openJoystick which
        addMessage s which s!"Joystick #{which.val} ('{← j.name}') added"
        s.openedJoysticks.modify (·.push (which, j))
      catch ex =>
        addMessage s which s!"Joystick #{which.val} add, but not opened: {ex}"
      return .continue
    | .joystickRemoved e =>
      let which := e.which
      let opened ← s.openedJoysticks.get
      if let some (_, j) := opened.find? (·.1 == which) then
        j.close  -- the joystick was unplugged.
      s.openedJoysticks.set (opened.filter (·.1 != which))
      addMessage s which s!"Joystick #{which.val} removed"
      return .continue
    | .joystickAxisMotion e =>
      let now ← getTicks
      if now ≥ (← s.axisCooldown.get) then
        s.axisCooldown.set (now + motionEventCooldown)
        addMessage s e.which s!"Joystick #{e.which.val} axis {e.axis} -> {e.value}"
      return .continue
    | .joystickBallMotion e =>
      let now ← getTicks
      if now ≥ (← s.ballCooldown.get) then
        s.ballCooldown.set (now + motionEventCooldown)
        addMessage s e.which s!"Joystick #{e.which.val} ball {e.ball} -> {e.xrel}, {e.yrel}"
      return .continue
    | .joystickHatMotion e =>
      addMessage s e.which s!"Joystick #{e.which.val} hat {e.hat} -> {hatStateString ⟨e.value⟩}"
      return .continue
    | .joystickButtonDown e =>
      addMessage s e.which s!"Joystick #{e.which.val} button {e.button} -> PRESSED"
      return .continue
    | .joystickButtonUp e =>
      addMessage s e.which s!"Joystick #{e.which.val} button {e.button} -> RELEASED"
      return .continue
    | .joystickBatteryUpdated e =>
      addMessage s e.which
        s!"Joystick #{e.which.val} battery -> {batteryStateString e.state} - {e.percent}%"
      return .continue
    | _ => return .continue
  iterate s := do
    let r := s.renderer
    let now ← getTicks
    r.setDrawColor 0 0 0 255
    r.clear
    let (winw, winh) ← s.window.getSize
    let kept ← renderMessages r now winw.toFloat winh.toFloat 0.0 (← s.messages.get).toList
    s.messages.set kept.toArray
    r.present
    return .continue

def main : IO UInt32 := Examples.runApp app
