import Common.Gpu

/-!
# gpu/09-basic-compute

Port of `BasicCompute.c` from
[SDL_gpu_examples](https://github.com/TheSpydog/SDL_gpu_examples): the first
compute dispatch. At init a compute pipeline runs once inside a compute pass
with a window-sized RGBA8 texture bound as a read-write storage texture, and
fills every texel with solid yellow (one 8×8 threadgroup per 8×8 pixel tile).
Every frame then samples that texture onto a full-screen quad, so the whole
window shows the compute shader's output.

Exercises: `createComputePipeline`, `CommandBuffer.beginComputePass` with a
`StorageTextureReadWriteBinding`, `ComputePass.bindPipeline` / `dispatch`,
and a texture carrying both the `computeStorageWrite` and `sampler` usages.

Shaders: `TexturedQuad.vert`, `TexturedQuad.frag`, `FillTexture.comp`
(sources under `examples/assets/gpu/shaders/Source/`).
-/

open Sdl Examples.Gpu

structure State where
  drawPipeline : Gpu.GraphicsPipeline
  texture : Gpu.Texture
  sampler : Gpu.Sampler
  vertexBuffer : Gpu.Buffer

/-- The full-screen quad, two triangles in clip space with UVs. -/
def quadVertices : Array PositionTextureVertex := #[
  ⟨-1, -1, 0, 0, 0⟩, ⟨1, -1, 0, 1, 0⟩, ⟨1, 1, 0, 1, 1⟩,
  ⟨-1, -1, 0, 0, 0⟩, ⟨1, 1, 0, 1, 1⟩, ⟨-1, 1, 0, 0, 1⟩]

/-- `sizeof(PositionTextureVertex) * 6`. -/
def vertexBufferSize : UInt32 := PositionTextureVertex.stride * 6

#guard (packVertices PositionTextureVertex.emit quadVertices).size.toUInt32 == vertexBufferSize

def demo : Example State where
  name := "BasicCompute"
  init ctx := do
    let vertexShader ← loadShader ctx.device "TexturedQuad.vert"
    let fragmentShader ← loadShader ctx.device "TexturedQuad.frag" (numSamplers := 1)
    let fillTexturePipeline ← createComputePipeline ctx.device "FillTexture.comp"
      { numReadwriteStorageTextures := 1, threadcountX := 8, threadcountY := 8, threadcountZ := 1 }
    let drawPipeline ← ctx.device.createGraphicsPipeline {
      vertexShader, fragmentShader
      primitiveType := .triangleList
      targetInfo := { colorTargetDescriptions := #[{ format := ← ctx.swapchainFormat }] }
      vertexInputState := PositionTextureVertex.inputState
    }
    vertexShader.release
    fragmentShader.release

    let (w, h) ← ctx.window.getSizeInPixels
    let w := w.toNatClampNeg.toUInt32
    let h := h.toNatClampNeg.toUInt32
    let texture ← ctx.device.createTexture {
      type := .d2, format := .r8g8b8a8Unorm, width := w, height := h
      usage := .computeStorageWrite ||| .sampler }
    let sampler ← ctx.device.createSampler { addressModeU := .«repeat», addressModeV := .«repeat» }
    let vertexBuffer ← ctx.device.createBuffer .vertex vertexBufferSize

    let transferBuffer ← ctx.device.createTransferBuffer .upload vertexBufferSize
    transferBuffer.write (packVertices PositionTextureVertex.emit quadVertices)

    -- One command buffer uploads the quad and runs the fill dispatch.
    let cmd ← ctx.device.acquireCommandBuffer
    let copyPass ← cmd.beginCopyPass
    copyPass.uploadToBuffer { buffer := transferBuffer }
      { buffer := vertexBuffer, size := vertexBufferSize }
    copyPass.finish

    let computePass ← cmd.beginComputePass (storageTextureBindings := #[{ texture }])
    computePass.bindPipeline fillTexturePipeline
    computePass.dispatch (w / 8) (h / 8) 1
    computePass.finish
    cmd.submit

    fillTexturePipeline.release
    transferBuffer.release
    return { drawPipeline, texture, sampler, vertexBuffer }
  draw ctx s := withSwapchainFrame ctx fun cmd sc => do
    let rp ← cmd.beginRenderPass #[{
      texture := sc.texture, clearColor := ⟨0, 0, 0, 1⟩, loadOp := .clear, storeOp := .store }]
    rp.bindPipeline s.drawPipeline
    rp.bindVertexBuffers 0 #[{ buffer := s.vertexBuffer }]
    rp.bindFragmentSamplers 0 #[{ texture := s.texture, sampler := s.sampler }]
    rp.drawPrimitives 6
    rp.finish

def main : IO UInt32 := demo.run
