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
