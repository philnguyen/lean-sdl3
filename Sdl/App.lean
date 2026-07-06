import Sdl.Init
import Sdl.Events

/-!
# Application lifecycle (`Sdl.App`)

A Lean-side mirror of SDL's callback-style application shape —
`SDL_AppInit` / `SDL_AppEvent` / `SDL_AppIterate` / `SDL_AppQuit` (the
`SDL_MAIN_USE_CALLBACKS` protocol the official examples use) — driven by an
ordinary Lean `main`. SDL never owns process entry: `App.run` is a plain event
loop that drains pending events through `event` and then calls `iterate`, the
same dispatch order as SDL's own callback runner.

Call `App.run` from `main` (Lean's `main` runs on the OS main thread, which
video, event, and render APIs require). Never call it from a `Task`.

The loop is unthrottled: `iterate` runs as fast as events allow. Pace frames
with renderer vsync (`Renderer.setVSync 1`) or an explicit delay, mirroring
what the official examples rely on (`SDL_HINT_MAIN_CALLBACK_RATE` has no
effect here because SDL is not running the callbacks).

The state type `σ` plays the role of `SDL_AppInit`'s `appstate` out-pointer;
apps that need mutation store `IO.Ref`s in it.
-/

namespace Sdl

/-- A callback-style SDL application over app state `σ`, mirroring
`SDL_AppInit`/`SDL_AppEvent`/`SDL_AppIterate`/`SDL_AppQuit`. Returning
`.success` or `.failure` from `event` or `iterate` ends the loop; `quit` then
runs exactly once with that result. Only `init` has no default. -/
structure App (σ : Type) where
  /-- Create the app state. Return `(.continue, some state)` to enter the
  loop; any other result ends the run immediately (with `quit` called iff a
  state was produced). C: `SDL_AppInit`. -/
  init : List String → IO (AppResult × Option σ)
  /-- Handle one event. Called for every pending event before each `iterate`,
  in queue order. Handle `Event.quit` here (return `.success`) if the app
  should exit when its window closes — there is no implicit quit handling.
  C: `SDL_AppEvent`. -/
  event : σ → Event → IO AppResult := fun _ _ => return .continue
  /-- One frame of work. Called once per loop pass after the event queue has
  drained. C: `SDL_AppIterate`. -/
  iterate : σ → IO AppResult := fun _ => return .continue
  /-- Cleanup, called exactly once with the final result — including when
  `init` itself returned a terminal result alongside a state, and when
  `event`/`iterate` raised an exception (result `.failure`, exception then
  propagates). C: `SDL_AppQuit`. -/
  quit : σ → AppResult → IO Unit := fun _ _ => return ()

namespace App

/-- Process exit code for a final `AppResult`: `.success` ↦ 0, everything
else ↦ 1 (matches SDL's callback runner). -/
def exitCode : AppResult → UInt32
  | .success => 0
  | _ => 1

#guard exitCode .success == 0
#guard exitCode .failure == 1
#guard exitCode .«continue» == 1

/-- Run the app to completion and return its process exit code: initialize,
then alternate draining the event queue (through `event`) with `iterate`
until either returns a terminal result, then `quit`.

Must be called on the main thread (call it from `main`). If `init` returns
`.continue` without a state, the run is treated as `.failure` (nothing to
loop over, nothing to clean up). C: `SDL_EnterAppMainCallbacks`. -/
partial def run (app : App σ) (args : List String := []) : IO UInt32 := do
  let (r, state?) ← app.init args
  match state? with
  | none =>
    -- No state ⇒ nothing to quit. `.continue` here is a contract violation.
    return exitCode (if r == .«continue» then .failure else r)
  | some s =>
    if r != .«continue» then
      app.quit s r
      return exitCode r
    let result ←
      try
        loop s
      catch e =>
        app.quit s .failure
        throw e
    app.quit s result
    return exitCode result
where
  /-- Dispatch pending events until the queue is empty or a handler ends the
  loop. -/
  drain (s : σ) : IO AppResult := do
    match (← pollEvent) with
    | none => return .«continue»
    | some e =>
      let r ← app.event s e
      if r == .«continue» then drain s else return r
  loop (s : σ) : IO AppResult := do
    let r ← drain s
    if r != .«continue» then return r
    let r ← app.iterate s
    if r != .«continue» then return r
    loop s

end App

end Sdl
