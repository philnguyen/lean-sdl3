import Sdl
import Tests.Harness

namespace Tests.Render
open Sdl Tests.Harness

/-- `a` within `tol` of `b` (Float32 comparisons). -/
private def approx (a b : Float32) (tol : Float32 := 0.01) : Bool :=
  (a - b).abs <= tol

/-- Absolute difference of two `Nat`s. -/
private def natDist (a b : Nat) : Nat := max a b - min a b

/-- `c` is within `tol` byte-steps of `(r, g, b)` per channel. -/
private def colorNear (c : Color) (r g b : UInt8) (tol : Nat := 2) : Bool :=
  natDist c.r.toNat r.toNat <= tol && natDist c.g.toNat g.toNat <= tol &&
  natDist c.b.toNat b.toNat <= tol

set_option maxRecDepth 8192 in
/-- Render tests (run under `SDL_VIDEO_DRIVER=dummy`, after the `Video` group
initialized the video subsystem). Uses the fully-functional "software" renderer:
driver enumeration, renderer creation + registry identity, draw + `readPixels`
verification, the streaming/static/target texture life cycles, mod/blend/scale
round-trips, viewport/clip/scale/logical-presentation state, `geometry`, the
destroy-order stress gate, and the packed-array draw variants. -/
def run : IO Unit := do
  -- 1. drivers
  check "getNumRenderDrivers >= 1" ((← getNumRenderDrivers) >= 1)
  check "getRenderDriver 0 isSome" ((← getRenderDriver 0).isSome)
  check "getRenderDriver out-of-range is none" ((← getRenderDriver 10000) == none)

  -- 2. window + software renderer + identity lookups
  let win ← createWindow "lean-sdl3 render" 320 240
  check "getRenderer none before create" ((← getRenderer win).isNone)
  let ren ← createRenderer win (some softwareRenderer)
  check "renderer name is software" ((← ren.name) == softwareRenderer)
  check "getRenderer isSome after create" ((← getRenderer win).isSome)
  win.setTitle "render-probe"
  match (← ren.getWindow) with
  | some w2 =>
    check "getWindow identity via title probe" ((← w2.getTitle) == "render-probe")
  | none => check "getWindow identity via title probe" false
  check "getOutputSize == (320, 240)" ((← ren.getOutputSize) == (320, 240))
  check "getCurrentOutputSize == (320, 240)" ((← ren.getCurrentOutputSize) == (320, 240))
  let props ← ren.properties
  check "properties name string" ((← props.getStringProperty "SDL.renderer.name") == "software")

  -- 3. draw + readPixels verification
  ren.setDrawColor 255 0 0 255
  check "getDrawColor round-trip" ((← ren.getDrawColor) == (255, 0, 0, 255))
  ren.clear
  let shot1 ← ren.readPixels
  check "clear red: pixel (0,0)" (colorNear (← shot1.readPixel 0 0) 255 0 0 0)
  ren.setDrawColor 0 255 0 255
  ren.fillRect (some ⟨10, 10, 20, 20⟩)
  let shot2 ← ren.readPixels
  check "fillRect green: inside pixel" (colorNear (← shot2.readPixel 15 15) 0 255 0 0)
  check "fillRect green: outside pixel still red"
    (colorNear (← shot2.readPixel 0 0) 255 0 0 0)
  ren.setDrawColorFloat 0.5 0.25 1.0 1.0
  let (fr, fg, fb, fa) ← ren.getDrawColorFloat
  check "getDrawColorFloat round-trip"
    (approx fr 0.5 && approx fg 0.25 && approx fb 1.0 && approx fa 1.0)
  ren.setColorScale 2.0
  check "colorScale round-trip" (approx (← ren.getColorScale) 2.0)
  ren.setColorScale 1.0

  -- 4. streaming texture lifecycle
  let tex ← ren.createTexture .argb8888 .streaming 4 4
  check "texture getSize == (4, 4)" ((← tex.getSize) == (4.0, 4.0))
  check "texture width == 4" ((← tex.width) == 4)
  check "texture height == 4" ((← tex.height) == 4)
  check "texture format round-trip" ((← tex.format) == .argb8888)
  let locked ← tex.lockToSurface
  locked.fillRect none (← locked.mapRGBA 0 0 255 255)
  tex.unlock
  ren.texture tex
  let shot3 ← ren.readPixels
  check "streaming texture renders blue" (colorNear (← shot3.readPixel 5 5) 0 0 255 0)
  check "texture renderer name via owner chain" ((← (← tex.renderer).name) == "software")
  let texProps ← tex.properties
  check "texture properties access number"
    ((← texProps.getNumberProperty "SDL.texture.access") == 1)

  -- update: push a solid white 4x4 ARGB8888 block through SDL_UpdateTexture
  let white := ByteArray.mk (Array.replicate (4 * 4 * 4) 0xFF)
  tex.update none white 16
  ren.texture tex
  let shot4 ← ren.readPixels
  check "update texture renders white" (colorNear (← shot4.readPixel 5 5) 255 255 255 0)
  -- undersized buffers and bad pitches must throw, not read out of bounds
  checkThrows "update with empty buffer throws" (tex.update none ByteArray.empty 16)
  checkThrows "update with short buffer throws"
    (tex.update none (ByteArray.mk (Array.replicate 63 0)) 16)
  checkThrows "update with zero pitch throws" (tex.update none white 0)
  checkThrows "update with negative pitch throws" (tex.update none white (-16))
  -- exact tight size for a sub-rect ((h-1)*pitch + w*bpp) is accepted
  tex.update (some ⟨0, 0, 2, 2⟩) (ByteArray.mk (Array.replicate 24 0xFF)) 16
  -- fully out-of-bounds rect clips to empty: SDL no-ops, no size demand
  tex.update (some ⟨64, 64, 4, 4⟩) ByteArray.empty 16

  -- 5. texture from surface
  let srcSurf ← createSurface 4 4 .rgba32
  srcSurf.fillRect none (← srcSurf.mapRGBA 255 255 0 255)
  let tex2 ← ren.createTextureFromSurface srcSurf
  ren.texture tex2
  let shot5 ← ren.readPixels
  check "surface texture renders yellow" (colorNear (← shot5.readPixel 7 7) 255 255 0 0)

  -- createTextureWithProperties
  let cprops ← createProperties
  cprops.setNumberProperty "SDL.texture.create.width" 8
  cprops.setNumberProperty "SDL.texture.create.height" 8
  let tex3 ← ren.createTextureWithProperties cprops
  check "createTextureWithProperties size" ((← tex3.width) == 8 && (← tex3.height) == 8)

  -- 6. mod / blend / scale round-trips
  tex.setColorModFloat 0.25 0.5 0.75
  let (mr, mg, mb) ← tex.getColorModFloat
  check "colorModFloat round-trip" (approx mr 0.25 && approx mg 0.5 && approx mb 0.75)
  tex.setAlphaModFloat 0.5
  check "alphaModFloat round-trip" (approx (← tex.getAlphaModFloat) 0.5)
  tex.setColorMod 100 150 200
  check "colorMod round-trip" ((← tex.getColorMod) == (100, 150, 200))
  tex.setAlphaMod 128
  check "alphaMod round-trip" ((← tex.getAlphaMod) == 128)
  tex.setBlendMode .add
  check "texture blendMode round-trip" ((← tex.getBlendMode) == .add)
  tex.setScaleMode .nearest
  check "texture scaleMode round-trip" ((← tex.getScaleMode) == .nearest)
  ren.setDrawBlendMode .blend
  check "draw blendMode round-trip" ((← ren.getDrawBlendMode) == .blend)
  ren.setDrawBlendMode .none
  ren.setDefaultTextureScaleMode .nearest
  check "defaultTextureScaleMode round-trip"
    ((← ren.getDefaultTextureScaleMode) == .nearest)
  ren.setDefaultTextureScaleMode .linear

  -- 7. viewport / clip / scale / logical presentation / coordinates
  ren.setViewport (some ⟨8, 8, 64, 48⟩)
  check "viewport round-trip" ((← ren.getViewport) == ⟨8, 8, 64, 48⟩)
  check "viewportSet true" (← ren.viewportSet)
  ren.setViewport none
  check "viewportSet false after reset" (!(← ren.viewportSet))
  check "viewport reset to full target" ((← ren.getViewport) == ⟨0, 0, 320, 240⟩)
  check "safeArea w > 0" ((← ren.getSafeArea).w > 0)
  ren.setClipRect (some ⟨4, 4, 32, 32⟩)
  check "clipRect round-trip" ((← ren.getClipRect) == ⟨4, 4, 32, 32⟩)
  check "clipEnabled true" (← ren.clipEnabled)
  ren.setClipRect none
  check "clipEnabled false after reset" (!(← ren.clipEnabled))
  ren.setScale 2.0 3.0
  check "scale round-trip" ((← ren.getScale) == (2.0, 3.0))
  ren.setScale 1.0 1.0
  ren.setLogicalPresentation 160 120 .letterbox
  check "logicalPresentation round-trip"
    ((← ren.getLogicalPresentation) == (160, 120, .letterbox))
  check "logicalPresentationRect w > 0" ((← ren.getLogicalPresentationRect).w > 0)
  ren.setLogicalPresentation 0 0 .disabled
  check "logicalPresentation disabled"
    ((← ren.getLogicalPresentation) == (0, 0, .disabled))
  let (cx, cy) ← ren.coordinatesFromWindow 10 20
  check "coordinatesFromWindow identity" (approx cx 10 && approx cy 20)
  let (wx, wy) ← ren.coordinatesToWindow 5 7
  check "coordinatesToWindow identity" (approx wx 5 && approx wy 7)
  ren.setTextureAddressMode .clamp .wrap
  check "textureAddressMode round-trip"
    ((← ren.getTextureAddressMode) == (.clamp, .wrap))
  ren.setTextureAddressMode .auto .auto

  -- 8. render target
  -- NOTE: `target` must stay referenced while bound — `setTarget` does not
  -- retain it (see its doc comment); the trailing `ren.texture target` below
  -- keeps it alive through the bound region under Lean's eager RC.
  let target ← ren.createTexture .argb8888 .target 8 8
  check "getTarget none initially" ((← ren.getTarget).isNone)
  ren.setTarget (some target)
  match (← ren.getTarget) with
  | some t2 => check "getTarget some while bound" ((← t2.width) == 8)
  | none => check "getTarget some while bound" false
  ren.setDrawColor 255 0 255 255
  ren.fillRect none
  let tshot ← ren.readPixels
  check "readPixels reads bound target (8x8)"
    ((← tshot.width) == 8 && (← tshot.height) == 8)
  check "readPixels reads bound target (magenta)"
    (colorNear (← tshot.readPixel 2 2) 255 0 255 0)
  -- the backbuffer still holds test 5's yellow, which differs from magenta
  ren.setTarget none
  check "getTarget none after reset" ((← ren.getTarget).isNone)
  let bshot ← ren.readPixels
  check "backbuffer differs from target"
    (colorNear (← bshot.readPixel 7 7) 255 255 0 0)
  -- draw the recorded target texture back onto the backbuffer
  ren.texture target
  let after ← ren.readPixels
  check "target texture renders onto backbuffer"
    (colorNear (← after.readPixel 5 5) 255 0 255 0)

  -- 9. geometry: two triangles filling a quad, uniform blue vertex color
  ren.setDrawColor 0 0 0 255
  ren.clear
  let blue : FColor := ⟨0, 0, 1, 1⟩
  let quad : Array Vertex := #[
    { position := ⟨8, 8⟩,  color := blue, texCoord := ⟨0, 0⟩ },
    { position := ⟨40, 8⟩, color := blue, texCoord := ⟨0, 0⟩ },
    { position := ⟨40, 40⟩, color := blue, texCoord := ⟨0, 0⟩ },
    { position := ⟨8, 40⟩, color := blue, texCoord := ⟨0, 0⟩ }]
  ren.geometry none quad #[0, 1, 2, 0, 2, 3]
  let gshot ← ren.readPixels
  check "geometry quad center is blue" (colorNear (← gshot.readPixel 24 24) 0 0 255)
  check "geometry quad outside stays black" (colorNear (← gshot.readPixel 100 100) 0 0 0)

  -- 10. destroy-order stress (the gate)
  let stray ← (do
    let w2 ← createWindow "render-stress" 64 64
    let r2 ← createRenderer w2 (some softwareRenderer)
    r2.createTexture .argb8888 .target 8 8)
  -- only the texture survived the scope; the owner chain keeps the renderer
  -- (and its window) alive
  let ren2 ← stray.renderer
  check "recovered renderer name" ((← ren2.name) == "software")
  ren2.setTarget (some stray)
  ren2.setDrawColor 12 34 56 255
  ren2.fillRect none
  let sshot ← ren2.readPixels
  check "draw through recovered renderer" (colorNear (← sshot.readPixel 1 1) 12 34 56 0)
  ren2.setTarget none
  stray.destroy
  checkThrows "texture op after destroy throws" stray.width
  checkThrows "second destroy throws" stray.destroy

  -- 11. debugText / present / flush / vsync
  ren.setDrawColor 255 255 255 255
  ren.debugText 2 2 "lean-sdl3"
  check "debugText no-throw" true
  ren.flush
  check "flush no-throw" true
  ren.present
  check "present no-throw" true
  try
    ren.setVSync 1
    check "setVSync 1 accepted" true
  catch _ =>
    check "setVSync unsupported (tolerated)" true
  let _ ← ren.getVSync
  check "getVSync no-throw" true

  -- 12. packed-array draw variants (3+ elements, then empty = no-op)
  ren.points #[⟨1, 1⟩, ⟨2, 2⟩, ⟨3, 3⟩]
  check "points draws" true
  ren.lines #[⟨1, 1⟩, ⟨10, 1⟩, ⟨10, 10⟩]
  check "lines draws" true
  ren.rects #[⟨1, 1, 4, 4⟩, ⟨6, 6, 4, 4⟩, ⟨11, 11, 4, 4⟩]
  check "rects draws" true
  ren.fillRects #[⟨1, 1, 4, 4⟩, ⟨6, 6, 4, 4⟩, ⟨11, 11, 4, 4⟩]
  check "fillRects draws" true
  ren.points #[]
  ren.lines #[]
  ren.rects #[]
  ren.fillRects #[]
  check "empty array draws are no-ops" true

  -- remaining texture-copy variants: draw without error
  ren.textureRotated tex none (some ⟨50, 50, 16, 16⟩) 45.0
  check "textureRotated no-throw" true
  ren.textureRotated tex none (some ⟨50, 50, 16, 16⟩) 90.0 (some ⟨8, 8⟩) .horizontal
  check "textureRotated center+flip no-throw" true
  ren.textureAffine tex none (some ⟨0, 0⟩) (some ⟨16, 0⟩) (some ⟨0, 16⟩)
  check "textureAffine no-throw" true
  ren.textureTiled tex none 1.0 (some ⟨0, 0, 32, 32⟩)
  check "textureTiled no-throw" true
  ren.texture9Grid tex none 1 1 1 1 0.0 (some ⟨0, 0, 32, 32⟩)
  check "texture9Grid no-throw" true
  ren.texture9GridTiled tex none 1 1 1 1 0.0 (some ⟨0, 0, 32, 32⟩) 1.0
  check "texture9GridTiled no-throw" true
  ren.point 1 1
  ren.line 0 0 8 8
  ren.rect (some ⟨2, 2, 8, 8⟩)
  check "point/line/rect no-throw" true

end Tests.Render
