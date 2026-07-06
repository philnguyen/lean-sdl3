/* Cross-module event decode.
 *
 * lean_sdl_decode_event (defined in ffi/events.c) turns an SDL_Event into an
 * owned `Sdl.Event` Lean object via the @[export]ed makers — total, never
 * fails. Shared here so callback trampolines that receive an SDL_Event*
 * outside events.c (none today; the event watch/filter trampolines live in
 * events.c itself) and future modules can decode without duplicating the
 * switch. Callers on SDL-owned threads must run lean_sdl_ensure_thread()
 * first: decoding allocates Lean objects. */
#pragma once
#include "util.h"

#ifdef __cplusplus
extern "C" {
#endif

lean_object *lean_sdl_decode_event(const SDL_Event *e);

#ifdef __cplusplus
}
#endif
