import Sdl.Core.Macros
import Sdl.Error

/-!
# Shared object loading (`SDL_loadso.h`)

Load a system shared library (`.dylib`/`.so`/`.dll`) at runtime and check for
exported C symbols.

**Partial binding by design:** Lean cannot call an arbitrary C function pointer,
so `SDL_LoadFunction` is exposed only as an *existence check* (`hasFunction`) —
there is no way to hand the resolved pointer back to Lean usefully.

## Ownership

`SharedObject` is an **owned root**: the finalizer (and the manual `unload`) run
`SDL_UnloadObject`.
-/

namespace Sdl

/-- A loaded shared object (dynamic library). C: `SDL_SharedObject`. -/
sdl_opaque SharedObject

@[extern "lean_sdl_loadso_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

/-- Dynamically load a shared object by a system-dependent name. On macOS a bare
library name is not searched for on the dyld path — pass a full path such as
`/opt/homebrew/lib/libSDL3.dylib`. Throws if it cannot be loaded.
C: `SDL_LoadObject`. -/
@[extern "lean_sdl_load_object"]
opaque loadObject (sofile : @& String) : IO SharedObject

namespace SharedObject

/-- Whether the object exports a C function with the given `name`. (`true` iff
`SDL_LoadFunction` returns a non-NULL pointer — the pointer itself is not
representable in Lean, so only its existence is reported.)
C: `SDL_LoadFunction`. -/
@[extern "lean_sdl_has_function"]
opaque hasFunction (self : @& SharedObject) (name : @& String) : IO Bool

/-- Unload the shared object; any function looked up in it becomes invalid. The
handle must not be used afterwards. C: `SDL_UnloadObject`. -/
@[extern "lean_sdl_unload_object"]
opaque unload (self : @& SharedObject) : IO Unit

end SharedObject
end Sdl
