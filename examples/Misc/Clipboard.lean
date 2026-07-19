import Common

/-!
# misc/02-clipboard

Lets the user copy and paste with the system clipboard: a button copies the
current time string to the clipboard, another pastes the clipboard's text
into a display area. This only handles text, but SDL supports other data
types, too.

Port of the official example `examples/misc/02-clipboard/clipboard.c`
(https://examples.libsdl.org/SDL3/misc/02-clipboard/).

Deviations:
- C calls `SDL_ConvertEventToRenderCoordinates` on every event (unbound;
  Lean events are immutable copies): instead the mouse handlers map the
  event's window coordinates through `Renderer.coordinatesFromWindow`.
- The C's `SDL_snprintf` formatting is reproduced with Lean string
  interpolation plus a local `%02d` padding helper.
- Pasted-line truncation uses `String.take`, which counts Unicode
  characters where the C counts bytes (the C comment itself disclaims
  Unicode handling).
- `pasted_str` is an `IO.Ref (Option String)`; no manual `SDL_free` needed.
-/

open Sdl

def copyButtonStr := "Click here to copy!"
def pasteButtonStr := "Click here to paste!"

structure State where
  window : Window
  renderer : Renderer
  currentTimeRect : FRect
  copyButtonRect : FRect
  pasteTextRect : FRect
  pasteButtonRect : FRect
  copyPressed : IO.Ref Bool
  pastePressed : IO.Ref Bool
  currentTime : IO.Ref String
  pastedStr : IO.Ref (Option String)

/-- Zero-padded two-digit number (C: `%02d`). -/
def pad2 (n : Int32) : String :=
  if 0 ≤ n && n < 10 then s!"0{n}" else toString n

/-- The current wall-clock time as a display string.
C: `CalculateCurrentTimeString`. -/
def calculateCurrentTimeString : IO String := do
  try
    let dt ← (← getCurrentTime).toDateTime
    let month := #["January", "February", "March", "April", "May", "June",
                   "July", "August", "September", "October", "November", "December"]
    let day := #["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday",
                 "Friday", "Saturday"]
    return s!"{day[dt.dayOfWeek.toNatClampNeg]!}, {month[(dt.month - 1).toNatClampNeg]!} \
      {dt.day}, {dt.year}   {pad2 dt.hour}:{pad2 dt.minute}:{pad2 dt.second}"
  catch _ =>
    return "(Don't know the current time, sorry.)"

/-- Draw the pasted clipboard text into `rect`, line by line.
C: `RenderPastedText`. -/
def renderPastedText (r : Renderer) (rect : FRect) (str : String) : IO Unit := do
  let charSize := (debugTextFontCharacterSize).toFloat32
  let x := rect.x + 5
  let w := rect.w - 10
  let h := rect.h
  let maxCharsPerLine := (w / charSize).toUInt32.toNat
  let mut y := rect.y + 5
  -- this doesn't wordwrap, or deal with Unicode....this is just a simple example app!
  let lines := str.splitOn "\n"
  for line in lines.dropLast do
    let line := if line.endsWith "\r" then line.dropEnd 1 else line
    r.debugText x y (line.take maxCharsPerLine).toString
    y := y + (charSize + 2)
    if h - y < charSize then
      break  -- no space for another line, stop here.
  -- last text after newline, if there's room.
  if h - y ≥ charSize then
    r.debugText x y (lines.getLast!.take maxCharsPerLine).toString

def app : App State where
  init _ := do
    setAppMetadata "Example Misc Clipboard" "1.0" "com.example.misc-clipboard"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/misc/clipboard" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox

    let currentTime ← IO.mkRef (← calculateCurrentTimeString)
    let charSize := (debugTextFontCharacterSize).toFloat32

    -- set up the locations where we'll draw stuff.
    let currentTimeRect : FRect := ⟨30, 10, 390, charSize + 10⟩
    let copyButtonRect : FRect :=
      ⟨currentTimeRect.x + currentTimeRect.w + 30, currentTimeRect.y,
       charSize * copyButtonStr.length.toFloat32 + 10, currentTimeRect.h⟩
    let pasteTextY := currentTimeRect.y + currentTimeRect.h + 10
    let pasteTextRect : FRect :=
      ⟨10, pasteTextY, 620, ((480 - pasteTextY) - copyButtonRect.h) - 20⟩
    let pasteButtonW := charSize * pasteButtonStr.length.toFloat32 + 10
    let pasteButtonRect : FRect :=
      ⟨(640 - pasteButtonW) / 2.0, pasteTextRect.y + pasteTextRect.h + 10,
       pasteButtonW, copyButtonRect.h⟩

    let copyPressed ← IO.mkRef false
    let pastePressed ← IO.mkRef false
    let pastedStr ← IO.mkRef (none : Option String)
    return (.continue, some {
      window, renderer, currentTimeRect, copyButtonRect, pasteTextRect,
      pasteButtonRect, copyPressed, pastePressed, currentTime, pastedStr })
  event s e := do
    match e with
    | .quit _ => return .success
    | .mouseButtonDown e =>
      if e.button == .left then
        let (px, py) ← s.renderer.coordinatesFromWindow e.x e.y
        let p : FPoint := ⟨px, py⟩
        s.copyPressed.set (p.inRect s.copyButtonRect)
        s.pastePressed.set (p.inRect s.pasteButtonRect)
    | .mouseButtonUp e =>
      if e.button == .left then
        let (px, py) ← s.renderer.coordinatesFromWindow e.x e.y
        let p : FPoint := ⟨px, py⟩
        if (← s.copyPressed.get) && p.inRect s.copyButtonRect then
          setClipboardText (← s.currentTime.get)
        else if (← s.pastePressed.get) && p.inRect s.pasteButtonRect then
          s.pastedStr.set (some (← getClipboardText))
        s.copyPressed.set false
        s.pastePressed.set false
    | _ => pure ()
    return .continue
  iterate s := do
    let r := s.renderer
    let charSize := (debugTextFontCharacterSize).toFloat32

    s.currentTime.set (← calculateCurrentTimeString)
    let currentTime ← s.currentTime.get

    r.setDrawColor 0 0 0 255  -- black
    r.clear

    -- draw a frame around the current time.
    r.setDrawColor 0 0 255 255
    r.fillRect (some s.currentTimeRect)
    r.setDrawColor 255 255 255 255
    r.rect (some s.currentTimeRect)

    -- draw the current time inside the frame.
    let x := s.currentTimeRect.x +
      (s.currentTimeRect.w - charSize * currentTime.length.toFloat32) / 2.0
    let y := s.currentTimeRect.y + 5
    r.setDrawColor 255 255 0 255
    r.debugText x y currentTime

    -- draw a frame for the "copy the current time to the clipboard" button.
    if (← s.copyPressed.get) then
      r.setDrawColor 0 255 0 255
    else
      r.setDrawColor 255 0 0 255
    r.fillRect (some s.copyButtonRect)
    r.setDrawColor 255 255 255 255
    r.rect (some s.copyButtonRect)

    -- draw the "copy this text" button string.
    r.setDrawColor 255 255 255 255
    r.debugText (s.copyButtonRect.x + 5) (s.copyButtonRect.y + 5) copyButtonStr

    -- draw a frame for the pasted text area.
    r.setDrawColor 0 53 25 255
    r.fillRect (some s.pasteTextRect)
    r.setDrawColor 255 255 255 255
    r.rect (some s.pasteTextRect)

    -- draw pasted text.
    r.setDrawColor 0 219 107 255
    if let some str := (← s.pastedStr.get) then
      renderPastedText r s.pasteTextRect str

    -- draw a frame for the "paste from the clipboard" button.
    if (← s.pastePressed.get) then
      r.setDrawColor 0 255 0 255
    else
      r.setDrawColor 255 0 0 255
    r.fillRect (some s.pasteButtonRect)
    r.setDrawColor 255 255 255 255
    r.rect (some s.pasteButtonRect)

    -- draw the "paste some text" button string.
    r.setDrawColor 255 255 255 255
    r.debugText (s.pasteButtonRect.x + 5) (s.pasteButtonRect.y + 5) pasteButtonStr

    r.present
    return .continue

def main : IO UInt32 := Examples.runApp app
