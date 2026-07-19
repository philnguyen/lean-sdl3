/* Shims for Sdl/Video.lean (SDL_video.h).
 *
 * Two external classes:
 *   - lean_sdl_window    : owned SDL_Window* (SDL_CreateWindow / popup /
 *     with-properties). FINALIZER-ONLY: no manual destroy is exposed (popup
 *     children and window surfaces make a manual destroy unsound). Top-level
 *     windows have owner = NULL; popup windows have owner = inc'd parent
 *     external (RC ordering keeps the parent alive until all its popups die,
 *     mirroring SDL destroying child popups with the parent). The class pointer
 *     global is extern-declared in classes.h and defined (non-static) here.
 *   - lean_sdl_glcontext : owned SDL_GLContext, owner = inc'd window external
 *     (deliberate, harmless over-retention). Manual GLContext.destroy is
 *     exposed (leaf type): NULLs the ptr on success; on failure the context
 *     still exists (SDL_GL_DestroyContext returned false), so it throws WITHOUT
 *     NULLing.
 *
 * Window registry: every window created through this binding stores its Lean
 * external as a non-owning "lean_sdl.window" pointer property on the window's
 * properties. SDL_Window* -> Window lookups (GetWindowFromID, GetWindowParent,
 * GetGrabbedWindow, GL_GetCurrentWindow, GetWindows) then return the SAME
 * handle. This is sound because the external and the SDL_Window are destroyed
 * together (finalizer-only) and SDL_DestroyWindow destroys the properties with
 * the window.
 *
 * Structure results (Rect, DisplayMode, Int32/Float32 pairs and quads) are
 * built by @[export]ed Lean makers, so C never lays out a Lean structure.
 * Rect params are flattened (a hasRect byte + 4 Int32) and rebuilt here;
 * updateSurfaceRects receives a packed ByteArray reinterpreted as SDL_Rect[]. */
#include "util.h"
#include "classes.h"
#include "callbacks.h"

/* updateSurfaceRects reinterprets a packed 4x Int32 (little-endian) ByteArray
 * as SDL_Rect[]; pin the ABI. */
_Static_assert(sizeof(SDL_Rect) == 16, "SDL_Rect packs to 16 bytes");

/* Lean-owned makers (see Sdl/Video.lean and Sdl/Surface.lean for mk_rect). */
extern lean_object *lean_sdl_mk_rect(int32_t x, int32_t y, int32_t w, int32_t h);
extern lean_object *lean_sdl_mk_display_mode(
    uint32_t display_id, uint32_t format, int32_t w, int32_t h,
    float pixel_density, float refresh_rate, int32_t num, int32_t den);
extern lean_object *lean_sdl_mk_int32_pair(int32_t a, int32_t b);
extern lean_object *lean_sdl_mk_float32_pair(float a, float b);
extern lean_object *lean_sdl_mk_int32_quad(int32_t a, int32_t b, int32_t c, int32_t d);

/* Owned window: destroy on finalize (finalizer-only, no manual destroy). */
SDL_DEFINE_CLASS(lean_sdl_window, SDL_DestroyWindow((SDL_Window *)self))
/* Owned GL context: destroy on finalize (manual destroy also exposed). */
SDL_DEFINE_CLASS(lean_sdl_glcontext, SDL_GL_DestroyContext((SDL_GLContext)self))

/* Register both classes. Called from Sdl/Video.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_video_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_window_class_init();
    lean_sdl_glcontext_class_init();
    return lean_sdl_unit_ok();
}

/* Build a DisplayMode from a (possibly const) SDL_DisplayMode* via the maker. */
static lean_object *lean_sdl_display_mode_obj(const SDL_DisplayMode *m) {
    return lean_sdl_mk_display_mode(
        (uint32_t)m->displayID, (uint32_t)m->format, m->w, m->h,
        m->pixel_density, m->refresh_rate,
        m->refresh_rate_numerator, m->refresh_rate_denominator);
}

/* Wrap a freshly-created owned SDL_Window* and register it for lookups. `owner`
 * is consumed (NULL for top-level, inc'd parent external for popups). The
 * external is mt-marked here (on the main thread, before it can be seen
 * elsewhere): the relative-mouse-transform trampoline incs it from SDL's mouse
 * input thread via lean_sdl_window_option, so its RC ops must be atomic. */
static lean_object *lean_sdl_wrap_window(SDL_Window *win, lean_object *owner) {
    lean_object *ext = lean_sdl_wrap(lean_sdl_window_class, win, owner);
    lean_mark_mt(ext);
    SDL_SetPointerProperty(SDL_GetWindowProperties(win), LEAN_SDL_WINDOW_PROP, ext);
    return ext;
}

/* Extract a required `@& Properties`: throw if the handle was destroyed. The
 * holder ptr encodes an SDL_PropertiesID (see ffi/properties.c). */
#define SDL_PROPS_ID_OR_THROW(id, obj)                                         \
    SDL_PropertiesID id;                                                       \
    do {                                                                       \
        sdl_holder *_h = lean_sdl_holder_of(obj);                             \
        if (!_h->ptr)                                                          \
            return lean_sdl_throw_msg("SDL: handle used after destroy/release"); \
        id = (SDL_PropertiesID)(uintptr_t)_h->ptr;                            \
    } while (0)

/* Extract an `@& Option Window` to an SDL_Window* (none -> NULL). Throws (via
 * `return`) if a `some` handle was destroyed. */
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

/* Extract an `@& Option Surface` to an SDL_Surface* (none -> NULL). */
#define SDL_OPT_SURFACE_OR_THROW(var, opt)                                     \
    SDL_Surface *var = NULL;                                                   \
    do {                                                                       \
        if (!lean_is_scalar(opt)) {                                            \
            sdl_holder *_h = lean_sdl_holder_of(lean_ctor_get(opt, 0));        \
            if (!_h->ptr)                                                      \
                return lean_sdl_throw_msg("SDL: handle used after destroy/release"); \
            var = (SDL_Surface *)_h->ptr;                                      \
        }                                                                      \
    } while (0)

/* Build an `SDL_Rect *` from flattened args: NULL when `has` is 0. */
#define SDL_RECT_ARG(name, has, rx, ry, rw, rh)                                \
    SDL_Rect name##_storage = { (int)(rx), (int)(ry), (int)(rw), (int)(rh) };  \
    const SDL_Rect *name = (has) ? &name##_storage : NULL

/* ==================== Video drivers and system theme ==================== */

/* Sdl.getNumVideoDrivers : IO Int32 -- C: SDL_GetNumVideoDrivers */
LEAN_EXPORT lean_obj_res lean_sdl_get_num_video_drivers(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetNumVideoDrivers()));
}

/* Sdl.getVideoDriver (index : Int32) : IO (Option String)
 * -- C: SDL_GetVideoDriver (NULL = out of range). */
LEAN_EXPORT lean_obj_res lean_sdl_get_video_driver(int32_t index, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_option_string(SDL_GetVideoDriver((int)index)));
}

/* Sdl.getCurrentVideoDriver : IO (Option String)
 * -- C: SDL_GetCurrentVideoDriver (NULL = video not initialized). */
LEAN_EXPORT lean_obj_res lean_sdl_get_current_video_driver(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_option_string(SDL_GetCurrentVideoDriver()));
}

/* Sdl.getSystemThemeRaw : IO UInt32 -- C: SDL_GetSystemTheme */
LEAN_EXPORT lean_obj_res lean_sdl_get_system_theme(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetSystemTheme()));
}

/* ==================== Displays ==================== */

/* Sdl.getDisplaysRaw : IO (Array UInt32) -- C: SDL_GetDisplays (single
 * allocation; copy ids then SDL_free; NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_displays(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    SDL_DisplayID *ids = SDL_GetDisplays(&count);
    if (!ids) return lean_sdl_throw();
    size_t n = count > 0 ? (size_t)count : 0;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++)
        lean_array_set_core(arr, i, lean_box_uint32((uint32_t)ids[i]));
    SDL_free(ids);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.getPrimaryDisplayRaw : IO UInt32 -- C: SDL_GetPrimaryDisplay (0 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_primary_display(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_DisplayID id = SDL_GetPrimaryDisplay();
    if (id == 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)id));
}

/* Sdl.getDisplayForPointRaw (x y : Int32) : IO UInt32
 * -- C: SDL_GetDisplayForPoint (0 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_display_for_point(
        int32_t x, int32_t y, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Point p = { (int)x, (int)y };
    SDL_DisplayID id = SDL_GetDisplayForPoint(&p);
    if (id == 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)id));
}

/* Sdl.getDisplayForRectRaw (x y w h : Int32) : IO UInt32
 * -- C: SDL_GetDisplayForRect (0 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_display_for_rect(
        int32_t x, int32_t y, int32_t rw, int32_t rh, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Rect r = { (int)x, (int)y, (int)rw, (int)rh };
    SDL_DisplayID id = SDL_GetDisplayForRect(&r);
    if (id == 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)id));
}

/* Sdl.DisplayId.getPropertiesRaw (id : UInt32) : IO Properties
 * -- C: SDL_GetDisplayProperties. Borrowed (SDL-global), owner NULL; 0 -> throw. */
LEAN_EXPORT lean_obj_res lean_sdl_get_display_properties(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PropertiesID pid = SDL_GetDisplayProperties((SDL_DisplayID)id);
    if (pid == 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap_properties_borrowed(pid, NULL));
}

/* Sdl.DisplayId.nameRaw (id : UInt32) : IO String
 * -- C: SDL_GetDisplayName (NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_display_name(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    const char *s = SDL_GetDisplayName((SDL_DisplayID)id);
    if (!s) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_string(s));
}

/* Sdl.DisplayId.boundsRaw (id : UInt32) : IO Rect
 * -- C: SDL_GetDisplayBounds (out-param; false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_display_bounds(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Rect r;
    if (!SDL_GetDisplayBounds((SDL_DisplayID)id, &r)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_rect(r.x, r.y, r.w, r.h));
}

/* Sdl.DisplayId.usableBoundsRaw (id : UInt32) : IO Rect
 * -- C: SDL_GetDisplayUsableBounds (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_display_usable_bounds(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Rect r;
    if (!SDL_GetDisplayUsableBounds((SDL_DisplayID)id, &r)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_rect(r.x, r.y, r.w, r.h));
}

/* Sdl.DisplayId.naturalOrientationRaw (id : UInt32) : IO UInt32
 * -- C: SDL_GetNaturalDisplayOrientation. */
LEAN_EXPORT lean_obj_res lean_sdl_get_natural_display_orientation(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_box_uint32((uint32_t)SDL_GetNaturalDisplayOrientation((SDL_DisplayID)id)));
}

/* Sdl.DisplayId.currentOrientationRaw (id : UInt32) : IO UInt32
 * -- C: SDL_GetCurrentDisplayOrientation. */
LEAN_EXPORT lean_obj_res lean_sdl_get_current_display_orientation(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_box_uint32((uint32_t)SDL_GetCurrentDisplayOrientation((SDL_DisplayID)id)));
}

/* Sdl.DisplayId.contentScaleRaw (id : UInt32) : IO Float32
 * -- C: SDL_GetDisplayContentScale (0.0 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_display_content_scale(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    float s = SDL_GetDisplayContentScale((SDL_DisplayID)id);
    if (s == 0.0f) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_float32(s));
}

/* Sdl.DisplayId.fullscreenModesRaw (id : UInt32) : IO (Array DisplayMode)
 * -- C: SDL_GetFullscreenDisplayModes (NULL-terminated single allocation;
 * build each via the maker, then SDL_free; NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_fullscreen_display_modes(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    SDL_DisplayMode **modes = SDL_GetFullscreenDisplayModes((SDL_DisplayID)id, &count);
    if (!modes) return lean_sdl_throw();
    size_t n = count > 0 ? (size_t)count : 0;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++)
        lean_array_set_core(arr, i, lean_sdl_display_mode_obj(modes[i]));
    SDL_free(modes);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.DisplayId.closestFullscreenModeRaw (id) (w h) (rate) (includeHiDensity)
 * : IO DisplayMode -- C: SDL_GetClosestFullscreenDisplayMode (out-param). */
LEAN_EXPORT lean_obj_res lean_sdl_get_closest_fullscreen_display_mode(
        uint32_t id, int32_t rw, int32_t rh, float refresh_rate,
        uint8_t include_high_density, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_DisplayMode m;
    if (!SDL_GetClosestFullscreenDisplayMode((SDL_DisplayID)id, (int)rw, (int)rh,
            refresh_rate, include_high_density != 0, &m))
        return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_display_mode_obj(&m));
}

/* Sdl.DisplayId.desktopModeRaw (id : UInt32) : IO DisplayMode
 * -- C: SDL_GetDesktopDisplayMode (const ptr; NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_desktop_display_mode(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    const SDL_DisplayMode *m = SDL_GetDesktopDisplayMode((SDL_DisplayID)id);
    if (!m) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_display_mode_obj(m));
}

/* Sdl.DisplayId.currentModeRaw (id : UInt32) : IO DisplayMode
 * -- C: SDL_GetCurrentDisplayMode (const ptr; NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_current_display_mode(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    const SDL_DisplayMode *m = SDL_GetCurrentDisplayMode((SDL_DisplayID)id);
    if (!m) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_display_mode_obj(m));
}

/* ==================== Window creation and identity ==================== */

/* Sdl.createWindowRaw (title) (w h) (flags : UInt64) : IO Window
 * -- C: SDL_CreateWindow. Top-level (owner NULL); registered. */
LEAN_EXPORT lean_obj_res lean_sdl_create_window(
        b_lean_obj_arg title, int32_t rw, int32_t rh, uint64_t flags, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Window *win = SDL_CreateWindow(lean_string_cstr(title), (int)rw, (int)rh,
                                       (SDL_WindowFlags)flags);
    if (!win) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap_window(win, NULL));
}

/* Sdl.createPopupWindowRaw (parent) (offsetX offsetY w h) (flags : UInt64)
 * : IO Window -- C: SDL_CreatePopupWindow. owner = inc'd parent external. */
LEAN_EXPORT lean_obj_res lean_sdl_create_popup_window(
        b_lean_obj_arg parent, int32_t ox, int32_t oy, int32_t rw, int32_t rh,
        uint64_t flags, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, p, parent);
    SDL_Window *win = SDL_CreatePopupWindow(p, (int)ox, (int)oy, (int)rw, (int)rh,
                                            (SDL_WindowFlags)flags);
    if (!win) return lean_sdl_throw();
    lean_inc(parent);
    return lean_io_result_mk_ok(lean_sdl_wrap_window(win, (lean_object *)parent));
}

/* Sdl.createWindowWithProperties (props : @& Properties) : IO Window
 * -- C: SDL_CreateWindowWithProperties. Top-level (owner NULL); registered. */
LEAN_EXPORT lean_obj_res lean_sdl_create_window_with_properties(
        b_lean_obj_arg props, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PROPS_ID_OR_THROW(pid, props);
    SDL_Window *win = SDL_CreateWindowWithProperties(pid);
    if (!win) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap_window(win, NULL));
}

/* Sdl.getWindowFromIdRaw (id : UInt32) : IO (Option Window)
 * -- C: SDL_GetWindowFromID (registry lookup; NULL/foreign -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_from_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_window_option(SDL_GetWindowFromID((SDL_WindowID)id)));
}

/* Sdl.getWindows : IO (Array Window) -- C: SDL_GetWindows (registry-lookup each;
 * skip foreign windows; free the SDL array). */
LEAN_EXPORT lean_obj_res lean_sdl_get_windows(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    SDL_Window **wins = SDL_GetWindows(&count);
    if (!wins) return lean_sdl_throw();
    size_t n = 0;
    for (int i = 0; i < count; i++) {
        if (SDL_GetPointerProperty(SDL_GetWindowProperties(wins[i]),
                                   LEAN_SDL_WINDOW_PROP, NULL))
            n++;
    }
    lean_object *arr = lean_alloc_array(n, n);
    size_t j = 0;
    for (int i = 0; i < count; i++) {
        lean_object *ext = (lean_object *)SDL_GetPointerProperty(
            SDL_GetWindowProperties(wins[i]), LEAN_SDL_WINDOW_PROP, NULL);
        if (ext) {
            lean_inc(ext);
            lean_array_set_core(arr, j++, ext);
        }
    }
    SDL_free(wins);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.getGrabbedWindow : IO (Option Window)
 * -- C: SDL_GetGrabbedWindow (registry lookup; NULL -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_grabbed_window(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_window_option(SDL_GetGrabbedWindow()));
}

/* Sdl.Window.idRaw : IO UInt32 -- C: SDL_GetWindowID (0 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_id(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_WindowID id = SDL_GetWindowID(win);
    if (id == 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)id));
}

/* Sdl.Window.parent : IO (Option Window)
 * -- C: SDL_GetWindowParent (registry; none for top-level/foreign). */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_parent(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    return lean_io_result_mk_ok(lean_sdl_window_option(SDL_GetWindowParent(win)));
}

/* Sdl.Window.getDisplayRaw : IO UInt32
 * -- C: SDL_GetDisplayForWindow (0 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_display_for_window(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_DisplayID id = SDL_GetDisplayForWindow(win);
    if (id == 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)id));
}

/* ==================== Window state ==================== */

/* Sdl.Window.pixelDensity : IO Float32
 * -- C: SDL_GetWindowPixelDensity (0.0 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_pixel_density(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    float d = SDL_GetWindowPixelDensity(win);
    if (d == 0.0f) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_float32(d));
}

/* Sdl.Window.displayScale : IO Float32
 * -- C: SDL_GetWindowDisplayScale (0.0 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_display_scale(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    float d = SDL_GetWindowDisplayScale(win);
    if (d == 0.0f) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_float32(d));
}

/* Sdl.Window.setFullscreenModeRaw (hasMode) (displayId format) (w h) (density
 * rate) (num den) -- C: SDL_SetWindowFullscreenMode. Rebuilds a zeroed
 * SDL_DisplayMode (internal = NULL); NULL when hasMode = 0. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_fullscreen_mode(
        b_lean_obj_arg self, uint8_t has_mode, uint32_t display_id, uint32_t format,
        int32_t rw, int32_t rh, float density, float rate, int32_t num, int32_t den,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    if (!has_mode) {
        SDL_BOOL_TO_IO(SDL_SetWindowFullscreenMode(win, NULL));
    }
    SDL_DisplayMode m;
    SDL_zero(m);
    m.displayID = (SDL_DisplayID)display_id;
    m.format = (SDL_PixelFormat)format;
    m.w = (int)rw;
    m.h = (int)rh;
    m.pixel_density = density;
    m.refresh_rate = rate;
    m.refresh_rate_numerator = (int)num;
    m.refresh_rate_denominator = (int)den;
    m.internal = NULL;
    SDL_BOOL_TO_IO(SDL_SetWindowFullscreenMode(win, &m));
}

/* Sdl.Window.getFullscreenMode : IO (Option DisplayMode)
 * -- C: SDL_GetWindowFullscreenMode (NULL -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_fullscreen_mode(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    const SDL_DisplayMode *m = SDL_GetWindowFullscreenMode(win);
    if (!m) return lean_io_result_mk_ok(lean_sdl_none());
    return lean_io_result_mk_ok(lean_sdl_some(lean_sdl_display_mode_obj(m)));
}

/* Sdl.Window.iccProfile : IO ByteArray -- C: SDL_GetWindowICCProfile
 * (copy the SDL-owned buffer into a fresh sarray, then SDL_free; NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_icc_profile(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    size_t size = 0;
    void *data = SDL_GetWindowICCProfile(win, &size);
    if (!data) return lean_sdl_throw();
    lean_object *arr = lean_alloc_sarray(1, size, size);
    if (size) SDL_memcpy(lean_sarray_cptr(arr), data, size);
    SDL_free(data);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.Window.pixelFormatRaw : IO UInt32
 * -- C: SDL_GetWindowPixelFormat (UNKNOWN -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_pixel_format(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_PixelFormat f = SDL_GetWindowPixelFormat(win);
    if (f == SDL_PIXELFORMAT_UNKNOWN) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)f));
}

/* Sdl.Window.getProperties : IO Properties -- C: SDL_GetWindowProperties.
 * Borrowed, owner = inc'd window; 0 -> throw. */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_properties(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_PropertiesID id = SDL_GetWindowProperties(win);
    if (id == 0) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_properties_borrowed(id, (lean_object *)self));
}

/* Sdl.Window.flagsRaw : IO UInt64 -- C: SDL_GetWindowFlags. */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_flags(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)SDL_GetWindowFlags(win)));
}

/* Sdl.Window.setTitle (title : @& String) -- C: SDL_SetWindowTitle. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_title(
        b_lean_obj_arg self, b_lean_obj_arg title, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowTitle(win, lean_string_cstr(title)));
}

/* Sdl.Window.getTitle : IO String -- C: SDL_GetWindowTitle (never NULL). */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_title(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    return lean_io_result_mk_ok(lean_sdl_mk_string(SDL_GetWindowTitle(win)));
}

/* Sdl.Window.setIcon (icon : @& Surface) -- C: SDL_SetWindowIcon.
 * Accepts owned or borrowed surface class alike (reads the holder only). */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_icon(
        b_lean_obj_arg self, b_lean_obj_arg icon, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_GET_OR_THROW(SDL_Surface, s, icon);
    SDL_BOOL_TO_IO(SDL_SetWindowIcon(win, s));
}

/* Sdl.Window.setPosition (x y : Int32) -- C: SDL_SetWindowPosition. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_position(
        b_lean_obj_arg self, int32_t x, int32_t y, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowPosition(win, (int)x, (int)y));
}

/* Sdl.Window.getPosition : IO (Int32 x Int32) -- C: SDL_GetWindowPosition. */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_position(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    int x = 0, y = 0;
    if (!SDL_GetWindowPosition(win, &x, &y)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_int32_pair((int32_t)x, (int32_t)y));
}

/* Sdl.Window.setSize (w h : Int32) -- C: SDL_SetWindowSize. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_size(
        b_lean_obj_arg self, int32_t rw, int32_t rh, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowSize(win, (int)rw, (int)rh));
}

/* Sdl.Window.getSize : IO (Int32 x Int32) -- C: SDL_GetWindowSize. */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_size(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    int rw = 0, rh = 0;
    if (!SDL_GetWindowSize(win, &rw, &rh)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_int32_pair((int32_t)rw, (int32_t)rh));
}

/* Sdl.Window.getSafeArea : IO Rect -- C: SDL_GetWindowSafeArea. */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_safe_area(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_Rect r;
    if (!SDL_GetWindowSafeArea(win, &r)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_rect(r.x, r.y, r.w, r.h));
}

/* Sdl.Window.setAspectRatio (minAspect maxAspect : Float32)
 * -- C: SDL_SetWindowAspectRatio. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_aspect_ratio(
        b_lean_obj_arg self, float min_a, float max_a, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowAspectRatio(win, min_a, max_a));
}

/* Sdl.Window.getAspectRatio : IO (Float32 x Float32)
 * -- C: SDL_GetWindowAspectRatio. */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_aspect_ratio(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    float mn = 0.0f, mx = 0.0f;
    if (!SDL_GetWindowAspectRatio(win, &mn, &mx)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_float32_pair(mn, mx));
}

/* Sdl.Window.getBordersSize : IO (Int32 x Int32 x Int32 x Int32)
 * -- C: SDL_GetWindowBordersSize (top,left,bottom,right; unsupported -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_borders_size(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    int top = 0, left = 0, bottom = 0, right = 0;
    if (!SDL_GetWindowBordersSize(win, &top, &left, &bottom, &right))
        return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_int32_quad(
        (int32_t)top, (int32_t)left, (int32_t)bottom, (int32_t)right));
}

/* Sdl.Window.getSizeInPixels : IO (Int32 x Int32)
 * -- C: SDL_GetWindowSizeInPixels. */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_size_in_pixels(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    int rw = 0, rh = 0;
    if (!SDL_GetWindowSizeInPixels(win, &rw, &rh)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_int32_pair((int32_t)rw, (int32_t)rh));
}

/* Sdl.Window.setMinimumSize (w h : Int32) -- C: SDL_SetWindowMinimumSize. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_minimum_size(
        b_lean_obj_arg self, int32_t rw, int32_t rh, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowMinimumSize(win, (int)rw, (int)rh));
}

/* Sdl.Window.getMinimumSize : IO (Int32 x Int32) -- C: SDL_GetWindowMinimumSize. */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_minimum_size(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    int rw = 0, rh = 0;
    if (!SDL_GetWindowMinimumSize(win, &rw, &rh)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_int32_pair((int32_t)rw, (int32_t)rh));
}

/* Sdl.Window.setMaximumSize (w h : Int32) -- C: SDL_SetWindowMaximumSize. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_maximum_size(
        b_lean_obj_arg self, int32_t rw, int32_t rh, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowMaximumSize(win, (int)rw, (int)rh));
}

/* Sdl.Window.getMaximumSize : IO (Int32 x Int32) -- C: SDL_GetWindowMaximumSize. */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_maximum_size(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    int rw = 0, rh = 0;
    if (!SDL_GetWindowMaximumSize(win, &rw, &rh)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_int32_pair((int32_t)rw, (int32_t)rh));
}

/* Sdl.Window.setBordered (bordered : Bool) -- C: SDL_SetWindowBordered. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_bordered(
        b_lean_obj_arg self, uint8_t bordered, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowBordered(win, bordered != 0));
}

/* Sdl.Window.setResizable (resizable : Bool) -- C: SDL_SetWindowResizable. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_resizable(
        b_lean_obj_arg self, uint8_t resizable, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowResizable(win, resizable != 0));
}

/* Sdl.Window.setAlwaysOnTop (onTop : Bool) -- C: SDL_SetWindowAlwaysOnTop. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_always_on_top(
        b_lean_obj_arg self, uint8_t on_top, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowAlwaysOnTop(win, on_top != 0));
}

/* Sdl.Window.setFillDocument (fill : Bool) -- C: SDL_SetWindowFillDocument
 * (Emscripten only; throws elsewhere). */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_fill_document(
        b_lean_obj_arg self, uint8_t fill, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowFillDocument(win, fill != 0));
}

/* Sdl.Window.show -- C: SDL_ShowWindow. */
LEAN_EXPORT lean_obj_res lean_sdl_show_window(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_ShowWindow(win));
}

/* Sdl.Window.hide -- C: SDL_HideWindow. */
LEAN_EXPORT lean_obj_res lean_sdl_hide_window(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_HideWindow(win));
}

/* Sdl.Window.raise -- C: SDL_RaiseWindow. */
LEAN_EXPORT lean_obj_res lean_sdl_raise_window(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_RaiseWindow(win));
}

/* Sdl.Window.maximize -- C: SDL_MaximizeWindow. */
LEAN_EXPORT lean_obj_res lean_sdl_maximize_window(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_MaximizeWindow(win));
}

/* Sdl.Window.minimize -- C: SDL_MinimizeWindow. */
LEAN_EXPORT lean_obj_res lean_sdl_minimize_window(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_MinimizeWindow(win));
}

/* Sdl.Window.restore -- C: SDL_RestoreWindow. */
LEAN_EXPORT lean_obj_res lean_sdl_restore_window(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_RestoreWindow(win));
}

/* Sdl.Window.setFullscreen (fullscreen : Bool) -- C: SDL_SetWindowFullscreen. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_fullscreen(
        b_lean_obj_arg self, uint8_t fullscreen, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowFullscreen(win, fullscreen != 0));
}

/* Sdl.Window.sync -- C: SDL_SyncWindow. */
LEAN_EXPORT lean_obj_res lean_sdl_sync_window(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SyncWindow(win));
}

/* ==================== Window surface ==================== */

/* Sdl.Window.hasSurface : IO Bool -- C: SDL_WindowHasSurface. */
LEAN_EXPORT lean_obj_res lean_sdl_window_has_surface(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    return lean_io_result_mk_ok(lean_box(SDL_WindowHasSurface(win)));
}

/* Sdl.Window.getSurface : IO Surface -- C: SDL_GetWindowSurface.
 * Borrowed wrap, owner = inc'd window; NULL -> throw. */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_surface(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_Surface *surf = SDL_GetWindowSurface(win);
    if (!surf) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_surface_borrowed(surf, (lean_object *)self));
}

/* Sdl.Window.setSurfaceVSync (vsync : Int32) -- C: SDL_SetWindowSurfaceVSync. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_surface_vsync(
        b_lean_obj_arg self, int32_t vsync, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowSurfaceVSync(win, (int)vsync));
}

/* Sdl.Window.getSurfaceVSync : IO Int32 -- C: SDL_GetWindowSurfaceVSync. */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_surface_vsync(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    int vsync = 0;
    if (!SDL_GetWindowSurfaceVSync(win, &vsync)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)(int32_t)vsync));
}

/* Sdl.Window.updateSurface -- C: SDL_UpdateWindowSurface. */
LEAN_EXPORT lean_obj_res lean_sdl_update_window_surface(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_UpdateWindowSurface(win));
}

/* Sdl.Window.updateSurfaceRectsRaw (rects : @& ByteArray)
 * -- C: SDL_UpdateWindowSurfaceRects. The ByteArray is 4x Int32 little-endian
 * per rect (asserted == SDL_Rect layout); numrects is size/16. */
LEAN_EXPORT lean_obj_res lean_sdl_update_window_surface_rects(
        b_lean_obj_arg self, b_lean_obj_arg rects, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    size_t n = lean_sarray_size(rects) / sizeof(SDL_Rect);
    SDL_BOOL_TO_IO(SDL_UpdateWindowSurfaceRects(
        win, (const SDL_Rect *)lean_sarray_cptr((lean_object *)rects), (int)n));
}

/* Sdl.Window.destroySurface -- C: SDL_DestroyWindowSurface (borrowed surfaces
 * previously fetched via getSurface dangle afterwards). */
LEAN_EXPORT lean_obj_res lean_sdl_destroy_window_surface(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_DestroyWindowSurface(win));
}

/* ==================== Grab, mouse confinement, appearance ==================== */

/* Sdl.Window.setKeyboardGrab (grabbed : Bool) -- C: SDL_SetWindowKeyboardGrab. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_keyboard_grab(
        b_lean_obj_arg self, uint8_t grabbed, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowKeyboardGrab(win, grabbed != 0));
}

/* Sdl.Window.getKeyboardGrab : IO Bool -- C: SDL_GetWindowKeyboardGrab. */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_keyboard_grab(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    return lean_io_result_mk_ok(lean_box(SDL_GetWindowKeyboardGrab(win)));
}

/* Sdl.Window.setMouseGrab (grabbed : Bool) -- C: SDL_SetWindowMouseGrab. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_mouse_grab(
        b_lean_obj_arg self, uint8_t grabbed, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowMouseGrab(win, grabbed != 0));
}

/* Sdl.Window.getMouseGrab : IO Bool -- C: SDL_GetWindowMouseGrab. */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_mouse_grab(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    return lean_io_result_mk_ok(lean_box(SDL_GetWindowMouseGrab(win)));
}

/* Sdl.Window.setMouseRectRaw (hasRect ...) -- C: SDL_SetWindowMouseRect
 * (none clears the confinement). */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_mouse_rect(
        b_lean_obj_arg self, uint8_t has_rect,
        int32_t x, int32_t y, int32_t rw, int32_t rh, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_RECT_ARG(rect, has_rect, x, y, rw, rh);
    SDL_BOOL_TO_IO(SDL_SetWindowMouseRect(win, rect));
}

/* Sdl.Window.getMouseRect : IO (Option Rect) -- C: SDL_GetWindowMouseRect
 * (NULL -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_mouse_rect(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    const SDL_Rect *r = SDL_GetWindowMouseRect(win);
    if (!r) return lean_io_result_mk_ok(lean_sdl_none());
    return lean_io_result_mk_ok(lean_sdl_some(lean_sdl_mk_rect(r->x, r->y, r->w, r->h)));
}

/* Sdl.Window.setOpacity (opacity : Float32) -- C: SDL_SetWindowOpacity. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_opacity(
        b_lean_obj_arg self, float opacity, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowOpacity(win, opacity));
}

/* Sdl.Window.getOpacity : IO Float32 -- C: SDL_GetWindowOpacity (< 0 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_opacity(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    float o = SDL_GetWindowOpacity(win);
    if (o < 0.0f) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_float32(o));
}

/* Sdl.Window.setParentRaw (parent : @& Option Window)
 * -- C: SDL_SetWindowParent (none -> NULL top-level). */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_parent(
        b_lean_obj_arg self, b_lean_obj_arg parent, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_OPT_WINDOW_OR_THROW(p, parent);
    SDL_BOOL_TO_IO(SDL_SetWindowParent(win, p));
}

/* Sdl.Window.setModal (modal : Bool) -- C: SDL_SetWindowModal. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_modal(
        b_lean_obj_arg self, uint8_t modal, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowModal(win, modal != 0));
}

/* Sdl.Window.setFocusable (focusable : Bool) -- C: SDL_SetWindowFocusable. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_focusable(
        b_lean_obj_arg self, uint8_t focusable, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowFocusable(win, focusable != 0));
}

/* Sdl.Window.showSystemMenu (x y : Int32) -- C: SDL_ShowWindowSystemMenu. */
LEAN_EXPORT lean_obj_res lean_sdl_show_window_system_menu(
        b_lean_obj_arg self, int32_t x, int32_t y, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_ShowWindowSystemMenu(win, (int)x, (int)y));
}

/* Sdl.Window.setShapeRaw (shape : @& Option Surface) -- C: SDL_SetWindowShape
 * (SDL copies the shape; none removes it; window needs SDL_WINDOW_TRANSPARENT). */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_shape(
        b_lean_obj_arg self, b_lean_obj_arg shape, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_OPT_SURFACE_OR_THROW(s, shape);
    SDL_BOOL_TO_IO(SDL_SetWindowShape(win, s));
}

/* Sdl.Window.flashRaw (operation : UInt32) -- C: SDL_FlashWindow. */
LEAN_EXPORT lean_obj_res lean_sdl_flash_window(
        b_lean_obj_arg self, uint32_t op, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_FlashWindow(win, (SDL_FlashOperation)op));
}

/* Sdl.Window.setProgressStateRaw (state : UInt32)
 * -- C: SDL_SetWindowProgressState. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_progress_state(
        b_lean_obj_arg self, uint32_t state, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowProgressState(win, (SDL_ProgressState)state));
}

/* Sdl.Window.getProgressStateRaw : IO UInt32
 * -- C: SDL_GetWindowProgressState (INVALID (-1) -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_progress_state(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_ProgressState st = SDL_GetWindowProgressState(win);
    if (st == SDL_PROGRESS_STATE_INVALID) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)st));
}

/* Sdl.Window.setProgressValue (value : Float32)
 * -- C: SDL_SetWindowProgressValue. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_progress_value(
        b_lean_obj_arg self, float value, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    SDL_BOOL_TO_IO(SDL_SetWindowProgressValue(win, value));
}

/* Sdl.Window.getProgressValue : IO Float32
 * -- C: SDL_GetWindowProgressValue (< 0 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_window_progress_value(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, self);
    float v = SDL_GetWindowProgressValue(win);
    if (v < 0.0f) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_float32(v));
}

/* ==================== Screensaver ==================== */

/* Sdl.screenSaverEnabled : IO Bool -- C: SDL_ScreenSaverEnabled. */
LEAN_EXPORT lean_obj_res lean_sdl_screen_saver_enabled(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_ScreenSaverEnabled()));
}

/* Sdl.enableScreenSaver -- C: SDL_EnableScreenSaver. */
LEAN_EXPORT lean_obj_res lean_sdl_enable_screen_saver(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_EnableScreenSaver());
}

/* Sdl.disableScreenSaver -- C: SDL_DisableScreenSaver. */
LEAN_EXPORT lean_obj_res lean_sdl_disable_screen_saver(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_DisableScreenSaver());
}

/* ==================== OpenGL ==================== */

/* Sdl.glLoadLibraryRaw (path : @& Option String)
 * -- C: SDL_GL_LoadLibrary (none -> NULL default library). */
LEAN_EXPORT lean_obj_res lean_sdl_gl_load_library(b_lean_obj_arg path, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    const char *p = NULL;
    if (!lean_is_scalar(path)) p = lean_string_cstr(lean_ctor_get(path, 0));
    SDL_BOOL_TO_IO(SDL_GL_LoadLibrary(p));
}

/* Sdl.glUnloadLibrary -- C: SDL_GL_UnloadLibrary (void). */
LEAN_EXPORT lean_obj_res lean_sdl_gl_unload_library(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GL_UnloadLibrary();
    return lean_sdl_unit_ok();
}

/* Sdl.glExtensionSupported (extension : @& String) : IO Bool
 * -- C: SDL_GL_ExtensionSupported. */
LEAN_EXPORT lean_obj_res lean_sdl_gl_extension_supported(
        b_lean_obj_arg ext, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_GL_ExtensionSupported(lean_string_cstr(ext))));
}

/* Sdl.glResetAttributes -- C: SDL_GL_ResetAttributes (void). */
LEAN_EXPORT lean_obj_res lean_sdl_gl_reset_attributes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GL_ResetAttributes();
    return lean_sdl_unit_ok();
}

/* Sdl.glSetAttributeRaw (attr : UInt32) (value : Int32)
 * -- C: SDL_GL_SetAttribute. */
LEAN_EXPORT lean_obj_res lean_sdl_gl_set_attribute(
        uint32_t attr, int32_t value, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_GL_SetAttribute((SDL_GLAttr)attr, (int)value));
}

/* Sdl.glGetAttributeRaw (attr : UInt32) : IO Int32
 * -- C: SDL_GL_GetAttribute. */
LEAN_EXPORT lean_obj_res lean_sdl_gl_get_attribute(uint32_t attr, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int value = 0;
    if (!SDL_GL_GetAttribute((SDL_GLAttr)attr, &value)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)(int32_t)value));
}

/* Sdl.glCreateContext (window : @& Window) : IO GLContext
 * -- C: SDL_GL_CreateContext. Owner = inc'd window external; NULL -> throw. */
LEAN_EXPORT lean_obj_res lean_sdl_gl_create_context(b_lean_obj_arg window, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, window);
    SDL_GLContext ctx = SDL_GL_CreateContext(win);
    if (!ctx) return lean_sdl_throw();
    lean_inc(window);
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_glcontext_class, (void *)ctx, (lean_object *)window));
}

/* Sdl.GLContext.destroy -- C: SDL_GL_DestroyContext (manual; leaf type).
 * On success NULL the ptr so the finalizer won't double-destroy; on failure the
 * context still exists, so throw WITHOUT NULLing. */
LEAN_EXPORT lean_obj_res lean_sdl_gl_destroy_context(b_lean_obj_arg context, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(context);
    if (!h->ptr)
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    if (!SDL_GL_DestroyContext((SDL_GLContext)h->ptr)) return lean_sdl_throw();
    h->ptr = NULL;
    return lean_sdl_unit_ok();
}

/* Sdl.glMakeCurrent (window : @& Window) (context : @& GLContext)
 * -- C: SDL_GL_MakeCurrent. */
LEAN_EXPORT lean_obj_res lean_sdl_gl_make_current(
        b_lean_obj_arg window, b_lean_obj_arg context, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, window);
    sdl_holder *ch = lean_sdl_holder_of(context);
    if (!ch->ptr)
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_BOOL_TO_IO(SDL_GL_MakeCurrent(win, (SDL_GLContext)ch->ptr));
}

/* Sdl.glGetCurrentWindow : IO (Option Window)
 * -- C: SDL_GL_GetCurrentWindow (registry; NULL -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_gl_get_current_window(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_window_option(SDL_GL_GetCurrentWindow()));
}

/* Sdl.glSetSwapInterval (interval : Int32) -- C: SDL_GL_SetSwapInterval. */
LEAN_EXPORT lean_obj_res lean_sdl_gl_set_swap_interval(int32_t interval, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_GL_SetSwapInterval((int)interval));
}

/* Sdl.glGetSwapInterval : IO Int32 -- C: SDL_GL_GetSwapInterval. */
LEAN_EXPORT lean_obj_res lean_sdl_gl_get_swap_interval(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int interval = 0;
    if (!SDL_GL_GetSwapInterval(&interval)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)(int32_t)interval));
}

/* Sdl.glSwapWindow (window : @& Window) -- C: SDL_GL_SwapWindow. */
LEAN_EXPORT lean_obj_res lean_sdl_gl_swap_window(b_lean_obj_arg window, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, window);
    SDL_BOOL_TO_IO(SDL_GL_SwapWindow(win));
}

/* ==================== Window hit test ====================
 * The Lean closure rides the window's own SDL properties with a lean_dec
 * cleanup (docs/DESIGN.md "Callbacks", property-stored variant): SDL then
 * guarantees exactly one release on replace, clear, or window destruction —
 * no registry entry can outlive the window. SDL_SetWindowHitTest and the hit
 * test itself both run on the main thread, so property read vs. replace
 * cannot race. */

#define LEAN_SDL_HITTEST_PROP "lean_sdl.hittest"

/* Stored closure: Window -> Int32 -> Int32 -> IO UInt32
 * (window, point x, point y, HitTestResult.val). The window is passed to the
 * closure by the trampoline so user code need not capture it (capturing it
 * would create a window -> properties -> closure -> window refcount cycle). */
static SDL_HitTestResult SDLCALL lean_sdl_hit_test_tramp(
        SDL_Window *win, const SDL_Point *area, void *data) {
    (void)data;
    lean_sdl_ensure_thread();
    lean_object *fn = (lean_object *)SDL_GetPointerProperty(
        SDL_GetWindowProperties(win), LEAN_SDL_HITTEST_PROP, NULL);
    if (!fn) return SDL_HITTEST_NORMAL;
    lean_object *win_opt = lean_sdl_window_option(win);
    if (lean_is_scalar(win_opt)) return SDL_HITTEST_NORMAL; /* foreign window */
    lean_object *win_ext = lean_ctor_get(win_opt, 0);
    lean_inc(win_ext);
    lean_dec(win_opt);
    lean_inc(fn);
    lean_object *res = lean_apply_4(fn, win_ext,
        lean_box_uint32((uint32_t)area->x), lean_box_uint32((uint32_t)area->y),
        lean_box(0));
    return (SDL_HitTestResult)lean_sdl_io_u32_or(res, (uint32_t)SDL_HITTEST_NORMAL);
}

/* Sdl.Window.setHitTestRaw -- C: SDL_SetWindowHitTest +
 * SDL_SetPointerPropertyWithCleanup. On property-set failure SDL has already
 * run the cleanup (dec'ing fn) — per SDL_properties.h — so no second dec. */
LEAN_EXPORT lean_obj_res lean_sdl_set_window_hit_test(
        b_lean_obj_arg window, lean_obj_arg fn, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(window);
    if (!h->ptr) {
        lean_dec(fn);
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    }
    SDL_Window *win = (SDL_Window *)h->ptr;
    lean_mark_mt(fn);
    SDL_PropertiesID props = SDL_GetWindowProperties(win);
    if (!SDL_SetPointerPropertyWithCleanup(props, LEAN_SDL_HITTEST_PROP,
                                           fn, lean_sdl_cleanup_dec, NULL))
        return lean_sdl_throw();
    if (!SDL_SetWindowHitTest(win, lean_sdl_hit_test_tramp, NULL)) {
        SDL_ClearProperty(props, LEAN_SDL_HITTEST_PROP); /* decs fn via cleanup */
        return lean_sdl_throw();
    }
    return lean_sdl_unit_ok();
}

/* Sdl.Window.clearHitTest -- C: SDL_SetWindowHitTest(win, NULL, NULL). */
LEAN_EXPORT lean_obj_res lean_sdl_clear_window_hit_test(
        b_lean_obj_arg window, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, window);
    if (!SDL_SetWindowHitTest(win, NULL, NULL)) return lean_sdl_throw();
    SDL_ClearProperty(SDL_GetWindowProperties(win), LEAN_SDL_HITTEST_PROP);
    return lean_sdl_unit_ok();
}
