import Sdl

/-!
# Shared demo scaffolding

Helpers used by every demo under `examples/`:
- `Examples.assetPath` resolves a vendored asset under `examples/assets/`.
- `Examples.runApp` runs an `Sdl.App`, honoring the `SDL_LEAN_MAX_FRAMES`
  environment variable so demos can be smoke-run headless:
  `SDL_VIDEO_DRIVER=dummy SDL_AUDIO_DRIVER=dummy SDL_LEAN_MAX_FRAMES=60
  lake exe renderer-01-clear` (see `scripts/smoke-examples.sh`).

Demos deliberately do not call `Sdl.quit`: window/renderer externals may still
be alive when `main` returns, and their finalizers must not run after the
video subsystem is gone. The OS reclaims everything at process exit (same
policy as `test/`).
-/

namespace Examples

/-- π as `Float`. The C examples use `SDL_PI_D`/`SDL_PI_F`; Lean core has no
`Float.pi`, and binding SDL's stdinc math is out of scope by design. -/
def pi : Float := 3.141592653589793

/-- Directory holding the vendored demo assets (zlib-licensed files copied
from the SDL repository's `test/` directory — see `examples/assets/README.md`). -/
def assetsDir : System.FilePath := System.FilePath.mk "examples" / "assets"

/-- The on-disk path of a vendored asset, with an actionable error if it is
missing (e.g. when not run from the repository root). -/
def assetPath (name : String) : IO System.FilePath := do
  let p := assetsDir / name
  unless (← p.pathExists) do
    throw <| IO.userError s!"asset not found: {p}\n\
      Run demos from the repository root, e.g. `lake exe renderer-06-textures`."
  return p

/-- Run `app`, capping the number of `iterate` calls at `SDL_LEAN_MAX_FRAMES`
(when that variable holds a number) by returning `.success` once the cap is
reached. Lets CI smoke-run demos that would otherwise loop until the window
closes. Event-driven demos still terminate: the cap counts loop turns, and
`Sdl.App.run` calls `iterate` on every turn. -/
def runApp (app : Sdl.App σ) (args : List String := []) : IO UInt32 := do
  match (← IO.getEnv "SDL_LEAN_MAX_FRAMES").bind (·.toNat?) with
  | none => app.run args
  | some cap =>
    let frames ← IO.mkRef 0
    let capped := { app with
      iterate := fun s => do
        if (← frames.get) ≥ cap then return .success
        frames.modify (· + 1)
        app.iterate s }
    capped.run args

end Examples
