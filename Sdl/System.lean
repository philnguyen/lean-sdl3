import Sdl.Core.Macros
import Sdl.Error

/-!
# Platform-specific system functions (`SDL_system.h`)

Only the cross-platform, macOS-relevant subset is bound here:
`isTablet`, `isTV`, and `getSandbox`.

Skipped (documented plan-level omissions):
* All Windows-specific (`SDL_SetWindowsMessageHook`, D3D device index queries,
  …), X11 (`SDL_SetX11EventHook`), Linux (`SDL_SetLinuxThreadPriority`, …), iOS
  (`SDL_SetiOSAnimationCallback`, `SDL_SetiOSEventPump`), Android
  (`SDL_GetAndroidJNIEnv`, `SDL_GetAndroidActivity`, storage/permission helpers,
  …), and GDK (`SDL_GetGDKTaskQueue`, `SDL_GetGDKDefaultUser`) functions — not
  applicable on macOS.
* The `SDL_OnApplicationDidChangeStatusBarOrientation` / `SDL_OnApplication*`
  lifecycle handlers — only for apps that own the OS event loop, which this
  binding's apps do not.
-/

namespace Sdl

/-- The application sandbox environment. Version-open (`sdl_enum_open`): new
container kinds can appear in future SDL releases. C: `SDL_Sandbox`. -/
sdl_enum_open Sandbox : UInt32 where
  | none             => 0  -- C: SDL_SANDBOX_NONE
  | unknownContainer => 1  -- C: SDL_SANDBOX_UNKNOWN_CONTAINER
  | flatpak          => 2  -- C: SDL_SANDBOX_FLATPAK
  | snap             => 3  -- C: SDL_SANDBOX_SNAP
  | macos            => 4  -- C: SDL_SANDBOX_MACOS

/-- Whether the current device is a tablet. Returns `false` if SDL cannot
determine this. C: `SDL_IsTablet`. -/
@[extern "lean_sdl_is_tablet"]
opaque isTablet : IO Bool

/-- Whether the current device is a TV. Returns `false` if SDL cannot determine
this. C: `SDL_IsTV`. -/
@[extern "lean_sdl_is_tv"]
opaque isTV : IO Bool

@[extern "lean_sdl_get_sandbox"]
private opaque getSandboxRaw : IO UInt32

/-- The application sandbox environment, or `.none` if not sandboxed.
C: `SDL_GetSandbox`. -/
def getSandbox : IO Sandbox := do
  return Sandbox.ofVal (← getSandboxRaw)

end Sdl
