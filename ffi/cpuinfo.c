/* Shims for Sdl/CpuInfo.lean (SDL_cpuinfo.h). Trivial getters. */
#include "util.h"

/* Boolean SDL_Has* check -> IO Bool */
#define SDL_HAS_SHIM(sym, call)                                          \
    LEAN_EXPORT lean_obj_res sym(lean_obj_arg w) {                       \
        (void)w;                                                         \
        SDL_SHIM_PROLOGUE();                                             \
        return lean_io_result_mk_ok(lean_box(call()));                  \
    }

/* Sdl.getNumLogicalCPUCores : IO Int32 -- C: SDL_GetNumLogicalCPUCores */
LEAN_EXPORT lean_obj_res lean_sdl_get_num_logical_cpu_cores(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetNumLogicalCPUCores()));
}

/* Sdl.getCPUCacheLineSize : IO Int32 -- C: SDL_GetCPUCacheLineSize */
LEAN_EXPORT lean_obj_res lean_sdl_get_cpu_cache_line_size(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetCPUCacheLineSize()));
}

SDL_HAS_SHIM(lean_sdl_has_altivec, SDL_HasAltiVec)   /* C: SDL_HasAltiVec */
SDL_HAS_SHIM(lean_sdl_has_mmx,     SDL_HasMMX)       /* C: SDL_HasMMX */
SDL_HAS_SHIM(lean_sdl_has_sse,     SDL_HasSSE)       /* C: SDL_HasSSE */
SDL_HAS_SHIM(lean_sdl_has_sse2,    SDL_HasSSE2)      /* C: SDL_HasSSE2 */
SDL_HAS_SHIM(lean_sdl_has_sse3,    SDL_HasSSE3)      /* C: SDL_HasSSE3 */
SDL_HAS_SHIM(lean_sdl_has_sse41,   SDL_HasSSE41)     /* C: SDL_HasSSE41 */
SDL_HAS_SHIM(lean_sdl_has_sse42,   SDL_HasSSE42)     /* C: SDL_HasSSE42 */
SDL_HAS_SHIM(lean_sdl_has_avx,     SDL_HasAVX)       /* C: SDL_HasAVX */
SDL_HAS_SHIM(lean_sdl_has_avx2,    SDL_HasAVX2)      /* C: SDL_HasAVX2 */
SDL_HAS_SHIM(lean_sdl_has_avx512f, SDL_HasAVX512F)   /* C: SDL_HasAVX512F */
SDL_HAS_SHIM(lean_sdl_has_armsimd, SDL_HasARMSIMD)   /* C: SDL_HasARMSIMD */
SDL_HAS_SHIM(lean_sdl_has_neon,    SDL_HasNEON)      /* C: SDL_HasNEON */
SDL_HAS_SHIM(lean_sdl_has_lsx,     SDL_HasLSX)       /* C: SDL_HasLSX */
SDL_HAS_SHIM(lean_sdl_has_lasx,    SDL_HasLASX)      /* C: SDL_HasLASX */

/* Sdl.getSystemRAM : IO Int32 -- C: SDL_GetSystemRAM (MiB) */
LEAN_EXPORT lean_obj_res lean_sdl_get_system_ram(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetSystemRAM()));
}

/* Sdl.getSIMDAlignment : IO USize -- C: SDL_GetSIMDAlignment */
LEAN_EXPORT lean_obj_res lean_sdl_get_simd_alignment(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_usize(SDL_GetSIMDAlignment()));
}

/* Sdl.getSystemPageSize : IO Int32 -- C: SDL_GetSystemPageSize */
LEAN_EXPORT lean_obj_res lean_sdl_get_system_page_size(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetSystemPageSize()));
}
