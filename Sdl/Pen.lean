import Sdl.Core.Macros
import Sdl.Error

/-!
# Pen (stylus) input state (`SDL_pen.h`)

Pressure-sensitive pen/stylus/eraser input. Pen input is delivered almost
entirely through the event system; the only query here is the device type.

Both enums are **version-open** (`sdl_enum_open`): the header notes new pen axes
and device types may be added in future SDL releases. The device-type sentinel
`SDL_PEN_DEVICE_TYPE_INVALID` (`-1`) is an error marker and is excluded from
`PenDeviceType`; `PenId.deviceType` throws when SDL returns it.
-/

namespace Sdl

/-- A pen instance id. `0` signifies an invalid/null device. Stable within a
single program run as long as SDL recognizes the same tool. C: `SDL_PenID`. -/
sdl_id PenId : UInt32

/-- Pen input flags, as reported in pen events' `penState` field.
C: `SDL_PenInputFlags`. -/
sdl_flags PenInputFlags : UInt32 where
  | down        := 0x1         -- C: SDL_PEN_INPUT_DOWN
  | button1     := 0x2         -- C: SDL_PEN_INPUT_BUTTON_1
  | button2     := 0x4         -- C: SDL_PEN_INPUT_BUTTON_2
  | button3     := 0x8         -- C: SDL_PEN_INPUT_BUTTON_3
  | button4     := 0x10        -- C: SDL_PEN_INPUT_BUTTON_4
  | button5     := 0x20        -- C: SDL_PEN_INPUT_BUTTON_5
  | eraserTip   := 0x40000000  -- C: SDL_PEN_INPUT_ERASER_TIP
  | inProximity := 0x80000000  -- C: SDL_PEN_INPUT_IN_PROXIMITY

/-- A pen axis index (the `axis` field of a pen axis event). Version-open: the
set of axes may grow in future SDL releases. C: `SDL_PenAxis`. -/
sdl_enum_open PenAxis : UInt32 where
  | pressure           => 0  -- C: SDL_PEN_AXIS_PRESSURE
  | xTilt              => 1  -- C: SDL_PEN_AXIS_XTILT
  | yTilt              => 2  -- C: SDL_PEN_AXIS_YTILT
  | distance           => 3  -- C: SDL_PEN_AXIS_DISTANCE
  | rotation           => 4  -- C: SDL_PEN_AXIS_ROTATION
  | slider             => 5  -- C: SDL_PEN_AXIS_SLIDER
  | tangentialPressure => 6  -- C: SDL_PEN_AXIS_TANGENTIAL_PRESSURE

/-- The type of a pen device. Version-open. The C sentinel
`SDL_PEN_DEVICE_TYPE_INVALID` (`-1`) is an error marker and is excluded here;
`PenId.deviceType` throws on it. C: `SDL_PenDeviceType`. -/
sdl_enum_open PenDeviceType : UInt32 where
  | unknown  => 0  -- C: SDL_PEN_DEVICE_TYPE_UNKNOWN
  | direct   => 1  -- C: SDL_PEN_DEVICE_TYPE_DIRECT
  | indirect => 2  -- C: SDL_PEN_DEVICE_TYPE_INDIRECT

namespace PenId

@[extern "lean_sdl_get_pen_device_type"]
private opaque deviceTypeRaw (id : UInt32) : IO UInt32

/-- The device type of the pen. Many platforms do not supply this, so
`PenDeviceType.unknown` is a common result. Throws on failure
(`SDL_PEN_DEVICE_TYPE_INVALID`). C: `SDL_GetPenDeviceType`. -/
def deviceType (self : PenId) : IO PenDeviceType := do
  return PenDeviceType.ofVal (← deviceTypeRaw self.val)

end PenId

end Sdl
