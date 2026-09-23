# HWX Parsing Guide

This document describes the structure of Apple Neural Engine (ANE) hardware executable files (`.hwx`) and the protocol for parsing task descriptors (TDs) across different architectures (M1-M4).

If you're looking for a way to bypass HWX and run your models directly on the ANE, Albert Li has done some great work for the Asahi Linux project. You can find his repository here: [github.com/allbilly/ane](https://github.com/allbilly/ane).

## 1. File Container: Mach-O HWX

The `.hwx` file is a customized Mach-O binary.

- **Magic Number**: `0xbeefface` (HWX_MAGIC).
- **Architecture Detection**: 
    - **Instruction Set Version $\le 7$**: Uses `ZinAneSequentialCommand_v7minus` (Stream Payload).
    - **Instruction Set Version $\ge 11$**: Uses `ZinAneSequentialCommand_v11` and `ZinAneMaskCommand_v11` (Dense Instruction Payload).

### SoC Architecture Reference Table

| Platform (SoCs) | ANE CPU Subtype | ANE Instruction Set Version |
| :--- | :--- | :--- |
| H11 (A12) | 1 | 5 |
| H12 (A13) | 3 | 6 |
| H13 (generic) / H13p (A14) / H13g (M1) / H13s (M1 Pro) / H13c (M1 Max) / H13d (M1 Ultra) | 4 | 7 |
| H14 (generic) / H14p (A15) / H14g (M2) / H14s (M2 Pro) / H14c (M2 Max) / H14d (M2 Ultra) | 5 | 11 |
| H15 (generic) / H15p (A16) / H15g (M3) / H15s (M3 Pro) / H15c (M3 Max 16c) / H15m (M3 Max 14c) / H15d (M3 Ultra) | 6 | 8 |
| H16 (generic) / H16p (A17 Pro) / H16g (M4) / H16s (M4 Pro) / H16c (M4 Max) | 7 | 17 |
| H17 (generic) / H17a (A18) / H17p (A18 Pro) / H17g (M5) / H17s (M5 Pro) / H17c (M5 Max) / H17d (M5 Ultra) | 9 | 19 |
| H18 (generic) / H18a (A19) / H18p (A19 Pro) | 10 | 20 |
| H18g (M6) / H19 (A20 Pro) | 11 | 24 |

> [!NOTE]
> The **Instruction Set Version** $n$ corresponds directly to the template parameter in the **`ZinAneTd<n u>`** class within the ANECompiler binary. For example, M1 (subtype 4) uses version 7, processed by `ZinAneTd<7u>`.

- **Location of Tasks**: ANE tasks are stored in the `__TEXT` segment, `__text` section.

### Feature Support by Generation (Curated)

Determined by disassembling each ISA version's `ZinAneTd<Nu>::Set*` method: versions that share a byte-identical (ICF-folded) address with earlier generations were checked for an unconditional `ZinAssertImpl` call (i.e. a stub that always rejects the feature, regardless of the caller), vs. a genuinely distinct implementation that stores a real bit/field.

| Feature | First Supported | ISA Version | Evidence |
| :--- | :--- | :--- | :--- |
| **Int8** | H11 (earliest generation checked) | v1+ | `GetHWKernelFormat` is not per-ISA-templated; int8's jump-table case returns hw code 0 unconditionally, with no version check or assert anywhere. |
| **DoubleInt8** | **H16** | v17 | `ZinAneTd<Nu>::SetDoubleInt8Enable` is a shared no-op stub for v1,4,5,6,7,8,10,11 (H11-H14 inclusive) that does nothing real; v17 is the first version with a genuine `mov w8,#0x4000000` / store into `MacCfg` bit 26 (`DoubleInt8En`, already documented in NE.MacCfg for H16/H17/H18/H19). |
| **1D Winograd** | **H17** | v19 | `ZinAneTd<Nu>::Set1DWinogradMode` is a shared stub for v1,4,5,6,7,8,10,11,17 (H11-H16 inclusive) that unconditionally calls `ZinAssertImpl("1D Winograd is not supported")`. v19 is the first version with real code (`mov w8,#0x8000000`, bit 27 of Common.MacCfg). |
| **2D Winograd** | **Not supported on any documented generation** (H11-H19) | — | `ZinAneTd<Nu>::Set2DWinogradMode` shares one address across every version from v1 through v31 (H11 through H19), and it unconditionally asserts `"2D Winograd is not supported"`. The `Set2DWinogradMode` symbol exists on every generation, but it has never actually worked on real silicon covered by this repo. |
| **FP8 / E4M3 (ChCfg, activation format)** | **H18** | v20 | H17 (v19) asserts `"E4M3 is not supported"` in `SetCommonOutFmt`; H18 (v20) and H19 (v24) accept it as field value 4 (see `hwx_dump/hwx_parsing.m`'s `get_ch_fmt_name()`). |
| **FP8 / E4M3 (KernelCfg, weight format)** | Inconclusive from ANECompiler alone | — | `GetHWKernelFormat` (weight-format path) is a single non-templated function, not gated per ISA version the way the activation path is; its only assert is a generic `"Unknown kernel format in codegen"` for out-of-range values. `get_kernel_fmt_name()`'s `case 3: e4m3` may be reachable in software before it's meaningful on real HW — needs empirical confirmation on a per-generation basis, not just static analysis. |
| **DetectZeros** | **H17** | v19 | `ZinAneTd<Nu>::SetKernelDetectZeros` is a shared stub for v4,5,6,7,8,10,11,17 (H12-H16 inclusive) that unconditionally asserts (embedded string is oddly `"On-the-fly Sparse Encoding is not supported"` — likely a copy/paste artifact in Apple's own source, not evidence against this being the DetectZeros setter). v19 is the first version with real code (`mov w8,#0x10000000`, bit 28 of `KernelCfg` — see `hwx_dump/ane_hwx_regs.h`). |

### Extended Feature Support Table (Auto-Generated)

The curated table above covers the handful of features investigated by hand. `hwx_dump/tools/classify_generation_features.py` automates the same technique across every `ZinAneTd<Nu>::Set*(bool)` toggle plus setters matching a hardware-capability keyword list (Winograd, Int8, Sparse, Palett, Quant, Gather, Texture, Reswizzle, Isolation, CircularBuffer, DetectZero, Asym, Compress, Reduction, Broadcast, DoubleRate, DoubleMac, FatTile, Interleave). Regenerate with:

```sh
python3 hwx_dump/tools/classify_generation_features.py
```

This writes `hwx_dump/feature_support.csv` and prints the markdown table below. Per-chip status values:
- **REAL**: writes a real bit/field (`str`/`stur`/`strb`/`strh`) — the feature genuinely works on this generation.
- **STUB**: unconditionally calls `ZinAssertImpl` — the feature is rejected outright on this generation.
- **NOOP**: compiles to an empty/near-empty function (frequently the exact same ICF-folded bare-`ret` address shared with hundreds of unrelated trivial functions elsewhere in the binary) — the argument is silently discarded, neither stored nor rejected.
- **DELEGATES**: tail-calls a differently-named setter (e.g. `SetKernelDmaSrcPaletteLutDmaCacheHint` → `SetKernelDmaSrcHeaderDmaCacheHint`) — not classified further, to avoid guessing the delegate's own behavior.
- **n/a**: no symbol exists for this method name on this ISA version at all (possibly renamed — see caveat below — or genuinely not introduced yet).

#### Insights from the data

**Features land in generational waves, not one at a time.** Each chip's cluster of newly-`REAL` setters roughly matches its known marketing story:
- **H13 (M1)**: the entire PE block (`PESrc1/2Broadcast`, `PESrc1/2ReLu`, `PESrc1/2Transpose`, `PEOutputCtoW`) plus tile-DMA and L2 compression support appear from nothing (`n/a` on H11/H12) — M1 substantially grew the register surface over the iPhone-only H11/H12 generations.
- **H14 (M2)**: an entire **Texture Engine** subsystem appears at once — a dozen+ setters (`TextureMode`, `TextureCropCfg/Coeff`, `TextureFilter`, `TextureWrap`, `TextureNormalization`, `TextureIdxPermute`, etc.), all `n/a` before H14, all `REAL` starting exactly there.
- **H15 (M3)**: activates several features that had existed as inert `NOOP`/`STUB` since H13/H14 — `PEIndexBroadcast/Transpose`, `L2ResultCfgForCompression`, `TileDmaDstCompressedInfo/Size`, `CacheDmaPreEnable`, `PassthroughEnable`.
- **H16 (M4)**: the quantization generation — `DoubleInt8Enable`, `KernelAsymQuantEn`, three quant zero-offset fields, and `PEOutputQuantization` all arrive together, matching M4/A17 Pro's native-int8 story.
- **H17**: `1DWinogradMode`, `KernelDetectZeros`, `PaletteBlockSize`, a new **FIFO DMA mode** across four setters (`L2Src1/2FIFOMode`, `TileDmaSrc1/2FIFOMode`), and new perf tracing (`TraceEn`, `TdHeaderPerfTraceEn`) — several unrelated subsystems landing in the same generation.
- **H18**: comparatively quiet here — only `TileOverlapPadReflect` is new. Combined with the already-documented ChCfg fp8/E4M3 addition, H18's real headline feature is fp8, not much else at the register level.
- **H19**: another big cluster — **multi-palette LUTs** (`MultiPaletteEnable`, `MultiPaletteSizeOneLut`, `PaletteGroupSize`) and a new **double-rate DMA mode** across L2 and Tile DMA (`L2Src1/2DmaDoubleRateMode`, `TileDmaSrc1/2DoubleRateMode`), on top of the bonded-networks work documented separately in [`docs/GUIDE_H18G_H19_BONDED_NETWORKS.md`](../docs/GUIDE_H18G_H19_BONDED_NETWORKS.md).

**A genuine regression, not just additions.** `NEKeepKernel`/`NEUsePrevKernel` are `REAL` on H13, silently become `NOOP` on H14/H15, then the symbols disappear entirely (`n/a`) from H16 onward. Apple removed a working feature rather than just adding one — plausibly consolidated into `GroupKernelReuse`, which has been unconditionally `REAL` since H11 and covers similar ground.

**Permanently dead API surface** (present as symbols but never `REAL` on any of H11-H19): `2DWinogradMode`, `DP2AddMode`, `NEInputTranspose`, `ReswizzleConfigEn`, and `ReswizzleConfigKernelTranspose` always assert; `BroadcastCfg`, `L2Src2NumInterleavedChannels`, `L2SrcNumInterleavedChannels`, `L2DstNumInterleavedChannels`, `NEKBufBypEn`, `KernelDmaSrcKBufByp`, and `SplitRowCompute` never even get instantiated for any mapped chip. The same compiler binary also contains unmapped ISA versions (v1, v4, v10, v26, v28, v31, v36 — presumably internal/pre-H11 or unreleased future targets not in this repo's chip table); it's possible some of these become real there, which this table doesn't check.

**Known limitation — renames aren't tracked.** `TileDmaSrc2Interleave` shows `REAL` only at H15 and `n/a` everywhere else, which looks like a feature that vanished. It didn't: Apple renamed the setter to `SetTileDmaSrc2FormatMode` starting at H17 (folding the interleave value into a broader tensor-format enum parameter). Per-setter-name tracking can't see through renames — treat isolated single-generation `REAL` islands as a signal to grep for a renamed sibling before concluding the feature was removed.

#### Full Table

| Feature | First Real | Chip Status (H11, H12, H13, H14, H15, H16, H17, H18, H19) |
| :--- | :--- | :--- |
| 1DWinogradMode | H17 | STUB / STUB / STUB / STUB / STUB / STUB / REAL / REAL / REAL |
| 2DWinogradMode | never (through H19) | STUB / STUB / STUB / STUB / STUB / STUB / STUB / STUB / STUB |
| AlignedKernelPaletteLut | H13 | n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| BroadcastCfg | never (through H19) | n/a / n/a / n/a / n/a / n/a / n/a / n/a / n/a / n/a |
| CacheDmaPreEnable | H15 | STUB / STUB / STUB / STUB / REAL / REAL / REAL / REAL / REAL |
| CcdmaAtomicEn | H11 | REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| CropOffsetForTexture | H16 | n/a / n/a / n/a / n/a / n/a / REAL / REAL / REAL / REAL |
| CustomCodegenTd | H17 | n/a / n/a / n/a / n/a / n/a / n/a / REAL / REAL / REAL |
| DP2AddMode | never (through H19) | STUB / STUB / STUB / STUB / STUB / STUB / STUB / STUB / STUB |
| DoubleInt8Enable | H16 | STUB / STUB / STUB / STUB / STUB / REAL / REAL / REAL / REAL |
| FillLowerNEFirst | H14 | n/a / n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL |
| GroupKernelReuse | H11 | REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| KernelAsymQuantEn | H16 | STUB / STUB / STUB / STUB / STUB / REAL / REAL / REAL / REAL |
| KernelDetectZeros | H17 | STUB / STUB / STUB / STUB / STUB / STUB / REAL / REAL / REAL |
| KernelDmaSrcKBufByp | never (through H19) | n/a / n/a / n/a / n/a / n/a / n/a / n/a / n/a / n/a |
| KernelDmaSrcNoReuseHint | H14 | n/a / n/a / NOOP / REAL / REAL / n/a / n/a / n/a / n/a |
| KernelDmaSrcPaletteLutDmaCacheHint | H15 | n/a / n/a / DELEGATES / DELEGATES / REAL / REAL / REAL / REAL / REAL |
| KernelDmaSrcPaletteLutUserTag | H14 | NOOP / NOOP / NOOP / REAL / REAL / REAL / REAL / REAL / REAL |
| KernelPalettizedBits | H11 | REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| KernelPalettizedEn | H11 | REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| KernelSparseBinary | H13 | STUB / STUB / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| KernelSparseBlockSize | H14 | n/a / n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL |
| KernelSparseFmt | H11 | REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| L2BfrMode | H11 | REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| L2DstNumInterleavedChannels | never (through H19) | n/a / n/a / n/a / n/a / n/a / n/a / n/a / n/a / n/a |
| L2ResultCfgForCompression | H15 | n/a / n/a / NOOP / NOOP / REAL / REAL / REAL / REAL / REAL |
| L2ResultInterleave | H11 | REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| L2Src1CfgForCompression | H13 | n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| L2Src1DmaDoubleRateMode | H19 | STUB / STUB / STUB / STUB / STUB / STUB / STUB / STUB / REAL |
| L2Src1FIFOMode | H17 | STUB / STUB / STUB / STUB / STUB / STUB / REAL / REAL / REAL |
| L2Src1Interleave | H11 | REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| L2Src2CfgForCompression | H13 | n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| L2Src2DmaDoubleRateMode | H19 | n/a / n/a / STUB / STUB / STUB / STUB / STUB / STUB / REAL |
| L2Src2FIFOMode | H17 | n/a / n/a / STUB / STUB / STUB / STUB / REAL / REAL / REAL |
| L2Src2Interleave | H14 | n/a / n/a / STUB / REAL / REAL / REAL / REAL / REAL / REAL |
| L2Src2NumInterleavedChannels | never (through H19) | n/a / n/a / n/a / n/a / n/a / n/a / n/a / n/a / n/a |
| L2SrcNumInterleavedChannels | never (through H19) | n/a / n/a / n/a / n/a / n/a / n/a / n/a / n/a / n/a |
| MultiPaletteEnable | H19 | STUB / STUB / STUB / STUB / STUB / STUB / STUB / STUB / REAL |
| MultiPaletteSizeOneLut | H19 | STUB / STUB / STUB / STUB / STUB / STUB / STUB / STUB / REAL |
| NEInputTranspose | never (through H19) | STUB / STUB / STUB / STUB / STUB / STUB / STUB / STUB / STUB |
| NEKBufBypEn | never (through H19) | n/a / n/a / n/a / n/a / n/a / n/a / n/a / n/a / n/a |
| NEKeepKernel | H13 | n/a / n/a / REAL / NOOP / NOOP / n/a / n/a / n/a / n/a |
| NEUsePrevKernel | H13 | n/a / n/a / REAL / NOOP / NOOP / n/a / n/a / n/a / n/a |
| OutputTranspose | H13 | NOOP / NOOP / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| PEBypass | H16 | n/a / n/a / n/a / n/a / n/a / REAL / REAL / REAL / REAL |
| PEIndexBroadcast | H15 | n/a / n/a / NOOP / NOOP / REAL / REAL / REAL / REAL / REAL |
| PEIndexTranspose | H15 | n/a / n/a / NOOP / NOOP / REAL / REAL / REAL / REAL / REAL |
| PEOutputCtoW | H13 | n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| PEOutputQuantization | H16 | n/a / n/a / STUB / STUB / STUB / REAL / REAL / REAL / REAL |
| PESrc1Broadcast | H13 | n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| PESrc1ReLu | H13 | n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| PESrc1Transpose | H13 | n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| PESrc2Broadcast | H13 | n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| PESrc2ReLu | H13 | n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| PESrc2Transpose | H13 | n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| PaletteBlockSize | H17 | STUB / STUB / STUB / STUB / STUB / STUB / REAL / REAL / REAL |
| PaletteGroupSize | H19 | STUB / STUB / STUB / STUB / STUB / STUB / STUB / STUB / REAL |
| PassthroughEnable | H15 | STUB / STUB / STUB / STUB / REAL / REAL / REAL / REAL / REAL |
| PublishBit | H19 | n/a / n/a / n/a / n/a / n/a / n/a / n/a / n/a / REAL |
| QuantizationOutputZeroOffset | H16 | STUB / STUB / STUB / STUB / STUB / REAL / REAL / REAL / REAL |
| QuantizationSrc1InputOffset | H16 | n/a / n/a / STUB / STUB / STUB / REAL / REAL / REAL / REAL |
| QuantizationSrc2InputOffset | H16 | n/a / n/a / STUB / STUB / STUB / REAL / REAL / REAL / REAL |
| ReswizzleConfigEn | never (through H19) | STUB / STUB / STUB / STUB / STUB / STUB / STUB / STUB / STUB |
| ReswizzleConfigInputInterleave | H11 | REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| ReswizzleConfigKernelBitDepth | H11 | REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| ReswizzleConfigKernelTranspose | never (through H19) | STUB / STUB / STUB / STUB / STUB / STUB / STUB / STUB / STUB |
| SplitRowCompute | never (through H19) | n/a / n/a / n/a / n/a / n/a / n/a / n/a / n/a / n/a |
| TdHeaderPerfTraceEn | H17 | n/a / n/a / n/a / n/a / n/a / n/a / REAL / REAL / REAL |
| TextureBackgroundEn | H14 | n/a / n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL |
| TextureBackgroundVal | H14 | n/a / n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL |
| TextureBypassFilter | H19 | n/a / n/a / n/a / STUB / STUB / STUB / STUB / STUB / REAL |
| TextureCropBatchSplit | H16 | n/a / n/a / n/a / STUB / STUB / REAL / REAL / REAL / REAL |
| TextureCropCfg | H14 | n/a / n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL |
| TextureCropCoeff | H14 | n/a / n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL |
| TextureDepthValue | H14 | n/a / n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL |
| TextureExtMax | H14 | n/a / n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL |
| TextureFilter | H14 | n/a / n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL |
| TextureGroupValue | H14 | n/a / n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL |
| TextureIdxPermute | H14 | n/a / n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL |
| TextureIndPermute | H14 | n/a / n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL |
| TextureIndexTensorInterleave | H14 | n/a / n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL |
| TextureMode | H14 | n/a / n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL |
| TextureNormalization | H14 | n/a / n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL |
| TexturePreserveFraction | H16 | n/a / n/a / n/a / STUB / STUB / REAL / REAL / REAL / REAL |
| TextureSrcPermute | H14 | n/a / n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL |
| TextureWrap | H14 | n/a / n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL |
| TileDmaDstAtomicEn | H13 | n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| TileDmaDstCompressedInfo | H15 | n/a / n/a / STUB / STUB / REAL / REAL / REAL / REAL / REAL |
| TileDmaDstCompressedSize | H15 | n/a / n/a / NOOP / NOOP / REAL / REAL / REAL / REAL / REAL |
| TileDmaDstandL2DstFifoMode | H13 | n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| TileDmaDstandL2DstInterleave | H13 | n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| TileDmaSrc1CompressedInfo | H13 | n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| TileDmaSrc1CompressedSize | H13 | n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| TileDmaSrc1DoubleRateMode | H19 | n/a / n/a / STUB / STUB / STUB / STUB / STUB / STUB / REAL |
| TileDmaSrc1FIFOMode | H17 | n/a / n/a / STUB / STUB / STUB / STUB / REAL / REAL / REAL |
| TileDmaSrc1Interleave | H13 | n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| TileDmaSrc2CompressedInfo | H15 | n/a / n/a / STUB / STUB / REAL / REAL / REAL / REAL / REAL |
| TileDmaSrc2CompressedSize | H13 | n/a / n/a / REAL / REAL / REAL / REAL / REAL / REAL / REAL |
| TileDmaSrc2DoubleRateMode | H19 | n/a / n/a / n/a / n/a / n/a / n/a / n/a / n/a / REAL |
| TileDmaSrc2FIFOMode | H17 | n/a / n/a / n/a / n/a / n/a / n/a / REAL / REAL / REAL |
| TileDmaSrc2Interleave | H15 | n/a / n/a / n/a / n/a / REAL / n/a / n/a / n/a / n/a |
| TileDmaSrcCompressed2MdUserTag | H15 | NOOP / NOOP / NOOP / NOOP / REAL / REAL / REAL / REAL / REAL |
| TileDmaSrcCompressedMdUserTag | H14 | NOOP / NOOP / NOOP / REAL / REAL / REAL / REAL / REAL / REAL |
| TileOverlapPadReflect | H18 | n/a / n/a / STUB / STUB / STUB / STUB / STUB / REAL / REAL |
| TraceEn | H17 | n/a / n/a / n/a / n/a / n/a / n/a / REAL / REAL / REAL |
| UnicastEn | H11 | REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL / REAL |

## 2. Register Naming Discovery (H16/M4)

To discover register names and bit-accurate fields for the H16 (M4) architecture, analyze the `ANECompiler` binary using two primary classes: `ZinAneTd<17u>` (setters/descriptor state) and `ZinGetRegisterProgramming<17u>` (getters/hardware constraints).

### 1. Structural Mapping
The compiler uses an internal array within `ZinAneTd<17u>` to store the Task Descriptor state.
- **Wait on `this`**: `Set` methods operate on the absolute base of the object (`this`).
- **Wait on `this + 8`**: `Get` methods (via `ZinGetRegisterProgramming`) operate on the `ZinAneTdHw_v17` sub-structure, which is offset by `+8` bytes (2 words).

| Logic Type | Method Prefix | Operation Base | Note |
| :--- | :--- | :--- | :--- |
| **Setters** | `ZinAneTd<17u>::Set*` | `this` | Writes to internal offsets. |
| **Getters** | `ZinGetRegisterProgramming<17u>::Get*` | `this + 0x8` | Reads internal state for HW programming. |

### 2. Identifying Hardware Addresses
Internal offsets correlate directly to hardware register addresses.
- **Formula**: `(Internal Word Offset) * 4` = `Hardware Address`.
- **Known Blocks**:
    - `+0x454` Word -> `0x1150` -> Block `0x4500` (PE)
    - `+0x498` Word -> `0x1260` -> Block `0x4900` (NE)

### 3. Disassembly Analysis Patterns

#### Identifying Fields (bfi)
The `bfi` (Bit Field Insert) instruction is the primary indicator of a register's bit layout.
```asm
; Example: SetNEBinaryPoint(int)
1e4492db0: b9449c08    ldr  w8, [x0, #0x49c]    ; Load MACCfg register
1e4492db4: 33181428    bfi  w8, w1, #8, #6      ; Insert argument at Bit 8, Size 6
1e4492db8: b9049c08    str  w8, [x0, #0x49c]    ; Store back
```
- **Target**: Offset `+0x49c` (HW `0x4904`).
- **Field**: BinaryPoint = Bits 8-13.

#### Identifying Flags (orr)
Single-bit flags often use immediate `orr`.
```asm
; Example: SetKernelAsymQuantEn(bool)
1e4492d04: 12077908    and  w8, w8, #0xfeffffff ; Clear bit 24
1e4492d08: 2a090108    orr  w8, w8, w9         ; Set bit 24 if true
```
- **Field**: AsymQuantEn = Bit 24.

### 4. Cross-Referencing Getters
Getters confirm how the hardware block views the data.
```asm
; Example: GetWin(ZinAneTdHw_v17 const&)
1e459a534: b941f400    ldr  w0, [x0, #0x1f4]
```
- **Input**: `this + 8`.
- **Read**: `0x1f4 + 0x8 = 0x1FC`.
- **Mapping**: `0x1FC` word -> HW Offset `0x1FC * 4` = `0x7F0` (Geometry register 1).

## 3. M1 Architecture (v7)

M1 uses a **Linked-List** task structure with a **Stream Payload** for register configuration.

### Header: `ane_header_h13_t` (0x28 bytes)
```c
typedef struct {
  uint16_t tid;             // 0x000
  uint8_t nid;              // 0x002
  uint8_t lnid_eon;         // 0x003: LNID (bit 0), EON (bit 1)
  uint16_t exe_cycles;      // 0x004
  uint16_t next_size_pad;   // 0x006: NextSize (9 bits)
  uint32_t log_events : 24; // 0x008
  uint32_t exceptions : 24; // 0x00c
  uint32_t debug_log_events:24; // 0x010
  uint32_t debug_exceptions:24; // 0x014
  uint32_t flags;           // 0x018
  uint32_t next_pointer;    // 0x01c
  uint32_t pad[2];          // 0x20-0x28
} ane_header_h13_t;
```

### Payload: Stream Parse
Immediately following the header (at offset `0x28`) is the register stream. Each command block consists of a 32-bit header followed by a variable number of data words.

- **Header Word**:
    - `bits [25:0]`: **Base Address** (e.g., `0x4800`).
    - `bits [31:26]`: Count (Number of 32-bit values following - 1).
- **Data Words**:
    - The next `count + 1` words are written sequentially starting at the target word address.

## 4. M4 Architecture (v11+)

M4 uses an **Aligned Array** task structure with a **Dense Instruction** format (Burst/Scatter).

### Header: `ane_header_h16_t` (0x24 bytes)
```c
typedef struct {
  uint16_t tid;             // 0x000
  uint32_t task_size : 11;  // 0x002
  uint16_t exe_cycles;      // 0x004
  uint32_t log_events : 24; // 0x008
  uint32_t exceptions : 24; // 0x00c
  uint32_t debug_log_events:24; // 0x010
  uint32_t debug_exceptions:24; // 0x014
  uint32_t live_outs;       // 0x018
  uint32_t tsr_tde_ene;     // 0x01c
  uint16_t tdid;            // 0x020
  uint16_t pad;             // 0x022
} ane_header_h16_t;
```
Tasks are 16-byte aligned. If `task_size` is 0, the parser skips to the next alignment boundary.

### Payload: Dense Instruction Format
The payload consists of command headers that specify sequential (Burst) or masked (Scatter) register writes.

**Mode A: Sequential / Burst (Bit 31 = 0)**
- `bits [14:0]`: **Base Address** (Value << 2).
- `bits [20:15]`: Count (burst length).
- `bits [30:21]`: Reserved.
- **Action**: Read `count + 1` data words and write them to `address ... address + count`.

**Mode B: Masked / Scatter (Bit 31 = 1)**
- `bits [14:0]`: **Base Address** (Value << 2).
- `bits [30:15]`: 16-bit population mask.
- **Action**:
    1. The first word following the header is ALWAYS written to `base_address`.
    2. For each bit $i$ set in the mask (0-15), the next word in the stream is written to `base_address + i + 1`.

## 5. Hardware Block Memory Map

Registers are grouped into functional blocks. Note the base address shift between architectures.

| Block Name | M1 Base (Byte) | M4 Base (Byte) | Description |
| :--- | :--- | :--- | :--- |
| **Common** | `0x00000` | `0x0000` | Tensor dims, strides, task types. |
| **L2** | `0x04800` | `0x4100` | L2 Cache and buffer management. |
| **PE** | `0x08800` | `0x4500` | Planar Engine (Pooling, Activation). |
| **NE** | `0x0C800` | `0x4900` | Neural Engine (Convolutions, MACC). |
| **TileDMASrc** | `0x13800` | `0x4D00` | Tiled memory input DMA. |
| **TileDMADst** | `0x17800` | `0x5100` | Tiled memory output DMA. |
| **KernelDMASrc** | `0x1F800` | `0x5500` | Weight and bias loading. |
| **CacheDMA** | N/A | `0x5900` | Telemetry and cache management (M4+). |

## 6. Parsing Workflow

1.  **Open HWX**: Read Mach-O header and verify `0xbeefface`.
2.  **Identify Architecture**: Check `cpusubtype` to choose parsing logic.
3.  **Locate Section**: Find the `__text` section offset and size.
4.  **Iterate Tasks**:
    -   **M1**: Follow `next_pointer` until it is 0.
    -   **M4**: Read `task_size`, parse payload, and jump to the next 16-byte boundary.
5.  **Reconstruct Register State**: For each task, process the payload instructions to populate a 512KB virtual register array (`reg_values[0x20000]`).
6.  **Interpret State**: Map the register array to hardware block structs (e.g., `ane_m1_pe_t`) based on the base addresses above.
