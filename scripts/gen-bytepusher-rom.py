#!/usr/bin/env python3
"""Regenerate examples/assets/hello.BytePusher, the test ROM for
demo-04-bytepusher (https://esolangs.org/wiki/BytePusher).

Layout (big-endian, as the BytePusher VM reads it):
  [0..1]   keyboard word (zero)
  [2..4]   program counter        = 0x000100
  [5]      screen page            = 0x01  -> framebuffer at 0x010000
  [6..7]   audio bank             = 0x0000 (RAM[0..255], near-silence)
  [0x100]  one self-looping instruction: src=0x000000 dst=0x000008
           next=0x000100 (copies the keyboard byte to scratch, forever)
  [0x010000..0x01FFFF] framebuffer prefilled with the gradient (x + y) % 216
                       (palette indices 0..215 are the web-safe colors)

The demo's headless self-check asserts fb[y=1][x=2] == 3 after running.
"""
rom = bytearray(0x20000)
rom[2:5] = (0x000100).to_bytes(3, "big")
rom[5] = 0x01
rom[0x100:0x109] = bytes([0, 0, 0, 0, 0, 8, 0, 1, 0])
for y in range(256):
    for x in range(256):
        rom[0x10000 + y * 256 + x] = (x + y) % 216
with open("examples/assets/hello.BytePusher", "wb") as f:
    f.write(rom)
print(f"wrote examples/assets/hello.BytePusher ({len(rom)} bytes)")
