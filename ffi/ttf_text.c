/* Shims for Sdl/Ttf/Text.lean (SDL3_ttf/SDL_ttf.h + SDL_textengine.h) -- the
 * text-engine half of SDL_ttf: the three TTF_TextEngine kinds, TTF_Text objects
 * (editing / layout / substrings / draws) and the GPU draw-data decode. Builds
 * on ffi/ttf.c (agent A): the TTF_Font class lives there (classes.h).
 *
 * Classes (all sdl_holder-based):
 *   - lean_sdl_ttf_engine_surface  : finalize TTF_DestroySurfaceTextEngine;
 *                                    owner = NULL.
 *   - lean_sdl_ttf_engine_renderer : finalize TTF_DestroyRendererTextEngine;
 *                                    owner = inc'd Renderer ext (or inc'd
 *                                    Properties ext for the *WithProperties
 *                                    creator, which cannot recover the renderer
 *                                    from the props bag).
 *   - lean_sdl_ttf_engine_gpu      : finalize TTF_DestroyGPUTextEngine;
 *                                    owner = inc'd Gpu.Device ext (or inc'd
 *                                    Properties ext, same rationale).
 *   - lean_sdl_ttf_text            : finalize TTF_DestroyText; owner = a 2-field
 *                                    Lean pair {engineExt, fontExt}. Manual
 *                                    Text.destroy NULLs the ptr (leaf).
 * The SDL_DEFINE_CLASS finalizer runs the destroy statement then decs the owner,
 * so decrementing the pair releases both the engine and the font. Generic Text
 * shims read the holder ptr uniformly; the GPU-only engine shims class-check
 * against lean_sdl_ttf_engine_gpu_class and throw otherwise.
 *
 * Multi-value results (SubString, AtlasDrawSequence, pairs) come back through
 * @[export]ed Lean makers (Sdl/Ttf/Text.lean and Sdl/Ttf.lean), so C never lays
 * out a Lean structure. Strings cross with an explicit byte length. */
#include <SDL3_ttf/SDL_ttf.h>
#include <SDL3_ttf/SDL_textengine.h>
#include "util.h"
#include "classes.h"

/* ---------- Classes ---------- */

SDL_DEFINE_CLASS(lean_sdl_ttf_engine_surface,
                 TTF_DestroySurfaceTextEngine((TTF_TextEngine *)self))
SDL_DEFINE_CLASS(lean_sdl_ttf_engine_renderer,
                 TTF_DestroyRendererTextEngine((TTF_TextEngine *)self))
SDL_DEFINE_CLASS(lean_sdl_ttf_engine_gpu,
                 TTF_DestroyGPUTextEngine((TTF_TextEngine *)self))
SDL_DEFINE_CLASS(lean_sdl_ttf_text, TTF_DestroyText((TTF_Text *)self))

/* Register the text-engine + text classes. Called from Sdl/Ttf/Text.lean's
 * `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_text_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_ttf_engine_surface_class_init();
    lean_sdl_ttf_engine_renderer_class_init();
    lean_sdl_ttf_engine_gpu_class_init();
    lean_sdl_ttf_text_class_init();
    return lean_sdl_unit_ok();
}

/* ---------- Lean-side makers ---------- */

/* Sdl/Ttf/Text.lean */
extern lean_object *lean_sdl_ttf_mk_substring(
    uint32_t flags, int32_t offset, int32_t length, int32_t line_index,
    int32_t cluster_index, int32_t rx, int32_t ry, int32_t rw, int32_t rh);
extern lean_object *lean_sdl_ttf_mk_atlas_draw_sequence(
    lean_object *atlas_texture, lean_object *xy, lean_object *uv,
    lean_object *indices, uint32_t raw_type);
/* Sdl/Ttf.lean */
extern lean_object *lean_sdl_ttf_mk_int32_pair(int32_t a, int32_t b);
/* Sdl/Pixels.lean */
extern lean_object *lean_sdl_mk_color(uint8_t r, uint8_t g, uint8_t b, uint8_t a);
extern lean_object *lean_sdl_mk_fcolor(float r, float g, float b, float a);

/* Byte length of a Lean string, excluding the trailing NUL. */
#define LEAN_STR_LEN(s) (lean_string_size(s) - 1)

/* Build a SubString maker call from a filled TTF_SubString. */
static lean_object *lean_sdl_ttf_substring_obj(const TTF_SubString *s) {
    return lean_sdl_ttf_mk_substring(
        (uint32_t)s->flags, (int32_t)s->offset, (int32_t)s->length,
        (int32_t)s->line_index, (int32_t)s->cluster_index,
        (int32_t)s->rect.x, (int32_t)s->rect.y, (int32_t)s->rect.w, (int32_t)s->rect.h);
}

/* Fetch the underlying TTF_TextEngine* from any of the three engine externals
 * (generic: no class check). Returns NULL if the holder was released (engines
 * are finalizer-only, so this only guards a defensive edge). */
static inline TTF_TextEngine *lean_sdl_ttf_engine_ptr(b_lean_obj_arg o) {
    return (TTF_TextEngine *)lean_sdl_holder_of(o)->ptr;
}

/* ---------- Engine creation ---------- */

/* Sdl.Ttf.createSurfaceTextEngine : IO TextEngine
 * -- C: TTF_CreateSurfaceTextEngine (owner = NULL). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_create_surface_text_engine(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    TTF_TextEngine *e = TTF_CreateSurfaceTextEngine();
    if (!e) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_ttf_engine_surface_class, e, NULL));
}

/* Sdl.Ttf.createRendererTextEngine (r : @& Renderer) : IO TextEngine
 * -- C: TTF_CreateRendererTextEngine (owner = inc'd Renderer ext). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_create_renderer_text_engine(
        b_lean_obj_arg r, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Renderer, ren, r);
    TTF_TextEngine *e = TTF_CreateRendererTextEngine(ren);
    if (!e) return lean_sdl_throw();
    lean_inc(r);
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_ttf_engine_renderer_class, e, (lean_object *)r));
}

/* Sdl.Ttf.createRendererTextEngineWithProperties (props : @& Properties)
 * : IO TextEngine -- C: TTF_CreateRendererTextEngineWithProperties. Cannot
 * recover the renderer from the props bag, so owner = inc'd Properties ext; the
 * renderer inside props must outlive the engine. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_create_renderer_text_engine_with_properties(
        b_lean_obj_arg props, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(props);
    if (!h->ptr) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    TTF_TextEngine *e =
        TTF_CreateRendererTextEngineWithProperties((SDL_PropertiesID)(uintptr_t)h->ptr);
    if (!e) return lean_sdl_throw();
    lean_inc(props);
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_ttf_engine_renderer_class, e, (lean_object *)props));
}

/* Sdl.Ttf.createGpuTextEngine (dev : @& Gpu.Device) : IO TextEngine
 * -- C: TTF_CreateGPUTextEngine (owner = inc'd Gpu.Device ext). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_create_gpu_text_engine(
        b_lean_obj_arg dev, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, d, dev);
    TTF_TextEngine *e = TTF_CreateGPUTextEngine(d);
    if (!e) return lean_sdl_throw();
    lean_inc(dev);
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_ttf_engine_gpu_class, e, (lean_object *)dev));
}

/* Sdl.Ttf.createGpuTextEngineWithProperties (props : @& Properties)
 * : IO TextEngine -- C: TTF_CreateGPUTextEngineWithProperties. owner = inc'd
 * Properties ext; the device inside props must outlive the engine. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_create_gpu_text_engine_with_properties(
        b_lean_obj_arg props, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(props);
    if (!h->ptr) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    TTF_TextEngine *e =
        TTF_CreateGPUTextEngineWithProperties((SDL_PropertiesID)(uintptr_t)h->ptr);
    if (!e) return lean_sdl_throw();
    lean_inc(props);
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_ttf_engine_gpu_class, e, (lean_object *)props));
}

/* Sdl.Ttf.TextEngine.setGpuWindingRaw (self) (winding : UInt32) : IO Unit
 * -- C: TTF_SetGPUTextEngineWinding (GPU-class check). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_gpu_text_engine_winding(
        b_lean_obj_arg self, uint32_t winding, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    if (lean_get_external_class((lean_object *)self) != lean_sdl_ttf_engine_gpu_class)
        return lean_sdl_throw_msg("SDL: not a GPU text engine");
    TTF_TextEngine *e = lean_sdl_ttf_engine_ptr(self);
    if (!e) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    TTF_SetGPUTextEngineWinding(e, (TTF_GPUTextEngineWinding)winding);
    return lean_sdl_unit_ok();
}

/* Sdl.Ttf.TextEngine.gpuWindingRaw (self) : IO UInt32
 * -- C: TTF_GetGPUTextEngineWinding (GPU-class check). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_gpu_text_engine_winding(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    if (lean_get_external_class((lean_object *)self) != lean_sdl_ttf_engine_gpu_class)
        return lean_sdl_throw_msg("SDL: not a GPU text engine");
    TTF_TextEngine *e = lean_sdl_ttf_engine_ptr(self);
    if (!e) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    return lean_io_result_mk_ok(
        lean_box_uint32((uint32_t)TTF_GetGPUTextEngineWinding(e)));
}

/* Sdl.Ttf.TextEngine.createTextRaw (self) (font) (text) : IO Text
 * -- C: TTF_CreateText. owner = {engineExt, fontExt} (both inc'd). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_create_text(
        b_lean_obj_arg self, b_lean_obj_arg font, b_lean_obj_arg text, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    TTF_TextEngine *e = lean_sdl_ttf_engine_ptr(self);
    if (!e) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_GET_OR_THROW(TTF_Font, f, font);
    TTF_Text *t = TTF_CreateText(e, f, lean_string_cstr(text), LEAN_STR_LEN(text));
    if (!t) return lean_sdl_throw();
    lean_inc(self);
    lean_inc(font);
    lean_object *pair = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(pair, 0, (lean_object *)self);
    lean_ctor_set(pair, 1, (lean_object *)font);
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_ttf_text_class, t, pair));
}

/* ---------- Text draws ---------- */

/* Sdl.Ttf.Text.drawSurface (self) (x y : Int32) (target : @& Surface) : IO Unit
 * -- C: TTF_DrawSurfaceText. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_draw_surface_text(
        b_lean_obj_arg self, int32_t x, int32_t y, b_lean_obj_arg target, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    SDL_GET_OR_THROW(SDL_Surface, surf, target);
    SDL_BOOL_TO_IO(TTF_DrawSurfaceText(t, (int)x, (int)y, surf));
}

/* Sdl.Ttf.Text.drawRenderer (self) (x y : Float32) : IO Unit
 * -- C: TTF_DrawRendererText. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_draw_renderer_text(
        b_lean_obj_arg self, float x, float y, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    SDL_BOOL_TO_IO(TTF_DrawRendererText(t, x, y));
}

/* Sdl.Ttf.Text.gpuDrawData (self) : IO (Array AtlasDrawSequence)
 * -- C: TTF_GetGPUTextDrawData. Walks the `next` linked list, copying each
 * sequence eagerly (the C data is invalidated by the next text update). The
 * atlas texture is a borrowed Gpu.Texture owned by an inc'd Text ext. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_gpu_text_draw_data(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    TTF_GPUAtlasDrawSequence *seq = TTF_GetGPUTextDrawData(t);
    /* NULL is a valid empty result (no glyphs); SDL sets no error. */
    size_t n = 0;
    for (TTF_GPUAtlasDrawSequence *p = seq; p; p = p->next) n++;
    lean_object *arr = lean_alloc_array(n, n);
    size_t i = 0;
    for (TTF_GPUAtlasDrawSequence *p = seq; p; p = p->next, i++) {
        size_t nv = p->num_vertices > 0 ? (size_t)p->num_vertices : 0;
        size_t ni = p->num_indices > 0 ? (size_t)p->num_indices : 0;
        /* xy / uv: 2 doubles per vertex (converted from the C floats). */
        lean_object *xy = lean_alloc_sarray(sizeof(double), 2 * nv, 2 * nv);
        lean_object *uv = lean_alloc_sarray(sizeof(double), 2 * nv, 2 * nv);
        double *xyd = lean_float_array_cptr(xy);
        double *uvd = lean_float_array_cptr(uv);
        for (size_t v = 0; v < nv; v++) {
            xyd[2 * v]     = (double)p->xy[v].x;
            xyd[2 * v + 1] = (double)p->xy[v].y;
            uvd[2 * v]     = (double)p->uv[v].x;
            uvd[2 * v + 1] = (double)p->uv[v].y;
        }
        /* indices: Array Int32 (boxed as uint32). */
        lean_object *inds = lean_alloc_array(ni, ni);
        for (size_t k = 0; k < ni; k++)
            lean_array_set_core(inds, k, lean_box_uint32((uint32_t)p->indices[k]));
        /* atlas texture: borrowed wrap, owner = inc'd Text ext. */
        lean_inc(self);
        lean_object *tex =
            lean_sdl_wrap_gpu_texture_borrowed(p->atlas_texture, (lean_object *)self);
        lean_object *elem = lean_sdl_ttf_mk_atlas_draw_sequence(
            tex, xy, uv, inds, (uint32_t)p->image_type);
        lean_array_set_core(arr, i, elem);
    }
    return lean_io_result_mk_ok(arr);
}

/* ---------- Text attributes ---------- */

/* Sdl.Ttf.Text.properties (self) : IO Properties
 * -- C: TTF_GetTextProperties. Borrowed, owner = inc'd Text ext. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_text_properties(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    SDL_PropertiesID id = TTF_GetTextProperties(t);
    if (id == 0) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_properties_borrowed(id, (lean_object *)self));
}

/* Sdl.Ttf.Text.setEngine (self) (e : @& TextEngine) : IO Unit
 * -- C: TTF_SetTextEngine. Rebuilds the owned pair: keep the font, swap in the
 * new engine (both inc'd), dec the old pair. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_text_engine(
        b_lean_obj_arg self, b_lean_obj_arg e, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    TTF_TextEngine *eng = lean_sdl_ttf_engine_ptr(e);
    if (!eng) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    if (!TTF_SetTextEngine(t, eng)) return lean_sdl_throw();
    sdl_holder *h = lean_sdl_holder_of(self);
    lean_object *oldpair = h->owner;
    lean_object *keptfont = lean_ctor_get(oldpair, 1);
    lean_inc(keptfont);
    lean_inc(e);
    lean_object *newpair = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(newpair, 0, (lean_object *)e);
    lean_ctor_set(newpair, 1, keptfont);
    h->owner = newpair;
    lean_dec(oldpair);
    return lean_sdl_unit_ok();
}

/* Sdl.Ttf.Text.engine (self) : IO TextEngine -- the stored engine ext, inc'd
 * (identity-preserving; the pair already holds it). C: TTF_GetTextEngine. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_text_engine(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    (void)t;
    lean_object *eng = lean_ctor_get(lean_sdl_holder_of(self)->owner, 0);
    lean_inc(eng);
    return lean_io_result_mk_ok(eng);
}

/* Sdl.Ttf.Text.setFont (self) (f : @& Font) : IO Unit
 * -- C: TTF_SetTextFont. Rebuilds the owned pair: keep the engine, swap in the
 * new font (both inc'd), dec the old pair. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_text_font(
        b_lean_obj_arg self, b_lean_obj_arg f, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    SDL_GET_OR_THROW(TTF_Font, fnt, f);
    if (!TTF_SetTextFont(t, fnt)) return lean_sdl_throw();
    sdl_holder *h = lean_sdl_holder_of(self);
    lean_object *oldpair = h->owner;
    lean_object *keptengine = lean_ctor_get(oldpair, 0);
    lean_inc(keptengine);
    lean_inc(f);
    lean_object *newpair = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(newpair, 0, keptengine);
    lean_ctor_set(newpair, 1, (lean_object *)f);
    h->owner = newpair;
    lean_dec(oldpair);
    return lean_sdl_unit_ok();
}

/* Sdl.Ttf.Text.font (self) : IO Font -- the stored font ext, inc'd
 * (identity-preserving; the pair already holds it). C: TTF_GetTextFont. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_text_font(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    (void)t;
    lean_object *fnt = lean_ctor_get(lean_sdl_holder_of(self)->owner, 1);
    lean_inc(fnt);
    return lean_io_result_mk_ok(fnt);
}

/* Sdl.Ttf.Text.setDirectionRaw (self) (direction : UInt32) : IO Unit
 * -- C: TTF_SetTextDirection. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_text_direction(
        b_lean_obj_arg self, uint32_t direction, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    SDL_BOOL_TO_IO(TTF_SetTextDirection(t, (TTF_Direction)direction));
}

/* Sdl.Ttf.Text.directionRaw (self) : IO UInt32 -- C: TTF_GetTextDirection. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_text_direction(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)TTF_GetTextDirection(t)));
}

/* Sdl.Ttf.Text.setScriptRaw (self) (script : UInt32) : IO Unit
 * -- C: TTF_SetTextScript (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_text_script(
        b_lean_obj_arg self, uint32_t script, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    SDL_BOOL_TO_IO(TTF_SetTextScript(t, (Uint32)script));
}

/* Sdl.Ttf.Text.scriptRaw (self) : IO UInt32 -- C: TTF_GetTextScript. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_text_script(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)TTF_GetTextScript(t)));
}

/* Sdl.Ttf.Text.setColorRaw (self) (r g b a : UInt8) : IO Unit
 * -- C: TTF_SetTextColor (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_text_color(
        b_lean_obj_arg self, uint8_t r, uint8_t g, uint8_t b, uint8_t a, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    SDL_BOOL_TO_IO(TTF_SetTextColor(t, r, g, b, a));
}

/* Sdl.Ttf.Text.color (self) : IO Color -- C: TTF_GetTextColor (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_text_color(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    Uint8 r = 0, g = 0, b = 0, a = 0;
    if (!TTF_GetTextColor(t, &r, &g, &b, &a)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_color(r, g, b, a));
}

/* Sdl.Ttf.Text.setColorFloatRaw (self) (r g b a : Float32) : IO Unit
 * -- C: TTF_SetTextColorFloat (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_text_color_float(
        b_lean_obj_arg self, float r, float g, float b, float a, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    SDL_BOOL_TO_IO(TTF_SetTextColorFloat(t, r, g, b, a));
}

/* Sdl.Ttf.Text.colorFloat (self) : IO FColor
 * -- C: TTF_GetTextColorFloat (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_text_color_float(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    float r = 0, g = 0, b = 0, a = 0;
    if (!TTF_GetTextColorFloat(t, &r, &g, &b, &a)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_fcolor(r, g, b, a));
}

/* Sdl.Ttf.Text.setPosition (self) (x y : Int32) : IO Unit
 * -- C: TTF_SetTextPosition (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_text_position(
        b_lean_obj_arg self, int32_t x, int32_t y, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    SDL_BOOL_TO_IO(TTF_SetTextPosition(t, (int)x, (int)y));
}

/* Sdl.Ttf.Text.position (self) : IO (Int32 x Int32)
 * -- C: TTF_GetTextPosition (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_text_position(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    int x = 0, y = 0;
    if (!TTF_GetTextPosition(t, &x, &y)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_ttf_mk_int32_pair((int32_t)x, (int32_t)y));
}

/* Sdl.Ttf.Text.setWrapWidth (self) (w : Int32) : IO Unit
 * -- C: TTF_SetTextWrapWidth (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_text_wrap_width(
        b_lean_obj_arg self, int32_t width, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    SDL_BOOL_TO_IO(TTF_SetTextWrapWidth(t, (int)width));
}

/* Sdl.Ttf.Text.wrapWidth (self) : IO Int32
 * -- C: TTF_GetTextWrapWidth (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_text_wrap_width(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    int width = 0;
    if (!TTF_GetTextWrapWidth(t, &width)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)width));
}

/* Sdl.Ttf.Text.setWrapWhitespaceVisible (self) (visible : Bool) : IO Unit
 * -- C: TTF_SetTextWrapWhitespaceVisible (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_text_wrap_whitespace_visible(
        b_lean_obj_arg self, uint8_t visible, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    SDL_BOOL_TO_IO(TTF_SetTextWrapWhitespaceVisible(t, visible != 0));
}

/* Sdl.Ttf.Text.wrapWhitespaceVisible (self) : IO Bool
 * -- C: TTF_TextWrapWhitespaceVisible. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_text_wrap_whitespace_visible(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    return lean_io_result_mk_ok(lean_box(TTF_TextWrapWhitespaceVisible(t)));
}

/* Sdl.Ttf.Text.setString (self) (s : @& String) : IO Unit
 * -- C: TTF_SetTextString (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_set_text_string(
        b_lean_obj_arg self, b_lean_obj_arg s, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    SDL_BOOL_TO_IO(TTF_SetTextString(t, lean_string_cstr(s), LEAN_STR_LEN(s)));
}

/* Sdl.Ttf.Text.insertString (self) (offset : Int32) (s : @& String) : IO Unit
 * -- C: TTF_InsertTextString (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_insert_text_string(
        b_lean_obj_arg self, int32_t offset, b_lean_obj_arg s, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    SDL_BOOL_TO_IO(TTF_InsertTextString(t, (int)offset, lean_string_cstr(s), LEAN_STR_LEN(s)));
}

/* Sdl.Ttf.Text.appendString (self) (s : @& String) : IO Unit
 * -- C: TTF_AppendTextString (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_append_text_string(
        b_lean_obj_arg self, b_lean_obj_arg s, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    SDL_BOOL_TO_IO(TTF_AppendTextString(t, lean_string_cstr(s), LEAN_STR_LEN(s)));
}

/* Sdl.Ttf.Text.deleteString (self) (offset length : Int32) : IO Unit
 * -- C: TTF_DeleteTextString (false -> throw; length -1 = to end). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_delete_text_string(
        b_lean_obj_arg self, int32_t offset, int32_t length, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    SDL_BOOL_TO_IO(TTF_DeleteTextString(t, (int)offset, (int)length));
}

/* Sdl.Ttf.Text.string (self) : IO String -- reads the public text->text field
 * (NULL -> ""). C: the `text` field of TTF_Text. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_text_string(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    return lean_io_result_mk_ok(lean_sdl_mk_string(t->text));
}

/* Sdl.Ttf.Text.size (self) : IO (Int32 x Int32)
 * -- C: TTF_GetTextSize (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_text_size(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    int tw = 0, th = 0;
    if (!TTF_GetTextSize(t, &tw, &th)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_ttf_mk_int32_pair((int32_t)tw, (int32_t)th));
}

/* Sdl.Ttf.Text.update (self) : IO Unit -- C: TTF_UpdateText (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_update_text(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    SDL_BOOL_TO_IO(TTF_UpdateText(t));
}

/* Sdl.Ttf.Text.destroy (self) : IO Unit -- C: TTF_DestroyText. Manual leaf:
 * NULL the ptr so a second call (and every other shim) throws. The pair owner
 * is released when the external is finalized. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_destroy_text(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    TTF_DestroyText(t);
    lean_sdl_holder_of(self)->ptr = NULL;
    return lean_sdl_unit_ok();
}

/* ---------- Substrings ---------- */

/* Sdl.Ttf.Text.subString (self) (offset : Int32) : IO SubString
 * -- C: TTF_GetTextSubString (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_text_substring(
        b_lean_obj_arg self, int32_t offset, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    TTF_SubString sub;
    SDL_memset(&sub, 0, sizeof(sub));
    if (!TTF_GetTextSubString(t, (int)offset, &sub)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_ttf_substring_obj(&sub));
}

/* Sdl.Ttf.Text.subStringForLine (self) (line : Int32) : IO SubString
 * -- C: TTF_GetTextSubStringForLine (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_text_substring_for_line(
        b_lean_obj_arg self, int32_t line, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    TTF_SubString sub;
    SDL_memset(&sub, 0, sizeof(sub));
    if (!TTF_GetTextSubStringForLine(t, (int)line, &sub)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_ttf_substring_obj(&sub));
}

/* Sdl.Ttf.Text.subStringsForRange (self) (offset length : Int32)
 * : IO (Array SubString) -- C: TTF_GetTextSubStringsForRange (NULL -> throw).
 * The returned array is one allocation freed with a single SDL_free. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_text_substrings_for_range(
        b_lean_obj_arg self, int32_t offset, int32_t length, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    int count = 0;
    TTF_SubString **subs =
        TTF_GetTextSubStringsForRange(t, (int)offset, (int)length, &count);
    if (!subs) return lean_sdl_throw();
    size_t n = count > 0 ? (size_t)count : 0;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++)
        lean_array_set_core(arr, i, lean_sdl_ttf_substring_obj(subs[i]));
    SDL_free(subs);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.Ttf.Text.subStringForPoint (self) (x y : Int32) : IO SubString
 * -- C: TTF_GetTextSubStringForPoint (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_text_substring_for_point(
        b_lean_obj_arg self, int32_t x, int32_t y, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    TTF_SubString sub;
    SDL_memset(&sub, 0, sizeof(sub));
    if (!TTF_GetTextSubStringForPoint(t, (int)x, (int)y, &sub)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_ttf_substring_obj(&sub));
}

/* Rebuild a TTF_SubString from the flattened Lean-side fields. */
static void lean_sdl_ttf_fill_substring(
        TTF_SubString *sub, uint32_t flags, int32_t offset, int32_t length,
        int32_t line_index, int32_t cluster_index,
        int32_t rx, int32_t ry, int32_t rw, int32_t rh) {
    SDL_memset(sub, 0, sizeof(*sub));
    sub->flags = (TTF_SubStringFlags)flags;
    sub->offset = (int)offset;
    sub->length = (int)length;
    sub->line_index = (int)line_index;
    sub->cluster_index = (int)cluster_index;
    sub->rect.x = (int)rx;
    sub->rect.y = (int)ry;
    sub->rect.w = (int)rw;
    sub->rect.h = (int)rh;
}

/* Sdl.Ttf.Text.prevSubStringRaw -- C: TTF_GetPreviousTextSubString
 * (false -> throw). The input substring is rebuilt from flattened fields. */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_previous_text_substring(
        b_lean_obj_arg self, uint32_t flags, int32_t offset, int32_t length,
        int32_t line_index, int32_t cluster_index,
        int32_t rx, int32_t ry, int32_t rw, int32_t rh, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    TTF_SubString in, out;
    lean_sdl_ttf_fill_substring(&in, flags, offset, length, line_index, cluster_index,
                                rx, ry, rw, rh);
    SDL_memset(&out, 0, sizeof(out));
    if (!TTF_GetPreviousTextSubString(t, &in, &out)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_ttf_substring_obj(&out));
}

/* Sdl.Ttf.Text.nextSubStringRaw -- C: TTF_GetNextTextSubString
 * (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_ttf_get_next_text_substring(
        b_lean_obj_arg self, uint32_t flags, int32_t offset, int32_t length,
        int32_t line_index, int32_t cluster_index,
        int32_t rx, int32_t ry, int32_t rw, int32_t rh, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(TTF_Text, t, self);
    TTF_SubString in, out;
    lean_sdl_ttf_fill_substring(&in, flags, offset, length, line_index, cluster_index,
                                rx, ry, rw, rh);
    SDL_memset(&out, 0, sizeof(out));
    if (!TTF_GetNextTextSubString(t, &in, &out)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_ttf_substring_obj(&out));
}
