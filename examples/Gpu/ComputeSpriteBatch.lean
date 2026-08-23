import Common.Gpu

/-!
# gpu/16-compute-sprite-batch

Port of `ComputeSpriteBatch.c` from
[SDL_gpu_examples](https://github.com/TheSpydog/SDL_gpu_examples): the same
8192-ravioli batch as `gpu-17-pull-sprite-batch`, built the compute way.
Each frame the `SpriteInstance` records are uploaded to a
`COMPUTE_STORAGE_READ` buffer, a compute pass (`SpriteBatch.comp`, one
thread per sprite) expands every sprite into four
`PositionTextureColorVertex` records in a `COMPUTE_STORAGE_WRITE | VERTEX`
buffer, and a render pass draws them through a static index buffer (six
`Uint32` indices per quad, uploaded once at init) with a single
`drawIndexedPrimitives`. As upstream notes, this is a little slower than the
vertex-pulling version; it is included to show a compute → graphics
workflow and buffer `cycle` on a storage buffer that is rewritten every
frame.

Present mode: immediate if the window supports it, else mailbox, else vsync.

Shaders: `SpriteBatch.comp` (1 readonly + 1 read-write storage buffer,
64×1×1 threads), `TexturedQuadColorWithMatrix.vert` (1 uniform buffer),
`TexturedQuadColor.frag` (1 sampler).
-/

open Sdl Examples.Gpu

/-- Sprites per frame. C: `SPRITE_COUNT`. -/
def spriteCount : Nat := 8192

/-- `sizeof(PositionTextureColorVertex)`: `x y z w | u v pad pad | r g b a`,
twelve floats — written by the compute shader, read by the vertex shader. -/
def vertexStride : UInt32 := 48

/-- Two triangles per quad: `0 1 2  3 2 1`, offset by 4 per sprite. C: the
`indexTransferPtr` loop in `Init`. -/
def spriteIndices : ByteArray := Id.run do
  let mut b := ByteArray.emptyWithCapacity (spriteCount * 6 * 4)
  for i in [0:spriteCount] do
    let j := (i * 4).toUInt32
    b := [j, j + 1, j + 2, j + 3, j + 2, j + 1].foldl pushU32 b
  return b

#guard spriteIndices.size == spriteCount * 6 * 4
#guard readU32 spriteIndices (6 * 4) == 4 && readU32 spriteIndices (11 * 4) == 5

structure State where
  computePipeline : Gpu.ComputePipeline
  renderPipeline : Gpu.GraphicsPipeline
  sampler : Gpu.Sampler
  texture : Gpu.Texture
  spriteComputeTransferBuffer : Gpu.TransferBuffer
  spriteComputeBuffer : Gpu.Buffer
  spriteVertexBuffer : Gpu.Buffer
  spriteIndexBuffer : Gpu.Buffer
  rng : IO.Ref UInt64

def demo : Example State where
  name := "ComputeSpriteBatch"
  init ctx := do
    let presentMode : Gpu.PresentMode ←
      if ← ctx.device.windowSupportsPresentMode ctx.window .immediate then pure .immediate
      else if ← ctx.device.windowSupportsPresentMode ctx.window .mailbox then pure .mailbox
      else pure .vsync
    ctx.device.setSwapchainParameters ctx.window .sdr presentMode

    -- Create the shaders
    let vertShader ← loadShader ctx.device "TexturedQuadColorWithMatrix.vert"
      (numUniformBuffers := 1)
    let fragShader ← loadShader ctx.device "TexturedQuadColor.frag" (numSamplers := 1)

    -- Create the sprite render pipeline
    let renderPipeline ← ctx.device.createGraphicsPipeline {
      vertexShader := vertShader
      fragmentShader := fragShader
      primitiveType := .triangleList
      vertexInputState := {
        vertexBufferDescriptions := #[{ slot := 0, pitch := vertexStride }]
        vertexAttributes := #[
          { location := 0, bufferSlot := 0, format := .float4, offset := 0 },
          { location := 1, bufferSlot := 0, format := .float2, offset := 16 },
          { location := 2, bufferSlot := 0, format := .float4, offset := 32 }] }
      targetInfo := { colorTargetDescriptions := #[{
        format := ← ctx.swapchainFormat
        blendState := {
          enableBlend := true
          colorBlendOp := .add
          alphaBlendOp := .add
          srcColorBlendfactor := .srcAlpha
          dstColorBlendfactor := .oneMinusSrcAlpha
          srcAlphaBlendfactor := .srcAlpha
          dstAlphaBlendfactor := .oneMinusSrcAlpha } }] }
    }
    vertShader.release
    fragShader.release

    -- Create the sprite batch compute pipeline
    let computePipeline ← createComputePipeline ctx.device "SpriteBatch.comp"
      { numReadonlyStorageBuffers := 1, numReadwriteStorageBuffers := 1
        threadcountX := 64, threadcountY := 1, threadcountZ := 1 }

    -- Load the image data
    let image ← loadImage "ravioli_atlas.bmp"
    let textureTransferBuffer ← ctx.device.createTransferBuffer .upload
      (image.width * image.height * 4)
    textureTransferBuffer.write image.pixels

    -- Create the GPU resources
    let texture ← ctx.device.createTexture {
      type := .d2, format := .r8g8b8a8Unorm, usage := .sampler
      width := image.width, height := image.height }
    let sampler ← ctx.device.createSampler {
      minFilter := .nearest, magFilter := .nearest, mipmapMode := .nearest
      addressModeU := .clampToEdge, addressModeV := .clampToEdge, addressModeW := .clampToEdge }
    let batchSize := (spriteCount * SpriteInstance.stride.toNat).toUInt32
    let spriteComputeTransferBuffer ← ctx.device.createTransferBuffer .upload batchSize
    let spriteComputeBuffer ← ctx.device.createBuffer .computeStorageRead batchSize
    let spriteVertexBuffer ← ctx.device.createBuffer (.computeStorageWrite ||| .vertex)
      (spriteCount.toUInt32 * 4 * vertexStride)
    let spriteIndexBuffer ← ctx.device.createBuffer .index spriteIndices.size.toUInt32

    -- Transfer the up-front data
    let indexBufferTransferBuffer ← ctx.device.createTransferBuffer .upload
      spriteIndices.size.toUInt32
    indexBufferTransferBuffer.write spriteIndices
    let uploadCmdBuf ← ctx.device.acquireCommandBuffer
    let copyPass ← uploadCmdBuf.beginCopyPass
    copyPass.uploadToTexture { buffer := textureTransferBuffer }
      { texture, w := image.width, h := image.height }
    copyPass.uploadToBuffer { buffer := indexBufferTransferBuffer }
      { buffer := spriteIndexBuffer, size := spriteIndices.size.toUInt32 }
    copyPass.finish
    uploadCmdBuf.submit
    textureTransferBuffer.release
    indexBufferTransferBuffer.release

    return { computePipeline, renderPipeline, sampler, texture, spriteComputeTransferBuffer,
             spriteComputeBuffer, spriteVertexBuffer, spriteIndexBuffer,
             rng := ← IO.mkRef 0x9E3779B97F4A7C15 }
  draw ctx s := do
    let cameraMatrix := Matrix4x4.orthographicOffCenter 0 640 480 0 0 (-1)
    withSwapchainFrame ctx fun cmd sc => do
      -- Build sprite instance transfer
      let (batch, rng) := randomSpriteBatch spriteCount (← s.rng.get)
      s.rng.set rng
      s.spriteComputeTransferBuffer.write batch (cycle := true)

      -- Upload instance data
      let copyPass ← cmd.beginCopyPass
      copyPass.uploadToBuffer { buffer := s.spriteComputeTransferBuffer }
        { buffer := s.spriteComputeBuffer, size := batch.size.toUInt32 } (cycle := true)
      copyPass.finish

      -- Set up compute pass to build vertex buffer
      let computePass ← cmd.beginComputePass
        (storageBufferBindings := #[{ buffer := s.spriteVertexBuffer, cycle := true }])
      computePass.bindPipeline s.computePipeline
      computePass.bindStorageBuffers 0 #[s.spriteComputeBuffer]
      computePass.dispatch (spriteCount / 64).toUInt32 1 1
      computePass.finish

      -- Render sprites
      let renderPass ← cmd.beginRenderPass #[{
        texture := sc.texture, loadOp := .clear, storeOp := .store, clearColor := ⟨0, 0, 0, 1⟩ }]
      renderPass.bindPipeline s.renderPipeline
      renderPass.bindVertexBuffers 0 #[{ buffer := s.spriteVertexBuffer }]
      renderPass.bindIndexBuffer { buffer := s.spriteIndexBuffer } .u32
      renderPass.bindFragmentSamplers 0 #[{ texture := s.texture, sampler := s.sampler }]
      cmd.pushVertexUniformData 0 cameraMatrix.toBytes
      renderPass.drawIndexedPrimitives (spriteCount * 6).toUInt32
      renderPass.finish

def main : IO UInt32 := demo.run
