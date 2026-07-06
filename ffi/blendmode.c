/* Shims for Sdl/BlendMode.lean (SDL_blendmode.h). */
#include "util.h"

/* Sdl.composeCustomBlendModeRaw (6 UInt32s) : UInt32
 * -- C: SDL_ComposeCustomBlendMode (pure bit packing: no SDL state, no
 * errors; no world argument, the uint32 is returned directly). */
LEAN_EXPORT uint32_t lean_sdl_compose_custom_blend_mode(
        uint32_t src_color_factor, uint32_t dst_color_factor, uint32_t color_operation,
        uint32_t src_alpha_factor, uint32_t dst_alpha_factor, uint32_t alpha_operation) {
    SDL_SHIM_PROLOGUE();
    return (uint32_t)SDL_ComposeCustomBlendMode(
        (SDL_BlendFactor)src_color_factor, (SDL_BlendFactor)dst_color_factor,
        (SDL_BlendOperation)color_operation,
        (SDL_BlendFactor)src_alpha_factor, (SDL_BlendFactor)dst_alpha_factor,
        (SDL_BlendOperation)alpha_operation);
}
