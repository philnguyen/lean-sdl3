import Sdl
import Tests.Harness

/-!
# Sensor + joystick runtime tests

All joystick verification goes through SDL's **virtual joystick** API under the
dummy drivers (no hardware). Bodies are split into helper `def`s so no single
`do` block trips the elaborator's recursion limit.
-/

namespace Tests.Input
open Sdl Tests.Harness

/-- Float32 vs Float within a tolerance (never compare Float32 with `==`). -/
private def approx (a : Float32) (b : Float) (eps : Float := 0.0001) : Bool :=
  (a.toFloat - b).abs < eps

/-- Poll until the queue drains, collecting every event (bounded loop). -/
def drainEvents : IO (Array Event) := do
  let mut evs := #[]
  for _ in [0:100000] do
    match ← pollEvent with
    | some e => evs := evs.push e
    | none => break
  return evs

/-- 1. Sensors: enumeration succeeds, bogus ids throw, gravity constant. -/
def sensorTests : IO Unit := do
  let _ ← getSensors
  check "getSensors succeeds" true
  checkThrows "openSensor bogus id throws" (openSensor ⟨0xDEADBEEF⟩)
  checkThrows "SensorId.name bogus id throws" (SensorId.name ⟨0xDEADBEEF⟩)
  check "standardGravity ≈ 9.80665" (approx standardGravity 9.80665)

/-- 2. Attach a virtual flight stick and confirm the ADDED event. -/
def attachStick : IO JoystickId := do
  let _ ← drainEvents
  let id ← attachVirtualJoystick
    { type := .flightStick, vendorId := 0x1234, productId := 0x5678,
      naxes := 3, nbuttons := 5, nhats := 1, name := some "Lean Virtual Stick" }
  check "attach id ≠ 0" (id.val != 0)
  let evs ← drainEvents
  check "joystickAdded fired for id"
    (evs.any (fun | .joystickAdded e => e.which == id | _ => false))
  return id

/-- 3. `*ForID` surface plus GUID decoding. -/
def forIDTests (id : JoystickId) : IO Unit := do
  check "isJoystickVirtual id" (← isJoystickVirtual id)
  check "id.name == Lean Virtual Stick" ((← id.name) == "Lean Virtual Stick")
  check "id.getType == flightStick" ((← id.getType) == .flightStick)
  check "id.vendor == 0x1234" ((← id.vendor) == 0x1234)
  check "id.product == 0x5678" ((← id.product) == 0x5678)
  let g ← id.guid
  let (vend, prod, _ver, _crc) ← getJoystickGUIDInfo g
  check "guid info vendor == 0x1234" (vend == 0x1234)
  check "guid info product == 0x5678" (prod == 0x5678)

/-- 4. Open the joystick and read its static attributes. -/
def openTests (id : JoystickId) : IO Joystick := do
  let j ← openJoystick id
  check "j.name == Lean Virtual Stick" ((← j.name) == "Lean Virtual Stick")
  check "j.numAxes == 3" ((← j.numAxes) == 3)
  check "j.numButtons == 5" ((← j.numButtons) == 5)
  check "j.numHats == 1" ((← j.numHats) == 1)
  check "j.connected" (← j.connected)
  check "j.getID == id" ((← j.getID) == id)
  check "j.serial == none" ((← j.serial) == none)
  check "j.getType == flightStick" ((← j.getType) == .flightStick)
  return j

/-- 5/6. Virtual state round-trip: set inputs, update, read back, and confirm
the axis/button/hat events fire; then the initial-state and centered-hat checks. -/
def stateTests (j : Joystick) (id : JoystickId) : IO Unit := do
  let _ ← drainEvents
  j.setVirtualAxis 0 12345
  j.setVirtualButton 2 true
  j.setVirtualHat 0 Hat.leftUp
  updateJoysticks
  check "getAxis 0 == 12345" ((← j.getAxis 0) == 12345)
  check "getButton 2" (← j.getButton 2)
  check "getHat 0 == leftUp" ((← j.getHat 0) == Hat.leftUp)
  let evs ← drainEvents
  check "joystickAxisMotion event (axis 0, value 12345)"
    (evs.any (fun | .joystickAxisMotion e => e.which == id && e.axis == 0 && e.value == 12345
                  | _ => false))
  check "joystickButtonDown event (button 2)"
    (evs.any (fun | .joystickButtonDown e => e.which == id && e.button == 2 | _ => false))
  check "joystickHatMotion event (leftUp)"
    (evs.any (fun | .joystickHatMotion e => e.which == id && (⟨e.value⟩ : Hat) == Hat.leftUp
                  | _ => false))
  check "getAxisInitialState 0 is some" ((← j.getAxisInitialState 0).isSome)
  j.setVirtualHat 0 Hat.centered
  updateJoysticks
  check "getHat 0 == centered" ((← j.getHat 0) == Hat.centered)

/-- 7/8. Capability results (false on virtual, never throw) + state queries. -/
def capabilityTests (j : Joystick) : IO Unit := do
  check "rumble unsupported == false" (!(← j.rumble 0xFFFF 0xFFFF 100))
  check "rumbleTriggers unsupported == false" (!(← j.rumbleTriggers 0xFFFF 0xFFFF 100))
  check "setLED unsupported == false" (!(← j.setLED 10 20 30))
  check "sendEffect unsupported == false" (!(← j.sendEffect (⟨#[1, 2, 3]⟩ : ByteArray)))
  check "connectionState == unknown" ((← j.connectionState) == .unknown)
  check "powerInfo == (unknown, none)" ((← j.powerInfo) == (.unknown, none))

/-- 9. A second handle from the id owns its own reference. -/
def fromIDTests (j : Joystick) (id : JoystickId) : IO Unit := do
  match ← getJoystickFromID id with
  | some j2 =>
    check "j2.name matches" ((← j2.name) == "Lean Virtual Stick")
    j2.close
    check "original handle survives closing j2" (← j.connected)
  | none => check "getJoystickFromID returns some" false
  check "getJoystickFromID bogus id == none" ((← getJoystickFromID ⟨0xDEADBEEF⟩).isNone)

/-- 10/11. Lock pairing, enumeration, presence. -/
def miscTests (id : JoystickId) : IO Unit := do
  lockJoysticks
  unlockJoysticks
  check "lock/unlock pair runs" true
  check "getJoysticks contains id" ((← getJoysticks).contains id)
  check "hasJoystick" (← hasJoystick)

/-- 12. Detach, confirm the REMOVED event, close, and post-close/post-detach
error behavior. -/
def detachTests (j : Joystick) (id : JoystickId) : IO Unit := do
  let _ ← drainEvents
  detachVirtualJoystick id
  let evs ← drainEvents
  check "joystickRemoved fired for id"
    (evs.any (fun | .joystickRemoved e => e.which == id | _ => false))
  check "connected == false after detach" (!(← j.connected))
  j.close
  checkThrows "method after close throws" j.name
  check "getJoystickFromID id == none after detach" ((← getJoystickFromID id).isNone)
  checkThrows "detach again throws" (detachVirtualJoystick id)

/-- 13. All-default descriptor attaches and detaches. -/
def defaultDescTest : IO Unit := do
  let id ← attachVirtualJoystick {}
  check "attach defaults id ≠ 0" (id.val != 0)
  detachVirtualJoystick id
  check "detach defaults ok" true

/-- Sensor + joystick tests (run under `SDL_VIDEO_DRIVER=dummy
SDL_AUDIO_DRIVER=dummy`). Initializes the joystick + sensor subsystems (joystick
implies events; video is already up). Does not `Sdl.quit` afterwards. -/
def run : IO Unit := do
  Sdl.init (.joystick ||| .sensor)
  sensorTests
  let id ← attachStick
  forIDTests id
  let j ← openTests id
  stateTests j id
  capabilityTests j
  fromIDTests j id
  miscTests id
  detachTests j id
  defaultDescTest

end Tests.Input
