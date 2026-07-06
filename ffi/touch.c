/* Shims for Sdl/Touch.lean (SDL_touch.h).
 *
 * Touch-device queries with no owned handles. Uint64 id arrays are copied
 * element-by-element via lean_box_uint64 then SDL_free'd. SDL_GetTouchFingers
 * returns a NULL-terminated SDL_Finger** in a single allocation; each finger is
 * handed back through the @[export]ed Lean maker, then the single block is
 * SDL_free'd. The device-type error sentinel SDL_TOUCH_DEVICE_INVALID is thrown
 * on before the Lean decode. */
#include "util.h"

/* Lean-owned maker (see Sdl/Touch.lean). */
extern lean_object *lean_sdl_mk_finger(uint64_t id, float x, float y, float pressure);

/* Sdl.getTouchDevicesRaw : IO (Array UInt64) -- C: SDL_GetTouchDevices (single
 * allocation; copy ids then SDL_free; NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_touch_devices(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    SDL_TouchID *ids = SDL_GetTouchDevices(&count);
    if (!ids) return lean_sdl_throw();
    size_t n = count > 0 ? (size_t)count : 0;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++)
        lean_array_set_core(arr, i, lean_box_uint64((uint64_t)ids[i]));
    SDL_free(ids);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.TouchId.nameRaw (id : UInt64) : IO String
 * -- C: SDL_GetTouchDeviceName (NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_touch_device_name(uint64_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    const char *s = SDL_GetTouchDeviceName((SDL_TouchID)id);
    if (!s) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_string(s));
}

/* Sdl.TouchId.deviceTypeRaw (id : UInt64) : IO UInt32
 * -- C: SDL_GetTouchDeviceType (INVALID -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_touch_device_type(uint64_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_TouchDeviceType t = SDL_GetTouchDeviceType((SDL_TouchID)id);
    if (t == SDL_TOUCH_DEVICE_INVALID) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)t));
}

/* Sdl.TouchId.fingersRaw (id : UInt64) : IO (Array Finger)
 * -- C: SDL_GetTouchFingers (NULL-terminated single allocation; build each
 * finger via the maker, then SDL_free the block; NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_touch_fingers(uint64_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    SDL_Finger **fingers = SDL_GetTouchFingers((SDL_TouchID)id, &count);
    if (!fingers) return lean_sdl_throw();
    size_t n = count > 0 ? (size_t)count : 0;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++) {
        SDL_Finger *f = fingers[i];
        lean_array_set_core(arr, i,
            lean_sdl_mk_finger((uint64_t)f->id, f->x, f->y, f->pressure));
    }
    SDL_free(fingers);
    return lean_io_result_mk_ok(arr);
}
