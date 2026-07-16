module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros
public import Sdl.Error
public meta import Sdl.Error
public import Sdl.Properties
public meta import Sdl.Properties
public import Sdl.Guid
public meta import Sdl.Guid
public import Sdl.Power
public meta import Sdl.Power
public import Sdl.Events
public meta import Sdl.Events
public import Sdl.Sensor
public meta import Sdl.Sensor

public section

/-!
# Joysticks (`SDL_joystick.h`)

The lower-level joystick API (for well-defined button semantics, prefer the
gamepad API). `SDL_Init` must have been called with `SDL_INIT_JOYSTICK` before
joysticks can be opened. This module also binds SDL's **virtual joystick** API:
an app describes an imaginary controller with `attachVirtualJoystick` and then
drives its inputs with the `Joystick.setVirtual*` family, so it looks like a
real joystick to SDL without any hardware backing it.

## Ownership

`Joystick` is an **owned root**: the finalizer runs `SDL_CloseJoystick` and the
holder's `owner` is always `NULL`. `Joystick.close` is a *manual* destroy that
NULLs the handle, so later use is a clean IO error. SDL refcounts joysticks
internally, so every handle the binding hands out has taken its own
`SDL_OpenJoystick` reference: `getJoystickFromID` / `getJoystickFromPlayerIndex`
re-open the joystick (ref-bump) and wrap that fresh reference, so the returned
handle owns its own reference and closing it does not invalidate other handles.

## Skipped (documented plan-level omissions)

The `SDL_VirtualJoystickDesc` callback fields (`Update`, `SetPlayerIndex`,
`Rumble`, `RumbleTriggers`, `SetLED`, `SendEffect`, `SetSensorsEnabled`,
`Cleanup`, `userdata`) are not bound: virtual devices driven from Lean push
their state with the `setVirtual*` family instead, and those callbacks exist to
*implement* rumble/LED/effects for consumers — a niche no example needs.
-/

namespace Sdl

/-- An opened joystick. C: `SDL_Joystick`. -/
sdl_opaque Joystick

@[extern "lean_sdl_joystick_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

/-! ## Enums and flags -/

/-- Some common joystick types. Version-open: this is not a complete list of
everything that can be plugged in, and the virtual-joystick descriptor carries a
`Uint16`, so future SDL values decode to `other`. `SDL_JOYSTICK_TYPE_COUNT` is
not a member. C: `SDL_JoystickType`. -/
sdl_enum_open JoystickType : UInt32 where
  | unknown     => 0  -- C: SDL_JOYSTICK_TYPE_UNKNOWN
  | gamepad     => 1  -- C: SDL_JOYSTICK_TYPE_GAMEPAD
  | wheel       => 2  -- C: SDL_JOYSTICK_TYPE_WHEEL
  | arcadeStick => 3  -- C: SDL_JOYSTICK_TYPE_ARCADE_STICK
  | flightStick => 4  -- C: SDL_JOYSTICK_TYPE_FLIGHT_STICK
  | dancePad    => 5  -- C: SDL_JOYSTICK_TYPE_DANCE_PAD
  | guitar      => 6  -- C: SDL_JOYSTICK_TYPE_GUITAR
  | drumKit     => 7  -- C: SDL_JOYSTICK_TYPE_DRUM_KIT
  | arcadePad   => 8  -- C: SDL_JOYSTICK_TYPE_ARCADE_PAD
  | throttle    => 9  -- C: SDL_JOYSTICK_TYPE_THROTTLE

/-- How a joystick device is connected. The C sentinel
`SDL_JOYSTICK_CONNECTION_INVALID (-1)` is not a member: `Joystick.connectionState`
throws on it. C: `SDL_JoystickConnectionState`. -/
sdl_enum JoystickConnectionState : UInt32 where
  | unknown  => 0  -- C: SDL_JOYSTICK_CONNECTION_UNKNOWN
  | wired    => 1  -- C: SDL_JOYSTICK_CONNECTION_WIRED
  | wireless => 2  -- C: SDL_JOYSTICK_CONNECTION_WIRELESS

/-- Bit flags for a POV hat's position. This is the payload of
`JoyHatEvent.value` and the state returned by `Joystick.getHat`; decode an event
value with `(⟨e.value⟩ : Hat)`. C: `SDL_HAT_*`. -/
sdl_flags Hat : UInt8 where
  | up    := 0x01  -- C: SDL_HAT_UP
  | right := 0x02  -- C: SDL_HAT_RIGHT
  | down  := 0x04  -- C: SDL_HAT_DOWN
  | left  := 0x08  -- C: SDL_HAT_LEFT

/-- The hat's centered (neutral) position. C: `SDL_HAT_CENTERED`. -/
def Hat.centered : Hat := ⟨0⟩
/-- Up and to the right. C: `SDL_HAT_RIGHTUP`. -/
def Hat.rightUp : Hat := .right ||| .up
/-- Down and to the right. C: `SDL_HAT_RIGHTDOWN`. -/
def Hat.rightDown : Hat := .right ||| .down
/-- Up and to the left. C: `SDL_HAT_LEFTUP`. -/
def Hat.leftUp : Hat := .left ||| .up
/-- Down and to the left. C: `SDL_HAT_LEFTDOWN`. -/
def Hat.leftDown : Hat := .left ||| .down

#guard Hat.centered.val == 0x00
#guard Hat.up.val == 0x01
#guard Hat.right.val == 0x02
#guard Hat.down.val == 0x04
#guard Hat.left.val == 0x08
#guard Hat.rightUp.val == 0x03
#guard Hat.rightDown.val == 0x06
#guard Hat.leftUp.val == 0x09
#guard Hat.leftDown.val == 0x0C

/-- The largest value a joystick axis can report. C: `SDL_JOYSTICK_AXIS_MAX`. -/
def Joystick.axisMax : Int16 := 32767
/-- The smallest value a joystick axis can report (negative!).
C: `SDL_JOYSTICK_AXIS_MIN`. -/
def Joystick.axisMin : Int16 := -32768

/-! ## Joystick capability property keys

Read-only boolean properties provided on a joystick's `Properties`. -/

/-- True if the joystick has an LED with adjustable brightness.
C: `SDL_PROP_JOYSTICK_CAP_MONO_LED_BOOLEAN`. -/
def Joystick.propCapMonoLED : String := "SDL.joystick.cap.mono_led"
/-- True if the joystick has an LED with adjustable color.
C: `SDL_PROP_JOYSTICK_CAP_RGB_LED_BOOLEAN`. -/
def Joystick.propCapRgbLED : String := "SDL.joystick.cap.rgb_led"
/-- True if the joystick has a player LED.
C: `SDL_PROP_JOYSTICK_CAP_PLAYER_LED_BOOLEAN`. -/
def Joystick.propCapPlayerLED : String := "SDL.joystick.cap.player_led"
/-- True if the joystick has left/right rumble.
C: `SDL_PROP_JOYSTICK_CAP_RUMBLE_BOOLEAN`. -/
def Joystick.propCapRumble : String := "SDL.joystick.cap.rumble"
/-- True if the joystick has simple trigger rumble.
C: `SDL_PROP_JOYSTICK_CAP_TRIGGER_RUMBLE_BOOLEAN`. -/
def Joystick.propCapTriggerRumble : String := "SDL.joystick.cap.trigger_rumble"

/-! ## Virtual joystick descriptors -/

/-- Describes a touchpad on a virtual joystick. C: `SDL_VirtualJoystickTouchpadDesc`. -/
structure VirtualJoystickTouchpadDesc where
  nfingers : UInt16
  deriving Repr, BEq, Inhabited

/-- Describes a sensor on a virtual joystick. C: `SDL_VirtualJoystickSensorDesc`. -/
structure VirtualJoystickSensorDesc where
  type : SensorType
  rate : Float32
  deriving Repr, BEq, Inhabited

/-- Describes a virtual joystick for `attachVirtualJoystick`. All fields are
optional in C; the defaults here match `SDL_INIT_INTERFACE` zeroing. The C
struct's callback fields (`Update`, `Rumble`, …) are not bound. C:
`SDL_VirtualJoystickDesc`. -/
structure VirtualJoystickDesc where
  type       : JoystickType := .unknown
  vendorId   : UInt16 := 0
  productId  : UInt16 := 0
  naxes      : UInt16 := 0
  nbuttons   : UInt16 := 0
  nballs     : UInt16 := 0
  nhats      : UInt16 := 0
  buttonMask : UInt32 := 0
  axisMask   : UInt32 := 0
  name       : Option String := none
  touchpads  : Array VirtualJoystickTouchpadDesc := #[]
  sensors    : Array VirtualJoystickSensorDesc := #[]
  deriving Repr, BEq, Inhabited

/-! ## Top-level functions -/

/-- Lock the joystick API for atomic access; pair with `unlockJoysticks`. While
locked, the joystick list will not change and joystick/gamepad events are not
delivered. C: `SDL_LockJoysticks`. -/
@[extern "lean_sdl_lock_joysticks"]
opaque lockJoysticks : IO Unit

/-- Unlock the joystick API locked by `lockJoysticks` (call from the same
thread). C: `SDL_UnlockJoysticks`. -/
@[extern "lean_sdl_unlock_joysticks"]
opaque unlockJoysticks : IO Unit

/-- Whether any joystick is currently connected. C: `SDL_HasJoystick`. -/
@[extern "lean_sdl_has_joystick"]
opaque hasJoystick : IO Bool

@[extern "lean_sdl_get_joysticks"]
private opaque getJoysticksRaw : IO (Array UInt32)

/-- The currently-connected joysticks. Throws on failure. C: `SDL_GetJoysticks`. -/
def getJoysticks : IO (Array JoystickId) := do
  return (← getJoysticksRaw).map (⟨·⟩)

@[extern "lean_sdl_open_joystick"]
private opaque openJoystickRaw (id : UInt32) : IO Joystick

/-- Open a joystick for use. Throws on failure. C: `SDL_OpenJoystick`. -/
def openJoystick (id : JoystickId) : IO Joystick := openJoystickRaw id.val

@[extern "lean_sdl_get_joystick_from_id"]
private opaque getJoystickFromIDRaw (id : UInt32) : IO (Option Joystick)

/-- The opened joystick with instance id `id`, or `none` if it has not been
opened. The returned handle owns its own reference (SDL re-opens it internally),
so closing it does not invalidate other handles. C: `SDL_GetJoystickFromID`. -/
def getJoystickFromID (id : JoystickId) : IO (Option Joystick) := getJoystickFromIDRaw id.val

@[extern "lean_sdl_get_joystick_from_player_index"]
private opaque getJoystickFromPlayerIndexRaw (idx : Int32) : IO (Option Joystick)

/-- The opened joystick assigned to player index `idx`, or `none`. The returned
handle owns its own reference, so closing it does not invalidate other handles.
C: `SDL_GetJoystickFromPlayerIndex`. -/
def getJoystickFromPlayerIndex (idx : Int32) : IO (Option Joystick) :=
  getJoystickFromPlayerIndexRaw idx

@[extern "lean_sdl_attach_virtual_joystick"]
private opaque attachVirtualJoystickRaw
  (type : UInt16) (vendorId productId naxes nbuttons nballs nhats : UInt16)
  (buttonMask axisMask : UInt32) (name : @& Option String)
  (touchpadFingers : @& Array UInt16) (sensorTypes : @& Array UInt32)
  (sensorRates : @& FloatArray) : IO UInt32

/-- Attach a new virtual joystick described by `desc`, returning its instance
id. Once attached it looks like any other joystick; drive its inputs with the
`Joystick.setVirtual*` family. Fires `SDL_EVENT_JOYSTICK_ADDED`. Throws on
failure. C: `SDL_AttachVirtualJoystick`. -/
def attachVirtualJoystick (desc : VirtualJoystickDesc) : IO JoystickId := do
  let touchpadFingers : Array UInt16 := desc.touchpads.map (·.nfingers)
  let sensorTypes : Array UInt32 := desc.sensors.map (·.type.val)
  let sensorRates : FloatArray := ⟨desc.sensors.map (·.rate.toFloat)⟩
  let id ← attachVirtualJoystickRaw desc.type.val.toUInt16 desc.vendorId desc.productId
    desc.naxes desc.nbuttons desc.nballs desc.nhats desc.buttonMask desc.axisMask
    desc.name touchpadFingers sensorTypes sensorRates
  return ⟨id⟩

@[extern "lean_sdl_detach_virtual_joystick"]
private opaque detachVirtualJoystickRaw (id : UInt32) : IO Unit

/-- Detach a virtual joystick previously attached with `attachVirtualJoystick`.
Fires `SDL_EVENT_JOYSTICK_REMOVED`. Throws on failure (e.g. `id` is not a live
virtual joystick). C: `SDL_DetachVirtualJoystick`. -/
def detachVirtualJoystick (id : JoystickId) : IO Unit := detachVirtualJoystickRaw id.val

@[extern "lean_sdl_is_joystick_virtual"]
private opaque isJoystickVirtualRaw (id : UInt32) : IO Bool

/-- Whether the joystick with instance id `id` is virtual.
C: `SDL_IsJoystickVirtual`. -/
def isJoystickVirtual (id : JoystickId) : IO Bool := isJoystickVirtualRaw id.val

/-- Enable or disable joystick event processing. When disabled, call
`updateJoysticks` yourself before polling joystick state.
C: `SDL_SetJoystickEventsEnabled`. -/
@[extern "lean_sdl_set_joystick_events_enabled"]
opaque setJoystickEventsEnabled (enabled : Bool) : IO Unit

/-- Whether joystick event processing is enabled. C: `SDL_JoystickEventsEnabled`. -/
@[extern "lean_sdl_joystick_events_enabled"]
opaque joystickEventsEnabled : IO Bool

/-- Update the current state of every open joystick. Called implicitly by the
event loop (and by `pollEvent`/`waitEvent`) when joystick events are enabled;
call it directly to apply queued virtual-joystick state without pumping events.
C: `SDL_UpdateJoysticks`. -/
@[extern "lean_sdl_update_joysticks"]
opaque updateJoysticks : IO Unit

@[extern "lean_sdl_get_joystick_guid_info"]
private opaque getJoystickGUIDInfoRaw (bytes : @& ByteArray) :
  IO (UInt16 × UInt16 × UInt16 × UInt16)

/-- Decode the device information `(vendor, product, version, crc16)` encoded in
a joystick `guid`; a field is `0` when not available.
C: `SDL_GetJoystickGUIDInfo`. -/
def getJoystickGUIDInfo (guid : @& Guid) : IO (UInt16 × UInt16 × UInt16 × UInt16) :=
  getJoystickGUIDInfoRaw guid.bytes

namespace JoystickId

@[extern "lean_sdl_get_joystick_name_for_id"]
private opaque nameRaw (id : UInt32) : IO String

/-- The implementation-dependent name of a joystick. Throws if no name is
available. C: `SDL_GetJoystickNameForID`. -/
def name (self : JoystickId) : IO String := nameRaw self.val

@[extern "lean_sdl_get_joystick_path_for_id"]
private opaque pathRaw (id : UInt32) : IO (Option String)

/-- The implementation-dependent path of a joystick, or `none` if unavailable
(common; not treated as an error). C: `SDL_GetJoystickPathForID`. -/
def path (self : JoystickId) : IO (Option String) := pathRaw self.val

@[extern "lean_sdl_get_joystick_player_index_for_id"]
private opaque playerIndexRaw (id : UInt32) : IO Int32

/-- The player index of a joystick, or `none` (`-1`) if unavailable.
C: `SDL_GetJoystickPlayerIndexForID`. -/
def playerIndex (self : JoystickId) : IO (Option Int32) := do
  let v ← playerIndexRaw self.val
  return if v < 0 then none else some v

@[extern "lean_sdl_get_joystick_guid_for_id"]
private opaque guidRaw (id : UInt32) : IO ByteArray

/-- The implementation-dependent GUID of a joystick (a zero GUID if `id` is
invalid). C: `SDL_GetJoystickGUIDForID`. -/
def guid (self : JoystickId) : IO Guid := do return ⟨← guidRaw self.val⟩

@[extern "lean_sdl_get_joystick_vendor_for_id"]
private opaque vendorRaw (id : UInt32) : IO UInt16

/-- The USB vendor id of a joystick, or `0` if unavailable.
C: `SDL_GetJoystickVendorForID`. -/
def vendor (self : JoystickId) : IO UInt16 := vendorRaw self.val

@[extern "lean_sdl_get_joystick_product_for_id"]
private opaque productRaw (id : UInt32) : IO UInt16

/-- The USB product id of a joystick, or `0` if unavailable.
C: `SDL_GetJoystickProductForID`. -/
def product (self : JoystickId) : IO UInt16 := productRaw self.val

@[extern "lean_sdl_get_joystick_product_version_for_id"]
private opaque productVersionRaw (id : UInt32) : IO UInt16

/-- The product version of a joystick, or `0` if unavailable.
C: `SDL_GetJoystickProductVersionForID`. -/
def productVersion (self : JoystickId) : IO UInt16 := productVersionRaw self.val

@[extern "lean_sdl_get_joystick_type_for_id"]
private opaque getTypeRaw (id : UInt32) : IO UInt32

/-- The type of a joystick (`.unknown` if `id` is invalid).
C: `SDL_GetJoystickTypeForID`. -/
def getType (self : JoystickId) : IO JoystickType := do
  return JoystickType.ofVal (← getTypeRaw self.val)

end JoystickId

namespace Joystick

/-- Close a joystick previously opened with `openJoystick`. The handle is
invalid afterwards, so later use is a clean IO error. Because SDL refcounts
joysticks, closing one handle does not invalidate other handles for the same
device. C: `SDL_CloseJoystick`. -/
@[extern "lean_sdl_close_joystick"]
opaque close (self : @& Joystick) : IO Unit

/-- The properties associated with the joystick (read-only capability booleans;
see the `propCap*` keys). Borrowed: tied to the joystick's lifetime, never
destroyed from Lean. Throws on failure. C: `SDL_GetJoystickProperties`. -/
@[extern "lean_sdl_get_joystick_properties"]
opaque getProperties (self : @& Joystick) : IO Properties

@[extern "lean_sdl_get_joystick_name"]
private opaque nameRaw (self : @& Joystick) : IO String

/-- The implementation-dependent name of the joystick. Throws if unavailable.
C: `SDL_GetJoystickName`. -/
def name (self : @& Joystick) : IO String := nameRaw self

@[extern "lean_sdl_get_joystick_path"]
private opaque pathRaw (self : @& Joystick) : IO (Option String)

/-- The implementation-dependent path of the joystick, or `none` if unavailable.
C: `SDL_GetJoystickPath`. -/
def path (self : @& Joystick) : IO (Option String) := pathRaw self

@[extern "lean_sdl_get_joystick_player_index"]
private opaque playerIndexRaw (self : @& Joystick) : IO Int32

/-- The player index of the joystick, or `none` (`-1`) if unavailable.
C: `SDL_GetJoystickPlayerIndex`. -/
def playerIndex (self : @& Joystick) : IO (Option Int32) := do
  let v ← playerIndexRaw self
  return if v < 0 then none else some v

@[extern "lean_sdl_set_joystick_player_index"]
private opaque setPlayerIndexRaw (self : @& Joystick) (idx : Int32) : IO Unit

/-- Set the player index of the joystick (`none` clears it and turns off player
LEDs). Throws on failure. C: `SDL_SetJoystickPlayerIndex`. -/
def setPlayerIndex (self : @& Joystick) (idx : Option Int32) : IO Unit :=
  setPlayerIndexRaw self (idx.getD (-1))

@[extern "lean_sdl_get_joystick_guid"]
private opaque guidRaw (self : @& Joystick) : IO ByteArray

/-- The implementation-dependent GUID of the joystick.
C: `SDL_GetJoystickGUID`. -/
def guid (self : @& Joystick) : IO Guid := do return ⟨← guidRaw self⟩

@[extern "lean_sdl_get_joystick_vendor"]
private opaque vendorRaw (self : @& Joystick) : IO UInt16

/-- The USB vendor id of the joystick, or `0` if unavailable.
C: `SDL_GetJoystickVendor`. -/
def vendor (self : @& Joystick) : IO UInt16 := vendorRaw self

@[extern "lean_sdl_get_joystick_product"]
private opaque productRaw (self : @& Joystick) : IO UInt16

/-- The USB product id of the joystick, or `0` if unavailable.
C: `SDL_GetJoystickProduct`. -/
def product (self : @& Joystick) : IO UInt16 := productRaw self

@[extern "lean_sdl_get_joystick_product_version"]
private opaque productVersionRaw (self : @& Joystick) : IO UInt16

/-- The product version of the joystick, or `0` if unavailable.
C: `SDL_GetJoystickProductVersion`. -/
def productVersion (self : @& Joystick) : IO UInt16 := productVersionRaw self

@[extern "lean_sdl_get_joystick_firmware_version"]
private opaque firmwareVersionRaw (self : @& Joystick) : IO UInt16

/-- The firmware version of the joystick, or `0` if unavailable.
C: `SDL_GetJoystickFirmwareVersion`. -/
def firmwareVersion (self : @& Joystick) : IO UInt16 := firmwareVersionRaw self

@[extern "lean_sdl_get_joystick_serial"]
private opaque serialRaw (self : @& Joystick) : IO (Option String)

/-- The serial number of the joystick, or `none` if unavailable.
C: `SDL_GetJoystickSerial`. -/
def serial (self : @& Joystick) : IO (Option String) := serialRaw self

@[extern "lean_sdl_get_joystick_type"]
private opaque getTypeRaw (self : @& Joystick) : IO UInt32

/-- The type of the joystick. C: `SDL_GetJoystickType`. -/
def getType (self : @& Joystick) : IO JoystickType := do
  return JoystickType.ofVal (← getTypeRaw self)

/-- Whether the joystick is still connected. C: `SDL_JoystickConnected`. -/
@[extern "lean_sdl_joystick_connected"]
opaque connected (self : @& Joystick) : IO Bool

@[extern "lean_sdl_get_joystick_id"]
private opaque getIDRaw (self : @& Joystick) : IO UInt32

/-- The instance id of the joystick. Throws (`0`) on failure.
C: `SDL_GetJoystickID`. -/
def getID (self : @& Joystick) : IO JoystickId := do return ⟨← getIDRaw self⟩

/-- The number of general axis controls on the joystick. Throws (`-1`) on
failure. C: `SDL_GetNumJoystickAxes`. -/
@[extern "lean_sdl_get_num_joystick_axes"]
opaque numAxes (self : @& Joystick) : IO Int32

/-- The number of trackballs on the joystick (most have none). Throws (`-1`) on
failure. C: `SDL_GetNumJoystickBalls`. -/
@[extern "lean_sdl_get_num_joystick_balls"]
opaque numBalls (self : @& Joystick) : IO Int32

/-- The number of POV hats on the joystick. Throws (`-1`) on failure.
C: `SDL_GetNumJoystickHats`. -/
@[extern "lean_sdl_get_num_joystick_hats"]
opaque numHats (self : @& Joystick) : IO Int32

/-- The number of buttons on the joystick. Throws (`-1`) on failure.
C: `SDL_GetNumJoystickButtons`. -/
@[extern "lean_sdl_get_num_joystick_buttons"]
opaque numButtons (self : @& Joystick) : IO Int32

/-- The current position of `axis` (`-32768`..`32767`). SDL conflates a genuine
`0` reading with failure, so this does **not** throw: a `0` may mean centered or
an invalid axis. C: `SDL_GetJoystickAxis`. -/
@[extern "lean_sdl_get_joystick_axis"]
opaque getAxis (self : @& Joystick) (axis : Int32) : IO Int16

/-- The initial value of `axis`, or `none` if the axis has no initial state.
C: `SDL_GetJoystickAxisInitialState`. -/
@[extern "lean_sdl_get_joystick_axis_initial_state"]
opaque getAxisInitialState (self : @& Joystick) (axis : Int32) : IO (Option Int16)

/-- The `(dx, dy)` trackball motion since the last call. Throws on failure.
C: `SDL_GetJoystickBall`. -/
@[extern "lean_sdl_get_joystick_ball"]
opaque getBall (self : @& Joystick) (ball : Int32) : IO (Int32 × Int32)

@[extern "lean_sdl_get_joystick_hat"]
private opaque getHatRaw (self : @& Joystick) (hat : Int32) : IO UInt8

/-- The current position of POV hat `hat`. C: `SDL_GetJoystickHat`. -/
def getHat (self : @& Joystick) (hat : Int32) : IO Hat := do
  return ⟨← getHatRaw self hat⟩

/-- Whether button `button` is currently pressed. C: `SDL_GetJoystickButton`. -/
@[extern "lean_sdl_get_joystick_button"]
opaque getButton (self : @& Joystick) (button : Int32) : IO Bool

/-- Start a rumble effect (motor intensities `0`..`0xFFFF`, `duration_ms`).
Returns `false` if rumble is unsupported on this joystick (not an error).
C: `SDL_RumbleJoystick`. -/
@[extern "lean_sdl_rumble_joystick"]
opaque rumble (self : @& Joystick) (lowFrequency highFrequency : UInt16)
  (durationMs : UInt32) : IO Bool

/-- Start a trigger rumble effect (Xbox One only). Returns `false` if
unsupported (not an error). C: `SDL_RumbleJoystickTriggers`. -/
@[extern "lean_sdl_rumble_joystick_triggers"]
opaque rumbleTriggers (self : @& Joystick) (left right : UInt16)
  (durationMs : UInt32) : IO Bool

/-- Set the joystick's LED color. Returns `false` if the joystick has no
settable LED (not an error). C: `SDL_SetJoystickLED`. -/
@[extern "lean_sdl_set_joystick_led"]
opaque setLED (self : @& Joystick) (red green blue : UInt8) : IO Bool

/-- Send a joystick-specific effect packet. Returns `false` if unsupported (not
an error). C: `SDL_SendJoystickEffect`. -/
@[extern "lean_sdl_send_joystick_effect"]
opaque sendEffect (self : @& Joystick) (data : @& ByteArray) : IO Bool

@[extern "lean_sdl_get_joystick_connection_state"]
private opaque connectionStateRaw (self : @& Joystick) : IO UInt32

/-- The connection state of the joystick. Throws
(`SDL_JOYSTICK_CONNECTION_INVALID`) on failure.
C: `SDL_GetJoystickConnectionState`. -/
def connectionState (self : @& Joystick) : IO JoystickConnectionState := do
  return (JoystickConnectionState.ofVal? (← connectionStateRaw self)).getD .unknown

@[extern "lean_sdl_get_joystick_power_info"]
private opaque powerInfoRaw (self : @& Joystick) : IO (UInt32 × Int32)

/-- The joystick's battery `(state, percent)`; `percent` is `none` when unknown
or there is no battery. Throws (`SDL_POWERSTATE_ERROR`) on failure. Treat battery
readings as rough estimates. C: `SDL_GetJoystickPowerInfo`. -/
def powerInfo (self : @& Joystick) : IO (PowerState × Option Int32) := do
  let (st, pct) ← powerInfoRaw self
  return ((PowerState.ofVal? st).getD .unknown, if pct < 0 then none else some pct)

@[extern "lean_sdl_set_joystick_virtual_axis"]
private opaque setVirtualAxisRaw (self : @& Joystick) (axis : Int32) (value : Int16) : IO Unit

/-- Set the state of `axis` on this virtual joystick (applied on the next
`updateJoysticks`). Throws on failure. C: `SDL_SetJoystickVirtualAxis`. -/
def setVirtualAxis (self : @& Joystick) (axis : Int32) (value : Int16) : IO Unit :=
  setVirtualAxisRaw self axis value

@[extern "lean_sdl_set_joystick_virtual_ball"]
private opaque setVirtualBallRaw (self : @& Joystick) (ball : Int32) (xrel yrel : Int16) : IO Unit

/-- Generate ball motion on this virtual joystick (applied on the next
`updateJoysticks`). Throws on failure. C: `SDL_SetJoystickVirtualBall`. -/
def setVirtualBall (self : @& Joystick) (ball : Int32) (xrel yrel : Int16) : IO Unit :=
  setVirtualBallRaw self ball xrel yrel

@[extern "lean_sdl_set_joystick_virtual_button"]
private opaque setVirtualButtonRaw (self : @& Joystick) (button : Int32) (down : Bool) : IO Unit

/-- Set the state of `button` on this virtual joystick (applied on the next
`updateJoysticks`). Throws on failure. C: `SDL_SetJoystickVirtualButton`. -/
def setVirtualButton (self : @& Joystick) (button : Int32) (down : Bool) : IO Unit :=
  setVirtualButtonRaw self button down

@[extern "lean_sdl_set_joystick_virtual_hat"]
private opaque setVirtualHatRaw (self : @& Joystick) (hat : Int32) (value : UInt8) : IO Unit

/-- Set the state of POV hat `hat` on this virtual joystick (applied on the next
`updateJoysticks`). Throws on failure. C: `SDL_SetJoystickVirtualHat`. -/
def setVirtualHat (self : @& Joystick) (hat : Int32) (value : Hat) : IO Unit :=
  setVirtualHatRaw self hat value.val

@[extern "lean_sdl_set_joystick_virtual_touchpad"]
private opaque setVirtualTouchpadRaw (self : @& Joystick) (touchpad finger : Int32)
  (down : Bool) (x y pressure : Float32) : IO Unit

/-- Set touchpad finger state on this virtual joystick (`x`/`y` normalized `0`
to `1`, origin upper-left; applied on the next `updateJoysticks`). Throws on
failure. C: `SDL_SetJoystickVirtualTouchpad`. -/
def setVirtualTouchpad (self : @& Joystick) (touchpad finger : Int32)
    (down : Bool) (x y pressure : Float32) : IO Unit :=
  setVirtualTouchpadRaw self touchpad finger down x y pressure

@[extern "lean_sdl_send_joystick_virtual_sensor_data"]
private opaque sendVirtualSensorDataRaw (self : @& Joystick) (type : UInt32)
  (sensorTimestampNs : UInt64) (data : @& FloatArray) : IO Unit

/-- Send a sensor update for this virtual joystick (`data` doubles narrowed to
32-bit floats; applied on the next `updateJoysticks`). Throws on failure.
C: `SDL_SendJoystickVirtualSensorData`. -/
def sendVirtualSensorData (self : @& Joystick) (type : SensorType)
    (sensorTimestampNs : UInt64) (data : @& FloatArray) : IO Unit :=
  sendVirtualSensorDataRaw self type.val sensorTimestampNs data

end Joystick
end Sdl

end
