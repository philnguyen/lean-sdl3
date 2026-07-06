/* Shims for Sdl/Clipboard.lean (SDL_clipboard.h).
 *
 * All functions are main-thread-only and require the video subsystem. No
 * external classes and no Lean-structure makers: every binding takes/returns
 * scalars, strings, a ByteArray, or an Array String, so C never lays out a
 * Lean structure.
 *
 * SDL-allocated results (GetClipboardText / GetPrimarySelectionText /
 * GetClipboardData / GetClipboardMimeTypes) are copied into fresh Lean objects
 * and then SDL_free'd. GetClipboardMimeTypes returns a NULL-terminated char**
 * in a SINGLE allocation: the individual strings are NOT separately freed. */
#include "util.h"

/* Sdl.setClipboardText (text : @& String) : IO Unit -- C: SDL_SetClipboardText. */
LEAN_EXPORT lean_obj_res lean_sdl_set_clipboard_text(b_lean_obj_arg text, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_SetClipboardText(lean_string_cstr(text)));
}

/* Sdl.getClipboardText : IO String -- C: SDL_GetClipboardText (SDL-malloc'd;
 * copy then SDL_free; "" on failure is indistinguishable from an empty
 * clipboard per the SDL contract; NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_clipboard_text(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    char *s = SDL_GetClipboardText();
    if (!s) return lean_sdl_throw();
    lean_object *str = lean_mk_string(s);
    SDL_free(s);
    return lean_io_result_mk_ok(str);
}

/* Sdl.hasClipboardText : IO Bool -- C: SDL_HasClipboardText. */
LEAN_EXPORT lean_obj_res lean_sdl_has_clipboard_text(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_HasClipboardText()));
}

/* Sdl.setPrimarySelectionText (text : @& String) : IO Unit
 * -- C: SDL_SetPrimarySelectionText. */
LEAN_EXPORT lean_obj_res lean_sdl_set_primary_selection_text(
        b_lean_obj_arg text, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_SetPrimarySelectionText(lean_string_cstr(text)));
}

/* Sdl.getPrimarySelectionText : IO String -- C: SDL_GetPrimarySelectionText
 * (same copy/free/contract as getClipboardText). */
LEAN_EXPORT lean_obj_res lean_sdl_get_primary_selection_text(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    char *s = SDL_GetPrimarySelectionText();
    if (!s) return lean_sdl_throw();
    lean_object *str = lean_mk_string(s);
    SDL_free(s);
    return lean_io_result_mk_ok(str);
}

/* Sdl.hasPrimarySelectionText : IO Bool -- C: SDL_HasPrimarySelectionText. */
LEAN_EXPORT lean_obj_res lean_sdl_has_primary_selection_text(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_HasPrimarySelectionText()));
}

/* Sdl.clearClipboardData : IO Unit -- C: SDL_ClearClipboardData. */
LEAN_EXPORT lean_obj_res lean_sdl_clear_clipboard_data(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_ClearClipboardData());
}

/* Sdl.getClipboardData (mimeType : @& String) : IO ByteArray
 * -- C: SDL_GetClipboardData (SDL-malloc'd; copy into a fresh sarray then
 * SDL_free; NULL, i.e. no data for that mime type, -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_clipboard_data(
        b_lean_obj_arg mime_type, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    size_t size = 0;
    void *data = SDL_GetClipboardData(lean_string_cstr(mime_type), &size);
    if (!data) return lean_sdl_throw();
    lean_object *arr = lean_alloc_sarray(1, size, size);
    if (size) SDL_memcpy(lean_sarray_cptr(arr), data, size);
    SDL_free(data);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.hasClipboardData (mimeType : @& String) : IO Bool
 * -- C: SDL_HasClipboardData. */
LEAN_EXPORT lean_obj_res lean_sdl_has_clipboard_data(
        b_lean_obj_arg mime_type, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_HasClipboardData(lean_string_cstr(mime_type))));
}

/* Sdl.getClipboardMimeTypes : IO (Array String)
 * -- C: SDL_GetClipboardMimeTypes (NULL-terminated char** in a SINGLE
 * allocation; copy each string into the Array via lean_sdl_string_array, then
 * SDL_free the array only -- NOT the individual strings; NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_clipboard_mime_types(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    size_t count = 0;
    char **types = SDL_GetClipboardMimeTypes(&count);
    if (!types) return lean_sdl_throw();
    lean_object *arr = lean_sdl_string_array((char const *const *)types);
    SDL_free(types);
    return lean_io_result_mk_ok(arr);
}
