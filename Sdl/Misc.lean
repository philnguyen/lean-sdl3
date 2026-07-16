module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros
public import Sdl.Error
public meta import Sdl.Error

public section

/-!
# Miscellaneous (`SDL_misc.h`)

The whole header: opening a URL in an external application.
-/

namespace Sdl

/-- Open a URL/URI in the system's default handler (browser, file manager, …).
Should be called on the main thread; success only means a handler was launched.
C: `SDL_OpenURL`. -/
@[extern "lean_sdl_open_url"]
opaque openURL (url : @& String) : IO Unit

end Sdl

end
