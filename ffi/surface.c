/* Shims for Sdl/Surface.lean (SDL_surface.h).
 *
 * Two external classes over the Lean `Surface` type:
 *   - lean_sdl_surface          : owned (SDL_CreateSurface / loaders / rotate /
 *     duplicate / scale / convert) -> finalizer runs SDL_DestroySurface.
 *   - lean_sdl_surface_borrowed : borrowed (e.g. a window's surface from
 *     SDL_GetWindowSurface in M4) -> never destroyed. Defined + registered now,
 *     unused here.
 *
 * FINALIZER-ONLY: no manual destroy. Surfaces hand out *borrowed* Palette
 * handles (SDL_CreateSurfacePalette / SDL_GetSurfacePalette) whose raw
 * SDL_Palette* dies with the surface; RC finalizer ordering (the borrowed
 * palette holds an owned ref to the surface external) keeps the surface alive
 * until the palette handle is gone. A manual destroy could NULL the surface out
 * from under a still-live borrowed palette, so it is not offered.
 *
 * Structure results (Color, FColor, Rect) are built by @[export]ed Lean makers,
 * so C never lays out a Lean structure. Rect params are flattened (a hasRect
 * byte + 4 Int32) and rebuilt here; nothing reinterprets a Lean buffer as an
 * SDL_Rect. */
#include "util.h"
#include "classes.h"

/* Lean-owned makers: mk_color/mk_rect build Sdl.Color/Sdl.Rect; mk_fcolor
 * builds Sdl.FColor (its maker lives in Sdl/Surface.lean per the plan). */
extern lean_object *lean_sdl_mk_color(uint8_t r, uint8_t g, uint8_t b, uint8_t a);
extern lean_object *lean_sdl_mk_fcolor(float r, float g, float b, float a);
extern lean_object *lean_sdl_mk_rect(int32_t x, int32_t y, int32_t w, int32_t h);

/* Owned: destroy on finalize. */
SDL_DEFINE_CLASS(lean_sdl_surface, SDL_DestroySurface((SDL_Surface *)self))
/* Borrowed (e.g. a window's surface): never destroyed. */
SDL_DEFINE_BORROWED_CLASS(lean_sdl_surface_borrowed)

/* Register both classes. Called from Sdl/Surface.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_surface_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_surface_class_init();
    lean_sdl_surface_borrowed_class_init();
    return lean_sdl_unit_ok();
}

/* Wrap an owned SDL_Surface* (result of a create/load/transform). */
static lean_obj_res lean_sdl_wrap_surface_or_throw(SDL_Surface *s) {
    if (!s) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_surface_class, s, NULL));
}

/* Extract a borrowed `@& Option Palette`: none -> NULL; some destroyed ->
 * flag *destroyed. Mirrors ffi/pixels.c's helper (static there). */
static SDL_Palette *lean_sdl_opt_palette(b_lean_obj_arg opt, bool *destroyed) {
    *destroyed = false;
    if (lean_is_scalar(opt)) return NULL; /* none = lean_box(0) */
    sdl_holder *h = lean_sdl_holder_of(lean_ctor_get(opt, 0));
    if (!h->ptr) { *destroyed = true; return NULL; }
    return (SDL_Palette *)h->ptr;
}

#define SDL_OPT_PALETTE_OR_THROW(var, opt)                                     \
    SDL_Palette *var;                                                          \
    do {                                                                       \
        bool _destroyed;                                                       \
        var = lean_sdl_opt_palette(opt, &_destroyed);                          \
        if (_destroyed)                                                        \
            return lean_sdl_throw_msg("SDL: handle used after destroy/release"); \
    } while (0)

/* Extract a borrowed `@& Option Properties`: none -> 0; some destroyed ->
 * flag *destroyed. The holder ptr encodes an SDL_PropertiesID. */
static SDL_PropertiesID lean_sdl_opt_props(b_lean_obj_arg opt, bool *destroyed) {
    *destroyed = false;
    if (lean_is_scalar(opt)) return 0; /* none = lean_box(0) */
    sdl_holder *h = lean_sdl_holder_of(lean_ctor_get(opt, 0));
    if (!h->ptr) { *destroyed = true; return 0; }
    return (SDL_PropertiesID)(uintptr_t)h->ptr;
}

#define SDL_OPT_PROPS_OR_THROW(var, opt)                                       \
    SDL_PropertiesID var;                                                      \
    do {                                                                       \
        bool _destroyed;                                                       \
        var = lean_sdl_opt_props(opt, &_destroyed);                            \
        if (_destroyed)                                                        \
            return lean_sdl_throw_msg("SDL: handle used after destroy/release"); \
    } while (0)

/* Build an `SDL_Rect *` from flattened args: NULL when `has` is 0. */
#define SDL_RECT_ARG(name, has, rx, ry, rw, rh)                                \
    SDL_Rect name##_storage = { (int)(rx), (int)(ry), (int)(rw), (int)(rh) };  \
    const SDL_Rect *name = (has) ? &name##_storage : NULL

/* ---------- Constructors / loaders ---------- */

/* Sdl.createSurface (width height : Int32) (format : UInt32) : IO Surface
 * -- C: SDL_CreateSurface */
LEAN_EXPORT lean_obj_res lean_sdl_create_surface(
        int32_t width, int32_t height, uint32_t format, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_sdl_wrap_surface_or_throw(
        SDL_CreateSurface((int)width, (int)height, (SDL_PixelFormat)format));
}

/* Sdl.loadBMP (file : String) : IO Surface -- C: SDL_LoadBMP */
LEAN_EXPORT lean_obj_res lean_sdl_load_bmp(b_lean_obj_arg file, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_sdl_wrap_surface_or_throw(SDL_LoadBMP(lean_string_cstr(file)));
}

/* Sdl.loadPNG (file : String) : IO Surface -- C: SDL_LoadPNG */
LEAN_EXPORT lean_obj_res lean_sdl_load_png(b_lean_obj_arg file, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_sdl_wrap_surface_or_throw(SDL_LoadPNG(lean_string_cstr(file)));
}

/* Sdl.loadSurface (file : String) : IO Surface -- C: SDL_LoadSurface (auto). */
LEAN_EXPORT lean_obj_res lean_sdl_load_surface(b_lean_obj_arg file, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_sdl_wrap_surface_or_throw(SDL_LoadSurface(lean_string_cstr(file)));
}

/* Sdl.loadBMPIO (src : @& IOStream) : IO Surface
 * -- C: SDL_LoadBMP_IO (closeio=false). */
LEAN_EXPORT lean_obj_res lean_sdl_load_bmp_io(b_lean_obj_arg src, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_IOStream, io, src);
    return lean_sdl_wrap_surface_or_throw(SDL_LoadBMP_IO(io, false));
}

/* Sdl.loadPNGIO (src : @& IOStream) : IO Surface
 * -- C: SDL_LoadPNG_IO (closeio=false). */
LEAN_EXPORT lean_obj_res lean_sdl_load_png_io(b_lean_obj_arg src, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_IOStream, io, src);
    return lean_sdl_wrap_surface_or_throw(SDL_LoadPNG_IO(io, false));
}

/* Sdl.loadSurfaceIO (src : @& IOStream) : IO Surface
 * -- C: SDL_LoadSurface_IO (closeio=false). */
LEAN_EXPORT lean_obj_res lean_sdl_load_surface_io(b_lean_obj_arg src, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_IOStream, io, src);
    return lean_sdl_wrap_surface_or_throw(SDL_LoadSurface_IO(io, false));
}

/* ---------- Field getters ---------- */

/* Sdl.Surface.width : IO Int32 -- reads SDL_Surface.w */
LEAN_EXPORT lean_obj_res lean_sdl_surface_width(b_lean_obj_arg surf, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)s->w));
}

/* Sdl.Surface.height : IO Int32 -- reads SDL_Surface.h */
LEAN_EXPORT lean_obj_res lean_sdl_surface_height(b_lean_obj_arg surf, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)s->h));
}

/* Sdl.Surface.pitch : IO Int32 -- reads SDL_Surface.pitch */
LEAN_EXPORT lean_obj_res lean_sdl_surface_pitch(b_lean_obj_arg surf, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)s->pitch));
}

/* Sdl.Surface.formatRaw : IO UInt32 -- reads SDL_Surface.format */
LEAN_EXPORT lean_obj_res lean_sdl_surface_format(b_lean_obj_arg surf, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)s->format));
}

/* Sdl.Surface.flagsRaw : IO UInt32 -- reads SDL_Surface.flags */
LEAN_EXPORT lean_obj_res lean_sdl_surface_flags(b_lean_obj_arg surf, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)s->flags));
}

/* ---------- Properties / colorspace / palette ---------- */

/* Sdl.Surface.getProperties : IO Properties -- C: SDL_GetSurfaceProperties.
 * Borrowed Properties, owner = inc'd surface. */
LEAN_EXPORT lean_obj_res lean_sdl_get_surface_properties(b_lean_obj_arg surf, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_PropertiesID id = SDL_GetSurfaceProperties(s);
    if (id == 0) return lean_sdl_throw();
    lean_inc(surf);
    return lean_io_result_mk_ok(lean_sdl_wrap_properties_borrowed(id, surf));
}

/* Sdl.Surface.setColorspaceRaw (c : UInt32) -- C: SDL_SetSurfaceColorspace */
LEAN_EXPORT lean_obj_res lean_sdl_set_surface_colorspace(
        b_lean_obj_arg surf, uint32_t c, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_BOOL_TO_IO(SDL_SetSurfaceColorspace(s, (SDL_Colorspace)c));
}

/* Sdl.Surface.getColorspaceRaw : IO UInt32 -- C: SDL_GetSurfaceColorspace
 * (infallible for a valid surface; UNKNOWN only when NULL). */
LEAN_EXPORT lean_obj_res lean_sdl_get_surface_colorspace(b_lean_obj_arg surf, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetSurfaceColorspace(s)));
}

/* Sdl.Surface.createPalette : IO Palette -- C: SDL_CreateSurfacePalette.
 * Borrowed palette owned by the surface (owner = inc'd surface). */
LEAN_EXPORT lean_obj_res lean_sdl_create_surface_palette(b_lean_obj_arg surf, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_Palette *p = SDL_CreateSurfacePalette(s);
    if (!p) return lean_sdl_throw();
    lean_inc(surf);
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_palette_borrowed_class, p, surf));
}

/* Sdl.Surface.getPalette : IO (Option Palette) -- C: SDL_GetSurfacePalette.
 * NULL is "no palette" (not an error); some is borrowed (owner = inc'd surface). */
LEAN_EXPORT lean_obj_res lean_sdl_get_surface_palette(b_lean_obj_arg surf, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_Palette *p = SDL_GetSurfacePalette(s);
    if (!p) return lean_io_result_mk_ok(lean_sdl_none());
    lean_inc(surf);
    return lean_io_result_mk_ok(
        lean_sdl_some(lean_sdl_wrap(lean_sdl_palette_borrowed_class, p, surf)));
}

/* Sdl.Surface.setPalette (p : @& Palette) -- C: SDL_SetSurfacePalette
 * (SDL keeps its own internal reference). */
LEAN_EXPORT lean_obj_res lean_sdl_set_surface_palette(
        b_lean_obj_arg surf, b_lean_obj_arg pal, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_GET_OR_THROW(SDL_Palette, p, pal);
    SDL_BOOL_TO_IO(SDL_SetSurfacePalette(s, p));
}

/* ---------- Alternate images ---------- */

/* Sdl.Surface.addAlternateImage (image : @& Surface)
 * -- C: SDL_AddSurfaceAlternateImage (SDL adds its own ref to `image`). */
LEAN_EXPORT lean_obj_res lean_sdl_add_surface_alternate_image(
        b_lean_obj_arg surf, b_lean_obj_arg image, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_GET_OR_THROW(SDL_Surface, img, image);
    SDL_BOOL_TO_IO(SDL_AddSurfaceAlternateImage(s, img));
}

/* Sdl.Surface.hasAlternateImages : IO Bool -- C: SDL_SurfaceHasAlternateImages */
LEAN_EXPORT lean_obj_res lean_sdl_surface_has_alternate_images(b_lean_obj_arg surf, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    return lean_io_result_mk_ok(lean_box(SDL_SurfaceHasAlternateImages(s)));
}

/* Sdl.Surface.removeAlternateImages : IO Unit -- C: SDL_RemoveSurfaceAlternateImages */
LEAN_EXPORT lean_obj_res lean_sdl_remove_surface_alternate_images(b_lean_obj_arg surf, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_RemoveSurfaceAlternateImages(s);
    return lean_sdl_unit_ok();
}

/* ---------- RLE / color key / mods / blend ---------- */

/* Sdl.Surface.setRLE (enabled : Bool) -- C: SDL_SetSurfaceRLE */
LEAN_EXPORT lean_obj_res lean_sdl_set_surface_rle(
        b_lean_obj_arg surf, uint8_t enabled, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_BOOL_TO_IO(SDL_SetSurfaceRLE(s, enabled != 0));
}

/* Sdl.Surface.hasRLE : IO Bool -- C: SDL_SurfaceHasRLE */
LEAN_EXPORT lean_obj_res lean_sdl_surface_has_rle(b_lean_obj_arg surf, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    return lean_io_result_mk_ok(lean_box(SDL_SurfaceHasRLE(s)));
}

/* Sdl.Surface.setColorKeyRaw (enabled : Bool) (key : UInt32)
 * -- C: SDL_SetSurfaceColorKey (none disables via enabled=false, key=0). */
LEAN_EXPORT lean_obj_res lean_sdl_set_surface_color_key(
        b_lean_obj_arg surf, uint8_t enabled, uint32_t key, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_BOOL_TO_IO(SDL_SetSurfaceColorKey(s, enabled != 0, key));
}

/* Sdl.Surface.getColorKey : IO (Option UInt32)
 * -- C: SDL_SurfaceHasColorKey ? SDL_GetSurfaceColorKey : none. */
LEAN_EXPORT lean_obj_res lean_sdl_get_surface_color_key(b_lean_obj_arg surf, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    if (!SDL_SurfaceHasColorKey(s)) return lean_io_result_mk_ok(lean_sdl_none());
    Uint32 key = 0;
    if (!SDL_GetSurfaceColorKey(s, &key)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_some(lean_box_uint32(key)));
}

/* Sdl.Surface.setColorMod (r g b : UInt8) -- C: SDL_SetSurfaceColorMod */
LEAN_EXPORT lean_obj_res lean_sdl_set_surface_color_mod(
        b_lean_obj_arg surf, uint8_t r, uint8_t g, uint8_t b, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_BOOL_TO_IO(SDL_SetSurfaceColorMod(s, r, g, b));
}

/* Sdl.Surface.getColorMod : IO Color -- C: SDL_GetSurfaceColorMod
 * (the returned Color's alpha is a placeholder 255). */
LEAN_EXPORT lean_obj_res lean_sdl_get_surface_color_mod(b_lean_obj_arg surf, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    Uint8 r = 0, g = 0, b = 0;
    if (!SDL_GetSurfaceColorMod(s, &r, &g, &b)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_color(r, g, b, 255));
}

/* Sdl.Surface.setAlphaMod (a : UInt8) -- C: SDL_SetSurfaceAlphaMod */
LEAN_EXPORT lean_obj_res lean_sdl_set_surface_alpha_mod(
        b_lean_obj_arg surf, uint8_t a, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_BOOL_TO_IO(SDL_SetSurfaceAlphaMod(s, a));
}

/* Sdl.Surface.getAlphaMod : IO UInt8 -- C: SDL_GetSurfaceAlphaMod */
LEAN_EXPORT lean_obj_res lean_sdl_get_surface_alpha_mod(b_lean_obj_arg surf, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    Uint8 a = 0;
    if (!SDL_GetSurfaceAlphaMod(s, &a)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box(a));
}

/* Sdl.Surface.setBlendModeRaw (m : UInt32) -- C: SDL_SetSurfaceBlendMode */
LEAN_EXPORT lean_obj_res lean_sdl_set_surface_blend_mode(
        b_lean_obj_arg surf, uint32_t m, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_BOOL_TO_IO(SDL_SetSurfaceBlendMode(s, (SDL_BlendMode)m));
}

/* Sdl.Surface.getBlendModeRaw : IO UInt32 -- C: SDL_GetSurfaceBlendMode */
LEAN_EXPORT lean_obj_res lean_sdl_get_surface_blend_mode(b_lean_obj_arg surf, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_BlendMode m = SDL_BLENDMODE_NONE;
    if (!SDL_GetSurfaceBlendMode(s, &m)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)m));
}

/* ---------- Clip rect ---------- */

/* Sdl.Surface.setClipRectRaw (hasRect ...) : IO Bool
 * -- C: SDL_SetSurfaceClipRect. The bool return is "intersects the surface",
 * NOT an error, so never throw. none (hasRect=0) resets to the full surface. */
LEAN_EXPORT lean_obj_res lean_sdl_set_surface_clip_rect(
        b_lean_obj_arg surf, uint8_t has_rect,
        int32_t x, int32_t y, int32_t rw, int32_t rh, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_RECT_ARG(rect, has_rect, x, y, rw, rh);
    bool intersects = SDL_SetSurfaceClipRect(s, rect);
    return lean_io_result_mk_ok(lean_box(intersects));
}

/* Sdl.Surface.getClipRect : IO Rect -- C: SDL_GetSurfaceClipRect (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_surface_clip_rect(b_lean_obj_arg surf, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_Rect r;
    if (!SDL_GetSurfaceClipRect(s, &r)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_rect(r.x, r.y, r.w, r.h));
}

/* ---------- Transforms ---------- */

/* Sdl.Surface.flipRaw (mode : UInt32) -- C: SDL_FlipSurface */
LEAN_EXPORT lean_obj_res lean_sdl_flip_surface(
        b_lean_obj_arg surf, uint32_t mode, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_BOOL_TO_IO(SDL_FlipSurface(s, (SDL_FlipMode)mode));
}

/* Sdl.Surface.rotate (angle : Float32) : IO Surface -- C: SDL_RotateSurface */
LEAN_EXPORT lean_obj_res lean_sdl_rotate_surface(
        b_lean_obj_arg surf, float angle, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    return lean_sdl_wrap_surface_or_throw(SDL_RotateSurface(s, angle));
}

/* Sdl.Surface.duplicate : IO Surface -- C: SDL_DuplicateSurface */
LEAN_EXPORT lean_obj_res lean_sdl_duplicate_surface(b_lean_obj_arg surf, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    return lean_sdl_wrap_surface_or_throw(SDL_DuplicateSurface(s));
}

/* Sdl.Surface.scaleRaw (width height : Int32) (mode : UInt32) : IO Surface
 * -- C: SDL_ScaleSurface */
LEAN_EXPORT lean_obj_res lean_sdl_scale_surface(
        b_lean_obj_arg surf, int32_t width, int32_t height, uint32_t mode, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    return lean_sdl_wrap_surface_or_throw(
        SDL_ScaleSurface(s, (int)width, (int)height, (SDL_ScaleMode)mode));
}

/* Sdl.Surface.convertRaw (format : UInt32) : IO Surface -- C: SDL_ConvertSurface */
LEAN_EXPORT lean_obj_res lean_sdl_convert_surface(
        b_lean_obj_arg surf, uint32_t format, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    return lean_sdl_wrap_surface_or_throw(
        SDL_ConvertSurface(s, (SDL_PixelFormat)format));
}

/* Sdl.Surface.convertAndColorspaceRaw (format) (palette) (colorspace) (props)
 * : IO Surface -- C: SDL_ConvertSurfaceAndColorspace (props none -> 0). */
LEAN_EXPORT lean_obj_res lean_sdl_convert_surface_and_colorspace(
        b_lean_obj_arg surf, uint32_t format, b_lean_obj_arg palette,
        uint32_t colorspace, b_lean_obj_arg props, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_OPT_PALETTE_OR_THROW(pal, palette);
    SDL_OPT_PROPS_OR_THROW(pid, props);
    return lean_sdl_wrap_surface_or_throw(SDL_ConvertSurfaceAndColorspace(
        s, (SDL_PixelFormat)format, pal, (SDL_Colorspace)colorspace, pid));
}

/* Sdl.Surface.premultiplyAlpha (linear : Bool) -- C: SDL_PremultiplySurfaceAlpha */
LEAN_EXPORT lean_obj_res lean_sdl_premultiply_surface_alpha(
        b_lean_obj_arg surf, uint8_t linear, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_BOOL_TO_IO(SDL_PremultiplySurfaceAlpha(s, linear != 0));
}

/* ---------- Clear / fill ---------- */

/* Sdl.Surface.clear (r g b a : Float32) -- C: SDL_ClearSurface (ignores clip). */
LEAN_EXPORT lean_obj_res lean_sdl_clear_surface(
        b_lean_obj_arg surf, float r, float g, float b, float a, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_BOOL_TO_IO(SDL_ClearSurface(s, r, g, b, a));
}

/* Sdl.Surface.fillRectRaw (hasRect ...) (color : UInt32)
 * -- C: SDL_FillSurfaceRect (none fills the whole surface). fillRects loops
 * this in Lean (semantically identical to SDL_FillSurfaceRects). */
LEAN_EXPORT lean_obj_res lean_sdl_fill_surface_rect(
        b_lean_obj_arg surf, uint8_t has_rect,
        int32_t x, int32_t y, int32_t rw, int32_t rh, uint32_t color, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_RECT_ARG(rect, has_rect, x, y, rw, rh);
    SDL_BOOL_TO_IO(SDL_FillSurfaceRect(s, rect, color));
}

/* ---------- Blits (all flattened src/dst Option Rect pairs) ---------- */

/* Sdl.Surface.blitRaw -- C: SDL_BlitSurface (clipped). */
LEAN_EXPORT lean_obj_res lean_sdl_blit_surface(
        b_lean_obj_arg src, uint8_t has_src, int32_t sx, int32_t sy, int32_t sw, int32_t sh,
        b_lean_obj_arg dst, uint8_t has_dst, int32_t dx, int32_t dy, int32_t dw, int32_t dh,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, src);
    SDL_GET_OR_THROW(SDL_Surface, d, dst);
    SDL_RECT_ARG(srcrect, has_src, sx, sy, sw, sh);
    SDL_RECT_ARG(dstrect, has_dst, dx, dy, dw, dh);
    SDL_BOOL_TO_IO(SDL_BlitSurface(s, srcrect, d, dstrect));
}

/* Sdl.Surface.blitUncheckedRaw -- C: SDL_BlitSurfaceUnchecked (no clipping;
 * both rects must be provided). */
LEAN_EXPORT lean_obj_res lean_sdl_blit_surface_unchecked(
        b_lean_obj_arg src, uint8_t has_src, int32_t sx, int32_t sy, int32_t sw, int32_t sh,
        b_lean_obj_arg dst, uint8_t has_dst, int32_t dx, int32_t dy, int32_t dw, int32_t dh,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, src);
    SDL_GET_OR_THROW(SDL_Surface, d, dst);
    SDL_RECT_ARG(srcrect, has_src, sx, sy, sw, sh);
    SDL_RECT_ARG(dstrect, has_dst, dx, dy, dw, dh);
    SDL_BOOL_TO_IO(SDL_BlitSurfaceUnchecked(s, srcrect, d, dstrect));
}

/* Sdl.Surface.blitScaledRaw (mode : UInt32) -- C: SDL_BlitSurfaceScaled. */
LEAN_EXPORT lean_obj_res lean_sdl_blit_surface_scaled(
        b_lean_obj_arg src, uint8_t has_src, int32_t sx, int32_t sy, int32_t sw, int32_t sh,
        b_lean_obj_arg dst, uint8_t has_dst, int32_t dx, int32_t dy, int32_t dw, int32_t dh,
        uint32_t mode, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, src);
    SDL_GET_OR_THROW(SDL_Surface, d, dst);
    SDL_RECT_ARG(srcrect, has_src, sx, sy, sw, sh);
    SDL_RECT_ARG(dstrect, has_dst, dx, dy, dw, dh);
    SDL_BOOL_TO_IO(SDL_BlitSurfaceScaled(s, srcrect, d, dstrect, (SDL_ScaleMode)mode));
}

/* Sdl.Surface.blitUncheckedScaledRaw (mode : UInt32)
 * -- C: SDL_BlitSurfaceUncheckedScaled (both rects must be provided). */
LEAN_EXPORT lean_obj_res lean_sdl_blit_surface_unchecked_scaled(
        b_lean_obj_arg src, uint8_t has_src, int32_t sx, int32_t sy, int32_t sw, int32_t sh,
        b_lean_obj_arg dst, uint8_t has_dst, int32_t dx, int32_t dy, int32_t dw, int32_t dh,
        uint32_t mode, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, src);
    SDL_GET_OR_THROW(SDL_Surface, d, dst);
    SDL_RECT_ARG(srcrect, has_src, sx, sy, sw, sh);
    SDL_RECT_ARG(dstrect, has_dst, dx, dy, dw, dh);
    SDL_BOOL_TO_IO(SDL_BlitSurfaceUncheckedScaled(s, srcrect, d, dstrect, (SDL_ScaleMode)mode));
}

/* Sdl.Surface.stretchRaw (mode : UInt32) -- C: SDL_StretchSurface. */
LEAN_EXPORT lean_obj_res lean_sdl_stretch_surface(
        b_lean_obj_arg src, uint8_t has_src, int32_t sx, int32_t sy, int32_t sw, int32_t sh,
        b_lean_obj_arg dst, uint8_t has_dst, int32_t dx, int32_t dy, int32_t dw, int32_t dh,
        uint32_t mode, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, src);
    SDL_GET_OR_THROW(SDL_Surface, d, dst);
    SDL_RECT_ARG(srcrect, has_src, sx, sy, sw, sh);
    SDL_RECT_ARG(dstrect, has_dst, dx, dy, dw, dh);
    SDL_BOOL_TO_IO(SDL_StretchSurface(s, srcrect, d, dstrect, (SDL_ScaleMode)mode));
}

/* Sdl.Surface.blitTiledRaw -- C: SDL_BlitSurfaceTiled. */
LEAN_EXPORT lean_obj_res lean_sdl_blit_surface_tiled(
        b_lean_obj_arg src, uint8_t has_src, int32_t sx, int32_t sy, int32_t sw, int32_t sh,
        b_lean_obj_arg dst, uint8_t has_dst, int32_t dx, int32_t dy, int32_t dw, int32_t dh,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, src);
    SDL_GET_OR_THROW(SDL_Surface, d, dst);
    SDL_RECT_ARG(srcrect, has_src, sx, sy, sw, sh);
    SDL_RECT_ARG(dstrect, has_dst, dx, dy, dw, dh);
    SDL_BOOL_TO_IO(SDL_BlitSurfaceTiled(s, srcrect, d, dstrect));
}

/* Sdl.Surface.blitTiledWithScaleRaw (scale : Float32) (mode : UInt32)
 * -- C: SDL_BlitSurfaceTiledWithScale. */
LEAN_EXPORT lean_obj_res lean_sdl_blit_surface_tiled_with_scale(
        b_lean_obj_arg src, uint8_t has_src, int32_t sx, int32_t sy, int32_t sw, int32_t sh,
        b_lean_obj_arg dst, uint8_t has_dst, int32_t dx, int32_t dy, int32_t dw, int32_t dh,
        float scale, uint32_t mode, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, src);
    SDL_GET_OR_THROW(SDL_Surface, d, dst);
    SDL_RECT_ARG(srcrect, has_src, sx, sy, sw, sh);
    SDL_RECT_ARG(dstrect, has_dst, dx, dy, dw, dh);
    SDL_BOOL_TO_IO(SDL_BlitSurfaceTiledWithScale(
        s, srcrect, scale, (SDL_ScaleMode)mode, d, dstrect));
}

/* Sdl.Surface.blit9GridRaw (left right top bottom : Int32) (scale : Float32)
 * (mode : UInt32) -- C: SDL_BlitSurface9Grid. */
LEAN_EXPORT lean_obj_res lean_sdl_blit_surface_9grid(
        b_lean_obj_arg src, uint8_t has_src, int32_t sx, int32_t sy, int32_t sw, int32_t sh,
        b_lean_obj_arg dst, uint8_t has_dst, int32_t dx, int32_t dy, int32_t dw, int32_t dh,
        int32_t left_width, int32_t right_width, int32_t top_height, int32_t bottom_height,
        float scale, uint32_t mode, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, src);
    SDL_GET_OR_THROW(SDL_Surface, d, dst);
    SDL_RECT_ARG(srcrect, has_src, sx, sy, sw, sh);
    SDL_RECT_ARG(dstrect, has_dst, dx, dy, dw, dh);
    SDL_BOOL_TO_IO(SDL_BlitSurface9Grid(
        s, srcrect, (int)left_width, (int)right_width, (int)top_height, (int)bottom_height,
        scale, (SDL_ScaleMode)mode, d, dstrect));
}

/* ---------- Map / read / write pixel ---------- */

/* Sdl.Surface.mapRGB (r g b : UInt8) : IO UInt32 -- C: SDL_MapSurfaceRGB. */
LEAN_EXPORT lean_obj_res lean_sdl_map_surface_rgb(
        b_lean_obj_arg surf, uint8_t r, uint8_t g, uint8_t b, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    return lean_io_result_mk_ok(lean_box_uint32(SDL_MapSurfaceRGB(s, r, g, b)));
}

/* Sdl.Surface.mapRGBA (r g b a : UInt8) : IO UInt32 -- C: SDL_MapSurfaceRGBA. */
LEAN_EXPORT lean_obj_res lean_sdl_map_surface_rgba(
        b_lean_obj_arg surf, uint8_t r, uint8_t g, uint8_t b, uint8_t a, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    return lean_io_result_mk_ok(lean_box_uint32(SDL_MapSurfaceRGBA(s, r, g, b, a)));
}

/* Sdl.Surface.readPixel (x y : Int32) : IO Color -- C: SDL_ReadSurfacePixel. */
LEAN_EXPORT lean_obj_res lean_sdl_read_surface_pixel(
        b_lean_obj_arg surf, int32_t x, int32_t y, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    Uint8 r = 0, g = 0, b = 0, a = 0;
    if (!SDL_ReadSurfacePixel(s, (int)x, (int)y, &r, &g, &b, &a)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_color(r, g, b, a));
}

/* Sdl.Surface.readPixelFloat (x y : Int32) : IO FColor
 * -- C: SDL_ReadSurfacePixelFloat. */
LEAN_EXPORT lean_obj_res lean_sdl_read_surface_pixel_float(
        b_lean_obj_arg surf, int32_t x, int32_t y, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    float r = 0, g = 0, b = 0, a = 0;
    if (!SDL_ReadSurfacePixelFloat(s, (int)x, (int)y, &r, &g, &b, &a)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_fcolor(r, g, b, a));
}

/* Sdl.Surface.writePixelRaw (x y : Int32) (r g b a : UInt8)
 * -- C: SDL_WriteSurfacePixel. */
LEAN_EXPORT lean_obj_res lean_sdl_write_surface_pixel(
        b_lean_obj_arg surf, int32_t x, int32_t y,
        uint8_t r, uint8_t g, uint8_t b, uint8_t a, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_BOOL_TO_IO(SDL_WriteSurfacePixel(s, (int)x, (int)y, r, g, b, a));
}

/* Sdl.Surface.writePixelFloatRaw (x y : Int32) (r g b a : Float32)
 * -- C: SDL_WriteSurfacePixelFloat. */
LEAN_EXPORT lean_obj_res lean_sdl_write_surface_pixel_float(
        b_lean_obj_arg surf, int32_t x, int32_t y,
        float r, float g, float b, float a, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_BOOL_TO_IO(SDL_WriteSurfacePixelFloat(s, (int)x, (int)y, r, g, b, a));
}

/* ---------- Save ---------- */

/* Sdl.Surface.saveBMP (file : String) -- C: SDL_SaveBMP. */
LEAN_EXPORT lean_obj_res lean_sdl_save_bmp(
        b_lean_obj_arg surf, b_lean_obj_arg file, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_BOOL_TO_IO(SDL_SaveBMP(s, lean_string_cstr(file)));
}

/* Sdl.Surface.savePNG (file : String) -- C: SDL_SavePNG. */
LEAN_EXPORT lean_obj_res lean_sdl_save_png(
        b_lean_obj_arg surf, b_lean_obj_arg file, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_BOOL_TO_IO(SDL_SavePNG(s, lean_string_cstr(file)));
}

/* Sdl.Surface.saveBMPIO (dst : @& IOStream)
 * -- C: SDL_SaveBMP_IO (closeio=false). */
LEAN_EXPORT lean_obj_res lean_sdl_save_bmp_io(
        b_lean_obj_arg surf, b_lean_obj_arg dst, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_GET_OR_THROW(SDL_IOStream, io, dst);
    SDL_BOOL_TO_IO(SDL_SaveBMP_IO(s, io, false));
}

/* Sdl.Surface.savePNGIO (dst : @& IOStream)
 * -- C: SDL_SavePNG_IO (closeio=false). */
LEAN_EXPORT lean_obj_res lean_sdl_save_png_io(
        b_lean_obj_arg surf, b_lean_obj_arg dst, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Surface, s, surf);
    SDL_GET_OR_THROW(SDL_IOStream, io, dst);
    SDL_BOOL_TO_IO(SDL_SavePNG_IO(s, io, false));
}
