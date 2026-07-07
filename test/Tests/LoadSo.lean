import Sdl
import Tests.Harness

/-!
# Shared-object loading runtime tests

No `Sdl.init` needed. Probes the standard install locations for the SDL3
shared library (Homebrew on macOS, distro/multiarch paths on Linux) and checks
symbol existence; the symbol checks are skipped when none is found. The
failure-path checks run everywhere.
-/

namespace Tests.LoadSo
open Sdl Tests.Harness

/-- Standard SDL3 shared-library locations, per platform/distro. -/
def sdlLibCandidates : List String := [
  "/opt/homebrew/lib/libSDL3.dylib",         -- macOS arm64 Homebrew
  "/usr/local/lib/libSDL3.dylib",            -- macOS x86_64 Homebrew
  "/usr/local/lib/libSDL3.so.0",             -- Linux, source install
  "/usr/lib/x86_64-linux-gnu/libSDL3.so.0",  -- Debian/Ubuntu multiarch
  "/usr/lib/aarch64-linux-gnu/libSDL3.so.0",
  "/usr/lib64/libSDL3.so.0",                 -- Fedora
  "/usr/lib/libSDL3.so.0"]                   -- Arch

def run : IO Unit := do
  match ← sdlLibCandidates.findM? (fun p => System.FilePath.pathExists p : String → IO Bool) with
  | none =>
    check "no SDL3 library at a standard path — symbol checks skipped" true
  | some path =>
    let so ← loadObject path
    check "hasFunction SDL_GetVersion" (← so.hasFunction "SDL_GetVersion")
    check "hasFunction bogus symbol == false"
      (!(← so.hasFunction "SDL_ThisSymbolDoesNotExist_xyz"))
    so.unload
    checkThrows "hasFunction after unload throws" (so.hasFunction "SDL_GetVersion")
  checkThrows "loadObject of a bogus path throws"
    (loadObject "/nonexistent/definitely-not-a-lib.dylib")

end Tests.LoadSo
