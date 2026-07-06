import Common

/-!
# renderer/17-read-pixels

Creates an SDL window and renderer, draws a rotating texture, reads back the
rendered pixels, converts them to black and white (with pure-black pixels turned
red), and draws the converted image, scaled down, into the top-left corner.

This is deliberately not efficient — a render target would be the real-world
approach — but it is a visual example of `Renderer.readPixels`.

Port of the official example `examples/renderer/17-read-pixels/read-pixels.c`
(https://examples.libsdl.org/SDL3/renderer/17-read-pixels/).

## Deviations
- Assets: the C uses `SDL_GetBasePath() + "sample.png"`; here we resolve the
  vendored asset with `Examples.assetPath` (see `examples/Common.lean`).
- Pixel access: the C reads/writes `surface->pixels` as raw `Uint32`s (and
  first converts non-RGBA/BGRA surfaces to `RGBA8888`). This binding exposes
  per-pixel `Surface.readPixel`/`writePixel` returning logical RGBA `Color`s, so
  the explicit format conversion is unnecessary and is dropped.
- Converted texture: the C keeps a cached streaming texture and
  `SDL_UpdateTexture`s it each frame; here we build it with
  `createTextureFromSurface` (and `destroy` it) each frame — visually identical.
-/

open Sdl

def windowWidth : Float32 := 640
def windowHeight : Float32 := 480

structure State where
  window : Window
  renderer : Renderer
  texture : Texture
  textureWidth : Float32
  textureHeight : Float32

def app : App State where
  init := fun _args => do
    setAppMetadata "Example Renderer Read Pixels" "1.0" "com.example.renderer-read-pixels"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/renderer/read-pixels" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    -- Load a .png into a surface, move it to a texture from there.
    let surface ← loadPNG (← Examples.assetPath "sample.png").toString
    let texture ← renderer.createTextureFromSurface surface
    let (textureWidth, textureHeight) ← texture.getSize
    return (.continue, some { window, renderer, texture, textureWidth, textureHeight })
  event := fun _ e => do
    if let .quit _ := e then return .success
    return .continue
  iterate := fun s => do
    let now ← getTicks
    let r := s.renderer
    -- rotate the texture around over 2 seconds (2000 ms); 360 degrees in a circle.
    let rotation := (now % 2000).toFloat32 / 2000.0 * 360.0

    -- rendering draws over whatever was drawn before it.
    r.setDrawColor 0 0 0 255  -- black, full alpha
    r.clear

    -- Center it and spin it around the center of the texture.
    let tw := s.textureWidth
    let th := s.textureHeight
    let dstRect : FRect := ⟨(windowWidth - tw) / 2, (windowHeight - th) / 2, tw, th⟩
    let center : FPoint := ⟨tw / 2, th / 2⟩
    r.textureRotated s.texture none (some dstRect) rotation.toFloat (some center)

    -- This next whole thing is _super_ expensive; don't do this in real life.
    -- Download the pixels of what was just rendered (GPU → system RAM).
    let surface ← r.readPixels
    let w := (← surface.width).toInt.toNat
    let h := (← surface.height).toInt.toNat

    -- Turn each pixel into black or white (pure-black pixels become red). A
    -- lousy technique, but it works here.
    for y in [0:h] do
      for x in [0:w] do
        let px := Int32.ofNat x
        let py := Int32.ofNat y
        let c ← surface.readPixel px py
        let average := (c.r.toNat + c.g.toNat + c.b.toNat) / 3
        if average == 0 then
          surface.writePixel px py ⟨255, 0, 0, 255⟩  -- pure black → red
        else
          let v : UInt8 := if average > 50 then 0xFF else 0x00
          surface.writePixel px py ⟨v, v, v, c.a⟩

    -- Upload the processed pixels and draw scaled to the top-left of the screen.
    let converted ← r.createTextureFromSurface surface
    r.texture converted (dstRect := some ⟨0, 0, windowWidth / 4, windowHeight / 4⟩)
    converted.destroy

    r.present
    return .continue

def main : IO UInt32 := Examples.runApp app
