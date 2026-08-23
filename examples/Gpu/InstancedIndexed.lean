import Common.Gpu

/-!
# gpu/06-instanced-indexed

Port of `InstancedIndexed.c` from
[SDL_gpu_examples](https://github.com/TheSpydog/SDL_gpu_examples): one draw
call produces a 4×4 grid of small triangles. The vertex shader offsets each
triangle by `SV_InstanceID`, and the draw asks for 16 instances of the 3
vertices. The vertex buffer holds three triangles (red/green/blue,
orange/dark-green/cyan, white) and the index buffer six indices, so the
vertex offset and index offset of `SDL_DrawGPUIndexedPrimitives` (and the
non-indexed `SDL_DrawGPUPrimitives`) can be shown selecting a different
triangle from the same data.

Controls: **Left** toggles the vertex offset, **Right** toggles the index
offset, **Up** toggles indexed vs. non-indexed drawing.

Shaders: `PositionColorInstanced.vert`, `SolidColor.frag` (sources under
`examples/assets/gpu/shaders/Source/`).
-/

open Sdl Examples.Gpu

structure State where
  pipeline : Gpu.GraphicsPipeline
  vertexBuffer : Gpu.Buffer
  indexBuffer : Gpu.Buffer
  useVertexOffset : IO.Ref Bool
  useIndexOffset : IO.Ref Bool
  useIndexBuffer : IO.Ref Bool

/-- The nine vertices (three triangles) of the C `transferData`. -/
def vertices : Array PositionColorVertex := #[
  ⟨-1, -1, 0, 255,   0,   0, 255⟩,
  ⟨ 1, -1, 0,   0, 255,   0, 255⟩,
  ⟨ 0,  1, 0,   0,   0, 255, 255⟩,

  ⟨-1, -1, 0, 255, 165,   0, 255⟩,
  ⟨ 1, -1, 0,   0, 128,   0, 255⟩,
  ⟨ 0,  1, 0,   0, 255, 255, 255⟩,

  ⟨-1, -1, 0, 255, 255, 255, 255⟩,
  ⟨ 1, -1, 0, 255, 255, 255, 255⟩,
  ⟨ 0,  1, 0, 255, 255, 255, 255⟩]

/-- `indexData[i] = i` for the six indices. -/
def indices : Array UInt16 := #[0, 1, 2, 3, 4, 5]

def vertexBytes : UInt32 := PositionColorVertex.stride * vertices.size.toUInt32
def indexBytes : UInt32 := 2 * indices.size.toUInt32

/-- The transfer-buffer contents: vertices then indices, as the C lays them
out back to back. -/
def transferData : ByteArray :=
  packVertices PositionColorVertex.emit vertices ++ packIndices16 indices

#guard vertexBytes == 144 && indexBytes == 12
#guard transferData.size.toUInt32 == vertexBytes + indexBytes
-- The first vertex's color bytes follow its 12 position bytes.
#guard transferData[12]! == 255 && transferData[13]! == 0 && transferData[15]! == 255
-- Index 5 lives at the end of the index area.
#guard transferData[154]! == 5 && transferData[155]! == 0

def demo : Example State where
  name := "InstancedIndexed"
  init ctx := do
    -- Create the shaders
    let vertexShader ← loadShader ctx.device "PositionColorInstanced.vert"
    let fragmentShader ← loadShader ctx.device "SolidColor.frag"

    -- Create the pipeline
    let pipeline ← ctx.device.createGraphicsPipeline {
      vertexShader, fragmentShader
      targetInfo := { colorTargetDescriptions := #[{ format := ← ctx.swapchainFormat }] }
      -- This is set up to match the vertex shader layout!
      vertexInputState := PositionColorVertex.inputState
      primitiveType := .triangleList
    }
    vertexShader.release
    fragmentShader.release

    -- Create the vertex and index buffers
    let vertexBuffer ← ctx.device.createBuffer .vertex vertexBytes
    let indexBuffer ← ctx.device.createBuffer .index indexBytes

    -- Set the buffer data
    let transferBuffer ← ctx.device.createTransferBuffer .upload (vertexBytes + indexBytes)
    transferBuffer.write transferData

    -- Upload the transfer data to the vertex and index buffer
    let uploadCmdBuf ← ctx.device.acquireCommandBuffer
    let copyPass ← uploadCmdBuf.beginCopyPass
    copyPass.uploadToBuffer { buffer := transferBuffer, offset := 0 }
      { buffer := vertexBuffer, offset := 0, size := vertexBytes }
    copyPass.uploadToBuffer { buffer := transferBuffer, offset := vertexBytes }
      { buffer := indexBuffer, offset := 0, size := indexBytes }
    copyPass.finish
    uploadCmdBuf.submit
    transferBuffer.release

    return { pipeline, vertexBuffer, indexBuffer,
             useVertexOffset := ← IO.mkRef false,
             useIndexOffset := ← IO.mkRef false,
             useIndexBuffer := ← IO.mkRef true }
  update ctx s := do
    if ← ctx.leftPressed then
      s.useVertexOffset.modify not
      IO.println s!"Using vertex offset: {← s.useVertexOffset.get}"
    if ← ctx.rightPressed then
      s.useIndexOffset.modify not
      IO.println s!"Using index offset: {← s.useIndexOffset.get}"
    if ← ctx.upPressed then
      s.useIndexBuffer.modify not
      IO.println s!"Using index buffer: {← s.useIndexBuffer.get}"
  draw ctx s := do
    let vertexOffset : UInt32 := if ← s.useVertexOffset.get then 3 else 0
    let indexOffset : UInt32 := if ← s.useIndexOffset.get then 3 else 0
    withSwapchainFrame ctx fun cmd sc => do
      let rp ← cmd.beginRenderPass #[{
        texture := sc.texture, clearColor := ⟨0, 0, 0, 1⟩, loadOp := .clear, storeOp := .store }]
      rp.bindPipeline s.pipeline
      rp.bindVertexBuffers 0 #[{ buffer := s.vertexBuffer, offset := 0 }]
      if ← s.useIndexBuffer.get then
        rp.bindIndexBuffer { buffer := s.indexBuffer, offset := 0 } .u16
        rp.drawIndexedPrimitives 3 16 indexOffset vertexOffset.toInt32 0
      else
        rp.drawPrimitives 3 16 vertexOffset 0
      rp.finish

def main : IO UInt32 := demo.run
