# ANE Feature Support by Generation

Which ANE hardware generation (chip codename, per the SoC Architecture Reference Table in [hwx_dump/README.md](../hwx_dump/README.md)) actually added each feature — determined by disassembling ANECompiler's per-ISA-version `ZinAneTd<Nu>::Set*` methods, not by symbol presence alone (many setters exist on every generation as an unconditional `ZinAssertImpl` reject stub long before the feature is real).

## Feature Support by Generation (Curated)

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

## Extended Feature Support Table (Auto-Generated)

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

## Insights from the data

**Features land in generational waves, not one at a time.** Each chip's cluster of newly-`REAL` setters roughly matches its known marketing story:
- **H13 (M1)**: the entire PE block (`PESrc1/2Broadcast`, `PESrc1/2ReLu`, `PESrc1/2Transpose`, `PEOutputCtoW`) plus tile-DMA and L2 compression support appear from nothing (`n/a` on H11/H12) — M1 substantially grew the register surface over the iPhone-only H11/H12 generations.
- **H14 (M2)**: an entire **Texture Engine** subsystem appears at once — a dozen+ setters (`TextureMode`, `TextureCropCfg/Coeff`, `TextureFilter`, `TextureWrap`, `TextureNormalization`, `TextureIdxPermute`, etc.), all `n/a` before H14, all `REAL` starting exactly there.
- **H15 (M3)**: activates several features that had existed as inert `NOOP`/`STUB` since H13/H14 — `PEIndexBroadcast/Transpose`, `L2ResultCfgForCompression`, `TileDmaDstCompressedInfo/Size`, `CacheDmaPreEnable`, `PassthroughEnable`.
- **H16 (M4)**: the quantization generation — `DoubleInt8Enable`, `KernelAsymQuantEn`, three quant zero-offset fields, and `PEOutputQuantization` all arrive together, matching M4/A17 Pro's native-int8 story.
- **H17**: `1DWinogradMode`, `KernelDetectZeros`, `PaletteBlockSize`, a new **FIFO DMA mode** across four setters (`L2Src1/2FIFOMode`, `TileDmaSrc1/2FIFOMode`), and new perf tracing (`TraceEn`, `TdHeaderPerfTraceEn`) — several unrelated subsystems landing in the same generation.
- **H18**: comparatively quiet here — only `TileOverlapPadReflect` is new. Combined with the already-documented ChCfg fp8/E4M3 addition, H18's real headline feature is fp8, not much else at the register level.
- **H19**: another big cluster — **multi-palette LUTs** (`MultiPaletteEnable`, `MultiPaletteSizeOneLut`, `PaletteGroupSize`) and a new **double-rate DMA mode** across L2 and Tile DMA (`L2Src1/2DmaDoubleRateMode`, `TileDmaSrc1/2DoubleRateMode`), on top of the bonded-networks work documented separately in [`GUIDE_H18G_H19_BONDED_NETWORKS.md`](GUIDE_H18G_H19_BONDED_NETWORKS.md).

**A genuine regression, not just additions.** `NEKeepKernel`/`NEUsePrevKernel` are `REAL` on H13, silently become `NOOP` on H14/H15, then the symbols disappear entirely (`n/a`) from H16 onward. Apple removed a working feature rather than just adding one — plausibly consolidated into `GroupKernelReuse`, which has been unconditionally `REAL` since H11 and covers similar ground.

**Permanently dead API surface** (present as symbols but never `REAL` on any of H11-H19): `2DWinogradMode`, `DP2AddMode`, `NEInputTranspose`, `ReswizzleConfigEn`, and `ReswizzleConfigKernelTranspose` always assert; `BroadcastCfg`, `L2Src2NumInterleavedChannels`, `L2SrcNumInterleavedChannels`, `L2DstNumInterleavedChannels`, `NEKBufBypEn`, `KernelDmaSrcKBufByp`, and `SplitRowCompute` never even get instantiated for any mapped chip. The same compiler binary also contains unmapped ISA versions (v1, v4, v10, v26, v28, v31, v36 — presumably internal/pre-H11 or unreleased future targets not in this repo's chip table); it's possible some of these become real there, which this table doesn't check.

**Known limitation — renames aren't tracked.** `TileDmaSrc2Interleave` shows `REAL` only at H15 and `n/a` everywhere else, which looks like a feature that vanished. It didn't: Apple renamed the setter to `SetTileDmaSrc2FormatMode` starting at H17 (folding the interleave value into a broader tensor-format enum parameter). Per-setter-name tracking can't see through renames — treat isolated single-generation `REAL` islands as a signal to grep for a renamed sibling before concluding the feature was removed.

## Future ISA Versions Beyond H19 (Unreleased)

ANECompiler contains no `TargetH20`/`TargetH21`/`TargetH22` and no literal "H20"/"H21"/"H22" string anywhere in the binary — there is no evidence of future chips using the established H-number scheme. There is, however, clear evidence of unreleased future hardware under a *different* naming scheme.

### New target classes

Beyond the H-series (`TargetH11` ... `TargetH19`, `TargetH18g`), the binary defines 9 additional `Target` subclasses with no H-number at all: `TargetM9`, `TargetT0`, `TargetT1`, `TargetU1`, `TargetU2`, `TargetU3`, `TargetU4`, `TargetM11`, `TargetM12`. Each has:
- a full constructor (`TargetM9::TargetM9()` etc.) following the exact same pattern as `TargetH18`/`TargetH19` (vtable setup, then a call into its own `ZinIrSocVariantParams::<Name>()` factory),
- its own `ZinIrSocVariantParams::M9()` / `T0()` / `T1()` / `U1()`-`U4()` / `M11()` / `M12()` factory function,
- its own typeinfo/vtable — these are not stubs or placeholders, they are fully linked-in classes.

`ZinIrSocVariantParams` also exposes a `GetSupportsLLM()` accessor as one of its per-chip capability fields, which is suggestive (though not proof) that some of these new targets are oriented around on-device LLM support rather than being a simple continuation of the M-series/H-series numbering (the M9-M12 names don't fit the established M1-M4 = H13-H16 mapping, and T-/U- prefixes haven't been used for ANE targets in this repo before).

**What we could not determine statically:** which of these 9 target classes maps to which ISA version below. Attempts that didn't pan out:
- Diffing the `Target` vtable slots for `TargetH19` vs `TargetU1` — the differing pointers turned out to belong to `std::shared_ptr` control-block internals (an artifact of how `Target` is held via `shared_ptr<ZinIrTarget>`), not real per-target virtual overrides.
- Diffing the `ZinIrSocVariantParams::<Name>()` factory bodies for a literal ISA-version constant — they only encode SoC/die parameters (DRAM channels, frequency tables, the `GetSupportsLLM` flag), not a compiler-target version number.
- No `CreateAneTd`/`SelectAneTd`-style dispatcher function exists that switches on target name to pick a `ZinAneTd<N>`; the binding is presumably data-driven elsewhere (e.g. a build-time flag or plist outside this framework).

### New ISA versions found

Separately from the target-class question, the binary contains four **fully-implemented, non-stub** ISA versions beyond H19's `ZinAneTd<24u>`: **v26, v28, v31, v36**. Each has its own complete vtable, typeinfo, and dedicated hardware register types (e.g. `ZinAneTdHw_v26`, `ane_common_cfg_small_source_mode_ssm_v28`, `_ane_ccdma_counter_address_lo_v28`) — these are genuine future generations' worth of compiler support, not speculative placeholders.

ICF-folding patterns suggest these four cluster into two pairs rather than four independent generations: v26 folds much of its code with v24/v28, while v31 and v36 diverge further — consistent with v26/v28 being two die variants of one future generation (analogous to H18/H18g) and v31/v36 being a subsequent generation.

#### What's new at each version (relative to H19 / v24)

Determined the same way as the rest of this document: comparing `ZinAneTd<Nu>::Set*` disassembly across versions, plus a direct diff of which setter *names* exist at all at each version vs. every H11-H19 version combined.

| Version | New setter names (never seen at H11-H19) | Previously-dead features that activate |
| :--- | :--- | :--- |
| **v26** | none | none — identical feature surface to v24; likely a die/config sibling rather than a real step forward |
| **v28** | 19 new setters — see below | `NEInputTranspose`, `ReswizzleConfigEn`, `ReswizzleConfigKernelTranspose` (all permanently `STUB` "not supported" since H11 through H19) |
| **v31** | none | keeps v28's three activations real; otherwise no further change vs v28 — looks like v28's successor/refinement, not its own wave |
| **v36** | 4 new setters — see below | `2DWinogradMode`, `DP2AddMode` (both permanently `STUB` "not supported" since H11 through v31) |

**v28's 19 new setters — a "UserSlot" DMA addressing layer**, spanning CCDMA, Kernel DMA, and all three Tile DMA engines:
- `SetCcdmaSrcUserSlotDim`, `SetCcdmaSrcUserSlotId`, `SetCcdmaSrcUserSlotMode`
- `SetCcdmaDstUserSlotDim`, `SetCcdmaDstUserSlotId`, `SetCcdmaDstUserSlotMode`
- `SetKernelDmaSrcUserSlotId`, `SetKernelDmaSrcUserSlotCoeffMode`
- `SetTileDmaDstUserSlotDim`, `SetTileDmaDstUserSlotId`, `SetTileDmaDstUserSlotMode`
- `SetTileDmaSrc1UserSlotDim`, `SetTileDmaSrc1UserSlotId`, `SetTileDmaSrc1UserSlotMode`
- `SetTileDmaSrc2UserSlotDim`, `SetTileDmaSrc2UserSlotId`, `SetTileDmaSrc2UserSlotMode`
- `SetTileDmaSrc2WaitEventAddr`, `SetTileDmaSrc2WaitEventValue`

This reads as an indirect "user slot" indexing scheme added across essentially every DMA engine at once, plus an explicit wait-event address/value pair specifically for `TileDmaSrc2` (the other DMA engines don't gain a wait-event setter at v28, only Src2 does).

**v36's 4 new setters — 4D strided addressing for TileDmaSrc2**:
- `SetTileDmaSrc2ChannelStride`, `SetTileDmaSrc2DepthStride`, `SetTileDmaSrc2GroupStride`, `SetTileDmaSrc2RowStride`

Curiosity: these exact setter names also exist at the unexplained `v1` (see "Unmapped ISA versions" below) and nowhere in between — the idea appears to have existed early, been dropped, and been revived at v36.

**Two long-dead features finally ship at v36**: `Set2DWinogradMode` and `SetDP2AddMode` had asserted "not supported" unconditionally on every version from H11 through v31 (part of this doc's "Permanently dead API surface" list above) — at v36 they become genuine `REAL` implementations for the first time.

### Summary

| | v26 | v28 | v31 | v36 |
| :--- | :--- | :--- | :--- | :--- |
| New DMA addressing setters | — | UserSlot layer (19 setters, CCDMA + Kernel DMA + all Tile DMA) | — | TileDmaSrc2 4D stride (4 setters) |
| Dead features revived | — | `NEInputTranspose`, `ReswizzleConfigEn`, `ReswizzleConfigKernelTranspose` | (inherits v28's) | `2DWinogradMode`, `DP2AddMode` |
| Relationship to neighbors | sibling of v24/v28 | own wave | successor of v28 | own wave |

## Full Table

| Feature | First Real | H11 | H12 | H13 | H14 | H15 | H16 | H17 | H18 | H19 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1DWinogradMode | H17 | STUB | STUB | STUB | STUB | STUB | STUB | REAL | REAL | REAL |
| 2DWinogradMode | never (through H19) | STUB | STUB | STUB | STUB | STUB | STUB | STUB | STUB | STUB |
| AlignedKernelPaletteLut | H13 | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| BroadcastCfg | never (through H19) | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| CacheDmaPreEnable | H15 | STUB | STUB | STUB | STUB | REAL | REAL | REAL | REAL | REAL |
| CcdmaAtomicEn | H11 | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| CropOffsetForTexture | H16 | n/a | n/a | n/a | n/a | n/a | REAL | REAL | REAL | REAL |
| CustomCodegenTd | H17 | n/a | n/a | n/a | n/a | n/a | n/a | REAL | REAL | REAL |
| DP2AddMode | never (through H19) | STUB | STUB | STUB | STUB | STUB | STUB | STUB | STUB | STUB |
| DoubleInt8Enable | H16 | STUB | STUB | STUB | STUB | STUB | REAL | REAL | REAL | REAL |
| FillLowerNEFirst | H14 | n/a | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL |
| GroupKernelReuse | H11 | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| KernelAsymQuantEn | H16 | STUB | STUB | STUB | STUB | STUB | REAL | REAL | REAL | REAL |
| KernelDetectZeros | H17 | STUB | STUB | STUB | STUB | STUB | STUB | REAL | REAL | REAL |
| KernelDmaSrcKBufByp | never (through H19) | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| KernelDmaSrcNoReuseHint | H14 | n/a | n/a | NOOP | REAL | REAL | n/a | n/a | n/a | n/a |
| KernelDmaSrcPaletteLutDmaCacheHint | H15 | n/a | n/a | DELEGATES | DELEGATES | REAL | REAL | REAL | REAL | REAL |
| KernelDmaSrcPaletteLutUserTag | H14 | NOOP | NOOP | NOOP | REAL | REAL | REAL | REAL | REAL | REAL |
| KernelPalettizedBits | H11 | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| KernelPalettizedEn | H11 | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| KernelSparseBinary | H13 | STUB | STUB | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| KernelSparseBlockSize | H14 | n/a | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL |
| KernelSparseFmt | H11 | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| L2BfrMode | H11 | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| L2DstNumInterleavedChannels | never (through H19) | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| L2ResultCfgForCompression | H15 | n/a | n/a | NOOP | NOOP | REAL | REAL | REAL | REAL | REAL |
| L2ResultInterleave | H11 | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| L2Src1CfgForCompression | H13 | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| L2Src1DmaDoubleRateMode | H19 | STUB | STUB | STUB | STUB | STUB | STUB | STUB | STUB | REAL |
| L2Src1FIFOMode | H17 | STUB | STUB | STUB | STUB | STUB | STUB | REAL | REAL | REAL |
| L2Src1Interleave | H11 | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| L2Src2CfgForCompression | H13 | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| L2Src2DmaDoubleRateMode | H19 | n/a | n/a | STUB | STUB | STUB | STUB | STUB | STUB | REAL |
| L2Src2FIFOMode | H17 | n/a | n/a | STUB | STUB | STUB | STUB | REAL | REAL | REAL |
| L2Src2Interleave | H14 | n/a | n/a | STUB | REAL | REAL | REAL | REAL | REAL | REAL |
| L2Src2NumInterleavedChannels | never (through H19) | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| L2SrcNumInterleavedChannels | never (through H19) | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| MultiPaletteEnable | H19 | STUB | STUB | STUB | STUB | STUB | STUB | STUB | STUB | REAL |
| MultiPaletteSizeOneLut | H19 | STUB | STUB | STUB | STUB | STUB | STUB | STUB | STUB | REAL |
| NEInputTranspose | never (through H19) | STUB | STUB | STUB | STUB | STUB | STUB | STUB | STUB | STUB |
| NEKBufBypEn | never (through H19) | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| NEKeepKernel | H13 | n/a | n/a | REAL | NOOP | NOOP | n/a | n/a | n/a | n/a |
| NEUsePrevKernel | H13 | n/a | n/a | REAL | NOOP | NOOP | n/a | n/a | n/a | n/a |
| OutputTranspose | H13 | NOOP | NOOP | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| PEBypass | H16 | n/a | n/a | n/a | n/a | n/a | REAL | REAL | REAL | REAL |
| PEIndexBroadcast | H15 | n/a | n/a | NOOP | NOOP | REAL | REAL | REAL | REAL | REAL |
| PEIndexTranspose | H15 | n/a | n/a | NOOP | NOOP | REAL | REAL | REAL | REAL | REAL |
| PEOutputCtoW | H13 | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| PEOutputQuantization | H16 | n/a | n/a | STUB | STUB | STUB | REAL | REAL | REAL | REAL |
| PESrc1Broadcast | H13 | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| PESrc1ReLu | H13 | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| PESrc1Transpose | H13 | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| PESrc2Broadcast | H13 | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| PESrc2ReLu | H13 | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| PESrc2Transpose | H13 | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| PaletteBlockSize | H17 | STUB | STUB | STUB | STUB | STUB | STUB | REAL | REAL | REAL |
| PaletteGroupSize | H19 | STUB | STUB | STUB | STUB | STUB | STUB | STUB | STUB | REAL |
| PassthroughEnable | H15 | STUB | STUB | STUB | STUB | REAL | REAL | REAL | REAL | REAL |
| PublishBit | H19 | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | REAL |
| QuantizationOutputZeroOffset | H16 | STUB | STUB | STUB | STUB | STUB | REAL | REAL | REAL | REAL |
| QuantizationSrc1InputOffset | H16 | n/a | n/a | STUB | STUB | STUB | REAL | REAL | REAL | REAL |
| QuantizationSrc2InputOffset | H16 | n/a | n/a | STUB | STUB | STUB | REAL | REAL | REAL | REAL |
| ReswizzleConfigEn | never (through H19) | STUB | STUB | STUB | STUB | STUB | STUB | STUB | STUB | STUB |
| ReswizzleConfigInputInterleave | H11 | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| ReswizzleConfigKernelBitDepth | H11 | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| ReswizzleConfigKernelTranspose | never (through H19) | STUB | STUB | STUB | STUB | STUB | STUB | STUB | STUB | STUB |
| SplitRowCompute | never (through H19) | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| TdHeaderPerfTraceEn | H17 | n/a | n/a | n/a | n/a | n/a | n/a | REAL | REAL | REAL |
| TextureBackgroundEn | H14 | n/a | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL |
| TextureBackgroundVal | H14 | n/a | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL |
| TextureBypassFilter | H19 | n/a | n/a | n/a | STUB | STUB | STUB | STUB | STUB | REAL |
| TextureCropBatchSplit | H16 | n/a | n/a | n/a | STUB | STUB | REAL | REAL | REAL | REAL |
| TextureCropCfg | H14 | n/a | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL |
| TextureCropCoeff | H14 | n/a | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL |
| TextureDepthValue | H14 | n/a | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL |
| TextureExtMax | H14 | n/a | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL |
| TextureFilter | H14 | n/a | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL |
| TextureGroupValue | H14 | n/a | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL |
| TextureIdxPermute | H14 | n/a | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL |
| TextureIndPermute | H14 | n/a | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL |
| TextureIndexTensorInterleave | H14 | n/a | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL |
| TextureMode | H14 | n/a | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL |
| TextureNormalization | H14 | n/a | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL |
| TexturePreserveFraction | H16 | n/a | n/a | n/a | STUB | STUB | REAL | REAL | REAL | REAL |
| TextureSrcPermute | H14 | n/a | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL |
| TextureWrap | H14 | n/a | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL |
| TileDmaDstAtomicEn | H13 | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| TileDmaDstCompressedInfo | H15 | n/a | n/a | STUB | STUB | REAL | REAL | REAL | REAL | REAL |
| TileDmaDstCompressedSize | H15 | n/a | n/a | NOOP | NOOP | REAL | REAL | REAL | REAL | REAL |
| TileDmaDstandL2DstFifoMode | H13 | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| TileDmaDstandL2DstInterleave | H13 | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| TileDmaSrc1CompressedInfo | H13 | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| TileDmaSrc1CompressedSize | H13 | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| TileDmaSrc1DoubleRateMode | H19 | n/a | n/a | STUB | STUB | STUB | STUB | STUB | STUB | REAL |
| TileDmaSrc1FIFOMode | H17 | n/a | n/a | STUB | STUB | STUB | STUB | REAL | REAL | REAL |
| TileDmaSrc1Interleave | H13 | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| TileDmaSrc2CompressedInfo | H15 | n/a | n/a | STUB | STUB | REAL | REAL | REAL | REAL | REAL |
| TileDmaSrc2CompressedSize | H13 | n/a | n/a | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
| TileDmaSrc2DoubleRateMode | H19 | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | REAL |
| TileDmaSrc2FIFOMode | H17 | n/a | n/a | n/a | n/a | n/a | n/a | REAL | REAL | REAL |
| TileDmaSrc2Interleave | H15 | n/a | n/a | n/a | n/a | REAL | n/a | n/a | n/a | n/a |
| TileDmaSrcCompressed2MdUserTag | H15 | NOOP | NOOP | NOOP | NOOP | REAL | REAL | REAL | REAL | REAL |
| TileDmaSrcCompressedMdUserTag | H14 | NOOP | NOOP | NOOP | REAL | REAL | REAL | REAL | REAL | REAL |
| TileOverlapPadReflect | H18 | n/a | n/a | STUB | STUB | STUB | STUB | STUB | REAL | REAL |
| TraceEn | H17 | n/a | n/a | n/a | n/a | n/a | n/a | REAL | REAL | REAL |
| UnicastEn | H11 | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL | REAL |
