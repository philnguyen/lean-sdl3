import Sdl.Core.Macros
import Sdl.Error
import Sdl.Properties
import Sdl.Guid
import Sdl.Power
import Sdl.Events
import Sdl.Sensor
import Sdl.Joystick
import Sdl.IOStream

/-!
# Gamepads (`SDL_gamepad.h`)

The higher-level gamepad API layered on top of `Sdl.Joystick`. A gamepad tells
you *where* a control is (the d-pad, the face buttons, the triggers) rather than
handing back arbitrary joystick button/axis indices; SDL turns a joystick into a
gamepad with a mapping string. `SDL_Init` must have been called with
`SDL_INIT_GAMEPAD` (which implies `SDL_INIT_JOYSTICK`) before gamepads can be
opened.

Because there is no hardware in headless environments, this binding is exercised
through **virtual joysticks shaped as gamepads**: attach a virtual joystick with
`type := .gamepad`, `naxes := 6` (`SDL_GAMEPAD_AXIS_COUNT`), `nbuttons := 26`
(`SDL_GAMEPAD_BUTTON_COUNT`) and nonzero button/axis masks, and SDL recognizes it
as a gamepad with an auto-generated mapping. Drive its state through the
underlying `Joystick` (`Gamepad.getJoystick` + the `Joystick.setVirtual*` family
with gamepad enum indices) and pump with `updateJoysticks`/`updateGamepads`.

## Ownership

`Gamepad` is an **owned root**: the finalizer runs `SDL_CloseGamepad` and the
holder's `owner` is always `NULL`. `Gamepad.close` is a *manual* destroy that
NULLs the handle, so later use is a clean IO error. SDL refcounts gamepads
internally, so every handle the binding hands out took its own `SDL_OpenGamepad`
reference: `getGamepadFromID` / `getGamepadFromPlayerIndex` re-open the gamepad
(ref-bump) and wrap that fresh reference, so closing one handle never invalidates
another.

`Gamepad.getJoystick` returns a `Joystick` that **owns its own reference** (it is
`SDL_OpenJoystick`ed from the gamepad's underlying joystick id and wrapped with
the joystick class); it is safe to use after the gamepad closes.

## Skipped

Nothing is skipped: all 73 `SDL_gamepad.h` functions are bound.
-/

namespace Sdl

/-- An opened gamepad. C: `SDL_Gamepad`. -/
sdl_opaque Gamepad

@[extern "lean_sdl_gamepad_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

/-! ## Enums -/

/-- Standard gamepad types. Version-open: third-party controllers can report as
one of these and new consoles ship over time, so a raw value outside the listed
set decodes to `other`. `SDL_GAMEPAD_TYPE_COUNT` is not a member.
C: `SDL_GamepadType`. -/
sdl_enum_open GamepadType : UInt32 where
  | unknown                   => 0   -- C: SDL_GAMEPAD_TYPE_UNKNOWN
  | standard                  => 1   -- C: SDL_GAMEPAD_TYPE_STANDARD
  | xbox360                   => 2   -- C: SDL_GAMEPAD_TYPE_XBOX360
  | xboxone                   => 3   -- C: SDL_GAMEPAD_TYPE_XBOXONE
  | ps3                       => 4   -- C: SDL_GAMEPAD_TYPE_PS3
  | ps4                       => 5   -- C: SDL_GAMEPAD_TYPE_PS4
  | ps5                       => 6   -- C: SDL_GAMEPAD_TYPE_PS5
  | nintendoSwitchPro         => 7   -- C: SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_PRO
  | nintendoSwitchJoyconLeft  => 8   -- C: SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_JOYCON_LEFT
  | nintendoSwitchJoyconRight => 9   -- C: SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_JOYCON_RIGHT
  | nintendoSwitchJoyconPair  => 10  -- C: SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_JOYCON_PAIR
  | gamecube                  => 11  -- C: SDL_GAMEPAD_TYPE_GAMECUBE

/-- The buttons available on a gamepad, by standard location. Version-open (new
buttons may be added; the C sentinel `SDL_GAMEPAD_BUTTON_INVALID (-1)` and
`SDL_GAMEPAD_BUTTON_COUNT` are not members). This is the payload of
`GamepadButtonEvent.button` (a raw `UInt8`): decode an event value with
`GamepadButton.ofVal e.button`. C: `SDL_GamepadButton`. -/
sdl_enum_open GamepadButton : UInt8 where
  | south         => 0   -- C: SDL_GAMEPAD_BUTTON_SOUTH
  | east          => 1   -- C: SDL_GAMEPAD_BUTTON_EAST
  | west          => 2   -- C: SDL_GAMEPAD_BUTTON_WEST
  | north         => 3   -- C: SDL_GAMEPAD_BUTTON_NORTH
  | back          => 4   -- C: SDL_GAMEPAD_BUTTON_BACK
  | guide         => 5   -- C: SDL_GAMEPAD_BUTTON_GUIDE
  | start         => 6   -- C: SDL_GAMEPAD_BUTTON_START
  | leftStick     => 7   -- C: SDL_GAMEPAD_BUTTON_LEFT_STICK
  | rightStick    => 8   -- C: SDL_GAMEPAD_BUTTON_RIGHT_STICK
  | leftShoulder  => 9   -- C: SDL_GAMEPAD_BUTTON_LEFT_SHOULDER
  | rightShoulder => 10  -- C: SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER
  | dpadUp        => 11  -- C: SDL_GAMEPAD_BUTTON_DPAD_UP
  | dpadDown      => 12  -- C: SDL_GAMEPAD_BUTTON_DPAD_DOWN
  | dpadLeft      => 13  -- C: SDL_GAMEPAD_BUTTON_DPAD_LEFT
  | dpadRight     => 14  -- C: SDL_GAMEPAD_BUTTON_DPAD_RIGHT
  | misc1         => 15  -- C: SDL_GAMEPAD_BUTTON_MISC1
  | rightPaddle1  => 16  -- C: SDL_GAMEPAD_BUTTON_RIGHT_PADDLE1
  | leftPaddle1   => 17  -- C: SDL_GAMEPAD_BUTTON_LEFT_PADDLE1
  | rightPaddle2  => 18  -- C: SDL_GAMEPAD_BUTTON_RIGHT_PADDLE2
  | leftPaddle2   => 19  -- C: SDL_GAMEPAD_BUTTON_LEFT_PADDLE2
  | touchpad      => 20  -- C: SDL_GAMEPAD_BUTTON_TOUCHPAD
  | misc2         => 21  -- C: SDL_GAMEPAD_BUTTON_MISC2
  | misc3         => 22  -- C: SDL_GAMEPAD_BUTTON_MISC3
  | misc4         => 23  -- C: SDL_GAMEPAD_BUTTON_MISC4
  | misc5         => 24  -- C: SDL_GAMEPAD_BUTTON_MISC5
  | misc6         => 25  -- C: SDL_GAMEPAD_BUTTON_MISC6

/-- Labels for the face buttons (enough to show button prompts). Version-open.
C: `SDL_GamepadButtonLabel`. -/
sdl_enum_open GamepadButtonLabel : UInt32 where
  | unknown  => 0  -- C: SDL_GAMEPAD_BUTTON_LABEL_UNKNOWN
  | a        => 1  -- C: SDL_GAMEPAD_BUTTON_LABEL_A
  | b        => 2  -- C: SDL_GAMEPAD_BUTTON_LABEL_B
  | x        => 3  -- C: SDL_GAMEPAD_BUTTON_LABEL_X
  | y        => 4  -- C: SDL_GAMEPAD_BUTTON_LABEL_Y
  | cross    => 5  -- C: SDL_GAMEPAD_BUTTON_LABEL_CROSS
  | circle   => 6  -- C: SDL_GAMEPAD_BUTTON_LABEL_CIRCLE
  | square   => 7  -- C: SDL_GAMEPAD_BUTTON_LABEL_SQUARE
  | triangle => 8  -- C: SDL_GAMEPAD_BUTTON_LABEL_TRIANGLE

/-- The axes available on a gamepad, by standard location. Version-open (the C
sentinel `SDL_GAMEPAD_AXIS_INVALID (-1)` and `SDL_GAMEPAD_AXIS_COUNT` are not
members). This is the payload of `GamepadAxisEvent.axis` (a raw `UInt8`): decode
an event value with `GamepadAxis.ofVal e.axis`. C: `SDL_GamepadAxis`. -/
sdl_enum_open GamepadAxis : UInt8 where
  | leftx        => 0  -- C: SDL_GAMEPAD_AXIS_LEFTX
  | lefty        => 1  -- C: SDL_GAMEPAD_AXIS_LEFTY
  | rightx       => 2  -- C: SDL_GAMEPAD_AXIS_RIGHTX
  | righty       => 3  -- C: SDL_GAMEPAD_AXIS_RIGHTY
  | leftTrigger  => 4  -- C: SDL_GAMEPAD_AXIS_LEFT_TRIGGER
  | rightTrigger => 5  -- C: SDL_GAMEPAD_AXIS_RIGHT_TRIGGER

/-! ## Mapping bindings -/

/-- Input half of a mapping binding. C: `SDL_GamepadBinding.input` (tagged by
`SDL_GamepadBinding.input_type`). -/
inductive GamepadBindingInput where
  | none                                          -- C: SDL_GAMEPAD_BINDTYPE_NONE
  | button (button : Int32)                       -- C: SDL_GAMEPAD_BINDTYPE_BUTTON
  | axis (axis : Int32) (axisMin axisMax : Int32) -- C: SDL_GAMEPAD_BINDTYPE_AXIS
  | hat (hat : Int32) (hatMask : Int32)           -- C: SDL_GAMEPAD_BINDTYPE_HAT
  deriving Repr, BEq, Inhabited

/-- Output half of a mapping binding. C: `SDL_GamepadBinding.output` (tagged by
`SDL_GamepadBinding.output_type`). -/
inductive GamepadBindingOutput where
  | none                                                  -- C: SDL_GAMEPAD_BINDTYPE_NONE
  | button (button : GamepadButton)                       -- C: SDL_GAMEPAD_BINDTYPE_BUTTON
  | axis (axis : GamepadAxis) (axisMin axisMax : Int32)   -- C: SDL_GAMEPAD_BINDTYPE_AXIS
  deriving Repr, BEq, Inhabited

/-- One entry of a gamepad's mapping. C: `SDL_GamepadBinding`. -/
structure GamepadBinding where
  input  : GamepadBindingInput
  output : GamepadBindingOutput
  deriving Repr, BEq, Inhabited

/-- Maker called from C to hand one decoded `SDL_GamepadBinding` back to Lean.
The C side flattens the tagged unions into scalars; this pure def dispatches on
the two type tags (`SDL_GamepadBindingType`). Unknown tags decode to the `.none`
constructors so decoding is total. `inA/inB/inC` are `button` /
`axis,axis_min,axis_max` / `hat,hat_mask` by input tag. -/
@[export lean_sdl_mk_gamepad_binding]
private def mkGamepadBinding (inType : UInt32) (inA inB inC : Int32)
    (outType : UInt32) (outButtonOrAxis : UInt32) (outMin outMax : Int32) :
    GamepadBinding :=
  let input : GamepadBindingInput :=
    match inType with
    | 1 => .button inA
    | 2 => .axis inA inB inC
    | 3 => .hat inA inB
    | _ => .none
  let output : GamepadBindingOutput :=
    match outType with
    | 1 => .button (GamepadButton.ofVal outButtonOrAxis.toUInt8)
    | 2 => .axis (GamepadAxis.ofVal outButtonOrAxis.toUInt8) outMin outMax
    | _ => .none
  { input, output }

#guard mkGamepadBinding 1 0 0 0 1 0 0 0 == { input := .button 0, output := .button .south }
#guard mkGamepadBinding 2 3 (-1) 1 2 1 (-100) 100 ==
  { input := .axis 3 (-1) 1, output := .axis .lefty (-100) 100 }
#guard mkGamepadBinding 0 0 0 0 0 0 0 0 == { input := .none, output := .none }

/-! ## Gamepad capability property keys

These read-only boolean properties are shared with the underlying joystick, so
they alias the `Joystick.propCap*` keys. -/

/-- True if this gamepad has an LED with adjustable brightness.
C: `SDL_PROP_GAMEPAD_CAP_MONO_LED_BOOLEAN`. -/
def Gamepad.propCapMonoLED : String := Joystick.propCapMonoLED
/-- True if this gamepad has an LED with adjustable color.
C: `SDL_PROP_GAMEPAD_CAP_RGB_LED_BOOLEAN`. -/
def Gamepad.propCapRgbLED : String := Joystick.propCapRgbLED
/-- True if this gamepad has a player LED.
C: `SDL_PROP_GAMEPAD_CAP_PLAYER_LED_BOOLEAN`. -/
def Gamepad.propCapPlayerLED : String := Joystick.propCapPlayerLED
/-- True if this gamepad has left/right rumble.
C: `SDL_PROP_GAMEPAD_CAP_RUMBLE_BOOLEAN`. -/
def Gamepad.propCapRumble : String := Joystick.propCapRumble
/-- True if this gamepad has simple trigger rumble.
C: `SDL_PROP_GAMEPAD_CAP_TRIGGER_RUMBLE_BOOLEAN`. -/
def Gamepad.propCapTriggerRumble : String := Joystick.propCapTriggerRumble

/-! ## Top-level functions -/

/-- Add a mapping (or change an existing one). Returns `true` if a new mapping
was added, `false` if an existing one was updated; throws on failure. The
mapping string has the format `"GUID,name,mapping"`. C: `SDL_AddGamepadMapping`. -/
@[extern "lean_sdl_add_gamepad_mapping"]
opaque addGamepadMapping (mapping : @& String) : IO Bool

@[extern "lean_sdl_add_gamepad_mappings_from_io"]
private opaque addGamepadMappingsFromIORaw (src : @& IOStream) : IO Int32

/-- Load a set of gamepad mappings from an `IOStream`, returning the number of
mappings added; throws on failure. Lean owns the stream (`closeio = false`), so
close it yourself. C: `SDL_AddGamepadMappingsFromIO`. -/
def addGamepadMappingsFromIO (src : @& IOStream) : IO Int32 := addGamepadMappingsFromIORaw src

/-- Load a set of gamepad mappings from a file, returning the number of mappings
added; throws on failure. C: `SDL_AddGamepadMappingsFromFile`. -/
@[extern "lean_sdl_add_gamepad_mappings_from_file"]
opaque addGamepadMappingsFromFile (path : @& String) : IO Int32

/-- Reinitialize the mapping database to its initial state (generating gamepad
events as needed). Throws on failure. C: `SDL_ReloadGamepadMappings`. -/
@[extern "lean_sdl_reload_gamepad_mappings"]
opaque reloadGamepadMappings : IO Unit

/-- All current gamepad mapping strings. Throws on failure.
C: `SDL_GetGamepadMappings`. -/
@[extern "lean_sdl_get_gamepad_mappings"]
opaque getGamepadMappings : IO (Array String)

@[extern "lean_sdl_get_gamepad_mapping_for_guid"]
private opaque getGamepadMappingForGUIDRaw (guid : @& ByteArray) : IO String

/-- The mapping string for a given GUID. Throws if none is available.
C: `SDL_GetGamepadMappingForGUID`. -/
def getGamepadMappingForGUID (guid : @& Guid) : IO String := getGamepadMappingForGUIDRaw guid.bytes

@[extern "lean_sdl_set_gamepad_mapping"]
private opaque setGamepadMappingRaw (id : UInt32) (mapping : @& Option String) : IO Unit

/-- Set the mapping of a joystick/gamepad (`none` clears it, resetting to the
default). Throws on failure. C: `SDL_SetGamepadMapping`. -/
def setGamepadMapping (id : JoystickId) (mapping : @& Option String) : IO Unit :=
  setGamepadMappingRaw id.val mapping

/-- Whether any gamepad is currently connected. C: `SDL_HasGamepad`. -/
@[extern "lean_sdl_has_gamepad"]
opaque hasGamepad : IO Bool

@[extern "lean_sdl_get_gamepads"]
private opaque getGamepadsRaw : IO (Array UInt32)

/-- The instance ids of the currently-connected gamepads. Throws on failure.
C: `SDL_GetGamepads`. -/
def getGamepads : IO (Array JoystickId) := do
  return (← getGamepadsRaw).map (⟨·⟩)

@[extern "lean_sdl_is_gamepad"]
private opaque isGamepadRaw (id : UInt32) : IO Bool

/-- Whether the joystick with instance id `id` is supported by the gamepad
interface. C: `SDL_IsGamepad`. -/
def isGamepad (id : JoystickId) : IO Bool := isGamepadRaw id.val

@[extern "lean_sdl_open_gamepad"]
private opaque openGamepadRaw (id : UInt32) : IO Gamepad

/-- Open a gamepad for use. Throws on failure. C: `SDL_OpenGamepad`. -/
def openGamepad (id : JoystickId) : IO Gamepad := openGamepadRaw id.val

@[extern "lean_sdl_get_gamepad_from_id"]
private opaque getGamepadFromIDRaw (id : UInt32) : IO (Option Gamepad)

/-- The opened gamepad with instance id `id`, or `none` if it has not been
opened. The returned handle owns its own reference (SDL re-opens it internally),
so closing it does not invalidate other handles. C: `SDL_GetGamepadFromID`. -/
def getGamepadFromID (id : JoystickId) : IO (Option Gamepad) := getGamepadFromIDRaw id.val

@[extern "lean_sdl_get_gamepad_from_player_index"]
private opaque getGamepadFromPlayerIndexRaw (idx : Int32) : IO (Option Gamepad)

/-- The opened gamepad assigned to player index `idx`, or `none`. The returned
handle owns its own reference. C: `SDL_GetGamepadFromPlayerIndex`. -/
def getGamepadFromPlayerIndex (idx : Int32) : IO (Option Gamepad) :=
  getGamepadFromPlayerIndexRaw idx

/-- Enable or disable gamepad event processing. When disabled, call
`updateGamepads` yourself before polling gamepad state.
C: `SDL_SetGamepadEventsEnabled`. -/
@[extern "lean_sdl_set_gamepad_events_enabled"]
opaque setGamepadEventsEnabled (enabled : Bool) : IO Unit

/-- Whether gamepad event processing is enabled. C: `SDL_GamepadEventsEnabled`. -/
@[extern "lean_sdl_gamepad_events_enabled"]
opaque gamepadEventsEnabled : IO Bool

/-- Manually pump gamepad updates (called implicitly by the event loop when
gamepad events are enabled). C: `SDL_UpdateGamepads`. -/
@[extern "lean_sdl_update_gamepads"]
opaque updateGamepads : IO Unit

@[extern "lean_sdl_get_gamepad_type_from_string"]
private opaque getGamepadTypeFromStringRaw (s : @& String) : IO UInt32

/-- Convert a mapping-string type name into a `GamepadType`. Unmatched strings
yield `.unknown` (C's own `SDL_GAMEPAD_TYPE_UNKNOWN`, value 0), so there is no
`Option`. C: `SDL_GetGamepadTypeFromString`. -/
def getGamepadTypeFromString (s : @& String) : IO GamepadType := do
  return GamepadType.ofVal (← getGamepadTypeFromStringRaw s)

@[extern "lean_sdl_get_gamepad_string_for_type"]
private opaque getGamepadStringForTypeRaw (type : UInt32) : IO (Option String)

/-- The mapping-string name for a `GamepadType`, or `none` if invalid.
C: `SDL_GetGamepadStringForType`. -/
def getGamepadStringForType (t : GamepadType) : IO (Option String) :=
  getGamepadStringForTypeRaw t.val

@[extern "lean_sdl_get_gamepad_axis_from_string"]
private opaque getGamepadAxisFromStringRaw (s : @& String) : IO Int32

/-- Convert a mapping-string axis name into a `GamepadAxis`, or `none`
(`SDL_GAMEPAD_AXIS_INVALID`) if no match. C: `SDL_GetGamepadAxisFromString`. -/
def getGamepadAxisFromString (s : @& String) : IO (Option GamepadAxis) := do
  let v ← getGamepadAxisFromStringRaw s
  return if v < 0 then none else some (GamepadAxis.ofVal v.toUInt32.toUInt8)

@[extern "lean_sdl_get_gamepad_string_for_axis"]
private opaque getGamepadStringForAxisRaw (axis : UInt8) : IO (Option String)

/-- The mapping-string name for a `GamepadAxis`, or `none` if invalid.
C: `SDL_GetGamepadStringForAxis`. -/
def getGamepadStringForAxis (axis : GamepadAxis) : IO (Option String) :=
  getGamepadStringForAxisRaw axis.val

@[extern "lean_sdl_get_gamepad_button_from_string"]
private opaque getGamepadButtonFromStringRaw (s : @& String) : IO Int32

/-- Convert a mapping-string button name into a `GamepadButton`, or `none`
(`SDL_GAMEPAD_BUTTON_INVALID`) if no match. C: `SDL_GetGamepadButtonFromString`. -/
def getGamepadButtonFromString (s : @& String) : IO (Option GamepadButton) := do
  let v ← getGamepadButtonFromStringRaw s
  return if v < 0 then none else some (GamepadButton.ofVal v.toUInt32.toUInt8)

@[extern "lean_sdl_get_gamepad_string_for_button"]
private opaque getGamepadStringForButtonRaw (button : UInt8) : IO (Option String)

/-- The mapping-string name for a `GamepadButton`, or `none` if invalid.
C: `SDL_GetGamepadStringForButton`. -/
def getGamepadStringForButton (button : GamepadButton) : IO (Option String) :=
  getGamepadStringForButtonRaw button.val

@[extern "lean_sdl_get_gamepad_button_label_for_type"]
private opaque getGamepadButtonLabelForTypeRaw (type : UInt32) (button : UInt8) : IO UInt32

/-- The label of a face button for a given gamepad type.
C: `SDL_GetGamepadButtonLabelForType`. -/
def getGamepadButtonLabelForType (t : GamepadType) (button : GamepadButton) :
    IO GamepadButtonLabel := do
  return GamepadButtonLabel.ofVal (← getGamepadButtonLabelForTypeRaw t.val button.val)

/-! ## `JoystickId` gamepad queries (`*ForID`)

These extend the `JoystickId` namespace with the gamepad-flavored queries; they
are named `gamepad*` to avoid clashing with the joystick-flavored ones. -/

namespace JoystickId

@[extern "lean_sdl_get_gamepad_name_for_id"]
private opaque gamepadNameRaw (id : UInt32) : IO String

/-- The implementation-dependent name of a gamepad. Throws if no name is
available. C: `SDL_GetGamepadNameForID`. -/
def gamepadName (self : JoystickId) : IO String := gamepadNameRaw self.val

@[extern "lean_sdl_get_gamepad_path_for_id"]
private opaque gamepadPathRaw (id : UInt32) : IO (Option String)

/-- The implementation-dependent path of a gamepad, or `none` if unavailable.
C: `SDL_GetGamepadPathForID`. -/
def gamepadPath (self : JoystickId) : IO (Option String) := gamepadPathRaw self.val

@[extern "lean_sdl_get_gamepad_player_index_for_id"]
private opaque gamepadPlayerIndexRaw (id : UInt32) : IO Int32

/-- The player index of a gamepad, or `none` (`-1`) if unavailable.
C: `SDL_GetGamepadPlayerIndexForID`. -/
def gamepadPlayerIndex (self : JoystickId) : IO (Option Int32) := do
  let v ← gamepadPlayerIndexRaw self.val
  return if v < 0 then none else some v

@[extern "lean_sdl_get_gamepad_guid_for_id"]
private opaque gamepadGuidRaw (id : UInt32) : IO ByteArray

/-- The implementation-dependent GUID of a gamepad (a zero GUID if `id` is
invalid). C: `SDL_GetGamepadGUIDForID`. -/
def gamepadGuid (self : JoystickId) : IO Guid := do return ⟨← gamepadGuidRaw self.val⟩

@[extern "lean_sdl_get_gamepad_vendor_for_id"]
private opaque gamepadVendorRaw (id : UInt32) : IO UInt16

/-- The USB vendor id of a gamepad, or `0` if unavailable.
C: `SDL_GetGamepadVendorForID`. -/
def gamepadVendor (self : JoystickId) : IO UInt16 := gamepadVendorRaw self.val

@[extern "lean_sdl_get_gamepad_product_for_id"]
private opaque gamepadProductRaw (id : UInt32) : IO UInt16

/-- The USB product id of a gamepad, or `0` if unavailable.
C: `SDL_GetGamepadProductForID`. -/
def gamepadProduct (self : JoystickId) : IO UInt16 := gamepadProductRaw self.val

@[extern "lean_sdl_get_gamepad_product_version_for_id"]
private opaque gamepadProductVersionRaw (id : UInt32) : IO UInt16

/-- The product version of a gamepad, or `0` if unavailable.
C: `SDL_GetGamepadProductVersionForID`. -/
def gamepadProductVersion (self : JoystickId) : IO UInt16 := gamepadProductVersionRaw self.val

@[extern "lean_sdl_get_gamepad_type_for_id"]
private opaque gamepadTypeRaw (id : UInt32) : IO UInt32

/-- The type of a gamepad. C: `SDL_GetGamepadTypeForID`. -/
def gamepadType (self : JoystickId) : IO GamepadType := do
  return GamepadType.ofVal (← gamepadTypeRaw self.val)

@[extern "lean_sdl_get_real_gamepad_type_for_id"]
private opaque realGamepadTypeRaw (id : UInt32) : IO UInt32

/-- The type of a gamepad, ignoring any mapping override.
C: `SDL_GetRealGamepadTypeForID`. -/
def realGamepadType (self : JoystickId) : IO GamepadType := do
  return GamepadType.ofVal (← realGamepadTypeRaw self.val)

@[extern "lean_sdl_get_gamepad_mapping_for_id"]
private opaque gamepadMappingRaw (id : UInt32) : IO (Option String)

/-- The mapping string of a gamepad, or `none` if none is available.
C: `SDL_GetGamepadMappingForID`. -/
def gamepadMapping (self : JoystickId) : IO (Option String) := gamepadMappingRaw self.val

end JoystickId

/-! ## `Gamepad` methods -/

namespace Gamepad

/-- Close a gamepad previously opened with `openGamepad`. The handle is invalid
afterwards, so later use is a clean IO error. Because SDL refcounts gamepads,
closing one handle does not invalidate other handles for the same device.
C: `SDL_CloseGamepad`. -/
@[extern "lean_sdl_close_gamepad"]
opaque close (self : @& Gamepad) : IO Unit

/-- The properties associated with the gamepad (read-only capability booleans;
see the `propCap*` keys). Borrowed: tied to the gamepad's lifetime, never
destroyed from Lean. Throws on failure. C: `SDL_GetGamepadProperties`. -/
@[extern "lean_sdl_get_gamepad_properties"]
opaque getProperties (self : @& Gamepad) : IO Properties

@[extern "lean_sdl_get_gamepad_id"]
private opaque getIDRaw (self : @& Gamepad) : IO UInt32

/-- The instance id of the gamepad. Throws (`0`) on failure.
C: `SDL_GetGamepadID`. -/
def getID (self : @& Gamepad) : IO JoystickId := do return ⟨← getIDRaw self⟩

@[extern "lean_sdl_get_gamepad_name"]
private opaque nameRaw (self : @& Gamepad) : IO String

/-- The implementation-dependent name of the gamepad. Throws if unavailable.
C: `SDL_GetGamepadName`. -/
def name (self : @& Gamepad) : IO String := nameRaw self

@[extern "lean_sdl_get_gamepad_path"]
private opaque pathRaw (self : @& Gamepad) : IO (Option String)

/-- The implementation-dependent path of the gamepad, or `none` if unavailable.
C: `SDL_GetGamepadPath`. -/
def path (self : @& Gamepad) : IO (Option String) := pathRaw self

@[extern "lean_sdl_get_gamepad_type"]
private opaque getTypeRaw (self : @& Gamepad) : IO UInt32

/-- The type of the gamepad (`.unknown` if unavailable). C: `SDL_GetGamepadType`. -/
def getType (self : @& Gamepad) : IO GamepadType := do
  return GamepadType.ofVal (← getTypeRaw self)

@[extern "lean_sdl_get_real_gamepad_type"]
private opaque realTypeRaw (self : @& Gamepad) : IO UInt32

/-- The type of the gamepad, ignoring any mapping override.
C: `SDL_GetRealGamepadType`. -/
def realType (self : @& Gamepad) : IO GamepadType := do
  return GamepadType.ofVal (← realTypeRaw self)

@[extern "lean_sdl_get_gamepad_player_index"]
private opaque playerIndexRaw (self : @& Gamepad) : IO Int32

/-- The player index of the gamepad, or `none` (`-1`) if unavailable.
C: `SDL_GetGamepadPlayerIndex`. -/
def playerIndex (self : @& Gamepad) : IO (Option Int32) := do
  let v ← playerIndexRaw self
  return if v < 0 then none else some v

@[extern "lean_sdl_set_gamepad_player_index"]
private opaque setPlayerIndexRaw (self : @& Gamepad) (idx : Int32) : IO Unit

/-- Set the player index of the gamepad (`none` clears it and turns off player
LEDs). Throws on failure. C: `SDL_SetGamepadPlayerIndex`. -/
def setPlayerIndex (self : @& Gamepad) (idx : Option Int32) : IO Unit :=
  setPlayerIndexRaw self (idx.getD (-1))

@[extern "lean_sdl_get_gamepad_vendor"]
private opaque vendorRaw (self : @& Gamepad) : IO UInt16

/-- The USB vendor id of the gamepad, or `0` if unavailable.
C: `SDL_GetGamepadVendor`. -/
def vendor (self : @& Gamepad) : IO UInt16 := vendorRaw self

@[extern "lean_sdl_get_gamepad_product"]
private opaque productRaw (self : @& Gamepad) : IO UInt16

/-- The USB product id of the gamepad, or `0` if unavailable.
C: `SDL_GetGamepadProduct`. -/
def product (self : @& Gamepad) : IO UInt16 := productRaw self

@[extern "lean_sdl_get_gamepad_product_version"]
private opaque productVersionRaw (self : @& Gamepad) : IO UInt16

/-- The product version of the gamepad, or `0` if unavailable.
C: `SDL_GetGamepadProductVersion`. -/
def productVersion (self : @& Gamepad) : IO UInt16 := productVersionRaw self

@[extern "lean_sdl_get_gamepad_firmware_version"]
private opaque firmwareVersionRaw (self : @& Gamepad) : IO UInt16

/-- The firmware version of the gamepad, or `0` if unavailable.
C: `SDL_GetGamepadFirmwareVersion`. -/
def firmwareVersion (self : @& Gamepad) : IO UInt16 := firmwareVersionRaw self

@[extern "lean_sdl_get_gamepad_serial"]
private opaque serialRaw (self : @& Gamepad) : IO (Option String)

/-- The serial number of the gamepad, or `none` if unavailable.
C: `SDL_GetGamepadSerial`. -/
def serial (self : @& Gamepad) : IO (Option String) := serialRaw self

/-- The Steam Input handle of the gamepad (`0` if unavailable). Kept as a raw
`UInt64`. C: `SDL_GetGamepadSteamHandle`. -/
@[extern "lean_sdl_get_gamepad_steam_handle"]
opaque steamHandle (self : @& Gamepad) : IO UInt64

@[extern "lean_sdl_get_gamepad_connection_state"]
private opaque connectionStateRaw (self : @& Gamepad) : IO UInt32

/-- The connection state of the gamepad. Throws
(`SDL_JOYSTICK_CONNECTION_INVALID`) on failure.
C: `SDL_GetGamepadConnectionState`. -/
def connectionState (self : @& Gamepad) : IO JoystickConnectionState := do
  return (JoystickConnectionState.ofVal? (← connectionStateRaw self)).getD .unknown

@[extern "lean_sdl_get_gamepad_power_info"]
private opaque powerInfoRaw (self : @& Gamepad) : IO (UInt32 × Int32)

/-- The gamepad's battery `(state, percent)`; `percent` is `none` when unknown or
there is no battery. Throws (`SDL_POWERSTATE_ERROR`) on failure. Treat battery
readings as rough estimates. C: `SDL_GetGamepadPowerInfo`. -/
def powerInfo (self : @& Gamepad) : IO (PowerState × Option Int32) := do
  let (st, pct) ← powerInfoRaw self
  return ((PowerState.ofVal? st).getD .unknown, if pct < 0 then none else some pct)

/-- Whether the gamepad has been opened and is currently connected.
C: `SDL_GamepadConnected`. -/
@[extern "lean_sdl_gamepad_connected"]
opaque connected (self : @& Gamepad) : IO Bool

/-- The underlying joystick of the gamepad. The returned handle **owns its own
reference** (SDL re-opens the joystick internally), so it is safe to use after
the gamepad closes and closing it does not affect the gamepad.
C: `SDL_GetGamepadJoystick`. -/
@[extern "lean_sdl_get_gamepad_joystick"]
opaque getJoystick (self : @& Gamepad) : IO Joystick

/-- The SDL joystick-layer bindings for the gamepad. Throws on failure.
C: `SDL_GetGamepadBindings`. -/
@[extern "lean_sdl_get_gamepad_bindings"]
opaque getBindings (self : @& Gamepad) : IO (Array GamepadBinding)

@[extern "lean_sdl_get_gamepad_mapping"]
private opaque getMappingRaw (self : @& Gamepad) : IO (Option String)

/-- The current mapping string of the gamepad, or `none` if none is available.
C: `SDL_GetGamepadMapping`. -/
def getMapping (self : @& Gamepad) : IO (Option String) := getMappingRaw self

@[extern "lean_sdl_gamepad_has_axis"]
private opaque hasAxisRaw (self : @& Gamepad) (axis : UInt8) : IO Bool

/-- Whether the gamepad's mapping defines a given axis. C: `SDL_GamepadHasAxis`. -/
def hasAxis (self : @& Gamepad) (axis : GamepadAxis) : IO Bool := hasAxisRaw self axis.val

@[extern "lean_sdl_get_gamepad_axis"]
private opaque getAxisRaw (self : @& Gamepad) (axis : UInt8) : IO Int16

/-- The current state of an axis (`-32768`..`32767` for sticks, `0`..`32767` for
triggers). SDL conflates a genuine `0` reading with an invalid axis, so this does
**not** throw. C: `SDL_GetGamepadAxis`. -/
def getAxis (self : @& Gamepad) (axis : GamepadAxis) : IO Int16 := getAxisRaw self axis.val

@[extern "lean_sdl_gamepad_has_button"]
private opaque hasButtonRaw (self : @& Gamepad) (button : UInt8) : IO Bool

/-- Whether the gamepad's mapping defines a given button.
C: `SDL_GamepadHasButton`. -/
def hasButton (self : @& Gamepad) (button : GamepadButton) : IO Bool := hasButtonRaw self button.val

@[extern "lean_sdl_get_gamepad_button"]
private opaque getButtonRaw (self : @& Gamepad) (button : UInt8) : IO Bool

/-- Whether a button is currently pressed. C: `SDL_GetGamepadButton`. -/
def getButton (self : @& Gamepad) (button : GamepadButton) : IO Bool := getButtonRaw self button.val

@[extern "lean_sdl_get_gamepad_button_label"]
private opaque buttonLabelRaw (self : @& Gamepad) (button : UInt8) : IO UInt32

/-- The label of a face button on the gamepad. C: `SDL_GetGamepadButtonLabel`. -/
def buttonLabel (self : @& Gamepad) (button : GamepadButton) : IO GamepadButtonLabel := do
  return GamepadButtonLabel.ofVal (← buttonLabelRaw self button.val)

/-- The number of touchpads on the gamepad. C: `SDL_GetNumGamepadTouchpads`. -/
@[extern "lean_sdl_get_num_gamepad_touchpads"]
opaque numTouchpads (self : @& Gamepad) : IO Int32

/-- The number of simultaneous fingers supported on a touchpad.
C: `SDL_GetNumGamepadTouchpadFingers`. -/
@[extern "lean_sdl_get_num_gamepad_touchpad_fingers"]
opaque numTouchpadFingers (self : @& Gamepad) (touchpad : Int32) : IO Int32

/-- The current state `(down, x, y, pressure)` of a finger on a touchpad
(`x`/`y` normalized `0` to `1`, origin upper-left). Throws on failure.
C: `SDL_GetGamepadTouchpadFinger`. -/
@[extern "lean_sdl_get_gamepad_touchpad_finger"]
opaque getTouchpadFinger (self : @& Gamepad) (touchpad finger : Int32) :
  IO (Bool × Float32 × Float32 × Float32)

@[extern "lean_sdl_gamepad_has_sensor"]
private opaque hasSensorRaw (self : @& Gamepad) (type : UInt32) : IO Bool

/-- Whether the gamepad has a particular sensor. C: `SDL_GamepadHasSensor`. -/
def hasSensor (self : @& Gamepad) (type : SensorType) : IO Bool := hasSensorRaw self type.val

@[extern "lean_sdl_set_gamepad_sensor_enabled"]
private opaque setSensorEnabledRaw (self : @& Gamepad) (type : UInt32) (enabled : Bool) : IO Unit

/-- Enable or disable data reporting for a gamepad sensor. Throws on failure.
C: `SDL_SetGamepadSensorEnabled`. -/
def setSensorEnabled (self : @& Gamepad) (type : SensorType) (enabled : Bool) : IO Unit :=
  setSensorEnabledRaw self type.val enabled

@[extern "lean_sdl_gamepad_sensor_enabled"]
private opaque sensorEnabledRaw (self : @& Gamepad) (type : UInt32) : IO Bool

/-- Whether sensor data reporting is enabled for a gamepad sensor.
C: `SDL_GamepadSensorEnabled`. -/
def sensorEnabled (self : @& Gamepad) (type : SensorType) : IO Bool := sensorEnabledRaw self type.val

@[extern "lean_sdl_get_gamepad_sensor_data_rate"]
private opaque sensorDataRateRaw (self : @& Gamepad) (type : UInt32) : IO Float32

/-- The data rate (events per second) of a gamepad sensor, or `0.0` if
unavailable (not treated as an error). C: `SDL_GetGamepadSensorDataRate`. -/
def sensorDataRate (self : @& Gamepad) (type : SensorType) : IO Float32 :=
  sensorDataRateRaw self type.val

@[extern "lean_sdl_get_gamepad_sensor_data"]
private opaque getSensorDataRaw (self : @& Gamepad) (type : UInt32) (numValues : Int32) :
  IO FloatArray

/-- The current state of a gamepad sensor: `numValues` reading values widened
from 32-bit floats to `Float`. Throws on failure. C: `SDL_GetGamepadSensorData`. -/
def getSensorData (self : @& Gamepad) (type : SensorType) (numValues : Int32) : IO FloatArray :=
  getSensorDataRaw self type.val numValues

/-- Start a rumble effect (motor intensities `0`..`0xFFFF`, `duration_ms`).
Returns `false` if rumble is unsupported on this gamepad (not an error).
C: `SDL_RumbleGamepad`. -/
@[extern "lean_sdl_rumble_gamepad"]
opaque rumble (self : @& Gamepad) (lowFrequency highFrequency : UInt16)
  (durationMs : UInt32) : IO Bool

/-- Start a trigger rumble effect (Xbox One only). Returns `false` if unsupported
(not an error). C: `SDL_RumbleGamepadTriggers`. -/
@[extern "lean_sdl_rumble_gamepad_triggers"]
opaque rumbleTriggers (self : @& Gamepad) (left right : UInt16)
  (durationMs : UInt32) : IO Bool

/-- Set the gamepad's LED color. Returns `false` if the gamepad has no settable
LED (not an error). C: `SDL_SetGamepadLED`. -/
@[extern "lean_sdl_set_gamepad_led"]
opaque setLED (self : @& Gamepad) (red green blue : UInt8) : IO Bool

/-- Send a gamepad-specific effect packet. Returns `false` if unsupported (not an
error). C: `SDL_SendGamepadEffect`. -/
@[extern "lean_sdl_send_gamepad_effect"]
opaque sendEffect (self : @& Gamepad) (data : @& ByteArray) : IO Bool

@[extern "lean_sdl_get_gamepad_apple_sf_symbols_name_for_button"]
private opaque appleSFSymbolsNameForButtonRaw (self : @& Gamepad) (button : UInt8) :
  IO (Option String)

/-- The Apple SF Symbols name for a button (Apple platforms), or `none` if not
found. C: `SDL_GetGamepadAppleSFSymbolsNameForButton`. -/
def appleSFSymbolsNameForButton (self : @& Gamepad) (button : GamepadButton) :
    IO (Option String) :=
  appleSFSymbolsNameForButtonRaw self button.val

@[extern "lean_sdl_get_gamepad_apple_sf_symbols_name_for_axis"]
private opaque appleSFSymbolsNameForAxisRaw (self : @& Gamepad) (axis : UInt8) :
  IO (Option String)

/-- The Apple SF Symbols name for an axis (Apple platforms), or `none` if not
found. C: `SDL_GetGamepadAppleSFSymbolsNameForAxis`. -/
def appleSFSymbolsNameForAxis (self : @& Gamepad) (axis : GamepadAxis) :
    IO (Option String) :=
  appleSFSymbolsNameForAxisRaw self axis.val

end Gamepad
end Sdl
