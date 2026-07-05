import Sdl.Core.Macros
import Sdl.Error

/-!
# Power management (`SDL_power.h`)

A single query, `getPowerInfo`. The C error sentinel `SDL_POWERSTATE_ERROR`
(-1) is not a Lean `PowerState` member: the shim throws on it, so a returned
`PowerInfo` always carries a genuine state.
-/

namespace Sdl

/-- Basic state of the system's power supply. C: `SDL_PowerState` (the -1
`SDL_POWERSTATE_ERROR` sentinel is surfaced as an `IO` error, not a member). -/
sdl_enum PowerState : UInt32 where
  | unknown   => 0  -- C: SDL_POWERSTATE_UNKNOWN
  | onBattery => 1  -- C: SDL_POWERSTATE_ON_BATTERY
  | noBattery => 2  -- C: SDL_POWERSTATE_NO_BATTERY
  | charging  => 3  -- C: SDL_POWERSTATE_CHARGING
  | charged   => 4  -- C: SDL_POWERSTATE_CHARGED

/-- Snapshot of the system power supply. C: results of `SDL_GetPowerInfo`. -/
structure PowerInfo where
  /-- The power state. -/
  state : PowerState
  /-- Seconds of battery life remaining, or `none` if unknown / no battery. -/
  seconds : Option Int32
  /-- Battery charge percentage [0-100], or `none` if unknown / no battery. -/
  percent : Option Int32
deriving Repr, Inhabited

/-- Maker called from C to hand a `PowerInfo` back to Lean. Negative
`seconds`/`percent` (SDL's -1 "unknown") map to `none`; an unknown raw state
maps to `.unknown`. -/
@[export lean_sdl_mk_power_info]
private def mkPowerInfo (state : UInt32) (seconds percent : Int32) : PowerInfo :=
  { state := PowerState.ofVal? state |>.getD .unknown
    seconds := if seconds < 0 then none else some seconds
    percent := if percent < 0 then none else some percent }

/-- Current power supply details. Throws on `SDL_POWERSTATE_ERROR`.
C: `SDL_GetPowerInfo`. -/
@[extern "lean_sdl_get_power_info"]
opaque getPowerInfo : IO PowerInfo

end Sdl
