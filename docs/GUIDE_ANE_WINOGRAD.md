# Technical Guide: Winograd Convolution in Apple Neural Engine

This guide documents how Winograd convolution is modeled, gated, and validated in Apple's ANE compiler stack (`ANECompiler`), based on static disassembly of the `ZinAneTd<Nu>::Set{1,2}DWinogradMode` setters and — more importantly — the `ZinValidateTd<Nu>::Validate1DWinograd` validation functions, which are where the real hardware/format contract actually lives. See [GUIDE_ANE_FEATURE_SUPPORT_BY_GENERATION.md](GUIDE_ANE_FEATURE_SUPPORT_BY_GENERATION.md) for how this fits into the broader per-generation feature timeline, and [`hwx_dump/h17_register_map.md`](../hwx_dump/h17_register_map.md) (or h18/h19) for the register-level `MacCfg` documentation this guide expands on.

---

## 1. Executive Summary

Apple's ANE supports a Winograd fast-convolution transform for specific small kernel/stride shapes, exposed as two independent hardware modes:

- **1D Winograd** (`MacCfg.Wino1D`) — first genuinely functional at **H17 (M5/A18, ISA v19)**. Stubbed out (unconditionally rejected) on every generation from H11 through H16.
- **2D Winograd** (`MacCfg` bit 26, at least on the newest known internal version) — a **permanently dead feature on every chip covered by this repo**: it is an unconditional `ZinAssertImpl("2D Winograd is not supported")` reject on H11 through H19, and on the two next known unreleased ISA versions (v26, v28, v31). It only gets a real, non-stub implementation at the newest known future ISA version, **v36**.

Critically, the `Set1DWinogradMode(bool)` **setter itself performs no validation at all** — it is a bare bitfield toggle. The actual hardware/format contract is enforced by a separate function, `ZinValidateTd<Nu>::Validate1DWinograd`, called during task-descriptor validation. That function is long (~15 distinct assert checks), and it is **far more restrictive than "just no fp8"**:

- Only three `(kernel_width, stride)` shapes are Winograd-eligible at all: `(3,1)`, `(5,2)`, `(6,2)`.
- Kernel/weight format: **E4M3 (fp8) is always hard-rejected. INT8 is only allowed when `double_int8` mode is enabled; UINT8 and FP16 are always allowed with no extra condition.** (An earlier pass at this analysis incorrectly concluded UINT8 was rejected — see the correction note in §4.)
- Activation/input format must be **INT8, UINT8, or FP16** — **E4M3 (fp8) is hard-rejected**, and FP16 is *additionally* disallowed whenever small-source-mode is active.
- Asymmetric quantization must be disabled; the op must be a plain `Conv` in `Kernel` mode; half-work-unit mode must be off (see §4.2 for what that is); and there's an accumulator-register budget check tied to the kernel/stride shape.
- At the newest known future version (**v36**), the kernel-format set widens further: **INT4 and a 2-bit-exponent MX-style mini-float (`e2_m1`) both become valid weight formats for Winograd**, alongside the newly-real UINT8/FP16/INT8(+double_int8) — see §4.1.

This logic is **byte-identical between H18 (v20) and H19 (v24)** — Apple has not changed Winograd's format contract since fp8 was introduced. The newest known future version (v36) restates the input-format check as a positive whitelist instead of an fp8-specific blacklist, but the practical effect (fp8 still excluded) is unchanged, and it adds one new gate (`dp2_add_en == 0`) tied to a feature that only becomes real at that same version.

---

## 2. Register-Level Model

### 2.1 Bit locations

| Field | Register | Bit | First real | Source |
| :--- | :--- | :--- | :--- | :--- |
| `Wino1D` (1D Winograd enable) | Common.`MacCfg` | 27 | H17 (v19) | `ane_hwx_regs.h` (`wino1d:1` in the H17/H18 `ane_common_h{17,18}_t::mac_cfg`); confirmed via `mov w8,#0x8000000` / `bfi` in `ZinAneTd<19u>::Set1DWinogradMode` |
| `Wino2D` (2D Winograd enable) | Common.`MacCfg` (or successor register) | 26 | v36 only | `mov w8,#0x4000000` in `ZinAneTd<36u>::Set2DWinogradMode`; unconfirmed on any documented HW register map since it's never real before v36 |

On H16, bit 27 of `MacCfg` is documented as padding (`pad3`, "1D Winograd unsupported in H16") — see `ane_hwx_regs.h` and the note already in `hwx_dump/h16_register_map.md`.

> [!NOTE]
> **Internal object offsets are not the same as HW register addresses.** The disassembly above reads/writes offsets like `[x0, #0x240]` (v19) or `[x0, #0x330]` (v36) — these are offsets into ANECompiler's *own in-memory* `ZinAneTd<N>` C++ object, not the ANE hardware register address space documented elsewhere in this repo (e.g. `0x4904` for `NE.MacCfg`). Don't conflate the two numbering spaces.
>
> At v36, `Set1DWinogradMode`/`Set2DWinogradMode` write to offset `0x330`, while `SetDoubleInt8Enable` (which shares bit 26 of the *hardware* `MacCfg.DoubleInt8En` field on every version through v31 — see `ane_ne_h1{6,7,8}_t::mac_cfg` in `ane_hwx_regs.h`) writes to a *different* offset, `0x66c`, at v36. So there's no bit collision between `DoubleInt8En` and `Wino2D` internally, but it also means v36's object layout has diverged enough that we can't assume its hardware register map matches H16-H19's without further work — this repo does not yet have a v36 register map.

### 2.2 Setter/getter symbols

| Symbol | Role |
| :--- | :--- |
| `ZinAneTd<Nu>::Set1DWinogradMode(bool)` | Writes `Wino1D` bit. Trivial toggle, no validation. |
| `ZinAneTd<Nu>::Set2DWinogradMode(bool)` | Writes `Wino2D` bit (v36+ only; unconditional assert reject on all earlier versions). |
| `ZinGetRegisterProgramming<Nu>::GetWinogradMode()` / `Get2DWinogradMode()` | Getter-side accessors (names only survive as literal strings in debug-log format strings; not independently disassembled for this guide). |
| `ZinValidateTd<Nu>::Validate1DWinograd(const ZinAneTdHw_vN&, bool)` | **The real gate** — see §4. |

---

## 3. Generational Support History

| Chip | ISA version | 1D Winograd | 2D Winograd |
| :--- | :--- | :--- | :--- |
| H11-H12 | v5, v6 | STUB | STUB |
| H13-H16 | v7, v11, v8, v17 | STUB | STUB |
| **H17** (M5/A18) | v19 | **REAL** | STUB |
| H18 (A19) | v20 | REAL | STUB |
| H18g (M6) / H19 (A20 Pro) | v24 | REAL | STUB |
| *unreleased* | v26, v28, v31 | REAL | STUB |
| *unreleased* | v36 | REAL | **REAL** |

(Cross-reference: `hwx_dump/feature_support.csv` and the curated table in [GUIDE_ANE_FEATURE_SUPPORT_BY_GENERATION.md](GUIDE_ANE_FEATURE_SUPPORT_BY_GENERATION.md).)

2D Winograd's assert string is unconditional and version-independent: `"2D Winograd is not supported"`. It shares one ICF-folded address across every version from H11 through v31 — this is not a per-generation nuance, it is simply dead code for eleven ISA versions in a row.

---

## 4. The Real Gate: `Validate1DWinograd` Decompiled

Reconstructed from `ZinValidateTd<20u>::Validate1DWinograd` (H18) by resolving each conditional branch's `.cold.N` assert target back to its embedded condition string — these strings are the literal C++ source expressions Apple's assert macro captured, so this is close to a genuine decompile rather than a guess. **Byte-identical logic exists at `ZinValidateTd<24u>` (H19).**

```cpp
// ZinValidateTd<20u>::Validate1DWinograd  (== ZinValidateTd<24u>, byte-identical)
bool Validate1DWinograd(const ZinAneTdHw_v20& hw, bool double_int8) {
    // --- Accumulator-register budget: ONE computed cost value, checked against
    // ONE of three thresholds (32/16/8), selected by a 2-bit mode field and a
    // 3-bit format-ish field. These are ALTERNATIVE branches, not four
    // sequential checks -- at most one of the three assert sites below can
    // fire for a given task descriptor.
    //
    // acc_regs   = ubfx([0x24c],13,2) * lsr([0x248],30)      // umull #1
    //            * ubfx([0x248],28,2)                          // umull #2
    //            * (skd << ([0x260] & 0x7))                    // skd from the
    //                                                            // first SubchannelKernelDimension call, see below
    //   acc_regs = acc_regs * (ubfx([0x25c],27,1) + 1)          // madd: +0 or +1x
    //   mode_sel = ubfx([0x25c], 2, 2)          // 2-bit selector
    //   fmt_sel  = [0x220] & 0x7                // 3-bit field, reused later as in_fmt
    if (mode_sel == 1) {
        if (acc_regs > 32) return false;                 // cold.3: "required_acc_regs_per_mac <= 32"
    } else if (fmt_sel >= 2) {
        if (acc_regs > 16) return false;                 // cold.2: "required_acc_regs_per_mac <= 16"
    } else /* fmt_sel < 2 */ {
        if (acc_regs >= 9) return false;                 // cold.1: "required_acc_regs_per_mac <= 8"
    }

    // op_mode check is itself conditional -- only reached when ubfx([0x25c],27,1)
    // (the same bit that adds +1x to acc_regs above) is set. When that bit is
    // clear, op_mode is never checked at all on this path.
    if (ubfx_0x25c_bit27 != 0 && hw.ne_config.mac_cfg.op_mode != Conv) return false;  // cold.4

    // skd/skh = perfmodel::SubchannelKernelDimension(...), called twice with
    // different bit-slices of the same packed register at [0x24c]/[0x248]:
    //   skd (sub-kernel depth)  = SubchannelKernelDimension(ubfx([0x24c],6,2), ubfx([0x24c],13,2), [0x24c]&0x1f, ubfx([0x24c],8,4))
    //   skh (sub-kernel height) = SubchannelKernelDimension(ubfx([0x248],6,6)... , lsr([0x248],30), ubfx([0x248],15,2), ubfx([0x248],22,5))
    // skd is computed unconditionally at function entry (used above); skh is
    // computed later, only once the (kernel_width, stride) shape check below passes.
    if (!(skd == 1 || !double_int8)) return false;  // cold.15: "skd == 1 || !double_int8"

    // Shared cold-path with ValidateOnTheFlySparseEncoding<20u>
    if (hw.ne_config.mac_cfg.kernel_mode != Kernel) return false;

    // Only these three (kernel_width, stride) shapes are Winograd-eligible
    if (!((kw == 3 && sx == 1) ||
          (kw == 5 && sx == 2) ||
          (kw == 6 && sx == 2)))
        return false;

    if (!(skh <= 5)) return false;

    if (!(hw.ne_config.kernel_cfg.sparse_fmt == 0 ||
          (!double_int8 && in_fmt != FP16) ||
          hw.ne_config.kernel_cfg.detect_zeros == 1))
        return false;

    if (hw.ne_config.kernel_cfg.asym_quant_en != 0) return false;

    // ssm: ZinSmallSourceMode enum = [Normal=0, SSM=1, SSM_Tiny=2, NP2_6=3,
    // NP2_10=4, SSM_Diminutive=5]. Note ssm==SSM(1) satisfies NEITHER disjunct
    // (ssm==Normal is false, and ssm>1 is false) -- so ssm==SSM is an
    // UNCONDITIONAL reject regardless of in_fmt, distinct from the other four
    // non-Normal modes, which are allowed but only for in_fmt < 2 (INT8/UINT8).
    if (!(ssm == Normal || (ssm > 1 /* Tiny, NP2_6, NP2_10, Diminutive */ && in_fmt < 2))) return false;

    // Weight format: reachable only when kernel_fmt == INT8 (0) -- the
    // `cbnz` guarding this branch skips it entirely for UINT8/FP16/anything
    // else. So this is NOT "INT8 is fine, everything else is checked"; it's
    // "INT8 requires double_int8, and nothing else is gated here at all."
    if (hw.ne_config.kernel_cfg.kernel_fmt == Int8 && !double_int8) return false;

    if (hw.common_config.ch_cfg.in_fmt == E4M3) return false;   // activation fmt

    if (hw.common_config.ne_cfg.half_wu != 0) return false;

    return true;  // Winograd is valid for this task descriptor
}
```

> [!IMPORTANT]
> **Correction to an earlier pass at this analysis.** The disassembly contains a branch whose `.cold` function embeds the string `"kernel_fmt != ane_ne_kernel_cfg_kernel_fmt_uint8_v20"`, and it is only reachable when `kernel_fmt == INT8 (0)` — the code explicitly skips this branch (`cbnz w8, [skip]`) for every other `kernel_fmt` value, including UINT8. Read literally, the embedded string says "reject unless UINT8"; read from the actual control flow, the real condition is "reject INT8 unless `double_int8` is set." These are different assertions. The most likely explanation is that the compiler merged two textually-different `assert()` call sites (from different source lines) into one shared `.cold` block during optimization, keeping only one of the two original strings. **Do not trust an embedded assert string in isolation — always trace the branch condition that reaches it.** This is corrected in the pseudocode above: UINT8 and FP16 kernel/weight formats are **not** gated by this check at all, and pass through unconditionally.
>
> The same caveat applies in reverse to the accumulator-budget block above: the three thresholds (32/16/8) are correctly attributed to distinct `.cold` sites with distinct, self-consistent strings (`<= 32`, `<= 16`, `<= 8`), confirmed by resolving each `.cold.N` independently — so unlike the kernel_fmt case, there is no mislabeling here, just a branchy/alternative structure that a flat sequential reading of the disassembly obscures.

### 4.1 What changes at v36

`ZinValidateTd<36u>::Validate1DWinograd` reorders/restates a few checks but keeps the same shape:

- The input-format check becomes a **positive whitelist** instead of an fp8-specific blacklist:
  `in_fmt == UInt8 || in_fmt == SInt8 || in_fmt == FP16` — E4M3 is still excluded, just by omission rather than by name. (This one *is* a direct comparison against the real `in_fmt`-carrying register, not a suspect shared cold-path — verified by tracing `cmp w23, #3` back to the same field read used for the dimension-format checks earlier in the function.)
- The kernel-format gate widens into an explicit `kfmt_allowed` membership check, traced directly (not from a suspect string) in `ZinValidateTd<36u>::Validate1DWinograd`'s disassembly at `0x20bb8fd78`:
  ```cpp
  uint32_t kfmt = hw.ne_config.kernel_cfg.kernel_fmt;   // now effectively a 3-bit field
  if (kfmt > 5 || kfmt == E4M3 /* == 3 */) return false;         // kfmt_allowed fails
  if (kfmt == Int8 /* == 0 */ && !double_int8) return false;     // same shared-cold-path pattern as v20/v24
  // kfmt == UInt8(1), FP16(2), Int4(4), or E2M1/MX(5): all pass through unconditionally
  ```
  Cross-referencing `ZinAneTd<36u>::SetKernelFmt(ZinHWKernelFmt)` (which maps enum value directly 1:1 onto this raw 3-bit field, and — unlike `ZinAneTd<20u>::SetKernelFmt`, which calls `ZinAssertImpl("Unsupported kernel format")` for enum values 4 and 5 — actually *writes* values 4 and 5 to hardware) plus the binary's own generic condition string `"kernel_fmt == ...int4 || kernel_fmt == ...e2_m1"`, values 4 and 5 are almost certainly **INT4** and a 2-bit-exponent MX-style mini-float (**e2_m1**), respectively. A separate v36-specific string, `"kernel_fmt != ...fp16 && kernel_fmt != ...bf16"`, additionally suggests **BF16** is a new named kernel format at v36, though its raw numeric value wasn't pinned down here. **So at v36, Winograd's weight-format eligibility set expands to `{UINT8, FP16, INT4, E2M1/MX}` unconditionally, plus `INT8` when `double_int8` is set** — a real capability expansion, not just format bookkeeping.
- One new gate is added: `hw.common_config.ne_cfg.dp2_add_en == 0` — consistent with `DP2AddMode` also only becoming real at v36 (see the feature-support guide's "permanently dead API surface" list).
- `ValidateHalfWUMode<36u>` (chained immediately after) additionally checks `wu_stack == 0`, re-checks `winograd1_d_en == 0` (see caveat below), `sh_max <= 3`, and a small-source-mode compatibility condition.

> [!NOTE]
> **The `winograd1_d_en == 0` check inside `ValidateHalfWUMode` looks contradictory** — a function chained from *inside* Winograd validation asserting Winograd is *not* enabled. Two readings are possible: (a) it's validating a different code path that also calls into `ValidateHalfWUMode` where Winograd must indeed be off, and the shared cold-path/tail-call structure makes it look like it's inside `Validate1DWinograd` when it isn't quite; or (b) it's a genuine mutual-exclusion check for some other feature combination. Not fully resolved — flagged here rather than guessed at. It is at least consistent with §4.2 below: HalfWU and Winograd are mutually exclusive, so a validator that touches both re-asserting "Winograd must be off" while validating HalfWU-adjacent state isn't surprising, even if the exact code path is unclear.

### 4.2 What `half_wu` actually is

The `hw.common_config.ne_cfg.half_wu != 0` check in §4's pseudocode refers to **Half Work Unit mode**, a separate NE throughput optimization — mutually exclusive with Winograd, but not a Winograd-specific concept, so it's worth explaining on its own.

ANE's NE processes convolutions in chunks called *work units*, sized by `ne_cfg.ocg_size` (output-channel-group size) and `ne_cfg.wu_stack`/`wu_stack_log2` (how many work units are pipelined per pass) — see `ane_hwx_regs.h`. When a tensor's channels/spatial dims don't evenly fill a full work unit, part of the MAC array sits idle for that pass. **Half Work Unit mode processes at half the normal work-unit granularity**, so small/narrow tensors that would otherwise underfill a full work unit can be packed more efficiently instead of wasting half the array.

- **Setter**: `ZinAneTd<Nu>::SetNEHalfWUMode(ZinNamedType<bool, HalfWorkUnitModeTag>)` — shared stub across v1 through v19 (H11-H17), first real at **v20 (H18/A19)**. Same generational landing point as fp8 and the ChCfg format widening.
- **Eligibility gate**: `ZinMirConvUtils::CanUseHalfWorkUnitMode(const ZinIrHalParameters&, ZinTensorFormat, ZinSmallSourceMode, bool, bool, size_t, optional<size_t>)`. Decompiled from its disassembly:
  ```cpp
  bool CanUseHalfWorkUnitMode(hal_params, ch_format, ssm, fat_tile_enable,
                               multicast /*likely*/, wu_stack_log2, max_src_width) {
      if (hal_params.supports_half_wu != 1) return false;  // per-SoC-variant HAL capability flag

      hw_fmt = GetHWChannelFormat(ch_format);
      if (!((1 << hw_fmt) & 0b10011)) return false;   // fmt must be in {0, 1, 4} -- NOT FP16

      if ((ssm & ~0x4) != 0) return false;             // ssm must be Normal(0) or NP2_6(bit 2 set)
      if (fat_tile_enable) return false;
      if (multicast) return false;
      if (wu_stack_log2 != 0) return false;             // wu_stack must be exactly 1

      if (max_src_width.has_value())
          return *max_src_width <= hal_params.half_wu_np2_6_max_src_width_inclusive;
      return true;
  }
  ```
  This matches the binary's own strings word-for-word: `"RasterizeWorkUnit: FP16 input is not supported for HalfWU"`, `"Small source mode SSM/NP2_10 is not supported for HalfWU"`, `"RasterizeWorkUnit: Multicast is not supported for HalfWU"`, and `"wu_stack must be 1 when half_wu is true"`.
- **Cost model**: even when legal, `ZinMirConvUtils::IsHalfWUBeneficial(...)` separately decides whether it's *worth* using — its disassembly does real floating-point cycle-count math (`perfmodel::DivRoundUp`, `fdiv`/`fcmp` comparing estimated cycles with vs. without HalfWU) rather than a simple heuristic. Same opt-in-when-beneficial pattern as Winograd's own cost model in §6.

Winograd and HalfWU both restructure how the kernel/output are tiled across the MAC array, in incompatible ways — hence `Validate1DWinograd` requiring `half_wu == 0`.

---

## 5. Format Compatibility Matrix

Derived directly from §4 (consistent across H18, H19, and the newest known future version):

| | Kernel / weight format (`kernel_cfg.kernel_fmt`) | Activation / input format (`ch_cfg.in_fmt`) |
| :--- | :--- | :--- |
| **INT8** | ✅ allowed **only with `double_int8` mode enabled** | ✅ allowed under `Normal` or `SSM_Tiny`/`NP2_6`/`NP2_10`/`SSM_Diminutive`; ❌ rejected under `SSM` specifically |
| **UINT8** | ✅ allowed unconditionally | ✅ allowed under `Normal` or `SSM_Tiny`/`NP2_6`/`NP2_10`/`SSM_Diminutive`; ❌ rejected under `SSM` specifically |
| **FP16** | ✅ allowed unconditionally | ✅ allowed under `Normal` only — ❌ rejected under **any** non-`Normal` small-source-mode (`SSM`, `SSM_Tiny`, `NP2_6`, `NP2_10`, `SSM_Diminutive` all reject FP16, not just `SSM`) |
| **E4M3 (fp8)** | ❌ rejected | ❌ rejected |
| **INT4** (v36 only) | ✅ allowed unconditionally | not applicable (activation-side INT4 not checked here) |
| **E2M1 / MX** (v36 only) | ✅ allowed unconditionally | not applicable |

The activation-format column depends on `ZinSmallSourceMode` (`ssm`): the check is `ssm == Normal || (ssm > 1 && in_fmt < 2)`. Since the enum is `[Normal=0, SSM=1, SSM_Tiny=2, NP2_6=3, NP2_10=4, SSM_Diminutive=5]`, `ssm == SSM (1)` satisfies neither disjunct and is **always** rejected regardless of format — it's not merely "FP16 restricted under small-source-mode," `SSM` mode itself is entirely incompatible with Winograd, while the *other four* non-Normal modes are allowed but only for INT8/UINT8 activations.

Additional non-format requirements that gate Winograd regardless of format: `(kernel_width, stride) ∈ {(3,1), (5,2), (6,2)}` only, `op_mode == Conv` (conditionally checked — see §4), `kernel_mode == Kernel`, asymmetric quantization disabled, half-work-unit mode disabled, and an accumulator-register budget (32/16/8, selected by mode/format fields, not simultaneous) tied to the kernel/stride shape.

---

## 6. Compiler-Level Decision Logic (Cost Model)

Even when a convolution is Winograd-*eligible* per §4-5, ANECompiler doesn't always choose to use it — Winograd trades a kernel-size "inflation" (transforming the kernel into a larger effective footprint) for fewer MACs, and that's only a net win for some shapes. This decision lives one layer above the hardware-validation code, in the MLIR-level optimization passes:

- `ZinMirOpt::EnableLargeKernelModeFor1DWinograd(ZinIrControlFlowGraph*, const ZinIrParameters&)` — the pass that actually flips `Set1DWinogradMode` on eligible ops.
- `ZinMirOpt::ComputeKernelInflationRatioByEnabling1DWinograd(const ZinKernelDescriptor&)` and `ZinMirOpt::IsWorthEnabling1DWinogradAtExpenseOfKernelInflation(const ZinIrParameters&, const ZinNEConvLayer*, float)` — the actual cost model: computes how much larger the effective kernel becomes and decides whether the MAC-count savings are worth it.
- `ZinNEConvLayer::CanUseWinogradMode(...)`, `UseWinogradOverDirectConv(...)`, `UseWinogradOverDoubleBuffer(...)`, and `ShouldEnableWinogradMode(...)` — layer-level plumbing that feeds tensor format/dimensions/small-source-mode into the eligibility+cost decision and picks Winograd vs. direct convolution vs. double-buffered convolution as the final codegen strategy.

There is also an explicit **opt-out compiler flag**: `ZinIrCompilerParameters::setDisableWinograd(bool)`, exposed as the `disable-winograd` / `DisableWinograd` command-line/debug flag (`Disable 1D Winograd Mode: %d` is the corresponding debug-log line). This suggests Winograd is *opt-in-by-default-but-overridable* at the compiler level, separate from the hardware eligibility checks in §4.

### 6.1 MLIR representation

Winograd also exists as a first-class op in the `anehlo` MLIR dialect: `polylang::anehlo::WinogradOp`, built via `LLIR::AneHloEmitter::EmitWinograd(mlir::Block*)`. It's a `ZeroRegions`/`ZeroResults`/`ZeroSuccessors`/`ZeroOperands` op that must have `ConvOp` as its parent (`OpTrait::HasParent<ConvOp>`) — i.e. it's a modifier attached to a convolution op in the IR, not a standalone op, consistent with Winograd being a *mode* of an existing conv rather than a distinct operation.

---

## 7. Open Questions

- ~~v36's `kfmt_allowed` helper~~ — **resolved**: traced to a widened kernel-format membership check allowing UINT8/FP16/INT4/E2M1(MX), rejecting only E4M3 and out-of-range values (§4.1).
- ~~What `skd`/`skh` are~~ — **resolved**: both are the return value of `perfmodel::SubchannelKernelDimension(...)`, called twice with different bit-slices of the packed registers at `[0x24c]` (depth) and `[0x248]` (height) — see §4.
- ~~Whether the accumulator-budget checks (32/16/8) are simultaneous or alternative~~ — **resolved**: they are alternative branches over a single computed cost value, selected by a 2-bit mode field (`ubfx([0x25c],2,2)`) and a 3-bit format field (`[0x220]&0x7`); at most one threshold applies per task descriptor — see §4.
- ~~The exact `ssm`/`in_fmt` edge case for `ssm==1`~~ — **resolved**: `ZinSmallSourceMode` enum is `[Normal, SSM, SSM_Tiny, NP2_6, NP2_10, SSM_Diminutive]`; `ssm==SSM(1)` is unconditionally rejected (satisfies neither disjunct of `ssm==Normal || (ssm>1 && in_fmt<2)`), while `SSM_Tiny`/`NP2_6`/`NP2_10`/`SSM_Diminutive` are allowed only for INT8/UINT8 — see §4 and §5.
- **Independent re-verification of the shared-cold-path risk for two other checks** (`kernel_mode != Kernel`, and the `sparse_fmt`/`in_fmt`/`detect_zeros` compound condition) — these were resolved by string-resolution alone, not by tracing branch reachability the way the mislabeled `kernel_fmt != uint8` case was caught; not yet independently re-verified for the same mislabeling risk.
- **The exact numeric identity of v36 kernel-format values 4 and 5** — inferred as INT4 and E2M1/MX respectively from `SetKernelFmt<36u>`'s identity mapping plus generic condition strings elsewhere in the binary, but not confirmed against a definitive enum-to-name table.
- **2D Winograd's actual format contract at v36** — no dedicated `ZinValidateTd<36u>::Validate2DWinogradMode` (or similarly named) symbol was found; whatever validates it may be folded into `Validate1DWinograd` or into a generic codegen path not yet identified.
- **The `ValidateHalfWUMode<36u>` cross-check on `winograd1_d_en`** (§4.1) — flagged as unresolved, not explained.
- **No local `.hwx` samples exist for H17/H18/H19** in this repo to empirically confirm Winograd's on-the-wire register encoding the way H13/H16 findings elsewhere in this repo have been confirmed against real compiled models. Everything in this guide is derived from static ANECompiler disassembly only.
