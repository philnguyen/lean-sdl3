/* Shims for Sdl/Render.lean (SDL_render.h).
 *
 * Two external classes:
 *   - lean_sdl_renderer : owned SDL_Renderer* (SDL_CreateRenderer /
 *     SDL_CreateSoftwareRenderer), owner = inc'd creating Window external (or
 *     Surface external for the software renderer). FINALIZER-ONLY: no manual
 *     destroy (SDL_DestroyRenderer frees the renderer's textures, so a manual
 *     destroy would dangle live Texture handles). RC ordering — every texture
 *     holds an owned ref to its renderer — keeps the renderer alive until all
 *     its textures are gone. The class pointer global is extern-declared in
 *     classes.h and defined (non-static) here.
 *   - lean_sdl_texture : owned SDL_Texture*, owner = inc'd renderer external.
 *     Manual Texture.destroy is exposed (leaf type): destroys, NULLs the ptr,
 *     and releases the owner. Every shim starts with SDL_GET_OR_THROW so
 *     post-destroy use throws.
 *
 * Registry: every renderer/texture created through this binding stores its
 * Lean external as a non-owning "lean_sdl.renderer"/"lean_sdl.texture" pointer
 * property on the object's own SDL properties. SDL_Renderer* -> Renderer
 * (GetRenderer) and SDL_Texture* -> Texture (GetRenderTarget) lookups then
 * return the SAME handle. Sound because the external and the SDL object die
 * together (renderer: finalizer-only; texture: the property dies inside
 * SDL_DestroyTexture whether via finalizer or manual destroy, and the guard
 * rejects post-destroy use). SDL_GetRendererFromTexture instead reads the
 * holder's owner directly (it IS the renderer external).
 *
 * Structure results (Rect, FRect, scalar pairs/triples/quads) are built by
 * @[export]ed Lean makers with render-specific export names (the plain
 * lean_sdl_mk_* names are claimed by other modules and export names are
 * process-global). Rect/FRect/FPoint params arrive flattened (a `has` byte +
 * fields) and are rebuilt here; the array draws (points/lines/rects/fillRects/
 * geometry) receive packed little-endian ByteArrays reinterpreted as
 * SDL_FPoint[] / SDL_FRect[] / SDL_Vertex[] / int[]. */
#include "util.h"
#include "classes.h"

/* The packed-ByteArray draws reinterpret little-endian float32/int32 buffers
 * as SDL struct arrays; pin the ABI (field offsets are pinned in
 * ffi/consts_check.c). */
_Static_assert(sizeof(SDL_FPoint) == 8, "SDL_FPoint packs to 8 bytes");
_Static_assert(sizeof(SDL_FRect) == 16, "SDL_FRect packs to 16 bytes");
_Static_assert(sizeof(SDL_Vertex) == 32, "SDL_Vertex packs to 32 bytes");
_Static_assert(sizeof(int) == 4, "geometry indices pack to 4 bytes");

/* Lean-owned makers (see Sdl/Render.lean). */
extern lean_object *lean_sdl_render_mk_int32_pair(int32_t a, int32_t b);
extern lean_object *lean_sdl_render_mk_uint32_pair(uint32_t a, uint32_t b);
extern lean_object *lean_sdl_render_mk_float32_pair(float a, float b);
extern lean_object *lean_sdl_render_mk_uint8_triple(uint8_t a, uint8_t b, uint8_t c);
extern lean_object *lean_sdl_render_mk_uint8_quad(
    uint8_t a, uint8_t b, uint8_t c, uint8_t d);
extern lean_object *lean_sdl_render_mk_float32_triple(float a, float b, float c);
extern lean_object *lean_sdl_render_mk_float32_quad(float a, float b, float c, float d);
extern lean_object *lean_sdl_render_mk_rect(int32_t x, int32_t y, int32_t w, int32_t h);
extern lean_object *lean_sdl_render_mk_frect(float x, float y, float w, float h);
extern lean_object *lean_sdl_render_mk_logical(int32_t w, int32_t h, uint32_t mode);

/* Owned renderer: destroy on finalize (finalizer-only, no manual destroy). */
SDL_DEFINE_CLASS(lean_sdl_renderer, SDL_DestroyRenderer((SDL_Renderer *)self))
/* Owned texture: destroy on finalize (manual Texture.destroy also exposed). */
SDL_DEFINE_CLASS(lean_sdl_texture, SDL_DestroyTexture((SDL_Texture *)self))

/* Register both classes. Called from Sdl/Render.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_render_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_renderer_class_init();
    lean_sdl_texture_class_init();
    return lean_sdl_unit_ok();
}

/* Wrap a freshly-created owned SDL_Renderer* and register it for lookups.
 * `owner` is consumed (an inc'd window or surface external). */
static lean_object *lean_sdl_wrap_renderer(SDL_Renderer *r, lean_object *owner) {
    lean_object *ext = lean_sdl_wrap(lean_sdl_renderer_class, r, owner);
    SDL_SetPointerProperty(SDL_GetRendererProperties(r), LEAN_SDL_RENDERER_PROP, ext);
    return ext;
}

/* Wrap a freshly-created owned SDL_Texture* and register it for lookups.
 * `owner` is consumed (an inc'd renderer external). */
static lean_object *lean_sdl_wrap_texture(SDL_Texture *t, lean_object *owner) {
    lean_object *ext = lean_sdl_wrap(lean_sdl_texture_class, t, owner);
    SDL_SetPointerProperty(SDL_GetTextureProperties(t), LEAN_SDL_TEXTURE_PROP, ext);
    return ext;
}

/* Borrowed `Option String` -> C string or NULL (duplicated from ffi/dialog.c,
 * where it is a static). */
static const char *lean_sdl_option_cstr(b_lean_obj_arg opt) {
    if (lean_is_scalar(opt)) return NULL;
    return lean_string_cstr(lean_ctor_get(opt, 0));
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

/* Extract an `@& Option Texture` to an SDL_Texture* (none -> NULL). Throws
 * (via `return`) if a `some` handle was destroyed. */
#define SDL_OPT_TEXTURE_OR_THROW(var, opt)                                      \
    SDL_Texture *var = NULL;                                                    \
    do {                                                                        \
        if (!lean_is_scalar(opt)) {                                             \
            sdl_holder *_h = lean_sdl_holder_of(lean_ctor_get(opt, 0));         \
            if (!_h->ptr)                                                       \
                return lean_sdl_throw_msg("SDL: handle used after destroy/release"); \
            var = (SDL_Texture *)_h->ptr;                                       \
        }                                                                       \
    } while (0)

/* Build an `SDL_Rect *` from flattened args: NULL when `has` is 0. */
#define SDL_RECT_ARG(name, has, rx, ry, rw, rh)                                \
    SDL_Rect name##_storage = { (int)(rx), (int)(ry), (int)(rw), (int)(rh) };  \
    const SDL_Rect *name = (has) ? &name##_storage : NULL

/* Build an `SDL_FRect *` from flattened args: NULL when `has` is 0. */
#define SDL_FRECT_ARG(name, has, rx, ry, rw, rh)                               \
    SDL_FRect name##_storage = { (rx), (ry), (rw), (rh) };                     \
    const SDL_FRect *name = (has) ? &name##_storage : NULL

/* Build an `SDL_FPoint *` from flattened args: NULL when `has` is 0. */
#define SDL_FPOINT_ARG(name, has, px, py)                                      \
    SDL_FPoint name##_storage = { (px), (py) };                                \
    const SDL_FPoint *name = (has) ? &name##_storage : NULL

/* ==================== Render drivers ==================== */

/* Sdl.getNumRenderDrivers : IO Int32 -- C: SDL_GetNumRenderDrivers */
LEAN_EXPORT lean_obj_res lean_sdl_get_num_render_drivers(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetNumRenderDrivers()));
}

/* Sdl.getRenderDriver (index : Int32) : IO (Option String)
 * -- C: SDL_GetRenderDriver (NULL = out of range). */
LEAN_EXPORT lean_obj_res lean_sdl_get_render_driver(int32_t index, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_option_string(SDL_GetRenderDriver((int)index)));
}

/* ==================== Renderer creation and lookup ==================== */

/* Sdl.createRendererRaw (window) (name : @& Option String) : IO Renderer
 * -- C: SDL_CreateRenderer. Owner = inc'd window external; registered. */
LEAN_EXPORT lean_obj_res lean_sdl_create_renderer(
        b_lean_obj_arg window, b_lean_obj_arg name_opt, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, window);
    SDL_Renderer *r = SDL_CreateRenderer(win, lean_sdl_option_cstr(name_opt));
    if (!r) return lean_sdl_throw();
    lean_inc(window);
    return lean_io_result_mk_ok(lean_sdl_wrap_renderer(r, (lean_object *)window));
}

/* Sdl.createSoftwareRenderer (surface : @& Surface) : IO Renderer
 * -- C: SDL_CreateSoftwareRenderer. Owner = inc'd surface external; registered. */
LEAN_EXPORT lean_obj_res lean_sdl_create_software_renderer(
        b_lean_obj_arg surface, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surface);
    SDL_Renderer *r = SDL_CreateSoftwareRenderer(s);
    if (!r) return lean_sdl_throw();
    lean_inc(surface);
    return lean_io_result_mk_ok(lean_sdl_wrap_renderer(r, (lean_object *)surface));
}

/* Sdl.getRenderer (window : @& Window) : IO (Option Renderer)
 * -- C: SDL_GetRenderer (registry lookup; NULL/foreign -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_renderer(b_lean_obj_arg window, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Window, win, window);
    return lean_io_result_mk_ok(lean_sdl_renderer_option(SDL_GetRenderer(win)));
}

/* ==================== Renderer queries ==================== */

/* Sdl.Renderer.getWindow : IO (Option Window)
 * -- C: SDL_GetRenderWindow (registry lookup; NULL/foreign -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_render_window(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    return lean_io_result_mk_ok(lean_sdl_window_option(SDL_GetRenderWindow(r)));
}

/* Sdl.Renderer.name : IO String -- C: SDL_GetRendererName (NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_renderer_name(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    const char *s = SDL_GetRendererName(r);
    if (!s) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_string(s));
}

/* Sdl.Renderer.properties : IO Properties -- C: SDL_GetRendererProperties.
 * Borrowed, owner = inc'd renderer; 0 -> throw. */
LEAN_EXPORT lean_obj_res lean_sdl_get_renderer_properties(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_PropertiesID id = SDL_GetRendererProperties(r);
    if (id == 0) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_properties_borrowed(id, (lean_object *)self));
}

/* Sdl.Renderer.getOutputSize : IO (Int32 x Int32) -- C: SDL_GetRenderOutputSize */
LEAN_EXPORT lean_obj_res lean_sdl_get_render_output_size(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    int rw = 0, rh = 0;
    if (!SDL_GetRenderOutputSize(r, &rw, &rh)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_render_mk_int32_pair((int32_t)rw, (int32_t)rh));
}

/* Sdl.Renderer.getCurrentOutputSize : IO (Int32 x Int32)
 * -- C: SDL_GetCurrentRenderOutputSize */
LEAN_EXPORT lean_obj_res lean_sdl_get_current_render_output_size(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    int rw = 0, rh = 0;
    if (!SDL_GetCurrentRenderOutputSize(r, &rw, &rh)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_render_mk_int32_pair((int32_t)rw, (int32_t)rh));
}

/* ==================== Texture creation ==================== */

/* Sdl.Renderer.createTextureRaw (format access : UInt32) (w h : Int32)
 * : IO Texture -- C: SDL_CreateTexture. Owner = inc'd renderer; registered. */
LEAN_EXPORT lean_obj_res lean_sdl_create_texture(
        b_lean_obj_arg self, uint32_t format, uint32_t access,
        int32_t rw, int32_t rh, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_Texture *t = SDL_CreateTexture(r, (SDL_PixelFormat)format,
                                       (SDL_TextureAccess)access, (int)rw, (int)rh);
    if (!t) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_texture(t, (lean_object *)self));
}

/* Sdl.Renderer.createTextureFromSurface (surface : @& Surface) : IO Texture
 * -- C: SDL_CreateTextureFromSurface. Owner = inc'd renderer; registered. */
LEAN_EXPORT lean_obj_res lean_sdl_create_texture_from_surface(
        b_lean_obj_arg self, b_lean_obj_arg surface, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_GET_OR_THROW(SDL_Surface, s, surface);
    SDL_Texture *t = SDL_CreateTextureFromSurface(r, s);
    if (!t) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_texture(t, (lean_object *)self));
}

/* Sdl.Renderer.createTextureWithProperties (props : @& Properties) : IO Texture
 * -- C: SDL_CreateTextureWithProperties. Owner = inc'd renderer; registered. */
LEAN_EXPORT lean_obj_res lean_sdl_create_texture_with_properties(
        b_lean_obj_arg self, b_lean_obj_arg props, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_PROPS_ID_OR_THROW(pid, props);
    SDL_Texture *t = SDL_CreateTextureWithProperties(r, pid);
    if (!t) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_texture(t, (lean_object *)self));
}

/* ==================== Render target ==================== */

/* Sdl.Renderer.setTargetRaw (texture : @& Option Texture)
 * -- C: SDL_SetRenderTarget (none -> NULL = the window). */
LEAN_EXPORT lean_obj_res lean_sdl_set_render_target(
        b_lean_obj_arg self, b_lean_obj_arg tex_opt, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_OPT_TEXTURE_OR_THROW(t, tex_opt);
    SDL_BOOL_TO_IO(SDL_SetRenderTarget(r, t));
}

/* Sdl.Renderer.getTarget : IO (Option Texture)
 * -- C: SDL_GetRenderTarget (registry lookup; NULL = default target -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_render_target(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    return lean_io_result_mk_ok(lean_sdl_texture_option(SDL_GetRenderTarget(r)));
}

/* ==================== Logical presentation / coordinates ==================== */

/* Sdl.Renderer.setLogicalPresentationRaw (w h : Int32) (mode : UInt32)
 * -- C: SDL_SetRenderLogicalPresentation */
LEAN_EXPORT lean_obj_res lean_sdl_set_render_logical_presentation(
        b_lean_obj_arg self, int32_t rw, int32_t rh, uint32_t mode, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BOOL_TO_IO(SDL_SetRenderLogicalPresentation(
        r, (int)rw, (int)rh, (SDL_RendererLogicalPresentation)mode));
}

/* Sdl.Renderer.getLogicalPresentationRaw : IO (Int32 x Int32 x UInt32)
 * -- C: SDL_GetRenderLogicalPresentation (mode decoded Lean-side). */
LEAN_EXPORT lean_obj_res lean_sdl_get_render_logical_presentation(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    int rw = 0, rh = 0;
    SDL_RendererLogicalPresentation mode = SDL_LOGICAL_PRESENTATION_DISABLED;
    if (!SDL_GetRenderLogicalPresentation(r, &rw, &rh, &mode)) return lean_sdl_throw();
    return lean_io_result_mk_ok(
        lean_sdl_render_mk_logical((int32_t)rw, (int32_t)rh, (uint32_t)mode));
}

/* Sdl.Renderer.getLogicalPresentationRect : IO FRect
 * -- C: SDL_GetRenderLogicalPresentationRect */
LEAN_EXPORT lean_obj_res lean_sdl_get_render_logical_presentation_rect(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_FRect fr;
    if (!SDL_GetRenderLogicalPresentationRect(r, &fr)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_render_mk_frect(fr.x, fr.y, fr.w, fr.h));
}

/* Sdl.Renderer.coordinatesFromWindow (windowX windowY : Float32)
 * : IO (Float32 x Float32) -- C: SDL_RenderCoordinatesFromWindow */
LEAN_EXPORT lean_obj_res lean_sdl_render_coordinates_from_window(
        b_lean_obj_arg self, float wx, float wy, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    float x = 0.0f, y = 0.0f;
    if (!SDL_RenderCoordinatesFromWindow(r, wx, wy, &x, &y)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_render_mk_float32_pair(x, y));
}

/* Sdl.Renderer.coordinatesToWindow (x y : Float32) : IO (Float32 x Float32)
 * -- C: SDL_RenderCoordinatesToWindow */
LEAN_EXPORT lean_obj_res lean_sdl_render_coordinates_to_window(
        b_lean_obj_arg self, float x, float y, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    float wx = 0.0f, wy = 0.0f;
    if (!SDL_RenderCoordinatesToWindow(r, x, y, &wx, &wy)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_render_mk_float32_pair(wx, wy));
}

/* ==================== Viewport, clip, scale ==================== */

/* Sdl.Renderer.setViewportRaw (hasRect ...) -- C: SDL_SetRenderViewport
 * (none = the entire target). */
LEAN_EXPORT lean_obj_res lean_sdl_set_render_viewport(
        b_lean_obj_arg self, uint8_t has_rect,
        int32_t x, int32_t y, int32_t rw, int32_t rh, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_RECT_ARG(rect, has_rect, x, y, rw, rh);
    SDL_BOOL_TO_IO(SDL_SetRenderViewport(r, rect));
}

/* Sdl.Renderer.getViewport : IO Rect -- C: SDL_GetRenderViewport */
LEAN_EXPORT lean_obj_res lean_sdl_get_render_viewport(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_Rect rect;
    if (!SDL_GetRenderViewport(r, &rect)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_render_mk_rect(rect.x, rect.y, rect.w, rect.h));
}

/* Sdl.Renderer.viewportSet : IO Bool -- C: SDL_RenderViewportSet */
LEAN_EXPORT lean_obj_res lean_sdl_render_viewport_set(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    return lean_io_result_mk_ok(lean_box(SDL_RenderViewportSet(r)));
}

/* Sdl.Renderer.getSafeArea : IO Rect -- C: SDL_GetRenderSafeArea */
LEAN_EXPORT lean_obj_res lean_sdl_get_render_safe_area(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_Rect rect;
    if (!SDL_GetRenderSafeArea(r, &rect)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_render_mk_rect(rect.x, rect.y, rect.w, rect.h));
}

/* Sdl.Renderer.setClipRectRaw (hasRect ...) -- C: SDL_SetRenderClipRect
 * (none disables clipping). */
LEAN_EXPORT lean_obj_res lean_sdl_set_render_clip_rect(
        b_lean_obj_arg self, uint8_t has_rect,
        int32_t x, int32_t y, int32_t rw, int32_t rh, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_RECT_ARG(rect, has_rect, x, y, rw, rh);
    SDL_BOOL_TO_IO(SDL_SetRenderClipRect(r, rect));
}

/* Sdl.Renderer.getClipRect : IO Rect -- C: SDL_GetRenderClipRect */
LEAN_EXPORT lean_obj_res lean_sdl_get_render_clip_rect(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_Rect rect;
    if (!SDL_GetRenderClipRect(r, &rect)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_render_mk_rect(rect.x, rect.y, rect.w, rect.h));
}

/* Sdl.Renderer.clipEnabled : IO Bool -- C: SDL_RenderClipEnabled */
LEAN_EXPORT lean_obj_res lean_sdl_render_clip_enabled(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    return lean_io_result_mk_ok(lean_box(SDL_RenderClipEnabled(r)));
}

/* Sdl.Renderer.setScale (scaleX scaleY : Float32) -- C: SDL_SetRenderScale */
LEAN_EXPORT lean_obj_res lean_sdl_set_render_scale(
        b_lean_obj_arg self, float sx, float sy, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BOOL_TO_IO(SDL_SetRenderScale(r, sx, sy));
}

/* Sdl.Renderer.getScale : IO (Float32 x Float32) -- C: SDL_GetRenderScale */
LEAN_EXPORT lean_obj_res lean_sdl_get_render_scale(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    float sx = 0.0f, sy = 0.0f;
    if (!SDL_GetRenderScale(r, &sx, &sy)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_render_mk_float32_pair(sx, sy));
}

/* ==================== Draw color, color scale, blend mode ==================== */

/* Sdl.Renderer.setDrawColor (r g b a : UInt8) -- C: SDL_SetRenderDrawColor */
LEAN_EXPORT lean_obj_res lean_sdl_set_render_draw_color(
        b_lean_obj_arg self, uint8_t cr, uint8_t cg, uint8_t cb, uint8_t ca,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BOOL_TO_IO(SDL_SetRenderDrawColor(r, cr, cg, cb, ca));
}

/* Sdl.Renderer.getDrawColor : IO (UInt8 x UInt8 x UInt8 x UInt8)
 * -- C: SDL_GetRenderDrawColor */
LEAN_EXPORT lean_obj_res lean_sdl_get_render_draw_color(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    Uint8 cr = 0, cg = 0, cb = 0, ca = 0;
    if (!SDL_GetRenderDrawColor(r, &cr, &cg, &cb, &ca)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_render_mk_uint8_quad(cr, cg, cb, ca));
}

/* Sdl.Renderer.setDrawColorFloat (r g b a : Float32)
 * -- C: SDL_SetRenderDrawColorFloat */
LEAN_EXPORT lean_obj_res lean_sdl_set_render_draw_color_float(
        b_lean_obj_arg self, float cr, float cg, float cb, float ca, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BOOL_TO_IO(SDL_SetRenderDrawColorFloat(r, cr, cg, cb, ca));
}

/* Sdl.Renderer.getDrawColorFloat : IO (Float32 x Float32 x Float32 x Float32)
 * -- C: SDL_GetRenderDrawColorFloat */
LEAN_EXPORT lean_obj_res lean_sdl_get_render_draw_color_float(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    float cr = 0, cg = 0, cb = 0, ca = 0;
    if (!SDL_GetRenderDrawColorFloat(r, &cr, &cg, &cb, &ca)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_render_mk_float32_quad(cr, cg, cb, ca));
}

/* Sdl.Renderer.setColorScale (scale : Float32) -- C: SDL_SetRenderColorScale */
LEAN_EXPORT lean_obj_res lean_sdl_set_render_color_scale(
        b_lean_obj_arg self, float scale, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BOOL_TO_IO(SDL_SetRenderColorScale(r, scale));
}

/* Sdl.Renderer.getColorScale : IO Float32 -- C: SDL_GetRenderColorScale */
LEAN_EXPORT lean_obj_res lean_sdl_get_render_color_scale(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    float scale = 0.0f;
    if (!SDL_GetRenderColorScale(r, &scale)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_float32(scale));
}

/* Sdl.Renderer.setDrawBlendModeRaw (mode : UInt32)
 * -- C: SDL_SetRenderDrawBlendMode */
LEAN_EXPORT lean_obj_res lean_sdl_set_render_draw_blend_mode(
        b_lean_obj_arg self, uint32_t mode, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BOOL_TO_IO(SDL_SetRenderDrawBlendMode(r, (SDL_BlendMode)mode));
}

/* Sdl.Renderer.getDrawBlendModeRaw : IO UInt32 -- C: SDL_GetRenderDrawBlendMode */
LEAN_EXPORT lean_obj_res lean_sdl_get_render_draw_blend_mode(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BlendMode mode = SDL_BLENDMODE_NONE;
    if (!SDL_GetRenderDrawBlendMode(r, &mode)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)mode));
}

/* ==================== Primitives ==================== */

/* Sdl.Renderer.clear -- C: SDL_RenderClear */
LEAN_EXPORT lean_obj_res lean_sdl_render_clear(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BOOL_TO_IO(SDL_RenderClear(r));
}

/* Sdl.Renderer.point (x y : Float32) -- C: SDL_RenderPoint */
LEAN_EXPORT lean_obj_res lean_sdl_render_point(
        b_lean_obj_arg self, float x, float y, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BOOL_TO_IO(SDL_RenderPoint(r, x, y));
}

/* Sdl.Renderer.pointsRaw (bytes : @& ByteArray) (count : Int32)
 * -- C: SDL_RenderPoints. Bytes are packed 2x float32 LE per point
 * (asserted == SDL_FPoint layout). */
LEAN_EXPORT lean_obj_res lean_sdl_render_points(
        b_lean_obj_arg self, b_lean_obj_arg bytes, int32_t count, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BOOL_TO_IO(SDL_RenderPoints(
        r, (const SDL_FPoint *)lean_sarray_cptr((lean_object *)bytes), (int)count));
}

/* Sdl.Renderer.line (x1 y1 x2 y2 : Float32) -- C: SDL_RenderLine */
LEAN_EXPORT lean_obj_res lean_sdl_render_line(
        b_lean_obj_arg self, float x1, float y1, float x2, float y2, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BOOL_TO_IO(SDL_RenderLine(r, x1, y1, x2, y2));
}

/* Sdl.Renderer.linesRaw (bytes : @& ByteArray) (count : Int32)
 * -- C: SDL_RenderLines (packed SDL_FPoint[]). */
LEAN_EXPORT lean_obj_res lean_sdl_render_lines(
        b_lean_obj_arg self, b_lean_obj_arg bytes, int32_t count, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BOOL_TO_IO(SDL_RenderLines(
        r, (const SDL_FPoint *)lean_sarray_cptr((lean_object *)bytes), (int)count));
}

/* Sdl.Renderer.rectRaw (hasRect ...) -- C: SDL_RenderRect
 * (none outlines the entire target). */
LEAN_EXPORT lean_obj_res lean_sdl_render_rect(
        b_lean_obj_arg self, uint8_t has_rect,
        float x, float y, float rw, float rh, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_FRECT_ARG(rect, has_rect, x, y, rw, rh);
    SDL_BOOL_TO_IO(SDL_RenderRect(r, rect));
}

/* Sdl.Renderer.rectsRaw (bytes : @& ByteArray) (count : Int32)
 * -- C: SDL_RenderRects (packed SDL_FRect[]). */
LEAN_EXPORT lean_obj_res lean_sdl_render_rects(
        b_lean_obj_arg self, b_lean_obj_arg bytes, int32_t count, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BOOL_TO_IO(SDL_RenderRects(
        r, (const SDL_FRect *)lean_sarray_cptr((lean_object *)bytes), (int)count));
}

/* Sdl.Renderer.fillRectRaw (hasRect ...) -- C: SDL_RenderFillRect
 * (none fills the entire target). */
LEAN_EXPORT lean_obj_res lean_sdl_render_fill_rect(
        b_lean_obj_arg self, uint8_t has_rect,
        float x, float y, float rw, float rh, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_FRECT_ARG(rect, has_rect, x, y, rw, rh);
    SDL_BOOL_TO_IO(SDL_RenderFillRect(r, rect));
}

/* Sdl.Renderer.fillRectsRaw (bytes : @& ByteArray) (count : Int32)
 * -- C: SDL_RenderFillRects (packed SDL_FRect[]). */
LEAN_EXPORT lean_obj_res lean_sdl_render_fill_rects(
        b_lean_obj_arg self, b_lean_obj_arg bytes, int32_t count, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BOOL_TO_IO(SDL_RenderFillRects(
        r, (const SDL_FRect *)lean_sarray_cptr((lean_object *)bytes), (int)count));
}

/* ==================== Texture copies ==================== */

/* Sdl.Renderer.textureRaw (tex) (hasSrc ...) (hasDst ...) -- C: SDL_RenderTexture */
LEAN_EXPORT lean_obj_res lean_sdl_render_texture(
        b_lean_obj_arg self, b_lean_obj_arg tex,
        uint8_t has_src, float sx, float sy, float sw, float sh,
        uint8_t has_dst, float dx, float dy, float dw, float dh, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_GET_OR_THROW(SDL_Texture, t, tex);
    SDL_FRECT_ARG(src, has_src, sx, sy, sw, sh);
    SDL_FRECT_ARG(dst, has_dst, dx, dy, dw, dh);
    SDL_BOOL_TO_IO(SDL_RenderTexture(r, t, src, dst));
}

/* Sdl.Renderer.textureRotatedRaw (tex) (hasSrc ...) (hasDst ...) (angle : Float)
 * (hasCenter cx cy) (flip : UInt32) -- C: SDL_RenderTextureRotated */
LEAN_EXPORT lean_obj_res lean_sdl_render_texture_rotated(
        b_lean_obj_arg self, b_lean_obj_arg tex,
        uint8_t has_src, float sx, float sy, float sw, float sh,
        uint8_t has_dst, float dx, float dy, float dw, float dh,
        double angle, uint8_t has_center, float cx, float cy,
        uint32_t flip, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_GET_OR_THROW(SDL_Texture, t, tex);
    SDL_FRECT_ARG(src, has_src, sx, sy, sw, sh);
    SDL_FRECT_ARG(dst, has_dst, dx, dy, dw, dh);
    SDL_FPOINT_ARG(center, has_center, cx, cy);
    SDL_BOOL_TO_IO(SDL_RenderTextureRotated(r, t, src, dst, angle, center,
                                            (SDL_FlipMode)flip));
}

/* Sdl.Renderer.textureAffineRaw (tex) (hasSrc ...) (hasOrigin ...) (hasRight ...)
 * (hasDown ...) -- C: SDL_RenderTextureAffine */
LEAN_EXPORT lean_obj_res lean_sdl_render_texture_affine(
        b_lean_obj_arg self, b_lean_obj_arg tex,
        uint8_t has_src, float sx, float sy, float sw, float sh,
        uint8_t has_origin, float ox, float oy,
        uint8_t has_right, float rx, float ry,
        uint8_t has_down, float ddx, float ddy, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_GET_OR_THROW(SDL_Texture, t, tex);
    SDL_FRECT_ARG(src, has_src, sx, sy, sw, sh);
    SDL_FPOINT_ARG(origin, has_origin, ox, oy);
    SDL_FPOINT_ARG(right, has_right, rx, ry);
    SDL_FPOINT_ARG(down, has_down, ddx, ddy);
    SDL_BOOL_TO_IO(SDL_RenderTextureAffine(r, t, src, origin, right, down));
}

/* Sdl.Renderer.textureTiledRaw (tex) (hasSrc ...) (scale) (hasDst ...)
 * -- C: SDL_RenderTextureTiled */
LEAN_EXPORT lean_obj_res lean_sdl_render_texture_tiled(
        b_lean_obj_arg self, b_lean_obj_arg tex,
        uint8_t has_src, float sx, float sy, float sw, float sh, float scale,
        uint8_t has_dst, float dx, float dy, float dw, float dh, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_GET_OR_THROW(SDL_Texture, t, tex);
    SDL_FRECT_ARG(src, has_src, sx, sy, sw, sh);
    SDL_FRECT_ARG(dst, has_dst, dx, dy, dw, dh);
    SDL_BOOL_TO_IO(SDL_RenderTextureTiled(r, t, src, scale, dst));
}

/* Sdl.Renderer.texture9GridRaw (tex) (hasSrc ...) (corner sizes + scale)
 * (hasDst ...) -- C: SDL_RenderTexture9Grid */
LEAN_EXPORT lean_obj_res lean_sdl_render_texture_9grid(
        b_lean_obj_arg self, b_lean_obj_arg tex,
        uint8_t has_src, float sx, float sy, float sw, float sh,
        float left_width, float right_width, float top_height, float bottom_height,
        float scale,
        uint8_t has_dst, float dx, float dy, float dw, float dh, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_GET_OR_THROW(SDL_Texture, t, tex);
    SDL_FRECT_ARG(src, has_src, sx, sy, sw, sh);
    SDL_FRECT_ARG(dst, has_dst, dx, dy, dw, dh);
    SDL_BOOL_TO_IO(SDL_RenderTexture9Grid(r, t, src, left_width, right_width,
                                          top_height, bottom_height, scale, dst));
}

/* Sdl.Renderer.texture9GridTiledRaw (... + tileScale)
 * -- C: SDL_RenderTexture9GridTiled */
LEAN_EXPORT lean_obj_res lean_sdl_render_texture_9grid_tiled(
        b_lean_obj_arg self, b_lean_obj_arg tex,
        uint8_t has_src, float sx, float sy, float sw, float sh,
        float left_width, float right_width, float top_height, float bottom_height,
        float scale,
        uint8_t has_dst, float dx, float dy, float dw, float dh,
        float tile_scale, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_GET_OR_THROW(SDL_Texture, t, tex);
    SDL_FRECT_ARG(src, has_src, sx, sy, sw, sh);
    SDL_FRECT_ARG(dst, has_dst, dx, dy, dw, dh);
    SDL_BOOL_TO_IO(SDL_RenderTexture9GridTiled(r, t, src, left_width, right_width,
                                               top_height, bottom_height, scale, dst,
                                               tile_scale));
}

/* Sdl.Renderer.geometryRaw (texture : @& Option Texture) (vertices : @& ByteArray)
 * (numVertices : Int32) (indices : @& ByteArray) (numIndices : Int32)
 * -- C: SDL_RenderGeometry. Vertices are packed 8x float32 LE per vertex
 * (asserted == SDL_Vertex layout); indices 1x int32 LE each (empty -> NULL, 0). */
LEAN_EXPORT lean_obj_res lean_sdl_render_geometry(
        b_lean_obj_arg self, b_lean_obj_arg tex_opt,
        b_lean_obj_arg vertices, int32_t num_vertices,
        b_lean_obj_arg indices, int32_t num_indices, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_OPT_TEXTURE_OR_THROW(t, tex_opt);
    const int *idx = num_indices > 0
        ? (const int *)lean_sarray_cptr((lean_object *)indices) : NULL;
    SDL_BOOL_TO_IO(SDL_RenderGeometry(
        r, t, (const SDL_Vertex *)lean_sarray_cptr((lean_object *)vertices),
        (int)num_vertices, idx, num_indices > 0 ? (int)num_indices : 0));
}

/* Sdl.Renderer.setTextureAddressModeRaw (u v : UInt32)
 * -- C: SDL_SetRenderTextureAddressMode */
LEAN_EXPORT lean_obj_res lean_sdl_set_render_texture_address_mode(
        b_lean_obj_arg self, uint32_t u_mode, uint32_t v_mode, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BOOL_TO_IO(SDL_SetRenderTextureAddressMode(
        r, (SDL_TextureAddressMode)u_mode, (SDL_TextureAddressMode)v_mode));
}

/* Sdl.Renderer.getTextureAddressModeRaw : IO (UInt32 x UInt32)
 * -- C: SDL_GetRenderTextureAddressMode */
LEAN_EXPORT lean_obj_res lean_sdl_get_render_texture_address_mode(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_TextureAddressMode u_mode = SDL_TEXTURE_ADDRESS_AUTO;
    SDL_TextureAddressMode v_mode = SDL_TEXTURE_ADDRESS_AUTO;
    if (!SDL_GetRenderTextureAddressMode(r, &u_mode, &v_mode)) return lean_sdl_throw();
    return lean_io_result_mk_ok(
        lean_sdl_render_mk_uint32_pair((uint32_t)u_mode, (uint32_t)v_mode));
}

/* ==================== Pixels, present, vsync ==================== */

/* Sdl.Renderer.readPixelsRaw (hasRect ...) : IO Surface
 * -- C: SDL_RenderReadPixels. New OWNED surface (root; owner NULL). */
LEAN_EXPORT lean_obj_res lean_sdl_render_read_pixels(
        b_lean_obj_arg self, uint8_t has_rect,
        int32_t x, int32_t y, int32_t rw, int32_t rh, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_RECT_ARG(rect, has_rect, x, y, rw, rh);
    SDL_Surface *s = SDL_RenderReadPixels(r, rect);
    if (!s) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_surface_class, s, NULL));
}

/* Sdl.Renderer.present -- C: SDL_RenderPresent */
LEAN_EXPORT lean_obj_res lean_sdl_render_present(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BOOL_TO_IO(SDL_RenderPresent(r));
}

/* Sdl.Renderer.flush -- C: SDL_FlushRenderer */
LEAN_EXPORT lean_obj_res lean_sdl_flush_renderer(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BOOL_TO_IO(SDL_FlushRenderer(r));
}

/* Sdl.Renderer.setVSync (vsync : Int32) -- C: SDL_SetRenderVSync */
LEAN_EXPORT lean_obj_res lean_sdl_set_render_vsync(
        b_lean_obj_arg self, int32_t vsync, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BOOL_TO_IO(SDL_SetRenderVSync(r, (int)vsync));
}

/* Sdl.Renderer.getVSync : IO Int32 -- C: SDL_GetRenderVSync */
LEAN_EXPORT lean_obj_res lean_sdl_get_render_vsync(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    int vsync = 0;
    if (!SDL_GetRenderVSync(r, &vsync)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)(int32_t)vsync));
}

/* Sdl.Renderer.debugText (x y : Float32) (text : @& String)
 * -- C: SDL_RenderDebugText */
LEAN_EXPORT lean_obj_res lean_sdl_render_debug_text(
        b_lean_obj_arg self, float x, float y, b_lean_obj_arg text, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BOOL_TO_IO(SDL_RenderDebugText(r, x, y, lean_string_cstr(text)));
}

/* Sdl.Renderer.setDefaultTextureScaleModeRaw (mode : UInt32)
 * -- C: SDL_SetDefaultTextureScaleMode */
LEAN_EXPORT lean_obj_res lean_sdl_set_default_texture_scale_mode(
        b_lean_obj_arg self, uint32_t mode, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_BOOL_TO_IO(SDL_SetDefaultTextureScaleMode(r, (SDL_ScaleMode)mode));
}

/* Sdl.Renderer.getDefaultTextureScaleModeRaw : IO UInt32
 * -- C: SDL_GetDefaultTextureScaleMode */
LEAN_EXPORT lean_obj_res lean_sdl_get_default_texture_scale_mode(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, r, self);
    SDL_ScaleMode mode = SDL_SCALEMODE_LINEAR;
    if (!SDL_GetDefaultTextureScaleMode(r, &mode)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)mode));
}

/* ==================== Texture queries ==================== */

/* Sdl.Texture.properties : IO Properties -- C: SDL_GetTextureProperties.
 * Borrowed, owner = inc'd texture; 0 -> throw. */
LEAN_EXPORT lean_obj_res lean_sdl_get_texture_properties(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    SDL_PropertiesID id = SDL_GetTextureProperties(t);
    if (id == 0) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_properties_borrowed(id, (lean_object *)self));
}

/* Sdl.Texture.renderer : IO Renderer -- C: SDL_GetRendererFromTexture. The
 * holder's owner IS the creating renderer's external (no registry lookup
 * needed); guarded so a destroyed texture throws. */
LEAN_EXPORT lean_obj_res lean_sdl_get_renderer_from_texture(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    (void)t;
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->owner)
        return lean_sdl_throw_msg("SDL: texture has no owning renderer");
    lean_inc(h->owner);
    return lean_io_result_mk_ok(h->owner);
}

/* Sdl.Texture.getSize : IO (Float32 x Float32) -- C: SDL_GetTextureSize */
LEAN_EXPORT lean_obj_res lean_sdl_get_texture_size(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    float tw = 0.0f, th = 0.0f;
    if (!SDL_GetTextureSize(t, &tw, &th)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_render_mk_float32_pair(tw, th));
}

/* Sdl.Texture.width : IO Int32 -- reads the public SDL_Texture.w */
LEAN_EXPORT lean_obj_res lean_sdl_texture_width(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)t->w));
}

/* Sdl.Texture.height : IO Int32 -- reads the public SDL_Texture.h */
LEAN_EXPORT lean_obj_res lean_sdl_texture_height(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)t->h));
}

/* Sdl.Texture.formatRaw : IO UInt32 -- reads the public SDL_Texture.format */
LEAN_EXPORT lean_obj_res lean_sdl_texture_format(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)t->format));
}

/* ==================== Texture palette / mods / modes ==================== */

/* Sdl.Texture.setPalette (palette : @& Palette) -- C: SDL_SetTexturePalette.
 * Accepts owned or borrowed palette class alike (reads the holder only). */
LEAN_EXPORT lean_obj_res lean_sdl_set_texture_palette(
        b_lean_obj_arg self, b_lean_obj_arg palette, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    SDL_GET_OR_THROW(SDL_Palette, p, palette);
    SDL_BOOL_TO_IO(SDL_SetTexturePalette(t, p));
}

/* Sdl.Texture.getPalette : IO (Option Palette) -- C: SDL_GetTexturePalette.
 * NULL -> none (SDL also returns NULL on error; the ambiguity is documented
 * Lean-side). Some -> borrowed palette, owner = inc'd texture. */
LEAN_EXPORT lean_obj_res lean_sdl_get_texture_palette(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    SDL_Palette *p = SDL_GetTexturePalette(t);
    if (!p) return lean_io_result_mk_ok(lean_sdl_none());
    lean_inc(self);
    return lean_io_result_mk_ok(
        lean_sdl_some(lean_sdl_wrap(lean_sdl_palette_borrowed_class, p,
                                    (lean_object *)self)));
}

/* Sdl.Texture.setColorMod (r g b : UInt8) -- C: SDL_SetTextureColorMod */
LEAN_EXPORT lean_obj_res lean_sdl_set_texture_color_mod(
        b_lean_obj_arg self, uint8_t cr, uint8_t cg, uint8_t cb, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    SDL_BOOL_TO_IO(SDL_SetTextureColorMod(t, cr, cg, cb));
}

/* Sdl.Texture.getColorMod : IO (UInt8 x UInt8 x UInt8)
 * -- C: SDL_GetTextureColorMod */
LEAN_EXPORT lean_obj_res lean_sdl_get_texture_color_mod(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    Uint8 cr = 0, cg = 0, cb = 0;
    if (!SDL_GetTextureColorMod(t, &cr, &cg, &cb)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_render_mk_uint8_triple(cr, cg, cb));
}

/* Sdl.Texture.setColorModFloat (r g b : Float32)
 * -- C: SDL_SetTextureColorModFloat */
LEAN_EXPORT lean_obj_res lean_sdl_set_texture_color_mod_float(
        b_lean_obj_arg self, float cr, float cg, float cb, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    SDL_BOOL_TO_IO(SDL_SetTextureColorModFloat(t, cr, cg, cb));
}

/* Sdl.Texture.getColorModFloat : IO (Float32 x Float32 x Float32)
 * -- C: SDL_GetTextureColorModFloat */
LEAN_EXPORT lean_obj_res lean_sdl_get_texture_color_mod_float(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    float cr = 0, cg = 0, cb = 0;
    if (!SDL_GetTextureColorModFloat(t, &cr, &cg, &cb)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_render_mk_float32_triple(cr, cg, cb));
}

/* Sdl.Texture.setAlphaMod (alpha : UInt8) -- C: SDL_SetTextureAlphaMod */
LEAN_EXPORT lean_obj_res lean_sdl_set_texture_alpha_mod(
        b_lean_obj_arg self, uint8_t alpha, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    SDL_BOOL_TO_IO(SDL_SetTextureAlphaMod(t, alpha));
}

/* Sdl.Texture.getAlphaMod : IO UInt8 -- C: SDL_GetTextureAlphaMod */
LEAN_EXPORT lean_obj_res lean_sdl_get_texture_alpha_mod(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    Uint8 alpha = 0;
    if (!SDL_GetTextureAlphaMod(t, &alpha)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box(alpha));
}

/* Sdl.Texture.setAlphaModFloat (alpha : Float32)
 * -- C: SDL_SetTextureAlphaModFloat */
LEAN_EXPORT lean_obj_res lean_sdl_set_texture_alpha_mod_float(
        b_lean_obj_arg self, float alpha, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    SDL_BOOL_TO_IO(SDL_SetTextureAlphaModFloat(t, alpha));
}

/* Sdl.Texture.getAlphaModFloat : IO Float32 -- C: SDL_GetTextureAlphaModFloat */
LEAN_EXPORT lean_obj_res lean_sdl_get_texture_alpha_mod_float(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    float alpha = 0.0f;
    if (!SDL_GetTextureAlphaModFloat(t, &alpha)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_float32(alpha));
}

/* Sdl.Texture.setBlendModeRaw (mode : UInt32) -- C: SDL_SetTextureBlendMode */
LEAN_EXPORT lean_obj_res lean_sdl_set_texture_blend_mode(
        b_lean_obj_arg self, uint32_t mode, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    SDL_BOOL_TO_IO(SDL_SetTextureBlendMode(t, (SDL_BlendMode)mode));
}

/* Sdl.Texture.getBlendModeRaw : IO UInt32 -- C: SDL_GetTextureBlendMode */
LEAN_EXPORT lean_obj_res lean_sdl_get_texture_blend_mode(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    SDL_BlendMode mode = SDL_BLENDMODE_NONE;
    if (!SDL_GetTextureBlendMode(t, &mode)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)mode));
}

/* Sdl.Texture.setScaleModeRaw (mode : UInt32) -- C: SDL_SetTextureScaleMode */
LEAN_EXPORT lean_obj_res lean_sdl_set_texture_scale_mode(
        b_lean_obj_arg self, uint32_t mode, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    SDL_BOOL_TO_IO(SDL_SetTextureScaleMode(t, (SDL_ScaleMode)mode));
}

/* Sdl.Texture.getScaleModeRaw : IO UInt32 -- C: SDL_GetTextureScaleMode */
LEAN_EXPORT lean_obj_res lean_sdl_get_texture_scale_mode(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    SDL_ScaleMode mode = SDL_SCALEMODE_LINEAR;
    if (!SDL_GetTextureScaleMode(t, &mode)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)mode));
}

/* ==================== Texture updates / locking ==================== */

/* Sdl.Texture.updateRaw (hasRect ...) (pixels : @& ByteArray) (pitch : Int32)
 * -- C: SDL_UpdateTexture (copies synchronously; the ByteArray stays owned by
 * Lean). */
LEAN_EXPORT lean_obj_res lean_sdl_update_texture(
        b_lean_obj_arg self, uint8_t has_rect,
        int32_t x, int32_t y, int32_t rw, int32_t rh,
        b_lean_obj_arg pixels, int32_t pitch, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    SDL_RECT_ARG(rect, has_rect, x, y, rw, rh);
    SDL_BOOL_TO_IO(SDL_UpdateTexture(
        t, rect, lean_sarray_cptr((lean_object *)pixels), (int)pitch));
}

/* Sdl.Texture.updateYUVRaw (hasRect ...) (y yPitch u uPitch v vPitch)
 * -- C: SDL_UpdateYUVTexture (copies synchronously). */
LEAN_EXPORT lean_obj_res lean_sdl_update_yuv_texture(
        b_lean_obj_arg self, uint8_t has_rect,
        int32_t x, int32_t y, int32_t rw, int32_t rh,
        b_lean_obj_arg yplane, int32_t ypitch,
        b_lean_obj_arg uplane, int32_t upitch,
        b_lean_obj_arg vplane, int32_t vpitch, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    SDL_RECT_ARG(rect, has_rect, x, y, rw, rh);
    SDL_BOOL_TO_IO(SDL_UpdateYUVTexture(
        t, rect,
        (const Uint8 *)lean_sarray_cptr((lean_object *)yplane), (int)ypitch,
        (const Uint8 *)lean_sarray_cptr((lean_object *)uplane), (int)upitch,
        (const Uint8 *)lean_sarray_cptr((lean_object *)vplane), (int)vpitch));
}

/* Sdl.Texture.updateNVRaw (hasRect ...) (y yPitch uv uvPitch)
 * -- C: SDL_UpdateNVTexture (copies synchronously). */
LEAN_EXPORT lean_obj_res lean_sdl_update_nv_texture(
        b_lean_obj_arg self, uint8_t has_rect,
        int32_t x, int32_t y, int32_t rw, int32_t rh,
        b_lean_obj_arg yplane, int32_t ypitch,
        b_lean_obj_arg uvplane, int32_t uvpitch, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    SDL_RECT_ARG(rect, has_rect, x, y, rw, rh);
    SDL_BOOL_TO_IO(SDL_UpdateNVTexture(
        t, rect,
        (const Uint8 *)lean_sarray_cptr((lean_object *)yplane), (int)ypitch,
        (const Uint8 *)lean_sarray_cptr((lean_object *)uvplane), (int)uvpitch));
}

/* Sdl.Texture.lockToSurfaceRaw (hasRect ...) : IO Surface
 * -- C: SDL_LockTextureToSurface. BORROWED surface (freed internally by
 * SDL_UnlockTexture / SDL_DestroyTexture), owner = inc'd texture. */
LEAN_EXPORT lean_obj_res lean_sdl_lock_texture_to_surface(
        b_lean_obj_arg self, uint8_t has_rect,
        int32_t x, int32_t y, int32_t rw, int32_t rh, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    SDL_RECT_ARG(rect, has_rect, x, y, rw, rh);
    SDL_Surface *surf = NULL;
    if (!SDL_LockTextureToSurface(t, rect, &surf)) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_surface_borrowed(surf, (lean_object *)self));
}

/* Sdl.Texture.unlock -- C: SDL_UnlockTexture (void). */
LEAN_EXPORT lean_obj_res lean_sdl_unlock_texture(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    SDL_UnlockTexture(t);
    return lean_sdl_unit_ok();
}

/* Sdl.Texture.destroy -- C: SDL_DestroyTexture. Manual destroy (leaf type):
 * NULL the ptr and release the owner so the renderer can die; a second destroy
 * or any later op throws via SDL_GET_OR_THROW. */
LEAN_EXPORT lean_obj_res lean_sdl_destroy_texture(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Texture, t, self);
    SDL_DestroyTexture(t);
    sdl_holder *h = lean_sdl_holder_of(self);
    h->ptr = NULL;
    if (h->owner) {
        lean_dec(h->owner);
        h->owner = NULL;
    }
    return lean_sdl_unit_ok();
}
