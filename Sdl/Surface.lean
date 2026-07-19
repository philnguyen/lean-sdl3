module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros
public import Sdl.Error
public meta import Sdl.Error
public import Sdl.IOStream
public meta import Sdl.IOStream
public import Sdl.Pixels
public meta import Sdl.Pixels
public import Sdl.Rect
public meta import Sdl.Rect
public import Sdl.BlendMode
public meta import Sdl.BlendMode
public import Sdl.Properties
public meta import Sdl.Properties

public section

/-!
# Software surfaces (`SDL_surface.h`)

A `Surface` handle wraps an `SDL_Surface *`. Two C external classes back the one
Lean type: an **owned** class (from `createSurface`, the loaders, and the
transforms; destroyed on finalize) and a **borrowed** class (for M4's
`SDL_GetWindowSurface`; defined and registered here but unused yet).

**Finalizer-only: there is no manual `destroy`.** Surfaces hand out *borrowed*
`Palette` handles (`createPalette` / `getPalette`) whose raw `SDL_Palette *`
lives and dies with the surface. Reference-count finalizer ordering (the
borrowed palette holds an owned ref to the surface external) guarantees the
surface outlives every borrowed palette; a manual destroy could not offer that
guarantee — it would leave a live borrowed palette pointing at freed memory — so
it is deliberately omitted.

`Rect` arguments are passed flattened (a `hasRect` byte plus four `Int32`s) and
rebuilt in C; nothing reinterprets a Lean buffer as an `SDL_Rect`. Structure
results (`Color`, `FColor`, `Rect`) come back through `@[export]`ed makers.

Skipped (documented plan-level omissions):
* `SDL_CreateSurfaceFrom` — writable aliasing into external pixel memory is
  unsound across the FFI boundary.
* `SDL_LockSurface` / `SDL_UnlockSurface` — the per-pixel, fill, and blit APIs
  lock internally; revisit if a demo needs bulk direct pixel access.
* `SDL_ConvertPixels` / `SDL_ConvertPixelsAndColorspace` / `SDL_PremultiplyAlpha`
  — operate on raw caller buffers rather than surfaces.
* `SDL_GetSurfaceImages` — the returned `SDL_Surface *` array has footgun
  ownership (its pointers die on `RemoveSurfaceAlternateImages`).
-/

namespace Sdl

/-- Read-only flags on a surface. C: `SDL_SurfaceFlags`. -/
sdl_flags SurfaceFlags : UInt32 where
  | preallocated := 0x00000001  -- C: SDL_SURFACE_PREALLOCATED (uses preallocated pixel memory)
  | lockNeeded   := 0x00000002  -- C: SDL_SURFACE_LOCK_NEEDED (must be locked to access pixels)
  | locked       := 0x00000004  -- C: SDL_SURFACE_LOCKED (currently locked)
  | simdAligned  := 0x00000008  -- C: SDL_SURFACE_SIMD_ALIGNED (SIMD-aligned pixel memory)

/-- Pixel sampling mode for scaling. `SDL_SCALEMODE_INVALID` (`-1`) is an error
sentinel and is excluded (shims here never receive it). C: `SDL_ScaleMode`. -/
sdl_enum ScaleMode : UInt32 where
  | nearest  => 0  -- C: SDL_SCALEMODE_NEAREST (nearest pixel sampling)
  | linear   => 1  -- C: SDL_SCALEMODE_LINEAR (linear filtering)
  | pixelart => 2  -- C: SDL_SCALEMODE_PIXELART (nearest, improved for pixel art)

/-- Flip direction for `Surface.flip`. C: `SDL_FlipMode`. -/
sdl_enum FlipMode : UInt32 where
  | none                   => 0  -- C: SDL_FLIP_NONE
  | horizontal             => 1  -- C: SDL_FLIP_HORIZONTAL
  | vertical               => 2  -- C: SDL_FLIP_VERTICAL
  | horizontalAndVertical  => 3  -- C: SDL_FLIP_HORIZONTAL_AND_VERTICAL

/-- Maker called from C to hand an `FColor` back to Lean (its home is here,
though `FColor` itself is defined in `Sdl.Pixels`). -/
@[export lean_sdl_mk_fcolor]
private def mkFColor (r g b a : Float32) : FColor :=
  { r, g, b, a }

/-- Maker called from C to hand a `Rect` back to Lean (e.g. `getClipRect`). -/
@[export lean_sdl_mk_rect]
private def mkRect (x y w h : Int32) : Rect :=
  { x, y, w, h }

/-- A surface: a buffer of pixels in system RAM. C: `SDL_Surface`. -/
sdl_opaque Surface

@[extern "lean_sdl_surface_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

/-- Flatten an `Option Rect` to the `(hasRect, x, y, w, h)` shape the raw
externs take. -/
private def rectArgs : Option Rect → UInt8 × Int32 × Int32 × Int32 × Int32
  | some r => (1, r.x, r.y, r.w, r.h)
  | none   => (0, 0, 0, 0, 0)

@[extern "lean_sdl_create_surface"]
private opaque createSurfaceRaw (width height : Int32) (format : UInt32) : IO Surface

/-- Allocate a new surface with a given size and pixel format (pixels zeroed).
C: `SDL_CreateSurface`. -/
def createSurface (width height : Int32) (format : PixelFormat) : IO Surface :=
  createSurfaceRaw width height format.val

/-- Load a BMP or PNG image from a file (auto-detecting the format).
C: `SDL_LoadSurface`. -/
@[extern "lean_sdl_load_surface"]
opaque loadSurface (file : @& String) : IO Surface

/-- Load a BMP image from a file. C: `SDL_LoadBMP`. -/
@[extern "lean_sdl_load_bmp"]
opaque loadBMP (file : @& String) : IO Surface

/-- Load a PNG image from a file. C: `SDL_LoadPNG`. -/
@[extern "lean_sdl_load_png"]
opaque loadPNG (file : @& String) : IO Surface

/-- Load a BMP or PNG image from a stream (Lean keeps the stream; `closeio` is
always `false`). C: `SDL_LoadSurface_IO`. -/
@[extern "lean_sdl_load_surface_io"]
opaque loadSurfaceIO (src : @& IOStream) : IO Surface

/-- Load a BMP image from a stream (`closeio = false`). C: `SDL_LoadBMP_IO`. -/
@[extern "lean_sdl_load_bmp_io"]
opaque loadBMPIO (src : @& IOStream) : IO Surface

/-- Load a PNG image from a stream (`closeio = false`). C: `SDL_LoadPNG_IO`. -/
@[extern "lean_sdl_load_png_io"]
opaque loadPNGIO (src : @& IOStream) : IO Surface

namespace Surface

/-- The width of the surface in pixels. C: reads `SDL_Surface.w`. -/
@[extern "lean_sdl_surface_width"]
opaque width (self : @& Surface) : IO Int32

/-- The height of the surface in pixels. C: reads `SDL_Surface.h`. -/
@[extern "lean_sdl_surface_height"]
opaque height (self : @& Surface) : IO Int32

/-- The pitch (byte distance between rows). C: reads `SDL_Surface.pitch`. -/
@[extern "lean_sdl_surface_pitch"]
opaque pitch (self : @& Surface) : IO Int32

@[extern "lean_sdl_surface_format"]
private opaque formatRaw (self : @& Surface) : IO UInt32

/-- The pixel format of the surface. C: reads `SDL_Surface.format`. -/
def format (self : @& Surface) : IO PixelFormat := do
  return PixelFormat.ofVal (← formatRaw self)

@[extern "lean_sdl_surface_flags"]
private opaque flagsRaw (self : @& Surface) : IO UInt32

/-- The read-only flags of the surface. C: reads `SDL_Surface.flags`. -/
def flags (self : @& Surface) : IO SurfaceFlags := do
  return ⟨← flagsRaw self⟩

/-- The properties associated with the surface. Borrowed: tied to the surface's
lifetime, never destroyed from Lean. C: `SDL_GetSurfaceProperties`. -/
@[extern "lean_sdl_get_surface_properties"]
opaque getProperties (self : @& Surface) : IO Properties

@[extern "lean_sdl_set_surface_colorspace"]
private opaque setColorspaceRaw (self : @& Surface) (c : UInt32) : IO Unit

/-- Set the colorspace used by the surface (reinterprets, doesn't convert
pixels). C: `SDL_SetSurfaceColorspace`. -/
def setColorspace (self : @& Surface) (c : Colorspace) : IO Unit :=
  setColorspaceRaw self c.val

@[extern "lean_sdl_get_surface_colorspace"]
private opaque getColorspaceRaw (self : @& Surface) : IO UInt32

/-- The colorspace used by the surface. C: `SDL_GetSurfaceColorspace`
(infallible for a valid surface). -/
def getColorspace (self : @& Surface) : IO Colorspace := do
  return Colorspace.ofVal (← getColorspaceRaw self)

/-- Create a palette compatible with (and used by) this surface. The palette is
**borrowed** — owned by the surface and freed with it; do not destroy it.
Fails if the surface has no indexed format. C: `SDL_CreateSurfacePalette`. -/
@[extern "lean_sdl_create_surface_palette"]
opaque createPalette (self : @& Surface) : IO Palette

/-- The palette used by the surface, or `none` if it has none (not an error).
The returned palette is **borrowed** (owned by the surface): after a
`setPalette` replacing the surface's palette the handle must not be used (drop
it and re-fetch). C: `SDL_GetSurfacePalette`. -/
@[extern "lean_sdl_get_surface_palette"]
opaque getPalette (self : @& Surface) : IO (Option Palette)

/-- Set the palette used by the surface (SDL keeps an internal reference, so the
palette can be safely dropped afterwards). C: `SDL_SetSurfacePalette`. -/
@[extern "lean_sdl_set_surface_palette"]
opaque setPalette (self : @& Surface) (p : @& Palette) : IO Unit

/-- Add an alternate version of the surface (e.g. a high-DPI variant). SDL adds
its own reference to `image`. C: `SDL_AddSurfaceAlternateImage`. -/
@[extern "lean_sdl_add_surface_alternate_image"]
opaque addAlternateImage (self : @& Surface) (image : @& Surface) : IO Unit

/-- Whether the surface has alternate versions. C: `SDL_SurfaceHasAlternateImages`. -/
@[extern "lean_sdl_surface_has_alternate_images"]
opaque hasAlternateImages (self : @& Surface) : IO Bool

/-- Remove all alternate versions of the surface. C: `SDL_RemoveSurfaceAlternateImages`. -/
@[extern "lean_sdl_remove_surface_alternate_images"]
opaque removeAlternateImages (self : @& Surface) : IO Unit

/-- Enable or disable RLE acceleration for color-key/alpha-blended blits.
C: `SDL_SetSurfaceRLE`. -/
@[extern "lean_sdl_set_surface_rle"]
opaque setRLE (self : @& Surface) (enabled : Bool) : IO Unit

/-- Whether RLE acceleration is enabled. C: `SDL_SurfaceHasRLE`. -/
@[extern "lean_sdl_surface_has_rle"]
opaque hasRLE (self : @& Surface) : IO Bool

@[extern "lean_sdl_set_surface_color_key"]
private opaque setColorKeyRaw (self : @& Surface) (enabled : Bool) (key : UInt32) : IO Unit

/-- Set (or, with `none`, clear) the color key — the pixel value treated as
transparent in blits. C: `SDL_SetSurfaceColorKey`. -/
def setColorKey (self : @& Surface) (key : Option UInt32) : IO Unit :=
  match key with
  | some k => setColorKeyRaw self true k
  | none   => setColorKeyRaw self false 0

/-- The color key of the surface, or `none` if it has none.
C: `SDL_GetSurfaceColorKey` (guarded by `SDL_SurfaceHasColorKey`). -/
@[extern "lean_sdl_get_surface_color_key"]
opaque getColorKey (self : @& Surface) : IO (Option UInt32)

/-- Set the per-channel color multiplier applied during blits.
C: `SDL_SetSurfaceColorMod`. -/
@[extern "lean_sdl_set_surface_color_mod"]
opaque setColorMod (self : @& Surface) (r g b : UInt8) : IO Unit

/-- The color multiplier applied during blits, as a `Color` whose alpha is a
placeholder `255` (color mod has no alpha component; use `getAlphaMod`).
C: `SDL_GetSurfaceColorMod`. -/
@[extern "lean_sdl_get_surface_color_mod"]
opaque getColorMod (self : @& Surface) : IO Color

/-- Set the alpha multiplier applied during blits. C: `SDL_SetSurfaceAlphaMod`. -/
@[extern "lean_sdl_set_surface_alpha_mod"]
opaque setAlphaMod (self : @& Surface) (a : UInt8) : IO Unit

/-- The alpha multiplier applied during blits. C: `SDL_GetSurfaceAlphaMod`. -/
@[extern "lean_sdl_get_surface_alpha_mod"]
opaque getAlphaMod (self : @& Surface) : IO UInt8

@[extern "lean_sdl_set_surface_blend_mode"]
private opaque setBlendModeRaw (self : @& Surface) (m : UInt32) : IO Unit

/-- Set the blend mode used for blits from this surface.
C: `SDL_SetSurfaceBlendMode`. -/
def setBlendMode (self : @& Surface) (m : BlendMode) : IO Unit :=
  setBlendModeRaw self m.val

@[extern "lean_sdl_get_surface_blend_mode"]
private opaque getBlendModeRaw (self : @& Surface) : IO UInt32

/-- The blend mode used for blits from this surface. C: `SDL_GetSurfaceBlendMode`. -/
def getBlendMode (self : @& Surface) : IO BlendMode := do
  return ⟨← getBlendModeRaw self⟩

@[extern "lean_sdl_set_surface_clip_rect"]
private opaque setClipRectRaw (self : @& Surface)
  (hasRect : UInt8) (x y w h : Int32) : IO Bool

/-- Set the clipping rectangle (or, with `none`, reset it to the full surface).
The returned `Bool` is whether the rectangle intersects the surface (not an
error). C: `SDL_SetSurfaceClipRect`. -/
def setClipRect (self : @& Surface) (rect : Option Rect) : IO Bool :=
  let (hasR, x, y, w, h) := rectArgs rect
  setClipRectRaw self hasR x y w h

/-- The current clipping rectangle of the surface. C: `SDL_GetSurfaceClipRect`. -/
@[extern "lean_sdl_get_surface_clip_rect"]
opaque getClipRect (self : @& Surface) : IO Rect

@[extern "lean_sdl_flip_surface"]
private opaque flipRaw (self : @& Surface) (mode : UInt32) : IO Unit

/-- Flip the surface horizontally and/or vertically (in place).
C: `SDL_FlipSurface`. -/
def flip (self : @& Surface) (mode : FlipMode) : IO Unit :=
  flipRaw self mode.val

/-- A copy of the surface rotated `angle` degrees clockwise (new owned surface).
C: `SDL_RotateSurface`. -/
@[extern "lean_sdl_rotate_surface"]
opaque rotate (self : @& Surface) (angle : Float32) : IO Surface

/-- An identical copy of the surface (new owned surface). C: `SDL_DuplicateSurface`. -/
@[extern "lean_sdl_duplicate_surface"]
opaque duplicate (self : @& Surface) : IO Surface

@[extern "lean_sdl_scale_surface"]
private opaque scaleRaw (self : @& Surface) (width height : Int32) (mode : UInt32) : IO Surface

/-- A copy of the surface scaled to `w × h` (new owned surface).
C: `SDL_ScaleSurface`. -/
def scale (self : @& Surface) (w h : Int32) (mode : ScaleMode) : IO Surface :=
  scaleRaw self w h mode.val

@[extern "lean_sdl_convert_surface"]
private opaque convertRaw (self : @& Surface) (format : UInt32) : IO Surface

/-- A copy of the surface in a new pixel format (new owned surface).
C: `SDL_ConvertSurface`. -/
def convert (self : @& Surface) (format : PixelFormat) : IO Surface :=
  convertRaw self format.val

@[extern "lean_sdl_convert_surface_and_colorspace"]
private opaque convertAndColorspaceRaw (self : @& Surface) (format : UInt32)
  (palette : @& Option Palette) (colorspace : UInt32) (props : @& Option Properties) : IO Surface

/-- A copy of the surface in a new pixel format and colorspace (new owned
surface). `palette` is used for indexed target formats; `props` carries extra
color properties (`none` means 0). C: `SDL_ConvertSurfaceAndColorspace`. -/
def convertAndColorspace (self : @& Surface) (format : PixelFormat)
    (palette : Option Palette := none) (colorspace : Colorspace)
    (props : Option Properties := none) : IO Surface :=
  convertAndColorspaceRaw self format.val palette colorspace.val props

/-- Premultiply the alpha of the surface's pixels (in place). `linear` converts
from sRGB to linear space for the multiplication. C: `SDL_PremultiplySurfaceAlpha`. -/
@[extern "lean_sdl_premultiply_surface_alpha"]
opaque premultiplyAlpha (self : @& Surface) (linear : Bool) : IO Unit

/-- Clear the whole surface to a floating-point color (ignores the clip rect).
C: `SDL_ClearSurface`. -/
@[extern "lean_sdl_clear_surface"]
opaque clear (self : @& Surface) (r g b a : Float32) : IO Unit

@[extern "lean_sdl_fill_surface_rect"]
private opaque fillRectRaw (self : @& Surface)
  (hasRect : UInt8) (x y w h : Int32) (color : UInt32) : IO Unit

/-- Fill a rectangle (or, with `none`, the whole surface) with a pixel value.
C: `SDL_FillSurfaceRect`. -/
def fillRect (self : @& Surface) (rect : Option Rect) (color : UInt32) : IO Unit :=
  let (hasR, x, y, w, h) := rectArgs rect
  fillRectRaw self hasR x y w h color

/-- Fill each of `rects` with a pixel value. Implemented as a Lean loop over
`fillRect` (semantically identical to C's `SDL_FillSurfaceRects`). -/
def fillRects (self : @& Surface) (rects : Array Rect) (color : UInt32) : IO Unit := do
  for r in rects do
    fillRect self (some r) color

@[extern "lean_sdl_blit_surface"]
private opaque blitRaw (src : @& Surface)
  (hasSrc : UInt8) (sx sy sw sh : Int32)
  (dst : @& Surface) (hasDst : UInt8) (dx dy dw dh : Int32) : IO Unit

/-- Blit (copy with clipping) `src` onto `dst`. `srcRect`/`dstRect` default to
the whole surface; a `dstRect`'s width/height are ignored (taken from `srcRect`).
C: `SDL_BlitSurface`. -/
def blit (src : @& Surface) (srcRect : Option Rect)
    (dst : @& Surface) (dstRect : Option Rect) : IO Unit :=
  let (hs, sx, sy, sw, sh) := rectArgs srcRect
  let (hd, dx, dy, dw, dh) := rectArgs dstRect
  blitRaw src hs sx sy sw sh dst hd dx dy dw dh

@[extern "lean_sdl_blit_surface_unchecked"]
private opaque blitUncheckedRaw (src : @& Surface)
  (hasSrc : UInt8) (sx sy sw sh : Int32)
  (dst : @& Surface) (hasDst : UInt8) (dx dy dw dh : Int32) : IO Unit

/-- Low-level blit with no clipping or validation. SDL requires both rects
(NULL is undefined), so unlike `blit` they are not optional here.
C: `SDL_BlitSurfaceUnchecked`. -/
def blitUnchecked (src : @& Surface) (srcRect : Rect)
    (dst : @& Surface) (dstRect : Rect) : IO Unit :=
  blitUncheckedRaw src 1 srcRect.x srcRect.y srcRect.w srcRect.h
    dst 1 dstRect.x dstRect.y dstRect.w dstRect.h

@[extern "lean_sdl_blit_surface_scaled"]
private opaque blitScaledRaw (src : @& Surface)
  (hasSrc : UInt8) (sx sy sw sh : Int32)
  (dst : @& Surface) (hasDst : UInt8) (dx dy dw dh : Int32) (mode : UInt32) : IO Unit

/-- Scaled blit (may change format). C: `SDL_BlitSurfaceScaled`. -/
def blitScaled (src : @& Surface) (srcRect : Option Rect)
    (dst : @& Surface) (dstRect : Option Rect) (mode : ScaleMode) : IO Unit :=
  let (hs, sx, sy, sw, sh) := rectArgs srcRect
  let (hd, dx, dy, dw, dh) := rectArgs dstRect
  blitScaledRaw src hs sx sy sw sh dst hd dx dy dw dh mode.val

@[extern "lean_sdl_blit_surface_unchecked_scaled"]
private opaque blitUncheckedScaledRaw (src : @& Surface)
  (hasSrc : UInt8) (sx sy sw sh : Int32)
  (dst : @& Surface) (hasDst : UInt8) (dx dy dw dh : Int32) (mode : UInt32) : IO Unit

/-- Low-level scaled blit with no clipping. SDL requires both rects (NULL is
undefined), so unlike `blitScaled` they are not optional here.
C: `SDL_BlitSurfaceUncheckedScaled`. -/
def blitUncheckedScaled (src : @& Surface) (srcRect : Rect)
    (dst : @& Surface) (dstRect : Rect) (mode : ScaleMode) : IO Unit :=
  blitUncheckedScaledRaw src 1 srcRect.x srcRect.y srcRect.w srcRect.h
    dst 1 dstRect.x dstRect.y dstRect.w dstRect.h mode.val

@[extern "lean_sdl_stretch_surface"]
private opaque stretchRaw (src : @& Surface)
  (hasSrc : UInt8) (sx sy sw sh : Int32)
  (dst : @& Surface) (hasDst : UInt8) (dx dy dw dh : Int32) (mode : UInt32) : IO Unit

/-- Stretched pixel copy from `src` to `dst`. C: `SDL_StretchSurface`. -/
def stretch (src : @& Surface) (srcRect : Option Rect)
    (dst : @& Surface) (dstRect : Option Rect) (mode : ScaleMode) : IO Unit :=
  let (hs, sx, sy, sw, sh) := rectArgs srcRect
  let (hd, dx, dy, dw, dh) := rectArgs dstRect
  stretchRaw src hs sx sy sw sh dst hd dx dy dw dh mode.val

@[extern "lean_sdl_blit_surface_tiled"]
private opaque blitTiledRaw (src : @& Surface)
  (hasSrc : UInt8) (sx sy sw sh : Int32)
  (dst : @& Surface) (hasDst : UInt8) (dx dy dw dh : Int32) : IO Unit

/-- Tiled blit: repeat `srcRect` to fill `dstRect`. C: `SDL_BlitSurfaceTiled`. -/
def blitTiled (src : @& Surface) (srcRect : Option Rect)
    (dst : @& Surface) (dstRect : Option Rect) : IO Unit :=
  let (hs, sx, sy, sw, sh) := rectArgs srcRect
  let (hd, dx, dy, dw, dh) := rectArgs dstRect
  blitTiledRaw src hs sx sy sw sh dst hd dx dy dw dh

@[extern "lean_sdl_blit_surface_tiled_with_scale"]
private opaque blitTiledWithScaleRaw (src : @& Surface)
  (hasSrc : UInt8) (sx sy sw sh : Int32)
  (dst : @& Surface) (hasDst : UInt8) (dx dy dw dh : Int32)
  (scale : Float32) (mode : UInt32) : IO Unit

/-- Scaled tiled blit: scale `srcRect` by `scale`, then tile it to fill
`dstRect`. C: `SDL_BlitSurfaceTiledWithScale`. -/
def blitTiledWithScale (src : @& Surface) (srcRect : Option Rect)
    (dst : @& Surface) (dstRect : Option Rect) (scale : Float32) (mode : ScaleMode) : IO Unit :=
  let (hs, sx, sy, sw, sh) := rectArgs srcRect
  let (hd, dx, dy, dw, dh) := rectArgs dstRect
  blitTiledWithScaleRaw src hs sx sy sw sh dst hd dx dy dw dh scale mode.val

@[extern "lean_sdl_blit_surface_9grid"]
private opaque blit9GridRaw (src : @& Surface)
  (hasSrc : UInt8) (sx sy sw sh : Int32)
  (dst : @& Surface) (hasDst : UInt8) (dx dy dw dh : Int32)
  (leftWidth rightWidth topHeight bottomHeight : Int32)
  (scale : Float32) (mode : UInt32) : IO Unit

/-- 9-grid blit: split `srcRect` into a 3×3 grid by the given corner sizes,
scale the corners by `scale` (`0.0` for unscaled), and stretch the sides and
center to cover `dstRect`. C: `SDL_BlitSurface9Grid`. -/
def blit9Grid (src : @& Surface) (srcRect : Option Rect)
    (dst : @& Surface) (dstRect : Option Rect)
    (leftWidth rightWidth topHeight bottomHeight : Int32)
    (scale : Float32) (mode : ScaleMode) : IO Unit :=
  let (hs, sx, sy, sw, sh) := rectArgs srcRect
  let (hd, dx, dy, dw, dh) := rectArgs dstRect
  blit9GridRaw src hs sx sy sw sh dst hd dx dy dw dh
    leftWidth rightWidth topHeight bottomHeight scale mode.val

/-- Map an RGB triple to an opaque pixel value for the surface's format (the
palette index for indexed surfaces). C: `SDL_MapSurfaceRGB`. -/
@[extern "lean_sdl_map_surface_rgb"]
opaque mapRGB (self : @& Surface) (r g b : UInt8) : IO UInt32

/-- Map an RGBA quadruple to a pixel value for the surface's format (the palette
index for indexed surfaces). C: `SDL_MapSurfaceRGBA`. -/
@[extern "lean_sdl_map_surface_rgba"]
opaque mapRGBA (self : @& Surface) (r g b a : UInt8) : IO UInt32

/-- Read a single pixel as a `Color`. Correctness-first (for tests, not hot
loops). C: `SDL_ReadSurfacePixel`. -/
@[extern "lean_sdl_read_surface_pixel"]
opaque readPixel (self : @& Surface) (x y : Int32) : IO Color

/-- Read a single pixel as an `FColor`. C: `SDL_ReadSurfacePixelFloat`. -/
@[extern "lean_sdl_read_surface_pixel_float"]
opaque readPixelFloat (self : @& Surface) (x y : Int32) : IO FColor

/-- Copy the whole pixel buffer into a `ByteArray`: `height` rows of
`width × bytes-per-pixel` bytes, top to bottom, rows tightly packed (pitch
padding stripped), in the surface's own format — `convert` first to fix the
layout. Locks the surface if it must. Throws for formats without whole-byte
pixels. C: `SDL_Surface.pixels` under `SDL_LockSurface`. -/
@[extern "lean_sdl_surface_get_pixels"]
opaque getPixels (self : @& Surface) : IO ByteArray

@[extern "lean_sdl_write_surface_pixel"]
private opaque writePixelRaw (self : @& Surface) (x y : Int32) (r g b a : UInt8) : IO Unit

/-- Write a single pixel from a `Color`. C: `SDL_WriteSurfacePixel`. -/
def writePixel (self : @& Surface) (x y : Int32) (c : Color) : IO Unit :=
  writePixelRaw self x y c.r c.g c.b c.a

@[extern "lean_sdl_write_surface_pixel_float"]
private opaque writePixelFloatRaw (self : @& Surface) (x y : Int32) (r g b a : Float32) : IO Unit

/-- Write a single pixel from an `FColor`. C: `SDL_WriteSurfacePixelFloat`. -/
def writePixelFloat (self : @& Surface) (x y : Int32) (c : FColor) : IO Unit :=
  writePixelFloatRaw self x y c.r c.g c.b c.a

/-- Save the surface to a file in BMP format. C: `SDL_SaveBMP`. -/
@[extern "lean_sdl_save_bmp"]
opaque saveBMP (self : @& Surface) (file : @& String) : IO Unit

/-- Save the surface to a file in PNG format. C: `SDL_SavePNG`. -/
@[extern "lean_sdl_save_png"]
opaque savePNG (self : @& Surface) (file : @& String) : IO Unit

/-- Save the surface to a stream in BMP format (`closeio = false`).
C: `SDL_SaveBMP_IO`. -/
@[extern "lean_sdl_save_bmp_io"]
opaque saveBMPIO (self : @& Surface) (dst : @& IOStream) : IO Unit

/-- Save the surface to a stream in PNG format (`closeio = false`).
C: `SDL_SavePNG_IO`. -/
@[extern "lean_sdl_save_png_io"]
opaque savePNGIO (self : @& Surface) (dst : @& IOStream) : IO Unit

end Surface
end Sdl

end
