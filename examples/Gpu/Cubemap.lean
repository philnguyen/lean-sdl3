import Common.Gpu

/-!
# gpu/14-cubemap

Port of `Cubemap.c` from
[SDL_gpu_examples](https://github.com/TheSpydog/SDL_gpu_examples): a cube
texture (`TextureType.cube`, six layers) used as a skybox. At init each face
is a render target of its own — six render passes clear layers 0–5 to red,
green, blue, yellow, magenta and cyan (`ColorTargetInfo.layerOrDepthPlane`).
Every frame a 20-unit cube around the origin is drawn from the inside; the
vertex shader passes the position through as the cube-map lookup direction,
so each visible wall shows one face's color.

This exercises cube textures, per-layer color targets, a vertex-uniform
`view × projection` matrix (`Matrix4x4.lookAt`, `perspectiveFieldOfView`),
and a `TextureCube` sampler binding.

Controls: **Left**/**Right** flip the camera to look the opposite way.

Shaders: `Skybox.vert`, `Skybox.frag` (sources under
`examples/assets/gpu/shaders/Source/`).
-/

open Sdl Examples.Gpu

structure State where
  pipeline : Gpu.GraphicsPipeline
  vertexBuffer : Gpu.Buffer
  indexBuffer : Gpu.Buffer
  texture : Gpu.Texture
  sampler : Gpu.Sampler
  /-- C: `CamPos` — only `z` ever changes (its sign flips). -/
  camPos : IO.Ref Vector3

/-- The clear color of each cube face (layer). C: `ClearColors`. -/
def clearColors : Array FColor :=
  #[⟨1, 0, 0, 1⟩, ⟨0, 1, 0, 1⟩, ⟨0, 0, 1, 1⟩, ⟨1, 1, 0, 1⟩, ⟨1, 0, 1, 1⟩, ⟨0, 1, 1, 1⟩]

#guard clearColors.size == 6

/-- The 24 corner vertices (4 per face) of the ±10 skybox cube. -/
def cubeVertices : Array PositionVertex := #[
  ⟨-10, -10, -10⟩, ⟨10, -10, -10⟩, ⟨10, 10, -10⟩, ⟨-10, 10, -10⟩,
  ⟨-10, -10, 10⟩, ⟨10, -10, 10⟩, ⟨10, 10, 10⟩, ⟨-10, 10, 10⟩,
  ⟨-10, -10, -10⟩, ⟨-10, 10, -10⟩, ⟨-10, 10, 10⟩, ⟨-10, -10, 10⟩,
  ⟨10, -10, -10⟩, ⟨10, 10, -10⟩, ⟨10, 10, 10⟩, ⟨10, -10, 10⟩,
  ⟨-10, -10, -10⟩, ⟨-10, -10, 10⟩, ⟨10, -10, 10⟩, ⟨10, -10, -10⟩,
  ⟨-10, 10, -10⟩, ⟨-10, 10, 10⟩, ⟨10, 10, 10⟩, ⟨10, 10, -10⟩]

/-- Two triangles per face, 36 indices. -/
def cubeIndices : Array UInt16 := #[
   0,  1,  2,  0,  2,  3,
   6,  5,  4,  7,  6,  4,
   8,  9, 10,  8, 10, 11,
  14, 13, 12, 15, 14, 12,
  16, 17, 18, 16, 18, 19,
  22, 21, 20, 23, 22, 20]

/-- `sizeof(PositionVertex) * 24`. -/
def vertexBytes : UInt32 := PositionVertex.stride * 24
/-- `sizeof(Uint16) * 36`. -/
def indexBytes : UInt32 := 2 * 36

#guard cubeVertices.size == 24 && cubeIndices.size == 36
#guard (packVertices PositionVertex.emit cubeVertices).size.toUInt32 == vertexBytes
#guard (packIndices16 cubeIndices).size.toUInt32 == indexBytes

/-- The `view × projection` matrix the vertex shader multiplies positions by.
C: the `viewproj` computed in `Draw`. -/
def viewProj (camPos : Vector3) : Matrix4x4 :=
  let proj := Matrix4x4.perspectiveFieldOfView (75.0 * Examples.pi.toFloat32 / 180.0) (640.0 / 480.0)
    0.01 100.0
  let view := Matrix4x4.lookAt camPos ⟨0, 0, 0⟩ ⟨0, 1, 0⟩
  view * proj

#guard (viewProj ⟨0, 0, 4⟩).toBytes.size == 64

/-- One vertex buffer of `PositionVertex`, one `float3` attribute at location 0. -/
def skyboxVertexInput : Gpu.VertexInputState where
  vertexBufferDescriptions :=
    #[{ slot := 0, inputRate := .vertex, instanceStepRate := 0, pitch := PositionVertex.stride }]
  vertexAttributes := #[{ bufferSlot := 0, format := .float3, location := 0, offset := 0 }]

def demo : Example State where
  name := "Cubemap"
  init ctx := do
    -- Create the shaders
    let vertexShader ← loadShader ctx.device "Skybox.vert" (numUniformBuffers := 1)
    let fragmentShader ← loadShader ctx.device "Skybox.frag" (numSamplers := 1)
    -- Create the pipeline
    let pipeline ← ctx.device.createGraphicsPipeline {
      vertexShader, fragmentShader
      primitiveType := .triangleList
      vertexInputState := skyboxVertexInput
      targetInfo := { colorTargetDescriptions := #[{ format := ← ctx.swapchainFormat }] }
    }
    vertexShader.release
    fragmentShader.release
    -- Create the GPU resources
    let vertexBuffer ← ctx.device.createBuffer .vertex vertexBytes
    let indexBuffer ← ctx.device.createBuffer .index indexBytes
    let texture ← ctx.device.createTexture {
      type := .cube, format := .r8g8b8a8Unorm, width := 64, height := 64,
      layerCountOrDepth := 6, numLevels := 1, usage := .colorTarget ||| .sampler }
    let sampler ← ctx.device.createSampler {
      minFilter := .nearest, magFilter := .nearest, mipmapMode := .nearest,
      addressModeU := .clampToEdge, addressModeV := .clampToEdge, addressModeW := .clampToEdge }
    -- Set up buffer data
    let bufferTransferBuffer ← ctx.device.createTransferBuffer .upload (vertexBytes + indexBytes)
    bufferTransferBuffer.write
      (packVertices PositionVertex.emit cubeVertices ++ packIndices16 cubeIndices)
    -- Upload the transfer data to the GPU buffers
    let cmd ← ctx.device.acquireCommandBuffer
    let copyPass ← cmd.beginCopyPass
    copyPass.uploadToBuffer { buffer := bufferTransferBuffer, offset := 0 }
      { buffer := vertexBuffer, offset := 0, size := vertexBytes }
    copyPass.uploadToBuffer { buffer := bufferTransferBuffer, offset := vertexBytes }
      { buffer := indexBuffer, offset := 0, size := indexBytes }
    copyPass.finish
    bufferTransferBuffer.release
    -- Clear the faces of the cube texture
    for i in [0:6] do
      let rp ← cmd.beginRenderPass #[{
        texture, layerOrDepthPlane := i.toUInt32, clearColor := clearColors[i]!,
        loadOp := .clear, storeOp := .store }]
      rp.finish
    cmd.submit
    -- Print the instructions
    IO.println "Press Left/Right to view the opposite direction!"
    return { pipeline, vertexBuffer, indexBuffer, texture, sampler,
             camPos := ← IO.mkRef ⟨0, 0, 4⟩ }
  update ctx s := do
    if (← ctx.leftPressed) || (← ctx.rightPressed) then
      s.camPos.modify fun p => { p with z := -p.z }
  draw ctx s := withSwapchainFrame ctx fun cmd sc => do
    let viewproj := viewProj (← s.camPos.get)
    let rp ← cmd.beginRenderPass #[{
      texture := sc.texture, clearColor := ⟨0, 0, 0, 1⟩, loadOp := .clear, storeOp := .store }]
    rp.bindPipeline s.pipeline
    rp.bindVertexBuffers 0 #[{ buffer := s.vertexBuffer, offset := 0 }]
    rp.bindIndexBuffer { buffer := s.indexBuffer, offset := 0 } .u16
    rp.bindFragmentSamplers 0 #[{ texture := s.texture, sampler := s.sampler }]
    cmd.pushVertexUniformData 0 viewproj.toBytes
    rp.drawIndexedPrimitives 36 1 0 0 0
    rp.finish

def main : IO UInt32 := demo.run
