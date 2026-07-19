import Common

/-!
# renderer/06-textures

Creates an SDL window and renderer, loads a PNG into a static texture, and
draws that texture ("sprite") several times per frame, sliding two copies back
and forth while a third stays centered.

Port of the official example `examples/renderer/06-textures/textures.c`
(https://examples.libsdl.org/SDL3/renderer/06-textures/).

## Deviations
- Assets: the C example builds the PNG path from `SDL_GetBasePath()`. Here we
  load the vendored `examples/assets/sample.png` via `Examples.assetPath` (demos
  run from the repository root).
- Surfaces are finalizer-only in this binding, so the C `SDL_DestroySurface`
  after `createTextureFromSurface` becomes letting the surface go out of scope.
-/

open Sdl

/-- Window is 640x480; texture size comes from the loaded PNG. -/
def windowWidth : Float := 640.0
def windowHeight : Float := 480.0

structure State where
  window : Window
  renderer : Renderer
  /-- The static texture uploaded once from `sample.png`. -/
  texture : Texture
  /-- Texture width in pixels (as `Float` for the per-frame geometry). -/
  texWidth : Float
  /-- Texture height in pixels. -/
  texHeight : Float

def app : App State where
  init _ := do
    setAppMetadata "Example Renderer Textures" "1.0" "com.example.renderer-textures"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/renderer/textures" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    -- SDL_Surface is CPU pixel data, SDL_Texture is GPU pixel data: load the
    -- PNG into a surface, then move it to a texture.
    let surface ← loadPNG (← Examples.assetPath "sample.png").toString
    let texWidth := (← surface.width).toFloat
    let texHeight := (← surface.height).toFloat
    let texture ← renderer.createTextureFromSurface surface
    return (.continue, some { window, renderer, texture, texWidth, texHeight })
  event _ e := do
    if let .quit _ := e then return .success
    return .continue
  iterate s := do
    let now ← getTicks
    -- some textures move around over a few seconds.
    let direction : Float := if now % 2000 ≥ 1000 then 1.0 else -1.0
    let scale : Float := ((now % 1000).toFloat - 500.0) / 500.0 * direction
    -- rendering draws over whatever was drawn before it.
    s.renderer.setDrawColor 0 0 0 255  -- black, full alpha
    s.renderer.clear                    -- start with a blank canvas.
    -- Draw the static texture a few times, like a stamp.
    -- top left
    s.renderer.texture s.texture none (some
      { x := (100.0 * scale).toFloat32, y := 0.0,
        w := s.texWidth.toFloat32, h := s.texHeight.toFloat32 })
    -- center
    s.renderer.texture s.texture none (some
      { x := ((windowWidth - s.texWidth) / 2.0).toFloat32,
        y := ((windowHeight - s.texHeight) / 2.0).toFloat32,
        w := s.texWidth.toFloat32, h := s.texHeight.toFloat32 })
    -- bottom right
    s.renderer.texture s.texture none (some
      { x := ((windowWidth - s.texWidth) - 100.0 * scale).toFloat32,
        y := (windowHeight - s.texHeight).toFloat32,
        w := s.texWidth.toFloat32, h := s.texHeight.toFloat32 })
    s.renderer.present
    return .continue

def main : IO UInt32 := Examples.runApp app
