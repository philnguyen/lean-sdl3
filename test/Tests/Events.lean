import Sdl
import Tests.Harness

/-!
# Event decode round-trip tests (group "Events")

Every SDL_Event family is fabricated by a test-only C pusher
(`ffi/events_synth.c`, `lean_sdl_test_push_*`), pushed onto the queue, polled
back, and compared field-for-field against the expected decoded `Event`. The
queue is fully synthetic (no driver-dependent events under the dummy driver
after the initial pump+flush), so every check is strict.
-/

namespace Tests.Events
open Sdl Tests.Harness

/-! ## Test-only synthetic pushers (private; not part of the public API).
Each mirrors a `ffi/events.c` maker family; String/Array payloads are fixed
static data on the C side. -/

@[extern "lean_sdl_test_push_common"]
private opaque pushCommon (type : UInt32) (ts : UInt64) : IO Unit
@[extern "lean_sdl_test_push_display"]
private opaque pushDisplay (type : UInt32) (ts : UInt64) (displayId : UInt32)
  (data1 data2 : Int32) : IO Unit
@[extern "lean_sdl_test_push_window"]
private opaque pushWindow (type : UInt32) (ts : UInt64) (windowId : UInt32)
  (data1 data2 : Int32) : IO Unit
@[extern "lean_sdl_test_push_kdevice"]
private opaque pushKdevice (type : UInt32) (ts : UInt64) (which : UInt32) : IO Unit
@[extern "lean_sdl_test_push_key"]
private opaque pushKey (type : UInt32) (ts : UInt64) (windowId which scancode key : UInt32)
  (mod raw : UInt16) (down «repeat» : Bool) : IO Unit
@[extern "lean_sdl_test_push_text_editing"]
private opaque pushTextEditing (type : UInt32) (ts : UInt64) (windowId : UInt32)
  (start length : Int32) : IO Unit
@[extern "lean_sdl_test_push_text_editing_candidates"]
private opaque pushTextEditingCandidates (type : UInt32) (ts : UInt64) (windowId : UInt32)
  (selected : Int32) (horizontal : Bool) : IO Unit
@[extern "lean_sdl_test_push_text_input"]
private opaque pushTextInput (type : UInt32) (ts : UInt64) (windowId : UInt32) : IO Unit
@[extern "lean_sdl_test_push_mdevice"]
private opaque pushMdevice (type : UInt32) (ts : UInt64) (which : UInt32) : IO Unit
@[extern "lean_sdl_test_push_mouse_motion"]
private opaque pushMouseMotion (type : UInt32) (ts : UInt64) (windowId which state : UInt32)
  (x y xrel yrel : Float32) : IO Unit
@[extern "lean_sdl_test_push_mouse_button"]
private opaque pushMouseButton (type : UInt32) (ts : UInt64) (windowId which : UInt32)
  (button : UInt8) (down : Bool) (clicks : UInt8) (x y : Float32) : IO Unit
@[extern "lean_sdl_test_push_mouse_wheel"]
private opaque pushMouseWheel (type : UInt32) (ts : UInt64) (windowId which : UInt32)
  (x y : Float32) (direction : UInt32) (mouseX mouseY : Float32)
  (integerX integerY : Int32) : IO Unit
@[extern "lean_sdl_test_push_jdevice"]
private opaque pushJdevice (type : UInt32) (ts : UInt64) (which : UInt32) : IO Unit
@[extern "lean_sdl_test_push_jaxis"]
private opaque pushJaxis (type : UInt32) (ts : UInt64) (which : UInt32) (axis : UInt8)
  (value : Int16) : IO Unit
@[extern "lean_sdl_test_push_jball"]
private opaque pushJball (type : UInt32) (ts : UInt64) (which : UInt32) (ball : UInt8)
  (xrel yrel : Int16) : IO Unit
@[extern "lean_sdl_test_push_jhat"]
private opaque pushJhat (type : UInt32) (ts : UInt64) (which : UInt32) (hat value : UInt8) : IO Unit
@[extern "lean_sdl_test_push_jbutton"]
private opaque pushJbutton (type : UInt32) (ts : UInt64) (which : UInt32) (button : UInt8)
  (down : Bool) : IO Unit
@[extern "lean_sdl_test_push_jbattery"]
private opaque pushJbattery (type : UInt32) (ts : UInt64) (which : UInt32)
  (state percent : Int32) : IO Unit
@[extern "lean_sdl_test_push_gdevice"]
private opaque pushGdevice (type : UInt32) (ts : UInt64) (which : UInt32) : IO Unit
@[extern "lean_sdl_test_push_gaxis"]
private opaque pushGaxis (type : UInt32) (ts : UInt64) (which : UInt32) (axis : UInt8)
  (value : Int16) : IO Unit
@[extern "lean_sdl_test_push_gbutton"]
private opaque pushGbutton (type : UInt32) (ts : UInt64) (which : UInt32) (button : UInt8)
  (down : Bool) : IO Unit
@[extern "lean_sdl_test_push_gtouchpad"]
private opaque pushGtouchpad (type : UInt32) (ts : UInt64) (which : UInt32)
  (touchpad finger : Int32) (x y pressure : Float32) : IO Unit
@[extern "lean_sdl_test_push_gsensor"]
private opaque pushGsensor (type : UInt32) (ts : UInt64) (which : UInt32) (sensor : Int32)
  (d0 d1 d2 : Float32) (sensorTs : UInt64) : IO Unit
@[extern "lean_sdl_test_push_adevice"]
private opaque pushAdevice (type : UInt32) (ts : UInt64) (which : UInt32) (recording : Bool) : IO Unit
@[extern "lean_sdl_test_push_cdevice"]
private opaque pushCdevice (type : UInt32) (ts : UInt64) (which : UInt32) : IO Unit
@[extern "lean_sdl_test_push_sensor"]
private opaque pushSensor (type : UInt32) (ts : UInt64) (which : UInt32)
  (d0 d1 d2 d3 d4 d5 : Float32) (sensorTs : UInt64) : IO Unit
@[extern "lean_sdl_test_push_tfinger"]
private opaque pushTfinger (type : UInt32) (ts : UInt64) (touchId fingerId : UInt64)
  (x y dx dy pressure : Float32) (windowId : UInt32) : IO Unit
@[extern "lean_sdl_test_push_pinch"]
private opaque pushPinch (type : UInt32) (ts : UInt64) (scale : Float32) (windowId : UInt32) : IO Unit
@[extern "lean_sdl_test_push_pproximity"]
private opaque pushPproximity (type : UInt32) (ts : UInt64) (windowId which : UInt32) : IO Unit
@[extern "lean_sdl_test_push_pmotion"]
private opaque pushPmotion (type : UInt32) (ts : UInt64) (windowId which penState : UInt32)
  (x y : Float32) : IO Unit
@[extern "lean_sdl_test_push_ptouch"]
private opaque pushPtouch (type : UInt32) (ts : UInt64) (windowId which penState : UInt32)
  (x y : Float32) (eraser down : Bool) : IO Unit
@[extern "lean_sdl_test_push_pbutton"]
private opaque pushPbutton (type : UInt32) (ts : UInt64) (windowId which penState : UInt32)
  (x y : Float32) (button : UInt8) (down : Bool) : IO Unit
@[extern "lean_sdl_test_push_paxis"]
private opaque pushPaxis (type : UInt32) (ts : UInt64) (windowId which penState : UInt32)
  (x y : Float32) (axis : UInt32) (value : Float32) : IO Unit
@[extern "lean_sdl_test_push_render"]
private opaque pushRender (type : UInt32) (ts : UInt64) (windowId : UInt32) : IO Unit
@[extern "lean_sdl_test_push_drop"]
private opaque pushDrop (type : UInt32) (ts : UInt64) (windowId : UInt32) (x y : Float32)
  (hasStrings : Bool) : IO Unit
@[extern "lean_sdl_test_push_clipboard"]
private opaque pushClipboard (type : UInt32) (ts : UInt64) (owner : Bool) : IO Unit

/-- Poll for the next real event, skipping a leading poll-sentinel `none`.

SDL inserts an internal `SDL_EVENT_POLL_SENTINEL` during pumping that
`SDL_PollEvent` surfaces as an end-of-cycle `false` (→ `none`); a real app
drains the queue in a `while (SDL_PollEvent(&e))` loop, so a single push
followed by one poll can return `none` before the pushed event. Since the
queue here holds exactly one freshly-pushed event, retry a bounded number of
times until it appears. -/
private def pollReal : IO (Option Event) := do
  let mut r : Option Event := none
  for _ in [0:4] do
    if r.isNone then r ← pollEvent
  return r

/-- Push then poll, comparing the decoded event against `expected` with `==`. -/
private def rt (name : String) (push : IO Unit) (expected : Event) : IO Unit := do
  push
  match ← pollReal with
  | some ev => check name (ev == expected)
  | none    => check s!"{name} (polled none)" false

/-- The distinctive fixed static text the string-bearing synth pushers use. -/
private def synthText : String := "sdl-lean synthetic"

def run : IO Unit := do
  -- Fully synthetic queue: init video, then pump + flush so leftovers from
  -- earlier groups cannot interleave with the events we push here.
  Sdl.init .video
  pumpEvents
  flushEvents

  -- Application / common (quit is payloadless).
  rt "common quit" (pushCommon 0x100 111) (.quit ⟨111⟩)

  -- Display.
  rt "display orientation" (pushDisplay 0x151 111 7 1 2)
    (.displayOrientation ⟨111, ⟨7⟩, 1, 2⟩)

  -- Window (two distinct types).
  rt "window shown" (pushWindow 0x202 111 7 0 0) (.windowShown ⟨111, ⟨7⟩, 0, 0⟩)
  rt "window resized" (pushWindow 0x206 111 7 640 480) (.windowResized ⟨111, ⟨7⟩, 640, 480⟩)

  -- Keyboard device.
  rt "keyboard added" (pushKdevice 0x305 111 7) (.keyboardAdded ⟨111, ⟨7⟩⟩)

  -- Key (down with repeat=true, then up with both bools false).
  rt "key down (repeat)" (pushKey 0x300 111 7 7 4 0x61 0 99 true true)
    (.keyDown ⟨111, ⟨7⟩, ⟨7⟩, ⟨4⟩, ⟨0x61⟩, ⟨0⟩, 99, true, true⟩)
  rt "key up" (pushKey 0x301 111 7 7 4 0x61 0 99 false false)
    (.keyUp ⟨111, ⟨7⟩, ⟨7⟩, ⟨4⟩, ⟨0x61⟩, ⟨0⟩, 99, false, false⟩)

  -- Text editing / input / candidates (fixed static strings).
  rt "text editing" (pushTextEditing 0x302 111 7 0 2)
    (.textEditing ⟨111, ⟨7⟩, synthText, 0, 2⟩)
  rt "text input" (pushTextInput 0x303 111 7)
    (.textInput ⟨111, ⟨7⟩, synthText⟩)
  rt "text editing candidates" (pushTextEditingCandidates 0x307 111 7 1 true)
    (.textEditingCandidates ⟨111, ⟨7⟩, #["alpha", "beta"], 1, true⟩)

  -- Mouse device / motion / button / wheel.
  rt "mouse added" (pushMdevice 0x404 111 7) (.mouseAdded ⟨111, ⟨7⟩⟩)
  rt "mouse motion" (pushMouseMotion 0x400 111 7 7 1 1.5 2.5 0.5 0.25)
    (.mouseMotion ⟨111, ⟨7⟩, ⟨7⟩, ⟨1⟩, 1.5, 2.5, 0.5, 0.25⟩)
  rt "mouse button down" (pushMouseButton 0x401 111 7 7 1 true 2 1.5 2.5)
    (.mouseButtonDown ⟨111, ⟨7⟩, ⟨7⟩, ⟨1⟩, true, 2, 1.5, 2.5⟩)
  rt "mouse wheel" (pushMouseWheel 0x403 111 7 7 1.5 2.5 1 3.5 4.5 1 2)
    (.mouseWheel ⟨111, ⟨7⟩, ⟨7⟩, 1.5, 2.5, .flipped, 3.5, 4.5, 1, 2⟩)

  -- Joystick.
  rt "joystick added" (pushJdevice 0x605 111 7) (.joystickAdded ⟨111, ⟨7⟩⟩)
  rt "joystick axis (negative)" (pushJaxis 0x600 111 7 2 (-1234))
    (.joystickAxisMotion ⟨111, ⟨7⟩, 2, -1234⟩)
  rt "joystick ball" (pushJball 0x601 111 7 1 (-2) 3)
    (.joystickBallMotion ⟨111, ⟨7⟩, 1, -2, 3⟩)
  rt "joystick hat" (pushJhat 0x602 111 7 1 2) (.joystickHatMotion ⟨111, ⟨7⟩, 1, 2⟩)
  rt "joystick button down" (pushJbutton 0x603 111 7 1 true)
    (.joystickButtonDown ⟨111, ⟨7⟩, 1, true⟩)
  rt "joystick battery (onBattery 42%)" (pushJbattery 0x607 111 7 1 42)
    (.joystickBatteryUpdated ⟨111, ⟨7⟩, .onBattery, 42⟩)

  -- Gamepad.
  rt "gamepad steam handle updated" (pushGdevice 0x65B 111 7)
    (.gamepadSteamHandleUpdated ⟨111, ⟨7⟩⟩)
  rt "gamepad axis" (pushGaxis 0x650 111 7 2 (-1234)) (.gamepadAxisMotion ⟨111, ⟨7⟩, 2, -1234⟩)
  rt "gamepad button down" (pushGbutton 0x651 111 7 1 true)
    (.gamepadButtonDown ⟨111, ⟨7⟩, 1, true⟩)
  rt "gamepad touchpad motion" (pushGtouchpad 0x657 111 7 1 2 1.5 2.5 0.5)
    (.gamepadTouchpadMotion ⟨111, ⟨7⟩, 1, 2, 1.5, 2.5, 0.5⟩)
  rt "gamepad sensor" (pushGsensor 0x659 111 7 3 1.5 2.5 3.5 222)
    (.gamepadSensorUpdate ⟨111, ⟨7⟩, 3, 1.5, 2.5, 3.5, 222⟩)

  -- Audio / camera / sensor.
  rt "audio device added (recording)" (pushAdevice 0x1100 111 7 true)
    (.audioDeviceAdded ⟨111, ⟨7⟩, true⟩)
  rt "camera device approved" (pushCdevice 0x1402 111 7) (.cameraDeviceApproved ⟨111, ⟨7⟩⟩)
  rt "sensor update" (pushSensor 0x1200 111 7 1.5 2.5 3.5 4.5 5.5 6.5 222)
    (.sensorUpdate ⟨111, ⟨7⟩, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 222⟩)

  -- Touch / pinch.
  rt "touch finger down" (pushTfinger 0x700 111 3 4 1.5 2.5 0.5 0.25 0.75 7)
    (.fingerDown ⟨111, ⟨3⟩, ⟨4⟩, 1.5, 2.5, 0.5, 0.25, 0.75, ⟨7⟩⟩)
  rt "pinch update" (pushPinch 0x711 111 1.5 7) (.pinchUpdate ⟨111, 1.5, ⟨7⟩⟩)

  -- Pen.
  rt "pen proximity in" (pushPproximity 0x1300 111 7 7) (.penProximityIn ⟨111, ⟨7⟩, ⟨7⟩⟩)
  rt "pen motion" (pushPmotion 0x1306 111 7 7 1 1.5 2.5)
    (.penMotion ⟨111, ⟨7⟩, ⟨7⟩, ⟨1⟩, 1.5, 2.5⟩)
  rt "pen down" (pushPtouch 0x1302 111 7 7 1 1.5 2.5 false true)
    (.penDown ⟨111, ⟨7⟩, ⟨7⟩, ⟨1⟩, 1.5, 2.5, false, true⟩)
  rt "pen button down" (pushPbutton 0x1304 111 7 7 1 1.5 2.5 2 true)
    (.penButtonDown ⟨111, ⟨7⟩, ⟨7⟩, ⟨1⟩, 1.5, 2.5, 2, true⟩)
  rt "pen axis" (pushPaxis 0x1307 111 7 7 1 1.5 2.5 0 0.5)
    (.penAxis ⟨111, ⟨7⟩, ⟨7⟩, ⟨1⟩, 1.5, 2.5, .pressure, 0.5⟩)

  -- Render.
  rt "render targets reset" (pushRender 0x2000 111 7) (.renderTargetsReset ⟨111, ⟨7⟩⟩)

  -- Drop (with strings, then the NULL variant -> Option none fields).
  rt "drop file (with strings)" (pushDrop 0x1000 111 7 1.5 2.5 true)
    (.dropFile ⟨111, ⟨7⟩, 1.5, 2.5, some "synthetic-source", some "/tmp/synthetic.txt"⟩)
  rt "drop begin (null strings)" (pushDrop 0x1002 111 7 0 0 false)
    (.dropBegin ⟨111, ⟨7⟩, 0, 0, none, none⟩)

  -- Clipboard.
  rt "clipboard update" (pushClipboard 0x900 111 true)
    (.clipboardUpdate ⟨111, true, #["text/plain", "text/html"]⟩)

  -- Timestamp preservation: a nonzero pushed timestamp round-trips exactly
  -- (SDL only stamps zero timestamps).
  pushCommon 0x100 12345
  match ← pollReal with
  | some ev => check "timestamp 12345 preserved" (ev.timestamp == 12345)
  | none    => check "timestamp 12345 preserved (polled none)" false

  -- Unmapped type -> .unknown (0x4000 is SDL_EVENT_PRIVATE0).
  rt "unknown 0x4000" (pushCommon 0x4000 111) (.unknown 0x4000 ⟨111⟩)

  -- Event.timestamp / Event.windowId on two decoded events.
  pushWindow 0x202 111 7 0 0
  match ← pollReal with
  | some ev =>
    check "Event.timestamp on window" (ev.timestamp == 111)
    check "Event.windowId on window" (ev.windowId == some ⟨7⟩)
  | none => check "decoded window (polled none)" false
  pushJball 0x601 111 7 1 (-2) 3
  match ← pollReal with
  | some ev => check "Event.windowId none on jball" (ev.windowId == none)
  | none    => check "decoded jball (polled none)" false

  -- User events: register a type, push, poll, check code/windowId/type
  -- (timestamp is SDL-stamped nonzero).
  match ← registerEvents with
  | none => check "registerEvents succeeds" false
  | some t =>
    check "registered user type >= 0x8000" (t.val >= 0x8000)
    let ok ← pushUserEvent t 42
    check "pushUserEvent returns true" ok
    match ← pollReal with
    | some (.user ty e) =>
      check "user event type" (ty == t.val)
      check "user event windowId" (e.windowId == ⟨0⟩)
      check "user event code" (e.code == 42)
    | _ => check "user event decoded as .user" false

  -- hasEvent / flushEvent.
  pushJball 0x601 111 7 1 (-2) 3
  check "hasEvent jball true" (← hasEvent .joystickBallMotion)
  flushEvent .joystickBallMotion
  check "hasEvent jball false after flush" (!(← hasEvent .joystickBallMotion))

  -- Disabled-event semantics (verified against SDL source): disabling a type
  -- FLUSHES its pending events; user pushes still BYPASS the enabled check, so
  -- we only assert the enable/disable state and the disable-flush behaviour.
  pushJball 0x601 111 7 1 (-2) 3
  check "hasEvent jball true (pre-disable)" (← hasEvent .joystickBallMotion)
  setEventEnabled .joystickBallMotion false
  check "disable flushed pending jball" (!(← hasEvent .joystickBallMotion))
  check "eventEnabled jball false" (!(← eventEnabled .joystickBallMotion))
  setEventEnabled .joystickBallMotion true
  check "eventEnabled jball true after re-enable" (← eventEnabled .joystickBallMotion)

  -- waitEventTimeout on an empty queue returns none.
  flushEvents
  check "waitEventTimeout 1 on empty -> none" ((← waitEventTimeout 1) == none)

end Tests.Events
