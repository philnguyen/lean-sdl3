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

/* ---- Sdl/Properties.lean: PropertyType ---- */
_Static_assert((int)SDL_PROPERTY_TYPE_INVALID == 0, "PropertyType.invalid");
_Static_assert((int)SDL_PROPERTY_TYPE_POINTER == 1, "PropertyType.pointer");
_Static_assert((int)SDL_PROPERTY_TYPE_STRING  == 2, "PropertyType.string");
_Static_assert((int)SDL_PROPERTY_TYPE_NUMBER  == 3, "PropertyType.number");
_Static_assert((int)SDL_PROPERTY_TYPE_FLOAT   == 4, "PropertyType.float");
_Static_assert((int)SDL_PROPERTY_TYPE_BOOLEAN == 5, "PropertyType.boolean");

/* ---- Sdl/Hints.lean: HintPriority ---- */
_Static_assert((int)SDL_HINT_DEFAULT  == 0, "HintPriority.default");
_Static_assert((int)SDL_HINT_NORMAL   == 1, "HintPriority.normal");
_Static_assert((int)SDL_HINT_OVERRIDE == 2, "HintPriority.override");

/* ---- Sdl/Log.lean: LogCategory (named constants) ---- */
_Static_assert((int)SDL_LOG_CATEGORY_APPLICATION == 0,  "LogCategory.application");
_Static_assert((int)SDL_LOG_CATEGORY_ERROR       == 1,  "LogCategory.error");
_Static_assert((int)SDL_LOG_CATEGORY_ASSERT      == 2,  "LogCategory.assert");
_Static_assert((int)SDL_LOG_CATEGORY_SYSTEM      == 3,  "LogCategory.system");
_Static_assert((int)SDL_LOG_CATEGORY_AUDIO       == 4,  "LogCategory.audio");
_Static_assert((int)SDL_LOG_CATEGORY_VIDEO       == 5,  "LogCategory.video");
_Static_assert((int)SDL_LOG_CATEGORY_RENDER      == 6,  "LogCategory.render");
_Static_assert((int)SDL_LOG_CATEGORY_INPUT       == 7,  "LogCategory.input");
_Static_assert((int)SDL_LOG_CATEGORY_TEST        == 8,  "LogCategory.test");
_Static_assert((int)SDL_LOG_CATEGORY_GPU         == 9,  "LogCategory.gpu");
_Static_assert((int)SDL_LOG_CATEGORY_CUSTOM      == 19, "LogCategory.custom");

/* ---- Sdl/Log.lean: LogPriority ---- */
_Static_assert((int)SDL_LOG_PRIORITY_INVALID  == 0, "LogPriority.invalid");
_Static_assert((int)SDL_LOG_PRIORITY_TRACE    == 1, "LogPriority.trace");
_Static_assert((int)SDL_LOG_PRIORITY_VERBOSE  == 2, "LogPriority.verbose");
_Static_assert((int)SDL_LOG_PRIORITY_DEBUG    == 3, "LogPriority.debug");
_Static_assert((int)SDL_LOG_PRIORITY_INFO     == 4, "LogPriority.info");
_Static_assert((int)SDL_LOG_PRIORITY_WARN     == 5, "LogPriority.warn");
_Static_assert((int)SDL_LOG_PRIORITY_ERROR    == 6, "LogPriority.error");
_Static_assert((int)SDL_LOG_PRIORITY_CRITICAL == 7, "LogPriority.critical");
