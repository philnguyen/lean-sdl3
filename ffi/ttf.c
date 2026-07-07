/* Shims for Sdl/Ttf.lean (SDL3_ttf/SDL_ttf.h) -- the font half of SDL_ttf.
 *
 * One owned external class over the Lean `Ttf.Font` type:
 *   - lean_sdl_ttf_font : finalizer runs TTF_CloseFont(ptr). FINALIZER-ONLY (no
 *     manual close): Texts and fallback configurations reference fonts, same
 *     rationale as Window/Renderer. The holder owner is NULL for file-opened
 *     fonts, an inc'd IOStream external for openFontIO (keeps a const-mem
 *     stream and its backing ByteArray alive), or an inc'd source Font external
 *     for copyFont (the copy shares the original's font data source).
 *
 * Strings cross with an explicit byte length (lean_string_size - 1), never
 * NUL-scanned. Colors arrive flattened as four uint8_t scalars and are rebuilt
 * into an SDL_Color here. Rendered/queried surfaces are wrapped owned with the
 * shared surface class (classes.h). Multi-value results are built by @[export]ed
 * Lean makers (defined in Sdl/Ttf.lean), so C never lays out a Lean tuple. */
#include <SDL3_ttf/SDL_ttf.h>
#include "util.h"
#include "classes.h"

/* Owned: TTF_CloseFont on finalize. */
SDL_DEFINE_CLASS(lean_sdl_ttf_font, TTF_CloseFont((TTF_Font *)self))

/* Register the font class. Called from Sdl/Ttf.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_ttf_font_class_init();
    return lean_sdl_unit_ok();
}

/* Lean-side makers (Sdl/Ttf.lean). */
extern lean_object *lean_sdl_ttf_mk_glyph_metrics(
    int32_t minx, int32_t maxx, int32_t miny, int32_t maxy, int32_t advance);
extern lean_object *lean_sdl_ttf_mk_int32_triple(int32_t a, int32_t b, int32_t c);
extern lean_object *lean_sdl_ttf_mk_int32_pair(int32_t a, int32_t b);
extern lean_object *lean_sdl_ttf_mk_measure(int32_t width, size_t length);
extern lean_object *lean_sdl_ttf_mk_glyph_image(lean_object *surf, uint32_t raw_type);

/* Byte length of a Lean string, excluding the trailing NUL. */
#define LEAN_STR_LEN(s) (lean_string_size(s) - 1)

/* Build an SDL_Color from four flattened bytes. */
#define TTF_COLOR(name, r, g, b, a) SDL_Color name = { (r), (g), (b), (a) }

/* Wrap an owned (font-produced) SDL_Surface* or throw. Surfaces returned from
 * the render/glyph-image calls are freestanding (owner = NULL). */
static lean_obj_res lean_sdl_ttf_wrap_surface_or_throw(SDL_Surface *s) {
    if (!s) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_surface_class, s, NULL));
}

/* Wrap a font-produced surface together with its TTF_ImageType (paired by a
 * Lean maker). */
static lean_obj_res lean_sdl_ttf_wrap_glyph_image(SDL_Surface *s, TTF_ImageType t) {
    if (!s) return lean_sdl_throw();
    lean_object *surf = lean_sdl_wrap(lean_sdl_surface_class, s, NULL);
    return lean_io_result_mk_ok(lean_sdl_ttf_mk_glyph_image(surf, (uint32_t)t));
}

/* ---------- Init / version ---------- */

/* Sdl.Ttf.version : IO Int32 -- C: TTF_Version. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_version(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)TTF_Version()));
}

/* Sdl.Ttf.getFreeTypeVersion : IO (Int32 x Int32 x Int32)
 * -- C: TTF_GetFreeTypeVersion. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_freetype_version(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int major = 0, minor = 0, patch = 0;
    TTF_GetFreeTypeVersion(&major, &minor, &patch);
    return lean_io_result_mk_ok(
        lean_sdl_ttf_mk_int32_triple((int32_t)major, (int32_t)minor, (int32_t)patch));
}

/* Sdl.Ttf.getHarfBuzzVersion : IO (Int32 x Int32 x Int32)
 * -- C: TTF_GetHarfBuzzVersion. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_harfbuzz_version(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int major = 0, minor = 0, patch = 0;
    TTF_GetHarfBuzzVersion(&major, &minor, &patch);
    return lean_io_result_mk_ok(
        lean_sdl_ttf_mk_int32_triple((int32_t)major, (int32_t)minor, (int32_t)patch));
}

/* Sdl.Ttf.init : IO Unit -- C: TTF_Init (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_init(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(TTF_Init());
}

/* Sdl.Ttf.quit : IO Unit -- C: TTF_Quit. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_quit(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    TTF_Quit();
    return lean_sdl_unit_ok();
}

/* Sdl.Ttf.wasInit : IO Int32 -- C: TTF_WasInit (the init refcount). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_was_init(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)TTF_WasInit()));
}

/* ---------- Opening fonts ---------- */

/* Sdl.Ttf.openFont (file : String) (ptsize : Float32) : IO Font
 * -- C: TTF_OpenFont (owner = NULL). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_open_font(
        b_lean_obj_arg file, float ptsize, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    TTF_Font *f = TTF_OpenFont(lean_string_cstr(file), ptsize);
    if (!f) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap_ttf_font(f, NULL));
}

/* Sdl.Ttf.openFontIO (src : @& IOStream) (ptsize : Float32) : IO Font
 * -- C: TTF_OpenFontIO (closeio = false; owner = inc'd IOStream external, so
 * the stream and its backing buffer outlive the font). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_open_font_io(
        b_lean_obj_arg src, float ptsize, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_IOStream, io, src);
    TTF_Font *f = TTF_OpenFontIO(io, false, ptsize);
    if (!f) return lean_sdl_throw();
    lean_inc(src);
    return lean_io_result_mk_ok(lean_sdl_wrap_ttf_font(f, (lean_object *)src));
}

/* Sdl.Ttf.openFontWithProperties (props : @& Properties) : IO Font
 * -- C: TTF_OpenFontWithProperties (owner = NULL). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_open_font_with_properties(
        b_lean_obj_arg props, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(props);
    if (!h->ptr) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    TTF_Font *f = TTF_OpenFontWithProperties((SDL_PropertiesID)(uintptr_t)h->ptr);
    if (!f) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap_ttf_font(f, NULL));
}

/* Sdl.Ttf.Font.copy (self : @& Font) : IO Font -- C: TTF_CopyFont. The copy
 * shares the original's font data source, so it owns an inc'd reference to the
 * original font external (RC keeps the source alive for the copy's life). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_copy_font(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_Font *copy = TTF_CopyFont(f);
    if (!copy) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_ttf_font(copy, (lean_object *)self));
}

/* ---------- Script tags ---------- */

/* Sdl.Ttf.stringToTagRaw (s : @& String) : UInt32 -- C: TTF_StringToTag. */
LEAN_EXPORT uint32_t lean_sdl_ttf_string_to_tag(b_lean_obj_arg s) {
    SDL_SHIM_PROLOGUE();
    return (uint32_t)TTF_StringToTag(lean_string_cstr(s));
}

/* Sdl.Ttf.tagToStringRaw (tag : UInt32) : String -- C: TTF_TagToString. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_tag_to_string(uint32_t tag) {
    SDL_SHIM_PROLOGUE();
    char buf[8];
    SDL_memset(buf, 0, sizeof(buf));
    TTF_TagToString((Uint32)tag, buf, sizeof(buf));
    return lean_mk_string(buf);
}

/* Sdl.Ttf.getGlyphScriptRaw (ch : UInt32) : IO UInt32
 * -- C: TTF_GetGlyphScript (0 + error -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_glyph_script(uint32_t ch, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    Uint32 tag = TTF_GetGlyphScript((Uint32)ch);
    if (tag == 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)tag));
}

/* ---------- Font attributes ---------- */

/* Sdl.Ttf.Font.properties (self : @& Font) : IO Properties
 * -- C: TTF_GetFontProperties. Borrowed Properties, owner = inc'd font. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_font_properties(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    SDL_PropertiesID id = TTF_GetFontProperties(f);
    if (id == 0) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_properties_borrowed(id, (lean_object *)self));
}

/* Sdl.Ttf.Font.generation (self : @& Font) : IO UInt32
 * -- C: TTF_GetFontGeneration (0 + error -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_font_generation(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    Uint32 gen = TTF_GetFontGeneration(f);
    if (gen == 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)gen));
}

/* Sdl.Ttf.Font.addFallbackFont (font fallback : @& Font) : IO Unit
 * -- C: TTF_AddFallbackFont. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_add_fallback_font(
        b_lean_obj_arg font, b_lean_obj_arg fallback, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, font);
    SDL_GET_OR_THROW(TTF_Font, fb, fallback);
    SDL_BOOL_TO_IO(TTF_AddFallbackFont(f, fb));
}

/* Sdl.Ttf.Font.removeFallbackFont (font fallback : @& Font) : IO Unit
 * -- C: TTF_RemoveFallbackFont. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_remove_fallback_font(
        b_lean_obj_arg font, b_lean_obj_arg fallback, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, font);
    SDL_GET_OR_THROW(TTF_Font, fb, fallback);
    TTF_RemoveFallbackFont(f, fb);
    return lean_sdl_unit_ok();
}

/* Sdl.Ttf.Font.clearFallbackFonts (self : @& Font) : IO Unit
 * -- C: TTF_ClearFallbackFonts. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_clear_fallback_fonts(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_ClearFallbackFonts(f);
    return lean_sdl_unit_ok();
}

/* Sdl.Ttf.Font.setSize (self : @& Font) (ptsize : Float32) : IO Unit
 * -- C: TTF_SetFontSize. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_font_size(
        b_lean_obj_arg self, float ptsize, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    SDL_BOOL_TO_IO(TTF_SetFontSize(f, ptsize));
}

/* Sdl.Ttf.Font.setSizeDPI (self : @& Font) (ptsize : Float32) (hdpi vdpi : Int32)
 * : IO Unit -- C: TTF_SetFontSizeDPI. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_font_size_dpi(
        b_lean_obj_arg self, float ptsize, int32_t hdpi, int32_t vdpi, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    SDL_BOOL_TO_IO(TTF_SetFontSizeDPI(f, ptsize, (int)hdpi, (int)vdpi));
}

/* Sdl.Ttf.Font.size (self : @& Font) : IO Float32
 * -- C: TTF_GetFontSize (0.0 + error -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_font_size(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    float sz = TTF_GetFontSize(f);
    if (sz == 0.0f) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_float32(sz));
}

/* Sdl.Ttf.Font.dpi (self : @& Font) : IO (Int32 x Int32) -- C: TTF_GetFontDPI. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_font_dpi(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    int hdpi = 0, vdpi = 0;
    if (!TTF_GetFontDPI(f, &hdpi, &vdpi)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_ttf_mk_int32_pair((int32_t)hdpi, (int32_t)vdpi));
}

/* Sdl.Ttf.Font.setStyleRaw (self : @& Font) (style : UInt32) : IO Unit
 * -- C: TTF_SetFontStyle. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_font_style(
        b_lean_obj_arg self, uint32_t style, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_SetFontStyle(f, (TTF_FontStyleFlags)style);
    return lean_sdl_unit_ok();
}

/* Sdl.Ttf.Font.getStyleRaw (self : @& Font) : IO UInt32 -- C: TTF_GetFontStyle. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_font_style(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)TTF_GetFontStyle(f)));
}

/* Sdl.Ttf.Font.setOutline (self : @& Font) (outline : Int32) : IO Unit
 * -- C: TTF_SetFontOutline (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_font_outline(
        b_lean_obj_arg self, int32_t outline, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    SDL_BOOL_TO_IO(TTF_SetFontOutline(f, (int)outline));
}

/* Sdl.Ttf.Font.outline (self : @& Font) : IO Int32 -- C: TTF_GetFontOutline. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_font_outline(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)TTF_GetFontOutline(f)));
}

/* Sdl.Ttf.Font.setHintingRaw (self : @& Font) (hinting : UInt32) : IO Unit
 * -- C: TTF_SetFontHinting. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_font_hinting(
        b_lean_obj_arg self, uint32_t hinting, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_SetFontHinting(f, (TTF_HintingFlags)hinting);
    return lean_sdl_unit_ok();
}

/* Sdl.Ttf.Font.getHintingRaw (self : @& Font) : IO UInt32
 * -- C: TTF_GetFontHinting. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_font_hinting(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)TTF_GetFontHinting(f)));
}

/* Sdl.Ttf.Font.numFaces (self : @& Font) : IO Int32 -- C: TTF_GetNumFontFaces. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_num_font_faces(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)TTF_GetNumFontFaces(f)));
}

/* Sdl.Ttf.Font.setSDF (self : @& Font) (enabled : Bool) : IO Unit
 * -- C: TTF_SetFontSDF (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_font_sdf(
        b_lean_obj_arg self, uint8_t enabled, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    SDL_BOOL_TO_IO(TTF_SetFontSDF(f, enabled != 0));
}

/* Sdl.Ttf.Font.sdf (self : @& Font) : IO Bool -- C: TTF_GetFontSDF. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_font_sdf(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    return lean_io_result_mk_ok(lean_box(TTF_GetFontSDF(f)));
}

/* Sdl.Ttf.Font.weight (self : @& Font) : IO Int32 -- C: TTF_GetFontWeight. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_font_weight(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)TTF_GetFontWeight(f)));
}

/* Sdl.Ttf.Font.setWrapAlignmentRaw (self : @& Font) (align : UInt32) : IO Unit
 * -- C: TTF_SetFontWrapAlignment. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_font_wrap_alignment(
        b_lean_obj_arg self, uint32_t align, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_SetFontWrapAlignment(f, (TTF_HorizontalAlignment)align);
    return lean_sdl_unit_ok();
}

/* Sdl.Ttf.Font.getWrapAlignmentRaw (self : @& Font) : IO UInt32
 * -- C: TTF_GetFontWrapAlignment. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_font_wrap_alignment(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)TTF_GetFontWrapAlignment(f)));
}

/* Sdl.Ttf.Font.height (self : @& Font) : IO Int32 -- C: TTF_GetFontHeight. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_font_height(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)TTF_GetFontHeight(f)));
}

/* Sdl.Ttf.Font.ascent (self : @& Font) : IO Int32 -- C: TTF_GetFontAscent. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_font_ascent(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)TTF_GetFontAscent(f)));
}

/* Sdl.Ttf.Font.descent (self : @& Font) : IO Int32 -- C: TTF_GetFontDescent. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_font_descent(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)TTF_GetFontDescent(f)));
}

/* Sdl.Ttf.Font.setLineSkip (self : @& Font) (lineskip : Int32) : IO Unit
 * -- C: TTF_SetFontLineSkip. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_font_line_skip(
        b_lean_obj_arg self, int32_t lineskip, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_SetFontLineSkip(f, (int)lineskip);
    return lean_sdl_unit_ok();
}

/* Sdl.Ttf.Font.lineSkip (self : @& Font) : IO Int32 -- C: TTF_GetFontLineSkip. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_font_line_skip(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)TTF_GetFontLineSkip(f)));
}

/* Sdl.Ttf.Font.setKerning (self : @& Font) (enabled : Bool) : IO Unit
 * -- C: TTF_SetFontKerning. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_font_kerning(
        b_lean_obj_arg self, uint8_t enabled, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_SetFontKerning(f, enabled != 0);
    return lean_sdl_unit_ok();
}

/* Sdl.Ttf.Font.kerning (self : @& Font) : IO Bool -- C: TTF_GetFontKerning. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_font_kerning(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    return lean_io_result_mk_ok(lean_box(TTF_GetFontKerning(f)));
}

/* Sdl.Ttf.Font.isFixedWidth (self : @& Font) : IO Bool
 * -- C: TTF_FontIsFixedWidth. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_font_is_fixed_width(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    return lean_io_result_mk_ok(lean_box(TTF_FontIsFixedWidth(f)));
}

/* Sdl.Ttf.Font.isScalable (self : @& Font) : IO Bool -- C: TTF_FontIsScalable. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_font_is_scalable(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    return lean_io_result_mk_ok(lean_box(TTF_FontIsScalable(f)));
}

/* Sdl.Ttf.Font.familyName (self : @& Font) : IO String
 * -- C: TTF_GetFontFamilyName (NULL -> ""). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_font_family_name(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    return lean_io_result_mk_ok(lean_sdl_mk_string(TTF_GetFontFamilyName(f)));
}

/* Sdl.Ttf.Font.styleName (self : @& Font) : IO String
 * -- C: TTF_GetFontStyleName (NULL -> ""). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_font_style_name(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    return lean_io_result_mk_ok(lean_sdl_mk_string(TTF_GetFontStyleName(f)));
}

/* Sdl.Ttf.Font.setDirectionRaw (self : @& Font) (direction : UInt32) : IO Unit
 * -- C: TTF_SetFontDirection (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_font_direction(
        b_lean_obj_arg self, uint32_t direction, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    SDL_BOOL_TO_IO(TTF_SetFontDirection(f, (TTF_Direction)direction));
}

/* Sdl.Ttf.Font.getDirectionRaw (self : @& Font) : IO UInt32
 * -- C: TTF_GetFontDirection. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_font_direction(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)TTF_GetFontDirection(f)));
}

/* Sdl.Ttf.Font.setScriptRaw (self : @& Font) (script : UInt32) : IO Unit
 * -- C: TTF_SetFontScript (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_font_script(
        b_lean_obj_arg self, uint32_t script, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    SDL_BOOL_TO_IO(TTF_SetFontScript(f, (Uint32)script));
}

/* Sdl.Ttf.Font.getScriptRaw (self : @& Font) : IO UInt32
 * -- C: TTF_GetFontScript (0 = unset, not an error). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_font_script(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)TTF_GetFontScript(f)));
}

/* Sdl.Ttf.Font.setLanguage (self : @& Font) (bcp47 : @& String) : IO Unit
 * -- C: TTF_SetFontLanguage (false -> throw). Empty string resets the language
 * (SDL treats "" the same as no shaping language). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_font_language(
        b_lean_obj_arg self, b_lean_obj_arg bcp47, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    SDL_BOOL_TO_IO(TTF_SetFontLanguage(f, lean_string_cstr(bcp47)));
}

/* ---------- Glyphs ---------- */

/* Sdl.Ttf.Font.hasGlyphRaw (self : @& Font) (ch : UInt32) : IO Bool
 * -- C: TTF_FontHasGlyph. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_font_has_glyph(
        b_lean_obj_arg self, uint32_t ch, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    return lean_io_result_mk_ok(lean_box(TTF_FontHasGlyph(f, (Uint32)ch)));
}

/* Sdl.Ttf.Font.glyphImageRaw (self : @& Font) (ch : UInt32)
 * : IO (Surface x ImageType) -- C: TTF_GetGlyphImage. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_glyph_image(
        b_lean_obj_arg self, uint32_t ch, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_ImageType t = TTF_IMAGE_INVALID;
    SDL_Surface *s = TTF_GetGlyphImage(f, (Uint32)ch, &t);
    return lean_sdl_ttf_wrap_glyph_image(s, t);
}

/* Sdl.Ttf.Font.glyphImageForIndex (self : @& Font) (glyphIndex : UInt32)
 * : IO (Surface x ImageType) -- C: TTF_GetGlyphImageForIndex. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_glyph_image_for_index(
        b_lean_obj_arg self, uint32_t glyph_index, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_ImageType t = TTF_IMAGE_INVALID;
    SDL_Surface *s = TTF_GetGlyphImageForIndex(f, (Uint32)glyph_index, &t);
    return lean_sdl_ttf_wrap_glyph_image(s, t);
}

/* Sdl.Ttf.Font.glyphMetricsRaw (self : @& Font) (ch : UInt32) : IO GlyphMetrics
 * -- C: TTF_GetGlyphMetrics (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_glyph_metrics(
        b_lean_obj_arg self, uint32_t ch, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    int minx = 0, maxx = 0, miny = 0, maxy = 0, advance = 0;
    if (!TTF_GetGlyphMetrics(f, (Uint32)ch, &minx, &maxx, &miny, &maxy, &advance))
        return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_ttf_mk_glyph_metrics(
        (int32_t)minx, (int32_t)maxx, (int32_t)miny, (int32_t)maxy, (int32_t)advance));
}

/* Sdl.Ttf.Font.glyphKerningRaw (self : @& Font) (previousCh ch : UInt32)
 * : IO Int32 -- C: TTF_GetGlyphKerning (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_glyph_kerning(
        b_lean_obj_arg self, uint32_t previous_ch, uint32_t ch, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    int kerning = 0;
    if (!TTF_GetGlyphKerning(f, (Uint32)previous_ch, (Uint32)ch, &kerning))
        return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)kerning));
}

/* ---------- Measurement ---------- */

/* Sdl.Ttf.Font.stringSize (self : @& Font) (text : @& String) : IO (Int32 x Int32)
 * -- C: TTF_GetStringSize (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_string_size(
        b_lean_obj_arg self, b_lean_obj_arg text, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    int rw = 0, rh = 0;
    if (!TTF_GetStringSize(f, lean_string_cstr(text), LEAN_STR_LEN(text), &rw, &rh))
        return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_ttf_mk_int32_pair((int32_t)rw, (int32_t)rh));
}

/* Sdl.Ttf.Font.stringSizeWrapped (self : @& Font) (text : @& String)
 * (wrapWidth : Int32) : IO (Int32 x Int32)
 * -- C: TTF_GetStringSizeWrapped (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_string_size_wrapped(
        b_lean_obj_arg self, b_lean_obj_arg text, int32_t wrap_width, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    int rw = 0, rh = 0;
    if (!TTF_GetStringSizeWrapped(f, lean_string_cstr(text), LEAN_STR_LEN(text),
                                  (int)wrap_width, &rw, &rh))
        return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_ttf_mk_int32_pair((int32_t)rw, (int32_t)rh));
}

/* Sdl.Ttf.Font.measureString (self : @& Font) (text : @& String) (maxWidth : Int32)
 * : IO (Int32 x Nat) -- C: TTF_MeasureString (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_measure_string(
        b_lean_obj_arg self, b_lean_obj_arg text, int32_t max_width, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    int measured_width = 0;
    size_t measured_length = 0;
    if (!TTF_MeasureString(f, lean_string_cstr(text), LEAN_STR_LEN(text),
                           (int)max_width, &measured_width, &measured_length))
        return lean_sdl_throw();
    return lean_io_result_mk_ok(
        lean_sdl_ttf_mk_measure((int32_t)measured_width, measured_length));
}

/* ---------- Rendering to a surface ---------- */

/* Sdl.Ttf.Font.renderSolidRaw -- C: TTF_RenderText_Solid. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_render_text_solid(
        b_lean_obj_arg self, b_lean_obj_arg text,
        uint8_t r, uint8_t g, uint8_t b, uint8_t a, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_COLOR(fg, r, g, b, a);
    return lean_sdl_ttf_wrap_surface_or_throw(
        TTF_RenderText_Solid(f, lean_string_cstr(text), LEAN_STR_LEN(text), fg));
}

/* Sdl.Ttf.Font.renderSolidWrappedRaw -- C: TTF_RenderText_Solid_Wrapped. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_render_text_solid_wrapped(
        b_lean_obj_arg self, b_lean_obj_arg text,
        uint8_t r, uint8_t g, uint8_t b, uint8_t a, int32_t wrap_length, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_COLOR(fg, r, g, b, a);
    return lean_sdl_ttf_wrap_surface_or_throw(TTF_RenderText_Solid_Wrapped(
        f, lean_string_cstr(text), LEAN_STR_LEN(text), fg, (int)wrap_length));
}

/* Sdl.Ttf.Font.renderGlyphSolidRaw -- C: TTF_RenderGlyph_Solid. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_render_glyph_solid(
        b_lean_obj_arg self, uint32_t ch,
        uint8_t r, uint8_t g, uint8_t b, uint8_t a, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_COLOR(fg, r, g, b, a);
    return lean_sdl_ttf_wrap_surface_or_throw(TTF_RenderGlyph_Solid(f, (Uint32)ch, fg));
}

/* Sdl.Ttf.Font.renderShadedRaw -- C: TTF_RenderText_Shaded. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_render_text_shaded(
        b_lean_obj_arg self, b_lean_obj_arg text,
        uint8_t fr, uint8_t fg_, uint8_t fb, uint8_t fa,
        uint8_t br, uint8_t bg_, uint8_t bb, uint8_t ba, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_COLOR(fg, fr, fg_, fb, fa);
    TTF_COLOR(bg, br, bg_, bb, ba);
    return lean_sdl_ttf_wrap_surface_or_throw(
        TTF_RenderText_Shaded(f, lean_string_cstr(text), LEAN_STR_LEN(text), fg, bg));
}

/* Sdl.Ttf.Font.renderShadedWrappedRaw -- C: TTF_RenderText_Shaded_Wrapped. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_render_text_shaded_wrapped(
        b_lean_obj_arg self, b_lean_obj_arg text,
        uint8_t fr, uint8_t fg_, uint8_t fb, uint8_t fa,
        uint8_t br, uint8_t bg_, uint8_t bb, uint8_t ba, int32_t wrap_width, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_COLOR(fg, fr, fg_, fb, fa);
    TTF_COLOR(bg, br, bg_, bb, ba);
    return lean_sdl_ttf_wrap_surface_or_throw(TTF_RenderText_Shaded_Wrapped(
        f, lean_string_cstr(text), LEAN_STR_LEN(text), fg, bg, (int)wrap_width));
}

/* Sdl.Ttf.Font.renderGlyphShadedRaw -- C: TTF_RenderGlyph_Shaded. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_render_glyph_shaded(
        b_lean_obj_arg self, uint32_t ch,
        uint8_t fr, uint8_t fg_, uint8_t fb, uint8_t fa,
        uint8_t br, uint8_t bg_, uint8_t bb, uint8_t ba, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_COLOR(fg, fr, fg_, fb, fa);
    TTF_COLOR(bg, br, bg_, bb, ba);
    return lean_sdl_ttf_wrap_surface_or_throw(TTF_RenderGlyph_Shaded(f, (Uint32)ch, fg, bg));
}

/* Sdl.Ttf.Font.renderBlendedRaw -- C: TTF_RenderText_Blended. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_render_text_blended(
        b_lean_obj_arg self, b_lean_obj_arg text,
        uint8_t r, uint8_t g, uint8_t b, uint8_t a, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_COLOR(fg, r, g, b, a);
    return lean_sdl_ttf_wrap_surface_or_throw(
        TTF_RenderText_Blended(f, lean_string_cstr(text), LEAN_STR_LEN(text), fg));
}

/* Sdl.Ttf.Font.renderBlendedWrappedRaw -- C: TTF_RenderText_Blended_Wrapped. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_render_text_blended_wrapped(
        b_lean_obj_arg self, b_lean_obj_arg text,
        uint8_t r, uint8_t g, uint8_t b, uint8_t a, int32_t wrap_width, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_COLOR(fg, r, g, b, a);
    return lean_sdl_ttf_wrap_surface_or_throw(TTF_RenderText_Blended_Wrapped(
        f, lean_string_cstr(text), LEAN_STR_LEN(text), fg, (int)wrap_width));
}

/* Sdl.Ttf.Font.renderGlyphBlendedRaw -- C: TTF_RenderGlyph_Blended. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_render_glyph_blended(
        b_lean_obj_arg self, uint32_t ch,
        uint8_t r, uint8_t g, uint8_t b, uint8_t a, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_COLOR(fg, r, g, b, a);
    return lean_sdl_ttf_wrap_surface_or_throw(TTF_RenderGlyph_Blended(f, (Uint32)ch, fg));
}

/* Sdl.Ttf.Font.renderLCDRaw -- C: TTF_RenderText_LCD. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_render_text_lcd(
        b_lean_obj_arg self, b_lean_obj_arg text,
        uint8_t fr, uint8_t fg_, uint8_t fb, uint8_t fa,
        uint8_t br, uint8_t bg_, uint8_t bb, uint8_t ba, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_COLOR(fg, fr, fg_, fb, fa);
    TTF_COLOR(bg, br, bg_, bb, ba);
    return lean_sdl_ttf_wrap_surface_or_throw(
        TTF_RenderText_LCD(f, lean_string_cstr(text), LEAN_STR_LEN(text), fg, bg));
}

/* Sdl.Ttf.Font.renderLCDWrappedRaw -- C: TTF_RenderText_LCD_Wrapped. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_render_text_lcd_wrapped(
        b_lean_obj_arg self, b_lean_obj_arg text,
        uint8_t fr, uint8_t fg_, uint8_t fb, uint8_t fa,
        uint8_t br, uint8_t bg_, uint8_t bb, uint8_t ba, int32_t wrap_width, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_COLOR(fg, fr, fg_, fb, fa);
    TTF_COLOR(bg, br, bg_, bb, ba);
    return lean_sdl_ttf_wrap_surface_or_throw(TTF_RenderText_LCD_Wrapped(
        f, lean_string_cstr(text), LEAN_STR_LEN(text), fg, bg, (int)wrap_width));
}

/* Sdl.Ttf.Font.renderGlyphLCDRaw -- C: TTF_RenderGlyph_LCD. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_render_glyph_lcd(
        b_lean_obj_arg self, uint32_t ch,
        uint8_t fr, uint8_t fg_, uint8_t fb, uint8_t fa,
        uint8_t br, uint8_t bg_, uint8_t bb, uint8_t ba, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Font, f, self);
    TTF_COLOR(fg, fr, fg_, fb, fa);
    TTF_COLOR(bg, br, bg_, bb, ba);
    return lean_sdl_ttf_wrap_surface_or_throw(TTF_RenderGlyph_LCD(f, (Uint32)ch, fg, bg));
}
