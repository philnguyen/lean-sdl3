import Common.Gpu

/-!
# gpu/03-basic-vertex-buffer

Port of `BasicVertexBuffer.c` from
[SDL_gpu_examples](https://github.com/TheSpydog/SDL_gpu_examples): the first
draw fed from a vertex buffer. Three `PositionColorVertex` records (position
as `FLOAT3`, color as `UBYTE4_NORM`) are packed into an upload transfer
buffer, copied into a `VERTEX` buffer through a copy pass, and drawn as one
triangle with a vertex-input-state that matches the vertex shader's layout.

Exercises `createBuffer`, `createTransferBuffer` + `TransferBuffer.write`,
`beginCopyPass` / `uploadToBuffer`, `VertexInputState`, and
`RenderPass.bindVertexBuffers`.

Shaders: `PositionColor.vert`, `SolidColor.frag` (sources under
`examples/assets/gpu/shaders/Source/`).
-/

open Sdl Examples.Gpu

structure State where
  pipeline : Gpu.GraphicsPipeline
  vertexBuffer : Gpu.Buffer

/-- The triangle: red bottom-left, green bottom-right, blue top. -/
def triangleVertices : Array PositionColorVertex := #[
  ⟨-1, -1, 0, 255,   0,   0, 255⟩,
  ⟨ 1, -1, 0,   0, 255,   0, 255⟩,
  ⟨ 0,  1, 0,   0,   0, 255, 255⟩]

/-- `sizeof(PositionColorVertex) * 3`. -/
def vertexBytes : UInt32 := PositionColorVertex.stride * 3

#guard (packVertices PositionColorVertex.emit triangleVertices).size.toUInt32 == vertexBytes
#guard (packVertices PositionColorVertex.emit triangleVertices)[12]! == 255

/-- This is set up to match the vertex shader layout! -/
def vertexInputState : Gpu.VertexInputState := {
  vertexBufferDescriptions := #[{ slot := 0, inputRate := .vertex, instanceStepRate := 0,
                                  pitch := PositionColorVertex.stride }]
  vertexAttributes := #[
    { bufferSlot := 0, format := .float3, location := 0, offset := 0 },
    { bufferSlot := 0, format := .ubyte4Norm, location := 1, offset := 4 * 3 }]
}

def demo : Example State where
  name := "BasicVertexBuffer"
  init ctx := do
    -- Create the shaders
    let vertexShader ← loadShader ctx.device "PositionColor.vert"
    let fragmentShader ← loadShader ctx.device "SolidColor.frag"
    -- Create the pipeline
    let pipeline ← ctx.device.createGraphicsPipeline {
      vertexShader, fragmentShader, vertexInputState
      primitiveType := .triangleList
      targetInfo := { colorTargetDescriptions := #[{ format := ← ctx.swapchainFormat }] }
    }
    vertexShader.release
    fragmentShader.release
    -- Create the vertex buffer
    let vertexBuffer ← ctx.device.createBuffer .vertex vertexBytes
    -- To get data into the vertex buffer, we have to use a transfer buffer
    let transferBuffer ← ctx.device.createTransferBuffer .upload vertexBytes
    transferBuffer.write (packVertices PositionColorVertex.emit triangleVertices)
    -- Upload the transfer data to the vertex buffer
    let uploadCmdBuf ← ctx.device.acquireCommandBuffer
    let copyPass ← uploadCmdBuf.beginCopyPass
    copyPass.uploadToBuffer { buffer := transferBuffer, offset := 0 }
      { buffer := vertexBuffer, offset := 0, size := vertexBytes }
    copyPass.finish
    uploadCmdBuf.submit
    transferBuffer.release
    return { pipeline, vertexBuffer }
  draw ctx s := withSwapchainFrame ctx fun cmd sc => do
    let rp ← cmd.beginRenderPass #[{
      texture := sc.texture, clearColor := ⟨0, 0, 0, 1⟩, loadOp := .clear, storeOp := .store }]
    rp.bindPipeline s.pipeline
    rp.bindVertexBuffers 0 #[{ buffer := s.vertexBuffer, offset := 0 }]
    rp.drawPrimitives 3
    rp.finish

def main : IO UInt32 := demo.run
