import Sdl.Core.Macros
import Sdl.Error

/-!
# Pixel formats and palettes (`SDL_pixels.h`)

`PixelFormat` and `Colorspace` are version-open enums (`sdl_enum_open`): SDL
returns them from queries and future releases may add members. The byte-order
aliases (`SDL_PIXELFORMAT_RGBA32` …, `SDL_COLORSPACE_RGB_DEFAULT` …) duplicate
canonical values and are bound as plain `def`s so `ofVal` stays well-defined.

A `Palette` handle is backed by two C external classes: an **owned** class
(from `Sdl.createPalette`, destroyed on finalize or via `Palette.destroy`) and
a **borrowed** class (palettes owned by another handle, e.g. a surface's;
handed out by later modules, never destroyed from Lean).

Skipped:
* The colorspace component enums (`SDL_ColorType`, `SDL_ColorRange`,
  `SDL_ColorPrimaries`, `SDL_TransferCharacteristics`,
  `SDL_MatrixCoefficients`, `SDL_ChromaLocation`) and the `SDL_COLORSPACE*` /
  `SDL_ISCOLORSPACE_*` introspection macros — bind them if colorspace
  introspection is ever needed.
* The pixel-format component enums (`SDL_PixelType`, `SDL_BitmapOrder`,
  `SDL_PackedOrder`, `SDL_ArrayOrder`, `SDL_PackedLayout`) and the raw
  `SDL_DEFINE_PIXELFORMAT`/`SDL_PIXELFLAG`/`SDL_PIXELTYPE`/`SDL_PIXELORDER`/
  `SDL_PIXELLAYOUT` macros — the `SDL_ISPIXELFORMAT_*` predicates and
  bits/bytes-per-pixel helpers below cover the useful introspection.
* `SDL_ALPHA_OPAQUE`/`SDL_ALPHA_TRANSPARENT` (and `_FLOAT`) — trivial
  literals (`255`/`0` and `1.0`/`0.0`).
-/

namespace Sdl

/-- A pixel format. Every distinct-valued member of the C enum is a
constructor; the platform byte-order aliases (`rgba32` …) are `def`s below.
C: `SDL_PixelFormat`. -/
sdl_enum_open PixelFormat : UInt32 where
  | unknown      => 0x00000000  -- C: SDL_PIXELFORMAT_UNKNOWN
  | index1lsb    => 0x11100100  -- C: SDL_PIXELFORMAT_INDEX1LSB
  | index1msb    => 0x11200100  -- C: SDL_PIXELFORMAT_INDEX1MSB
  | index2lsb    => 0x1c100200  -- C: SDL_PIXELFORMAT_INDEX2LSB
  | index2msb    => 0x1c200200  -- C: SDL_PIXELFORMAT_INDEX2MSB
  | index4lsb    => 0x12100400  -- C: SDL_PIXELFORMAT_INDEX4LSB
  | index4msb    => 0x12200400  -- C: SDL_PIXELFORMAT_INDEX4MSB
  | index8       => 0x13000801  -- C: SDL_PIXELFORMAT_INDEX8
  | rgb332       => 0x14110801  -- C: SDL_PIXELFORMAT_RGB332
  | xrgb4444     => 0x15120c02  -- C: SDL_PIXELFORMAT_XRGB4444
  | xbgr4444     => 0x15520c02  -- C: SDL_PIXELFORMAT_XBGR4444
  | xrgb1555     => 0x15130f02  -- C: SDL_PIXELFORMAT_XRGB1555
  | xbgr1555     => 0x15530f02  -- C: SDL_PIXELFORMAT_XBGR1555
  | argb4444     => 0x15321002  -- C: SDL_PIXELFORMAT_ARGB4444
  | rgba4444     => 0x15421002  -- C: SDL_PIXELFORMAT_RGBA4444
  | abgr4444     => 0x15721002  -- C: SDL_PIXELFORMAT_ABGR4444
  | bgra4444     => 0x15821002  -- C: SDL_PIXELFORMAT_BGRA4444
  | argb1555     => 0x15331002  -- C: SDL_PIXELFORMAT_ARGB1555
  | rgba5551     => 0x15441002  -- C: SDL_PIXELFORMAT_RGBA5551
  | abgr1555     => 0x15731002  -- C: SDL_PIXELFORMAT_ABGR1555
  | bgra5551     => 0x15841002  -- C: SDL_PIXELFORMAT_BGRA5551
  | rgb565       => 0x15151002  -- C: SDL_PIXELFORMAT_RGB565
  | bgr565       => 0x15551002  -- C: SDL_PIXELFORMAT_BGR565
  | rgb24        => 0x17101803  -- C: SDL_PIXELFORMAT_RGB24
  | bgr24        => 0x17401803  -- C: SDL_PIXELFORMAT_BGR24
  | xrgb8888     => 0x16161804  -- C: SDL_PIXELFORMAT_XRGB8888
  | rgbx8888     => 0x16261804  -- C: SDL_PIXELFORMAT_RGBX8888
  | xbgr8888     => 0x16561804  -- C: SDL_PIXELFORMAT_XBGR8888
  | bgrx8888     => 0x16661804  -- C: SDL_PIXELFORMAT_BGRX8888
  | argb8888     => 0x16362004  -- C: SDL_PIXELFORMAT_ARGB8888
  | rgba8888     => 0x16462004  -- C: SDL_PIXELFORMAT_RGBA8888
  | abgr8888     => 0x16762004  -- C: SDL_PIXELFORMAT_ABGR8888
  | bgra8888     => 0x16862004  -- C: SDL_PIXELFORMAT_BGRA8888
  | xrgb2101010  => 0x16172004  -- C: SDL_PIXELFORMAT_XRGB2101010
  | xbgr2101010  => 0x16572004  -- C: SDL_PIXELFORMAT_XBGR2101010
  | argb2101010  => 0x16372004  -- C: SDL_PIXELFORMAT_ARGB2101010
  | abgr2101010  => 0x16772004  -- C: SDL_PIXELFORMAT_ABGR2101010
  | rgb48        => 0x18103006  -- C: SDL_PIXELFORMAT_RGB48
  | bgr48        => 0x18403006  -- C: SDL_PIXELFORMAT_BGR48
  | rgba64       => 0x18204008  -- C: SDL_PIXELFORMAT_RGBA64
  | argb64       => 0x18304008  -- C: SDL_PIXELFORMAT_ARGB64
  | bgra64       => 0x18504008  -- C: SDL_PIXELFORMAT_BGRA64
  | abgr64       => 0x18604008  -- C: SDL_PIXELFORMAT_ABGR64
  | rgb48Float   => 0x1a103006  -- C: SDL_PIXELFORMAT_RGB48_FLOAT
  | bgr48Float   => 0x1a403006  -- C: SDL_PIXELFORMAT_BGR48_FLOAT
  | rgba64Float  => 0x1a204008  -- C: SDL_PIXELFORMAT_RGBA64_FLOAT
  | argb64Float  => 0x1a304008  -- C: SDL_PIXELFORMAT_ARGB64_FLOAT
  | bgra64Float  => 0x1a504008  -- C: SDL_PIXELFORMAT_BGRA64_FLOAT
  | abgr64Float  => 0x1a604008  -- C: SDL_PIXELFORMAT_ABGR64_FLOAT
  | rgb96Float   => 0x1b10600c  -- C: SDL_PIXELFORMAT_RGB96_FLOAT
  | bgr96Float   => 0x1b40600c  -- C: SDL_PIXELFORMAT_BGR96_FLOAT
  | rgba128Float => 0x1b208010  -- C: SDL_PIXELFORMAT_RGBA128_FLOAT
  | argb128Float => 0x1b308010  -- C: SDL_PIXELFORMAT_ARGB128_FLOAT
  | bgra128Float => 0x1b508010  -- C: SDL_PIXELFORMAT_BGRA128_FLOAT
  | abgr128Float => 0x1b608010  -- C: SDL_PIXELFORMAT_ABGR128_FLOAT
  | yv12         => 0x32315659  -- C: SDL_PIXELFORMAT_YV12 (planar Y + V + U)
  | iyuv         => 0x56555949  -- C: SDL_PIXELFORMAT_IYUV (planar Y + U + V)
  | yuy2         => 0x32595559  -- C: SDL_PIXELFORMAT_YUY2 (packed Y0+U0+Y1+V0)
  | uyvy         => 0x59565955  -- C: SDL_PIXELFORMAT_UYVY (packed U0+Y0+V0+Y1)
  | yvyu         => 0x55595659  -- C: SDL_PIXELFORMAT_YVYU (packed Y0+V0+Y1+U0)
  | nv12         => 0x3231564e  -- C: SDL_PIXELFORMAT_NV12 (planar Y + U/V interleaved)
  | nv21         => 0x3132564e  -- C: SDL_PIXELFORMAT_NV21 (planar Y + V/U interleaved)
  | p010         => 0x30313050  -- C: SDL_PIXELFORMAT_P010 (planar Y + U/V interleaved)
  | externalOes  => 0x2053454f  -- C: SDL_PIXELFORMAT_EXTERNAL_OES (Android video texture)
  | mjpg         => 0x47504a4d  -- C: SDL_PIXELFORMAT_MJPG (Motion JPEG)

namespace PixelFormat

/-- Little-endian alias of `abgr8888` (RGBA byte array of color data).
C: `SDL_PIXELFORMAT_RGBA32`. -/
def rgba32 : PixelFormat := .abgr8888
/-- Little-endian alias of `bgra8888` (ARGB byte array of color data).
C: `SDL_PIXELFORMAT_ARGB32`. -/
def argb32 : PixelFormat := .bgra8888
/-- Little-endian alias of `argb8888` (BGRA byte array of color data).
C: `SDL_PIXELFORMAT_BGRA32`. -/
def bgra32 : PixelFormat := .argb8888
/-- Little-endian alias of `rgba8888` (ABGR byte array of color data).
C: `SDL_PIXELFORMAT_ABGR32`. -/
def abgr32 : PixelFormat := .rgba8888
/-- Little-endian alias of `xbgr8888` (RGBX byte array of color data).
C: `SDL_PIXELFORMAT_RGBX32`. -/
def rgbx32 : PixelFormat := .xbgr8888
/-- Little-endian alias of `bgrx8888` (XRGB byte array of color data).
C: `SDL_PIXELFORMAT_XRGB32`. -/
def xrgb32 : PixelFormat := .bgrx8888
/-- Little-endian alias of `xrgb8888` (BGRX byte array of color data).
C: `SDL_PIXELFORMAT_BGRX32`. -/
def bgrx32 : PixelFormat := .xrgb8888
/-- Little-endian alias of `rgbx8888` (XBGR byte array of color data).
C: `SDL_PIXELFORMAT_XBGR32`. -/
def xbgr32 : PixelFormat := .rgbx8888

#guard rgba32.val == 0x16762004
#guard argb32.val == 0x16862004
#guard bgra32.val == 0x16362004
#guard abgr32.val == 0x16462004
#guard rgbx32.val == 0x16561804
#guard xrgb32.val == 0x16661804
#guard bgrx32.val == 0x16161804
#guard xbgr32.val == 0x16261804

/-! ### Introspection (pure reimplementations of the header macros) -/

/-- The flag nibble (bits 28–31) of a format value. C: `SDL_PIXELFLAG`. -/
private def flagBits (v : UInt32) : UInt32 := (v >>> 28) &&& 0x0F

/-- The `SDL_PixelType` nibble (bits 24–27). C: `SDL_PIXELTYPE`. -/
private def typeBits (v : UInt32) : UInt32 := (v >>> 24) &&& 0x0F

/-- The order nibble (bits 20–23). C: `SDL_PIXELORDER`. -/
private def orderBits (v : UInt32) : UInt32 := (v >>> 20) &&& 0x0F

/-- The `SDL_PackedLayout` nibble (bits 16–19). C: `SDL_PIXELLAYOUT`. -/
private def layoutBits (v : UInt32) : UInt32 := (v >>> 16) &&& 0x0F

/-- Whether this is a "FourCC" format (opaque encodings such as `yuy2`;
covers custom and other unusual formats). C: `SDL_ISPIXELFORMAT_FOURCC`. -/
def isFourcc (f : PixelFormat) : Bool :=
  f.val != 0 && flagBits f.val != 1

/-- Bits per pixel; `0` for FourCC formats (a per-pixel measure rarely makes
sense for them). C: `SDL_BITSPERPIXEL`. -/
def bitsPerPixel (f : PixelFormat) : UInt32 :=
  if f.isFourcc then 0 else (f.val >>> 8) &&& 0xFF

/-- Bytes per pixel. FourCC formats do their best: `2` for `yuy2`, `uyvy`,
`yvyu`, and `p010`, `1` for the rest (many have no meaningful measurement).
C: `SDL_BYTESPERPIXEL`. -/
def bytesPerPixel (f : PixelFormat) : UInt32 :=
  if f.isFourcc then
    if f.val == yuy2.val || f.val == uyvy.val || f.val == yvyu.val ||
       f.val == p010.val then 2 else 1
  else
    f.val &&& 0xFF

/-- Whether the format is indexed (pixel types `INDEX1`, `INDEX2`, `INDEX4`,
`INDEX8`). C: `SDL_ISPIXELFORMAT_INDEXED`. -/
def isIndexed (f : PixelFormat) : Bool :=
  !f.isFourcc &&
  (typeBits f.val == 1 ||   -- SDL_PIXELTYPE_INDEX1
   typeBits f.val == 12 ||  -- SDL_PIXELTYPE_INDEX2
   typeBits f.val == 2 ||   -- SDL_PIXELTYPE_INDEX4
   typeBits f.val == 3)     -- SDL_PIXELTYPE_INDEX8

/-- Whether the format is packed (pixel types `PACKED8`, `PACKED16`,
`PACKED32`). C: `SDL_ISPIXELFORMAT_PACKED`. -/
def isPacked (f : PixelFormat) : Bool :=
  !f.isFourcc &&
  (typeBits f.val == 4 ||   -- SDL_PIXELTYPE_PACKED8
   typeBits f.val == 5 ||   -- SDL_PIXELTYPE_PACKED16
   typeBits f.val == 6)     -- SDL_PIXELTYPE_PACKED32

/-- Whether the format is an array format (pixel types `ARRAYU8`, `ARRAYU16`,
`ARRAYU32`, `ARRAYF16`, `ARRAYF32`). C: `SDL_ISPIXELFORMAT_ARRAY`. -/
def isArray (f : PixelFormat) : Bool :=
  !f.isFourcc &&
  (typeBits f.val == 7 ||   -- SDL_PIXELTYPE_ARRAYU8
   typeBits f.val == 8 ||   -- SDL_PIXELTYPE_ARRAYU16
   typeBits f.val == 9 ||   -- SDL_PIXELTYPE_ARRAYU32
   typeBits f.val == 10 ||  -- SDL_PIXELTYPE_ARRAYF16
   typeBits f.val == 11)    -- SDL_PIXELTYPE_ARRAYF32

/-- Whether the format is 10-bit (pixel type `PACKED32` with layout
`2101010`). C: `SDL_ISPIXELFORMAT_10BIT`. -/
def is10Bit (f : PixelFormat) : Bool :=
  !f.isFourcc &&
  typeBits f.val == 6 &&    -- SDL_PIXELTYPE_PACKED32
  layoutBits f.val == 7     -- SDL_PACKEDLAYOUT_2101010

/-- Whether the format is floating point (pixel types `ARRAYF16`, `ARRAYF32`).
C: `SDL_ISPIXELFORMAT_FLOAT`. -/
def isFloat (f : PixelFormat) : Bool :=
  !f.isFourcc &&
  (typeBits f.val == 10 ||  -- SDL_PIXELTYPE_ARRAYF16
   typeBits f.val == 11)    -- SDL_PIXELTYPE_ARRAYF32

/-- Whether the format has an alpha channel (a packed format with order
`ARGB`/`RGBA`/`ABGR`/`BGRA`, or an array format with order
`ARGB`/`RGBA`/`ABGR`/`BGRA`). C: `SDL_ISPIXELFORMAT_ALPHA`. -/
def isAlpha (f : PixelFormat) : Bool :=
  (f.isPacked &&
    (orderBits f.val == 3 ||   -- SDL_PACKEDORDER_ARGB
     orderBits f.val == 4 ||   -- SDL_PACKEDORDER_RGBA
     orderBits f.val == 7 ||   -- SDL_PACKEDORDER_ABGR
     orderBits f.val == 8)) || -- SDL_PACKEDORDER_BGRA
  (f.isArray &&
    (orderBits f.val == 3 ||   -- SDL_ARRAYORDER_ARGB
     orderBits f.val == 2 ||   -- SDL_ARRAYORDER_RGBA
     orderBits f.val == 6 ||   -- SDL_ARRAYORDER_ABGR
     orderBits f.val == 5))    -- SDL_ARRAYORDER_BGRA

#guard rgba8888.bitsPerPixel == 32
#guard rgba8888.bytesPerPixel == 4
#guard rgb565.bitsPerPixel == 16
#guard rgb565.bytesPerPixel == 2
#guard index1lsb.bitsPerPixel == 1
#guard yuy2.isFourcc
#guard !rgba8888.isFourcc
#guard !unknown.isFourcc
#guard yuy2.bitsPerPixel == 0
#guard yuy2.bytesPerPixel == 2
#guard yv12.bytesPerPixel == 1
#guard p010.bytesPerPixel == 2
#guard index8.isIndexed
#guard index2msb.isIndexed
#guard !rgba8888.isIndexed
#guard !yuy2.isIndexed
#guard rgb565.isPacked
#guard !rgb24.isPacked
#guard rgb24.isArray
#guard rgba64Float.isArray
#guard !rgba8888.isArray
#guard argb2101010.is10Bit
#guard xbgr2101010.is10Bit
#guard !rgba8888.is10Bit
#guard rgba128Float.isFloat
#guard rgb48Float.isFloat
#guard !rgba64.isFloat
#guard rgba8888.isAlpha
#guard !xrgb8888.isAlpha
#guard rgba64.isAlpha
#guard !rgb24.isAlpha
#guard !yuy2.isAlpha

end PixelFormat

/-- A colorspace. Every distinct-valued member of the C enum is a constructor;
the default aliases are `def`s below. Custom values can be built with C's
`SDL_DEFINE_COLORSPACE` packing (unbound here, see the module docstring).
C: `SDL_Colorspace`. -/
sdl_enum_open Colorspace : UInt32 where
  | unknown       => 0x00000000  -- C: SDL_COLORSPACE_UNKNOWN
  | srgb          => 0x120005a0  -- C: SDL_COLORSPACE_SRGB (gamma-corrected; default for SDL rendering and 8-bit RGB surfaces)
  | srgbLinear    => 0x12000500  -- C: SDL_COLORSPACE_SRGB_LINEAR (linear; default for floating point surfaces)
  | hdr10         => 0x12002600  -- C: SDL_COLORSPACE_HDR10 (non-linear HDR; default for 10-bit surfaces)
  | jpeg          => 0x220004c6  -- C: SDL_COLORSPACE_JPEG
  | bt601Limited  => 0x211018c6  -- C: SDL_COLORSPACE_BT601_LIMITED
  | bt601Full     => 0x221018c6  -- C: SDL_COLORSPACE_BT601_FULL
  | bt709Limited  => 0x21100421  -- C: SDL_COLORSPACE_BT709_LIMITED
  | bt709Full     => 0x22100421  -- C: SDL_COLORSPACE_BT709_FULL
  | bt2020Limited => 0x21102609  -- C: SDL_COLORSPACE_BT2020_LIMITED
  | bt2020Full    => 0x22102609  -- C: SDL_COLORSPACE_BT2020_FULL

/-- Alias of `srgb`: the default colorspace for RGB surfaces if none is
specified. C: `SDL_COLORSPACE_RGB_DEFAULT`. -/
def Colorspace.rgbDefault : Colorspace := .srgb
/-- Alias of `bt601Limited`: the default colorspace for YUV surfaces if none
is specified. C: `SDL_COLORSPACE_YUV_DEFAULT`. -/
def Colorspace.yuvDefault : Colorspace := .bt601Limited

#guard Colorspace.rgbDefault.val == 0x120005a0
#guard Colorspace.yuvDefault.val == 0x211018c6

/-- A color as 8-bit RGBA components. Its byte layout matches C's `SDL_Color`
exactly (`r`, `g`, `b`, `a` — the `rgba32` pixel format). C: `SDL_Color`. -/
structure Color where
  /-- Red component [0-255]. -/
  r : UInt8
  /-- Green component [0-255]. -/
  g : UInt8
  /-- Blue component [0-255]. -/
  b : UInt8
  /-- Alpha component [0-255] (255 = opaque). -/
  a : UInt8
deriving Repr, BEq, DecidableEq, Inhabited

/-- Maker called from C to hand a `Color` back to Lean. -/
@[export lean_sdl_mk_color]
private def mkColor (r g b a : UInt8) : Color :=
  { r, g, b, a }

/-- A color as floating-point RGBA components (the `rgba128Float` pixel
format). C: `SDL_FColor`. -/
structure FColor where
  /-- Red component. -/
  r : Float32
  /-- Green component. -/
  g : Float32
  /-- Blue component. -/
  b : Float32
  /-- Alpha component (1.0 = opaque). -/
  a : Float32
deriving Repr, BEq, Inhabited

/-- Details about the format of a pixel (a copy of the fields of the
static/cached C struct). C: `SDL_PixelFormatDetails`. -/
structure PixelFormatDetails where
  /-- The pixel format this describes. -/
  format : PixelFormat
  /-- Bits per pixel. -/
  bitsPerPixel : UInt8
  /-- Bytes per pixel. -/
  bytesPerPixel : UInt8
  /-- Red bit mask. -/
  rMask : UInt32
  /-- Green bit mask. -/
  gMask : UInt32
  /-- Blue bit mask. -/
  bMask : UInt32
  /-- Alpha bit mask. -/
  aMask : UInt32
  /-- Bits in the red mask. -/
  rBits : UInt8
  /-- Bits in the green mask. -/
  gBits : UInt8
  /-- Bits in the blue mask. -/
  bBits : UInt8
  /-- Bits in the alpha mask. -/
  aBits : UInt8
  /-- Shift of the red mask. -/
  rShift : UInt8
  /-- Shift of the green mask. -/
  gShift : UInt8
  /-- Shift of the blue mask. -/
  bShift : UInt8
  /-- Shift of the alpha mask. -/
  aShift : UInt8
deriving Repr, BEq, DecidableEq, Inhabited

/-- Maker called from C to hand a `PixelFormatDetails` back to Lean (flattened
scalars; the raw format value is decoded with the total `PixelFormat.ofVal`). -/
@[export lean_sdl_mk_pixel_format_details]
private def mkPixelFormatDetails (format : UInt32) (bitsPerPixel bytesPerPixel : UInt8)
    (rMask gMask bMask aMask : UInt32)
    (rBits gBits bBits aBits rShift gShift bShift aShift : UInt8) : PixelFormatDetails :=
  { format := PixelFormat.ofVal format, bitsPerPixel, bytesPerPixel,
    rMask, gMask, bMask, aMask, rBits, gBits, bBits, aBits,
    rShift, gShift, bShift, aShift }

/-- A bpp-plus-RGBA-masks description of a pixel format. C: the out parameters
of `SDL_GetMasksForPixelFormat`. -/
structure PixelFormatMasks where
  /-- Bits per pixel (usually 15, 16, or 32). -/
  bpp : Int32
  /-- Red bit mask. -/
  rMask : UInt32
  /-- Green bit mask. -/
  gMask : UInt32
  /-- Blue bit mask. -/
  bMask : UInt32
  /-- Alpha bit mask. -/
  aMask : UInt32
deriving Repr, BEq, DecidableEq, Inhabited

/-- Maker called from C to hand a `PixelFormatMasks` back to Lean. -/
@[export lean_sdl_mk_pixel_format_masks]
private def mkPixelFormatMasks (bpp : Int32) (rMask gMask bMask aMask : UInt32) :
    PixelFormatMasks :=
  { bpp, rMask, gMask, bMask, aMask }

/-- A set of indexed colors representing a palette. C: `SDL_Palette`. -/
sdl_opaque Palette

@[extern "lean_sdl_pixels_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

@[extern "lean_sdl_get_pixel_format_name"]
private opaque getPixelFormatNameRaw (format : UInt32) : String

/-- The human-readable name of a pixel format (`"SDL_PIXELFORMAT_UNKNOWN"` if
the format isn't recognized). Pure: the C function returns a static string and
never fails. C: `SDL_GetPixelFormatName`. -/
def getPixelFormatName (format : PixelFormat) : String :=
  getPixelFormatNameRaw format.val

@[extern "lean_sdl_get_masks_for_pixel_format"]
private opaque getMasksForPixelFormatRaw (format : UInt32) : IO PixelFormatMasks

/-- Convert a pixel format to a bpp value and RGBA masks. Throws when the
format has no mask representation. C: `SDL_GetMasksForPixelFormat`. -/
def getMasksForPixelFormat (format : PixelFormat) : IO PixelFormatMasks :=
  getMasksForPixelFormatRaw format.val

@[extern "lean_sdl_get_pixel_format_for_masks"]
private opaque getPixelFormatForMasksRaw
  (bpp : Int32) (rMask gMask bMask aMask : UInt32) : IO UInt32

/-- Convert a bpp value and RGBA masks to a pixel format. Returns `.unknown`
when no format matches (not an error). C: `SDL_GetPixelFormatForMasks`. -/
def getPixelFormatForMasks (bpp : Int32) (rMask gMask bMask aMask : UInt32) :
    IO PixelFormat := do
  return PixelFormat.ofVal (← getPixelFormatForMasksRaw bpp rMask gMask bMask aMask)

@[extern "lean_sdl_get_pixel_format_details"]
private opaque getPixelFormatDetailsRaw (format : UInt32) : IO PixelFormatDetails

/-- Details about a pixel format (copied out of SDL's static/cached struct).
Throws on an unsupported format. C: `SDL_GetPixelFormatDetails`. -/
def getPixelFormatDetails (format : PixelFormat) : IO PixelFormatDetails :=
  getPixelFormatDetailsRaw format.val

/-- Create a palette with `ncolors` entries, initialized to white. Owned:
destroyed when garbage-collected or via `Palette.destroy`.
C: `SDL_CreatePalette`. -/
@[extern "lean_sdl_create_palette"]
opaque createPalette (ncolors : Int32) : IO Palette

namespace Palette

/-- The number of colors in the palette. C: reads `SDL_Palette.ncolors`. -/
@[extern "lean_sdl_palette_ncolors"]
opaque ncolors (palette : @& Palette) : IO Int32

@[extern "lean_sdl_set_palette_colors"]
private opaque setColorsRaw (palette : @& Palette) (colors : @& ByteArray)
  (firstColor : Int32) : IO Unit

/-- Copy `colors` into the palette starting at index `firstColor`. The wrapper
packs the colors into a `ByteArray` (4 bytes per color, `r`,`g`,`b`,`a` —
exactly `SDL_Color`'s layout) so C never reads a Lean structure.
C: `SDL_SetPaletteColors`. -/
def setColors (palette : Palette) (colors : Array Color) (firstColor : Int32 := 0) :
    IO Unit := do
  let mut bytes := ByteArray.emptyWithCapacity (colors.size * 4)
  for c in colors do
    bytes := ((bytes.push c.r).push c.g).push c.b |>.push c.a
  setColorsRaw palette bytes firstColor

/-- All colors currently in the palette (copied out). C: reads
`SDL_Palette.colors`. -/
@[extern "lean_sdl_get_palette_colors"]
opaque getColors (palette : @& Palette) : IO (Array Color)

/-- Destroy the palette (do not use the handle afterwards). Throws if the
palette is borrowed (owned by another handle, e.g. a surface).
C: `SDL_DestroyPalette`. -/
@[extern "lean_sdl_destroy_palette"]
opaque destroy (palette : @& Palette) : IO Unit

end Palette

@[extern "lean_sdl_map_rgb"]
private opaque mapRGBRaw (format : UInt32) (palette : @& Option Palette)
  (r g b : UInt8) : IO UInt32

/-- Map an RGB triple to an opaque pixel value for a pixel format (alpha, if
the format has it, is fully opaque). For indexed formats pass the `palette`;
the result is then the index of the closest matching color. Formats narrower
than 32-bpp leave the unused upper bits zero. C: `SDL_MapRGB` (the required
`SDL_PixelFormatDetails` is looked up internally). -/
def mapRGB (format : PixelFormat) (palette : Option Palette := none)
    (r g b : UInt8) : IO UInt32 :=
  mapRGBRaw format.val palette r g b

@[extern "lean_sdl_map_rgba"]
private opaque mapRGBARaw (format : UInt32) (palette : @& Option Palette)
  (r g b a : UInt8) : IO UInt32

/-- Map an RGBA quadruple to a pixel value for a pixel format (alpha is
ignored for formats without it, including indexed ones). For indexed formats
pass the `palette`. C: `SDL_MapRGBA` (the required `SDL_PixelFormatDetails` is
looked up internally). -/
def mapRGBA (format : PixelFormat) (palette : Option Palette := none)
    (r g b a : UInt8) : IO UInt32 :=
  mapRGBARaw format.val palette r g b a

@[extern "lean_sdl_get_rgb"]
private opaque getRGBRaw (pixel : UInt32) (format : UInt32)
  (palette : @& Option Palette) : IO Color

/-- Get the RGB components of a pixel value in the given format (the full
8-bit range is used for components narrower than 8 bits). The returned alpha
is always 255. C: `SDL_GetRGB` (the required `SDL_PixelFormatDetails` is
looked up internally). -/
def getRGB (pixel : UInt32) (format : PixelFormat)
    (palette : Option Palette := none) : IO Color :=
  getRGBRaw pixel format.val palette

@[extern "lean_sdl_get_rgba"]
private opaque getRGBARaw (pixel : UInt32) (format : UInt32)
  (palette : @& Option Palette) : IO Color

/-- Get the RGBA components of a pixel value in the given format (the full
8-bit range is used for components narrower than 8 bits; alpha is 255 for
formats without an alpha channel). C: `SDL_GetRGBA` (the required
`SDL_PixelFormatDetails` is looked up internally). -/
def getRGBA (pixel : UInt32) (format : PixelFormat)
    (palette : Option Palette := none) : IO Color :=
  getRGBARaw pixel format.val palette

end Sdl
