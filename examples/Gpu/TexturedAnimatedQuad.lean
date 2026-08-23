import Common.Gpu

/-!
# gpu/08-textured-animated-quad

Port of `TexturedAnimatedQuad.c` from
[SDL_gpu_examples](https://github.com/TheSpydog/SDL_gpu_examples): uniform
data. Four copies of a textured ravioli quad spin in the four quadrants of
the window, each drawn with its own vertex uniform (a rotation × translation
`Matrix4x4`, pushed with `SDL_PushGPUVertexUniformData`) and fragment
uniform (a multiply color whose green channel pulses with `sin`/`cos` of the
elapsed time, pushed with `SDL_PushGPUFragmentUniformData`). The pipeline
enables standard alpha blending so the texture's transparent background
stays black.

Shaders: `TexturedQuadWithMatrix.vert`, `TexturedQuadWithMultiplyColor.frag`
(sources under `examples/assets/gpu/shaders/Source/`).
-/

open Sdl Examples.Gpu

structure State where
  pipeline : Gpu.GraphicsPipeline
  vertexBuffer : Gpu.Buffer
  indexBuffer : Gpu.Buffer
  texture : Gpu.Texture
  sampler : Gpu.Sampler
  /-- Elapsed seconds. C: `static float t`. -/
  t : IO.Ref Float32

/-- A unit quad centered on the origin; the per-draw matrix places it. -/
def vertices : Array PositionTextureVertex := #[
  ⟨-0.5, -0.5, 0, 0, 0⟩,
  ⟨ 0.5, -0.5, 0, 1, 0⟩,
  ⟨ 0.5,  0.5, 0, 1, 1⟩,
  ⟨-0.5,  0.5, 0, 0, 1⟩]

def indices : Array UInt16 := #[0, 1, 2, 0, 2, 3]

def vertexBytes : UInt32 := PositionTextureVertex.stride * vertices.size.toUInt32
def indexBytes : UInt32 := 2 * indices.size.toUInt32

/-- The buffer transfer data: vertices then indices, back to back as in C. -/
def transferData : ByteArray :=
  packVertices PositionTextureVertex.emit vertices ++ packIndices16 indices

#guard vertexBytes == 80 && indexBytes == 12
#guard transferData.size.toUInt32 == vertexBytes + indexBytes
#guard readU32 transferData 0 == (-0.5 : Float32).toBits
#guard transferData[80]! == 0 && transferData[82]! == 1 && transferData[90]! == 3

/-- C: `FragMultiplyUniform { float r, g, b, a; }` (16 bytes). -/
def fragMultiplyUniform (r g b a : Float32) : ByteArray :=
  [r, g, b, a].foldl pushF32 (.emptyWithCapacity 16)

#guard (fragMultiplyUniform 1 0.5 1 1).size == 16
#guard readU32 (fragMultiplyUniform 1 0.5 1 1) 4 == (0.5 : Float32).toBits

def twoPi : Float32 := 2.0 * Examples.pi.toFloat32

/-- The four quads' vertex/fragment uniforms at time `t`: bottom-left,
bottom-right, top-left, top-right — matching the C `Draw` in order. -/
def quadUniforms (t : Float32) : Array (Matrix4x4 × ByteArray) := #[
  (Matrix4x4.rotationZ t * Matrix4x4.translation (-0.5) (-0.5) 0,
    fragMultiplyUniform 1 (0.5 + t.sin * 0.5) 1 1),
  (Matrix4x4.rotationZ (twoPi - t) * Matrix4x4.translation 0.5 (-0.5) 0,
    fragMultiplyUniform 1 (0.5 + t.cos * 0.5) 1 1),
  (Matrix4x4.rotationZ t * Matrix4x4.translation (-0.5) 0.5 0,
    fragMultiplyUniform 1 (0.5 + t.sin * 0.2) 1 1),
  (Matrix4x4.rotationZ t * Matrix4x4.translation 0.5 0.5 0,
    fragMultiplyUniform 1 (0.5 + t.cos * 1.0) 1 1)]

#guard (quadUniforms 0).size == 4
-- At t = 0 the `rotationZ t` quads are pure translations (the bottom-right
-- one rotates by 2π, which is only approximately the identity in floats).
#guard ((quadUniforms 0)[0]?.map (·.1)) == some (Matrix4x4.translation (-0.5) (-0.5) 0)
#guard ((quadUniforms 0)[2]?.map (·.1)) == some (Matrix4x4.translation (-0.5) 0.5 0)
#guard ((quadUniforms 0)[3]?.map (·.1)) == some (Matrix4x4.translation 0.5 0.5 0)
#guard ((quadUniforms 0)[1]?.map fun q => (q.1.m41, q.1.m42, q.1.m43))
  == some ((0.5 : Float32), (-0.5 : Float32), (0 : Float32))
-- At t = 0 the top-right quad's green channel is 0.5 + cos 0 = 1.5.
#guard ((quadUniforms 0)[3]?.map fun q => readU32 q.2 4) == some (1.5 : Float32).toBits

def demo : Example State where
  name := "TexturedAnimatedQuad"
  init ctx := do
    -- Create the shaders
    let vertexShader ← loadShader ctx.device "TexturedQuadWithMatrix.vert"
      (numUniformBuffers := 1)
    let fragmentShader ← loadShader ctx.device "TexturedQuadWithMultiplyColor.frag"
      (numSamplers := 1) (numUniformBuffers := 1)

    -- Load the image
    let imageData ← loadImage "ravioli.bmp"

    -- Create the pipeline
    let pipeline ← ctx.device.createGraphicsPipeline {
      vertexShader, fragmentShader
      targetInfo := { colorTargetDescriptions := #[{
        format := ← ctx.swapchainFormat
        blendState := {
          enableBlend := true
          alphaBlendOp := .add
          colorBlendOp := .add
          srcColorBlendfactor := .srcAlpha
          srcAlphaBlendfactor := .srcAlpha
          dstColorBlendfactor := .oneMinusSrcAlpha
          dstAlphaBlendfactor := .oneMinusSrcAlpha } }] }
      vertexInputState := {
        vertexBufferDescriptions := #[{
          slot := 0, inputRate := .vertex, instanceStepRate := 0,
          pitch := PositionTextureVertex.stride }]
        vertexAttributes := #[
          { bufferSlot := 0, format := .float3, location := 0, offset := 0 },
          { bufferSlot := 0, format := .float2, location := 1, offset := 4 * 3 }]
      }
      primitiveType := .triangleList
    }
    vertexShader.release
    fragmentShader.release

    -- Create the GPU resources
    let vertexBuffer ← ctx.device.createBuffer .vertex vertexBytes
    let indexBuffer ← ctx.device.createBuffer .index indexBytes
    let texture ← ctx.device.createTexture {
      type := .d2, format := .r8g8b8a8Unorm,
      width := imageData.width, height := imageData.height,
      layerCountOrDepth := 1, numLevels := 1, usage := .sampler }
    let sampler ← ctx.device.createSampler {
      minFilter := .nearest, magFilter := .nearest, mipmapMode := .nearest,
      addressModeU := .clampToEdge, addressModeV := .clampToEdge,
      addressModeW := .clampToEdge }

    -- Set up buffer data
    let bufferTransferBuffer ←
      ctx.device.createTransferBuffer .upload (vertexBytes + indexBytes)
    bufferTransferBuffer.write transferData

    -- Set up texture data
    let textureTransferBuffer ←
      ctx.device.createTransferBuffer .upload (imageData.width * imageData.height * 4)
    textureTransferBuffer.write imageData.pixels

    -- Upload the transfer data to the GPU resources
    let uploadCmdBuf ← ctx.device.acquireCommandBuffer
    let copyPass ← uploadCmdBuf.beginCopyPass
    copyPass.uploadToBuffer { buffer := bufferTransferBuffer, offset := 0 }
      { buffer := vertexBuffer, offset := 0, size := vertexBytes }
    copyPass.uploadToBuffer { buffer := bufferTransferBuffer, offset := vertexBytes }
      { buffer := indexBuffer, offset := 0, size := indexBytes }
    copyPass.uploadToTexture
      { buffer := textureTransferBuffer, offset := 0 } -- Zeroes out the rest
      { texture, w := imageData.width, h := imageData.height, d := 1 }
    copyPass.finish
    uploadCmdBuf.submit
    bufferTransferBuffer.release
    textureTransferBuffer.release

    return { pipeline, vertexBuffer, indexBuffer, texture, sampler, t := ← IO.mkRef 0 }
  update ctx s := do
    s.t.modify (· + (← ctx.getDeltaTime))
  draw ctx s := withSwapchainFrame ctx fun cmd sc => do
    let rp ← cmd.beginRenderPass #[{
      texture := sc.texture, clearColor := ⟨0, 0, 0, 1⟩, loadOp := .clear, storeOp := .store }]
    rp.bindPipeline s.pipeline
    rp.bindVertexBuffers 0 #[{ buffer := s.vertexBuffer, offset := 0 }]
    rp.bindIndexBuffer { buffer := s.indexBuffer, offset := 0 } .u16
    rp.bindFragmentSamplers 0 #[{ texture := s.texture, sampler := s.sampler }]
    -- Bottom-left, bottom-right, top-left, top-right: each draw gets its own
    -- matrix and multiply color, pushed on the command buffer before it.
    for (matrixUniform, fragUniform) in quadUniforms (← s.t.get) do
      cmd.pushVertexUniformData 0 matrixUniform.toBytes
      cmd.pushFragmentUniformData 0 fragUniform
      rp.drawIndexedPrimitives 6 1 0 0 0
    rp.finish

def main : IO UInt32 := demo.run
