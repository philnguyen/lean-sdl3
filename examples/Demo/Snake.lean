import Common

/-!
# demo/01-snake

The classic Snake game. The snake grows when it eats food and the game restarts
if it runs into itself. Steer with the arrow keys or a joystick hat; `r` restarts
and `q`/Escape quits.

Port of the official example `examples/demo/01-snake/snake.c`
(https://examples.libsdl.org/SDL3/demo/01-snake/). The game logic is a pure,
idiomatic Lean reimplementation of the C, with `#guard` tests below each group
of definitions.

## Deviations
- **Cell storage**: the C bit-packs 3 bits per cell into a byte array. We use a
  plain `Array SnakeCell` (row-major, `gameWidth × gameHeight`) — idiomatic Lean
  and behavior-identical.
- **RNG**: the C draws food positions from SDL's global `SDL_rand`. We carry an
  `xorshift64` state inside `SnakeContext`, so `step`/`initialize` stay pure and
  testable. The re-initialization on collision continues the same rng stream
  (as the C's global rng does), so it takes a `SnakeContext`'s current `rng`.
- **`newFoodPos` termination**: the C loops forever until it hits a free cell (it
  is only ever called when a free cell exists). We bound the search with
  `gameWidth * gameHeight * 8` fuel and fall back to a linear scan for the first
  free cell, so the function is total.
- **Positions as `Nat`**: the C uses `signed char` positions with an explicit
  `wrap_around_`. We keep `Nat` positions and fold the single-step wraparound into
  modular arithmetic (`+1 → (x+1) % w`, `-1 → (x + w - 1) % w`), which is
  equivalent for unit moves.
- **Headless self-test**: when `SDL_LEAN_MAX_FRAMES` is set (the smoke-run gate),
  `iterate` pushes a synthetic key-down event every 20 frames cycling
  right→down→left→up, exercising the full push → poll → decode → `redir`
  pipeline. It is inert in interactive runs (the env var is absent). The push
  uses the same test-only C entry point (`lean_sdl_test_push_key`) that
  `test/Tests/Events.lean` uses.
- No `Sdl.quit`; the joystick is released by its finalizer at process exit.
-/

open Sdl

/-! ## Constants (C: the `#define`s) -/

def stepRateMs : UInt64 := 125
def blockPx : Nat := 24
def gameWidth : Nat := 24
def gameHeight : Nat := 18

/-! ## Game state -/

/-- What occupies a cell. C: `SNAKE_CELL_*` (the value `next_dir + 1` encodes the
body segment's travel direction). -/
inductive SnakeCell where
  | nothing | sright | sup | sleft | sdown | food
  deriving Repr, BEq, Inhabited

/-- The snake's heading. C: `SNAKE_DIR_*`. -/
inductive SnakeDirection where
  | right | up | left | down
  deriving Repr, BEq, Inhabited

/-- The full game state. C: `SnakeContext`. -/
structure SnakeContext where
  /-- `gameWidth × gameHeight`, row-major. -/
  cells : Array SnakeCell
  headX : Nat
  headY : Nat
  tailX : Nat
  tailY : Nat
  nextDir : SnakeDirection
  inhibitTailStep : Nat
  occupiedCells : Nat
  /-- xorshift64 state. -/
  rng : UInt64
  deriving Repr, Inhabited

/-! ## Pure logic -/

/-- Row-major cell index. C: `SHIFT(x, y) / SNAKE_CELL_MAX_BITS`. -/
def cellIndex (x y : Nat) : Nat := x + y * gameWidth

/-- The cell at `(x, y)`. C: `snake_cell_at`. -/
def cellAt (ctx : SnakeContext) (x y : Nat) : SnakeCell :=
  ctx.cells[cellIndex x y]!

/-- Set the cell at `(x, y)`. C: `put_cell_at_`. -/
def putCell (ctx : SnakeContext) (x y : Nat) (ct : SnakeCell) : SnakeContext :=
  { ctx with cells := ctx.cells.set! (cellIndex x y) ct }

/-- Whether every cell is accounted for. C: `are_cells_full_`. -/
def cellsFull (ctx : SnakeContext) : Bool :=
  ctx.occupiedCells == gameWidth * gameHeight

/-- One step of the xorshift64 PRNG (never maps a nonzero state to zero). -/
def xorshift64 (s : UInt64) : UInt64 :=
  let s := s ^^^ (s <<< 13)
  let s := s ^^^ (s >>> 7)
  s ^^^ (s <<< 17)

/-- Place food on the first free cell found by linear scan (the exhausted-fuel
fallback for `newFoodPos`). -/
def fallbackFood (ctx : SnakeContext) : SnakeContext :=
  match (List.range (gameWidth * gameHeight)).find? (fun i => ctx.cells[i]! == .nothing) with
  | some i => { ctx with cells := ctx.cells.set! i .food }
  | none   => ctx

/-- Drop food on a random free cell, retrying up to `fuel` times. C: `new_food_pos_`. -/
def newFoodPosFuel (ctx : SnakeContext) : Nat → SnakeContext
  | 0 => fallbackFood ctx
  | fuel + 1 =>
    let r1 := xorshift64 ctx.rng
    let x := (r1 % gameWidth.toUInt64).toNat
    let r2 := xorshift64 r1
    let y := (r2 % gameHeight.toUInt64).toNat
    let ctx := { ctx with rng := r2 }
    if cellAt ctx x y == .nothing then
      putCell ctx x y .food
    else
      newFoodPosFuel ctx fuel

/-- Drop food on a random free cell. C: `new_food_pos_`. -/
def newFoodPos (ctx : SnakeContext) : SnakeContext :=
  newFoodPosFuel ctx (gameWidth * gameHeight * 8)

/-- Place `n` pieces of food, bumping `occupiedCells` for each. -/
def placeNFood : SnakeContext → Nat → SnakeContext
  | ctx, 0 => ctx
  | ctx, n + 1 =>
    let ctx := newFoodPos ctx
    placeNFood { ctx with occupiedCells := ctx.occupiedCells + 1 } n

/-- Fresh game with the given rng stream (continued on collision restart). -/
def initializeWith (rng : UInt64) : SnakeContext :=
  let cx := gameWidth / 2
  let cy := gameHeight / 2
  let ctx : SnakeContext :=
    { cells := Array.replicate (gameWidth * gameHeight) .nothing
      headX := cx, headY := cy, tailX := cx, tailY := cy
      nextDir := .right
      -- C: inhibit = occupied = 4; then --occupied.
      inhibitTailStep := 4, occupiedCells := 3
      rng }
  let ctx := putCell ctx cx cy .sright
  placeNFood ctx 4

/-- Fresh game seeded from `seed` (0 is remapped so the rng never sticks at 0).
C: `snake_initialize`. -/
def snakeInit (seed : UInt64) : SnakeContext :=
  initializeWith (if seed == 0 then 1 else seed)

#guard (snakeInit 12345).headX == 12
#guard (snakeInit 12345).headY == 9
#guard cellAt (snakeInit 12345) 12 9 == .sright
#guard (snakeInit 12345).occupiedCells == 7

/-- Change heading unless it would reverse straight back into the neck.
C: `snake_redir`. -/
def redir (ctx : SnakeContext) (dir : SnakeDirection) : SnakeContext :=
  let ct := cellAt ctx ctx.headX ctx.headY
  if (dir == .right && ct != .sleft) ||
     (dir == .up    && ct != .sdown) ||
     (dir == .left  && ct != .sright) ||
     (dir == .down  && ct != .sup) then
    { ctx with nextDir := dir }
  else ctx

-- Initial head cell is SRIGHT: reversing left is refused, turning up is accepted.
#guard (redir (snakeInit 12345) .left).nextDir == .right
#guard (redir (snakeInit 12345) .up).nextDir == .up

/-- The body cell that encodes `dir`. C: `(SnakeCell)(next_dir + 1)`. -/
def dirToCell : SnakeDirection → SnakeCell
  | .right => .sright
  | .up    => .sup
  | .left  => .sleft
  | .down  => .sdown

/-- Advance the game by one tick. C: `snake_step`. -/
def step (ctx : SnakeContext) : SnakeContext := Id.run do
  let dirAsCell := dirToCell ctx.nextDir
  let mut ctx := ctx
  -- Move tail forward (unless still inhibited).
  ctx := { ctx with inhibitTailStep := ctx.inhibitTailStep - 1 }
  if ctx.inhibitTailStep == 0 then
    ctx := { ctx with inhibitTailStep := ctx.inhibitTailStep + 1 }
    let ct := cellAt ctx ctx.tailX ctx.tailY
    ctx := putCell ctx ctx.tailX ctx.tailY .nothing
    match ct with
    | .sright => ctx := { ctx with tailX := (ctx.tailX + 1) % gameWidth }
    | .sup    => ctx := { ctx with tailY := (ctx.tailY + gameHeight - 1) % gameHeight }
    | .sleft  => ctx := { ctx with tailX := (ctx.tailX + gameWidth - 1) % gameWidth }
    | .sdown  => ctx := { ctx with tailY := (ctx.tailY + 1) % gameHeight }
    | _       => pure ()
  -- Move head forward.
  let prevX := ctx.headX
  let prevY := ctx.headY
  match ctx.nextDir with
  | .right => ctx := { ctx with headX := (ctx.headX + 1) % gameWidth }
  | .up    => ctx := { ctx with headY := (ctx.headY + gameHeight - 1) % gameHeight }
  | .left  => ctx := { ctx with headX := (ctx.headX + gameWidth - 1) % gameWidth }
  | .down  => ctx := { ctx with headY := (ctx.headY + 1) % gameHeight }
  -- Collisions.
  let ct := cellAt ctx ctx.headX ctx.headY
  if ct != .nothing && ct != .food then
    return initializeWith ctx.rng
  ctx := putCell ctx prevX prevY dirAsCell
  ctx := putCell ctx ctx.headX ctx.headY dirAsCell
  if ct == .food then
    if cellsFull ctx then
      return initializeWith ctx.rng
    ctx := newFoodPos ctx
    ctx := { ctx with inhibitTailStep := ctx.inhibitTailStep + 1 }
    ctx := { ctx with occupiedCells := ctx.occupiedCells + 1 }
  return ctx

-- Stepping from init moves the head one cell to the right; the vacated head
-- cell now holds the direction (body) cell.
#guard (step (snakeInit 12345)).headX == 13
#guard (step (snakeInit 12345)).headY == 9
#guard cellAt (step (snakeInit 12345)) 12 9 == .sright

-- Wraparound at the right edge: a head at the last column moving right lands at 0.
#guard
  let clean : SnakeContext :=
    { cells := Array.replicate (gameWidth * gameHeight) .nothing
      headX := gameWidth - 1, headY := 5, tailX := gameWidth - 1, tailY := 5
      nextDir := .right, inhibitTailStep := 4, occupiedCells := 1, rng := 1 }
  (step clean).headX == 0

-- Running into your own body re-initializes: head returns to the center and
-- `occupiedCells` resets to the fresh-game value.
#guard
  let collide : SnakeContext :=
    { cells := (Array.replicate (gameWidth * gameHeight) SnakeCell.nothing).set!
        (cellIndex 6 5) .sright
      headX := 5, headY := 5, tailX := 5, tailY := 5
      nextDir := .right, inhibitTailStep := 4, occupiedCells := 99, rng := 1 }
  (step collide).headX == gameWidth / 2 &&
    (step collide).occupiedCells == (initializeWith 1).occupiedCells

/-! ## App wiring -/

/-- Test-only synthetic event pusher (see module Deviations); backed by
`ffi/events_synth.c`, which the `extern_lib` archive links into every exe. -/
@[extern "lean_sdl_test_push_key"]
private opaque testPushKey (type : UInt32) (ts : UInt64) (windowId which scancode key : UInt32)
  (mod raw : UInt16) (down «repeat» : Bool) : IO Unit

structure AppState where
  window : Window
  renderer : Renderer
  ctx : IO.Ref SnakeContext
  lastStep : IO.Ref UInt64
  joystick : IO.Ref (Option Joystick)
  /-- Frame counter for the headless self-test. -/
  frame : IO.Ref Nat
  /-- Whether the headless self-test is active (`SDL_LEAN_MAX_FRAMES` set). -/
  selfDrive : Bool

/-- Steer from a keyboard scancode. C: `handle_key_event_`. -/
def handleKeyEvent (ctx : IO.Ref SnakeContext) (sc : Scancode) : IO AppResult := do
  if sc == Scancode.escape || sc == Scancode.q then
    return .success
  else if sc == Scancode.r then
    ctx.modify (fun c => initializeWith c.rng)
  else if sc == Scancode.right then
    ctx.modify (redir · .right)
  else if sc == Scancode.up then
    ctx.modify (redir · .up)
  else if sc == Scancode.left then
    ctx.modify (redir · .left)
  else if sc == Scancode.down then
    ctx.modify (redir · .down)
  return .continue

/-- Steer from a joystick hat position. C: `handle_hat_event_`. -/
def handleHatEvent (ctx : IO.Ref SnakeContext) (hat : Hat) : IO AppResult := do
  match hat.val with
  | 0x02 => ctx.modify (redir · .right)  -- SDL_HAT_RIGHT
  | 0x01 => ctx.modify (redir · .up)     -- SDL_HAT_UP
  | 0x08 => ctx.modify (redir · .left)   -- SDL_HAT_LEFT
  | 0x04 => ctx.modify (redir · .down)   -- SDL_HAT_DOWN
  | _    => pure ()
  return .continue

/-- The pixel rectangle for cell `(x, y)`. C: `set_rect_xy_` + the fixed w/h. -/
def cellRect (x y : Nat) : FRect :=
  { x := (x * blockPx).toFloat.toFloat32, y := (y * blockPx).toFloat.toFloat32
    w := blockPx.toFloat.toFloat32, h := blockPx.toFloat.toFloat32 }

/-- Draw the whole board: food blue-ish, body green, head yellow. -/
def draw (r : Renderer) (ctx : SnakeContext) : IO Unit := do
  r.setDrawColor 0 0 0 255
  r.clear
  for i in [0:gameWidth] do
    for j in [0:gameHeight] do
      let ct := cellAt ctx i j
      if ct != .nothing then
        if ct == .food then
          r.setDrawColor 80 80 255 255
        else
          r.setDrawColor 0 128 0 255  -- body
        r.fillRect (some (cellRect i j))
  r.setDrawColor 255 255 0 255  -- head
  r.fillRect (some (cellRect ctx.headX ctx.headY))
  r.present

/-- The four steering scancodes cycled through by the headless self-test. -/
def selfDriveKeys : Array Scancode := #[Scancode.right, Scancode.down, Scancode.left, Scancode.up]

def app : App AppState where
  init _ := do
    setAppMetadata "Example Snake game" "1.0" "com.example.Snake"
    -- Extended metadata (C: the `extended_metadata[]` table).
    setAppMetadataProperty "SDL.app.metadata.url" "https://examples.libsdl.org/SDL3/demo/01-snake/"
    setAppMetadataProperty "SDL.app.metadata.creator" "SDL team"
    setAppMetadataProperty "SDL.app.metadata.copyright" "Placed in the public domain"
    setAppMetadataProperty "SDL.app.metadata.type" "game"
    Sdl.init (.video ||| .joystick)
    let (window, renderer) ←
      createWindowAndRenderer "examples/demo/snake"
        (Int32.ofNat (blockPx * gameWidth)) (Int32.ofNat (blockPx * gameHeight)) .resizable
    renderer.setLogicalPresentation
      (Int32.ofNat (blockPx * gameWidth)) (Int32.ofNat (blockPx * gameHeight)) .letterbox
    let ctx ← IO.mkRef (snakeInit (← getTicksNS))
    let lastStep ← IO.mkRef (← getTicks)
    let joystick ← IO.mkRef none
    let frame ← IO.mkRef 0
    let selfDrive := (← IO.getEnv "SDL_LEAN_MAX_FRAMES").isSome
    return (.continue, some { window, renderer, ctx, lastStep, joystick, frame, selfDrive })
  event s e := do
    match e with
    | .quit _ => return .success
    | .joystickAdded e =>
      if (← s.joystick.get).isNone then
        try
          s.joystick.set (some (← openJoystick e.which))
        catch ex =>
          Sdl.log s!"Failed to open joystick ID {e.which.val}: {ex}"
      return .continue
    | .joystickRemoved e =>
      if let some j ← s.joystick.get then
        if (← j.getID) == e.which then
          j.close
          s.joystick.set none
      return .continue
    | .joystickHatMotion e => handleHatEvent s.ctx ⟨e.value⟩
    | .keyDown e => handleKeyEvent s.ctx e.scancode
    | _ => return .continue
  iterate s := do
    let now ← getTicks
    -- Run game logic if we're at or past the time to run it; if we're really
    -- behind, run it several times.
    let mut lastStep ← s.lastStep.get
    while now - lastStep ≥ stepRateMs do
      s.ctx.modify step
      lastStep := lastStep + stepRateMs
    s.lastStep.set lastStep
    draw s.renderer (← s.ctx.get)
    -- Headless self-test: drive the snake with synthetic key events.
    if s.selfDrive then
      let f ← s.frame.get
      s.frame.set (f + 1)
      if f % 20 == 0 then
        let sc := selfDriveKeys[(f / 20) % 4]!
        testPushKey 0x300 0 0 0 sc.val 0 0 0 true false
    return .continue

def main : IO UInt32 := Examples.runApp app
