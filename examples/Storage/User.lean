import Common

/-!
# storage/user

Waits for a click on the window, then saves or loads a one-`Uint64` "game
world" through SDL user storage without blocking the main thread. Left click
saves, any other click loads. The window color tracks the state machine: blue
(idle), yellow (serializing), cyan (opening storage), magenta (writing), green
on success / red on failure.

Port of the official example `examples/storage/01-user/user.c`
(https://examples.libsdl.org/SDL3/storage/01-user/).

## Deviations (threading model)
The C original coordinates a background `SDL_Thread` with an `SDL_AtomicInt`
state, an `SDL_Semaphore`, and `SDL_WaitThread`. Per the project plan these SDL
primitives are replaced by Lean `Task`/`IO.Ref` idioms:
- `SDL_AtomicInt current_save_state` → `IO.Ref SaveState` (a plain inductive).
- `SDL_Thread` + `SDL_CreateThread` → `IO.asTask` (the worker runs on a Lean
  task thread; SDL storage calls are thread-safe and have no main-thread
  constraint).
- `SDL_Semaphore storage_ready` + the main thread polling `SDL_StorageReady`
  and signaling → the WORKER polls `storage.ready` itself in a `Sdl.delay 10`
  loop (up to ~500 iterations, then give up as failure). In C the main thread
  only did this to demonstrate a semaphore; the observable behavior is the same.
- `save_result` int → `IO.Ref (Option Bool)` (`none` = in progress).
- `SDL_WaitThread` → an `IO.Ref (Option (Task ..))`; the main loop polls
  `IO.hasFinished`.

## Deviations (self-check)
Under `SDL_LEAN_MAX_FRAMES` (headless smoke) the state machine is driven
automatically: at frame 5 the save routine is triggered, and once it reaches a
successful `finalCheck` the load routine runs; when the load finishes, the
loaded value is compared to the saved one and `storage self-check: round-trip
value matches (ok)` is printed. `main` returns 1 if the frame cap expires before
the round-trip is verified. Interactive mouse behavior is unchanged. No such
gate exists in the C original.

Note: this writes a real file under
`~/Library/Application Support/libsdl/User Storage Example/` (same org/app and
same location as the C example on macOS) — intended.
-/

open Sdl

/-- The steps of a save or load, mirroring the C `savestate_t` enum. -/
inductive SaveState
  | unstarted            -- blue
  | processingGameWorld  -- yellow
  | preparingStorage     -- cyan
  | processingStorageFile -- magenta
  | finalCheck           -- green if ok, red if failed
deriving BEq, Inhabited

/-! ## Little-endian `UInt64` (de)serialization -/

/-- The 8 bytes of `n`, little-endian. C: writing `sizeof(Uint64)` raw bytes. -/
def u64ToBytesLE (n : UInt64) : ByteArray := Id.run do
  let mut b := ByteArray.emptyWithCapacity 8
  for i in [0:8] do
    b := b.push (n >>> (i.toUInt64 * 8)).toUInt8
  return b

/-- Reassemble a `UInt64` from its little-endian bytes (first 8 bytes of `b`). -/
def u64FromBytesLE (b : ByteArray) : UInt64 := Id.run do
  let mut n : UInt64 := 0
  for i in [0:8] do
    n := n ||| (b[i]!.toUInt64 <<< (i.toUInt64 * 8))
  return n

#guard (u64ToBytesLE 1).toList == [1, 0, 0, 0, 0, 0, 0, 0]
#guard (u64ToBytesLE 0x0102030405060708).toList == [8, 7, 6, 5, 4, 3, 2, 1]
#guard (u64ToBytesLE 12345).size == 8
#guard u64FromBytesLE (u64ToBytesLE 0) == 0
#guard u64FromBytesLE (u64ToBytesLE 12345) == 12345
#guard u64FromBytesLE (u64ToBytesLE 0x0123456789ABCDEF) == 0x0123456789ABCDEF
#guard u64FromBytesLE (u64ToBytesLE 0xFFFFFFFFFFFFFFFF) == 0xFFFFFFFFFFFFFFFF

/-! ## Shared refs -/

/-- Mutable state shared between the main loop and the worker task. Created in
`main` so the post-run self-check can inspect it (BytePusher's shape). -/
structure Refs where
  saveState  : IO.Ref SaveState
  /-- Worker outcome: `none` while in progress, `some ok` when done. -/
  saveResult : IO.Ref (Option Bool)
  /-- The running worker, or `none` when idle. `SDL_WaitThread` → poll this. -/
  task       : IO.Ref (Option (Task (Except IO.Error Unit)))
  /-- The value written by the last save, for the round-trip self-check. -/
  savedValue  : IO.Ref (Option UInt64)
  /-- The value read by the last load, for the round-trip self-check. -/
  loadedValue : IO.Ref (Option UInt64)
  /-- Frame counter (self-check only). -/
  frame      : IO.Ref Nat
  /-- Self-check phase: 0 idle, 1 saving, 2 loading, 3 verified/done. -/
  scPhase    : IO.Ref Nat
  /-- Whether the round-trip was verified (self-check success flag). -/
  verified   : IO.Ref Bool
  /-- `SDL_LEAN_MAX_FRAMES`, if set (enables the self-check driver). -/
  maxFrames  : Option Nat

def Refs.new : IO Refs := do
  let saveState ← IO.mkRef SaveState.unstarted
  let saveResult ← IO.mkRef (none : Option Bool)
  let task ← IO.mkRef (none : Option (Task (Except IO.Error Unit)))
  let savedValue ← IO.mkRef (none : Option UInt64)
  let loadedValue ← IO.mkRef (none : Option UInt64)
  let frame ← IO.mkRef 0
  let scPhase ← IO.mkRef 0
  let verified ← IO.mkRef false
  let maxFrames := (← IO.getEnv "SDL_LEAN_MAX_FRAMES").bind (·.toNat?)
  return {
    saveState, saveResult, task, savedValue, loadedValue, frame, scPhase,
    verified, maxFrames }

/-- Org/app for `openUser` — same identifiers as the C example. -/
def saveOrg : String := "libsdl"
def saveApp : String := "User Storage Example"
def saveFileName : String := "save.sav"

/-- Poll `storage.ready` up to ~500 times, sleeping 10 ms between polls (the
worker's stand-in for the C semaphore handshake). Returns `false` if it never
becomes ready. -/
partial def pollReady (storage : Storage) : IO Bool := do
  let rec go (i : Nat) : IO Bool := do
    if (← storage.ready) then return true
    if i == 0 then return false
    Sdl.delay 10
    go (i - 1)
  go 500

/-! ## Worker routines (run on a Lean task thread) -/

/-- Serialize a fictional 64-bit game world and write it to user storage.
C: `WriteSaveData`. -/
def writeSaveData (r : Refs) : IO Unit := do
  r.saveState.set .processingGameWorld
  -- Pretend an entire game fits in 64 bits. C: SDL_GetPerformanceCounter.
  let gameWorld ← getPerformanceCounter
  r.savedValue.set (some gameWorld)
  let ok ← try
    let storage ← Storage.openUser saveOrg saveApp
    r.saveState.set .preparingStorage
    if !(← pollReady storage) then
      storage.close
      pure false
    else
      r.saveState.set .processingStorageFile
      storage.writeFile saveFileName (u64ToBytesLE gameWorld)
      storage.close
      pure true
  catch e =>
    Sdl.log s!"Save failed: {e}"
    pure false
  r.saveResult.set (some ok)
  r.saveState.set .finalCheck

/-- Open user storage, read the save file, and deserialize the game world.
C: `ReadSaveData`. -/
def readSaveData (r : Refs) : IO Unit := do
  let ok ← try
    let storage ← Storage.openUser saveOrg saveApp
    r.saveState.set .preparingStorage
    if !(← pollReady storage) then
      storage.close
      pure false
    else
      -- getFileSize throws when the file is absent (C: read_result == false).
      let size ← try
          pure (← storage.getFileSize saveFileName)
        catch _ =>
          storage.close
          Sdl.log "Save data was not found"
          pure (0 : UInt64)
      if size == 0 then
        pure false
      else if size != 8 then
        storage.close
        Sdl.log "Save data size is incorrect, was the file corrupted?"
        pure false
      else
        let bytes ← storage.readFile saveFileName
        storage.close
        r.saveState.set .processingGameWorld
        let gameWorld := u64FromBytesLE bytes
        r.loadedValue.set (some gameWorld)
        Sdl.log s!"Game World loaded, value was {gameWorld}"
        pure true
  catch e =>
    Sdl.log s!"Load failed: {e}"
    pure false
  r.saveResult.set (some ok)
  r.saveState.set .finalCheck

/-- Start `writeSaveData`/`readSaveData` as a background task. -/
def startWorker (r : Refs) (save : Bool) : IO Unit := do
  r.saveState.set .unstarted
  r.saveResult.set none
  let t ← IO.asTask (if save then writeSaveData r else readSaveData r)
  r.task.set (some t)

/-! ## App wiring -/

structure State where
  window : Window
  renderer : Renderer
  refs : Refs

/-- `(red, green, blue)` for the current state. Same RGB as the C `switch`. -/
def stateColor (st : SaveState) (result : Option Bool) :
    Float32 × Float32 × Float32 :=
  match st with
  | .unstarted             => (0, 0, 1)  -- blue
  | .processingGameWorld   => (1, 1, 0)  -- yellow
  | .preparingStorage      => (0, 1, 1)  -- cyan
  | .processingStorageFile => (1, 0, 1)  -- magenta
  | .finalCheck            =>
    if result == some true then (0, 1, 0)  -- green
    else (1, 0, 0)                          -- red

/-- Advance the automated round-trip (self-check only). The loop is unthrottled,
so frame count barely tracks wall-clock; we instead drive the machine
deterministically: at frame 5 kick off the save and `IO.wait` for it (safe —
the worker polls `storage.ready` itself, with no main-thread dependency), then
the load, then verify. This completes in a few frames whatever the loop speed,
so the 60-frame smoke cap has ample margin. Each stage still renders a frame so
the state colors cycle as in the interactive app. -/
def driveSelfCheck (r : Refs) : IO Unit := do
  let f ← r.frame.get
  r.frame.set (f + 1)
  match (← r.scPhase.get) with
  | 0 =>
    if f ≥ 5 then
      startWorker r true
      if let some t ← r.task.get then let _ ← IO.wait t
      r.scPhase.set 1
  | 1 =>
    -- Save done (reaped by `iterate`'s finalCheck handler). If it succeeded,
    -- start the load and wait for it too.
    if (← r.saveResult.get) == some true then
      r.loadedValue.set none
      startWorker r false
      if let some t ← r.task.get then let _ ← IO.wait t
      r.scPhase.set 2
    else
      IO.eprintln "storage self-check FAILED: save did not succeed"
      r.scPhase.set 3
  | 2 =>
    -- Load done and reaped; compare the round-trip values.
    let saved ← r.savedValue.get
    let loaded ← r.loadedValue.get
    if saved.isSome && saved == loaded then
      IO.println "storage self-check: round-trip value matches (ok)"
      r.verified.set true
    else
      IO.eprintln s!"storage self-check FAILED: saved={saved} loaded={loaded}"
    r.scPhase.set 3
  | _ => pure ()

def app (refs : Refs) : App State where
  init := fun _args => do
    setAppMetadata "User Storage Example" "1.0" "com.example.storage-user"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/storage/user" 640 480 .none
    return (.continue, some { window, renderer, refs })
  event := fun s e => do
    let r := s.refs
    match e with
    | .quit _ => return .success
    | .mouseButtonDown me =>
      if (← r.task.get).isSome then
        Sdl.log "Ignoring interaction, save/load is in progress"
      else
        -- Left button saves; anything else loads. C: button == 1.
        startWorker r (me.button == MouseButton.left)
      return .continue
    | _ => return .continue
  iterate := fun s => do
    let r := s.refs
    let st ← r.saveState.get
    -- Reap a finished worker (C: SDL_WaitThread on SAVE_STATE_FINAL_CHECK).
    if st == .finalCheck then
      if let some t ← r.task.get then
        if (← IO.hasFinished t) then
          r.task.set none
          if (← r.saveResult.get) == some true then
            Sdl.log "Save/Load complete!"
          else
            Sdl.log "Save/Load failed"
    -- Color by state.
    let (red, green, blue) := stateColor st (← r.saveResult.get)
    s.renderer.setDrawColorFloat red green blue 1.0
    s.renderer.clear
    s.renderer.present
    -- Headless self-check driver.
    if r.maxFrames.isSome then driveSelfCheck r
    return .continue

  quit := fun s _ => do
    -- If a worker is still running, wait for it (C: SDL_WaitThread at shutdown).
    if let some t ← s.refs.task.get then
      let _ ← IO.wait t
    return ()

def main : IO UInt32 := do
  let refs ← Refs.new
  let code ← Examples.runApp (app refs)
  if refs.maxFrames.isSome then
    if !(← refs.verified.get) then
      IO.eprintln "storage self-check FAILED: round-trip not verified before frame cap"
      return 1
  return code
