/* Compile-time cross-checks: every value in a Lean `sdl_enum`/`sdl_flags`
 * block is pinned against the real SDL headers here. A wrong Lean literal
 * shows up as a build failure. Grouped by Lean module. */
#include <SDL3/SDL.h>

/* ---- ABI assumptions ---- */
_Static_assert(sizeof(SDL_Event) == 128, "SDL_Event ABI size");
_Static_assert(sizeof(bool) == 1, "bool size");

/* ---- Sdl/Init.lean: InitFlags ---- */
_Static_assert(SDL_INIT_AUDIO    == 0x00000010u, "InitFlags.audio");
_Static_assert(SDL_INIT_VIDEO    == 0x00000020u, "InitFlags.video");
_Static_assert(SDL_INIT_JOYSTICK == 0x00000200u, "InitFlags.joystick");
_Static_assert(SDL_INIT_HAPTIC   == 0x00001000u, "InitFlags.haptic");
_Static_assert(SDL_INIT_GAMEPAD  == 0x00002000u, "InitFlags.gamepad");
_Static_assert(SDL_INIT_EVENTS   == 0x00004000u, "InitFlags.events");
_Static_assert(SDL_INIT_SENSOR   == 0x00008000u, "InitFlags.sensor");
_Static_assert(SDL_INIT_CAMERA   == 0x00010000u, "InitFlags.camera");

/* ---- Sdl/Init.lean: AppResult ---- */
_Static_assert((int)SDL_APP_CONTINUE == 0, "AppResult.continue");
_Static_assert((int)SDL_APP_SUCCESS  == 1, "AppResult.success");
_Static_assert((int)SDL_APP_FAILURE  == 2, "AppResult.failure");
