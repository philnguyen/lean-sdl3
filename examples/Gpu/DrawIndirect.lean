import Common.Gpu

/-!
# gpu/11-draw-indirect

Port of `DrawIndirect.c` from
[SDL_gpu_examples](https://github.com/TheSpydog/SDL_gpu_examples): draw
parameters read from a GPU buffer instead of the command stream. One
`INDIRECT` buffer holds an indexed command (a full-screen quad drawn through
a 16-bit index buffer) followed by two non-indexed commands (two triangles
starting at vertex 4 and 7 of the same vertex buffer). The frame issues one
`drawIndexedPrimitivesIndirect` and one `drawPrimitivesIndirect` with a
draw count of 2; every triangle is red/green/blue Gouraud-shaded.

Exercises: `Gpu.IndexedIndirectDrawCommand` / `Gpu.IndirectDrawCommand`
packing, a buffer with the `indirect` usage, and the indirect draw calls with
byte offsets and draw counts.

Shaders: `PositionColor.vert`, `SolidColor.frag` (sources under
`examples/assets/gpu/shaders/Source/`).
-/

open Sdl Examples.Gpu

structure State where
  pipeline : Gpu.GraphicsPipeline
  vertexBuffer : Gpu.Buffer
  indexBuffer : Gpu.Buffer
  drawBuffer : Gpu.Buffer

/-- Vertices 0–3: the quad; 4–6 and 7–9: the two indirect triangles. -/
def vertices : Array PositionColorVertex := #[
  ⟨-1, -1, 0, 255, 0, 0, 255⟩,
  ⟨1, -1, 0, 0, 255, 0, 255⟩,
  ⟨1, 1, 0, 0, 0, 255, 255⟩,
  ⟨-1, 1, 0, 255, 255, 255, 255⟩,

  ⟨1, -1, 0, 0, 255, 0, 255⟩,
  ⟨0, -1, 0, 0, 0, 255, 255⟩,
  ⟨0.5, 1, 0, 255, 0, 0, 255⟩,
  ⟨-1, -1, 0, 0, 255, 0, 255⟩,
  ⟨0, -1, 0, 0, 0, 255, 255⟩,
  ⟨-0.5, 1, 0, 255, 0, 0, 255⟩]

def indices : Array UInt16 := #[0, 1, 2, 0, 2, 3]

/-- `sizeof(PositionColorVertex) * 10`. -/
def vertexBufferSize : UInt32 := PositionColorVertex.stride * 10
/-- `sizeof(Uint16) * 6`. -/
def indexBufferSize : UInt32 := 2 * 6
/-- `sizeof(SDL_GPUIndexedIndirectDrawCommand)`. -/
def indexedCommandSize : UInt32 := 20
/-- `sizeof(SDL_GPUIndexedIndirectDrawCommand) * 1 + sizeof(SDL_GPUIndirectDrawCommand) * 2`. -/
def drawBufferSize : UInt32 := indexedCommandSize + 16 * 2

/-- The indirect buffer contents: one indexed command (the quad), then two
plain draws of 3 vertices starting at vertex 4 and 7. -/
def drawCommands : ByteArray :=
  (Gpu.IndexedIndirectDrawCommand.toBytes { numIndices := 6, numInstances := 1 })
    ++ Gpu.IndirectDrawCommand.toBytes { numVertices := 3, numInstances := 1, firstVertex := 4 }
    ++ Gpu.IndirectDrawCommand.toBytes { numVertices := 3, numInstances := 1, firstVertex := 7 }

/-- The whole upload, laid out as the C maps it: vertices, indices, commands. -/
def transferData : ByteArray :=
  packVertices PositionColorVertex.emit vertices ++ packIndices16 indices ++ drawCommands

#guard (packVertices PositionColorVertex.emit vertices).size.toUInt32 == vertexBufferSize
#guard (packIndices16 indices).size.toUInt32 == indexBufferSize
#guard drawCommands.size.toUInt32 == drawBufferSize
#guard transferData.size.toUInt32 == vertexBufferSize + indexBufferSize + drawBufferSize
-- The second plain command's `first_vertex` sits 8 bytes into that command.
#guard readU32 drawCommands (indexedCommandSize.toNat + 16 + 8) == 7

def demo : Example State where
  name := "DrawIndirect"
  init ctx := do
    -- Create the shaders
    let vertexShader ← loadShader ctx.device "PositionColor.vert"
    let fragmentShader ← loadShader ctx.device "SolidColor.frag"

    -- Create the pipeline
    let pipeline ← ctx.device.createGraphicsPipeline {
      vertexShader, fragmentShader
      primitiveType := .triangleList
      targetInfo := { colorTargetDescriptions := #[{ format := ← ctx.swapchainFormat }] }
      -- This is set up to match the vertex shader layout!
      vertexInputState := PositionColorVertex.inputState
    }
    vertexShader.release
    fragmentShader.release

    -- Create the buffers
    let vertexBuffer ← ctx.device.createBuffer .vertex vertexBufferSize
    let indexBuffer ← ctx.device.createBuffer .index indexBufferSize
    let drawBuffer ← ctx.device.createBuffer .indirect drawBufferSize

    -- Set the buffer data
    let transferBuffer ← ctx.device.createTransferBuffer .upload
      (vertexBufferSize + indexBufferSize + drawBufferSize)
    transferBuffer.write transferData

    -- Upload the transfer data to the GPU buffers
    let uploadCmdBuf ← ctx.device.acquireCommandBuffer
    let copyPass ← uploadCmdBuf.beginCopyPass
    copyPass.uploadToBuffer { buffer := transferBuffer, offset := 0 }
      { buffer := vertexBuffer, offset := 0, size := vertexBufferSize }
    copyPass.uploadToBuffer { buffer := transferBuffer, offset := vertexBufferSize }
      { buffer := indexBuffer, offset := 0, size := indexBufferSize }
    copyPass.uploadToBuffer
      { buffer := transferBuffer, offset := vertexBufferSize + indexBufferSize }
      { buffer := drawBuffer, offset := 0, size := drawBufferSize }
    copyPass.finish
    uploadCmdBuf.submit
    transferBuffer.release
    return { pipeline, vertexBuffer, indexBuffer, drawBuffer }
  draw ctx s := withSwapchainFrame ctx fun cmd sc => do
    let rp ← cmd.beginRenderPass #[{
      texture := sc.texture, clearColor := ⟨0, 0, 0, 1⟩, loadOp := .clear, storeOp := .store }]
    rp.bindPipeline s.pipeline
    rp.bindVertexBuffers 0 #[{ buffer := s.vertexBuffer }]
    rp.bindIndexBuffer { buffer := s.indexBuffer } .u16
    rp.drawIndexedPrimitivesIndirect s.drawBuffer 0 1
    rp.drawPrimitivesIndirect s.drawBuffer indexedCommandSize 2
    rp.finish

def main : IO UInt32 := demo.run
