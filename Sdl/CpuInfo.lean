import Sdl.Core.Macros
import Sdl.Error

/-!
# CPU feature detection (`SDL_cpuinfo.h`)

Trivial getters: core/cache/RAM/page/alignment queries and the fourteen
`SDL_Has*` SIMD instruction-set checks. The `SDL_Has*` checks are available on
every platform and simply return `false` where they don't apply.
-/

namespace Sdl

/-- Number of logical CPU cores (may exceed physical cores with
hyperthreading). C: `SDL_GetNumLogicalCPUCores`. -/
@[extern "lean_sdl_get_num_logical_cpu_cores"]
opaque getNumLogicalCPUCores : IO Int32

/-- L1 cache line size in bytes. C: `SDL_GetCPUCacheLineSize`. -/
@[extern "lean_sdl_get_cpu_cache_line_size"]
opaque getCPUCacheLineSize : IO Int32

/-- Whether the CPU has AltiVec features. C: `SDL_HasAltiVec`. -/
@[extern "lean_sdl_has_altivec"]
opaque hasAltiVec : IO Bool

/-- Whether the CPU has MMX features. C: `SDL_HasMMX`. -/
@[extern "lean_sdl_has_mmx"]
opaque hasMMX : IO Bool

/-- Whether the CPU has SSE features. C: `SDL_HasSSE`. -/
@[extern "lean_sdl_has_sse"]
opaque hasSSE : IO Bool

/-- Whether the CPU has SSE2 features. C: `SDL_HasSSE2`. -/
@[extern "lean_sdl_has_sse2"]
opaque hasSSE2 : IO Bool

/-- Whether the CPU has SSE3 features. C: `SDL_HasSSE3`. -/
@[extern "lean_sdl_has_sse3"]
opaque hasSSE3 : IO Bool

/-- Whether the CPU has SSE4.1 features. C: `SDL_HasSSE41`. -/
@[extern "lean_sdl_has_sse41"]
opaque hasSSE41 : IO Bool

/-- Whether the CPU has SSE4.2 features. C: `SDL_HasSSE42`. -/
@[extern "lean_sdl_has_sse42"]
opaque hasSSE42 : IO Bool

/-- Whether the CPU has AVX features. C: `SDL_HasAVX`. -/
@[extern "lean_sdl_has_avx"]
opaque hasAVX : IO Bool

/-- Whether the CPU has AVX2 features. C: `SDL_HasAVX2`. -/
@[extern "lean_sdl_has_avx2"]
opaque hasAVX2 : IO Bool

/-- Whether the CPU has AVX-512F features. C: `SDL_HasAVX512F`. -/
@[extern "lean_sdl_has_avx512f"]
opaque hasAVX512F : IO Bool

/-- Whether the CPU has ARM SIMD (ARMv6) features. C: `SDL_HasARMSIMD`. -/
@[extern "lean_sdl_has_armsimd"]
opaque hasARMSIMD : IO Bool

/-- Whether the CPU has NEON (ARM SIMD) features. C: `SDL_HasNEON`. -/
@[extern "lean_sdl_has_neon"]
opaque hasNEON : IO Bool

/-- Whether the CPU has LSX (LoongArch SIMD) features. C: `SDL_HasLSX`. -/
@[extern "lean_sdl_has_lsx"]
opaque hasLSX : IO Bool

/-- Whether the CPU has LASX (LoongArch SIMD) features. C: `SDL_HasLASX`. -/
@[extern "lean_sdl_has_lasx"]
opaque hasLASX : IO Bool

/-- Amount of system RAM in MiB. C: `SDL_GetSystemRAM`. -/
@[extern "lean_sdl_get_system_ram"]
opaque getSystemRAM : IO Int32

/-- Byte alignment required for SIMD allocations on this machine.
C: `SDL_GetSIMDAlignment`. -/
@[extern "lean_sdl_get_simd_alignment"]
opaque getSIMDAlignment : IO USize

/-- Size of a memory page in bytes, or 0 if SDL can't determine it (no error is
set in that case). C: `SDL_GetSystemPageSize`. -/
@[extern "lean_sdl_get_system_page_size"]
opaque getSystemPageSize : IO Int32

end Sdl
