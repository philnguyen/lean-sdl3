/* Shims for Sdl/Keyboard.lean (SDL_keyboard.h).
 *
 * Keyboard-state queries with no owned handles of their own. A KeyboardState is
 * a copy-no-handle snapshot: SDL_GetKeyboardState hands back a pointer into an
 * internal array valid for the whole app lifetime, so the bytes are copied into
 * a fresh Lean sarray at the call site and wrapped via the @[export]ed maker.
 * Structure results (KeyboardState, Scancode x Keymod, Rect x Int32) are built
 * by Lean makers, so C never lays out a Lean structure. Optional-Window returns
 * go through the shared window registry (classes.h). Window / Properties args
 * are extracted from their holders. */
#include "util.h"
#include "classes.h"

/* SDL_GetKeyboardState returns `const bool *`; the snapshot copy assumes one
 * byte per element. */
_Static_assert(sizeof(bool) == 1, "bool size (keyboard state snapshot)");

/* Lean-owned makers (see Sdl/Keyboard.lean). */
extern lean_object *lean_sdl_mk_keyboard_state(lean_object *states);
extern lean_object *lean_sdl_mk_scancode_keymod(uint32_t sc, uint16_t mod);
extern lean_object *lean_sdl_mk_rect_cursor(
    int32_t x, int32_t y, int32_t w, int32_t h, int32_t cursor);

/* Extract a required `@& Properties`: throw if the handle was destroyed. The
 * holder ptr encodes an SDL_PropertiesID (see ffi/properties.c). Kept local:
 * video.c does not export its copy. */
#define SDL_PROPS_ID_OR_THROW(id, obj)                                         \
    SDL_PropertiesID id;                                                       \
    do {                                                                       \
        sdl_holder *_h = lean_sdl_holder_of(obj);                             \
        if (!_h->ptr)                                                          \
            return lean_sdl_throw_msg("SDL: handle used after destroy/release"); \
        id = (SDL_PropertiesID)(uintptr_t)_h->ptr;                            \
    } while (0)

/* ==================== Keyboard devices ==================== */

/* Sdl.hasKeyboard : IO Bool -- C: SDL_HasKeyboard. */
LEAN_EXPORT lean_obj_res lean_sdl_has_keyboard(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_HasKeyboard()));
}

/* Sdl.getKeyboardsRaw : IO (Array UInt32) -- C: SDL_GetKeyboards (single
 * allocation; copy ids then SDL_free; NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_keyboards(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    SDL_KeyboardID *ids = SDL_GetKeyboards(&count);
    if (!ids) return lean_sdl_throw();
    size_t n = count > 0 ? (size_t)count : 0;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++)
        lean_array_set_core(arr, i, lean_box_uint32((uint32_t)ids[i]));
    SDL_free(ids);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.KeyboardId.nameRaw (id : UInt32) : IO String
 * -- C: SDL_GetKeyboardNameForID (NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_keyboard_name_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    const char *s = SDL_GetKeyboardNameForID((SDL_KeyboardID)id);
    if (!s) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_string(s));
}

/* Sdl.getKeyboardFocus : IO (Option Window)
 * -- C: SDL_GetKeyboardFocus (registry lookup; NULL/foreign -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_keyboard_focus(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_window_option(SDL_GetKeyboardFocus()));
}

/* ==================== Keyboard state and modifiers ==================== */

/* Sdl.getKeyboardState : IO KeyboardState -- C: SDL_GetKeyboardState (copy
 * numkeys bytes from the internal `const bool*` into a fresh sarray). */
LEAN_EXPORT lean_obj_res lean_sdl_get_keyboard_state(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int numkeys = 0;
    const bool *state = SDL_GetKeyboardState(&numkeys);
    size_t n = numkeys > 0 ? (size_t)numkeys : 0;
    lean_object *bytes = lean_alloc_sarray(1, n, n);
    if (n && state) SDL_memcpy(lean_sarray_cptr(bytes), state, n);
    return lean_io_result_mk_ok(lean_sdl_mk_keyboard_state(bytes));
}

/* Sdl.resetKeyboard : IO Unit -- C: SDL_ResetKeyboard. */
LEAN_EXPORT lean_obj_res lean_sdl_reset_keyboard(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_ResetKeyboard();
    return lean_sdl_unit_ok();
}

/* Sdl.getModStateRaw : IO UInt32 -- C: SDL_GetModState. */
LEAN_EXPORT lean_obj_res lean_sdl_get_mod_state(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetModState()));
}

/* Sdl.setModStateRaw (mod : UInt16) : IO Unit -- C: SDL_SetModState. */
LEAN_EXPORT lean_obj_res lean_sdl_set_mod_state(uint16_t mod, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_SetModState((SDL_Keymod)mod);
    return lean_sdl_unit_ok();
}

/* ==================== Scancode/keycode/name mapping ==================== */

/* Sdl.getKeyFromScancodeRaw (scancode : UInt32) (mod : UInt16) (keyEvent : Bool)
 * : IO UInt32 -- C: SDL_GetKeyFromScancode. */
LEAN_EXPORT lean_obj_res lean_sdl_get_key_from_scancode(
        uint32_t scancode, uint16_t mod, uint8_t key_event, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Keycode k = SDL_GetKeyFromScancode(
        (SDL_Scancode)scancode, (SDL_Keymod)mod, key_event != 0);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)k));
}

/* Sdl.getScancodeFromKeyRaw (key : UInt32) : IO (Scancode x Keymod)
 * -- C: SDL_GetScancodeFromKey (out-param mod; pair via the maker). */
LEAN_EXPORT lean_obj_res lean_sdl_get_scancode_from_key(uint32_t key, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Keymod mod = SDL_KMOD_NONE;
    SDL_Scancode sc = SDL_GetScancodeFromKey((SDL_Keycode)key, &mod);
    return lean_io_result_mk_ok(
        lean_sdl_mk_scancode_keymod((uint32_t)sc, (uint16_t)mod));
}

/* Sdl.Scancode.nameRaw (scancode : UInt32) : IO String
 * -- C: SDL_GetScancodeName (never NULL; "" if no name). */
LEAN_EXPORT lean_obj_res lean_sdl_get_scancode_name(uint32_t scancode, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_sdl_mk_string(SDL_GetScancodeName((SDL_Scancode)scancode)));
}

/* Sdl.getScancodeFromNameRaw (name : @& String) : IO UInt32
 * -- C: SDL_GetScancodeFromName (UNKNOWN on failure; never throws). */
LEAN_EXPORT lean_obj_res lean_sdl_get_scancode_from_name(
        b_lean_obj_arg name, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_box_uint32((uint32_t)SDL_GetScancodeFromName(lean_string_cstr(name))));
}

/* Sdl.Keycode.nameRaw (key : UInt32) : IO String
 * -- C: SDL_GetKeyName (never NULL; "" if no name). */
LEAN_EXPORT lean_obj_res lean_sdl_get_key_name(uint32_t key, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_mk_string(SDL_GetKeyName((SDL_Keycode)key)));
}

/* Sdl.getKeyFromNameRaw (name : @& String) : IO UInt32
 * -- C: SDL_GetKeyFromName (UNKNOWN on failure; never throws). */
LEAN_EXPORT lean_obj_res lean_sdl_get_key_from_name(b_lean_obj_arg name, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_box_uint32((uint32_t)SDL_GetKeyFromName(lean_string_cstr(name))));
}

/* ==================== Text input (IME) ==================== */

/* Sdl.Window.startTextInput -- C: SDL_StartTextInput. */
LEAN_EXPORT lean_obj_res lean_sdl_start_text_input(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_StartTextInput(win));
}

/* Sdl.Window.startTextInputWithProperties (props : @& Properties)
 * -- C: SDL_StartTextInputWithProperties. */
LEAN_EXPORT lean_obj_res lean_sdl_start_text_input_with_properties(
        b_lean_obj_arg self, b_lean_obj_arg props, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_PROPS_ID_OR_THROW(pid, props);
    SDL_BOOL_TO_IO(SDL_StartTextInputWithProperties(win, pid));
}

/* Sdl.Window.textInputActive : IO Bool -- C: SDL_TextInputActive. */
LEAN_EXPORT lean_obj_res lean_sdl_text_input_active(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    return lean_io_result_mk_ok(lean_box(SDL_TextInputActive(win)));
}

/* Sdl.Window.stopTextInput -- C: SDL_StopTextInput. */
LEAN_EXPORT lean_obj_res lean_sdl_stop_text_input(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_StopTextInput(win));
}

/* Sdl.Window.clearComposition -- C: SDL_ClearComposition. */
LEAN_EXPORT lean_obj_res lean_sdl_clear_composition(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_ClearComposition(win));
}

/* Sdl.Window.setTextInputAreaRaw (hasRect) (x y w h) (cursor)
 * -- C: SDL_SetTextInputArea (NULL rect when hasRect = 0). */
LEAN_EXPORT lean_obj_res lean_sdl_set_text_input_area(
        b_lean_obj_arg self, uint8_t has_rect,
        int32_t x, int32_t y, int32_t rw, int32_t rh, int32_t cursor,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_Rect r = { (int)x, (int)y, (int)rw, (int)rh };
    const SDL_Rect *rp = has_rect ? &r : NULL;
    SDL_BOOL_TO_IO(SDL_SetTextInputArea(win, rp, (int)cursor));
}

/* Sdl.Window.getTextInputArea : IO (Rect x Int32)
 * -- C: SDL_GetTextInputArea (out-params; false -> throw; pair via the maker). */
LEAN_EXPORT lean_obj_res lean_sdl_get_text_input_area(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_Rect r;
    SDL_zero(r);
    int cursor = 0;
    if (!SDL_GetTextInputArea(win, &r, &cursor)) return lean_sdl_throw();
    return lean_io_result_mk_ok(
        lean_sdl_mk_rect_cursor(r.x, r.y, r.w, r.h, (int32_t)cursor));
}

/* ==================== Screen keyboard ==================== */

/* Sdl.hasScreenKeyboardSupport : IO Bool -- C: SDL_HasScreenKeyboardSupport. */
LEAN_EXPORT lean_obj_res lean_sdl_has_screen_keyboard_support(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_HasScreenKeyboardSupport()));
}

/* Sdl.Window.screenKeyboardShown : IO Bool -- C: SDL_ScreenKeyboardShown. */
LEAN_EXPORT lean_obj_res lean_sdl_screen_keyboard_shown(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    return lean_io_result_mk_ok(lean_box(SDL_ScreenKeyboardShown(win)));
}
