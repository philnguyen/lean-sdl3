/* Shims for Sdl/Mouse.lean (SDL_mouse.h).
 *
 * Two external classes back the one Lean Cursor type:
 *   - lean_sdl_cursor          : owned SDL_Cursor* (SDL_CreateCursor /
 *     CreateColorCursor / CreateSystemCursor). FINALIZER-ONLY: no manual destroy
 *     is exposed. owner = NULL (cursors have no parent handle).
 *   - lean_sdl_cursor_borrowed : SDL_Cursor* owned by SDL (SDL_GetCursor /
 *     GetDefaultCursor); never destroyed from Lean, owner = NULL.
 *
 * Active-cursor retention: SDL keeps rendering the cursor most recently passed
 * to SDL_SetCursor, so its Lean external must not be finalized while SDL still
 * displays it. `lean_sdl_active_cursor` holds one extra reference to that
 * external. A successful setCursor inc's the new external into the slot and
 * dec's the previous occupant. The slot is only touched from shims (main
 * thread), so no locking is needed.
 *
 * State results ((MouseButtonFlags, x, y) tuples) are built by an @[export]ed
 * Lean maker. Optional-Window returns go through the shared window registry
 * (classes.h). Surface args (createColorCursor) are read from the holder,
 * working for the owned or borrowed surface class alike. */
#include "util.h"
#include "classes.h"
#include "callbacks.h"

/* Lean-owned maker (see Sdl/Mouse.lean). */
extern lean_object *lean_sdl_mk_mouse_state(uint32_t state, float x, float y);

/* Owned cursor: destroy on finalize (finalizer-only, no manual destroy). */
SDL_DEFINE_CLASS(lean_sdl_cursor, SDL_DestroyCursor((SDL_Cursor *)self))
/* Borrowed cursor (SDL_GetCursor / GetDefaultCursor): never destroyed. */
SDL_DEFINE_BORROWED_CLASS(lean_sdl_cursor_borrowed)

/* The one extra reference to the active cursor's external, or NULL. Only ever
 * touched from shims (main thread). */
static lean_object *lean_sdl_active_cursor = NULL;

/* Register both cursor classes. Called from Sdl/Mouse.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_mouse_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_cursor_class_init();
    lean_sdl_cursor_borrowed_class_init();
    return lean_sdl_unit_ok();
}

/* ==================== Mouse devices ==================== */

/* Sdl.hasMouse : IO Bool -- C: SDL_HasMouse. */
LEAN_EXPORT lean_obj_res lean_sdl_has_mouse(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_HasMouse()));
}

/* Sdl.getMiceRaw : IO (Array UInt32) -- C: SDL_GetMice (single allocation;
 * copy ids then SDL_free; NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_mice(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    SDL_MouseID *ids = SDL_GetMice(&count);
    if (!ids) return lean_sdl_throw();
    size_t n = count > 0 ? (size_t)count : 0;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++)
        lean_array_set_core(arr, i, lean_box_uint32((uint32_t)ids[i]));
    SDL_free(ids);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.MouseId.nameRaw (id : UInt32) : IO String
 * -- C: SDL_GetMouseNameForID (NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_mouse_name_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    const char *s = SDL_GetMouseNameForID((SDL_MouseID)id);
    if (!s) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_string(s));
}

/* Sdl.getMouseFocus : IO (Option Window)
 * -- C: SDL_GetMouseFocus (registry lookup; NULL/foreign -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_mouse_focus(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_window_option(SDL_GetMouseFocus()));
}

/* ==================== Mouse state ==================== */

/* Sdl.getMouseState : IO (MouseButtonFlags x Float32 x Float32)
 * -- C: SDL_GetMouseState (window-relative cached state). */
LEAN_EXPORT lean_obj_res lean_sdl_get_mouse_state(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    float x = 0.0f, y = 0.0f;
    SDL_MouseButtonFlags s = SDL_GetMouseState(&x, &y);
    return lean_io_result_mk_ok(lean_sdl_mk_mouse_state((uint32_t)s, x, y));
}

/* Sdl.getGlobalMouseState : IO (MouseButtonFlags x Float32 x Float32)
 * -- C: SDL_GetGlobalMouseState (desktop-relative async state). */
LEAN_EXPORT lean_obj_res lean_sdl_get_global_mouse_state(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    float x = 0.0f, y = 0.0f;
    SDL_MouseButtonFlags s = SDL_GetGlobalMouseState(&x, &y);
    return lean_io_result_mk_ok(lean_sdl_mk_mouse_state((uint32_t)s, x, y));
}

/* Sdl.getRelativeMouseState : IO (MouseButtonFlags x Float32 x Float32)
 * -- C: SDL_GetRelativeMouseState (accumulated relative motion). */
LEAN_EXPORT lean_obj_res lean_sdl_get_relative_mouse_state(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    float x = 0.0f, y = 0.0f;
    SDL_MouseButtonFlags s = SDL_GetRelativeMouseState(&x, &y);
    return lean_io_result_mk_ok(lean_sdl_mk_mouse_state((uint32_t)s, x, y));
}

/* Sdl.Window.warpMouse (x y : Float32) -- C: SDL_WarpMouseInWindow (void). */
LEAN_EXPORT lean_obj_res lean_sdl_warp_mouse_in_window(
        b_lean_obj_arg self, float x, float y, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_WarpMouseInWindow(win, x, y);
    return lean_sdl_unit_ok();
}

/* Sdl.warpMouseGlobal (x y : Float32) -- C: SDL_WarpMouseGlobal. */
LEAN_EXPORT lean_obj_res lean_sdl_warp_mouse_global(float x, float y, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_WarpMouseGlobal(x, y));
}

/* Sdl.captureMouse (enabled : Bool) -- C: SDL_CaptureMouse. */
LEAN_EXPORT lean_obj_res lean_sdl_capture_mouse(uint8_t enabled, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_CaptureMouse(enabled != 0));
}

/* Sdl.Window.setRelativeMouseMode (enabled : Bool)
 * -- C: SDL_SetWindowRelativeMouseMode. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_relative_mouse_mode(
        b_lean_obj_arg self, uint8_t enabled, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowRelativeMouseMode(win, enabled != 0));
}

/* Sdl.Window.relativeMouseMode : IO Bool -- C: SDL_GetWindowRelativeMouseMode. */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_relative_mouse_mode(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    return lean_io_result_mk_ok(lean_box(SDL_GetWindowRelativeMouseMode(win)));
}

/* ==================== Cursors ==================== */

/* Sdl.createCursor (data mask : @& ByteArray) (w h hotX hotY : Int32) : IO Cursor
 * -- C: SDL_CreateCursor. Validates the bitmap sizes to prevent OOB reads:
 * each of data/mask must hold at least ((w+7)/8)*h bytes; w,h must be > 0. */
LEAN_EXPORT lean_obj_res lean_sdl_create_cursor(
        b_lean_obj_arg data, b_lean_obj_arg mask,
        int32_t rw, int32_t rh, int32_t hot_x, int32_t hot_y, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    if (rw <= 0 || rh <= 0)
        return lean_sdl_throw_msg("SDL_CreateCursor: width and height must be positive");
    size_t need = (((size_t)rw + 7) / 8) * (size_t)rh;
    if (lean_sarray_size(data) < need || lean_sarray_size(mask) < need)
        return lean_sdl_throw_msg(
            "SDL_CreateCursor: data/mask ByteArray smaller than ((w+7)/8)*h");
    SDL_Cursor *c = SDL_CreateCursor(
        lean_sarray_cptr((lean_object *)data), lean_sarray_cptr((lean_object *)mask),
        (int)rw, (int)rh, (int)hot_x, (int)hot_y);
    if (!c) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_cursor_class, c, NULL));
}

/* Sdl.Surface.createColorCursor (surface : @& Surface) (hotX hotY : Int32)
 * : IO Cursor -- C: SDL_CreateColorCursor (SDL copies the pixels; owner NULL). */
LEAN_EXPORT lean_obj_res lean_sdl_create_color_cursor(
        b_lean_obj_arg surface, int32_t hot_x, int32_t hot_y, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surface);
    SDL_Cursor *c = SDL_CreateColorCursor(s, (int)hot_x, (int)hot_y);
    if (!c) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_cursor_class, c, NULL));
}

/* Sdl.createSystemCursorRaw (id : UInt32) : IO Cursor
 * -- C: SDL_CreateSystemCursor. */
LEAN_EXPORT lean_obj_res lean_sdl_create_system_cursor(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Cursor *c = SDL_CreateSystemCursor((SDL_SystemCursor)id);
    if (!c) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_cursor_class, c, NULL));
}

/* Sdl.setCursor (cursor : @& Cursor) -- C: SDL_SetCursor. On success retain the
 * new external in the active slot and release the previous occupant. */
LEAN_EXPORT lean_obj_res lean_sdl_set_cursor(b_lean_obj_arg cursor, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Cursor, c, cursor);
    if (!SDL_SetCursor(c)) return lean_sdl_throw();
    lean_inc(cursor);
    if (lean_sdl_active_cursor) lean_dec(lean_sdl_active_cursor);
    lean_sdl_active_cursor = (lean_object *)cursor;
    return lean_sdl_unit_ok();
}

/* Sdl.redrawCursor : IO Unit -- C: SDL_SetCursor(NULL) (force cursor redraw;
 * does not change the retained active cursor). */
LEAN_EXPORT lean_obj_res lean_sdl_redraw_cursor(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_SetCursor(NULL));
}

/* Sdl.getCursor : IO (Option Cursor) -- C: SDL_GetCursor (NULL -> none). When
 * the active cursor was set through the binding, return the same retained
 * external (identity-preserving; a fresh borrowed wrap would dangle once
 * setCursor's active slot releases the cursor). Otherwise (the default
 * cursor, alive for the video subsystem's lifetime) wrap borrowed. */
LEAN_EXPORT lean_obj_res lean_sdl_get_cursor(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Cursor *c = SDL_GetCursor();
    if (!c) return lean_io_result_mk_ok(lean_sdl_none());
    if (lean_sdl_active_cursor &&
            lean_sdl_holder_of(lean_sdl_active_cursor)->ptr == c) {
        lean_inc(lean_sdl_active_cursor);
        return lean_io_result_mk_ok(lean_sdl_some(lean_sdl_active_cursor));
    }
    return lean_io_result_mk_ok(
        lean_sdl_some(lean_sdl_wrap(lean_sdl_cursor_borrowed_class, c, NULL)));
}

/* Sdl.getDefaultCursor : IO Cursor -- C: SDL_GetDefaultCursor (borrowed wrap;
 * NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_default_cursor(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Cursor *c = SDL_GetDefaultCursor();
    if (!c) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_cursor_borrowed_class, c, NULL));
}

/* Sdl.showCursor : IO Unit -- C: SDL_ShowCursor. */
LEAN_EXPORT lean_obj_res lean_sdl_show_cursor(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_ShowCursor());
}

/* Sdl.hideCursor : IO Unit -- C: SDL_HideCursor. */
LEAN_EXPORT lean_obj_res lean_sdl_hide_cursor(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_HideCursor());
}

/* Sdl.cursorVisible : IO Bool -- C: SDL_CursorVisible. */
LEAN_EXPORT lean_obj_res lean_sdl_cursor_visible(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_CursorVisible()));
}

/* ==================== Relative mouse transform ====================
 * Locked slot (docs/DESIGN.md "Callbacks" #2): SDL keeps exactly one global
 * transform. Fires from SDL's mouse input processing, which may be a separate
 * realtime-priority thread. */

static sdl_cb_slot lean_sdl_mouse_transform_slot;

/* Registered closure: UInt64 -> Option Window -> UInt32 -> Float32 -> Float32
 * -> IO (Float32 x Float32) (timestamp, window, mouseIdVal, x, y -> x', y').
 * An exception leaves the delta unchanged. */
static void SDLCALL lean_sdl_mouse_transform_tramp(void *userdata, Uint64 timestamp,
        SDL_Window *window, SDL_MouseID mouseID, float *x, float *y) {
    (void)userdata;
    lean_sdl_ensure_thread();
    lean_object *fn = lean_sdl_slot_acquire(&lean_sdl_mouse_transform_slot);
    if (!fn) return; /* cleared mid-dispatch */
    lean_object *res = lean_apply_6(fn, lean_box_uint64(timestamp),
        lean_sdl_window_option(window), lean_box_uint32((uint32_t)mouseID),
        lean_box_float32(*x), lean_box_float32(*y), lean_box(0));
    if (lean_io_result_is_ok(res)) {
        lean_object *pair = lean_io_result_get_value(res);
        *x = lean_unbox_float32(lean_ctor_get(pair, 0));
        *y = lean_unbox_float32(lean_ctor_get(pair, 1));
    }
    lean_dec(res);
}

/* Sdl.setRelativeMouseTransformRaw -- C: SDL_SetRelativeMouseTransform */
LEAN_EXPORT lean_obj_res lean_sdl_set_relative_mouse_transform(
        lean_obj_arg fn, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_slot_set(&lean_sdl_mouse_transform_slot, fn);
    if (!SDL_SetRelativeMouseTransform(lean_sdl_mouse_transform_tramp, NULL)) {
        lean_sdl_slot_clear(&lean_sdl_mouse_transform_slot);
        return lean_sdl_throw();
    }
    return lean_sdl_unit_ok();
}

/* Sdl.clearRelativeMouseTransform -- C: SDL_SetRelativeMouseTransform(NULL).
 * SDL is unhooked first; a trampoline mid-flight holds its own closure ref. */
LEAN_EXPORT lean_obj_res lean_sdl_clear_relative_mouse_transform(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    if (!SDL_SetRelativeMouseTransform(NULL, NULL)) return lean_sdl_throw();
    lean_sdl_slot_clear(&lean_sdl_mouse_transform_slot);
    return lean_sdl_unit_ok();
}
