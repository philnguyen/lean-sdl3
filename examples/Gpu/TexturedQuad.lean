import Common.Gpu

/-!
# gpu/07-textured-quad

Port of `TexturedQuad.c` from
[SDL_gpu_examples](https://github.com/TheSpydog/SDL_gpu_examples): the first
texture. A full-screen quad (two indexed triangles) samples `ravioli.bmp`
with texture coordinates running from 0 to 4, so the image tiles or clamps
depending on the sampler. Six samplers — point/linear/anisotropic filtering,
each with clamp-to-edge and repeat addressing — can be cycled through to
compare them. Exercises `SDL_UploadToGPUTexture`, `SDL_CreateGPUSampler`,
`SDL_BindGPUFragmentSamplers` and the buffer/texture debug names.

Controls: **Left**/**Right** switch between the sampler states.

Shaders: `TexturedQuad.vert`, `TexturedQuad.frag` (sources under
`examples/assets/gpu/shaders/Source/`).
-/

open Sdl Examples.Gpu

def samplerNames : Array String := #[
  "PointClamp",
  "PointWrap",
  "LinearClamp",
  "LinearWrap",
  "AnisotropicClamp",
  "AnisotropicWrap"]

structure State where
  pipeline : Gpu.GraphicsPipeline
  vertexBuffer : Gpu.Buffer
  indexBuffer : Gpu.Buffer
  texture : Gpu.Texture
  /-- One per `samplerNames` entry; held here so the bound one stays alive. -/
  samplers : Array Gpu.Sampler
  currentSamplerIndex : IO.Ref Nat

/-- The quad's corners; the 0..4 texture coordinates tile the image 4×4
under the wrapping samplers. -/
def vertices : Array PositionTextureVertex := #[
  ⟨-1,  1, 0, 0, 0⟩,
  ⟨ 1,  1, 0, 4, 0⟩,
  ⟨ 1, -1, 0, 4, 4⟩,
  ⟨-1, -1, 0, 0, 4⟩]

def indices : Array UInt16 := #[0, 1, 2, 0, 2, 3]

def vertexBytes : UInt32 := PositionTextureVertex.stride * vertices.size.toUInt32
def indexBytes : UInt32 := 2 * indices.size.toUInt32

/-- The buffer transfer data: vertices then indices, back to back as in C. -/
def transferData : ByteArray :=
  packVertices PositionTextureVertex.emit vertices ++ packIndices16 indices

#guard vertexBytes == 80 && indexBytes == 12
#guard transferData.size.toUInt32 == vertexBytes + indexBytes
-- Vertex 1's `u = 4.0f` sits at offset 20 + 12.
#guard (readU32 transferData 32) == (4.0 : Float32).toBits
#guard transferData[80]! == 0 && transferData[82]! == 1 && transferData[90]! == 3

/-- The six upstream sampler states, in `samplerNames` order. -/
def samplerInfos : Array Gpu.SamplerCreateInfo :=
  let point : Gpu.SamplerCreateInfo :=
    { minFilter := .nearest, magFilter := .nearest, mipmapMode := .nearest }
  let linear : Gpu.SamplerCreateInfo :=
    { minFilter := .linear, magFilter := .linear, mipmapMode := .linear }
  let anisotropic : Gpu.SamplerCreateInfo :=
    { linear with enableAnisotropy := true, maxAnisotropy := 4 }
  let clamp (i : Gpu.SamplerCreateInfo) : Gpu.SamplerCreateInfo :=
    { i with addressModeU := .clampToEdge, addressModeV := .clampToEdge,
             addressModeW := .clampToEdge }
  let wrap (i : Gpu.SamplerCreateInfo) : Gpu.SamplerCreateInfo :=
    { i with addressModeU := .«repeat», addressModeV := .«repeat», addressModeW := .«repeat» }
  #[clamp point, wrap point, clamp linear, wrap linear, clamp anisotropic, wrap anisotropic]

#guard samplerInfos.size == samplerNames.size
#guard samplerInfos[4]?.any fun i => i.enableAnisotropy && i.maxAnisotropy == 4
#guard samplerInfos[5]?.any fun i => i.addressModeU == .«repeat» && i.magFilter == .linear
#guard samplerInfos[0]?.any fun i => i.addressModeW == .clampToEdge && i.magFilter == .nearest

def demo : Example State where
  name := "TexturedQuad"
  init ctx := do
    -- Create the shaders
    let vertexShader ← loadShader ctx.device "TexturedQuad.vert"
    let fragmentShader ← loadShader ctx.device "TexturedQuad.frag" (numSamplers := 1)

    -- Load the image
    let imageData ← loadImage "ravioli.bmp"

    -- Create the pipeline
    let pipeline ← ctx.device.createGraphicsPipeline {
      vertexShader, fragmentShader
      targetInfo := { colorTargetDescriptions := #[{ format := ← ctx.swapchainFormat }] }
      vertexInputState := PositionTextureVertex.inputState
      primitiveType := .triangleList
    }
    vertexShader.release
    fragmentShader.release

    let samplers ← samplerInfos.mapM fun info => ctx.device.createSampler info

    -- Create the GPU resources
    let vertexBuffer ← ctx.device.createBuffer .vertex vertexBytes
    vertexBuffer.setName "Ravioli Vertex Buffer 🥣"
    let indexBuffer ← ctx.device.createBuffer .index indexBytes
    let texture ← ctx.device.createTexture {
      type := .d2, format := .r8g8b8a8Unorm,
      width := imageData.width, height := imageData.height,
      layerCountOrDepth := 1, numLevels := 1, usage := .sampler }
    texture.setName "Ravioli Texture 🖼️"

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
      { buffer := textureTransferBuffer, offset := 0 } -- Zeros out the rest
      { texture, w := imageData.width, h := imageData.height, d := 1 }
    copyPass.finish
    uploadCmdBuf.submit
    bufferTransferBuffer.release
    textureTransferBuffer.release

    -- Finally, print instructions!
    IO.println "Press Left/Right to switch between sampler states"
    IO.println s!"Setting sampler state to: {samplerNames[0]!}"

    return { pipeline, vertexBuffer, indexBuffer, texture, samplers,
             currentSamplerIndex := ← IO.mkRef 0 }
  update ctx s := do
    if ← ctx.leftPressed then
      s.currentSamplerIndex.modify fun i => if i == 0 then samplerNames.size - 1 else i - 1
      IO.println s!"Setting sampler state to: {samplerNames[← s.currentSamplerIndex.get]!}"
    if ← ctx.rightPressed then
      s.currentSamplerIndex.modify fun i => (i + 1) % samplerNames.size
      IO.println s!"Setting sampler state to: {samplerNames[← s.currentSamplerIndex.get]!}"
  draw ctx s := withSwapchainFrame ctx fun cmd sc => do
    let some sampler := s.samplers[← s.currentSamplerIndex.get]?
      | throw <| IO.userError "sampler index out of range"
    let rp ← cmd.beginRenderPass #[{
      texture := sc.texture, clearColor := ⟨0, 0, 0, 1⟩, loadOp := .clear, storeOp := .store }]
    rp.bindPipeline s.pipeline
    rp.bindVertexBuffers 0 #[{ buffer := s.vertexBuffer, offset := 0 }]
    rp.bindIndexBuffer { buffer := s.indexBuffer, offset := 0 } .u16
    rp.bindFragmentSamplers 0 #[{ texture := s.texture, sampler }]
    rp.drawIndexedPrimitives 6 1 0 0 0
    rp.finish

def main : IO UInt32 := demo.run
