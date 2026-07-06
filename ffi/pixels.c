/* Shims for Sdl/Pixels.lean (SDL_pixels.h).
 *
 * Palette archetypes (docs/DESIGN.md "Ownership"):
 *   - lean_sdl_palette          : owned root (SDL_CreatePalette) -> finalizer
 *     destroys; manual Palette.destroy allowed (leaf type, no children).
 *   - lean_sdl_palette_borrowed : borrowed (palettes owned by another handle,
 *     e.g. a surface's palette; wrapped by other modules via ffi/classes.h)
 *     -> never destroyed, destroy shim throws.
 *
 * Structure results (PixelFormatDetails, PixelFormatMasks, Color) are built by
 * the @[export]ed Lean makers, so C never lays out a Lean structure; likewise
 * Palette.setColors receives a packed ByteArray, not an Array Color. */
#include "util.h"
#include "classes.h"
#include <stddef.h>

/* Palette.setColors reinterprets a packed r,g,b,a ByteArray as SDL_Color[]. */
_Static_assert(sizeof(SDL_Color) == 4, "SDL_Color packs to 4 bytes");
_Static_assert(offsetof(SDL_Color, r) == 0, "SDL_Color.r offset");
_Static_assert(offsetof(SDL_Color, g) == 1, "SDL_Color.g offset");
_Static_assert(offsetof(SDL_Color, b) == 2, "SDL_Color.b offset");
_Static_assert(offsetof(SDL_Color, a) == 3, "SDL_Color.a offset");

/* Owned: destroy on finalize. `self` is the holder's void* ptr. */
SDL_DEFINE_CLASS(lean_sdl_palette,
    SDL_DestroyPalette((SDL_Palette *)self))
/* Borrowed (e.g. a surface's palette): never destroyed. */
SDL_DEFINE_BORROWED_CLASS(lean_sdl_palette_borrowed)

/* Register both classes. Called from Sdl/Pixels.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_pixels_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_palette_class_init();
    lean_sdl_palette_borrowed_class_init();
    return lean_sdl_unit_ok();
}

/* Lean-owned makers (see Sdl/Pixels.lean). */
extern lean_object *lean_sdl_mk_pixel_format_details(
    uint32_t format, uint8_t bits_per_pixel, uint8_t bytes_per_pixel,
    uint32_t rmask, uint32_t gmask, uint32_t bmask, uint32_t amask,
    uint8_t rbits, uint8_t gbits, uint8_t bbits, uint8_t abits,
    uint8_t rshift, uint8_t gshift, uint8_t bshift, uint8_t ashift);
extern lean_object *lean_sdl_mk_pixel_format_masks(
    int32_t bpp, uint32_t rmask, uint32_t gmask, uint32_t bmask, uint32_t amask);
extern lean_object *lean_sdl_mk_color(uint8_t r, uint8_t g, uint8_t b, uint8_t a);

/* Extract a borrowed `@& Option Palette` argument: `none` yields NULL (SDL
 * accepts a NULL palette); `some p` yields the SDL_Palette* or flags
 * `*destroyed` when the handle was manually destroyed. */
static SDL_Palette *lean_sdl_opt_palette(b_lean_obj_arg opt, bool *destroyed) {
    *destroyed = false;
    if (lean_is_scalar(opt)) return NULL; /* none = lean_box(0) */
    sdl_holder *h = lean_sdl_holder_of(lean_ctor_get(opt, 0));
    if (!h->ptr) { *destroyed = true; return NULL; }
    return (SDL_Palette *)h->ptr;
}

/* Option-Palette variant of SDL_GET_OR_THROW: NULL is fine (none), but a
 * destroyed handle inside `some` is an IO error. */
#define SDL_OPT_PALETTE_OR_THROW(var, opt)                                     \
    SDL_Palette *var;                                                          \
    do {                                                                       \
        bool _destroyed;                                                       \
        var = lean_sdl_opt_palette(opt, &_destroyed);                          \
        if (_destroyed)                                                        \
            return lean_sdl_throw_msg("SDL: handle used after destroy/release"); \
    } while (0)

/* Sdl.getPixelFormatNameRaw (format : UInt32) : String
 * -- C: SDL_GetPixelFormatName (pure: static string, never fails; junk input
 * yields "SDL_PIXELFORMAT_UNKNOWN"). Copied with lean_mk_string. */
LEAN_EXPORT lean_object *lean_sdl_get_pixel_format_name(uint32_t format) {
    SDL_SHIM_PROLOGUE();
    return lean_sdl_mk_string(SDL_GetPixelFormatName((SDL_PixelFormat)format));
}

/* Sdl.getMasksForPixelFormatRaw (format : UInt32) : IO PixelFormatMasks
 * -- C: SDL_GetMasksForPixelFormat */
LEAN_EXPORT lean_obj_res lean_sdl_get_masks_for_pixel_format(
        uint32_t format, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int bpp = 0;
    Uint32 rmask = 0, gmask = 0, bmask = 0, amask = 0;
    if (!SDL_GetMasksForPixelFormat((SDL_PixelFormat)format,
                                    &bpp, &rmask, &gmask, &bmask, &amask))
        return lean_sdl_throw();
    return lean_io_result_mk_ok(
        lean_sdl_mk_pixel_format_masks((int32_t)bpp, rmask, gmask, bmask, amask));
}

/* Sdl.getPixelFormatForMasksRaw (bpp : Int32) (4 UInt32 masks) : IO UInt32
 * -- C: SDL_GetPixelFormatForMasks (no match is SDL_PIXELFORMAT_UNKNOWN, not
 * an error). */
LEAN_EXPORT lean_obj_res lean_sdl_get_pixel_format_for_masks(
        int32_t bpp, uint32_t rmask, uint32_t gmask, uint32_t bmask, uint32_t amask,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PixelFormat f = SDL_GetPixelFormatForMasks((int)bpp, rmask, gmask, bmask, amask);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)f));
}

/* Sdl.getPixelFormatDetailsRaw (format : UInt32) : IO PixelFormatDetails
 * -- C: SDL_GetPixelFormatDetails (the struct is static/cached; fields are
 * copied out through the maker). */
LEAN_EXPORT lean_obj_res lean_sdl_get_pixel_format_details(
        uint32_t format, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    const SDL_PixelFormatDetails *d = SDL_GetPixelFormatDetails((SDL_PixelFormat)format);
    if (!d) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_pixel_format_details(
        (uint32_t)d->format, d->bits_per_pixel, d->bytes_per_pixel,
        d->Rmask, d->Gmask, d->Bmask, d->Amask,
        d->Rbits, d->Gbits, d->Bbits, d->Abits,
        d->Rshift, d->Gshift, d->Bshift, d->Ashift));
}

/* Sdl.createPalette (ncolors : Int32) : IO Palette -- C: SDL_CreatePalette */
LEAN_EXPORT lean_obj_res lean_sdl_create_palette(int32_t ncolors, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Palette *p = SDL_CreatePalette((int)ncolors);
    if (!p) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_palette_class, p, NULL));
}

/* Sdl.Palette.ncolors : IO Int32 -- reads SDL_Palette.ncolors */
LEAN_EXPORT lean_obj_res lean_sdl_palette_ncolors(
        b_lean_obj_arg palette, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Palette, p, palette);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)p->ncolors));
}

/* Sdl.Palette.setColorsRaw (palette : @& Palette) (colors : @& ByteArray)
 * (firstColor : Int32) : IO Unit -- C: SDL_SetPaletteColors.
 * `colors` is packed r,g,b,a per entry (asserted == SDL_Color layout above);
 * ncolors is size/4. */
LEAN_EXPORT lean_obj_res lean_sdl_set_palette_colors(
        b_lean_obj_arg palette, b_lean_obj_arg colors, int32_t first_color,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Palette, p, palette);
    size_t n = lean_sarray_size(colors) / 4;
    SDL_BOOL_TO_IO(SDL_SetPaletteColors(
        p, (const SDL_Color *)lean_sarray_cptr((lean_object *)colors),
        (int)first_color, (int)n));
}

/* Sdl.Palette.getColors : IO (Array Color) -- copies SDL_Palette.colors out
 * through the lean_sdl_mk_color maker. */
LEAN_EXPORT lean_obj_res lean_sdl_get_palette_colors(
        b_lean_obj_arg palette, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Palette, p, palette);
    size_t n = p->ncolors > 0 ? (size_t)p->ncolors : 0;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++) {
        SDL_Color c = p->colors[i];
        lean_array_set_core(arr, i, lean_sdl_mk_color(c.r, c.g, c.b, c.a));
    }
    return lean_io_result_mk_ok(arr);
}

/* Sdl.Palette.destroy -- C: SDL_DestroyPalette (manual; leaf type).
 * Throws on the borrowed class; otherwise destroys and NULLs the ptr so
 * later use is an IO error. */
LEAN_EXPORT lean_obj_res lean_sdl_destroy_palette(
        b_lean_obj_arg palette, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(palette);
    if (!h->ptr)
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    if (lean_get_external_class(palette) == lean_sdl_palette_borrowed_class)
        return lean_sdl_throw_msg("SDL: cannot destroy borrowed Palette");
    SDL_DestroyPalette((SDL_Palette *)h->ptr);
    h->ptr = NULL;
    return lean_sdl_unit_ok();
}

/* Sdl.mapRGBRaw (format : UInt32) (palette : @& Option Palette) (r g b) :
 * IO UInt32 -- C: SDL_MapRGB (SDL_GetPixelFormatDetails is called
 * internally; NULL details -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_map_rgb(
        uint32_t format, b_lean_obj_arg palette,
        uint8_t r, uint8_t g, uint8_t b, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_OPT_PALETTE_OR_THROW(pal, palette);
    const SDL_PixelFormatDetails *d = SDL_GetPixelFormatDetails((SDL_PixelFormat)format);
    if (!d) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32(SDL_MapRGB(d, pal, r, g, b)));
}

/* Sdl.mapRGBARaw (format : UInt32) (palette : @& Option Palette) (r g b a) :
 * IO UInt32 -- C: SDL_MapRGBA (details looked up internally). */
LEAN_EXPORT lean_obj_res lean_sdl_map_rgba(
        uint32_t format, b_lean_obj_arg palette,
        uint8_t r, uint8_t g, uint8_t b, uint8_t a, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_OPT_PALETTE_OR_THROW(pal, palette);
    const SDL_PixelFormatDetails *d = SDL_GetPixelFormatDetails((SDL_PixelFormat)format);
    if (!d) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32(SDL_MapRGBA(d, pal, r, g, b, a)));
}

/* Sdl.getRGBRaw (pixel : UInt32) (format : UInt32)
 * (palette : @& Option Palette) : IO Color -- C: SDL_GetRGB (details looked
 * up internally; alpha in the returned Color is always 255). */
LEAN_EXPORT lean_obj_res lean_sdl_get_rgb(
        uint32_t pixel, uint32_t format, b_lean_obj_arg palette, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_OPT_PALETTE_OR_THROW(pal, palette);
    const SDL_PixelFormatDetails *d = SDL_GetPixelFormatDetails((SDL_PixelFormat)format);
    if (!d) return lean_sdl_throw();
    Uint8 r = 0, g = 0, b = 0;
    SDL_GetRGB(pixel, d, pal, &r, &g, &b);
    return lean_io_result_mk_ok(lean_sdl_mk_color(r, g, b, 255));
}

/* Sdl.getRGBARaw (pixel : UInt32) (format : UInt32)
 * (palette : @& Option Palette) : IO Color -- C: SDL_GetRGBA (details looked
 * up internally). */
LEAN_EXPORT lean_obj_res lean_sdl_get_rgba(
        uint32_t pixel, uint32_t format, b_lean_obj_arg palette, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_OPT_PALETTE_OR_THROW(pal, palette);
    const SDL_PixelFormatDetails *d = SDL_GetPixelFormatDetails((SDL_PixelFormat)format);
    if (!d) return lean_sdl_throw();
    Uint8 r = 0, g = 0, b = 0, a = 0;
    SDL_GetRGBA(pixel, d, pal, &r, &g, &b, &a);
    return lean_io_result_mk_ok(lean_sdl_mk_color(r, g, b, a));
}
