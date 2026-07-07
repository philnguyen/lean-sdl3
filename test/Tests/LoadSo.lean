import Sdl
import Tests.Harness

/-!
# Shared-object loading runtime tests

No `Sdl.init` needed. Loads the linked SDL3 dylib from the standard Homebrew
path (the same path CI installs) and checks symbol existence.
-/

namespace Tests.LoadSo
open Sdl Tests.Harness

def run : IO Unit := do
  let so ← loadObject "/opt/homebrew/lib/libSDL3.dylib"
  check "hasFunction SDL_GetVersion" (← so.hasFunction "SDL_GetVersion")
  check "hasFunction bogus symbol == false"
    (!(← so.hasFunction "SDL_ThisSymbolDoesNotExist_xyz"))
  checkThrows "loadObject of a bogus path throws"
    (loadObject "/nonexistent/definitely-not-a-lib.dylib")
  so.unload
  checkThrows "hasFunction after unload throws" (so.hasFunction "SDL_GetVersion")

end Tests.LoadSo
