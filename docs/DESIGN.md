# lean-sdl3 binding architecture

Settled design for the SDL3 FFI. Read together with `AGENTS.md` (naming and
testing conventions). Implementation subagents: follow this document exactly;
deviations require orchestrator sign-off.

Facts this design rests on (verified against Lean v4.31.0 + SDL 3.4.10):
- `@[extern]` IO functions receive a trailing world argument and must return
  `lean_io_result_*` — so **every IO binding goes through a C shim**; direct
  `@[extern "SDL_..."]` to an SDL symbol is never correct for IO.
- Scalars (`UInt8..64`, `USize`, `Bool`, `Char`, `Float`, `Float32`) pass
  **unboxed** across `@[extern]`/`@[export]`; `String`/structures/externals pass
  as `lean_object*`. `@&` parameters arrive borrowed (`b_lean_obj_arg`, do not
  dec); plain parameters are owned; returns are owned.
- `lean_initialize_thread`/`lean_finalize_thread` are exported by the runtime
  but **not declared in `lean.h`** — `ffi/util.h` forward-declares (guarded so a
  future toolchain that declares them doesn't conflict).
- External-class `foreach` does **not** provide finalization order; it only
  propagates `lean_mark_mt`/`lean_mark_persistent` into nested Lean objects.
  Destruction order comes from reference counting: a child holding an **owned**
  ref to its parent's external object keeps the parent finalizer from running
  first.
- Errors: fallible SDL calls return `false`/`NULL`; shims convert to an IO
  error carrying `SDL_GetError()` (`sdl_throw()` in `ffi/util.h`).

## Symbol & module conventions

- C shim symbols: `lean_sdl_<snake_case>` (e.g. `lean_sdl_create_window`).
  `@[export]`ed Lean makers: `lean_sdl_mk_<snake_case>` — the standard way for C
  to hand a multi-field Lean structure back to Lean (a private Lean def over
  flattened scalars/objects; the shim forward-declares and calls it, so the
  Lean compiler owns constructor layout). ABI note: Lean's generated C uses
  `uint32_t`/`uint64_t` even for `Int32`/`Int64` params; shim forward-decls may
  use the signed `intN_t` — identical width/registers, bits preserved.
- One Lean module per SDL header: `Sdl/<Name>.lean` + `ffi/<name>.c` mirror
  `SDL_<name>.h`. Shared machinery: `ffi/util.{h,c}`, `ffi/callbacks.{h,c}`,
  `ffi/consts_check.c`. External-class pointer globals that another module's
  shims need (e.g. surface.c wrapping a borrowed Properties or Palette) are
  declared in `ffi/classes.h` — never forward-declared locally.
- Lean naming (AGENTS.md): drop `SDL_`, lowerCamelCase functions, cite the
  exact C name in every binding's doc comment. Enum/flag members carry a
  `-- C: SDL_NAME` comment.
- Raw externs are `private … Raw` when a public wrapper packs/unpacks Lean
  structures (raw externs take flattened scalars; C never learns Lean struct
  layouts in either direction).

## Binding-kit macros (`Sdl/Core/Macros.lean`)

| Macro | Generates | Use for |
|---|---|---|
| `sdl_opaque X` | `private opaque XPointed : NonemptyType`, `def X`, `Nonempty X` | opaque C handles |
| `sdl_id X : UIntN where …` | 1-field structure + BEq/Hashable/Repr/Inhabited/DecidableEq + optional named constants | IDs; open numeric domains (Keycode, BlendMode) where exhaustiveness is impossible |
| `sdl_enum X : UIntN where \| a => 0 …` | genuine `inductive` + `val` + `ofVal?` + `#guard`s | closed C enums (exhaustive `match`) |
| `sdl_enum_open X : UIntN where …` | same + `\| other (raw)` ctor and total `ofVal` | version-open enums returned from C (e.g. PixelFormat) |
| `sdl_flags X : UIntN where \| f := 0x1 …` | 1-field structure + OrOp/AndOp/Xor/Complement + `none`/`has` + members + `#guard`s | bit flags |

All macros require a leading doc comment. FFI boundary always converts via
`val`/`ofVal?`/`ofVal` — never assume a Lean inductive tag equals the C value.
Every enum/flag block has a mirror `_Static_assert` block in
`ffi/consts_check.c` pinning the C side at build time.

## Ownership (`sdl_holder`)

```c
typedef struct { void *ptr; lean_object *owner; } sdl_holder;
```

Archetypes (decide per handle, record in the module's header comment):

| Archetype | Holder | Finalizer | Manual destroy? |
|---|---|---|---|
| Owned root | `{ptr, NULL}` | `SDL_Destroy*/Close*(ptr)` | Only child-free leaves (Cursor, Gamepad, …); **Window/Renderer/Camera are finalizer-only** |
| Owned child | `{ptr, parentExternal}` | destroy child, then `lean_dec(owner)` | Leaves yes (e.g. `Texture.destroy`) |
| Release-to-source | `{surface, cameraExternal}` | `SDL_ReleaseCameraFrame(owner->ptr, ptr)` | Yes (prompt release) |
| Borrowed | `{ptr, sourceExternal}` — same Lean type, **distinct class** | dec owner only | No; destroy shims throw on borrowed class |
| Consumable/typestate | `{ptr, deviceExternal}` | dec owner only | `submit`/`cancel` NULL the ptr |
| Copy-no-handle | — | — | e.g. KeyboardState = ByteArray snapshot |

Every shim uses `SDL_GET_OR_THROW` (NULL-guard) so post-destroy use is an IO
error, never UB. Manual destroy = destroy + `ptr = NULL` (+ dec/NULL owner).

Refcounted re-open (joystick/gamepad/sensor): SDL's `Open*` on an already-open
instance id returns the same pointer with an internal refcount bump, so
functions that hand back a borrowed pointer to an open device
(`SDL_Get*FromID`, `SDL_GetGamepadJoystick`) are bound by taking a **fresh
reference** (`SDL_Open*(id)`) and wrapping that as a new owned root — every
Lean handle owns its own reference and no borrowed class is needed. Haptic
lacks documented refcounting; its `getHapticFromID` carries a doc warning
instead.
External classes are registered from a per-module `initialize` block in the
Lean module (runs on the main thread at startup, deterministic). This requires
`precompileModules := true` on `lean_lib Sdl`: the initializer runs in the
interpreter at import time while *compiling* downstream modules, and only a
precompiled (natively linked) library can resolve the shim symbol then.

Caveat (documented, not enforced): don't let the *last* reference to a video
handle die inside a `Task` or SDL-thread callback — finalizers run on the
dropping thread and video destroys are main-thread-only. `SDL_RunOnMainThread`
is the escape hatch if this ever needs enforcement.

Caveat (documented, not enforced): when SDL holds a raw pointer to an object
without owning it (e.g. the texture bound via `SDL_SetRenderTarget`), the
binding does NOT add a hidden retain if doing so would create a reference
cycle (render target: texture already owns its renderer). Lean's eager RC
frees the object the moment the last visible reference dies — SDL then
destroys it and resets its own pointer, which is memory-safe but silently
undoes the binding-time state. Rule: such bindings document "keep your
reference alive while bound".

## Event decode

One C switch in `ffi/events.c` over `event->type` calls `@[export]`ed Lean
makers (one per C event-struct family, flattened unboxed scalars) — the Lean
compiler owns constructor layout. Type→constructor dispatch happens in the
pure Lean makers (`#guard`-testable). `Sdl.Event` has ~115 constructors (one
per `SDL_EventType`; families share payload structures), plus `.user (type) …`
and `.unknown (type) …` so decoding is total. String fields are copied eagerly
(`lean_mk_string`) — their C pointers die at the next poll.

Validation: `test/Events.lean` pushes synthetic events per family and compares
decoded fields; after the first build, diff the exported maker signatures in
`.lake/build/ir/Sdl/Events.c` against the prototypes block in `ffi/events.c`.

## Callbacks — three primitives (`ffi/callbacks.{h,c}`)

1. **Gen-key registry** (AddTimer, AddEventWatch, AddHintCallback;
   SetAudioPostmixCallback with aux = device id, dropped on close): userdata is
   a non-pointer monotone `uint64` key into a mutex-guarded list of
   `{key, fn(owned, lean_mark_mt'd), aux}`. Register into the map **before**
   the SDL add-call (timer callbacks can fire before `SDL_AddTimer` returns).
   Trampoline: `sdl_ensure_lean_thread()` → find+`lean_inc` under mutex →
   `lean_apply_N(fn, …, lean_box(0))`. Remove: take-under-mutex → SDL remove →
   `lean_dec`. Nothing freeable is ever userdata; at most one trailing
   invocation after remove (same as SDL's own semantics).
2. **Locked slot** (audio stream callbacks; global log output): closure lives
   in the owner's external data (static slot for log); replace under
   `SDL_LockAudioStream` (SDL holds it during callbacks) or a dedicated mutex;
   dec the old closure after unlock. Stream finalizer destroys the stream
   first, then decs closures. Trampolines pass a **borrowed** handle to avoid
   RC cycles.
3. **One-shot** (dialog callbacks): the owned mt-marked closure IS the
   userdata (inside a small heap context when SDL also needs auxiliary data,
   e.g. strdup'd dialog filters); `lean_apply` consumes it, the trampoline
   frees the context. Variant with SDL-managed lifetime (clipboard data
   provider): SDL's cleanup callback frees the context instead, firing exactly
   once on replace/clear/quit.

Property-stored variant of #2 for per-window callbacks (hit test): the owned
mt-marked closure rides the window's own SDL properties under a `lean_sdl.*`
key via `SDL_SetPointerPropertyWithCleanup` with a `lean_dec` cleanup — SDL
guarantees exactly one release on overwrite, clear, or window destruction, so
no registry entry can outlive its window. The trampoline passes the window to
the closure so user code need not capture it (capturing would cycle:
window → properties → closure → window).

Synchronous callbacks that only run inside one of our shim calls
(`SDL_FilterEvents`, property/directory enumeration) skip the machinery: the
closure pointer itself is the userdata, borrowed for the duration of the call
(`lean_inc` before each consuming `lean_apply`).

Thread rule: every trampoline that may run on an SDL thread starts with
`sdl_ensure_lean_thread()`; every shim entry runs `SDL_SHIM_PROLOGUE()` so
synchronous callbacks on Lean threads never double-init. `lean_finalize_thread`
is never called (SDL threads are long-lived; bounded TLS leak).

## Threading / main loop

Lean's generated entry point hands the program to `lean_run_main`, which by
default runs `main` on a **spawned thread** (for stack-size control) — macOS's
cocoa driver then reports "No available video device" (AppKit requires the
process's primary thread; the dummy driver doesn't care, so headless tests
pass regardless). `ffi/util.c` therefore sets `LEAN_MAIN_USE_THREAD=0` from an
`__attribute__((constructor))` — image-load constructors run on the primary
thread before `main`, and an explicit value in the environment is not
overwritten — so `lean_run_main` calls `main` directly on the OS main thread.
Cost: the OS-default main stack (8 MiB) instead of Lean's configurable thread
stack; add `-Wl,-stack_size,…` to `moreLinkArgs` if that ever bites.
`test/Tests/App.lean` asserts `Sdl.isMainThread` so a toolchain that stops
honoring the variable fails CI.

With that in place, `SDL_Init`, window creation, event pump, and all rendering
stay on the main thread. Never call video/render APIs from `Task`/`IO.asTask`. Examples use `Sdl.App` (init/event/iterate/quit record,
mirroring the official examples' `SDL_MAIN_USE_CALLBACKS` shape) driven by
`App.run` from `main`. Headless verification: `SDL_VIDEO_DRIVER=dummy
SDL_AUDIO_DRIVER=dummy`, frame cap via `SDL_LEAN_MAX_FRAMES` env var
(`examples/Common.lean`).

## Build (`lakefile.lean`)

`findSdl3IncludeArgs` detects SDL3 at build time (pkg-config → `brew --prefix
sdl3` → standard prefixes) and fails with an actionable install message.
`extern_lib sdlShim` compiles every `ffi/*.c` (`buildO`, system `cc`; include
paths are weak args, semantic flags are trace args; `ffi/*.h` hashed via
`extraDepTrace`) into a static archive that Lake auto-links into every
executable. Link flags (`-lSDL3` + rpath) are in `package … moreLinkArgs`
(hardcoded Homebrew prefix — portability follow-up: `buildSharedLib` variant).
