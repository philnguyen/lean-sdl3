import Sdl.Core.Macros
import Sdl.Error
import Sdl.Properties
import Sdl.Events

/-!
# Sensors (`SDL_sensor.h`)

Access to gyros and accelerometers. `SDL_Init` must have been called with
`SDL_INIT_SENSOR` before opening sensors.

## Ownership

`Sensor` is an **owned root**: the finalizer runs `SDL_CloseSensor` and the
holder's `owner` is always `NULL`. `Sensor.close` is a *manual* destroy that
NULLs the handle, so later use is a clean IO error.

`getSensorFromID` does **not** transfer ownership of the joystick-manager's
internal handle; it re-opens the sensor (`SDL_OpenSensor` on the same id, which
bumps SDL's internal refcount) and wraps that fresh reference. The returned
handle owns its own reference; closing it does not invalidate other handles.
-/

namespace Sdl

-- `SensorId` (C: `SDL_SensorID`) is defined in `Sdl/Events.lean` because event
-- payloads carry it; this module extends its namespace with the id-level
-- queries.

/-- The kind of a sensor. Version-open: additional platform-dependent sensors
may exist, so a raw value outside the listed set decodes to `other`. The C
sentinel `SDL_SENSOR_INVALID (-1)` is **not** a member: functions returning it
throw an `IO` error instead. C: `SDL_SensorType`. -/
sdl_enum_open SensorType : UInt32 where
  | unknown => 0  -- C: SDL_SENSOR_UNKNOWN
  | accel   => 1  -- C: SDL_SENSOR_ACCEL
  | gyro    => 2  -- C: SDL_SENSOR_GYRO
  | accelL  => 3  -- C: SDL_SENSOR_ACCEL_L
  | gyroL   => 4  -- C: SDL_SENSOR_GYRO_L
  | accelR  => 5  -- C: SDL_SENSOR_ACCEL_R
  | gyroR   => 6  -- C: SDL_SENSOR_GYRO_R

/-- An opened sensor. C: `SDL_Sensor`. -/
sdl_opaque Sensor

@[extern "lean_sdl_sensor_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

/-- Standard gravity for accelerometer sensors, in SI m/s² (a device at rest
reads this away from the earth's center). C: `SDL_STANDARD_GRAVITY`. -/
def standardGravity : Float32 := 9.80665

/-! ## Enumeration and opening -/

@[extern "lean_sdl_get_sensors"]
private opaque getSensorsRaw : IO (Array UInt32)

/-- The currently-connected sensors. Throws on failure. C: `SDL_GetSensors`. -/
def getSensors : IO (Array SensorId) := do
  return (← getSensorsRaw).map (⟨·⟩)

@[extern "lean_sdl_open_sensor"]
private opaque openSensorRaw (id : UInt32) : IO Sensor

/-- Open a sensor for use. Throws if `id` is not valid. C: `SDL_OpenSensor`. -/
def openSensor (id : SensorId) : IO Sensor := openSensorRaw id.val

@[extern "lean_sdl_get_sensor_from_id"]
private opaque getSensorFromIDRaw (id : UInt32) : IO (Option Sensor)

/-- The opened sensor with instance id `id`, or `none` if it has not been
opened. The returned handle owns its own reference (SDL re-opens it internally),
so closing it does not invalidate other handles. C: `SDL_GetSensorFromID`. -/
def getSensorFromID (id : SensorId) : IO (Option Sensor) := getSensorFromIDRaw id.val

/-- Update the current state of every open sensor. Called automatically by the
event loop when sensor events are enabled. Must be called from the thread that
initialized the sensor subsystem. C: `SDL_UpdateSensors`. -/
@[extern "lean_sdl_update_sensors"]
opaque updateSensors : IO Unit

namespace SensorId

@[extern "lean_sdl_get_sensor_name_for_id"]
private opaque nameRaw (id : UInt32) : IO String

/-- The implementation-dependent name of a sensor. Throws if the id is not
valid. C: `SDL_GetSensorNameForID`. -/
def name (self : SensorId) : IO String := nameRaw self.val

@[extern "lean_sdl_get_sensor_type_for_id"]
private opaque getTypeRaw (id : UInt32) : IO UInt32

/-- The type of a sensor. Throws (`SDL_SENSOR_INVALID`) if the id is not valid.
C: `SDL_GetSensorTypeForID`. -/
def getType (self : SensorId) : IO SensorType := do
  return SensorType.ofVal (← getTypeRaw self.val)

@[extern "lean_sdl_get_sensor_non_portable_type_for_id"]
private opaque nonPortableTypeRaw (id : UInt32) : IO Int32

/-- The platform-dependent type of a sensor. Throws (`-1`) if the id is not
valid. C: `SDL_GetSensorNonPortableTypeForID`. -/
def nonPortableType (self : SensorId) : IO Int32 := nonPortableTypeRaw self.val

end SensorId

namespace Sensor

/-- Close a sensor previously opened with `openSensor`. The handle is invalid
afterwards, so later use is a clean IO error. C: `SDL_CloseSensor`. -/
@[extern "lean_sdl_close_sensor"]
opaque close (self : @& Sensor) : IO Unit

/-- The properties associated with the sensor. Borrowed: tied to the sensor's
lifetime, never destroyed from Lean. Throws on failure.
C: `SDL_GetSensorProperties`. -/
@[extern "lean_sdl_get_sensor_properties"]
opaque getProperties (self : @& Sensor) : IO Properties

@[extern "lean_sdl_get_sensor_name"]
private opaque nameRaw (self : @& Sensor) : IO String

/-- The implementation-dependent name of the sensor. Throws on failure.
C: `SDL_GetSensorName`. -/
def name (self : @& Sensor) : IO String := nameRaw self

@[extern "lean_sdl_get_sensor_type"]
private opaque getTypeRaw (self : @& Sensor) : IO UInt32

/-- The type of the sensor. Throws (`SDL_SENSOR_INVALID`) on failure.
C: `SDL_GetSensorType`. -/
def getType (self : @& Sensor) : IO SensorType := do
  return SensorType.ofVal (← getTypeRaw self)

@[extern "lean_sdl_get_sensor_non_portable_type"]
private opaque nonPortableTypeRaw (self : @& Sensor) : IO Int32

/-- The platform-dependent type of the sensor. Throws (`-1`) on failure.
C: `SDL_GetSensorNonPortableType`. -/
def nonPortableType (self : @& Sensor) : IO Int32 := nonPortableTypeRaw self

@[extern "lean_sdl_get_sensor_id"]
private opaque getIDRaw (self : @& Sensor) : IO UInt32

/-- The instance id of the sensor. Throws (`0`) on failure.
C: `SDL_GetSensorId`. -/
def getID (self : @& Sensor) : IO SensorId := do return ⟨← getIDRaw self⟩

/-- The current state of the sensor: `numValues` reading values, widened from
32-bit floats to `Float`. The number and meaning of values are sensor
dependent. Throws if `numValues < 0` or on an SDL error.
C: `SDL_GetSensorData`. -/
@[extern "lean_sdl_get_sensor_data"]
opaque getData (self : @& Sensor) (numValues : Int32) : IO FloatArray

end Sensor
end Sdl
