module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros
public import Sdl.Error
public meta import Sdl.Error
public import Sdl.Joystick
public meta import Sdl.Joystick

public section

/-!
# Haptics (`SDL_haptic.h`) — partial binding

The haptic (force-feedback) subsystem. `SDL_Init` must have been called with
`SDL_INIT_HAPTIC` before haptic devices can be opened. This is a **partial**
binding: the full device/effect surface is bound, but two effect variants that
need force-feedback hardware to exercise are omitted (see *Skipped* below).

## Ownership

`Haptic` is an **owned root**: the finalizer runs `SDL_CloseHaptic` and the
holder's `owner` is always `NULL`. `Haptic.close` is a *manual* destroy that
NULLs the handle, so later use is a clean IO error.

Unlike joysticks/gamepads, SDL's haptic open is **not** documented as
refcounted. `getHapticFromID` still takes a fresh reference via
`SDL_OpenHaptic(id)` (mirroring the joystick shape), but prefer keeping a single
`Haptic` handle per device: closing any handle closes the device for all of
them. This is untestable without hardware; safety within the binding comes from
`SDL_GET_OR_THROW` guarding our own NULLed handles.

## Skipped (documented plan-level omissions)

- `SDL_HapticCondition` (spring / damper / inertia / friction — 4-axis array
  parameters) and `SDL_HapticCustom` (raw sample upload) effect variants are not
  bound: they are niche and untestable without force-feedback hardware. Their
  `HapticFeatures` flags (`.spring`, `.damper`, `.inertia`, `.friction`,
  `.custom`) are still reported.
-/

namespace Sdl

/-- An opened haptic device. C: `SDL_Haptic`. -/
sdl_opaque Haptic

@[extern "lean_sdl_haptic_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

/-- The instance id of a haptic device (`0` is invalid). C: `SDL_HapticID`. -/
sdl_id HapticId : UInt32

/-- The id of an uploaded haptic effect (`-1` is invalid). C:
`SDL_HapticEffectID` (a plain `int` handle returned by
`SDL_CreateHapticEffect`). Deviation: modelled with `sdl_id … : Int32` rather
than a `UInt`-typed id, matching the signed C handle. -/
sdl_id HapticEffectId : Int32

/-- The haptic features a device can support (a bitmask). Bits `0`..`15` are
effect types; bits `16`..`19` are device capabilities. C: `SDL_HAPTIC_*`. -/
sdl_flags HapticFeatures : UInt32 where
  | constant     := 0x1      -- C: SDL_HAPTIC_CONSTANT
  | sine         := 0x2      -- C: SDL_HAPTIC_SINE
  | square       := 0x4      -- C: SDL_HAPTIC_SQUARE
  | triangle     := 0x8      -- C: SDL_HAPTIC_TRIANGLE
  | sawtoothUp   := 0x10     -- C: SDL_HAPTIC_SAWTOOTHUP
  | sawtoothDown := 0x20     -- C: SDL_HAPTIC_SAWTOOTHDOWN
  | ramp         := 0x40     -- C: SDL_HAPTIC_RAMP
  | spring       := 0x80     -- C: SDL_HAPTIC_SPRING
  | damper       := 0x100    -- C: SDL_HAPTIC_DAMPER
  | inertia      := 0x200    -- C: SDL_HAPTIC_INERTIA
  | friction     := 0x400    -- C: SDL_HAPTIC_FRICTION
  | leftRight    := 0x800    -- C: SDL_HAPTIC_LEFTRIGHT
  | custom       := 0x8000   -- C: SDL_HAPTIC_CUSTOM
  | gain         := 0x10000  -- C: SDL_HAPTIC_GAIN
  | autocenter   := 0x20000  -- C: SDL_HAPTIC_AUTOCENTER
  | status       := 0x40000  -- C: SDL_HAPTIC_STATUS
  | pause        := 0x80000  -- C: SDL_HAPTIC_PAUSE

/-- Play an effect an infinite number of times (pass as `runEffect`'s
`iterations`, or as an effect's `length`). C: `SDL_HAPTIC_INFINITY`. -/
def hapticInfinity : UInt32 := 0xFFFFFFFF

#guard hapticInfinity == 0xFFFFFFFF

/-! ## Effect templates -/

/-- Direction encoding for a haptic effect. The direction is where the force
comes *from*. C: `SDL_HapticDirection` (`type` is
`SDL_HAPTIC_POLAR`/`CARTESIAN`/`SPHERICAL`/`STEERING_AXIS`). -/
inductive HapticDirection where
  | polar (degreesHundredths : Int32)      -- C: SDL_HAPTIC_POLAR, dir[0]
  | cartesian (x y z : Int32)              -- C: SDL_HAPTIC_CARTESIAN, dir[0..2]
  | spherical (a b : Int32)                -- C: SDL_HAPTIC_SPHERICAL, dir[0..1]
  | steeringAxis                           -- C: SDL_HAPTIC_STEERING_AXIS
  deriving Repr, BEq, Inhabited

/-- Periodic waveform selector. C: the `type` field of `SDL_HapticPeriodic`. -/
inductive HapticWave where
  | sine          -- C: SDL_HAPTIC_SINE
  | square        -- C: SDL_HAPTIC_SQUARE
  | triangle      -- C: SDL_HAPTIC_TRIANGLE
  | sawtoothUp    -- C: SDL_HAPTIC_SAWTOOTHUP
  | sawtoothDown  -- C: SDL_HAPTIC_SAWTOOTHDOWN
  deriving Repr, BEq, Inhabited

/-- The `SDL_HapticEffectType` value SDL stores in the effect's `.type` field for
this waveform (identical to the matching `SDL_HAPTIC_*` feature bit). -/
def HapticWave.effectType : HapticWave → UInt32
  | .sine         => 0x2   -- C: SDL_HAPTIC_SINE
  | .square       => 0x4   -- C: SDL_HAPTIC_SQUARE
  | .triangle     => 0x8   -- C: SDL_HAPTIC_TRIANGLE
  | .sawtoothUp   => 0x10  -- C: SDL_HAPTIC_SAWTOOTHUP
  | .sawtoothDown => 0x20  -- C: SDL_HAPTIC_SAWTOOTHDOWN

/-- A haptic effect (partial: `SDL_HapticCondition` and `SDL_HapticCustom` are
not bound — see the module docstring). C: `SDL_HapticEffect`. -/
inductive HapticEffect where
  | constant (direction : HapticDirection) (length : UInt32) (delay : UInt16)
      (button : UInt16) (interval : UInt16) (level : Int16)
      (attackLength : UInt16) (attackLevel : UInt16)
      (fadeLength : UInt16) (fadeLevel : UInt16)   -- C: SDL_HapticConstant
  | periodic (wave : HapticWave) (direction : HapticDirection)
      (length : UInt32) (delay : UInt16) (button : UInt16) (interval : UInt16)
      (period : UInt16) (magnitude : Int16) (offset : Int16) (phase : UInt16)
      (attackLength : UInt16) (attackLevel : UInt16)
      (fadeLength : UInt16) (fadeLevel : UInt16)   -- C: SDL_HapticPeriodic
  | ramp (direction : HapticDirection) (length : UInt32) (delay : UInt16)
      (button : UInt16) (interval : UInt16) (start : Int16) (end_ : Int16)
      (attackLength : UInt16) (attackLevel : UInt16)
      (fadeLength : UInt16) (fadeLevel : UInt16)   -- C: SDL_HapticRamp
  | leftRight (length : UInt32) (largeMagnitude smallMagnitude : UInt16)
                                                    -- C: SDL_HapticLeftRight
  deriving Repr, BEq, Inhabited

/-- Flattened scalar view of a `HapticEffect` for the FFI boundary: a fixed
field order with zeros for fields a variant lacks. The C shim `memset`s an
`SDL_HapticEffect` and, switching on `effectType`, fills the right union member. -/
private structure HapticEffectRaw where
  effectType : UInt32
  dirType : UInt32
  dir0 : Int32
  dir1 : Int32
  dir2 : Int32
  length : UInt32
  delay : UInt16
  button : UInt16
  interval : UInt16
  level : Int16
  period : UInt16
  magnitude : Int16
  offset : Int16
  phase : UInt16
  rampStart : Int16
  rampEnd : Int16
  largeMagnitude : UInt16
  smallMagnitude : UInt16
  attackLength : UInt16
  attackLevel : UInt16
  fadeLength : UInt16
  fadeLevel : UInt16

/-- Encode a `HapticDirection` as `(type, dir0, dir1, dir2)`. -/
private def HapticDirection.encode : HapticDirection → UInt32 × Int32 × Int32 × Int32
  | .polar d       => (0, d, 0, 0)  -- C: SDL_HAPTIC_POLAR
  | .cartesian x y z => (1, x, y, z)  -- C: SDL_HAPTIC_CARTESIAN
  | .spherical a b => (2, a, b, 0)  -- C: SDL_HAPTIC_SPHERICAL
  | .steeringAxis  => (3, 0, 0, 0)  -- C: SDL_HAPTIC_STEERING_AXIS

/-- Flatten a `HapticEffect` into its raw scalar view. -/
private def HapticEffect.toRaw : HapticEffect → HapticEffectRaw
  | .constant dir length delay button interval level aL aLv fL fLv =>
    let (dt, d0, d1, d2) := dir.encode
    { effectType := 0x1, dirType := dt, dir0 := d0, dir1 := d1, dir2 := d2,
      length, delay, button, interval, level, period := 0, magnitude := 0,
      offset := 0, phase := 0, rampStart := 0, rampEnd := 0,
      largeMagnitude := 0, smallMagnitude := 0,
      attackLength := aL, attackLevel := aLv, fadeLength := fL, fadeLevel := fLv }
  | .periodic wave dir length delay button interval period magnitude offset phase aL aLv fL fLv =>
    let (dt, d0, d1, d2) := dir.encode
    { effectType := wave.effectType, dirType := dt, dir0 := d0, dir1 := d1, dir2 := d2,
      length, delay, button, interval, level := 0, period, magnitude, offset, phase,
      rampStart := 0, rampEnd := 0, largeMagnitude := 0, smallMagnitude := 0,
      attackLength := aL, attackLevel := aLv, fadeLength := fL, fadeLevel := fLv }
  | .ramp dir length delay button interval start end_ aL aLv fL fLv =>
    let (dt, d0, d1, d2) := dir.encode
    { effectType := 0x40, dirType := dt, dir0 := d0, dir1 := d1, dir2 := d2,
      length, delay, button, interval, level := 0, period := 0, magnitude := 0,
      offset := 0, phase := 0, rampStart := start, rampEnd := end_,
      largeMagnitude := 0, smallMagnitude := 0,
      attackLength := aL, attackLevel := aLv, fadeLength := fL, fadeLevel := fLv }
  | .leftRight length large small =>
    { effectType := 0x800, dirType := 0, dir0 := 0, dir1 := 0, dir2 := 0,
      length, delay := 0, button := 0, interval := 0, level := 0, period := 0,
      magnitude := 0, offset := 0, phase := 0, rampStart := 0, rampEnd := 0,
      largeMagnitude := large, smallMagnitude := small,
      attackLength := 0, attackLevel := 0, fadeLength := 0, fadeLevel := 0 }

/-! ## Top-level functions -/

@[extern "lean_sdl_get_haptics"]
private opaque getHapticsRaw : IO (Array UInt32)

/-- The currently-connected haptic devices. Throws on failure.
C: `SDL_GetHaptics`. -/
def getHaptics : IO (Array HapticId) := do
  return (← getHapticsRaw).map (⟨·⟩)

@[extern "lean_sdl_open_haptic"]
private opaque openHapticRaw (id : UInt32) : IO Haptic

/-- Open a haptic device for use. Throws on failure. C: `SDL_OpenHaptic`. -/
def openHaptic (id : HapticId) : IO Haptic := openHapticRaw id.val

@[extern "lean_sdl_get_haptic_from_id"]
private opaque getHapticFromIDRaw (id : UInt32) : IO (Option Haptic)

/-- The opened haptic device with instance id `id`, or `none` if it has not been
opened. Takes a fresh reference (`SDL_OpenHaptic(id)`). ⚠️ SDL's haptic open is
not documented as refcounted: prefer keeping a single `Haptic` handle per device
— closing any handle closes the device for all of them.
C: `SDL_GetHapticFromID`. -/
def getHapticFromID (id : HapticId) : IO (Option Haptic) := getHapticFromIDRaw id.val

/-- Whether the current mouse has haptic capabilities. C: `SDL_IsMouseHaptic`. -/
@[extern "lean_sdl_is_mouse_haptic"]
opaque isMouseHaptic : IO Bool

/-- Try to open a haptic device from the current mouse. Throws on failure.
C: `SDL_OpenHapticFromMouse`. -/
@[extern "lean_sdl_open_haptic_from_mouse"]
opaque openHapticFromMouse : IO Haptic

/-- Whether a joystick has haptic features. C: `SDL_IsJoystickHaptic`. -/
@[extern "lean_sdl_is_joystick_haptic"]
opaque isJoystickHaptic (joystick : @& Joystick) : IO Bool

/-- Open a haptic device from a joystick. Close the haptic device before the
joystick. Throws on failure (e.g. the joystick is not haptic).
C: `SDL_OpenHapticFromJoystick`. -/
@[extern "lean_sdl_open_haptic_from_joystick"]
opaque openHapticFromJoystick (joystick : @& Joystick) : IO Haptic

namespace HapticId

@[extern "lean_sdl_get_haptic_name_for_id"]
private opaque nameRaw (id : UInt32) : IO String

/-- The implementation-dependent name of a haptic device. Throws if no name is
available. C: `SDL_GetHapticNameForID`. -/
def name (self : HapticId) : IO String := nameRaw self.val

end HapticId

/-! ## `Haptic` methods -/

namespace Haptic

/-- Close a haptic device previously opened with `openHaptic`. The handle is
invalid afterwards, so later use is a clean IO error. ⚠️ Closing any handle
closes the underlying device for all handles (haptic open is not refcounted).
C: `SDL_CloseHaptic`. -/
@[extern "lean_sdl_close_haptic"]
opaque close (self : @& Haptic) : IO Unit

@[extern "lean_sdl_get_haptic_id"]
private opaque getIDRaw (self : @& Haptic) : IO UInt32

/-- The instance id of the haptic device. Throws (`0`) on failure.
C: `SDL_GetHapticID`. -/
def getID (self : @& Haptic) : IO HapticId := do return ⟨← getIDRaw self⟩

/-- The implementation-dependent name of the haptic device, or `none` if it has
no name. C: `SDL_GetHapticName`. -/
@[extern "lean_sdl_get_haptic_name"]
opaque name (self : @& Haptic) : IO (Option String)

/-- The number of effects the device can store. Throws (`-1`) on failure.
C: `SDL_GetMaxHapticEffects`. -/
@[extern "lean_sdl_get_max_haptic_effects"]
opaque maxEffects (self : @& Haptic) : IO Int32

/-- The number of effects the device can play at the same time. Throws (`-1`) on
failure. C: `SDL_GetMaxHapticEffectsPlaying`. -/
@[extern "lean_sdl_get_max_haptic_effects_playing"]
opaque maxEffectsPlaying (self : @& Haptic) : IO Int32

@[extern "lean_sdl_get_haptic_features"]
private opaque featuresRaw (self : @& Haptic) : IO UInt32

/-- The device's supported features (a bitmask). Throws (`0`) on failure.
C: `SDL_GetHapticFeatures`. -/
def features (self : @& Haptic) : IO HapticFeatures := do return ⟨← featuresRaw self⟩

/-- The number of haptic axes the device has. Throws (`-1`) on failure.
C: `SDL_GetNumHapticAxes`. -/
@[extern "lean_sdl_get_num_haptic_axes"]
opaque numAxes (self : @& Haptic) : IO Int32

@[extern "lean_sdl_haptic_effect_supported"]
private opaque effectSupportedRaw (self : @& Haptic)
  (effectType dirType : UInt32) (dir0 dir1 dir2 : Int32)
  (length : UInt32) (delay button interval : UInt16) (level : Int16)
  (period : UInt16) (magnitude offset : Int16) (phase : UInt16)
  (rampStart rampEnd : Int16) (largeMagnitude smallMagnitude : UInt16)
  (attackLength attackLevel fadeLength fadeLevel : UInt16) : IO Bool

/-- Whether an effect is supported by the device.
C: `SDL_HapticEffectSupported`. -/
def effectSupported (self : @& Haptic) (effect : @& HapticEffect) : IO Bool :=
  let r := effect.toRaw
  effectSupportedRaw self r.effectType r.dirType r.dir0 r.dir1 r.dir2 r.length
    r.delay r.button r.interval r.level r.period r.magnitude r.offset r.phase
    r.rampStart r.rampEnd r.largeMagnitude r.smallMagnitude
    r.attackLength r.attackLevel r.fadeLength r.fadeLevel

@[extern "lean_sdl_create_haptic_effect"]
private opaque createEffectRaw (self : @& Haptic)
  (effectType dirType : UInt32) (dir0 dir1 dir2 : Int32)
  (length : UInt32) (delay button interval : UInt16) (level : Int16)
  (period : UInt16) (magnitude offset : Int16) (phase : UInt16)
  (rampStart rampEnd : Int16) (largeMagnitude smallMagnitude : UInt16)
  (attackLength attackLevel fadeLength fadeLevel : UInt16) : IO Int32

/-- Create a new effect on the device, returning its id. Throws (`-1`) on
failure. C: `SDL_CreateHapticEffect`. -/
def createEffect (self : @& Haptic) (effect : @& HapticEffect) : IO HapticEffectId := do
  let r := effect.toRaw
  return ⟨← createEffectRaw self r.effectType r.dirType r.dir0 r.dir1 r.dir2 r.length
    r.delay r.button r.interval r.level r.period r.magnitude r.offset r.phase
    r.rampStart r.rampEnd r.largeMagnitude r.smallMagnitude
    r.attackLength r.attackLevel r.fadeLength r.fadeLevel⟩

@[extern "lean_sdl_update_haptic_effect"]
private opaque updateEffectRaw (self : @& Haptic) (id : Int32)
  (effectType dirType : UInt32) (dir0 dir1 dir2 : Int32)
  (length : UInt32) (delay button interval : UInt16) (level : Int16)
  (period : UInt16) (magnitude offset : Int16) (phase : UInt16)
  (rampStart rampEnd : Int16) (largeMagnitude smallMagnitude : UInt16)
  (attackLength attackLevel fadeLength fadeLevel : UInt16) : IO Unit

/-- Update the properties of an existing effect (the effect type cannot change).
Throws on failure. C: `SDL_UpdateHapticEffect`. -/
def updateEffect (self : @& Haptic) (id : HapticEffectId) (effect : @& HapticEffect) : IO Unit :=
  let r := effect.toRaw
  updateEffectRaw self id.val r.effectType r.dirType r.dir0 r.dir1 r.dir2 r.length
    r.delay r.button r.interval r.level r.period r.magnitude r.offset r.phase
    r.rampStart r.rampEnd r.largeMagnitude r.smallMagnitude
    r.attackLength r.attackLevel r.fadeLength r.fadeLevel

@[extern "lean_sdl_run_haptic_effect"]
private opaque runEffectRaw (self : @& Haptic) (id : Int32) (iterations : UInt32) : IO Unit

/-- Run an effect. Pass `hapticInfinity` as `iterations` to repeat forever.
Throws on failure. C: `SDL_RunHapticEffect`. -/
def runEffect (self : @& Haptic) (id : HapticEffectId) (iterations : UInt32) : IO Unit :=
  runEffectRaw self id.val iterations

@[extern "lean_sdl_stop_haptic_effect"]
private opaque stopEffectRaw (self : @& Haptic) (id : Int32) : IO Unit

/-- Stop a running effect. Throws on failure. C: `SDL_StopHapticEffect`. -/
def stopEffect (self : @& Haptic) (id : HapticEffectId) : IO Unit := stopEffectRaw self id.val

@[extern "lean_sdl_destroy_haptic_effect"]
private opaque destroyEffectRaw (self : @& Haptic) (id : Int32) : IO Unit

/-- Destroy an effect (stopping it first if running). Effects are automatically
destroyed when the device is closed. C: `SDL_DestroyHapticEffect` (void). -/
def destroyEffect (self : @& Haptic) (id : HapticEffectId) : IO Unit := destroyEffectRaw self id.val

@[extern "lean_sdl_get_haptic_effect_status"]
private opaque effectStatusRaw (self : @& Haptic) (id : Int32) : IO Bool

/-- Whether an effect is currently playing. Requires the `.status` feature;
returns `false` if the effect is not playing or status is unsupported.
C: `SDL_GetHapticEffectStatus`. -/
def effectStatus (self : @& Haptic) (id : HapticEffectId) : IO Bool := effectStatusRaw self id.val

/-- Set the global gain of the device (`0`..`100`). Requires the `.gain`
feature. Throws on failure. C: `SDL_SetHapticGain`. -/
@[extern "lean_sdl_set_haptic_gain"]
opaque setGain (self : @& Haptic) (gain : Int32) : IO Unit

/-- Set the global autocenter of the device (`0`..`100`; `0` disables). Requires
the `.autocenter` feature. Throws on failure. C: `SDL_SetHapticAutocenter`. -/
@[extern "lean_sdl_set_haptic_autocenter"]
opaque setAutocenter (self : @& Haptic) (autocenter : Int32) : IO Unit

/-- Pause the device. Requires the `.pause` feature. Throws on failure.
C: `SDL_PauseHaptic`. -/
@[extern "lean_sdl_pause_haptic"]
opaque pause (self : @& Haptic) : IO Unit

/-- Resume the device after `pause`. Throws on failure. C: `SDL_ResumeHaptic`. -/
@[extern "lean_sdl_resume_haptic"]
opaque resume (self : @& Haptic) : IO Unit

/-- Stop all currently-playing effects on the device. Throws on failure.
C: `SDL_StopHapticEffects`. -/
@[extern "lean_sdl_stop_haptic_effects"]
opaque stopEffects (self : @& Haptic) : IO Unit

/-- Whether simple rumble is supported on the device.
C: `SDL_HapticRumbleSupported`. -/
@[extern "lean_sdl_haptic_rumble_supported"]
opaque rumbleSupported (self : @& Haptic) : IO Bool

/-- Initialize the device for simple rumble playback. Throws on failure.
C: `SDL_InitHapticRumble`. -/
@[extern "lean_sdl_init_haptic_rumble"]
opaque initRumble (self : @& Haptic) : IO Unit

/-- Run a simple rumble effect (`strength` as a `0`-`1` float, `lengthMs`).
Throws on failure. C: `SDL_PlayHapticRumble`. -/
@[extern "lean_sdl_play_haptic_rumble"]
opaque playRumble (self : @& Haptic) (strength : Float32) (lengthMs : UInt32) : IO Unit

/-- Stop the simple rumble effect. Throws on failure. C: `SDL_StopHapticRumble`. -/
@[extern "lean_sdl_stop_haptic_rumble"]
opaque stopRumble (self : @& Haptic) : IO Unit

end Haptic
end Sdl

end
