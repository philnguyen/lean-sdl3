module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros
public import Sdl.Error
public meta import Sdl.Error

public section

/-!
# Touch input state (`SDL_touch.h`)

Query the registered touch devices, their names and types, and the active
fingers on a device. Touch is mostly consumed through the event system; these
are the hardware-detail queries.

The device-type sentinel `SDL_TOUCH_DEVICE_INVALID` (`-1`) is an error marker
(like `PowerState.error` / `ScaleMode.invalid`): it is excluded from
`TouchDeviceType`, and `TouchId.deviceType` throws when SDL returns it.
-/

namespace Sdl

/-- A touch device instance id, valid while the device is connected and never
reused for the lifetime of the app. `0` is never a valid id. The named
constants are the virtual touch devices for mouse and pen input.
C: `SDL_TouchID`. -/
sdl_id TouchId : UInt64 where
  | mouse := 0xFFFFFFFFFFFFFFFF  -- C: SDL_MOUSE_TOUCHID
  | pen   := 0xFFFFFFFFFFFFFFFE  -- C: SDL_PEN_TOUCHID

/-- A unique id for one finger (stylus, etc.) on a touch device, tracking a
single continuous touch. `0` is never a valid id. C: `SDL_FingerID`. -/
sdl_id FingerId : UInt64

/-- The type of a touch device. The C sentinel `SDL_TOUCH_DEVICE_INVALID`
(`-1`) is an error marker and is excluded here; `TouchId.deviceType` throws on
it. C: `SDL_TouchDeviceType`. -/
sdl_enum TouchDeviceType : UInt32 where
  | direct           => 0  -- C: SDL_TOUCH_DEVICE_DIRECT
  | indirectAbsolute => 1  -- C: SDL_TOUCH_DEVICE_INDIRECT_ABSOLUTE
  | indirectRelative => 2  -- C: SDL_TOUCH_DEVICE_INDIRECT_RELATIVE

/-- Data about a single finger in a multitouch event. Coordinates and pressure
are normalized to `0..1`. C: `SDL_Finger`. -/
structure Finger where
  /-- The finger id. -/
  id : FingerId
  /-- Normalized x-axis location (`0..1`). -/
  x : Float32
  /-- Normalized y-axis location (`0..1`). -/
  y : Float32
  /-- Normalized pressure (`0..1`). -/
  pressure : Float32
deriving Repr, BEq, Inhabited

/-- Maker: build a `Finger` from flattened scalars (C never lays out a Lean
structure). -/
@[export lean_sdl_mk_finger]
private def mkFinger (id : UInt64) (x y pressure : Float32) : Finger :=
  { id := ⟨id⟩, x, y, pressure }

@[extern "lean_sdl_get_touch_devices"]
private opaque getTouchDevicesRaw : IO (Array UInt64)

/-- The registered touch devices. On some platforms a device only appears after
it has been used, so the list may be empty even when devices exist. Throws on
failure. C: `SDL_GetTouchDevices`. -/
def getTouchDevices : IO (Array TouchId) := do
  return (← getTouchDevicesRaw).map (⟨·⟩)

namespace TouchId

@[extern "lean_sdl_get_touch_device_name"]
private opaque nameRaw (id : UInt64) : IO String

/-- The touch device name as reported by the driver. Throws on failure.
C: `SDL_GetTouchDeviceName`. -/
def name (self : TouchId) : IO String :=
  nameRaw self.val

@[extern "lean_sdl_get_touch_device_type"]
private opaque deviceTypeRaw (id : UInt64) : IO UInt32

/-- The type of the touch device. Throws on failure
(`SDL_TOUCH_DEVICE_INVALID`). C: `SDL_GetTouchDeviceType`. -/
def deviceType (self : TouchId) : IO TouchDeviceType := do
  return TouchDeviceType.ofVal? (← deviceTypeRaw self.val) |>.getD .direct

@[extern "lean_sdl_get_touch_fingers"]
private opaque fingersRaw (id : UInt64) : IO (Array Finger)

/-- The active fingers on the touch device. Throws on failure.
C: `SDL_GetTouchFingers`. -/
def fingers (self : TouchId) : IO (Array Finger) :=
  fingersRaw self.val

end TouchId

end Sdl

end
