import Common

/-!
# renderer/08-rotating-textures

Loads a PNG into a static texture and draws it centered, spinning a full
rotation about its own center every two seconds.

Port of the official example
`examples/renderer/08-rotating-textures/rotating-textures.c`
(https://examples.libsdl.org/SDL3/renderer/08-rotating-textures/).

## Deviations
- Assets: the C example builds the PNG path from `SDL_GetBasePath()`. Here we
  load the vendored `examples/assets/sample.png` via `Examples.assetPath`.
- Surfaces are finalizer-only in this binding, so the C `SDL_DestroySurface`
  becomes letting the surface go out of scope.
-/

open Sdl

def windowWidth : Float := 640.0
def windowHeight : Float := 480.0

structure State where
  window : Window
  renderer : Renderer
  texture : Texture
  /-- Texture width in pixels (as `Float` for the per-frame geometry). -/
  texWidth : Float
  /-- Texture height in pixels. -/
  texHeight : Float

def app : App State where
  init := fun _args => do
    setAppMetadata "Example Renderer Rotating Textures" "1.0"
      "com.example.renderer-rotating-textures"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/renderer/rotating-textures" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    let surface ← loadPNG (← Examples.assetPath "sample.png").toString
    let texWidth := (← surface.width).toFloat
    let texHeight := (← surface.height).toFloat
    let texture ← renderer.createTextureFromSurface surface
    return (.continue, some { window, renderer, texture, texWidth, texHeight })
  event := fun _ e => do
    if let .quit _ := e then return .success
    return .continue
  iterate := fun s => do
    let now ← getTicks
    -- rotate a full circle (360 degrees) over two seconds (2000 ms).
    let rotation : Float := ((now % 2000).toFloat / 2000.0) * 360.0
    -- rendering draws over whatever was drawn before it.
    s.renderer.setDrawColor 0 0 0 255  -- black, full alpha
    s.renderer.clear                    -- start with a blank canvas.
    -- Center it, and spin it about the center of the texture.
    let dst : FRect :=
      { x := ((windowWidth - s.texWidth) / 2.0).toFloat32,
        y := ((windowHeight - s.texHeight) / 2.0).toFloat32,
        w := s.texWidth.toFloat32, h := s.texHeight.toFloat32 }
    let center : FPoint :=
      { x := (s.texWidth / 2.0).toFloat32, y := (s.texHeight / 2.0).toFloat32 }
    s.renderer.textureRotated s.texture none (some dst) rotation (some center)
    s.renderer.present
    return .continue

def main : IO UInt32 := Examples.runApp app
