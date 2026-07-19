import Common

/-!
# renderer/11-color-mods

Creates an SDL window and renderer, then draws a static texture several times
each frame with different color modulation: one tinted blue, one cycling
through colors via a sine wave, and one tinted red.

Port of the official example `examples/renderer/11-color-mods/color-mods.c`
(https://examples.libsdl.org/SDL3/renderer/11-color-mods/).

## Deviations
- Assets: the C uses `SDL_GetBasePath() + "sample.png"`; here we resolve the
  vendored asset with `Examples.assetPath` (see `examples/Common.lean`).
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
  init _ := do
    setAppMetadata "Example Renderer Color Mods" "1.0" "com.example.renderer-color-mods"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/renderer/color-mods" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    -- Load a .png into a surface, move it to a texture from there.
    let surface ← loadPNG (← Examples.assetPath "sample.png").toString
    let texture ← renderer.createTextureFromSurface surface
    let (textureWidth, textureHeight) ← texture.getSize
    return (.continue, some { window, renderer, texture, textureWidth, textureHeight })
  event _ e := do
    if let .quit _ := e then return .success
    return .continue
  iterate s := do
    let now := (← getTicks).toFloat / 1000.0  -- milliseconds to seconds
    -- The sine wave trick makes the center texture fade between colors smoothly.
    let red   := (0.5 + 0.5 * Float.sin now).toFloat32
    let green := (0.5 + 0.5 * Float.sin (now + Examples.pi * 2 / 3)).toFloat32
    let blue  := (0.5 + 0.5 * Float.sin (now + Examples.pi * 4 / 3)).toFloat32

    -- rendering draws over whatever was drawn before it.
    s.renderer.setDrawColor 0 0 0 255  -- black, full alpha
    s.renderer.clear

    let tw := s.textureWidth
    let th := s.textureHeight

    -- top left; make this one blue (kill all red and green).
    s.texture.setColorModFloat 0.0 0.0 1.0
    s.renderer.texture s.texture (dstRect := some ⟨0, 0, tw, th⟩)

    -- center; cycle through red/green/blue modulations.
    s.texture.setColorModFloat red green blue
    s.renderer.texture s.texture
      (dstRect := some ⟨(windowWidth - tw) / 2, (windowHeight - th) / 2, tw, th⟩)

    -- bottom right; make this one red (kill all green and blue).
    s.texture.setColorModFloat 1.0 0.0 0.0
    s.renderer.texture s.texture
      (dstRect := some ⟨windowWidth - tw, windowHeight - th, tw, th⟩)

    s.renderer.present
    return .continue

def main : IO UInt32 := Examples.runApp app
