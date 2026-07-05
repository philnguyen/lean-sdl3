/-!
# Error handling (`SDL_error.h`)

Convention: fallible SDL calls return `false`/`NULL` in C; the shims convert
that into an `IO` error carrying `SDL_GetError()`, so Lean code just uses `IO`
exceptions and rarely needs the functions below directly.
-/

namespace Sdl

/-- Message describing the last error on this thread, or `""` if none.
Bindings surface failures as `IO` errors already carrying this message.
C: `SDL_GetError`. -/
@[extern "lean_sdl_get_error"]
opaque getError : IO String

/-- Clear this thread's error message. C: `SDL_ClearError`. -/
@[extern "lean_sdl_clear_error"]
opaque clearError : IO Unit

/-- Set the per-thread error message. C: `SDL_SetError` (fixed-string variant;
the C varargs formatting is not bound). -/
@[extern "lean_sdl_set_error"]
opaque setError (message : @& String) : IO Unit

end Sdl
