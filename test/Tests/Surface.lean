import Sdl
import Tests.Harness

namespace Tests.Surface
open Sdl Tests.Harness

set_option maxRecDepth 4096 in
/-- Surface creation and field queries, pixel read/write/map, color-key /
color-mod / alpha-mod / blend-mode / clip-rect round-trips, convert/scale/flip/
duplicate, blits (plain and the scaled/tiled/stretch/9-grid smoke set), an
indexed-surface + borrowed-palette life cycle, alternate images, and BMP/PNG
round-trips via both files and an in-memory stream. -/
def run : IO Unit := do
  -- create a 4x4 RGBA8888 surface; check the read-only fields
  let surf ← Sdl.createSurface 4 4 .rgba8888
  check "width == 4" ((← surf.width) == 4)
  check "height == 4" ((← surf.height) == 4)
  check "pitch >= 16" ((← surf.pitch) >= 16)
  check "format == rgba8888" ((← surf.format) == .rgba8888)
  check "not locked" (!(← surf.flags).has .locked)

  -- fill with mapped red, then read pixels back
  let red ← surf.mapRGBA 255 0 0 255
  surf.fillRect none red
  check "fill red -> readPixel (0,0)" ((← surf.readPixel 0 0) == ⟨255, 0, 0, 255⟩)
  surf.writePixel 1 1 ⟨10, 20, 30, 40⟩
  check "writePixel/readPixel round-trip" ((← surf.readPixel 1 1) == ⟨10, 20, 30, 40⟩)
  let fc ← surf.readPixelFloat 0 0
  check "readPixelFloat red ~ 1.0"
    (fc.r > 0.99 && fc.g < 0.01 && fc.b < 0.01 && fc.a > 0.99)

  -- clear to blue (float color), read back
  surf.clear 0 0 1 1
  check "clear blue -> readPixel (0,0)" ((← surf.readPixel 0 0) == ⟨0, 0, 255, 255⟩)

  -- color key none -> some -> none
  check "colorKey initially none" ((← surf.getColorKey) == none)
  surf.setColorKey (some red)
  check "colorKey some round-trip" ((← surf.getColorKey) == some red)
  surf.setColorKey none
  check "colorKey none after disable" ((← surf.getColorKey) == none)

  -- color mod / alpha mod round-trips
  surf.setColorMod 11 22 33
  check "colorMod round-trip" ((← surf.getColorMod) == ⟨11, 22, 33, 255⟩)
  surf.setAlphaMod 44
  check "alphaMod round-trip" ((← surf.getAlphaMod) == 44)

  -- blend mode round-trip
  surf.setBlendMode .blend
  check "blendMode blend round-trip" ((← surf.getBlendMode) == .blend)

  -- clip rect: some -> get, none resets to full surface
  let _ ← surf.setClipRect (some ⟨1, 1, 2, 2⟩)
  check "clipRect some round-trip" ((← surf.getClipRect) == ⟨1, 1, 2, 2⟩)
  let _ ← surf.setClipRect none
  check "clipRect none resets to full" ((← surf.getClipRect) == ⟨0, 0, 4, 4⟩)

  -- make surf pure red for the transform/save tests below
  surf.clear 1 0 0 1

  -- convert to rgb565: pure red survives
  let conv ← surf.convert .rgb565
  check "convert format rgb565" ((← conv.format) == .rgb565)
  check "convert red survives" ((← conv.readPixel 0 0) == ⟨255, 0, 0, 255⟩)

  -- scale 4x4 -> 8x8 nearest: corner pixel stays red
  let scaled ← surf.scale 8 8 .nearest
  check "scaled width == 8" ((← scaled.width) == 8)
  check "scaled corner red" ((← scaled.readPixel 0 0) == ⟨255, 0, 0, 255⟩)

  -- flip horizontal moves a marked pixel across a 2x1 surface
  let fs ← Sdl.createSurface 2 1 .rgba8888
  fs.clear 0 0 0 1
  fs.writePixel 0 0 ⟨255, 255, 255, 255⟩
  fs.flip .horizontal
  check "flip moved pixel right" ((← fs.readPixel 1 0) == ⟨255, 255, 255, 255⟩)
  check "flip left now black" ((← fs.readPixel 0 0) == ⟨0, 0, 0, 255⟩)

  -- duplicate is independent of the original
  let dup ← surf.duplicate
  dup.writePixel 0 0 ⟨1, 2, 3, 4⟩
  check "duplicate write isolated" ((← dup.readPixel 0 0) == ⟨1, 2, 3, 4⟩)
  check "original unchanged by dup write" ((← surf.readPixel 0 0) == ⟨255, 0, 0, 255⟩)

  -- blit a 2x2 red source onto a 4x4 blue dest at (1,1)
  let dstS ← Sdl.createSurface 4 4 .rgba8888
  dstS.fillRect none (← dstS.mapRGBA 0 0 255 255)
  let srcS ← Sdl.createSurface 2 2 .rgba8888
  srcS.fillRect none (← srcS.mapRGBA 255 0 0 255)
  srcS.blit none dstS (some ⟨1, 1, 0, 0⟩)
  check "blit (1,1) red" ((← dstS.readPixel 1 1) == ⟨255, 0, 0, 255⟩)
  check "blit (0,0) still blue" ((← dstS.readPixel 0 0) == ⟨0, 0, 255, 255⟩)

  -- scaled / tiled / stretch / 9-grid smoke (no throw), plus a scaled check
  let big ← Sdl.createSurface 16 16 .rgba8888
  let smoke ← Sdl.createSurface 4 4 .rgba8888
  smoke.fillRect none (← smoke.mapRGBA 255 0 0 255)
  smoke.blitScaled none big (some ⟨0, 0, 16, 16⟩) .nearest
  check "blitScaled filled center red" ((← big.readPixel 8 8) == ⟨255, 0, 0, 255⟩)
  smoke.blitTiled none big none
  check "blitTiled no throw" true
  smoke.blitTiledWithScale none big none 2.0 .nearest
  check "blitTiledWithScale no throw" true
  smoke.stretch none big none .nearest
  check "stretch no throw" true
  smoke.blit9Grid none big none 1 1 1 1 1.0 .nearest
  check "blit9Grid no throw" true

  -- indexed surface + borrowed palette life cycle
  let idx ← Sdl.createSurface 2 2 .index8
  let pal ← idx.createPalette
  pal.setColors #[⟨255, 0, 0, 255⟩, ⟨0, 255, 0, 255⟩]
  idx.writePixel 0 0 ⟨255, 0, 0, 255⟩
  check "index8 readPixel red via palette" ((← idx.readPixel 0 0) == ⟨255, 0, 0, 255⟩)
  check "getPalette is some" ((← idx.getPalette).isSome)
  checkThrows "destroy on borrowed palette throws" pal.destroy

  -- alternate images: add / has / remove, parent still usable, child refcounted
  let parent ← Sdl.createSurface 4 4 .rgba8888
  check "no alt images initially" (!(← parent.hasAlternateImages))
  let child ← Sdl.createSurface 2 2 .rgba8888
  parent.addAlternateImage child
  check "has alt images after add" (← parent.hasAlternateImages)
  parent.removeAlternateImages
  check "no alt images after remove" (!(← parent.hasAlternateImages))
  check "child still usable (SDL held its own ref)" ((← child.width) == 2)

  -- BMP round-trip via a file (surf is pure red)
  let pref ← Sdl.getPrefPath "lean-sdl3" "test-surface"
  let bmpPath := pref ++ "probe.bmp"
  surf.saveBMP bmpPath
  check "BMP file round-trip red" ((← (← Sdl.loadBMP bmpPath).readPixel 0 0) == ⟨255, 0, 0, 255⟩)
  Sdl.removePath bmpPath

  -- PNG round-trip via a file
  let pngPath := pref ++ "probe.png"
  surf.savePNG pngPath
  check "PNG file round-trip red" ((← (← Sdl.loadPNG pngPath).readPixel 0 0) == ⟨255, 0, 0, 255⟩)
  Sdl.removePath pngPath

  -- in-memory round-trip: saveBMPIO -> stream.loadFile -> ioFromConstMem -> loadBMPIO
  let memOut ← Sdl.ioFromDynamicMem
  surf.saveBMPIO memOut
  let _ ← memOut.seek 0 .seekSet  -- rewind past the just-written BMP before draining
  let bytes ← memOut.loadFile
  memOut.close
  let memIn ← Sdl.ioFromConstMem bytes
  let memSurf ← Sdl.loadBMPIO memIn
  memIn.close
  check "in-memory BMP round-trip red" ((← memSurf.readPixel 0 0) == ⟨255, 0, 0, 255⟩)

  -- getPixels: tightly packed rows in the surface's own byte layout
  let px ← Sdl.createSurface 3 2 .rgba32   -- rgba32 = byte order r,g,b,a
  px.fillRect none (← px.mapRGBA 10 20 30 255)
  px.writePixel 2 1 ⟨1, 2, 3, 4⟩
  let bytes ← px.getPixels
  check "getPixels size = w·h·4" (bytes.size == 3 * 2 * 4)
  check "getPixels first pixel" (bytes[0]! == 10 && bytes[1]! == 20 && bytes[2]! == 30)
  check "getPixels last pixel row-major"
    (bytes[(1 * 3 + 2) * 4]! == 1 && bytes[(1 * 3 + 2) * 4 + 3]! == 4)

end Tests.Surface
