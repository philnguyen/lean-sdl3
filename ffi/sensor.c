/* Shims for Sdl/Sensor.lean (SDL_sensor.h).
 *
 * One external class over the Lean `Sensor` type: an OWNED ROOT whose finalizer
 * runs SDL_CloseSensor and whose holder owner is always NULL. Sensor.close is a
 * manual destroy that NULLs the holder ptr, so later use is a clean IO error.
 *
 * SensorID is a plain Uint32 on the Lean side (sdl_id); its shims take the raw
 * id. SensorType crosses the boundary as its raw Uint32; the Lean wrapper
 * decodes it with the total SensorType.ofVal. The C sentinel SDL_SENSOR_INVALID
 * (-1) is caught here and turned into an IO error, so it never reaches ofVal.
 *
 * getSensorFromID does not own the manager's internal handle: it re-opens the
 * sensor (SDL_OpenSensor bumps SDL's internal refcount) and wraps that fresh
 * reference, so each handle the binding hands out is independently owned. */
#include "util.h"
#include "classes.h"

/* Owned root: finalizer closes the sensor. */
SDL_DEFINE_CLASS(lean_sdl_sensor, SDL_CloseSensor((SDL_Sensor *)self))

static lean_object *lean_sdl_wrap_sensor(SDL_Sensor *s) {
    return lean_sdl_wrap(lean_sdl_sensor_class, s, NULL);
}

/* Register the class. Called from Sdl/Sensor.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_sensor_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_sensor_class_init();
    return lean_sdl_unit_ok();
}

/* ==================== Enumeration and opening ==================== */

/* Sdl.getSensorsRaw : IO (Array UInt32) -- C: SDL_GetSensors (NULL -> throw;
 * SDL_free after copy). */
LEAN_EXPORT lean_obj_res lean_sdl_get_sensors(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    SDL_SensorID *ids = SDL_GetSensors(&count);
    if (!ids) return lean_sdl_throw();
    size_t n = count > 0 ? (size_t)count : 0;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++)
        lean_array_set_core(arr, i, lean_box_uint32((uint32_t)ids[i]));
    SDL_free(ids);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.openSensorRaw (id : UInt32) : IO Sensor -- C: SDL_OpenSensor (NULL ->
 * throw). */
LEAN_EXPORT lean_obj_res lean_sdl_open_sensor(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Sensor *s = SDL_OpenSensor((SDL_SensorID)id);
    if (!s) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap_sensor(s));
}

/* Sdl.getSensorFromIDRaw (id : UInt32) : IO (Option Sensor)
 * -- C: SDL_GetSensorFromID. NULL -> none; otherwise re-open (ref-bump) and wrap
 * that fresh, independently-owned reference. */
LEAN_EXPORT lean_obj_res lean_sdl_get_sensor_from_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Sensor *s = SDL_GetSensorFromID((SDL_SensorID)id);
    if (!s) return lean_io_result_mk_ok(lean_sdl_none());
    SDL_Sensor *s2 = SDL_OpenSensor(SDL_GetSensorID(s));
    if (!s2) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_some(lean_sdl_wrap_sensor(s2)));
}

/* Sdl.updateSensors : IO Unit -- C: SDL_UpdateSensors (void). */
LEAN_EXPORT lean_obj_res lean_sdl_update_sensors(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_UpdateSensors();
    return lean_sdl_unit_ok();
}

/* ==================== SensorID methods ==================== */

/* Sdl.SensorID.nameRaw (id : UInt32) : IO String
 * -- C: SDL_GetSensorNameForID (NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_sensor_name_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    const char *n = SDL_GetSensorNameForID((SDL_SensorID)id);
    if (!n) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_mk_string(n));
}

/* Sdl.SensorID.getTypeRaw (id : UInt32) : IO UInt32
 * -- C: SDL_GetSensorTypeForID (SDL_SENSOR_INVALID -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_sensor_type_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_SensorType t = SDL_GetSensorTypeForID((SDL_SensorID)id);
    if (t == SDL_SENSOR_INVALID) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)t));
}

/* Sdl.SensorID.nonPortableTypeRaw (id : UInt32) : IO Int32
 * -- C: SDL_GetSensorNonPortableTypeForID (-1 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_sensor_non_portable_type_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int v = SDL_GetSensorNonPortableTypeForID((SDL_SensorID)id);
    if (v == -1) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)v));
}

/* ==================== Sensor methods ==================== */

/* Sdl.Sensor.close : IO Unit -- C: SDL_CloseSensor (manual destroy; NULL the
 * ptr). */
LEAN_EXPORT lean_obj_res lean_sdl_close_sensor(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_CloseSensor((SDL_Sensor *)h->ptr);
    h->ptr = NULL;
    return lean_sdl_unit_ok();
}

/* Sdl.Sensor.getProperties : IO Properties -- C: SDL_GetSensorProperties.
 * Borrowed Properties whose lifetime is tied to the sensor (owner = inc'd
 * sensor external). */
LEAN_EXPORT lean_obj_res lean_sdl_get_sensor_properties(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Sensor, s, self);
    SDL_PropertiesID id = SDL_GetSensorProperties(s);
    if (id == 0) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_properties_borrowed(id, (lean_object *)self));
}

/* Sdl.Sensor.nameRaw : IO String -- C: SDL_GetSensorName (NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_sensor_name(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Sensor, s, self);
    const char *n = SDL_GetSensorName(s);
    if (!n) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_mk_string(n));
}

/* Sdl.Sensor.getTypeRaw : IO UInt32
 * -- C: SDL_GetSensorType (SDL_SENSOR_INVALID -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_sensor_type(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Sensor, s, self);
    SDL_SensorType t = SDL_GetSensorType(s);
    if (t == SDL_SENSOR_INVALID) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)t));
}

/* Sdl.Sensor.nonPortableTypeRaw : IO Int32
 * -- C: SDL_GetSensorNonPortableType (-1 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_sensor_non_portable_type(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Sensor, s, self);
    int v = SDL_GetSensorNonPortableType(s);
    if (v == -1) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)v));
}

/* Sdl.Sensor.getIDRaw : IO UInt32 -- C: SDL_GetSensorID (0 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_sensor_id(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Sensor, s, self);
    SDL_SensorID id = SDL_GetSensorID(s);
    if (id == 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)id));
}

/* Sdl.Sensor.getData (numValues : Int32) : IO FloatArray
 * -- C: SDL_GetSensorData into a temp float[numValues], widened to Lean
 * doubles. numValues < 0 -> throw before alloc. */
LEAN_EXPORT lean_obj_res lean_sdl_get_sensor_data(
        b_lean_obj_arg self, int32_t num_values, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Sensor, s, self);
    if (num_values < 0)
        return lean_sdl_throw_msg("SDL: getData numValues must be non-negative");
    size_t n = (size_t)num_values;
    float *buf = (float *)SDL_malloc(n ? n * sizeof(float) : 1);
    if (!buf) return lean_sdl_throw_msg("SDL: out of memory");
    if (!SDL_GetSensorData(s, buf, num_values)) { SDL_free(buf); return lean_sdl_throw(); }
    lean_object *arr = lean_alloc_sarray(sizeof(double), n, n);
    double *d = lean_float_array_cptr(arr);
    for (size_t i = 0; i < n; i++) d[i] = (double)buf[i];
    SDL_free(buf);
    return lean_io_result_mk_ok(arr);
}
