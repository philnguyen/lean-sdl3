# Demo assets

Files vendored from the [SDL repository](https://github.com/libsdl-org/SDL)'s
`test/` directory (tag `release-3.4.10`), used by the demos under `examples/`.

Like SDL itself they are distributed under the zlib license — a copy is
included here as [`LICENSE.txt`](LICENSE.txt).

| File | Used by |
|---|---|
| `sample.png` | renderer texture demos (06–09, 11, 19) |
| `gamepad_front.png` | input-03-gamepad-polling |
| `sample.wav` | audio-03-load-wav, audio-04-multiple-streams (a sample from Will Provost's *The Living Proof*, used with permission — see the upstream example's header) |
| `sword.wav` | audio-04-multiple-streams |

`hello.BytePusher` is not vendored: it is a locally generated
[BytePusher](https://esolangs.org/wiki/BytePusher) test ROM for
demo-04-bytepusher (a static gradient plus an idle loop). Regenerate it with
`python3 scripts/gen-bytepusher-rom.py` from the repository root.

## `gpu/` — SDL_gpu_examples assets

Files under `gpu/` are vendored from
[SDL_gpu_examples](https://github.com/TheSpydog/SDL_gpu_examples) (commit
`636f4ff`), the official SDL_GPU example suite that the `gpu-02` … `gpu-17`
demos port. They are distributed under the zlib license — a copy is included
as [`gpu/LICENSE.txt`](gpu/LICENSE.txt).

- `gpu/shaders/Source/*.hlsl` — the shader sources (readable reference for
  the resource bindings and vertex/uniform layouts each demo packs).
- `gpu/shaders/{SPIRV,MSL,DXIL}/` — the same shaders precompiled by
  [SDL_shadercross](https://github.com/libsdl-org/SDL_shadercross) for the
  Vulkan, Metal and D3D12 backends; `Examples.Gpu.loadShader` picks the one
  the device accepts at runtime. Only the shaders the ported demos use are
  vendored (upstream's `compile.sh` regenerates all three from the sources).
- `gpu/images/ravioli.bmp`, `ravioli_atlas.bmp` — the textured-quad and
  sprite-batch textures; `cube0.bmp` … `cube5.bmp` — cubemap faces /
  mipmap source.
