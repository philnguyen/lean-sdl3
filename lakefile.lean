import Lake
open Lake DSL System

/-- Run a process, returning trimmed stdout on success; `none` if it fails or
the executable is missing. -/
def tryCmd (cmd : String) (args : Array String) : IO (Option String) := do
  try
    let out ← IO.Process.output { cmd, args }
    return if out.exitCode == 0 then some out.stdout.trimAscii.toString else none
  catch _ => return none

def sdl3NotFoundMsg : String :=
  "SDL3 development files not found.\n\
   \n\
   To install on macOS:   brew install sdl3\n\
   On other systems, install SDL3 >= 3.2 so that either `pkg-config sdl3`\n\
   works or headers live under a standard prefix (/opt/homebrew, /usr/local,\n\
   /usr).\n\
   \n\
   Searched: pkg-config sdl3, `brew --prefix sdl3`, /opt/homebrew, /usr/local, /usr."

/-- Locate SDL3 headers at build time: pkg-config → Homebrew → standard
prefixes → actionable error. Returns compiler include args. -/
def findSdl3IncludeArgs : IO (Array String) := do
  if let some cflags ← tryCmd "pkg-config" #["--cflags", "sdl3"] then
    return cflags.splitOn " " |>.filter (· ≠ "") |>.toArray
  let candidates ← do
    let mut cs := #[]
    if let some p ← tryCmd "brew" #["--prefix", "sdl3"] then
      cs := cs.push p
    pure (cs ++ #["/opt/homebrew", "/usr/local", "/usr"])
  for p in candidates do
    if ← (FilePath.mk p / "include" / "SDL3" / "SDL.h").pathExists then
      return #["-I", p ++ "/include"]
  throw <| IO.userError sdl3NotFoundMsg

package sdl where
  -- Link flags are a static field, so the Homebrew prefix is hardcoded here;
  -- header detection (above) is dynamic. Portability follow-up: a
  -- buildSharedLib shim that bakes in the detected rpath.
  moreLinkArgs := #["-L/opt/homebrew/lib", "-lSDL3", "-Wl,-rpath,/opt/homebrew/lib"]

@[default_target]
lean_lib Sdl where
  -- Properties' `initialize` block registers external classes by calling an FFI
  -- shim; the interpreter must be able to resolve that symbol when it runs the
  -- initializer at import time, so the library's native code (with the linked
  -- `sdlShim`) is precompiled and loaded rather than interpreted.
  precompileModules := true

/-- Compile every `ffi/*.c` shim into one static archive; Lake auto-links it
into all executables. Header changes retrigger via `extraDepTrace`. -/
extern_lib sdlShim pkg := do
  let sdlInclude ← findSdl3IncludeArgs
  let leanInclude := (← getLeanIncludeDir).toString
  let shimDir := pkg.dir / "ffi"
  let entries ← shimDir.readDir
  let paths := (entries.map (·.path)).qsort (toString · < toString ·)
  let srcs    := paths.filter (·.extension == some "c")
  let headers := paths.filter (·.extension == some "h")
  let oJobs ← srcs.mapM fun src => do
    let oFile := pkg.irDir / "ffi" / (src.fileStem.get! ++ ".o")
    let srcJob ← inputTextFile src
    buildO oFile srcJob (#["-I", leanInclude] ++ sdlInclude) #["-fPIC"] "cc"
      (extraDepTrace := do
        let mut t := BuildTrace.nil
        for h in headers do
          t := t.mix (← computeTrace (TextFilePath.mk h))
        return t)
  buildStaticLib (pkg.staticLibDir / nameToStaticLib "sdlShim") oJobs

@[default_target]
lean_exe sdl where
  root := `Main

-- Registers the `Tests.*` submodules (Harness + per-module test groups) so the
-- test exe below can import them; a bare `lean_exe` does not glob its srcDir.
lean_lib Tests where
  srcDir := "test"
  globs := #[.andSubmodules `Tests]

@[test_driver]
lean_exe test where
  srcDir := "test"
  root := `Tests

-- Provides the `Common` module (shared demo scaffolding) that every example
-- exe imports; the example root modules themselves belong to their exes.
lean_lib Examples where
  srcDir := "examples"
  roots := #[`Common]

/- Demos: Lean ports of the official SDL3 examples (examples.libsdl.org), one
`lean_exe` per example, named `<category>-<nn>-<name>` after the upstream
directory. Sources live at `examples/<Category>/<Name>.lean`. Smoke-run all of
them headless with `scripts/smoke-examples.sh`. -/

lean_exe «renderer-01-clear» where
  srcDir := "examples"
  root := `Renderer.Clear

lean_exe «renderer-02-primitives» where
  srcDir := "examples"
  root := `Renderer.Primitives

lean_exe «renderer-03-lines» where
  srcDir := "examples"
  root := `Renderer.Lines

lean_exe «renderer-04-points» where
  srcDir := "examples"
  root := `Renderer.Points

lean_exe «renderer-05-rectangles» where
  srcDir := "examples"
  root := `Renderer.Rectangles

lean_exe «renderer-06-textures» where
  srcDir := "examples"
  root := `Renderer.Textures

lean_exe «renderer-07-streaming-textures» where
  srcDir := "examples"
  root := `Renderer.StreamingTextures

lean_exe «renderer-08-rotating-textures» where
  srcDir := "examples"
  root := `Renderer.RotatingTextures

lean_exe «renderer-09-scaling-textures» where
  srcDir := "examples"
  root := `Renderer.ScalingTextures

lean_exe «renderer-10-geometry» where
  srcDir := "examples"
  root := `Renderer.Geometry

lean_exe «renderer-11-color-mods» where
  srcDir := "examples"
  root := `Renderer.ColorMods

lean_exe «renderer-14-viewport» where
  srcDir := "examples"
  root := `Renderer.Viewport

lean_exe «renderer-15-cliprect» where
  srcDir := "examples"
  root := `Renderer.ClipRect

lean_exe «renderer-17-read-pixels» where
  srcDir := "examples"
  root := `Renderer.ReadPixels

lean_exe «renderer-18-debug-text» where
  srcDir := "examples"
  root := `Renderer.DebugText

lean_exe «renderer-19-affine-textures» where
  srcDir := "examples"
  root := `Renderer.AffineTextures

lean_exe «renderer-20-blending» where
  srcDir := "examples"
  root := `Renderer.Blending

lean_exe «misc-01-power» where
  srcDir := "examples"
  root := `Misc.Power

lean_exe «misc-02-clipboard» where
  srcDir := "examples"
  root := `Misc.Clipboard

lean_exe «misc-03-locale» where
  srcDir := "examples"
  root := `Misc.Locale

lean_exe «audio-01-simple-playback» where
  srcDir := "examples"
  root := `Audio.SimplePlayback

lean_exe «audio-02-simple-playback-callback» where
  srcDir := "examples"
  root := `Audio.SimplePlaybackCallback

lean_exe «audio-03-load-wav» where
  srcDir := "examples"
  root := `Audio.LoadWav

lean_exe «audio-04-multiple-streams» where
  srcDir := "examples"
  root := `Audio.MultipleStreams

lean_exe «audio-05-planar-data» where
  srcDir := "examples"
  root := `Audio.PlanarData

lean_exe «input-01-joystick-polling» where
  srcDir := "examples"
  root := `Input.JoystickPolling

lean_exe «input-02-joystick-events» where
  srcDir := "examples"
  root := `Input.JoystickEvents

lean_exe «input-03-gamepad-polling» where
  srcDir := "examples"
  root := `Input.GamepadPolling

lean_exe «input-04-gamepad-events» where
  srcDir := "examples"
  root := `Input.GamepadEvents

lean_exe «input-05-gamepad-rumble» where
  srcDir := "examples"
  root := `Input.GamepadRumble

lean_exe «demo-01-snake» where
  srcDir := "examples"
  root := `Demo.Snake
