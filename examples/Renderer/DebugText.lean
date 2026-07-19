import Common

/-!
# renderer/18-debug-text

Creates an SDL window and renderer, then draws some text using
`Renderer.debugText` every frame, in different colors and scales.

Port of the official example `examples/renderer/18-debug-text/debug-text.c`
(https://examples.libsdl.org/SDL3/renderer/18-debug-text/).

## Deviations
- `SDL_RenderDebugTextFormat` is C varargs and is not bound; the last line is
  formatted with Lean string interpolation (`s!"…"`) and drawn with `debugText`
  (matching the C's `%llu`-formatted seconds).
-/

open Sdl

def windowWidth : Int32 := 640

structure State where
  window : Window
  renderer : Renderer

def app : App State where
  init _ := do
    setAppMetadata "Example Renderer Debug Texture" "1.0" "com.example.renderer-debug-text"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/renderer/debug-text" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    return (.continue, some { window, renderer })
  event _ e := do
    if let .quit _ := e then return .success
    return .continue
  iterate s := do
    let charsize := debugTextFontCharacterSize
    let r := s.renderer

    -- rendering draws over whatever was drawn before it.
    r.setDrawColor 0 0 0 255  -- black, full alpha
    r.clear

    r.setDrawColor 255 255 255 255  -- white, full alpha
    r.debugText 272 100 "Hello world!"
    r.debugText 224 150 "This is some debug text."

    r.setDrawColor 51 102 255 255  -- light blue, full alpha
    r.debugText 184 200 "You can do it in different colors."
    r.setDrawColor 255 255 255 255  -- white, full alpha

    r.setScale 4.0 4.0
    r.debugText 14 65 "It can be scaled."
    r.setScale 1.0 1.0
    r.debugText 64 350 "This only does ASCII chars. So this laughing emoji won't draw: 🤣"

    let seconds := (← getTicks) / 1000
    r.debugText ((windowWidth - (charsize * 46)).toFloat32 / 2) 400
      s!"(This program has been running for {seconds} seconds.)"

    r.present
    return .continue

def main : IO UInt32 := Examples.runApp app
