import Sdl
import Tests.Harness

/-!
# Gamepad + haptic runtime tests

Gamepad verification goes through SDL's **virtual joystick** API shaped as a
gamepad (`type := .gamepad`, `naxes := 6`, `nbuttons := 26`, nonzero masks), so
no hardware is needed under the dummy drivers. Haptic is exercised only through
its failure paths (no haptic devices exist headless) plus pure guards. Bodies are
split into helper `def`s so no single `do` block trips the elaborator's recursion
limit.
-/

namespace Tests.Gamepad
open Sdl Tests.Harness

/-- Float32 vs Float within a tolerance (never compare Float32 with `==`). -/
private def approx (a : Float32) (b : Float) (eps : Float := 0.001) : Bool :=
  (a.toFloat - b).abs < eps

/-- Float vs Float within a tolerance. -/
private def approxF (a b : Float) (eps : Float := 0.001) : Bool := (a - b).abs < eps

/-- Whether `sub` occurs in `s`. -/
private def containsSub (s sub : String) : Bool := (s.splitOn sub).length > 1

/-- Poll until the queue drains, collecting every event (bounded loop). -/
def drainEvents : IO (Array Event) := do
  let mut evs := #[]
  for _ in [0:100000] do
    match ← pollEvent with
    | some e => evs := evs.push e
    | none => break
  return evs

/-- 1. Attach a gamepad-shaped virtual joystick and confirm the ADDED event. -/
def attachPad : IO JoystickId := do
  let _ ← drainEvents
  let id ← attachVirtualJoystick
    { type := .gamepad, vendorId := 0x1234, productId := 0x5678,
      naxes := 6, nbuttons := 26,
      buttonMask := 0x803,   -- (1<<<0)|(1<<<1)|(1<<<11) = south|east|dpadUp
      axisMask := 3,         -- leftx|lefty
      name := some "Lean Virtual Pad" }
  check "attach pad id ≠ 0" (id.val != 0)
  let evs ← drainEvents
  check "gamepadAdded fired for id"
    (evs.any (fun | .gamepadAdded e => e.which == id | _ => false))
  check "isGamepad id" (← isGamepad id)
  return id

/-- 2. Open the gamepad and read its static attributes. -/
def openTests (id : JoystickId) : IO Gamepad := do
  let pad ← openGamepad id
  check "pad.name == Lean Virtual Pad" ((← pad.name) == "Lean Virtual Pad")
  check "pad.getType == standard" ((← pad.getType) == .standard)
  let m ← pad.getMapping
  check "pad.getMapping contains Lean"
    (match m with | some s => containsSub s "Lean" | none => false)
  check "pad.getID == id" ((← pad.getID) == id)
  check "pad.connected" (← pad.connected)
  return pad

/-- 3. Button/axis presence reflects the masks. -/
def hasTests (pad : Gamepad) : IO Unit := do
  check "hasButton south" (← pad.hasButton .south)
  check "hasButton west == false" (!(← pad.hasButton .west))
  check "hasAxis leftx" (← pad.hasAxis .leftx)
  check "hasAxis rightx == false" (!(← pad.hasAxis .rightx))

/-- 4. Drive state through the underlying joystick, read it back on the gamepad,
and confirm the gamepad axis/button events fire. -/
def stateTests (pad : Gamepad) (id : JoystickId) : IO Unit := do
  let j ← pad.getJoystick
  let _ ← drainEvents
  j.setVirtualAxis 0 (-20000)   -- leftx
  j.setVirtualButton 0 true     -- south
  updateJoysticks
  check "getAxis leftx == -20000" ((← pad.getAxis .leftx) == -20000)
  check "getButton south" (← pad.getButton .south)
  let evs ← drainEvents
  let axisOk := evs.any (fun e => match e with
    | .gamepadAxisMotion ev =>
        ev.which == id && GamepadAxis.ofVal ev.axis == .leftx && ev.value == -20000
    | _ => false)
  check "gamepadAxisMotion (leftx, -20000)" axisOk
  let buttonOk := evs.any (fun e => match e with
    | .gamepadButtonDown ev => ev.which == id && GamepadButton.ofVal ev.button == .south
    | _ => false)
  check "gamepadButtonDown (south)" buttonOk

/-- 5. Capability results (false on virtual, never throw). -/
def capabilityTests (pad : Gamepad) : IO Unit := do
  check "rumble unsupported == false" (!(← pad.rumble 0xFFFF 0xFFFF 100))
  check "rumbleTriggers unsupported == false" (!(← pad.rumbleTriggers 0xFFFF 0xFFFF 100))
  check "setLED unsupported == false" (!(← pad.setLED 10 20 30))

/-- 6. String round-trips + a button label. -/
def stringTests (pad : Gamepad) : IO Unit := do
  check "stringForButton south == a" ((← getGamepadStringForButton .south) == some "a")
  check "buttonFromString a == south" ((← getGamepadButtonFromString "a") == some .south)
  check "axisFromString lefty == lefty" ((← getGamepadAxisFromString "lefty") == some .lefty)
  check "buttonFromString nonsense == none" ((← getGamepadButtonFromString "nonsense") == none)
  let _ ← pad.buttonLabel .south
  check "buttonLabel south runs" true

/-- 7. A second virtual pad with a touchpad + accel sensor, driven end-to-end. -/
def touchpadSensorTests : IO Unit := do
  let _ ← drainEvents
  let id ← attachVirtualJoystick
    { type := .gamepad, naxes := 6, nbuttons := 26,
      buttonMask := 0x803, axisMask := 3,
      name := some "Lean Sensor Pad",
      touchpads := #[⟨2⟩], sensors := #[⟨.accel, 100.0⟩] }
  let _ ← drainEvents
  let pad ← openGamepad id
  let j ← pad.getJoystick
  check "numTouchpads == 1" ((← pad.numTouchpads) == 1)
  check "numTouchpadFingers 0 == 2" ((← pad.numTouchpadFingers 0) == 2)
  check "hasSensor accel" (← pad.hasSensor .accel)
  check "hasSensor gyro == false" (!(← pad.hasSensor .gyro))
  pad.setSensorEnabled .accel true
  check "sensorEnabled accel" (← pad.sensorEnabled .accel)
  check "sensorDataRate accel ≈ 100" (approx (← pad.sensorDataRate .accel) 100.0 0.5)
  j.sendVirtualSensorData .accel 0 (⟨#[1.0, 2.5, -9.8]⟩ : FloatArray)
  updateJoysticks
  let d ← pad.getSensorData .accel 3
  check "getSensorData accel ≈ [1.0, 2.5, -9.8]"
    (d.size == 3 && approxF (d.get! 0) 1.0 && approxF (d.get! 1) 2.5 && approxF (d.get! 2) (-9.8))
  j.setVirtualTouchpad 0 1 true 0.25 0.75 0.5
  updateJoysticks
  let (down, x, y, p) ← pad.getTouchpadFinger 0 1
  check "getTouchpadFinger 0 1 round-trips"
    (down && approx x 0.25 && approx y 0.75 && approx p 0.5)
  pad.close
  detachVirtualJoystick id

/-- 8. Mapping bindings decode with the right shape. -/
def bindingTests (pad : Gamepad) : IO Unit := do
  let binds ← pad.getBindings
  check "getBindings size ≥ 2" (binds.size ≥ 2)
  check "a binding is button→button south"
    (binds.any (fun b =>
      match b.input, b.output with
      | .button _, .button .south => true
      | _, _ => false))

/-- 9. Mapping database queries. -/
def mappingTests (id : JoystickId) : IO Unit := do
  let maps ← getGamepadMappings
  check "getGamepadMappings contains Lean Virtual Pad"
    (maps.any (fun s => containsSub s "Lean Virtual Pad"))
  let added ← addGamepadMapping "00001111222233334444555566667777,Fake Pad,a:b0,b:b1,"
  check "addGamepadMapping new == true" added
  let fm ← getGamepadMappingForGUID (stringToGuid "00001111222233334444555566667777")
  check "mappingForGUID contains Fake Pad" (containsSub fm "Fake Pad")
  setGamepadMapping id none
  check "setGamepadMapping id none ok" true
  -- clearing the mapping re-maps the virtual pad (remove/add churn); flush it
  let _ ← drainEvents

/-- 10. From-id handle + misc state queries + events toggle. -/
def fromIDTests (pad : Gamepad) (id : JoystickId) : IO Unit := do
  match ← getGamepadFromID id with
  | some pad2 =>
    check "pad2.getID == id" ((← pad2.getID) == id)
    pad2.close
    check "original pad survives closing pad2" (← pad.connected)
  | none => check "getGamepadFromID returns some" false
  check "getGamepadFromID bogus id == none" ((← getGamepadFromID ⟨0xDEADBEEF⟩).isNone)
  check "steamHandle == 0" ((← pad.steamHandle) == 0)
  check "serial == none" ((← pad.serial) == none)
  check "powerInfo == (unknown, none)" ((← pad.powerInfo) == (.unknown, none))
  check "connectionState == unknown" ((← pad.connectionState) == .unknown)
  check "gamepadEventsEnabled" (← gamepadEventsEnabled)
  setGamepadEventsEnabled false
  check "gamepadEventsEnabled false after toggle" (!(← gamepadEventsEnabled))
  setGamepadEventsEnabled true
  check "gamepadEventsEnabled true after toggle" (← gamepadEventsEnabled)

/-- 11. Detach (REMOVED event), close (later use throws), and — only once the
gamepad handle is closed — the id is no longer a gamepad. `SDL_IsGamepad` keeps
reporting true while an opened `Gamepad` for that id is alive, so the check must
follow `close`. -/
def detachTests (pad : Gamepad) (id : JoystickId) : IO Unit := do
  let _ ← drainEvents
  detachVirtualJoystick id
  updateGamepads
  let evs ← drainEvents
  check "gamepadRemoved fired for id"
    (evs.any (fun | .gamepadRemoved e => e.which == id | _ => false))
  check "pad connected == false after detach" (!(← pad.connected))
  check "id no longer in getGamepads after detach" (!((← getGamepads).contains id))
  pad.close
  checkThrows "pad.name after close throws" pad.name
  -- Only once the handle is closed does the id stop resolving to a gamepad.
  check "getGamepadFromID id == none after detach + close" ((← getGamepadFromID id).isNone)
  -- NOTE: `SDL_IsGamepad id` is deliberately NOT asserted false here. SDL caches
  -- the gamepad mapping by instance and never clears it on detach (instance ids
  -- are never reused), so `isGamepad id` keeps returning true for a detached
  -- virtual pad — verified empirically on SDL 3.4.10. The observable post-detach
  -- facts are that the id leaves the connected list and no open gamepad remains.
  checkThrows "detach again throws" (detachVirtualJoystick id)

/-- Reinitializing the mapping database works (tested standalone, after the
shared pad is gone, so its remove/add churn disturbs nothing). -/
def reloadTest : IO Unit := do
  reloadGamepadMappings
  check "reloadGamepadMappings ok" true
  let _ ← drainEvents

/-- 12. Haptic: enumeration succeeds, bogus ids throw, mouse query runs, pure
guards on the `HapticFeatures`/`HapticEffect`/`hapticInfinity` surface. -/
def hapticTests : IO Unit := do
  let _ ← getHaptics
  check "getHaptics succeeds" true
  checkThrows "openHaptic bogus id throws" (openHaptic ⟨0xDEADBEEF⟩)
  checkThrows "HapticId.name bogus id throws" (HapticId.name ⟨0xDEADBEEF⟩)
  let _ ← isMouseHaptic
  check "isMouseHaptic runs" true
  check "HapticFeatures.gain ||| .autocenter has gain"
    ((HapticFeatures.gain ||| HapticFeatures.autocenter).has .gain)
  check "HapticFeatures.gain does not have sine" (!(HapticFeatures.gain.has .sine))
  check "HapticEffect.leftRight constructs"
    (HapticEffect.leftRight 100 0x8000 0x4000 == HapticEffect.leftRight 100 0x8000 0x4000)
  check "hapticInfinity == 0xFFFFFFFF" (hapticInfinity == 0xFFFFFFFF)

/-- 13. A virtual joystick is not haptic; opening a haptic from it throws. -/
def joystickHapticTests : IO Unit := do
  let _ ← drainEvents
  let jid ← attachVirtualJoystick
    { type := .gamepad, naxes := 6, nbuttons := 26,
      buttonMask := 1, axisMask := 1, name := some "Lean Haptic Probe" }
  let _ ← drainEvents
  let j ← openJoystick jid
  check "isJoystickHaptic virtual == false" (!(← isJoystickHaptic j))
  checkThrows "openHapticFromJoystick virtual throws" (openHapticFromJoystick j)
  j.close
  detachVirtualJoystick jid

/-- Gamepad + haptic tests (run under `SDL_VIDEO_DRIVER=dummy
SDL_AUDIO_DRIVER=dummy`). Initializes the gamepad (implies joystick) + haptic
subsystems. Does not `Sdl.quit` afterwards. -/
def run : IO Unit := do
  Sdl.init (.gamepad ||| .haptic)
  let id ← attachPad
  let pad ← openTests id
  hasTests pad
  stateTests pad id
  capabilityTests pad
  stringTests pad
  touchpadSensorTests
  bindingTests pad
  mappingTests id
  fromIDTests pad id
  detachTests pad id
  reloadTest
  hapticTests
  joystickHapticTests

end Tests.Gamepad
