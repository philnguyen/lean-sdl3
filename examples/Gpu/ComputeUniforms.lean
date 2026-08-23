import Common.Gpu

/-!
# gpu/10-compute-uniforms

Port of `ComputeUniforms.c` from
[SDL_gpu_examples](https://github.com/TheSpydog/SDL_gpu_examples): a compute
shader driven by a uniform block. Every frame a compute pass writes an
animated cosine color gradient into a window-sized RGBA8 texture, with the
current time pushed as a single-`float` uniform, and the result is blitted
straight onto the swapchain texture — no graphics pipeline at all.

Exercises: `CommandBuffer.pushComputeUniformData`, a cycled read-write
storage-texture binding, and `CommandBuffer.blitTexture` as the presentation
path.

Shaders: `GradientTexture.comp` (source under
`examples/assets/gpu/shaders/Source/`).
-/

open Sdl Examples.Gpu

structure State where
  gradientPipeline : Gpu.ComputePipeline
  gradientRenderTexture : Gpu.Texture
  /-- C: `GradientUniformValues.time`. -/
  time : IO.Ref Float32

/-- The `GradientUniforms` block: `{float time}` (4 bytes). -/
def packGradientUniforms (time : Float32) : ByteArray := pushF32 (.emptyWithCapacity 4) time

#guard (packGradientUniforms 1.0).toList == [0, 0, 0x80, 0x3F]

def demo : Example State where
  name := "ComputeUniforms"
  init ctx := do
    let gradientPipeline ← createComputePipeline ctx.device "GradientTexture.comp"
      { numReadwriteStorageTextures := 1, numUniformBuffers := 1,
        threadcountX := 8, threadcountY := 8, threadcountZ := 1 }
    let (w, h) ← ctx.window.getSizeInPixels
    let gradientRenderTexture ← ctx.device.createTexture {
      format := .r8g8b8a8Unorm, type := .d2
      width := w.toNatClampNeg.toUInt32, height := h.toNatClampNeg.toUInt32
      usage := .sampler ||| .computeStorageWrite }
    return { gradientPipeline, gradientRenderTexture, time := ← IO.mkRef 0 }
  update _ s := s.time.modify (· + 0.01)
  draw ctx s := withSwapchainFrame ctx fun cmd sc => do
    let computePass ← cmd.beginComputePass
      (storageTextureBindings := #[{ texture := s.gradientRenderTexture, cycle := true }])
    computePass.bindPipeline s.gradientPipeline
    cmd.pushComputeUniformData 0 (packGradientUniforms (← s.time.get))
    computePass.dispatch (sc.width / 8) (sc.height / 8) 1
    computePass.finish
    cmd.blitTexture {
      source := { texture := s.gradientRenderTexture, w := sc.width, h := sc.height }
      destination := { texture := sc.texture, w := sc.width, h := sc.height }
      loadOp := .dontCare
      filter := .linear }

def main : IO UInt32 := demo.run
