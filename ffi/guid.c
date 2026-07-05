/* Shims for Sdl/Guid.lean (SDL_guid.h).
 *
 * Both SDL GUID operations are pure functions of their input (no SDL state, no
 * errors), so these shims take no world argument and return the value directly
 * rather than an io_result. A Guid's `bytes` is always a 16-byte ByteArray;
 * foreign input is zero-padded/truncated to 16 bytes (pure code cannot throw). */
#include "util.h"
#include <string.h>

/* Sdl.guidToStringRaw (bytes : @& ByteArray) : String -- C: SDL_GUIDToString */
LEAN_EXPORT lean_object *lean_sdl_guid_to_string(b_lean_obj_arg bytes) {
    SDL_SHIM_PROLOGUE();
    SDL_GUID guid;
    SDL_zero(guid);
    size_t n = lean_sarray_size(bytes);
    size_t k = n < sizeof(guid.data) ? n : sizeof(guid.data);
    memcpy(guid.data, lean_sarray_cptr((lean_object *)bytes), k);
    char buf[33];
    SDL_GUIDToString(guid, buf, (int)sizeof(buf));
    return lean_mk_string(buf);
}

/* Sdl.stringToGuidRaw (s : @& String) : ByteArray -- C: SDL_StringToGUID */
LEAN_EXPORT lean_object *lean_sdl_string_to_guid(b_lean_obj_arg s) {
    SDL_SHIM_PROLOGUE();
    SDL_GUID guid = SDL_StringToGUID(lean_string_cstr(s));
    lean_object *arr = lean_alloc_sarray(1, sizeof(guid.data), sizeof(guid.data));
    memcpy(lean_sarray_cptr(arr), guid.data, sizeof(guid.data));
    return arr;
}
