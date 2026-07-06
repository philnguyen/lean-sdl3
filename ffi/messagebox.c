/* Shims for Sdl/MessageBox.lean (SDL_messagebox.h).
 *
 * No runtime tests: on macOS these open a real Cocoa dialog and block. The
 * Lean wrappers do all the packing; the raw externs receive flattened
 * scalars / ByteArrays so C never reads a Lean structure:
 *   - buttonMeta : @& ByteArray -- 8 bytes/button: uint32 flags LE, int32 id LE.
 *   - buttonTexts : @& Array String -- parallel text array (same order); the
 *     borrowed cstrs stay valid for the whole SDL_ShowMessageBox call.
 *   - scheme : @& ByteArray -- 15 bytes (5 colors x r,g,b) when hasScheme != 0.
 * Little-endian byte order is assumed for the packed metadata (all supported
 * targets; matches Video.updateSurfaceRects). The parent Window is a borrowed
 * `@& Option Window` extracted like video.c's SDL_OPT_WINDOW_OR_THROW /
 * pixels.c's SDL_OPT_PALETTE_OR_THROW (none -> NULL). */
#include "util.h"
#include <string.h>

/* Pin the packed color ABI: the Lean wrapper packs 3 bytes (r,g,b) per color. */
_Static_assert(sizeof(SDL_MessageBoxColor) == 3, "SDL_MessageBoxColor packs to 3 bytes");

/* Extract a borrowed `@& Option Window` to an SDL_Window* (none -> NULL).
 * Throws (via `return`) if a `some` handle was finalized. Modeled on video.c's
 * local SDL_OPT_WINDOW_OR_THROW (kept local: video.c does not export it). */
#define SDL_OPT_WINDOW_OR_THROW(var, opt)                                      \
    SDL_Window *var = NULL;                                                    \
    do {                                                                       \
        if (!lean_is_scalar(opt)) {                                            \
            sdl_holder *_h = lean_sdl_holder_of(lean_ctor_get(opt, 0));        \
            if (!_h->ptr)                                                      \
                return lean_sdl_throw_msg("SDL: handle used after destroy/release"); \
            var = (SDL_Window *)_h->ptr;                                       \
        }                                                                      \
    } while (0)

/* Sdl.showSimpleMessageBoxRaw (flags : UInt32) (title message : @& String)
 * (window : @& Option Window) : IO Unit -- C: SDL_ShowSimpleMessageBox. */
LEAN_EXPORT lean_obj_res lean_sdl_show_simple_message_box(
        uint32_t flags, b_lean_obj_arg title, b_lean_obj_arg message,
        b_lean_obj_arg window, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_OPT_WINDOW_OR_THROW(win, window);
    SDL_BOOL_TO_IO(SDL_ShowSimpleMessageBox((SDL_MessageBoxFlags)flags,
        lean_string_cstr(title), lean_string_cstr(message), win));
}

/* Sdl.showMessageBoxRaw (flags : UInt32) (title message : @& String)
 * (buttonMeta : @& ByteArray) (buttonTexts : @& Array String)
 * (hasScheme : UInt8) (scheme : @& ByteArray) (window : @& Option Window)
 * : IO Int32 -- C: SDL_ShowMessageBox.
 *
 * buttonMeta is 8 bytes/button (uint32 flags LE, then int32 id LE) read via
 * memcpy into local ints (LE target assumed, see file header). The button array
 * is SDL_calloc'd (count is user-controlled) and freed on every path. Returns
 * the pressed button's id; SDL sets -1 when the dialog is closed without a
 * press. An empty button array is passed through (SDL shows a default button). */
LEAN_EXPORT lean_obj_res lean_sdl_show_message_box(
        uint32_t flags, b_lean_obj_arg title, b_lean_obj_arg message,
        b_lean_obj_arg button_meta, b_lean_obj_arg button_texts,
        uint8_t has_scheme, b_lean_obj_arg scheme, b_lean_obj_arg window,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_OPT_WINDOW_OR_THROW(win, window);

    size_t n = lean_sarray_size(button_meta) / 8;
    const uint8_t *meta = (const uint8_t *)lean_sarray_cptr((lean_object *)button_meta);

    SDL_MessageBoxButtonData *btns = NULL;
    if (n > 0) {
        btns = (SDL_MessageBoxButtonData *)SDL_calloc(n, sizeof(SDL_MessageBoxButtonData));
        if (!btns)
            return lean_sdl_throw_msg("SDL: out of memory allocating message box buttons");
        for (size_t i = 0; i < n; i++) {
            uint32_t bflags;
            int32_t bid;
            memcpy(&bflags, meta + i * 8, 4);
            memcpy(&bid, meta + i * 8 + 4, 4);
            btns[i].flags = (SDL_MessageBoxButtonFlags)bflags;
            btns[i].buttonID = (int)bid;
            /* Borrowed cstr; valid for the whole call (button_texts outlives it). */
            btns[i].text = lean_string_cstr(lean_array_get_core((lean_object *)button_texts, i));
        }
    }

    SDL_MessageBoxColorScheme cs;
    if (has_scheme) {
        const uint8_t *sp = (const uint8_t *)lean_sarray_cptr((lean_object *)scheme);
        for (int i = 0; i < SDL_MESSAGEBOX_COLOR_COUNT; i++) {
            cs.colors[i].r = sp[i * 3 + 0];
            cs.colors[i].g = sp[i * 3 + 1];
            cs.colors[i].b = sp[i * 3 + 2];
        }
    }

    SDL_MessageBoxData data;
    SDL_zero(data);
    data.flags = (SDL_MessageBoxFlags)flags;
    data.window = win;
    data.title = lean_string_cstr(title);
    data.message = lean_string_cstr(message);
    data.numbuttons = (int)n;
    data.buttons = btns;
    data.colorScheme = has_scheme ? &cs : NULL;

    int buttonid = -1;
    bool ok = SDL_ShowMessageBox(&data, &buttonid);
    SDL_free(btns);
    if (!ok) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)(int32_t)buttonid));
}
