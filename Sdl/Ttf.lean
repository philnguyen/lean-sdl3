import Sdl.Core.Macros
import Sdl.Error
import Sdl.Pixels
import Sdl.Surface
import Sdl.IOStream
import Sdl.Properties

/-!
# TrueType fonts, core (`SDL3_ttf/SDL_ttf.h`)

The font half of SDL_ttf 3.2.2: init/version, the font enums/flags, `Font`
open/attributes/glyphs/measurement, and the 12 render-to-surface functions.
Text engines and `TTF_Text` (which build on `Font`) live in `Sdl/Ttf/Text.lean`.

`init`/`quit` are refcounted by SDL_ttf itself (`wasInit` returns the count);
nothing auto-inits, and `init` works with no `Sdl.init` at all (video is only
needed for the renderer/GPU text engines). `getFreeTypeVersion` reports `0.0.0`
until `init` has run.

**Font** is an owned root, finalizer-only (`TTF_CloseFont`; no manual close —
`Text` objects and fallback configurations reference fonts, same rationale as
`Window`/`Renderer`). `openFontIO` always passes `closeio = false` and stores
the source `IOStream` external as the holder owner, so stream-backed fonts
(including const-mem streams over a Lean `ByteArray`) keep their source alive by
reference count. `Font.copy` shares the original's font data source, so the copy
holds an owned ref to the original font external (see `Font.copy`).

`addFallbackFont` does NOT retain the fallback: the caller must keep the
fallback font alive while it is set (documented caveat, same class as the GPU
bind rule).

Strings always cross with an explicit byte length, never NUL-scanned. `Color`
arguments are passed flattened (four `UInt8`s) and rebuilt into an `SDL_Color`
in C. Multi-value results come back through `@[export]`ed Lean makers.

Skipped: nothing in the 70-function core inventory.
-/

namespace Sdl.Ttf

open Sdl (Color Surface Properties IOStream)

/-! ## Enums and flags -/

/-- Direction to be used for text shaping. The values match HarfBuzz's
`hb_direction_t`. `invalid` is a legitimate state: fonts default to it.
C: `TTF_Direction`. -/
sdl_enum Direction : UInt32 where
  | invalid => 0  -- C: TTF_DIRECTION_INVALID
  | ltr     => 4  -- C: TTF_DIRECTION_LTR (left to right)
  | rtl     => 5  -- C: TTF_DIRECTION_RTL (right to left)
  | ttb     => 6  -- C: TTF_DIRECTION_TTB (top to bottom)
  | btt     => 7  -- C: TTF_DIRECTION_BTT (bottom to top)

/-- Level of hinting applied to font rendering. Despite the C name
`TTF_HintingFlags`, this is a plain enum, not a bit field; `TTF_HINTING_INVALID`
is `-1` (surfaced here as `0xFFFFFFFF`). C: `TTF_HintingFlags`. -/
sdl_enum Hinting : UInt32 where
  | invalid       => 0xFFFFFFFF  -- C: TTF_HINTING_INVALID (-1)
  | normal        => 0           -- C: TTF_HINTING_NORMAL (standard grid-fitting)
  | light         => 1           -- C: TTF_HINTING_LIGHT
  | mono          => 2           -- C: TTF_HINTING_MONO
  | none          => 3           -- C: TTF_HINTING_NONE
  | lightSubpixel => 4           -- C: TTF_HINTING_LIGHT_SUBPIXEL

/-- Horizontal alignment used when rendering wrapped text.
C: `TTF_HorizontalAlignment`. -/
sdl_enum HorizontalAlignment : UInt32 where
  | invalid => 0xFFFFFFFF  -- C: TTF_HORIZONTAL_ALIGN_INVALID (-1)
  | left    => 0           -- C: TTF_HORIZONTAL_ALIGN_LEFT
  | center  => 1           -- C: TTF_HORIZONTAL_ALIGN_CENTER
  | right   => 2           -- C: TTF_HORIZONTAL_ALIGN_RIGHT

/-- The type of data in a glyph image. C: `TTF_ImageType`. -/
sdl_enum ImageType : UInt32 where
  | invalid => 0  -- C: TTF_IMAGE_INVALID
  | alpha   => 1  -- C: TTF_IMAGE_ALPHA (color channels are white)
  | color   => 2  -- C: TTF_IMAGE_COLOR (color channels have image data)
  | sdf     => 3  -- C: TTF_IMAGE_SDF (alpha holds signed-distance-field data)

/-- Font style flags, OR'd together. `TTF_STYLE_NORMAL` (`0`) is the
macro-generated empty set `FontStyle.none`. C: `TTF_FontStyleFlags`. -/
sdl_flags FontStyle : UInt32 where
  | bold          := 0x01  -- C: TTF_STYLE_BOLD
  | italic        := 0x02  -- C: TTF_STYLE_ITALIC
  | underline     := 0x04  -- C: TTF_STYLE_UNDERLINE
  | strikethrough := 0x08  -- C: TTF_STYLE_STRIKETHROUGH

/-- A four-character script tag: an [ISO 15924 code](https://unicode.org/iso15924/iso15924-codes.html)
packed big-endian into 32 bits. Build/inspect with `stringToTag`/`tagToString`.
C: the `Uint32` script tags used by `TTF_SetFontScript` etc. -/
sdl_id Script : UInt32

/-! ## Opaque font handle -/

/-- A loaded font at a fixed point size. Owned root, finalizer-only
(`TTF_CloseFont`). C: `TTF_Font`. -/
sdl_opaque Font

@[extern "lean_sdl_ttf_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

/-! ## Makers (C never lays out a Lean structure or tuple) -/

/-- Metrics of a font's glyph, in pixels. C: the out-params of
`TTF_GetGlyphMetrics`. -/
structure GlyphMetrics where
  /-- Minimum x from the left edge of the bounding box (may be negative). -/
  minx : Int32
  /-- Maximum x from the left edge of the bounding box. -/
  maxx : Int32
  /-- Minimum y from the bottom edge of the bounding box (may be negative). -/
  miny : Int32
  /-- Maximum y from the bottom edge of the bounding box. -/
  maxy : Int32
  /-- Distance to the next glyph from the left edge of this glyph's box. -/
  advance : Int32
deriving Repr, BEq, Inhabited

@[export lean_sdl_ttf_mk_glyph_metrics]
private def mkGlyphMetrics (minx maxx miny maxy advance : Int32) : GlyphMetrics :=
  { minx, maxx, miny, maxy, advance }

/-- Maker for an `Int32 × Int32 × Int32` version triple. -/
@[export lean_sdl_ttf_mk_int32_triple]
private def mkInt32Triple (a b c : Int32) : Int32 × Int32 × Int32 := (a, b, c)

/-- Maker for an `Int32 × Int32` pair (DPI, string size). -/
@[export lean_sdl_ttf_mk_int32_pair]
private def mkInt32Pair (a b : Int32) : Int32 × Int32 := (a, b)

/-- Maker for a `measureString` result: `(measured_width, measured_length)`,
where the byte length crosses as a `USize`. -/
@[export lean_sdl_ttf_mk_measure]
private def mkMeasure (width : Int32) (length : USize) : Int32 × Nat :=
  (width, length.toNat)

/-- Maker pairing a rendered/queried glyph `Surface` with its `ImageType`. -/
@[export lean_sdl_ttf_mk_glyph_image]
private def mkGlyphImage (surf : Surface) (rawType : UInt32) : Surface × ImageType :=
  (surf, (ImageType.ofVal? rawType).getD .invalid)

/-! ## Init and version -/

/-- The version of the dynamically linked SDL_ttf library, as
`SDL_VERSIONNUM(major, minor, micro)`. C: `TTF_Version`. -/
@[extern "lean_sdl_ttf_version"]
opaque version : IO Int32

@[extern "lean_sdl_ttf_get_freetype_version"]
private opaque getFreeTypeVersionRaw : IO (Int32 × Int32 × Int32)

/-- The `(major, minor, patch)` version of the FreeType library in use.
`init` should have run first (it reports `0.0.0` otherwise).
C: `TTF_GetFreeTypeVersion`. -/
def getFreeTypeVersion : IO (Int32 × Int32 × Int32) := getFreeTypeVersionRaw

/-- The `(major, minor, patch)` version of the HarfBuzz library in use, or
`(0, 0, 0)` if HarfBuzz is not available. C: `TTF_GetHarfBuzzVersion`. -/
@[extern "lean_sdl_ttf_get_harfbuzz_version"]
opaque getHarfBuzzVersion : IO (Int32 × Int32 × Int32)

/-- Initialize SDL_ttf. Safe to call more than once; each successful call should
be paired with a `quit`. Throws on failure. C: `TTF_Init`. -/
@[extern "lean_sdl_ttf_init"]
opaque init : IO Unit

/-- Deinitialize SDL_ttf (decrements the init refcount). C: `TTF_Quit`. -/
@[extern "lean_sdl_ttf_quit"]
opaque quit : IO Unit

/-- The current init refcount (number of successful `init` calls not yet paired
with a `quit`). C: `TTF_WasInit`. -/
@[extern "lean_sdl_ttf_was_init"]
opaque wasInit : IO Int32

/-! ## Opening fonts -/

/-- Open a font from a file at a given point size. C: `TTF_OpenFont`. -/
@[extern "lean_sdl_ttf_open_font"]
opaque openFont (file : @& String) (ptsize : Float32) : IO Font

/-- Open a font from an `IOStream` at a given point size. The stream is never
auto-closed (`closeio = false`); the returned font keeps an owned reference to
`src` (and transitively its backing `ByteArray` for a const-mem stream), so the
source outlives the font. C: `TTF_OpenFontIO`. -/
@[extern "lean_sdl_ttf_open_font_io"]
opaque openFontIO (src : @& IOStream) (ptsize : Float32) : IO Font

/-- Open a font from a property set (`Props.create*` keys). An `IOStream`-backed
property set must outlive the font; prefer `openFontIO`, which manages that
lifetime for you. C: `TTF_OpenFontWithProperties`. -/
@[extern "lean_sdl_ttf_open_font_with_properties"]
opaque openFontWithProperties (props : @& Properties) : IO Font

/-! ## Script tags -/

@[extern "lean_sdl_ttf_string_to_tag"]
private opaque stringToTagRaw (s : @& String) : UInt32

/-- Pack a 4-character string into a 32-bit script tag. C: `TTF_StringToTag`. -/
def stringToTag (s : String) : Script := ⟨stringToTagRaw s⟩

@[extern "lean_sdl_ttf_tag_to_string"]
private opaque tagToStringRaw (tag : UInt32) : String

/-- Unpack a 32-bit script tag into its 4-character string. C: `TTF_TagToString`. -/
def tagToString (tag : Script) : String := tagToStringRaw tag.val

@[extern "lean_sdl_ttf_get_glyph_script"]
private opaque getGlyphScriptRaw (ch : UInt32) : IO UInt32

/-- The script (ISO 15924) used by a codepoint. Throws on failure.
C: `TTF_GetGlyphScript`. -/
def getGlyphScript (ch : Char) : IO Script := do
  return ⟨← getGlyphScriptRaw ch.val⟩

namespace Font

/-! ## Font attributes -/

/-- The properties associated with a font (read-write outline properties).
Borrowed: tied to the font's lifetime, never destroyed from Lean.
C: `TTF_GetFontProperties`. -/
@[extern "lean_sdl_ttf_get_font_properties"]
opaque properties (self : @& Font) : IO Properties

/-- The font generation, incremented whenever a change requires rebuilding
glyphs (style, size, …). Throws on failure. C: `TTF_GetFontGeneration`. -/
@[extern "lean_sdl_ttf_get_font_generation"]
opaque generation (self : @& Font) : IO UInt32

/-- Add a fallback font, used for glyphs the current font lacks (in add order).
SDL_ttf does NOT retain `fallback`: keep it reachable in Lean for as long as it
stays set on `font`, or later glyph lookups dereference freed memory.
C: `TTF_AddFallbackFont`. -/
@[extern "lean_sdl_ttf_add_fallback_font"]
opaque addFallbackFont (font fallback : @& Font) : IO Unit

/-- Remove a previously added fallback font. C: `TTF_RemoveFallbackFont`. -/
@[extern "lean_sdl_ttf_remove_fallback_font"]
opaque removeFallbackFont (font fallback : @& Font) : IO Unit

/-- Remove all fallback fonts. C: `TTF_ClearFallbackFonts`. -/
@[extern "lean_sdl_ttf_clear_fallback_fonts"]
opaque clearFallbackFonts (self : @& Font) : IO Unit

/-- Resize the font dynamically. C: `TTF_SetFontSize`. -/
@[extern "lean_sdl_ttf_set_font_size"]
opaque setSize (self : @& Font) (ptsize : Float32) : IO Unit

/-- Resize the font with target resolutions, in dots per inch.
C: `TTF_SetFontSizeDPI`. -/
@[extern "lean_sdl_ttf_set_font_size_dpi"]
opaque setSizeDPI (self : @& Font) (ptsize : Float32) (hdpi vdpi : Int32) : IO Unit

/-- The font's point size. Throws on failure. C: `TTF_GetFontSize`. -/
@[extern "lean_sdl_ttf_get_font_size"]
opaque size (self : @& Font) : IO Float32

/-- The font's `(horizontal, vertical)` target DPI. C: `TTF_GetFontDPI`. -/
@[extern "lean_sdl_ttf_get_font_dpi"]
opaque dpi (self : @& Font) : IO (Int32 × Int32)

@[extern "lean_sdl_ttf_set_font_style"]
private opaque setStyleRaw (self : @& Font) (style : UInt32) : IO Unit

/-- Set the font's style flags. C: `TTF_SetFontStyle`. -/
def setStyle (self : @& Font) (style : FontStyle) : IO Unit := setStyleRaw self style.val

@[extern "lean_sdl_ttf_get_font_style"]
private opaque getStyleRaw (self : @& Font) : IO UInt32

/-- The font's current style flags. C: `TTF_GetFontStyle`. -/
def style (self : @& Font) : IO FontStyle := do return ⟨← getStyleRaw self⟩

/-- Set the font's outline (`0` to disable). Throws on failure.
C: `TTF_SetFontOutline`. -/
@[extern "lean_sdl_ttf_set_font_outline"]
opaque setOutline (self : @& Font) (outline : Int32) : IO Unit

/-- The font's current outline value. C: `TTF_GetFontOutline`. -/
@[extern "lean_sdl_ttf_get_font_outline"]
opaque outline (self : @& Font) : IO Int32

@[extern "lean_sdl_ttf_set_font_hinting"]
private opaque setHintingRaw (self : @& Font) (hinting : UInt32) : IO Unit

/-- Set the font's hinter. C: `TTF_SetFontHinting`. -/
def setHinting (self : @& Font) (hinting : Hinting) : IO Unit :=
  setHintingRaw self hinting.val

@[extern "lean_sdl_ttf_get_font_hinting"]
private opaque getHintingRaw (self : @& Font) : IO UInt32

/-- The font's current hinter (`.invalid` if the font is invalid).
C: `TTF_GetFontHinting`. -/
def hinting (self : @& Font) : IO Hinting := do
  return (Hinting.ofVal? (← getHintingRaw self)).getD .invalid

/-- The number of FreeType font faces. C: `TTF_GetNumFontFaces`. -/
@[extern "lean_sdl_ttf_get_num_font_faces"]
opaque numFaces (self : @& Font) : IO Int32

/-- Enable or disable Signed Distance Field rendering. Throws on failure.
C: `TTF_SetFontSDF`. -/
@[extern "lean_sdl_ttf_set_font_sdf"]
opaque setSDF (self : @& Font) (enabled : Bool) : IO Unit

/-- Whether SDF rendering is enabled. C: `TTF_GetFontSDF`. -/
@[extern "lean_sdl_ttf_get_font_sdf"]
opaque sdf (self : @& Font) : IO Bool

/-- The font's weight (lightness/heaviness of the strokes). C: `TTF_GetFontWeight`. -/
@[extern "lean_sdl_ttf_get_font_weight"]
opaque weight (self : @& Font) : IO Int32

@[extern "lean_sdl_ttf_set_font_wrap_alignment"]
private opaque setWrapAlignmentRaw (self : @& Font) (align : UInt32) : IO Unit

/-- Set the wrap alignment for wrapped text. C: `TTF_SetFontWrapAlignment`. -/
def setWrapAlignment (self : @& Font) (align : HorizontalAlignment) : IO Unit :=
  setWrapAlignmentRaw self align.val

@[extern "lean_sdl_ttf_get_font_wrap_alignment"]
private opaque getWrapAlignmentRaw (self : @& Font) : IO UInt32

/-- The current wrap alignment. C: `TTF_GetFontWrapAlignment`. -/
def wrapAlignment (self : @& Font) : IO HorizontalAlignment := do
  return (HorizontalAlignment.ofVal? (← getWrapAlignmentRaw self)).getD .invalid

/-- The total height of the font (usually the point size). C: `TTF_GetFontHeight`. -/
@[extern "lean_sdl_ttf_get_font_height"]
opaque height (self : @& Font) : IO Int32

/-- The offset from the baseline to the top of the font (positive).
C: `TTF_GetFontAscent`. -/
@[extern "lean_sdl_ttf_get_font_ascent"]
opaque ascent (self : @& Font) : IO Int32

/-- The offset from the baseline to the bottom of the font (negative).
C: `TTF_GetFontDescent`. -/
@[extern "lean_sdl_ttf_get_font_descent"]
opaque descent (self : @& Font) : IO Int32

/-- Set the spacing between lines of text. C: `TTF_SetFontLineSkip`. -/
@[extern "lean_sdl_ttf_set_font_line_skip"]
opaque setLineSkip (self : @& Font) (lineskip : Int32) : IO Unit

/-- The recommended spacing between lines of text. C: `TTF_GetFontLineSkip`. -/
@[extern "lean_sdl_ttf_get_font_line_skip"]
opaque lineSkip (self : @& Font) : IO Int32

/-- Enable or disable kerning (enabled by default). C: `TTF_SetFontKerning`. -/
@[extern "lean_sdl_ttf_set_font_kerning"]
opaque setKerning (self : @& Font) (enabled : Bool) : IO Unit

/-- Whether kerning is enabled. C: `TTF_GetFontKerning`. -/
@[extern "lean_sdl_ttf_get_font_kerning"]
opaque kerning (self : @& Font) : IO Bool

/-- Whether the font is fixed-width. C: `TTF_FontIsFixedWidth`. -/
@[extern "lean_sdl_ttf_font_is_fixed_width"]
opaque isFixedWidth (self : @& Font) : IO Bool

/-- Whether the font is scalable (outline vs. bitmap). C: `TTF_FontIsScalable`. -/
@[extern "lean_sdl_ttf_font_is_scalable"]
opaque isScalable (self : @& Font) : IO Bool

/-- The font's family name (empty string if unavailable). C: `TTF_GetFontFamilyName`. -/
@[extern "lean_sdl_ttf_get_font_family_name"]
opaque familyName (self : @& Font) : IO String

/-- The font's style name (empty string if unavailable). C: `TTF_GetFontStyleName`. -/
@[extern "lean_sdl_ttf_get_font_style_name"]
opaque styleName (self : @& Font) : IO String

@[extern "lean_sdl_ttf_set_font_direction"]
private opaque setDirectionRaw (self : @& Font) (direction : UInt32) : IO Unit

/-- Set the text-shaping direction. Throws on failure (e.g. a non-LTR direction
without HarfBuzz support). C: `TTF_SetFontDirection`. -/
def setDirection (self : @& Font) (direction : Direction) : IO Unit :=
  setDirectionRaw self direction.val

@[extern "lean_sdl_ttf_get_font_direction"]
private opaque getDirectionRaw (self : @& Font) : IO UInt32

/-- The text-shaping direction (`.invalid` if unset). C: `TTF_GetFontDirection`. -/
def direction (self : @& Font) : IO Direction := do
  return (Direction.ofVal? (← getDirectionRaw self)).getD .invalid

@[extern "lean_sdl_ttf_set_font_script"]
private opaque setScriptRaw (self : @& Font) (script : UInt32) : IO Unit

/-- Set the text-shaping script (ISO 15924). Throws on failure (e.g. without
HarfBuzz support). C: `TTF_SetFontScript`. -/
def setScript (self : @& Font) (script : Script) : IO Unit := setScriptRaw self script.val

@[extern "lean_sdl_ttf_get_font_script"]
private opaque getScriptRaw (self : @& Font) : IO UInt32

/-- The text-shaping script (`⟨0⟩` if unset). C: `TTF_GetFontScript`. -/
def script (self : @& Font) : IO Script := do return ⟨← getScriptRaw self⟩

/-- Set the text-shaping language (a BCP47 code), or `""` to reset. Throws on
failure (e.g. without HarfBuzz support). C: `TTF_SetFontLanguage`. -/
@[extern "lean_sdl_ttf_set_font_language"]
opaque setLanguage (self : @& Font) (bcp47 : @& String) : IO Unit

/-! ## Glyphs -/

@[extern "lean_sdl_ttf_font_has_glyph"]
private opaque hasGlyphRaw (self : @& Font) (ch : UInt32) : IO Bool

/-- Whether the font provides a glyph for a codepoint. C: `TTF_FontHasGlyph`. -/
def hasGlyph (self : @& Font) (ch : Char) : IO Bool := hasGlyphRaw self ch.val

@[extern "lean_sdl_ttf_get_glyph_image"]
private opaque glyphImageRaw (self : @& Font) (ch : UInt32) : IO (Surface × ImageType)

/-- The pixel image (and its `ImageType`) for a codepoint. Throws on failure.
C: `TTF_GetGlyphImage`. -/
def glyphImage (self : @& Font) (ch : Char) : IO (Surface × ImageType) :=
  glyphImageRaw self ch.val

/-- The pixel image (and its `ImageType`) for a glyph index (useful to text
engines). Throws on failure. C: `TTF_GetGlyphImageForIndex`. -/
@[extern "lean_sdl_ttf_get_glyph_image_for_index"]
opaque glyphImageForIndex (self : @& Font) (glyphIndex : UInt32) : IO (Surface × ImageType)

@[extern "lean_sdl_ttf_get_glyph_metrics"]
private opaque glyphMetricsRaw (self : @& Font) (ch : UInt32) : IO GlyphMetrics

/-- The metrics of the font's glyph for a codepoint. Throws on failure.
C: `TTF_GetGlyphMetrics`. -/
def glyphMetrics (self : @& Font) (ch : Char) : IO GlyphMetrics := glyphMetricsRaw self ch.val

@[extern "lean_sdl_ttf_get_glyph_kerning"]
private opaque glyphKerningRaw (self : @& Font) (previousCh ch : UInt32) : IO Int32

/-- The kerning, in pixels, between two glyphs. Throws on failure.
C: `TTF_GetGlyphKerning`. -/
def glyphKerning (self : @& Font) (prev ch : Char) : IO Int32 :=
  glyphKerningRaw self prev.val ch.val

/-! ## Measurement -/

/-- The `(width, height)` in pixels a string would take to render (no wrapping).
Throws on failure. C: `TTF_GetStringSize`. -/
@[extern "lean_sdl_ttf_get_string_size"]
opaque stringSize (self : @& Font) (text : @& String) : IO (Int32 × Int32)

/-- The `(width, height)` in pixels a string would take to render, wrapped to
`wrapWidth` pixels (`0` wraps only on newlines). Throws on failure.
C: `TTF_GetStringSizeWrapped`. -/
@[extern "lean_sdl_ttf_get_string_size_wrapped"]
opaque stringSizeWrapped (self : @& Font) (text : @& String) (wrapWidth : Int32) :
  IO (Int32 × Int32)

/-- How much of a string fits in `maxWidth` pixels (`0` for unbounded): the
`(measured_width_px, measured_length_bytes)`. Throws on failure.
C: `TTF_MeasureString`. -/
@[extern "lean_sdl_ttf_measure_string"]
opaque measureString (self : @& Font) (text : @& String) (maxWidth : Int32) : IO (Int32 × Nat)

/-! ## Rendering to a surface

Each renderer returns a newly allocated owned `Surface`. `Solid`/`Shaded`
produce `index8` (palettized) surfaces; `Blended`/`LCD` produce `argb8888`. -/

@[extern "lean_sdl_ttf_render_text_solid"]
private opaque renderSolidRaw (self : @& Font) (text : @& String)
  (r g b a : UInt8) : IO Surface

/-- Render text at fast quality to a new 8-bit surface. C: `TTF_RenderText_Solid`. -/
def renderSolid (self : @& Font) (text : String) (fg : Color) : IO Surface :=
  renderSolidRaw self text fg.r fg.g fg.b fg.a

@[extern "lean_sdl_ttf_render_text_solid_wrapped"]
private opaque renderSolidWrappedRaw (self : @& Font) (text : @& String)
  (r g b a : UInt8) (wrapLength : Int32) : IO Surface

/-- Render word-wrapped text at fast quality to a new 8-bit surface (`wrapLength`
`0` wraps only on newlines). C: `TTF_RenderText_Solid_Wrapped`. -/
def renderSolidWrapped (self : @& Font) (text : String) (fg : Color) (wrapLength : Int32) :
    IO Surface :=
  renderSolidWrappedRaw self text fg.r fg.g fg.b fg.a wrapLength

@[extern "lean_sdl_ttf_render_glyph_solid"]
private opaque renderGlyphSolidRaw (self : @& Font) (ch : UInt32)
  (r g b a : UInt8) : IO Surface

/-- Render a single glyph at fast quality to a new 8-bit surface.
C: `TTF_RenderGlyph_Solid`. -/
def renderGlyphSolid (self : @& Font) (ch : Char) (fg : Color) : IO Surface :=
  renderGlyphSolidRaw self ch.val fg.r fg.g fg.b fg.a

@[extern "lean_sdl_ttf_render_text_shaded"]
private opaque renderShadedRaw (self : @& Font) (text : @& String)
  (fr fg fb fa br bg bb ba : UInt8) : IO Surface

/-- Render text at high quality onto an opaque background to a new 8-bit surface.
C: `TTF_RenderText_Shaded`. -/
def renderShaded (self : @& Font) (text : String) (fg bg : Color) : IO Surface :=
  renderShadedRaw self text fg.r fg.g fg.b fg.a bg.r bg.g bg.b bg.a

@[extern "lean_sdl_ttf_render_text_shaded_wrapped"]
private opaque renderShadedWrappedRaw (self : @& Font) (text : @& String)
  (fr fg fb fa br bg bb ba : UInt8) (wrapWidth : Int32) : IO Surface

/-- Render word-wrapped text at high quality onto an opaque background.
C: `TTF_RenderText_Shaded_Wrapped`. -/
def renderShadedWrapped (self : @& Font) (text : String) (fg bg : Color)
    (wrapWidth : Int32) : IO Surface :=
  renderShadedWrappedRaw self text fg.r fg.g fg.b fg.a bg.r bg.g bg.b bg.a wrapWidth

@[extern "lean_sdl_ttf_render_glyph_shaded"]
private opaque renderGlyphShadedRaw (self : @& Font) (ch : UInt32)
  (fr fg fb fa br bg bb ba : UInt8) : IO Surface

/-- Render a single glyph at high quality onto an opaque background.
C: `TTF_RenderGlyph_Shaded`. -/
def renderGlyphShaded (self : @& Font) (ch : Char) (fg bg : Color) : IO Surface :=
  renderGlyphShadedRaw self ch.val fg.r fg.g fg.b fg.a bg.r bg.g bg.b bg.a

@[extern "lean_sdl_ttf_render_text_blended"]
private opaque renderBlendedRaw (self : @& Font) (text : @& String)
  (r g b a : UInt8) : IO Surface

/-- Render text at high quality to a new ARGB surface with alpha blending.
C: `TTF_RenderText_Blended`. -/
def renderBlended (self : @& Font) (text : String) (fg : Color) : IO Surface :=
  renderBlendedRaw self text fg.r fg.g fg.b fg.a

@[extern "lean_sdl_ttf_render_text_blended_wrapped"]
private opaque renderBlendedWrappedRaw (self : @& Font) (text : @& String)
  (r g b a : UInt8) (wrapWidth : Int32) : IO Surface

/-- Render word-wrapped text at high quality to a new ARGB surface.
C: `TTF_RenderText_Blended_Wrapped`. -/
def renderBlendedWrapped (self : @& Font) (text : String) (fg : Color) (wrapWidth : Int32) :
    IO Surface :=
  renderBlendedWrappedRaw self text fg.r fg.g fg.b fg.a wrapWidth

@[extern "lean_sdl_ttf_render_glyph_blended"]
private opaque renderGlyphBlendedRaw (self : @& Font) (ch : UInt32)
  (r g b a : UInt8) : IO Surface

/-- Render a single glyph at high quality to a new ARGB surface.
C: `TTF_RenderGlyph_Blended`. -/
def renderGlyphBlended (self : @& Font) (ch : Char) (fg : Color) : IO Surface :=
  renderGlyphBlendedRaw self ch.val fg.r fg.g fg.b fg.a

@[extern "lean_sdl_ttf_render_text_lcd"]
private opaque renderLCDRaw (self : @& Font) (text : @& String)
  (fr fg fb fa br bg bb ba : UInt8) : IO Surface

/-- Render text at LCD-subpixel quality onto an opaque background.
C: `TTF_RenderText_LCD`. -/
def renderLCD (self : @& Font) (text : String) (fg bg : Color) : IO Surface :=
  renderLCDRaw self text fg.r fg.g fg.b fg.a bg.r bg.g bg.b bg.a

@[extern "lean_sdl_ttf_render_text_lcd_wrapped"]
private opaque renderLCDWrappedRaw (self : @& Font) (text : @& String)
  (fr fg fb fa br bg bb ba : UInt8) (wrapWidth : Int32) : IO Surface

/-- Render word-wrapped text at LCD-subpixel quality onto an opaque background.
C: `TTF_RenderText_LCD_Wrapped`. -/
def renderLCDWrapped (self : @& Font) (text : String) (fg bg : Color)
    (wrapWidth : Int32) : IO Surface :=
  renderLCDWrappedRaw self text fg.r fg.g fg.b fg.a bg.r bg.g bg.b bg.a wrapWidth

@[extern "lean_sdl_ttf_render_glyph_lcd"]
private opaque renderGlyphLCDRaw (self : @& Font) (ch : UInt32)
  (fr fg fb fa br bg bb ba : UInt8) : IO Surface

/-- Render a single glyph at LCD-subpixel quality onto an opaque background.
C: `TTF_RenderGlyph_LCD`. -/
def renderGlyphLCD (self : @& Font) (ch : Char) (fg bg : Color) : IO Surface :=
  renderGlyphLCDRaw self ch.val fg.r fg.g fg.b fg.a bg.r bg.g bg.b bg.a

/-- Create a copy of a font, distinct from the original but sharing its font
data source. Because the copy shares the source, it holds an owned reference to
the original font external for its whole life. C: `TTF_CopyFont`. -/
@[extern "lean_sdl_ttf_copy_font"]
opaque copy (self : @& Font) : IO Font

end Font

/-! ## Font-creation and outline properties -/

namespace Props

/-- The font file to open, when not using an `IOStream`.
C: `TTF_PROP_FONT_CREATE_FILENAME_STRING`. -/
def createFilename : String := "SDL_ttf.font.create.filename"
/-- An `SDL_IOStream` containing the font to open (keep open until the font is
closed). C: `TTF_PROP_FONT_CREATE_IOSTREAM_POINTER`. -/
def createIostream : String := "SDL_ttf.font.create.iostream"
/-- The offset in the iostream where the font begins (defaults to `0`).
C: `TTF_PROP_FONT_CREATE_IOSTREAM_OFFSET_NUMBER`. -/
def createIostreamOffset : String := "SDL_ttf.font.create.iostream.offset"
/-- Whether closing the font also closes the associated iostream.
C: `TTF_PROP_FONT_CREATE_IOSTREAM_AUTOCLOSE_BOOLEAN`. -/
def createIostreamAutoclose : String := "SDL_ttf.font.create.iostream.autoclose"
/-- The point size of the font. C: `TTF_PROP_FONT_CREATE_SIZE_FLOAT`. -/
def createSize : String := "SDL_ttf.font.create.size"
/-- The face index, if the font contains multiple faces.
C: `TTF_PROP_FONT_CREATE_FACE_NUMBER`. -/
def createFace : String := "SDL_ttf.font.create.face"
/-- The horizontal DPI for rendering (defaults to the vertical DPI or `72`).
C: `TTF_PROP_FONT_CREATE_HORIZONTAL_DPI_NUMBER`. -/
def createHorizontalDpi : String := "SDL_ttf.font.create.hdpi"
/-- The vertical DPI for rendering (defaults to the horizontal DPI or `72`).
C: `TTF_PROP_FONT_CREATE_VERTICAL_DPI_NUMBER`. -/
def createVerticalDpi : String := "SDL_ttf.font.create.vdpi"
/-- An existing `TTF_Font` used as the data source and initial size/style.
C: `TTF_PROP_FONT_CREATE_EXISTING_FONT`. -/
def createExistingFont : String := "SDL_ttf.font.create.existing_font"

/-- The `FT_Stroker_LineCap` used when setting the font outline (defaults to
`FT_STROKER_LINECAP_ROUND`). C: `TTF_PROP_FONT_OUTLINE_LINE_CAP_NUMBER`. -/
def outlineLineCap : String := "SDL_ttf.font.outline.line_cap"
/-- The `FT_Stroker_LineJoin` used when setting the font outline (defaults to
`FT_STROKER_LINEJOIN_ROUND`). C: `TTF_PROP_FONT_OUTLINE_LINE_JOIN_NUMBER`. -/
def outlineLineJoin : String := "SDL_ttf.font.outline.line_join"
/-- The `FT_Fixed` miter limit used when setting the font outline (defaults to
`0`). C: `TTF_PROP_FONT_OUTLINE_MITER_LIMIT_NUMBER`. -/
def outlineMiterLimit : String := "SDL_ttf.font.outline.miter_limit"

end Props

end Sdl.Ttf
