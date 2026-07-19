import Common

/-!
# renderer/01-clear

Creates an SDL window and renderer, then clears the window to a different
color every frame, so the window smoothly fades between colors.

Port of the official example `examples/renderer/01-clear/clear.c`
(https://examples.libsdl.org/SDL3/renderer/01-clear/).
-/

open Sdl

structure State where
  window : Window
  renderer : Renderer

def app : App State where
  init _ := do
    setAppMetadata "Example Renderer Clear" "1.0" "com.example.renderer-clear"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/renderer/clear" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    return (.continue, some { window, renderer })
  event _ e := do
    if let .quit _ := e then return .success
    return .continue
  iterate s := do
    -- The sine-wave trick fades smoothly between colors.
    let now := (← getTicks).toFloat / 1000.0
    let red   := 0.5 + 0.5 * Float.sin now
    let green := 0.5 + 0.5 * Float.sin (now + Examples.pi * 2 / 3)
    let blue  := 0.5 + 0.5 * Float.sin (now + Examples.pi * 4 / 3)
    s.renderer.setDrawColorFloat red.toFloat32 green.toFloat32 blue.toFloat32 1.0
    s.renderer.clear
    s.renderer.present
    return .continue

def main : IO UInt32 := Examples.runApp app
