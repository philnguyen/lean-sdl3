import Sdl
import Tests.Harness

namespace Tests.Pixels
open Sdl Tests.Harness

/-- Format details and name queries, map/get pixel round-trips, mask
round-trips, and the palette life cycle (create, ncolors, set/get colors,
indexed mapping, destroy, use-after-destroy). -/
def run : IO Unit := do
  -- getPixelFormatDetails .rgba8888
  let d ← Sdl.getPixelFormatDetails .rgba8888
  check "details format rgba8888" (d.format == .rgba8888)
  check "details bitsPerPixel 32" (d.bitsPerPixel == 32)
  check "details bytesPerPixel 4" (d.bytesPerPixel == 4)
  check "details masks rgba8888"
    (d.rMask == 0xFF000000 && d.gMask == 0x00FF0000 &&
     d.bMask == 0x0000FF00 && d.aMask == 0x000000FF)
  -- the C-side name agrees with the Lean member
  check "getPixelFormatName rgba8888"
    (Sdl.getPixelFormatName .rgba8888 == "SDL_PIXELFORMAT_RGBA8888")
  -- mapRGB/getRGB round-trip on xrgb8888 (no alpha channel: comes back opaque)
  let px ← Sdl.mapRGB .xrgb8888 (r := 12) (g := 34) (b := 56)
  check "mapRGB/getRGB xrgb8888 round-trip"
    ((← Sdl.getRGB px .xrgb8888) == ⟨12, 34, 56, 255⟩)
  -- mapRGBA/getRGBA round-trip on rgba8888 (Color comes back exactly)
  let px2 ← Sdl.mapRGBA .rgba8888 (r := 12) (g := 34) (b := 56) (a := 78)
  check "mapRGBA/getRGBA rgba8888 round-trip"
    ((← Sdl.getRGBA px2 .rgba8888) == ⟨12, 34, 56, 78⟩)
  -- masks round-trip: rgb565 -> masks -> rgb565
  let m ← Sdl.getMasksForPixelFormat .rgb565
  check "rgb565 masks bpp 16" (m.bpp == 16)
  check "masks round-trip rgb565"
    ((← Sdl.getPixelFormatForMasks m.bpp m.rMask m.gMask m.bMask m.aMask) == .rgb565)
  -- garbage masks -> .unknown (not an error)
  check "garbage masks give .unknown"
    ((← Sdl.getPixelFormatForMasks 13 0xDEAD 0xBEEF 0x1234 0x5678) == .unknown)
  -- palette life cycle
  let pal ← Sdl.createPalette 256
  check "createPalette ncolors 256" ((← pal.ncolors) == 256)
  let red   : Sdl.Color := ⟨255, 0, 0, 255⟩
  let green : Sdl.Color := ⟨0, 255, 0, 255⟩
  let blue  : Sdl.Color := ⟨0, 0, 255, 255⟩
  pal.setColors #[red, green, blue]
  let colors ← pal.getColors
  check "getColors size 256" (colors.size == 256)
  check "setColors/getColors round-trip"
    (colors[0]! == red && colors[1]! == green && colors[2]! == blue)
  check "unset entries stay white" (colors[3]! == ⟨255, 255, 255, 255⟩)
  -- setColors at an offset
  pal.setColors #[⟨1, 2, 3, 4⟩] (firstColor := 10)
  check "setColors firstColor offset" ((← pal.getColors)[10]! == ⟨1, 2, 3, 4⟩)
  -- mapRGB with .index8 + palette maps to the closest entry's index
  check "mapRGB index8 palette maps green to 1"
    ((← Sdl.mapRGB .index8 (palette := some pal) (r := 0) (g := 255) (b := 0)) == 1)
  -- destroy, then any use throws
  pal.destroy
  checkThrows "palette ncolors after destroy throws" pal.ncolors
  checkThrows "palette getColors after destroy throws" pal.getColors
  checkThrows "mapRGB with destroyed palette throws"
    (Sdl.mapRGB .index8 (palette := some pal) (r := 0) (g := 255) (b := 0))
  checkThrows "double destroy throws" pal.destroy

end Tests.Pixels
