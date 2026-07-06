import Sdl.Core.Macros
import Sdl.Error
import Sdl.Rect
import Sdl.Pixels
import Sdl.BlendMode
import Sdl.Surface
import Sdl.Properties
import Sdl.Video

/-!
# 2D accelerated rendering (`SDL_render.h`)

A `Renderer` handle wraps an `SDL_Renderer *`; a `Texture` handle wraps an
`SDL_Texture *`. **Call on the main thread** (per SDL, every function here is
main-thread-only). Do not let the *last* reference to a `Renderer`/`Texture`
die inside a `Task` — finalizers run on the dropping thread.

## Ownership

* `Renderer` is an **owned child** whose owner is the creating `Window`'s
  external (or the `Surface`'s external for the software renderer). It is
  **finalizer-only** (no manual destroy), mirroring `Window`: the finalizer runs
  `SDL_DestroyRenderer`, which frees the renderer's textures, so a manual
  destroy would dangle any live `Texture` handles. Reference-count ordering (a
  texture holds an owned ref to its renderer) keeps the renderer alive until all
  its textures are gone.
* `Texture` is an **owned leaf** whose owner is the creating `Renderer`'s
  external; `Texture.destroy` is exposed. Every shim starts with a
  use-after-destroy guard, so post-destroy use throws instead of crashing.

Each renderer and texture created through this binding stores its Lean external
as a non-owning pointer property on its own SDL properties
(`"lean_sdl.renderer"` / `"lean_sdl.texture"`), so `SDL_Renderer *` → `Renderer`
(`getRenderer`) and `SDL_Texture *` → `Texture` (`Renderer.getTarget`) lookups
return the *same* handle. Foreign renderers/textures yield `none`.
`Texture.renderer` recovers the owning renderer straight from the holder's owner
reference (no property needed).

`Rect`/`FRect`/`FPoint` arguments are passed flattened (a `has` byte plus the
fields) and rebuilt in C; array arguments (`points`, `lines`, `rects`,
`fillRects`, `geometry`) are packed into a little-endian `ByteArray` reinterpreted
as the matching SDL struct array. Structure results come back through
`@[export]`ed makers, so C never lays out a Lean structure.

## Skipped (plan-level omissions)

* `SDL_CreateRendererWithProperties` — its useful create-properties (window /
  surface pointers) require pointer properties this binding deliberately does
  not expose; name/vsync are reachable via `createRenderer` + `setVSync`.
* `SDL_CreateGPURenderer`, `SDL_GetGPURendererDevice`,
  `SDL_CreateGPURenderState`, `SDL_SetGPURenderStateFragmentUniforms`,
  `SDL_SetGPURenderState`, `SDL_DestroyGPURenderState` — deferred to the GPU tier.
* `SDL_LockTexture` — raw pixel pointer; `Texture.lockToSurface` covers the use
  case safely.
* `SDL_ConvertEventToRenderCoordinates` — mutates a raw `SDL_Event` in place;
  decoded Lean events are immutable copies. Use `coordinatesFromWindow` on the
  event's coordinates instead.
* `SDL_RenderGeometryRaw` — raw pointers + strides; `Renderer.geometry` covers it.
* `SDL_GetRenderMetalLayer` / `SDL_GetRenderMetalCommandEncoder` — raw `void *`.
* `SDL_AddVulkanRenderSemaphores` — Vulkan is unsupported by this binding.
* `SDL_RenderDebugTextFormat` — C varargs; use Lean string interpolation +
  `debugText`.
* `SDL_DestroyRenderer` — finalizer-only policy (see Ownership).
-/

namespace Sdl

/-- The access pattern allowed for a texture. C: `SDL_TextureAccess`. -/
sdl_enum TextureAccess : UInt32 where
  | static    => 0  -- C: SDL_TEXTUREACCESS_STATIC (changes rarely, not lockable)
  | streaming => 1  -- C: SDL_TEXTUREACCESS_STREAMING (changes frequently, lockable)
  | target    => 2  -- C: SDL_TEXTUREACCESS_TARGET (can be a render target)

/-- The addressing mode for a texture in `Renderer.geometry`. The C sentinel
`SDL_TEXTURE_ADDRESS_INVALID` (`-1`) is an error marker (like `ScaleMode.invalid`)
and is excluded; shims never pass or receive it. C: `SDL_TextureAddressMode`. -/
sdl_enum TextureAddressMode : UInt32 where
  | auto  => 0  -- C: SDL_TEXTURE_ADDRESS_AUTO (wrap iff coords are outside [0,1])
  | clamp => 1  -- C: SDL_TEXTURE_ADDRESS_CLAMP (clamp coords to [0,1])
  | wrap  => 2  -- C: SDL_TEXTURE_ADDRESS_WRAP (repeat/tile the texture)

/-- How the logical size is mapped to the output.
C: `SDL_RendererLogicalPresentation`. -/
sdl_enum RendererLogicalPresentation : UInt32 where
  | disabled     => 0  -- C: SDL_LOGICAL_PRESENTATION_DISABLED
  | stretch      => 1  -- C: SDL_LOGICAL_PRESENTATION_STRETCH
  | letterbox    => 2  -- C: SDL_LOGICAL_PRESENTATION_LETTERBOX
  | overscan     => 3  -- C: SDL_LOGICAL_PRESENTATION_OVERSCAN
  | integerScale => 4  -- C: SDL_LOGICAL_PRESENTATION_INTEGER_SCALE

/-- A vertex for `Renderer.geometry`. Its byte layout matches C's `SDL_Vertex`
exactly (`position`, `color`, `tex_coord`). C: `SDL_Vertex`. -/
structure Vertex where
  /-- Vertex position, in renderer coordinates. -/
  position : FPoint
  /-- Vertex color. -/
  color : FColor
  /-- Normalized texture coordinates, if needed. C: `tex_coord`. -/
  texCoord : FPoint
deriving Repr, BEq, Inhabited

/-- The name of the software renderer. C: `SDL_SOFTWARE_RENDERER`. -/
def softwareRenderer : String := "software"

/-- The name of the GPU renderer. C: `SDL_GPU_RENDERER`. -/
def gpuRenderer : String := "gpu"

/-- The size in pixels of one `Renderer.debugText` glyph (the font is monospaced
and square). C: `SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE`. -/
def debugTextFontCharacterSize : Int32 := 8

/-- A 2D rendering context. Owned child of a `Window`/`Surface`; finalizer-only
(no manual destroy). C: `SDL_Renderer`. -/
sdl_opaque Renderer

/-- A driver-specific representation of pixel data. Owned leaf of a `Renderer`;
destroyed on finalize or via `Texture.destroy`. C: `SDL_Texture`. -/
sdl_opaque Texture

@[extern "lean_sdl_render_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

/-! ## Private result makers (C never builds Lean tuples/structures)

Render defines its own makers with render-specific export names: the plain
`lean_sdl_mk_*` export names are already claimed by other modules, and
`@[export]` names are process-global. -/

/-- Maker for an `Int32 × Int32` pair result. -/
@[export lean_sdl_render_mk_int32_pair]
private def mkInt32Pair (a b : Int32) : Int32 × Int32 := (a, b)

/-- Maker for a `UInt32 × UInt32` pair result (texture-address-mode gets). -/
@[export lean_sdl_render_mk_uint32_pair]
private def mkUInt32Pair (a b : UInt32) : UInt32 × UInt32 := (a, b)

/-- Maker for a `Float32 × Float32` pair result. -/
@[export lean_sdl_render_mk_float32_pair]
private def mkFloat32Pair (a b : Float32) : Float32 × Float32 := (a, b)

/-- Maker for a `UInt8 × UInt8 × UInt8` triple result (byte color-mod gets). -/
@[export lean_sdl_render_mk_uint8_triple]
private def mkUInt8Triple (a b c : UInt8) : UInt8 × UInt8 × UInt8 := (a, b, c)

/-- Maker for a `UInt8 × UInt8 × UInt8 × UInt8` quad result (byte draw-color). -/
@[export lean_sdl_render_mk_uint8_quad]
private def mkUInt8Quad (a b c d : UInt8) : UInt8 × UInt8 × UInt8 × UInt8 := (a, b, c, d)

/-- Maker for a `Float32 × Float32 × Float32` triple result (float color-mod). -/
@[export lean_sdl_render_mk_float32_triple]
private def mkFloat32Triple (a b c : Float32) : Float32 × Float32 × Float32 := (a, b, c)

/-- Maker for a `Float32 × Float32 × Float32 × Float32` quad result (float
draw-color). -/
@[export lean_sdl_render_mk_float32_quad]
private def mkFloat32Quad (a b c d : Float32) :
    Float32 × Float32 × Float32 × Float32 := (a, b, c, d)

/-- Maker for a `Rect` result (getViewport / getClipRect / getSafeArea). -/
@[export lean_sdl_render_mk_rect]
private def mkRect (x y w h : Int32) : Rect := { x, y, w, h }

/-- Maker for an `FRect` result (getLogicalPresentationRect). -/
@[export lean_sdl_render_mk_frect]
private def mkFRect (x y w h : Float32) : FRect := { x, y, w, h }

/-- Maker for the raw logical-presentation triple `(w, h, mode)`; the wrapper
decodes `mode`. -/
@[export lean_sdl_render_mk_logical]
private def mkLogical (w h : Int32) (mode : UInt32) : Int32 × Int32 × UInt32 := (w, h, mode)

/-! ## Private argument flattening / packing helpers -/

/-- Flatten an `Option Rect` to the `(hasRect, x, y, w, h)` shape the raw externs
take. -/
private def rectArgs : Option Rect → UInt8 × Int32 × Int32 × Int32 × Int32
  | some r => (1, r.x, r.y, r.w, r.h)
  | none   => (0, 0, 0, 0, 0)

/-- Flatten an `Option FRect` to `(hasRect, x, y, w, h)` (float zeros for none). -/
private def frectArgs : Option FRect → UInt8 × Float32 × Float32 × Float32 × Float32
  | some r => (1, r.x, r.y, r.w, r.h)
  | none   => (0, 0, 0, 0, 0)

/-- Flatten an `Option FPoint` to `(hasPoint, x, y)` (float zeros for none). -/
private def fpointArgs : Option FPoint → UInt8 × Float32 × Float32
  | some p => (1, p.x, p.y)
  | none   => (0, 0, 0)

/-- Append `f` to `b` as 4 little-endian bytes (its IEEE-754 bit pattern). Used
to pack `SDL_FPoint[]`/`SDL_FRect[]`/`SDL_Vertex[]`; all supported targets are
little-endian. -/
private def pushFloat32LE (b : ByteArray) (f : Float32) : ByteArray :=
  let u := f.toBits
  b.push u.toUInt8 |>.push (u >>> 8).toUInt8 |>.push (u >>> 16).toUInt8
    |>.push (u >>> 24).toUInt8

/-- Append `v` to `b` as 4 little-endian bytes (its two's-complement bit pattern).
Used to pack the `int[]` index array for `geometry`. -/
private def pushInt32LE (b : ByteArray) (v : Int32) : ByteArray :=
  let u := v.toUInt32
  b.push u.toUInt8 |>.push (u >>> 8).toUInt8 |>.push (u >>> 16).toUInt8
    |>.push (u >>> 24).toUInt8

/-- Pack an `Array FPoint` into a `ByteArray` matching `SDL_FPoint[]` (two
little-endian float32s each). -/
private def packFPoints (pts : Array FPoint) : ByteArray := Id.run do
  let mut bytes := ByteArray.emptyWithCapacity (pts.size * 8)
  for p in pts do
    bytes := pushFloat32LE (pushFloat32LE bytes p.x) p.y
  return bytes

/-- Pack an `Array FRect` into a `ByteArray` matching `SDL_FRect[]` (four
little-endian float32s each). -/
private def packFRects (rs : Array FRect) : ByteArray := Id.run do
  let mut bytes := ByteArray.emptyWithCapacity (rs.size * 16)
  for r in rs do
    bytes := pushFloat32LE (pushFloat32LE (pushFloat32LE (pushFloat32LE bytes r.x) r.y) r.w) r.h
  return bytes

/-- Pack an `Array Vertex` into a `ByteArray` matching `SDL_Vertex[]` (eight
little-endian float32s each: `position.x`, `position.y`, `color.r`, `g`, `b`,
`a`, `texCoord.x`, `texCoord.y` — exactly `SDL_Vertex`'s field layout, see
`ffi/consts_check.c`). -/
private def packVertices (vs : Array Vertex) : ByteArray := Id.run do
  let mut bytes := ByteArray.emptyWithCapacity (vs.size * 32)
  for v in vs do
    bytes := pushFloat32LE bytes v.position.x
    bytes := pushFloat32LE bytes v.position.y
    bytes := pushFloat32LE bytes v.color.r
    bytes := pushFloat32LE bytes v.color.g
    bytes := pushFloat32LE bytes v.color.b
    bytes := pushFloat32LE bytes v.color.a
    bytes := pushFloat32LE bytes v.texCoord.x
    bytes := pushFloat32LE bytes v.texCoord.y
  return bytes

/-- Pack an `Array Int32` into a `ByteArray` matching `int[]` (four
little-endian bytes each). -/
private def packIndices (idx : Array Int32) : ByteArray := Id.run do
  let mut bytes := ByteArray.emptyWithCapacity (idx.size * 4)
  for i in idx do
    bytes := pushInt32LE bytes i
  return bytes

/-! ## Render drivers -/

/-- The number of 2D rendering drivers available. C: `SDL_GetNumRenderDrivers`. -/
@[extern "lean_sdl_get_num_render_drivers"]
opaque getNumRenderDrivers : IO Int32

/-- The name of the built-in render driver at `index` (a simple low-ASCII id
like `"software"`/`"opengl"`/`"metal"`), or `none` if `index` is out of range.
C: `SDL_GetRenderDriver`. -/
@[extern "lean_sdl_get_render_driver"]
opaque getRenderDriver (index : Int32) : IO (Option String)

/-! ## Renderer creation and lookup -/

@[extern "lean_sdl_create_renderer"]
private opaque createRendererRaw (window : @& Window) (name : @& Option String) : IO Renderer

/-- Create a 2D rendering context for `window`. `name` picks a specific driver
(a comma-separated list is tried in order); `none` lets SDL choose. The renderer
holds an owned reference to `window` and is registered for identity-preserving
lookups. Throws on failure. C: `SDL_CreateRenderer`. -/
def createRenderer (window : @& Window) (name : Option String := none) : IO Renderer :=
  createRendererRaw window name

/-- Create a 2D software rendering context targeting `surface` (holds an owned
reference to it). Throws on failure. C: `SDL_CreateSoftwareRenderer`. -/
@[extern "lean_sdl_create_software_renderer"]
opaque createSoftwareRenderer (surface : @& Surface) : IO Renderer

/-- Create a window and a default renderer for it. A Lean-side composition of
`createWindow` then `createRenderer` (SDL's `SDL_CreateWindowAndRenderer` is a
convenience wrapper over the same two calls). Throws on failure.
C: `SDL_CreateWindowAndRenderer`. -/
def createWindowAndRenderer (title : String) (w h : Int32)
    (flags : WindowFlags := .none) : IO (Window × Renderer) := do
  let win ← Sdl.createWindow title w h flags
  let ren ← createRenderer win
  return (win, ren)

/-- The renderer associated with `window`, or `none` if it has none (or the
renderer is a foreign one not created through this binding). Returns the *same*
handle the renderer was created with. C: `SDL_GetRenderer`. -/
@[extern "lean_sdl_get_renderer"]
opaque getRenderer (window : @& Window) : IO (Option Renderer)

namespace Renderer

/-- The window associated with the renderer, or `none` (e.g. a software renderer
targeting a surface, or a foreign window). C: `SDL_GetRenderWindow`. -/
@[extern "lean_sdl_get_render_window"]
opaque getWindow (self : @& Renderer) : IO (Option Window)

/-- The name of the renderer (e.g. `"software"`). Throws on failure.
C: `SDL_GetRendererName`. -/
@[extern "lean_sdl_get_renderer_name"]
opaque name (self : @& Renderer) : IO String

/-- The properties associated with the renderer. Borrowed: tied to the
renderer's lifetime, never destroyed from Lean. Throws on failure.
C: `SDL_GetRendererProperties`. -/
@[extern "lean_sdl_get_renderer_properties"]
opaque properties (self : @& Renderer) : IO Properties

/-- The true output size in pixels `(w, h)`, ignoring render targets and logical
presentation. Throws on failure. C: `SDL_GetRenderOutputSize`. -/
@[extern "lean_sdl_get_render_output_size"]
opaque getOutputSize (self : @& Renderer) : IO (Int32 × Int32)

/-- The current output size in pixels `(w, h)` (the render target's size,
adjusted by logical presentation). Throws on failure.
C: `SDL_GetCurrentRenderOutputSize`. -/
@[extern "lean_sdl_get_current_render_output_size"]
opaque getCurrentOutputSize (self : @& Renderer) : IO (Int32 × Int32)

/-! ### Textures -/

@[extern "lean_sdl_create_texture"]
private opaque createTextureRaw (self : @& Renderer) (format access : UInt32)
  (w h : Int32) : IO Texture

/-- Create a texture with the given pixel `format`, `access` pattern, and size.
The contents are initially undefined. The texture holds an owned reference to
the renderer and is registered for identity-preserving lookups. Throws on
failure. C: `SDL_CreateTexture`. -/
def createTexture (self : @& Renderer) (format : PixelFormat) (access : TextureAccess)
    (w h : Int32) : IO Texture :=
  createTextureRaw self format.val access.val w h

/-- Create a static-access texture from `surface` (SDL copies the pixels; the
texture format may differ). Throws on failure.
C: `SDL_CreateTextureFromSurface`. -/
@[extern "lean_sdl_create_texture_from_surface"]
opaque createTextureFromSurface (self : @& Renderer) (surface : @& Surface) : IO Texture

/-- Create a texture from a group of `SDL_PROP_TEXTURE_CREATE_*` properties
(e.g. `"SDL.texture.create.format"`, `"SDL.texture.create.width"`). Throws on
failure. C: `SDL_CreateTextureWithProperties`. -/
@[extern "lean_sdl_create_texture_with_properties"]
opaque createTextureWithProperties (self : @& Renderer) (props : @& Properties) : IO Texture

@[extern "lean_sdl_set_render_target"]
private opaque setTargetRaw (self : @& Renderer) (texture : @& Option Texture) : IO Unit

/-- Set the current render target: `some t` renders to the texture `t` (which
must have been created with `.target` access), `none` renders to the window.
Viewport/clip/scale/logical-presentation are per-target and persist across
switches.

**Keep your reference to `t` alive while it is the target.** The binding does
not retain the bound texture (retaining it would create a permanent
renderer-texture reference cycle): if the last reference dies, the finalizer
destroys the texture and SDL resets the target back to the window. Throws on
failure. C: `SDL_SetRenderTarget`. -/
def setTarget (self : @& Renderer) (texture : Option Texture := none) : IO Unit :=
  setTargetRaw self texture

/-- The current render target, or `none` for the default (window) target.
Returns the same handle the texture was created with. C: `SDL_GetRenderTarget`. -/
@[extern "lean_sdl_get_render_target"]
opaque getTarget (self : @& Renderer) : IO (Option Texture)

/-! ### Logical presentation and coordinates -/

@[extern "lean_sdl_set_render_logical_presentation"]
private opaque setLogicalPresentationRaw (self : @& Renderer) (w h : Int32)
  (mode : UInt32) : IO Unit

/-- Set a device-independent logical resolution and presentation mode for the
current render target. Throws on failure.
C: `SDL_SetRenderLogicalPresentation`. -/
def setLogicalPresentation (self : @& Renderer) (w h : Int32)
    (mode : RendererLogicalPresentation) : IO Unit :=
  setLogicalPresentationRaw self w h mode.val

@[extern "lean_sdl_get_render_logical_presentation"]
private opaque getLogicalPresentationRaw (self : @& Renderer) :
  IO (Int32 × Int32 × UInt32)

/-- The logical resolution `(w, h)` and presentation `mode` for the current
render target (`w`/`h` are `0` when disabled). Throws on failure.
C: `SDL_GetRenderLogicalPresentation`. -/
def getLogicalPresentation (self : @& Renderer) :
    IO (Int32 × Int32 × RendererLogicalPresentation) := do
  let (w, h, m) ← getLogicalPresentationRaw self
  return (w, h, RendererLogicalPresentation.ofVal? m |>.getD .disabled)

/-- The final presentation rectangle used for logical presentation (the full
output size, in pixels, when disabled). Throws on failure.
C: `SDL_GetRenderLogicalPresentationRect`. -/
@[extern "lean_sdl_get_render_logical_presentation_rect"]
opaque getLogicalPresentationRect (self : @& Renderer) : IO FRect

/-- Map a point in window coordinates to render coordinates (accounting for
logical presentation, scale, and viewport). Throws on failure.
C: `SDL_RenderCoordinatesFromWindow`. -/
@[extern "lean_sdl_render_coordinates_from_window"]
opaque coordinatesFromWindow (self : @& Renderer) (windowX windowY : Float32) :
  IO (Float32 × Float32)

/-- Map a point in render coordinates to window coordinates. Throws on failure.
C: `SDL_RenderCoordinatesToWindow`. -/
@[extern "lean_sdl_render_coordinates_to_window"]
opaque coordinatesToWindow (self : @& Renderer) (x y : Float32) :
  IO (Float32 × Float32)

/-! ### Viewport, clip, scale -/

@[extern "lean_sdl_set_render_viewport"]
private opaque setViewportRaw (self : @& Renderer) (hasRect : UInt8)
  (x y w h : Int32) : IO Unit

/-- Set the drawing area for the current target; `none` uses the entire target.
Throws on failure. C: `SDL_SetRenderViewport`. -/
def setViewport (self : @& Renderer) (rect : Option Rect := none) : IO Unit :=
  let (hasR, x, y, w, h) := rectArgs rect
  setViewportRaw self hasR x y w h

/-- The drawing area for the current target. Throws on failure.
C: `SDL_GetRenderViewport`. -/
@[extern "lean_sdl_get_render_viewport"]
opaque getViewport (self : @& Renderer) : IO Rect

/-- Whether an explicit viewport rectangle was set (vs. the entire target).
Throws on failure. C: `SDL_RenderViewportSet`. -/
@[extern "lean_sdl_render_viewport_set"]
opaque viewportSet (self : @& Renderer) : IO Bool

/-- The safe area for interactive content within the current viewport. Throws on
failure. C: `SDL_GetRenderSafeArea`. -/
@[extern "lean_sdl_get_render_safe_area"]
opaque getSafeArea (self : @& Renderer) : IO Rect

@[extern "lean_sdl_set_render_clip_rect"]
private opaque setClipRectRaw (self : @& Renderer) (hasRect : UInt8)
  (x y w h : Int32) : IO Unit

/-- Set the clip rectangle (relative to the viewport) for the current target;
`none` disables clipping. Throws on failure. C: `SDL_SetRenderClipRect`. -/
def setClipRect (self : @& Renderer) (rect : Option Rect := none) : IO Unit :=
  let (hasR, x, y, w, h) := rectArgs rect
  setClipRectRaw self hasR x y w h

/-- The clip rectangle for the current target (empty if clipping is disabled).
Throws on failure. C: `SDL_GetRenderClipRect`. -/
@[extern "lean_sdl_get_render_clip_rect"]
opaque getClipRect (self : @& Renderer) : IO Rect

/-- Whether clipping is enabled for the current target. Throws on failure.
C: `SDL_RenderClipEnabled`. -/
@[extern "lean_sdl_render_clip_enabled"]
opaque clipEnabled (self : @& Renderer) : IO Bool

/-- Set the drawing scale `(scaleX, scaleY)` for the current target. Throws on
failure. C: `SDL_SetRenderScale`. -/
@[extern "lean_sdl_set_render_scale"]
opaque setScale (self : @& Renderer) (scaleX scaleY : Float32) : IO Unit

/-- The drawing scale `(scaleX, scaleY)` for the current target. Throws on
failure. C: `SDL_GetRenderScale`. -/
@[extern "lean_sdl_get_render_scale"]
opaque getScale (self : @& Renderer) : IO (Float32 × Float32)

/-! ### Draw color, color scale, blend mode -/

/-- Set the color used for drawing/filling and `clear`. Throws on failure.
C: `SDL_SetRenderDrawColor`. -/
@[extern "lean_sdl_set_render_draw_color"]
opaque setDrawColor (self : @& Renderer) (r g b a : UInt8) : IO Unit

/-- The draw color `(r, g, b, a)`. Throws on failure. C: `SDL_GetRenderDrawColor`. -/
@[extern "lean_sdl_get_render_draw_color"]
opaque getDrawColor (self : @& Renderer) : IO (UInt8 × UInt8 × UInt8 × UInt8)

/-- Set the draw color in floating point. Throws on failure.
C: `SDL_SetRenderDrawColorFloat`. -/
@[extern "lean_sdl_set_render_draw_color_float"]
opaque setDrawColorFloat (self : @& Renderer) (r g b a : Float32) : IO Unit

/-- The draw color as floating point `(r, g, b, a)`. Throws on failure.
C: `SDL_GetRenderDrawColorFloat`. -/
@[extern "lean_sdl_get_render_draw_color_float"]
opaque getDrawColorFloat (self : @& Renderer) : IO (Float32 × Float32 × Float32 × Float32)

/-- Set the color scale multiplied into rendered pixel colors (brightness; does
not affect alpha). Throws on failure. C: `SDL_SetRenderColorScale`. -/
@[extern "lean_sdl_set_render_color_scale"]
opaque setColorScale (self : @& Renderer) (scale : Float32) : IO Unit

/-- The color scale for render operations. Throws on failure.
C: `SDL_GetRenderColorScale`. -/
@[extern "lean_sdl_get_render_color_scale"]
opaque getColorScale (self : @& Renderer) : IO Float32

@[extern "lean_sdl_set_render_draw_blend_mode"]
private opaque setDrawBlendModeRaw (self : @& Renderer) (mode : UInt32) : IO Unit

/-- Set the blend mode used for drawing (fill and line). Throws on failure.
C: `SDL_SetRenderDrawBlendMode`. -/
def setDrawBlendMode (self : @& Renderer) (mode : BlendMode) : IO Unit :=
  setDrawBlendModeRaw self mode.val

@[extern "lean_sdl_get_render_draw_blend_mode"]
private opaque getDrawBlendModeRaw (self : @& Renderer) : IO UInt32

/-- The blend mode used for drawing operations. Throws on failure.
C: `SDL_GetRenderDrawBlendMode`. -/
def getDrawBlendMode (self : @& Renderer) : IO BlendMode := do
  return ⟨← getDrawBlendModeRaw self⟩

/-! ### Primitives -/

/-- Clear the current target with the draw color (ignores viewport and clip).
Throws on failure. C: `SDL_RenderClear`. -/
@[extern "lean_sdl_render_clear"]
opaque clear (self : @& Renderer) : IO Unit

/-- Draw a single point at subpixel precision. Throws on failure.
C: `SDL_RenderPoint`. -/
@[extern "lean_sdl_render_point"]
opaque point (self : @& Renderer) (x y : Float32) : IO Unit

@[extern "lean_sdl_render_points"]
private opaque pointsRaw (self : @& Renderer) (bytes : @& ByteArray) (count : Int32) : IO Unit

/-- Draw multiple points at subpixel precision (packed into a `ByteArray` of
`SDL_FPoint`s). An empty array is a no-op. Throws on failure.
C: `SDL_RenderPoints`. -/
def points (self : @& Renderer) (points : Array FPoint) : IO Unit := do
  if points.isEmpty then return
  pointsRaw self (packFPoints points) (Int32.ofNat points.size)

/-- Draw a line between two points at subpixel precision. Throws on failure.
C: `SDL_RenderLine`. -/
@[extern "lean_sdl_render_line"]
opaque line (self : @& Renderer) (x1 y1 x2 y2 : Float32) : IO Unit

@[extern "lean_sdl_render_lines"]
private opaque linesRaw (self : @& Renderer) (bytes : @& ByteArray) (count : Int32) : IO Unit

/-- Draw a connected series of lines through `points` (drawing `count-1` lines).
An empty array is a no-op. Throws on failure. C: `SDL_RenderLines`. -/
def lines (self : @& Renderer) (points : Array FPoint) : IO Unit := do
  if points.isEmpty then return
  linesRaw self (packFPoints points) (Int32.ofNat points.size)

@[extern "lean_sdl_render_rect"]
private opaque rectRaw (self : @& Renderer) (hasRect : UInt8)
  (x y w h : Float32) : IO Unit

/-- Outline a rectangle at subpixel precision; `none` outlines the entire target.
Throws on failure. C: `SDL_RenderRect`. -/
def rect (self : @& Renderer) (rect : Option FRect := none) : IO Unit :=
  let (hasR, x, y, w, h) := frectArgs rect
  rectRaw self hasR x y w h

@[extern "lean_sdl_render_rects"]
private opaque rectsRaw (self : @& Renderer) (bytes : @& ByteArray) (count : Int32) : IO Unit

/-- Outline multiple rectangles (packed as `SDL_FRect`s). An empty array is a
no-op. Throws on failure. C: `SDL_RenderRects`. -/
def rects (self : @& Renderer) (rects : Array FRect) : IO Unit := do
  if rects.isEmpty then return
  rectsRaw self (packFRects rects) (Int32.ofNat rects.size)

@[extern "lean_sdl_render_fill_rect"]
private opaque fillRectRaw (self : @& Renderer) (hasRect : UInt8)
  (x y w h : Float32) : IO Unit

/-- Fill a rectangle with the draw color; `none` fills the entire target. Throws
on failure. C: `SDL_RenderFillRect`. -/
def fillRect (self : @& Renderer) (rect : Option FRect := none) : IO Unit :=
  let (hasR, x, y, w, h) := frectArgs rect
  fillRectRaw self hasR x y w h

@[extern "lean_sdl_render_fill_rects"]
private opaque fillRectsRaw (self : @& Renderer) (bytes : @& ByteArray) (count : Int32) : IO Unit

/-- Fill multiple rectangles (packed as `SDL_FRect`s). An empty array is a
no-op. Throws on failure. C: `SDL_RenderFillRects`. -/
def fillRects (self : @& Renderer) (rects : Array FRect) : IO Unit := do
  if rects.isEmpty then return
  fillRectsRaw self (packFRects rects) (Int32.ofNat rects.size)

/-! ### Texture copies -/

@[extern "lean_sdl_render_texture"]
private opaque textureRaw (self : @& Renderer) (tex : @& Texture)
  (hasSrc : UInt8) (sx sy sw sh : Float32)
  (hasDst : UInt8) (dx dy dw dh : Float32) : IO Unit

/-- Copy (a portion of) `tex` to the current target at subpixel precision.
`srcRect`/`dstRect` default to the whole texture/target. Throws on failure.
C: `SDL_RenderTexture`. -/
def texture (self : @& Renderer) (tex : @& Texture)
    (srcRect dstRect : Option FRect := none) : IO Unit :=
  let (hs, sx, sy, sw, sh) := frectArgs srcRect
  let (hd, dx, dy, dw, dh) := frectArgs dstRect
  textureRaw self tex hs sx sy sw sh hd dx dy dw dh

@[extern "lean_sdl_render_texture_rotated"]
private opaque textureRotatedRaw (self : @& Renderer) (tex : @& Texture)
  (hasSrc : UInt8) (sx sy sw sh : Float32)
  (hasDst : UInt8) (dx dy dw dh : Float32)
  (angle : Float) (hasCenter : UInt8) (cx cy : Float32)
  (flip : UInt32) : IO Unit

/-- Copy `tex` with rotation (`angle` degrees clockwise about `center`, or the
destination center when `none`) and `flip`. Throws on failure.
C: `SDL_RenderTextureRotated`. -/
def textureRotated (self : @& Renderer) (tex : @& Texture)
    (srcRect dstRect : Option FRect) (angle : Float)
    (center : Option FPoint := none) (flip : FlipMode := .none) : IO Unit :=
  let (hs, sx, sy, sw, sh) := frectArgs srcRect
  let (hd, dx, dy, dw, dh) := frectArgs dstRect
  let (hc, cx, cy) := fpointArgs center
  textureRotatedRaw self tex hs sx sy sw sh hd dx dy dw dh angle hc cx cy flip.val

@[extern "lean_sdl_render_texture_affine"]
private opaque textureAffineRaw (self : @& Renderer) (tex : @& Texture)
  (hasSrc : UInt8) (sx sy sw sh : Float32)
  (hasOrigin : UInt8) (ox oy : Float32)
  (hasRight : UInt8) (rx ry : Float32)
  (hasDown : UInt8) (ddx ddy : Float32) : IO Unit

/-- Copy `tex` with an affine transform: `origin`/`right`/`down` map the
top-left/top-right/bottom-left corners of `srcRect` (each `none` defaults to the
target's corresponding corner). Throws on failure. C: `SDL_RenderTextureAffine`. -/
def textureAffine (self : @& Renderer) (tex : @& Texture)
    (srcRect : Option FRect) (origin right down : Option FPoint := none) : IO Unit :=
  let (hs, sx, sy, sw, sh) := frectArgs srcRect
  let (ho, ox, oy) := fpointArgs origin
  let (hr, rx, ry) := fpointArgs right
  let (hd, ddx, ddy) := fpointArgs down
  textureAffineRaw self tex hs sx sy sw sh ho ox oy hr rx ry hd ddx ddy

@[extern "lean_sdl_render_texture_tiled"]
private opaque textureTiledRaw (self : @& Renderer) (tex : @& Texture)
  (hasSrc : UInt8) (sx sy sw sh : Float32) (scale : Float32)
  (hasDst : UInt8) (dx dy dw dh : Float32) : IO Unit

/-- Tile (a portion of) `tex` to fill `dstRect`, scaling `srcRect` by `scale`.
Throws on failure. C: `SDL_RenderTextureTiled`. -/
def textureTiled (self : @& Renderer) (tex : @& Texture)
    (srcRect : Option FRect) (scale : Float32) (dstRect : Option FRect := none) : IO Unit :=
  let (hs, sx, sy, sw, sh) := frectArgs srcRect
  let (hd, dx, dy, dw, dh) := frectArgs dstRect
  textureTiledRaw self tex hs sx sy sw sh scale hd dx dy dw dh

@[extern "lean_sdl_render_texture_9grid"]
private opaque texture9GridRaw (self : @& Renderer) (tex : @& Texture)
  (hasSrc : UInt8) (sx sy sw sh : Float32)
  (leftWidth rightWidth topHeight bottomHeight scale : Float32)
  (hasDst : UInt8) (dx dy dw dh : Float32) : IO Unit

/-- 9-grid copy: split `srcRect` into a 3×3 grid by the corner sizes, scale the
corners by `scale` (`0.0` = unscaled), and stretch the sides/center to cover
`dstRect`. Throws on failure. C: `SDL_RenderTexture9Grid`. -/
def texture9Grid (self : @& Renderer) (tex : @& Texture)
    (srcRect : Option FRect)
    (leftWidth rightWidth topHeight bottomHeight scale : Float32)
    (dstRect : Option FRect := none) : IO Unit :=
  let (hs, sx, sy, sw, sh) := frectArgs srcRect
  let (hd, dx, dy, dw, dh) := frectArgs dstRect
  texture9GridRaw self tex hs sx sy sw sh
    leftWidth rightWidth topHeight bottomHeight scale hd dx dy dw dh

@[extern "lean_sdl_render_texture_9grid_tiled"]
private opaque texture9GridTiledRaw (self : @& Renderer) (tex : @& Texture)
  (hasSrc : UInt8) (sx sy sw sh : Float32)
  (leftWidth rightWidth topHeight bottomHeight scale : Float32)
  (hasDst : UInt8) (dx dy dw dh : Float32) (tileScale : Float32) : IO Unit

/-- Like `texture9Grid`, but the sides and center are *tiled* (by `tileScale`,
`1.0` = unscaled) rather than stretched. Throws on failure.
C: `SDL_RenderTexture9GridTiled`. -/
def texture9GridTiled (self : @& Renderer) (tex : @& Texture)
    (srcRect : Option FRect)
    (leftWidth rightWidth topHeight bottomHeight scale : Float32)
    (dstRect : Option FRect := none) (tileScale : Float32 := 1.0) : IO Unit :=
  let (hs, sx, sy, sw, sh) := frectArgs srcRect
  let (hd, dx, dy, dw, dh) := frectArgs dstRect
  texture9GridTiledRaw self tex hs sx sy sw sh
    leftWidth rightWidth topHeight bottomHeight scale hd dx dy dw dh tileScale

@[extern "lean_sdl_render_geometry"]
private opaque geometryRaw (self : @& Renderer) (texture : @& Option Texture)
  (vertices : @& ByteArray) (numVertices : Int32)
  (indices : @& ByteArray) (numIndices : Int32) : IO Unit

/-- Render a list of triangles, optionally textured and indexed. Per-vertex
color/alpha modulation is applied (texture color/alpha mod are ignored). When
`indices` is empty, vertices are drawn in sequential order. Throws on failure.
C: `SDL_RenderGeometry`. -/
def geometry (self : @& Renderer) (texture : Option Texture)
    (vertices : Array Vertex) (indices : Array Int32 := #[]) : IO Unit :=
  geometryRaw self texture (packVertices vertices) (Int32.ofNat vertices.size)
    (packIndices indices) (Int32.ofNat indices.size)

@[extern "lean_sdl_set_render_texture_address_mode"]
private opaque setTextureAddressModeRaw (self : @& Renderer) (u v : UInt32) : IO Unit

/-- Set the texture addressing mode (`u`/`v`) used in `geometry`. Throws on
failure. C: `SDL_SetRenderTextureAddressMode`. -/
def setTextureAddressMode (self : @& Renderer) (u v : TextureAddressMode) : IO Unit :=
  setTextureAddressModeRaw self u.val v.val

@[extern "lean_sdl_get_render_texture_address_mode"]
private opaque getTextureAddressModeRaw (self : @& Renderer) : IO (UInt32 × UInt32)

/-- The texture addressing mode `(u, v)` used in `geometry`. Throws on failure.
C: `SDL_GetRenderTextureAddressMode`. -/
def getTextureAddressMode (self : @& Renderer) : IO (TextureAddressMode × TextureAddressMode) := do
  let (u, v) ← getTextureAddressModeRaw self
  return (TextureAddressMode.ofVal? u |>.getD .auto, TextureAddressMode.ofVal? v |>.getD .auto)

/-! ### Pixels, present, vsync -/

@[extern "lean_sdl_render_read_pixels"]
private opaque readPixelsRaw (self : @& Renderer) (hasRect : UInt8)
  (x y w h : Int32) : IO Surface

/-- Read pixels from the current target into a new (owned) `Surface`, clipped to
the current viewport; `none` reads the entire viewport. Very slow — for tests
and captures, not hot loops. Throws on failure. C: `SDL_RenderReadPixels`. -/
def readPixels (self : @& Renderer) (rect : Option Rect := none) : IO Surface :=
  let (hasR, x, y, w, h) := rectArgs rect
  readPixelsRaw self hasR x y w h

/-- Present the composed backbuffer to the screen (call once per frame; do not
call while rendering to a texture target). Throws on failure.
C: `SDL_RenderPresent`. -/
@[extern "lean_sdl_render_present"]
opaque present (self : @& Renderer) : IO Unit

/-- Flush any pending render commands and state (only needed when mixing SDL's
render API with direct GL/D3D/Metal calls). Throws on failure.
C: `SDL_FlushRenderer`. -/
@[extern "lean_sdl_flush_renderer"]
opaque flush (self : @& Renderer) : IO Unit

/-- `SDL_RENDERER_VSYNC_DISABLED`: value for `setVSync` disabling vsync.
C: `SDL_RENDERER_VSYNC_DISABLED`. -/
def vsyncDisabled : Int32 := 0

/-- `SDL_RENDERER_VSYNC_ADAPTIVE`: value for `setVSync` requesting adaptive
vsync (late-swap tearing). C: `SDL_RENDERER_VSYNC_ADAPTIVE`. -/
def vsyncAdaptive : Int32 := -1

/-- Set the vsync interval: `0` (`vsyncDisabled`) disables it, `1..N` presents
every Nth vertical refresh, `-1` (`vsyncAdaptive`) requests adaptive vsync. Not
every value is supported by every driver. Throws on failure.
C: `SDL_SetRenderVSync`. -/
@[extern "lean_sdl_set_render_vsync"]
opaque setVSync (self : @& Renderer) (vsync : Int32) : IO Unit

/-- The current vsync interval (see `setVSync` for the meaning). Throws on
failure. C: `SDL_GetRenderVSync`. -/
@[extern "lean_sdl_get_render_vsync"]
opaque getVSync (self : @& Renderer) : IO Int32

/-- Draw a line of debug text (ASCII, 8×8 monospaced bitmap font) at `(x, y)` in
the current draw color. A convenience for debugging only. Throws on failure.
C: `SDL_RenderDebugText`. -/
@[extern "lean_sdl_render_debug_text"]
opaque debugText (self : @& Renderer) (x y : Float32) (text : @& String) : IO Unit

@[extern "lean_sdl_set_default_texture_scale_mode"]
private opaque setDefaultTextureScaleModeRaw (self : @& Renderer) (mode : UInt32) : IO Unit

/-- Set the default scale mode for new textures of this renderer (default is
`.linear`). Throws on failure. C: `SDL_SetDefaultTextureScaleMode`. -/
def setDefaultTextureScaleMode (self : @& Renderer) (mode : ScaleMode) : IO Unit :=
  setDefaultTextureScaleModeRaw self mode.val

@[extern "lean_sdl_get_default_texture_scale_mode"]
private opaque getDefaultTextureScaleModeRaw (self : @& Renderer) : IO UInt32

/-- The default scale mode for new textures of this renderer. Throws on failure.
C: `SDL_GetDefaultTextureScaleMode`. -/
def getDefaultTextureScaleMode (self : @& Renderer) : IO ScaleMode := do
  return ScaleMode.ofVal? (← getDefaultTextureScaleModeRaw self) |>.getD .linear

end Renderer

namespace Texture

/-- The properties associated with the texture. Borrowed: tied to the texture's
lifetime, never destroyed from Lean. Throws on failure.
C: `SDL_GetTextureProperties`. -/
@[extern "lean_sdl_get_texture_properties"]
opaque properties (self : @& Texture) : IO Properties

/-- The renderer that created the texture (recovered from the owner reference).
Throws if the texture was destroyed. C: `SDL_GetRendererFromTexture`. -/
@[extern "lean_sdl_get_renderer_from_texture"]
opaque renderer (self : @& Texture) : IO Renderer

/-- The size of the texture in pixels `(w, h)`, as floating point. Throws on
failure. C: `SDL_GetTextureSize`. -/
@[extern "lean_sdl_get_texture_size"]
opaque getSize (self : @& Texture) : IO (Float32 × Float32)

/-- The width of the texture in pixels. C: reads the public `SDL_Texture.w`. -/
@[extern "lean_sdl_texture_width"]
opaque width (self : @& Texture) : IO Int32

/-- The height of the texture in pixels. C: reads the public `SDL_Texture.h`. -/
@[extern "lean_sdl_texture_height"]
opaque height (self : @& Texture) : IO Int32

@[extern "lean_sdl_texture_format"]
private opaque formatRaw (self : @& Texture) : IO UInt32

/-- The pixel format of the texture. C: reads the public `SDL_Texture.format`. -/
def format (self : @& Texture) : IO PixelFormat := do
  return PixelFormat.ofVal (← formatRaw self)

/-- Set the palette used by the texture (SDL keeps an internal reference, so the
palette can be dropped afterwards). Throws on failure. C: `SDL_SetTexturePalette`. -/
@[extern "lean_sdl_set_texture_palette"]
opaque setPalette (self : @& Texture) (palette : @& Palette) : IO Unit

/-- The palette used by the texture, or `none` if it has none. The returned
palette is **borrowed** (owned by the texture). Note SDL also returns `NULL` on
error, which is reported here as `none`. C: `SDL_GetTexturePalette`. -/
@[extern "lean_sdl_get_texture_palette"]
opaque getPalette (self : @& Texture) : IO (Option Palette)

/-- Set the per-channel color multiplier applied during copies
(`srcC = srcC * color/255`). Throws on failure. C: `SDL_SetTextureColorMod`. -/
@[extern "lean_sdl_set_texture_color_mod"]
opaque setColorMod (self : @& Texture) (r g b : UInt8) : IO Unit

/-- The color multiplier `(r, g, b)`. Throws on failure.
C: `SDL_GetTextureColorMod`. -/
@[extern "lean_sdl_get_texture_color_mod"]
opaque getColorMod (self : @& Texture) : IO (UInt8 × UInt8 × UInt8)

/-- Set the per-channel color multiplier in floating point (`srcC = srcC * color`).
Throws on failure. C: `SDL_SetTextureColorModFloat`. -/
@[extern "lean_sdl_set_texture_color_mod_float"]
opaque setColorModFloat (self : @& Texture) (r g b : Float32) : IO Unit

/-- The floating-point color multiplier `(r, g, b)`. Throws on failure.
C: `SDL_GetTextureColorModFloat`. -/
@[extern "lean_sdl_get_texture_color_mod_float"]
opaque getColorModFloat (self : @& Texture) : IO (Float32 × Float32 × Float32)

/-- Set the alpha multiplier applied during copies (`srcA = srcA * alpha/255`).
Throws on failure. C: `SDL_SetTextureAlphaMod`. -/
@[extern "lean_sdl_set_texture_alpha_mod"]
opaque setAlphaMod (self : @& Texture) (alpha : UInt8) : IO Unit

/-- The alpha multiplier. Throws on failure. C: `SDL_GetTextureAlphaMod`. -/
@[extern "lean_sdl_get_texture_alpha_mod"]
opaque getAlphaMod (self : @& Texture) : IO UInt8

/-- Set the alpha multiplier in floating point (`srcA = srcA * alpha`). Throws on
failure. C: `SDL_SetTextureAlphaModFloat`. -/
@[extern "lean_sdl_set_texture_alpha_mod_float"]
opaque setAlphaModFloat (self : @& Texture) (alpha : Float32) : IO Unit

/-- The floating-point alpha multiplier. Throws on failure.
C: `SDL_GetTextureAlphaModFloat`. -/
@[extern "lean_sdl_get_texture_alpha_mod_float"]
opaque getAlphaModFloat (self : @& Texture) : IO Float32

@[extern "lean_sdl_set_texture_blend_mode"]
private opaque setBlendModeRaw (self : @& Texture) (mode : UInt32) : IO Unit

/-- Set the blend mode used by `Renderer.texture`. Throws on failure.
C: `SDL_SetTextureBlendMode`. -/
def setBlendMode (self : @& Texture) (mode : BlendMode) : IO Unit :=
  setBlendModeRaw self mode.val

@[extern "lean_sdl_get_texture_blend_mode"]
private opaque getBlendModeRaw (self : @& Texture) : IO UInt32

/-- The blend mode used for texture copies. Throws on failure.
C: `SDL_GetTextureBlendMode`. -/
def getBlendMode (self : @& Texture) : IO BlendMode := do
  return ⟨← getBlendModeRaw self⟩

@[extern "lean_sdl_set_texture_scale_mode"]
private opaque setScaleModeRaw (self : @& Texture) (mode : UInt32) : IO Unit

/-- Set the scale mode used for texture scaling (default is `.linear`). Throws on
failure. C: `SDL_SetTextureScaleMode`. -/
def setScaleMode (self : @& Texture) (mode : ScaleMode) : IO Unit :=
  setScaleModeRaw self mode.val

@[extern "lean_sdl_get_texture_scale_mode"]
private opaque getScaleModeRaw (self : @& Texture) : IO UInt32

/-- The scale mode used for texture scaling. Throws on failure.
C: `SDL_GetTextureScaleMode`. -/
def getScaleMode (self : @& Texture) : IO ScaleMode := do
  return ScaleMode.ofVal? (← getScaleModeRaw self) |>.getD .linear

@[extern "lean_sdl_update_texture"]
private opaque updateRaw (self : @& Texture) (hasRect : UInt8) (x y w h : Int32)
  (pixels : @& ByteArray) (pitch : Int32) : IO Unit

/-- Update (a rectangle of) the texture with new pixel data in the texture's
format; `none` updates the entire texture. `pitch` is the byte length of one
row. Throws on failure. C: `SDL_UpdateTexture`. -/
def update (self : @& Texture) (rect : Option Rect) (pixels : @& ByteArray)
    (pitch : Int32) : IO Unit :=
  let (hasR, x, y, w, h) := rectArgs rect
  updateRaw self hasR x y w h pixels pitch

@[extern "lean_sdl_update_yuv_texture"]
private opaque updateYUVRaw (self : @& Texture) (hasRect : UInt8) (x y w h : Int32)
  (y_ : @& ByteArray) (yPitch : Int32) (u : @& ByteArray) (uPitch : Int32)
  (v : @& ByteArray) (vPitch : Int32) : IO Unit

/-- Update (a rectangle of) a planar YV12/IYUV texture from separate Y, U, V
planes; `none` updates the entire texture. Throws on failure.
C: `SDL_UpdateYUVTexture`. -/
def updateYUV (self : @& Texture) (rect : Option Rect)
    (y : @& ByteArray) (yPitch : Int32) (u : @& ByteArray) (uPitch : Int32)
    (v : @& ByteArray) (vPitch : Int32) : IO Unit :=
  let (hasR, rx, ry, rw, rh) := rectArgs rect
  updateYUVRaw self hasR rx ry rw rh y yPitch u uPitch v vPitch

@[extern "lean_sdl_update_nv_texture"]
private opaque updateNVRaw (self : @& Texture) (hasRect : UInt8) (x y w h : Int32)
  (y_ : @& ByteArray) (yPitch : Int32) (uv : @& ByteArray) (uvPitch : Int32) : IO Unit

/-- Update (a rectangle of) a planar NV12/NV21 texture from separate Y and UV
planes; `none` updates the entire texture. Throws on failure.
C: `SDL_UpdateNVTexture`. -/
def updateNV (self : @& Texture) (rect : Option Rect)
    (y : @& ByteArray) (yPitch : Int32) (uv : @& ByteArray) (uvPitch : Int32) : IO Unit :=
  let (hasR, rx, ry, rw, rh) := rectArgs rect
  updateNVRaw self hasR rx ry rw rh y yPitch uv uvPitch

@[extern "lean_sdl_lock_texture_to_surface"]
private opaque lockToSurfaceRaw (self : @& Texture) (hasRect : UInt8)
  (x y w h : Int32) : IO Surface

/-- Lock (a portion of) a `.streaming` texture for **write-only** pixel access,
exposed as a **borrowed** `Surface`; `none` locks the entire texture. Fill the
locked area fully (its previous contents are undefined), then `unlock`. The
surface is invalid after `unlock` (or destroy) — do not use it afterwards.
Throws on failure. C: `SDL_LockTextureToSurface`. -/
def lockToSurface (self : @& Texture) (rect : Option Rect := none) : IO Surface :=
  let (hasR, x, y, w, h) := rectArgs rect
  lockToSurfaceRaw self hasR x y w h

/-- Unlock a texture, uploading the changes made through `lockToSurface`.
C: `SDL_UnlockTexture`. -/
@[extern "lean_sdl_unlock_texture"]
opaque unlock (self : @& Texture) : IO Unit

/-- Destroy the texture (do not use the handle afterwards; a later use — or a
second `destroy` — throws). C: `SDL_DestroyTexture`. -/
@[extern "lean_sdl_destroy_texture"]
opaque destroy (self : @& Texture) : IO Unit

end Texture

end Sdl
