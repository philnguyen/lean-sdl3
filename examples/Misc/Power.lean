import Common

/-!
# misc/01-power

Reports power status (plugged in, battery level, etc): a battery percentage
bar plus status text, redrawn every frame.

Port of the official example `examples/misc/01-power/power.c`
(https://examples.libsdl.org/SDL3/misc/01-power/).

Deviations:
- The C's `SDL_snprintf` formatting (`%02d`, `%3d`) is reproduced with Lean
  string interpolation plus local padding helpers.
- The C matches on `SDL_POWERSTATE_ERROR`; the Lean binding surfaces that
  sentinel as an `IO` error instead, so the error branch (red background,
  "ERROR GETTING POWER STATE" + the SDL error text) is a `try`/`catch`
  around `getPowerInfo`.
- C's `percent >= 0` / `seconds < 0` "unknown" sentinels arrive as `Option`
  fields of `PowerInfo`.
-/

open Sdl

structure State where
  window : Window
  renderer : Renderer

/-- Zero-padded two-digit number (C: `%02d`). -/
def pad2 (n : Int) : String :=
  if 0 ≤ n && n < 10 then s!"0{n}" else toString n

/-- Space-padded, right-aligned three-column number (C: `%3d`). -/
def pad3 (n : Int32) : String :=
  let s := toString n
  "".pushn ' ' (3 - s.length) ++ s

def app : App State where
  init := fun _args => do
    setAppMetadata "Example Misc Power" "1.0" "com.example.misc-power"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/misc/power" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    return (.continue, some { window, renderer })
  event := fun _ e => do
    if let .quit _ := e then return .success
    return .continue
  iterate := fun s => do
    let r := s.renderer
    let charSize := (debugTextFontCharacterSize).toFloat32
    let frame : FRect := ⟨100, 200, 440, 80⟩  -- the percentage bar dimensions.

    -- Query for battery info (the C error sentinel arrives as an exception).
    let info : Except String PowerInfo ←
      try pure (Except.ok (← getPowerInfo)) catch e => pure (Except.error e.toString)

    -- We set up different drawing details for each power state, then
    -- run it all through the same drawing code.
    -- Text and bar-frame colors are white in every state.
    let (clearColor, barColor, msg, msg2?, percent?, seconds?) :
        (UInt8 × UInt8 × UInt8) × (UInt8 × UInt8 × UInt8) × String
          × Option String × Option Int32 × Option Int32 :=
      match info with
      | .error err =>  -- red background
        ((255, 0, 0), (0, 0, 0), err, some "ERROR GETTING POWER STATE", none, none)
      | .ok info =>
        let (clearColor, barColor, msg) :
            (UInt8 × UInt8 × UInt8) × (UInt8 × UInt8 × UInt8) × String :=
          match info.state with
          | .unknown   => ((50, 50, 50), (0, 0, 0), "Power state is unknown.")  -- grey background
          | .onBattery => ((0, 0, 0), (255, 0, 0), "Running on battery.")  -- draw bar in red
          | .noBattery => ((0, 50, 0), (0, 0, 0), "Plugged in, no battery available.")  -- green background
          | .charging  => ((0, 0, 0), (0, 255, 255), "Charging.")  -- draw bar in cyan
          | .charged   => ((0, 0, 0), (0, 255, 0), "Charged.")  -- draw bar in green
        (clearColor, barColor, msg, none, info.percent, info.seconds)

    let (clearR, clearG, clearB) := clearColor
    r.setDrawColor clearR clearG clearB 255
    r.clear

    if let some percent := percent? then
      let pctrect : FRect := { frame with w := frame.w * percent.toFloat32 / 100.0 }
      let remainstr :=
        match seconds? with
        | none => "unknown time"
        | some secs =>
          let total := secs.toInt
          s!"{pad2 (total / 3600)}:{pad2 (total % 3600 / 60)}:{pad2 (total % 60)}"
      let msgbuf := s!"Battery: {pad3 percent} percent, {remainstr} remaining"
      let x := frame.x + (frame.w - charSize * msgbuf.length.toFloat32) / 2.0
      let y := frame.y + frame.h + charSize
      let (barR, barG, barB) := barColor
      r.setDrawColor barR barG barB 255  -- draw percent bar.
      r.fillRect (some pctrect)
      r.setDrawColor 255 255 255 255  -- draw frame on top of bar.
      r.rect (some frame)
      r.setDrawColor 255 255 255 255
      r.debugText x y msgbuf  -- draw text about battery level

    let x := frame.x + (frame.w - charSize * msg.length.toFloat32) / 2.0
    let y := frame.y - charSize * 2
    r.setDrawColor 255 255 255 255
    r.debugText x y msg

    if let some msg2 := msg2? then
      let x := frame.x + (frame.w - charSize * msg2.length.toFloat32) / 2.0
      let y := frame.y - charSize * 4
      r.setDrawColor 255 255 255 255
      r.debugText x y msg2

    r.present
    return .continue

def main : IO UInt32 := Examples.runApp app
