import Sdl
import Tests.Harness

namespace Tests.CpuInfo
open Sdl Tests.Harness

/-- Sanity bounds on the numeric getters plus a crash-check calling every
`has*` SIMD probe once. -/
def run : IO Unit := do
  check "cores >= 1" ((← Sdl.getNumLogicalCPUCores) >= 1)
  check "cacheLineSize > 0" ((← Sdl.getCPUCacheLineSize) > 0)
  check "systemRAM > 0" ((← Sdl.getSystemRAM) > 0)
  check "simdAlignment >= 1" ((← Sdl.getSIMDAlignment) >= 1)
  -- getSystemPageSize may legitimately be 0 (SDL couldn't determine it)
  check "systemPageSize >= 0" ((← Sdl.getSystemPageSize) >= 0)
  -- call every SIMD probe once (must not crash)
  let _ ← Sdl.hasAltiVec
  let _ ← Sdl.hasMMX
  let _ ← Sdl.hasSSE
  let _ ← Sdl.hasSSE2
  let _ ← Sdl.hasSSE3
  let _ ← Sdl.hasSSE41
  let _ ← Sdl.hasSSE42
  let _ ← Sdl.hasAVX
  let _ ← Sdl.hasAVX2
  let _ ← Sdl.hasAVX512F
  let _ ← Sdl.hasARMSIMD
  let _ ← Sdl.hasNEON
  let _ ← Sdl.hasLSX
  let _ ← Sdl.hasLASX
  check "has* probes did not crash" true
  -- any Mac (Intel or Apple Silicon) has at least one of SSE / NEON
  check "hasNEON or hasSSE" ((← Sdl.hasNEON) || (← Sdl.hasSSE))

end Tests.CpuInfo
