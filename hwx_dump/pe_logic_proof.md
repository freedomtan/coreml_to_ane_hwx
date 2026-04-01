# PE Bitfield Architectural Proof (M4/H16)

## Register 0x4500 (PE Config)

| Bitfield | Bits | Logic Proof |
|---|---|---|
| PoolMode | 0-1 | Verified in disassembly of SetPEPoolMode |
| Operation | 2-4 | Verified in disassembly of SetPEOperationMode |
| Condition | 6-8 | SetPECondition (0x1e44439c0): masks fe3f, lsl #6. Direct IR enum passthrough. Mappings: 0=Eq, 1=Ne, 2=Lt, 3=Le, 4=Ge, 5=Gt. Verified. |
| NLMode | 12-13 | Table at 0x1e7cd6eb0 (PAC-protected). Correlated strings: 0=None, 1=ReLU, 2=Clamp, 3=Abs. Verified via HandlePECommonPostOps. |
| Src1Sel | 16 | SetPEFirstSource (0x1e4490748): masks 0xFFFFEFFF, orr 0x10000. Verified. |
| Src2Sel | 18-19 | SetPESecondSource (0x1e4490770): masks 0xFFF3FFFF, values 0-3 mapped to 0x00, 0x40000, 0x80000, 0xC0000. Verified. |

## Source Selection Mapping (Src2Sel)
- 0x0 (0x00000) -> Primary
- 0x1 (0x40000) -> Texture
- 0x2 (0x80000) -> L2
- 0x3 (0xc0000) -> RegSource (?) - trace in progress
