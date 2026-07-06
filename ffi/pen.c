/* Shims for Sdl/Pen.lean (SDL_pen.h).
 *
 * The pen API is delivered almost entirely through events; the only query is
 * the device type. The error sentinel SDL_PEN_DEVICE_TYPE_INVALID is thrown on
 * before the Lean decode. */
#include "util.h"

/* Sdl.PenId.deviceTypeRaw (id : UInt32) : IO UInt32
 * -- C: SDL_GetPenDeviceType (INVALID -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_pen_device_type(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PenDeviceType t = SDL_GetPenDeviceType((SDL_PenID)id);
    if (t == SDL_PEN_DEVICE_TYPE_INVALID) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)t));
}
