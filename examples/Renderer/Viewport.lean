import Common

/-!
# renderer/14-viewport

Creates an SDL window and renderer, then draws some textures to it every
frame, adjusting the viewport.

Port of the official example `examples/renderer/14-viewport/viewport.c`
(https://examples.libsdl.org/SDL3/renderer/14-viewport/).

## Deviations

* Assets: the C example builds the image path from `SDL_GetBasePath()`; here
  the vendored `examples/assets/sample.png` is resolved with
  `Examples.assetPath` (run demos from the repository root).
* The C example destroys the source surface right after creating the texture
  (`SDL_DestroySurface`); Lean surfaces are finalizer-only, so the surface is
  simply dropped and reclaimed automatically.
* The window/renderer are not destroyed at exit, matching the C (see
  `examples/Common.lean`); the texture is destroyed in `quit` like the C's
  `SDL_AppQuit`.
-/

open Sdl

def windowWidth : Int32 := 640
def windowHeight : Int32 := 480

structure State where
  window : Window
  renderer : Renderer
  texture : Texture
  textureWidth : Float32
  textureHeight : Float32

def app : App State where
  init _ := do
    setAppMetadata "Example Renderer Viewport" "1.0" "com.example.renderer-viewport"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/renderer/viewport" windowWidth windowHeight .resizable
    renderer.setLogicalPresentation windowWidth windowHeight .letterbox
    -- Textures are pixel data that we upload to the video hardware for fast drawing. Lots of 2D
    -- engines refer to these as "sprites." We'll do a static texture (upload once, draw many
    -- times) with data from a bitmap file.

    -- An SDL surface is pixel data the CPU can access. An SDL texture is pixel data the GPU can
    -- access. Load a .png into a surface, move it to a texture from there.
    let surface ← loadPNG (← Examples.assetPath "sample.png").toString
    let textureWidth := (← surface.width).toFloat.toFloat32
    let textureHeight := (← surface.height).toFloat.toFloat32
    let texture ← renderer.createTextureFromSurface surface
    -- (the surface is dropped here; the texture has a copy of the pixels now.)
    return (.continue, some { window, renderer, texture, textureWidth, textureHeight })
  event _ e := do
    if let .quit _ := e then return .success
    return .continue
  iterate s := do
    let dstRect : FRect := { x := 0, y := 0, w := s.textureWidth, h := s.textureHeight }
    -- Setting a viewport has the effect of limiting the area that rendering
    -- can happen, and making coordinate (0, 0) live somewhere else in the
    -- window. It does _not_ scale rendering to fit the viewport.

    -- as you can see from this, rendering draws over whatever was drawn before it.
    s.renderer.setDrawColor 0 0 0 255  -- black, full alpha
    s.renderer.clear                    -- start with a blank canvas.
    -- Draw once with the whole window as the viewport.
    s.renderer.setViewport none         -- `none` means "use the whole window"
    s.renderer.texture s.texture none (some dstRect)
    -- top right quarter of the window.
    s.renderer.setViewport (some { x := windowWidth / 2, y := windowHeight / 2,
                                   w := windowWidth / 2, h := windowHeight / 2 })
    s.renderer.texture s.texture none (some dstRect)
    -- bottom 20% of the window. Note it clips the width!
    s.renderer.setViewport (some { x := 0, y := windowHeight - windowHeight / 5,
                                   w := windowWidth / 5, h := windowHeight / 5 })
    s.renderer.texture s.texture none (some dstRect)
    -- what happens if you try to draw above the viewport? It should clip!
    s.renderer.setViewport (some { x := 100, y := 200, w := windowWidth, h := windowHeight })
    s.renderer.texture s.texture none (some { dstRect with y := -50 })
    s.renderer.present                  -- put it all on the screen!
    return .continue
  quit s _ := s.texture.destroy

def main : IO UInt32 := Examples.runApp app
