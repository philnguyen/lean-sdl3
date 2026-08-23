import Common.Gpu

/-!
# gpu/05-basic-stencil

Port of `BasicStencil.c` from
[SDL_gpu_examples](https://github.com/TheSpydog/SDL_gpu_examples): stencil
masking. A "masker" pipeline whose stencil test always fails with
`fail_op = REPLACE` writes the reference value 1 into the stencil buffer
wherever a small yellow triangle would be drawn (no color is written, since
the test fails). A "maskee" pipeline then draws the big RGB triangle with
`compare_op = EQUAL` against reference 0, so it appears everywhere except
inside the small triangle's stencil footprint — a black cut-out.

Exercises `Device.textureSupportsFormat` (probing for a depth-stencil format),
a `DEPTH_STENCIL_TARGET` texture, `DepthStencilState` / `StencilOpState`,
`DepthStencilTargetInfo` in `beginRenderPass`, and
`RenderPass.setStencilReference`.

Shaders: `PositionColor.vert`, `SolidColor.frag` (sources under
`examples/assets/gpu/shaders/Source/`).
-/

open Sdl Examples.Gpu

structure State where
  maskerPipeline : Gpu.GraphicsPipeline
  maskeePipeline : Gpu.GraphicsPipeline
  vertexBuffer : Gpu.Buffer
  depthStencilTexture : Gpu.Texture

/-- The small yellow masker triangle (vertices 0–2) and the big RGB maskee
triangle (vertices 3–5). -/
def vertices : Array PositionColorVertex := #[
  ⟨-0.5, -0.5, 0, 255, 255,   0, 255⟩,
  ⟨ 0.5, -0.5, 0, 255, 255,   0, 255⟩,
  ⟨   0,  0.5, 0, 255, 255,   0, 255⟩,
  ⟨  -1,   -1, 0, 255,   0,   0, 255⟩,
  ⟨   1,   -1, 0,   0, 255,   0, 255⟩,
  ⟨   0,    1, 0,   0,   0, 255, 255⟩]

/-- `sizeof(PositionColorVertex) * 6`. -/
def vertexBytes : UInt32 := PositionColorVertex.stride * 6

#guard (packVertices PositionColorVertex.emit vertices).size.toUInt32 == vertexBytes

/-- Masker: the test never passes, and failing replaces the stored stencil
value with the reference (1). -/
def maskerDepthStencilState : Gpu.DepthStencilState := {
  enableStencilTest := true
  frontStencilState := { compareOp := .never, failOp := .replace, passOp := .keep,
                         depthFailOp := .keep }
  backStencilState := { compareOp := .never, failOp := .replace, passOp := .keep,
                        depthFailOp := .keep }
  writeMask := 0xFF
}

/-- Maskee: only fragments whose stored stencil equals the reference (0)
pass; nothing is written back. -/
def maskeeDepthStencilState : Gpu.DepthStencilState := {
  enableStencilTest := true
  frontStencilState := { compareOp := .equal, failOp := .keep, passOp := .keep,
                         depthFailOp := .keep }
  backStencilState := { compareOp := .never, failOp := .keep, passOp := .keep,
                        depthFailOp := .keep }
  compareMask := 0xFF
  writeMask := 0
}

#guard maskerDepthStencilState.frontStencilState.failOp == .replace
#guard maskeeDepthStencilState.writeMask == 0

/-- Pick a depth-stencil texture format the device supports: D24S8 if it
can, otherwise D32S8. C: the `SDL_GPUTextureSupportsFormat` probe in
`Init`. -/
def pickDepthStencilFormat (device : Gpu.Device) : IO Gpu.TextureFormat := do
  if ← device.textureSupportsFormat .d24UnormS8Uint .d2 .depthStencilTarget then
    return .d24UnormS8Uint
  else if ← device.textureSupportsFormat .d32FloatS8Uint .d2 .depthStencilTarget then
    return .d32FloatS8Uint
  else
    throw <| IO.userError "Stencil formats not supported!"

def demo : Example State where
  name := "BasicStencil"
  init ctx := do
    let vertexShader ← loadShader ctx.device "PositionColor.vert"
    let fragmentShader ← loadShader ctx.device "SolidColor.frag"
    let depthStencilFormat ← pickDepthStencilFormat ctx.device
    let info : Gpu.GraphicsPipelineCreateInfo := {
      vertexShader, fragmentShader
      vertexInputState := PositionColorVertex.inputState
      primitiveType := .triangleList
      targetInfo := {
        colorTargetDescriptions := #[{ format := ← ctx.swapchainFormat }]
        hasDepthStencilTarget := true
        depthStencilFormat }
      depthStencilState := maskerDepthStencilState
      rasterizerState := { cullMode := .none, fillMode := .fill, frontFace := .counterClockwise }
    }
    let maskerPipeline ← ctx.device.createGraphicsPipeline info
    let maskeePipeline ← ctx.device.createGraphicsPipeline
      { info with depthStencilState := maskeeDepthStencilState }
    vertexShader.release
    fragmentShader.release
    let vertexBuffer ← ctx.device.createBuffer .vertex vertexBytes
    let (w, h) ← ctx.window.getSizeInPixels
    let depthStencilTexture ← ctx.device.createTexture {
      type := .d2
      width := w.toNatClampNeg.toUInt32
      height := h.toNatClampNeg.toUInt32
      layerCountOrDepth := 1
      numLevels := 1
      sampleCount := .x1
      format := depthStencilFormat
      usage := .depthStencilTarget }
    let transferBuffer ← ctx.device.createTransferBuffer .upload vertexBytes
    transferBuffer.write (packVertices PositionColorVertex.emit vertices)
    let uploadCmdBuf ← ctx.device.acquireCommandBuffer
    let copyPass ← uploadCmdBuf.beginCopyPass
    copyPass.uploadToBuffer { buffer := transferBuffer, offset := 0 }
      { buffer := vertexBuffer, offset := 0, size := vertexBytes }
    copyPass.finish
    uploadCmdBuf.submit
    transferBuffer.release
    return { maskerPipeline, maskeePipeline, vertexBuffer, depthStencilTexture }
  draw ctx s := withSwapchainFrame ctx fun cmd sc => do
    let rp ← cmd.beginRenderPass
      #[{ texture := sc.texture, clearColor := ⟨0, 0, 0, 1⟩, loadOp := .clear, storeOp := .store }]
      (some { texture := s.depthStencilTexture, cycle := true,
              clearDepth := 0, clearStencil := 0,
              loadOp := .clear, storeOp := .dontCare,
              stencilLoadOp := .clear, stencilStoreOp := .dontCare })
    rp.bindVertexBuffers 0 #[{ buffer := s.vertexBuffer, offset := 0 }]
    rp.setStencilReference 1
    rp.bindPipeline s.maskerPipeline
    rp.drawPrimitives 3
    rp.setStencilReference 0
    rp.bindPipeline s.maskeePipeline
    rp.drawPrimitives 3 (firstVertex := 3)
    rp.finish

def main : IO UInt32 := demo.run
