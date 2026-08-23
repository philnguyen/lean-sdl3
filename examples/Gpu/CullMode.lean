import Common.Gpu

/-!
# gpu/04-cull-mode

Port of `CullMode.c` from
[SDL_gpu_examples](https://github.com/TheSpydog/SDL_gpu_examples): six
pipelines that differ only in their rasterizer state — every `CullMode`
(none / front / back) combined with both `FrontFace` windings. Each frame
draws the same triangle twice side by side: the left half from a
clockwise-wound vertex buffer, the right half from a counter-clockwise one,
so the currently selected mode shows which winding survives culling.

Exercises `RasterizerState.cullMode` / `frontFace`, two vertex buffers filled
from one transfer buffer (`uploadToBuffer` with a source offset), and
`setViewport` to split the window.

Controls: **Left**/**Right** cycle through the six modes (the current mode
is logged).

Shaders: `PositionColor.vert`, `SolidColor.frag` (sources under
`examples/assets/gpu/shaders/Source/`).
-/

open Sdl Examples.Gpu

/-- C: `ModeNames`. Index `i` is cull mode `i % 3` with front face CCW for
`i ≤ 2`, CW otherwise. -/
def modeNames : Array String := #[
  "CCW_CullNone", "CCW_CullFront", "CCW_CullBack",
  "CW_CullNone", "CW_CullFront", "CW_CullBack"]

/-- The rasterizer state of mode `i` (C: `i % 3` → cull mode, `i > 2` → CW). -/
def modeRasterizerState (i : Nat) : Gpu.RasterizerState := {
  cullMode := match i % 3 with | 0 => .none | 1 => .front | _ => .back
  frontFace := if i > 2 then .clockwise else .counterClockwise
}

#guard modeNames.size == 6
#guard (modeRasterizerState 0).cullMode == .none && (modeRasterizerState 0).frontFace == .counterClockwise
#guard (modeRasterizerState 4).cullMode == .front && (modeRasterizerState 4).frontFace == .clockwise
#guard (modeRasterizerState 5).cullMode == .back

structure State where
  /-- One pipeline per `modeNames` entry. C: `Pipelines`. -/
  pipelines : Array Gpu.GraphicsPipeline
  vertexBufferCW : Gpu.Buffer
  vertexBufferCCW : Gpu.Buffer
  currentMode : IO.Ref Nat

/-- The two triangles are the same except for the vertex order: the first
three are wound clockwise (in NDC, y up), the next three counter-clockwise. -/
def vertices : Array PositionColorVertex := #[
  ⟨-1, -1, 0, 255,   0,   0, 255⟩,
  ⟨ 1, -1, 0,   0, 255,   0, 255⟩,
  ⟨ 0,  1, 0,   0,   0, 255, 255⟩,
  ⟨ 0,  1, 0, 255,   0,   0, 255⟩,
  ⟨ 1, -1, 0,   0, 255,   0, 255⟩,
  ⟨-1, -1, 0,   0,   0, 255, 255⟩]

/-- `sizeof(PositionColorVertex) * 3`: one triangle. -/
def triangleBytes : UInt32 := PositionColorVertex.stride * 3

#guard (packVertices PositionColorVertex.emit vertices).size.toUInt32 == 2 * triangleBytes

def demo : Example State where
  name := "CullMode"
  init ctx := do
    -- Create the shaders
    let vertexShader ← loadShader ctx.device "PositionColor.vert"
    let fragmentShader ← loadShader ctx.device "SolidColor.frag"
    -- Create the pipelines
    let info : Gpu.GraphicsPipelineCreateInfo := {
      vertexShader, fragmentShader
      vertexInputState := PositionColorVertex.inputState
      primitiveType := .triangleList
      targetInfo := { colorTargetDescriptions := #[{ format := ← ctx.swapchainFormat }] }
    }
    let mut pipelines := #[]
    for i in [0:modeNames.size] do
      pipelines := pipelines.push (← ctx.device.createGraphicsPipeline
        { info with rasterizerState := modeRasterizerState i })
    -- Clean up shader resources
    vertexShader.release
    fragmentShader.release
    -- Create the vertex buffers. They're the same except for the vertex order.
    let vertexBufferCW ← ctx.device.createBuffer .vertex triangleBytes
    let vertexBufferCCW ← ctx.device.createBuffer .vertex triangleBytes
    -- Set up the transfer buffer
    let transferBuffer ← ctx.device.createTransferBuffer .upload (2 * triangleBytes)
    transferBuffer.write (packVertices PositionColorVertex.emit vertices)
    -- Upload the transfer data to the vertex buffers
    let uploadCmdBuf ← ctx.device.acquireCommandBuffer
    let copyPass ← uploadCmdBuf.beginCopyPass
    copyPass.uploadToBuffer { buffer := transferBuffer, offset := 0 }
      { buffer := vertexBufferCW, offset := 0, size := triangleBytes }
    copyPass.uploadToBuffer { buffer := transferBuffer, offset := triangleBytes }
      { buffer := vertexBufferCCW, offset := 0, size := triangleBytes }
    copyPass.finish
    uploadCmdBuf.submit
    transferBuffer.release
    -- Finally, print instructions!
    IO.println "Press Left/Right to switch between modes"
    IO.println s!"Current Mode: {modeNames[0]!}"
    return { pipelines, vertexBufferCW, vertexBufferCCW, currentMode := ← IO.mkRef 0 }
  update ctx s := do
    if ← ctx.leftPressed then
      s.currentMode.modify fun m => if m == 0 then modeNames.size - 1 else m - 1
      IO.println s!"Current Mode: {modeNames[← s.currentMode.get]!}"
    if ← ctx.rightPressed then
      s.currentMode.modify fun m => (m + 1) % modeNames.size
      IO.println s!"Current Mode: {modeNames[← s.currentMode.get]!}"
  draw ctx s := withSwapchainFrame ctx fun cmd sc => do
    let rp ← cmd.beginRenderPass #[{
      texture := sc.texture, clearColor := ⟨0, 0, 0, 1⟩, loadOp := .clear, storeOp := .store }]
    let some pipeline := s.pipelines[← s.currentMode.get]?
      | throw <| IO.userError "CullMode: current mode out of range"
    rp.bindPipeline pipeline
    rp.setViewport { x := 0, y := 0, w := 320, h := 480 }
    rp.bindVertexBuffers 0 #[{ buffer := s.vertexBufferCW, offset := 0 }]
    rp.drawPrimitives 3
    rp.setViewport { x := 320, y := 0, w := 320, h := 480 }
    rp.bindVertexBuffers 0 #[{ buffer := s.vertexBufferCCW, offset := 0 }]
    rp.drawPrimitives 3
    rp.finish

def main : IO UInt32 := demo.run
