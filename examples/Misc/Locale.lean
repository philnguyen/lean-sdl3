import Common

/-!
# misc/03-locale

Reports the user's preferred locales, one per line, in order of preference.

Port of the official example `examples/misc/03-locale/locale.c`
(https://examples.libsdl.org/SDL3/misc/03-locale/).

Deviations:
- The C's `SDL_snprintf` formatting is reproduced with Lean string
  interpolation.
- When `SDL_GetPreferredLocales` fails, the C renders its `msg` buffer
  uninitialized (an upstream bug); the Lean binding throws instead, so the
  failure branch draws the SDL error text in the same centered position.
-/

open Sdl

structure State where
  window : Window
  renderer : Renderer

def app : App State where
  init := fun _args => do
    setAppMetadata "Example Misc Locale" "1.0" "com.example.misc-locale"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/misc/locale" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    return (.continue, some { window, renderer })
  event := fun _ e => do
    if let .quit _ := e then return .success
    return .continue
  iterate := fun s => do
    let r := s.renderer
    let charSize := (debugTextFontCharacterSize).toFloat32
    let frame : FRect := ⟨0, 0, 640, 480⟩

    r.setDrawColor 0 0 0 255
    r.clear

    let locales : Except String (Array Locale) ←
      try pure (Except.ok (← getPreferredLocales))
      catch e => pure (Except.error e.toString)
    match locales with
    | .error err =>
      let x := frame.x + (frame.w - charSize * err.length.toFloat32) / 2.0
      r.setDrawColor 255 255 255 255
      r.debugText x frame.y err
    | .ok locales =>
      let msg := s!"Locales, in order of preference ({locales.size} total):"
      let x := frame.x + (frame.w - charSize * msg.length.toFloat32) / 2.0
      r.setDrawColor 255 255 255 255
      r.debugText x frame.y msg

      let mut i := 0
      for l in locales do
        let msg :=
          match l.country with
          | some c => s!" - {l.language}_{c}"
          | none   => s!" - {l.language}"
        let x := frame.x + (frame.w - charSize * msg.length.toFloat32) / 2.0
        let y := frame.y + (charSize * 2) * (i + 1).toFloat32
        r.setDrawColor 255 255 255 255
        r.debugText x y msg
        i := i + 1

    r.present
    return .continue

def main : IO UInt32 := Examples.runApp app
