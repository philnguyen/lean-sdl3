import Common

/-!
# demo/03-infinite-monkeys

A troupe of monkeys bangs on keyboards; whenever a monkey happens to type the
next character of a fixed text, that character is accepted and the text advances.
A green bar tracks progress and a caption shows the elapsed time.

Port of the official example `examples/demo/03-infinite-monkeys/infinite-monkeys.c`
(https://examples.libsdl.org/SDL3/demo/03-infinite-monkeys/). The typing logic
is a pure, `#guard`-tested Lean reimplementation; the layout-dependent
scancode/keycode queries stay in `IO` exactly as the C does.

## Deviations
- **Text as `Array Char`**: the C walks a UTF-8 `char*` with `SDL_StepUTF8` and
  reassembles typed characters with `SDL_UCS4ToUTF8`. Lean strings are already
  Unicode, so the text is a `Array Char` and `progress : Nat` an index into it
  ("advance index" replaces `SDL_StepUTF8`, `String.mk`/`Array.push` replaces the
  UCS4→UTF8 accumulation). The progress fraction uses character counts, not byte
  counts — visually equivalent.
- **RNG in the state**: the C draws from SDL's global `SDL_rand`. We carry an
  `xorshift64` stream in `MonkeyState.rng` (Snake idiom) so `monkeyRandom` stays
  pure and testable.
- **`canMonkeyType` on an unmapped key**: `SDL_GetScancodeFromKey` (and its
  shim) returns `SDL_SCANCODE_UNKNOWN` (0) without failing for keys the layout
  can't produce; 0 falls below the monkey range, so it is rejected — same as the
  C, which relies on `UNKNOWN` being outside `[A, SLASH]`.
- **CLI args via `main`**: `main` forwards its argument list to `runApp`, so
  `--monkeys N` and the optional text-file path work as in the C's `argv`.
- No `Sdl.quit`; SDL reclaims the window/renderer at process exit (repo policy).
-/

open Sdl

/-! ## Constants (C: the `#define`s) -/

/-- Lowest scancode a monkey can hit. C: `MIN_MONKEY_SCANCODE` (`SDL_SCANCODE_A`). -/
def minMonkeyScancode : UInt32 := Scancode.a.val
/-- Highest scancode a monkey can hit. C: `MAX_MONKEY_SCANCODE` (`SDL_SCANCODE_SLASH`). -/
def maxMonkeyScancode : UInt32 := Scancode.slash.val
/-- Glyph size of the debug-text font (pixels). C: `SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE`. -/
def fontSize : Nat := 8

/-! ## Default text (C: `default_text`, all 36 `\n`-terminated lines) -/

/-- The 36 lines of the built-in Jabberwocky text, in C source order. -/
def defaultTextLines : List String :=
  [ "Jabberwocky, by Lewis Carroll",
    "",
    "'Twas brillig, and the slithy toves",
    "      Did gyre and gimble in the wabe:",
    "All mimsy were the borogoves,",
    "      And the mome raths outgrabe.",
    "",
    "\"Beware the Jabberwock, my son!",
    "      The jaws that bite, the claws that catch!",
    "Beware the Jubjub bird, and shun",
    "      The frumious Bandersnatch!\"",
    "",
    "He took his vorpal sword in hand;",
    "      Long time the manxome foe he sought-",
    "So rested he by the Tumtum tree",
    "      And stood awhile in thought.",
    "",
    "And, as in uffish thought he stood,",
    "      The Jabberwock, with eyes of flame,",
    "Came whiffling through the tulgey wood,",
    "      And burbled as it came!",
    "",
    "One, two! One, two! And through and through",
    "      The vorpal blade went snicker-snack!",
    "He left it dead, and with its head",
    "      He went galumphing back.",
    "",
    "\"And hast thou slain the Jabberwock?",
    "      Come to my arms, my beamish boy!",
    "O frabjous day! Callooh! Callay!\"",
    "      He chortled in his joy.",
    "",
    "'Twas brillig, and the slithy toves",
    "      Did gyre and gimble in the wabe:",
    "All mimsy were the borogoves,",
    "      And the mome raths outgrabe." ]

/-- The built-in text with a trailing newline (matching the C's final `\n`).
C: `default_text`. -/
def defaultText : String := String.intercalate "\n" defaultTextLines ++ "\n"

/-! ## Pure logic -/

/-- One step of the xorshift64 PRNG (never maps a nonzero state to zero). -/
def xorshift64 (s : UInt64) : UInt64 :=
  let s := s ^^^ (s <<< 13)
  let s := s ^^^ (s >>> 7)
  s ^^^ (s <<< 17)

/-- The full typing state. Groups the C's `text`/`progress`/`row`/`lines`/
`monkey_chars` globals plus the RNG stream. `lines` has `rows` entries (each a
ring-buffered line, its `.size` the C `Line.length`); `monkeyChars` has `cols`
entries. C: the file-scope globals. -/
structure MonkeyState where
  /-- The full text, one `Char` per code point. -/
  text : Array Char
  /-- Index of the next character to type (C: `progress - text`). -/
  progress : Nat
  /-- Visible line count (`h/8 - 4`); `0` disables line bookkeeping. -/
  rows : Nat
  /-- Visible column count (`w/8`); `0` disables line bookkeeping. -/
  cols : Nat
  /-- Monotone row counter; the visible slot is `row % rows`. -/
  row : Nat
  /-- `rows` ring-buffered lines. -/
  lines : Array (Array Char)
  /-- `cols` most-recently-typed characters (per monkey column). -/
  monkeyChars : Array Char
  /-- xorshift64 state. -/
  rng : UInt64
deriving Inhabited

/-- Finish the current line and start the next. C: `AdvanceRow`. -/
def advanceRow (s : MonkeyState) : MonkeyState :=
  let row := s.row + 1
  { s with row, lines := s.lines.set! (row % s.rows) #[] }

/-- Record a typed (or freebie, `monkey = -1`) character: stamp the monkey
column, append to the current ring line (wrapping at `cols`, or advancing on
`'\n'`), and advance `progress`. C: `AddMonkeyChar`. -/
def addMonkeyChar (s : MonkeyState) (monkey : Int) (ch : Char) : MonkeyState :=
  let s :=
    if monkey ≥ 0 ∧ s.cols > 0 then
      { s with monkeyChars := s.monkeyChars.set! (monkey.toNat % s.cols) ch }
    else s
  let s :=
    if s.rows > 0 ∧ s.cols > 0 then
      if ch == '\n' then advanceRow s
      else
        let idx := s.row % s.rows
        let line := s.lines[idx]!.push ch
        let s := { s with lines := s.lines.set! idx line }
        if line.size == s.cols then advanceRow s else s
    else s
  { s with progress := s.progress + 1 }

-- Line bookkeeping on a tiny 3×4 grid.
def testGrid : MonkeyState :=
  { text := #[], progress := 0, rows := 3, cols := 4, row := 0,
    lines := Array.replicate 3 #[], monkeyChars := Array.replicate 4 ' ', rng := 1 }

#guard (addMonkeyChar testGrid 0 'a').lines[0]! == #['a']
#guard (addMonkeyChar testGrid 2 'x').monkeyChars[2]! == 'x'
#guard (addMonkeyChar testGrid 0 'a').progress == 1
-- A freebie (`monkey = -1`) advances progress but leaves the monkey columns.
#guard (addMonkeyChar testGrid (-1) 'q').monkeyChars == Array.replicate 4 ' '
#guard (addMonkeyChar testGrid (-1) 'q').lines[0]! == #['q']
-- A newline advances the row.
#guard (addMonkeyChar testGrid 0 '\n').row == 1
-- Filling a line (cols = 4) wraps to the next row.
#guard
  let s := addMonkeyChar (addMonkeyChar (addMonkeyChar
    (addMonkeyChar testGrid 0 'a') 1 'b') 2 'c') 3 'd'
  s.row == 1 && s.lines[0]!.size == 4
-- Ring indexing: after three newlines, row = 3 and the next char lands in slot 0.
#guard
  let s := addMonkeyChar (addMonkeyChar (addMonkeyChar testGrid 0 '\n') 0 '\n') 0 '\n'
  (addMonkeyChar s 0 'z').lines[0]! == #['z']

/-- Draw a random scancode in `[A, SLASH]` with a random shift-or-none modifier,
advancing the RNG stream. Returns `(scancode, modifier, newRng)`. C: the random
draws inside `MonkeyPlay`. -/
def monkeyRandom (rng : UInt64) : Scancode × Keymod × UInt64 :=
  let r1 := xorshift64 rng
  -- count = MAX_MONKEY_SCANCODE - MIN_MONKEY_SCANCODE + 1 = 0x38 - 0x04 + 1 = 53
  let count : UInt64 := (maxMonkeyScancode - minMonkeyScancode + 1).toUInt64
  let scv : UInt32 := minMonkeyScancode + (r1 % count).toUInt32
  let r2 := xorshift64 r1
  let mod : Keymod := if r2 % 2 == 1 then Keymod.shift else Keymod.none
  (⟨scv⟩, mod, r2)

#guard (monkeyRandom 12345).1.val ≥ minMonkeyScancode
#guard (monkeyRandom 12345).1.val ≤ maxMonkeyScancode
#guard (monkeyRandom 999).1.val ≥ minMonkeyScancode
#guard (monkeyRandom 999).1.val ≤ maxMonkeyScancode

/-! ## Layout-dependent queries (IO, like the C) -/

/-- Whether a monkey could produce character `ch`: it must map to a scancode in
`[A, SLASH]` using no modifier other than shift. C: `CanMonkeyType`. -/
def canMonkeyType (ch : Char) : IO Bool := do
  let (sc, mod) ← getScancodeFromKey ⟨ch.val⟩
  if sc.val < minMonkeyScancode || sc.val > maxMonkeyScancode then
    return false
  -- Monkeys can hit shift, but nothing else.
  return (mod &&& (~~~ Keymod.shift)) == Keymod.none

/-- One random keypress attempt, advancing the RNG in `st`. C: `MonkeyPlay`. -/
def monkeyPlay (st : IO.Ref MonkeyState) : IO Keycode := do
  let s ← st.get
  let (sc, mod, rng') := monkeyRandom s.rng
  st.set { s with rng := rng' }
  getKeyFromScancode sc mod false

/-- Advance `progress` over any characters the monkeys can't type (recording
them as freebies) and return the next typable character, or `none` at the end.
C: `GetNextChar`. -/
def getNextChar (st : IO.Ref MonkeyState) : IO (Option Char) := do
  let mut res : Option Char := none
  let mut go := true
  while go do
    let s ← st.get
    if s.progress < s.text.size then
      let ch := s.text[s.progress]!
      if (← canMonkeyType ch) then
        res := some ch
        go := false
      else
        -- Freebie: the monkeys can't type this, so accept it for free.
        st.modify (addMonkeyChar · (-1) ch)
    else
      go := false
  return res

/-! ## App wiring -/

structure AppState where
  window : Window
  renderer : Renderer
  st : IO.Ref MonkeyState
  /-- Clock at startup. C: `start_time`. -/
  startTime : Time
  /-- Frozen completion clock, set the first frame `progress` reaches the end.
  C: `end_time`. -/
  endTime : IO.Ref (Option Time)
  /-- Number of monkeys. C: `monkeys`. -/
  monkeys : Nat

/-- The visible `(rows, cols)` for the current render output. C: the row/col
computation in `OnWindowSizeChanged` (guarding both `> 0`). -/
def computeGrid (r : Renderer) : IO (Nat × Nat) := do
  let (w, h) ← r.getCurrentOutputSize
  let fs := Sdl.debugTextFontCharacterSize
  let rows := ((h / fs) - 4).toNatClampNeg
  let cols := (w / fs).toNatClampNeg
  return (rows, cols)

/-- Fresh typing state for a text and grid. C: the allocations in
`OnWindowSizeChanged` plus the globals initialized in `SDL_AppInit`. -/
def initialMonkeyState (text : Array Char) (rng : UInt64) (rows cols : Nat) : MonkeyState :=
  { text, progress := 0, rows, cols, row := 0,
    lines := Array.replicate rows #[],
    monkeyChars := Array.replicate cols ' ', rng }

/-- Draw one line's characters as debug text at `(x, y)`. C: `DisplayLine`. -/
def displayLine (r : Renderer) (x y : Float32) (line : Array Char) : IO Unit :=
  r.debugText x y (String.ofList line.toList)

/-- The elapsed-time caption (freezing the clock once the text completes).
C: the caption block of `SDL_AppIterate`. -/
def captionString (s : AppState) (m : MonkeyState) : IO String := do
  let now ←
    if m.progress ≥ m.text.size then
      match (← s.endTime.get) with
      | some t => pure t
      | none => let t ← getCurrentTime; s.endTime.set (some t); pure t
    else getCurrentTime
  let elapsed := (now.ns - s.startTime.ns).toInt / 1000000000
  let seconds := (elapsed % 60).toNat
  let minutes := ((elapsed / 60) % 60).toNat
  let hours := (elapsed / 3600).toNat
  return s!"Monkeys: {s.monkeys} - {hours}H:{minutes}M:{seconds}S"

def app : App AppState where
  init args := do
    setAppMetadata "Infinite Monkeys" "1.0" "com.example.infinite-monkeys"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/demo/infinite-monkeys" 640 480
    renderer.setVSync 1
    -- argv: [--monkeys N] [file.txt]
    let mut monkeys : Nat := 100
    let mut fileArg : Option String := none
    match args with
    | "--monkeys" :: rest =>
      match rest with
      | n :: rest2 =>
        monkeys := (n.toNat?).getD 0
        fileArg := rest2.head?
      | [] =>
        IO.eprintln "Usage: infinite-monkeys [--monkeys N] [file.txt]"
        return (.failure, none)
    | other => fileArg := other.head?
    let text : Array Char ←
      match fileArg with
      | some file =>
        try
          let contents ← IO.FS.readFile file
          pure contents.toList.toArray
        catch e =>
          IO.eprintln s!"Couldn't open {file}: {e}"
          return (.failure, none)
      | none => pure defaultText.toList.toArray
    let startTime ← getCurrentTime
    let seed ← getTicksNS
    let rng := if seed == 0 then 1 else seed
    let (rows, cols) ← computeGrid renderer
    let st ← IO.mkRef (initialMonkeyState text rng rows cols)
    let endTime ← IO.mkRef none
    return (.continue, some { window, renderer, st, startTime, endTime, monkeys })
  event s e := do
    match e with
    | .quit _ => return .success
    | .windowPixelSizeChanged _ =>
      let (rows, cols) ← computeGrid s.renderer
      s.st.modify fun m =>
        { m with
          rows := rows, cols := cols, row := 0,
          lines := Array.replicate rows #[],
          monkeyChars := Array.replicate cols ' ' }
      return .continue
    | _ => return .continue
  iterate s := do
    -- Let each monkey take a turn: fetch the next typable character (skipping
    -- freebies), then attempt one random keypress. C: the `for` loop.
    let mut nextChar : Option Char := none
    let mut stop := false
    for monkey in [0:s.monkeys] do
      if !stop then
        if nextChar.isNone then
          match (← getNextChar s.st) with
          | none => stop := true          -- all done
          | some c => nextChar := some c
        if !stop then
          let key ← monkeyPlay s.st
          if let some c := nextChar then
            if key.val == c.val then
              s.st.modify (addMonkeyChar · (Int.ofNat monkey) c)
              nextChar := none
    -- Render.
    let m ← s.st.get
    s.renderer.setDrawColor 0 0 0 255
    s.renderer.clear
    s.renderer.setDrawColor 255 255 255 255
    let font : Float32 := Nat.toFloat32 fontSize
    let mut y : Float32 := 0.0
    if m.rows > 0 then
      -- The `rows` visible lines, in ring order.
      let rowOffset := if m.row + 1 < m.rows then 0 else m.row + 1 - m.rows
      for i in [0:m.rows] do
        displayLine s.renderer 0.0 (Nat.toFloat32 (i * fontSize))
          m.lines[(rowOffset + i) % m.rows]!
      -- Caption one blank line below.
      y := Nat.toFloat32 ((m.rows + 1) * fontSize)
      s.renderer.debugText 0.0 y (← captionString s m)
      y := y + font
      -- The currently-typed characters.
      displayLine s.renderer 0.0 y m.monkeyChars
      y := y + font
    -- Progress bar (green).
    s.renderer.setDrawColor 0 255 0 255
    let progW : Float32 :=
      if m.text.size == 0 then 0.0
      else (m.progress.toFloat / m.text.size.toFloat).toFloat32 * Nat.toFloat32 (m.cols * fontSize)
    s.renderer.fillRect (some { x := 0.0, y, w := progW, h := font })
    s.renderer.present
    return .continue

def main (args : List String) : IO UInt32 := Examples.runApp app args
