import Sdl.Ttf
import Sdl.Render
import Sdl.Gpu
import Sdl.Rect

/-!
# SDL_ttf text engines and `TTF_Text` (`SDL3_ttf/SDL_ttf.h` + `SDL_textengine.h`)

The text-engine half of SDL_ttf 3.2.2: the three `TTF_TextEngine` kinds
(surface / renderer / GPU), `TTF_Text` objects with editing / layout /
substring queries / draws, and the GPU draw-data decode. Builds on
`Sdl/Ttf.lean` (namespace `Sdl.Ttf`: `Font`, `Direction`, `ImageType`,
`Script`).

**TextEngine** is one Lean type backed by three external classes (surface /
renderer / GPU), each finalizing with its own `TTF_Destroy*TextEngine`. A
surface engine has no owner; a renderer engine owns an inc'd `Renderer`
external; a GPU engine owns an inc'd `Gpu.Device` external. The
`*WithProperties` creators cannot recover their creator from the props bag, so
they own the inc'd `Properties` external instead and document that the renderer
/ device inside those props must outlive the engine. Engines are finalizer-only
(no manual destroy — `Text` objects reference them). The GPU-only shims
(`setGpuWinding` / `gpuWinding`) class-check and throw on a non-GPU engine;
every generic shim reads the holder pointer uniformly.

**Text** is an owned child whose holder owner is a 2-field Lean pair
`(engineExt, fontExt)`, so a live `Text` pins BOTH its engine and its font by
reference count. `setEngine` / `setFont` rebuild the pair (keep one field, swap
the other; dec the old pair). `engine` / `font` return the pair's stored
externals — identity-preserving, no wrap-from-raw. `Text.destroy` is exposed
(leaf: NULLs the pointer; every other shim throws after that).

`SubString` decodes through an `@[export]` Lean maker (events precedent); its
`flags.direction` reads the low byte as a `Direction`. `subStringsForRange`
copies the C array then frees it with a single `SDL_free` (the substrings live
in one allocation, per the header). `gpuDrawData` walks the `next` linked list
and copies everything eagerly, since the C data is invalidated by the next text
update; the atlas `Gpu.Texture` is a borrowed wrap owned by the `Text` (which
transitively keeps the engine, hence the atlas, alive).

Strings always cross with an explicit byte length; text-edit offsets/lengths
are BYTE offsets (`Int32`, negative counting from the end per the C docs).
-/

namespace Sdl.Ttf

open Sdl (Color FColor Rect Properties Renderer Surface)

/-! ## Enums and flags -/

/-- The winding order of the vertices returned by the GPU text engine's draw
data. C: `TTF_GPUTextEngineWinding`. -/
sdl_enum GpuTextEngineWinding : UInt32 where
  | invalid          => 0xFFFFFFFF  -- C: TTF_GPU_TEXTENGINE_WINDING_INVALID (-1)
  | clockwise        => 0           -- C: TTF_GPU_TEXTENGINE_WINDING_CLOCKWISE
  | counterClockwise => 1           -- C: TTF_GPU_TEXTENGINE_WINDING_COUNTER_CLOCKWISE

/-- Flags describing a `SubString`. The low byte (`TTF_SUBSTRING_DIRECTION_MASK`)
holds the flow `Direction`; the named bits mark whether the substring contains
the start/end of the text or of its line. C: `TTF_SubStringFlags`. -/
sdl_flags SubStringFlags : UInt32 where
  | textStart := 0x100  -- C: TTF_SUBSTRING_TEXT_START
  | lineStart := 0x200  -- C: TTF_SUBSTRING_LINE_START
  | lineEnd   := 0x400  -- C: TTF_SUBSTRING_LINE_END
  | textEnd   := 0x800  -- C: TTF_SUBSTRING_TEXT_END

/-- The flow `Direction` of a substring, decoded from the low byte
(`TTF_SUBSTRING_DIRECTION_MASK` `0xFF`); an unrecognized value maps to
`.invalid`. -/
def SubStringFlags.direction (f : SubStringFlags) : Direction :=
  (Direction.ofVal? (f.val &&& 0xFF)).getD .invalid

#guard (SubStringFlags.mk 0x104).direction == .ltr        -- LTR (4) in the low byte
#guard (SubStringFlags.mk 0x104).has .textStart           -- text-start bit set
#guard (SubStringFlags.mk 0x805).direction == .rtl        -- RTL (5), text-end set
#guard (SubStringFlags.mk 0x805).has .textEnd
#guard (SubStringFlags.mk 0x000).direction == .invalid

/-! ## Makers (C never lays out a Lean structure) -/

/-- The location and metadata of a substring within a `Text`. C: `TTF_SubString`
(the out-param of `TTF_GetTextSubString` and friends). -/
structure SubString where
  /-- Flags for this substring (flow direction + start/end markers). -/
  flags : SubStringFlags
  /-- The byte offset from the beginning of the text. -/
  offset : Int32
  /-- The byte length starting at `offset`. -/
  length : Int32
  /-- The index of the line that contains this substring. -/
  lineIndex : Int32
  /-- The internal cluster index (for quick iteration). -/
  clusterIndex : Int32
  /-- The rectangle, relative to the top-left of the text, containing the
  substring. -/
  rect : Rect
deriving Repr, BEq, Inhabited

@[export lean_sdl_ttf_mk_substring]
private def mkSubString (flags : UInt32) (offset length lineIndex clusterIndex : Int32)
    (rx ry rw rh : Int32) : SubString :=
  { flags := ⟨flags⟩, offset, length, lineIndex, clusterIndex,
    rect := ⟨rx, ry, rw, rh⟩ }

/-- One atlas draw sequence produced by the GPU text engine: a snapshot copied
eagerly out of SDL's `TTF_GPUAtlasDrawSequence` linked list. The number of
vertices is `xy.size / 2` (each vertex is an `(x, y)` pair, likewise `uv`).
C: `TTF_GPUAtlasDrawSequence`. -/
structure AtlasDrawSequence where
  /-- The glyph atlas texture (a borrowed `Gpu.Texture` owned by the engine; the
  wrap keeps the `Text`, hence the engine, alive). Do not `release` it. -/
  atlasTexture : Gpu.Texture
  /-- Vertex positions, flattened as `2 * numVertices` `Float`s (`x, y, …`). -/
  xy : FloatArray
  /-- Normalized texture coordinates, flattened as `2 * numVertices` `Float`s. -/
  uv : FloatArray
  /-- Indices into the vertex arrays. -/
  indices : Array Int32
  /-- The image type of this draw sequence. -/
  imageType : ImageType

@[export lean_sdl_ttf_mk_atlas_draw_sequence]
private def mkAtlasDrawSequence (atlasTexture : Gpu.Texture) (xy uv : FloatArray)
    (indices : Array Int32) (rawType : UInt32) : AtlasDrawSequence :=
  { atlasTexture, xy, uv, indices, imageType := (ImageType.ofVal? rawType).getD .invalid }

/-! ## Opaque handles -/

/-- A text engine that lays out and draws `Text` objects. One Lean type over
three backends (surface / renderer / GPU); finalizer-only (Texts reference it).
C: `TTF_TextEngine`. -/
sdl_opaque TextEngine

/-- A laid-out, editable text object bound to an engine and a font. Owned child
of the `(engine, font)` pair; a manual `destroy` is exposed. C: `TTF_Text`. -/
sdl_opaque Text

@[extern "lean_sdl_ttf_text_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

/-! ## Engine creation and configuration -/

/-- Create a text engine for drawing text onto `Surface`s. Works with no
`Sdl.init`. Throws on failure. C: `TTF_CreateSurfaceTextEngine`. -/
@[extern "lean_sdl_ttf_create_surface_text_engine"]
opaque createSurfaceTextEngine : IO TextEngine

/-- Create a text engine for drawing text with an SDL `Renderer`. The engine
keeps an owned reference to `r`. Throws on failure.
C: `TTF_CreateRendererTextEngine`. -/
@[extern "lean_sdl_ttf_create_renderer_text_engine"]
opaque createRendererTextEngine (r : @& Renderer) : IO TextEngine

/-- Create a renderer text engine from a properties bag (see the `Props`
namespace). Because the renderer cannot be recovered from the props bag, the
engine keeps an owned reference to `props` instead; the renderer stored in
`props` must outlive the engine. Throws on failure.
C: `TTF_CreateRendererTextEngineWithProperties`. -/
@[extern "lean_sdl_ttf_create_renderer_text_engine_with_properties"]
opaque createRendererTextEngineWithProperties (props : @& Properties) : IO TextEngine

/-- Create a text engine for drawing text with the SDL GPU API. The engine keeps
an owned reference to `dev`. Throws on failure (no GPU backend under the dummy
driver). C: `TTF_CreateGPUTextEngine`. -/
@[extern "lean_sdl_ttf_create_gpu_text_engine"]
opaque createGpuTextEngine (dev : @& Gpu.Device) : IO TextEngine

/-- Create a GPU text engine from a properties bag (see the `Props` namespace).
Like the renderer variant, the engine owns an inc'd reference to `props`; the
`Gpu.Device` stored in `props` must outlive the engine. Throws on failure.
C: `TTF_CreateGPUTextEngineWithProperties`. -/
@[extern "lean_sdl_ttf_create_gpu_text_engine_with_properties"]
opaque createGpuTextEngineWithProperties (props : @& Properties) : IO TextEngine

namespace TextEngine

@[extern "lean_sdl_ttf_set_gpu_text_engine_winding"]
private opaque setGpuWindingRaw (self : @& TextEngine) (winding : UInt32) : IO Unit

/-- Set the winding order of the vertices in the GPU draw data. Throws if `self`
is not a GPU text engine. C: `TTF_SetGPUTextEngineWinding`. -/
def setGpuWinding (self : @& TextEngine) (winding : GpuTextEngineWinding) : IO Unit :=
  setGpuWindingRaw self winding.val

@[extern "lean_sdl_ttf_get_gpu_text_engine_winding"]
private opaque gpuWindingRaw (self : @& TextEngine) : IO UInt32

/-- The winding order of the vertices in the GPU draw data. Throws if `self` is
not a GPU text engine. C: `TTF_GetGPUTextEngineWinding`. -/
def gpuWinding (self : @& TextEngine) : IO GpuTextEngineWinding := do
  return (GpuTextEngineWinding.ofVal? (← gpuWindingRaw self)).getD .invalid

@[extern "lean_sdl_ttf_create_text"]
private opaque createTextRaw (self : @& TextEngine) (font : @& Font) (text : @& String) :
  IO Text

/-- Create a `Text` object from `text` laid out by `self` in `font`. The
resulting `Text` keeps owned references to both `self` and `font`. Throws on
failure. C: `TTF_CreateText`. -/
def createText (self : @& TextEngine) (font : @& Font) (text : String) : IO Text :=
  createTextRaw self font text

end TextEngine

/-! ## Text draws -/

namespace Text

/-- Draw `self` onto `target` at `(x, y)`. Throws on failure.
C: `TTF_DrawSurfaceText`. -/
@[extern "lean_sdl_ttf_draw_surface_text"]
opaque drawSurface (self : @& Text) (x y : Int32) (target : @& Surface) : IO Unit

/-- Draw `self` with its engine's `Renderer` at `(x, y)`. Throws on failure.
C: `TTF_DrawRendererText`. -/
@[extern "lean_sdl_ttf_draw_renderer_text"]
opaque drawRenderer (self : @& Text) (x y : Float32) : IO Unit

/-- The GPU draw data for `self`: a snapshot of SDL's `TTF_GPUAtlasDrawSequence`
linked list, copied eagerly (the C data is invalidated by the next text
update). Requires the text engine to be a GPU engine. Throws on failure.
C: `TTF_GetGPUTextDrawData`. -/
@[extern "lean_sdl_ttf_get_gpu_text_draw_data"]
opaque gpuDrawData (self : @& Text) : IO (Array AtlasDrawSequence)

/-! ## Text attributes -/

/-- The properties associated with `self` (borrowed; tied to the text's
lifetime, never destroyed from Lean). C: `TTF_GetTextProperties`. -/
@[extern "lean_sdl_ttf_get_text_properties"]
opaque properties (self : @& Text) : IO Properties

/-- Set the text engine used by `self`, rebuilding the owned `(engine, font)`
pair. Throws on failure. C: `TTF_SetTextEngine`. -/
@[extern "lean_sdl_ttf_set_text_engine"]
opaque setEngine (self : @& Text) (e : @& TextEngine) : IO Unit

/-- The text engine used by `self`: the engine external the `Text` already
holds (identity-preserving). C: `TTF_GetTextEngine`. -/
@[extern "lean_sdl_ttf_get_text_engine"]
opaque engine (self : @& Text) : IO TextEngine

/-- Set the font used by `self`, rebuilding the owned `(engine, font)` pair.
Throws on failure. C: `TTF_SetTextFont`. -/
@[extern "lean_sdl_ttf_set_text_font"]
opaque setFont (self : @& Text) (f : @& Font) : IO Unit

/-- The font used by `self`: the font external the `Text` already holds
(identity-preserving). C: `TTF_GetTextFont`. -/
@[extern "lean_sdl_ttf_get_text_font"]
opaque font (self : @& Text) : IO Font

@[extern "lean_sdl_ttf_set_text_direction"]
private opaque setDirectionRaw (self : @& Text) (direction : UInt32) : IO Unit

/-- Set the text-shaping direction of `self`. Throws on failure.
C: `TTF_SetTextDirection`. -/
def setDirection (self : @& Text) (d : Direction) : IO Unit := setDirectionRaw self d.val

@[extern "lean_sdl_ttf_get_text_direction"]
private opaque directionRaw (self : @& Text) : IO UInt32

/-- The text-shaping direction of `self` (`.invalid` if unset).
C: `TTF_GetTextDirection`. -/
def direction (self : @& Text) : IO Direction := do
  return (Direction.ofVal? (← directionRaw self)).getD .invalid

@[extern "lean_sdl_ttf_set_text_script"]
private opaque setScriptRaw (self : @& Text) (script : UInt32) : IO Unit

/-- Set the text-shaping script (ISO 15924) of `self`. Throws on failure.
C: `TTF_SetTextScript`. -/
def setScript (self : @& Text) (s : Script) : IO Unit := setScriptRaw self s.val

@[extern "lean_sdl_ttf_get_text_script"]
private opaque scriptRaw (self : @& Text) : IO UInt32

/-- The text-shaping script of `self` (`⟨0⟩` if unset). C: `TTF_GetTextScript`. -/
def script (self : @& Text) : IO Script := do return ⟨← scriptRaw self⟩

@[extern "lean_sdl_ttf_set_text_color"]
private opaque setColorRaw (self : @& Text) (r g b a : UInt8) : IO Unit

/-- Set the color of `self`. Throws on failure. C: `TTF_SetTextColor`. -/
def setColor (self : @& Text) (c : Color) : IO Unit := setColorRaw self c.r c.g c.b c.a

/-- The color of `self`. Throws on failure. C: `TTF_GetTextColor`. -/
@[extern "lean_sdl_ttf_get_text_color"]
opaque color (self : @& Text) : IO Color

@[extern "lean_sdl_ttf_set_text_color_float"]
private opaque setColorFloatRaw (self : @& Text) (r g b a : Float32) : IO Unit

/-- Set the color of `self` from floating-point components. Throws on failure.
C: `TTF_SetTextColorFloat`. -/
def setColorFloat (self : @& Text) (c : FColor) : IO Unit :=
  setColorFloatRaw self c.r c.g c.b c.a

/-- The color of `self` as floating-point components. Throws on failure.
C: `TTF_GetTextColorFloat`. -/
@[extern "lean_sdl_ttf_get_text_color_float"]
opaque colorFloat (self : @& Text) : IO FColor

/-- Set the position of `self` (the top-left corner of its layout). Throws on
failure. C: `TTF_SetTextPosition`. -/
@[extern "lean_sdl_ttf_set_text_position"]
opaque setPosition (self : @& Text) (x y : Int32) : IO Unit

/-- The `(x, y)` position of `self`. Throws on failure. C: `TTF_GetTextPosition`. -/
@[extern "lean_sdl_ttf_get_text_position"]
opaque position (self : @& Text) : IO (Int32 × Int32)

/-- Set the wrap width of `self` in pixels (`0` wraps only on newlines). Throws
on failure. C: `TTF_SetTextWrapWidth`. -/
@[extern "lean_sdl_ttf_set_text_wrap_width"]
opaque setWrapWidth (self : @& Text) (w : Int32) : IO Unit

/-- The wrap width of `self` in pixels (`0` if wrapping only on newlines).
Throws on failure. C: `TTF_GetTextWrapWidth`. -/
@[extern "lean_sdl_ttf_get_text_wrap_width"]
opaque wrapWidth (self : @& Text) : IO Int32

/-- Set whether whitespace should be visible when wrapping `self`. Throws on
failure. C: `TTF_SetTextWrapWhitespaceVisible`. -/
@[extern "lean_sdl_ttf_set_text_wrap_whitespace_visible"]
opaque setWrapWhitespaceVisible (self : @& Text) (visible : Bool) : IO Unit

/-- Whether whitespace is visible when wrapping `self`.
C: `TTF_TextWrapWhitespaceVisible`. -/
@[extern "lean_sdl_ttf_text_wrap_whitespace_visible"]
opaque wrapWhitespaceVisible (self : @& Text) : IO Bool

/-- Replace the string of `self`. Throws on failure. C: `TTF_SetTextString`. -/
@[extern "lean_sdl_ttf_set_text_string"]
opaque setString (self : @& Text) (s : @& String) : IO Unit

/-- Insert `s` into `self` at byte `offset` (a negative offset counts from the
end; insert only at UTF-8 boundaries). Throws on failure.
C: `TTF_InsertTextString`. -/
@[extern "lean_sdl_ttf_insert_text_string"]
opaque insertString (self : @& Text) (offset : Int32) (s : @& String) : IO Unit

/-- Append `s` to `self`. Throws on failure. C: `TTF_AppendTextString`. -/
@[extern "lean_sdl_ttf_append_text_string"]
opaque appendString (self : @& Text) (s : @& String) : IO Unit

/-- Delete `length` bytes from `self` starting at byte `offset` (a negative
offset counts from the end; `length = -1` deletes to the end of the string;
delete only at UTF-8 boundaries). Throws on failure. C: `TTF_DeleteTextString`. -/
@[extern "lean_sdl_ttf_delete_text_string"]
opaque deleteString (self : @& Text) (offset length : Int32) : IO Unit

/-- The current UTF-8 string of `self`, read from the public `text->text` struct
field (`""` if NULL). C: the `text` field of `TTF_Text`. -/
@[extern "lean_sdl_ttf_text_string"]
opaque string (self : @& Text) : IO String

/-- The `(width, height)` in pixels of `self`. Throws on failure.
C: `TTF_GetTextSize`. -/
@[extern "lean_sdl_ttf_get_text_size"]
opaque size (self : @& Text) : IO (Int32 × Int32)

/-- Force `self` to be laid out now (normally lazy). Throws on failure.
C: `TTF_UpdateText`. -/
@[extern "lean_sdl_ttf_update_text"]
opaque update (self : @& Text) : IO Unit

/-- Destroy `self` immediately (a manual leaf; the underlying pointer is NULLed,
so every subsequent shim — including a second `destroy` — throws). The engine
and font references are released when the external is collected.
C: `TTF_DestroyText`. -/
@[extern "lean_sdl_ttf_destroy_text"]
opaque destroy (self : @& Text) : IO Unit

/-! ## Substrings -/

/-- The substring of `self` containing byte `offset`. Throws on failure.
C: `TTF_GetTextSubString`. -/
@[extern "lean_sdl_ttf_get_text_substring"]
opaque subString (self : @& Text) (offset : Int32) : IO SubString

/-- The substring covering line `line` of `self`. Throws on failure.
C: `TTF_GetTextSubStringForLine`. -/
@[extern "lean_sdl_ttf_get_text_substring_for_line"]
opaque subStringForLine (self : @& Text) (line : Int32) : IO SubString

/-- The substrings of `self` that contain the byte range `[offset, offset +
length)` (`length = -1` for the remainder). Throws on failure.
C: `TTF_GetTextSubStringsForRange`. -/
@[extern "lean_sdl_ttf_get_text_substrings_for_range"]
opaque subStringsForRange (self : @& Text) (offset length : Int32) : IO (Array SubString)

/-- The substring of `self` at pixel `(x, y)` (relative to the text's top-left).
Throws on failure. C: `TTF_GetTextSubStringForPoint`. -/
@[extern "lean_sdl_ttf_get_text_substring_for_point"]
opaque subStringForPoint (self : @& Text) (x y : Int32) : IO SubString

@[extern "lean_sdl_ttf_get_previous_text_substring"]
private opaque prevSubStringRaw (self : @& Text)
  (flags : UInt32) (offset length lineIndex clusterIndex rx ry rw rh : Int32) : IO SubString

/-- The substring of `self` immediately before `sub`. Throws on failure.
C: `TTF_GetPreviousTextSubString`. -/
def prevSubString (self : @& Text) (sub : SubString) : IO SubString :=
  prevSubStringRaw self sub.flags.val sub.offset sub.length sub.lineIndex sub.clusterIndex
    sub.rect.x sub.rect.y sub.rect.w sub.rect.h

@[extern "lean_sdl_ttf_get_next_text_substring"]
private opaque nextSubStringRaw (self : @& Text)
  (flags : UInt32) (offset length lineIndex clusterIndex rx ry rw rh : Int32) : IO SubString

/-- The substring of `self` immediately after `sub`. Throws on failure.
C: `TTF_GetNextTextSubString`. -/
def nextSubString (self : @& Text) (sub : SubString) : IO SubString :=
  nextSubStringRaw self sub.flags.val sub.offset sub.length sub.lineIndex sub.clusterIndex
    sub.rect.x sub.rect.y sub.rect.w sub.rect.h

end Text

/-! ## Text-engine creation properties -/

namespace Props

/-- The `SDL_Renderer` to use when creating a renderer text engine with
properties. C: `TTF_PROP_RENDERER_TEXT_ENGINE_RENDERER`. -/
def rendererTextEngineRenderer : String := "SDL_ttf.renderer_text_engine.create.renderer"
/-- The size of the glyph atlas texture for a renderer text engine (defaults to
`SDL_max(width, height)`). C: `TTF_PROP_RENDERER_TEXT_ENGINE_ATLAS_TEXTURE_SIZE`. -/
def rendererTextEngineAtlasTextureSize : String :=
  "SDL_ttf.renderer_text_engine.create.atlas_texture_size"
/-- The `SDL_GPUDevice` to use when creating a GPU text engine with properties.
C: `TTF_PROP_GPU_TEXT_ENGINE_DEVICE`. -/
def gpuTextEngineDevice : String := "SDL_ttf.gpu_text_engine.create.device"
/-- The size of the glyph atlas texture for a GPU text engine (defaults to
`SDL_max(width, height)`). C: `TTF_PROP_GPU_TEXT_ENGINE_ATLAS_TEXTURE_SIZE`. -/
def gpuTextEngineAtlasTextureSize : String :=
  "SDL_ttf.gpu_text_engine.create.atlas_texture_size"

end Props

end Sdl.Ttf
