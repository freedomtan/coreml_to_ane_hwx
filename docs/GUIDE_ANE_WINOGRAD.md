# Technical Guide: Winograd Convolution in Apple Neural Engine

This guide documents how Winograd convolution is modeled, gated, and validated in Apple's ANE compiler stack (`ANECompiler`), based on static disassembly of the `ZinAneTd<Nu>::Set{1,2}DWinogradMode` setters and — more importantly — the `ZinValidateTd<Nu>::Validate1DWinograd` validation functions, which are where the real hardware/format contract actually lives. See [GUIDE_ANE_FEATURE_SUPPORT_BY_GENERATION.md](GUIDE_ANE_FEATURE_SUPPORT_BY_GENERATION.md) for how this fits into the broader per-generation feature timeline, and [`hwx_dump/h17_register_map.md`](../hwx_dump/h17_register_map.md) (or h18/h19) for the register-level `MacCfg` documentation this guide expands on.

---

## 1. Executive Summary

Apple's ANE supports a Winograd fast-convolution transform for specific small kernel/stride shapes, exposed as two independent hardware modes:

- **1D Winograd** (`MacCfg.Wino1D`) — first genuinely functional at **H17 (M5/A18, ISA v19)**. Stubbed out (unconditionally rejected) on every generation from H11 through H16.
- **2D Winograd** (`MacCfg` bit 26, at least on the newest known internal version) — a **permanently dead feature on every chip covered by this repo**: it is an unconditional `ZinAssertImpl("2D Winograd is not supported")` reject on H11 through H19, and on the two next known unreleased ISA versions (v26, v28, v31). It only gets a real, non-stub implementation at the newest known future ISA version, **v36**.

Critically, the `Set1DWinogradMode(bool)` **setter itself performs no validation at all** — it is a bare bitfield toggle. The actual hardware/format contract is enforced by a separate function, `ZinValidateTd<Nu>::Validate1DWinograd`, called during task-descriptor validation. That function is long (~15 distinct assert checks), and it is **far more restrictive than "just no fp8"**:

- Only three `(kernel_width, stride)` shapes are Winograd-eligible at all: `(3,1)`, `(5,2)`, `(6,2)`.
- Kernel/weight format: **E4M3 (fp8) is always hard-rejected. UINT8 (raw `kernel_fmt` value 0) is only allowed when `double_int8` mode is enabled; INT8 (raw value 1) and FP16 are always allowed with no extra condition.** (Two corrections to earlier passes at this analysis, both in §4: which raw value the `double_int8` requirement gates, and — found later, via empirical verification against real compiled `.hwx` output — that raw `kernel_fmt` 0/1 mean UINT8/INT8 respectively, the reverse of this guide's original assumption.)
- Activation/input format must be **INT8, UINT8, or FP16** — **E4M3 (fp8) is hard-rejected**, and FP16 is *additionally* disallowed whenever small-source-mode is active.
- Asymmetric quantization must be disabled; the op must be a plain `Conv` in `Kernel` mode; half-work-unit mode must be off (see §4.2 for what that is); and there's an accumulator-register budget check tied to the kernel/stride shape.
- At the newest known future version (**v36**), the kernel-format set widens further: **INT4 and `e2_m1` (a 2-bit-exponent mini-float) both become valid weight formats for Winograd**, alongside the newly-real UINT8/FP16/INT8(+double_int8) — see §4.1. (Separately, v36 also adds true MX/microscaled formats, but as an orthogonal field never checked by Winograd's validator — not part of this eligibility set; see §4.1's correction note.)

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

    // Shared cold-path with ValidateOnTheFlySparseEncoding<20u> -- RE-VERIFIED
    // (not just string-trusted): bit3 of the byte at [0x4d0] is tested directly,
    // immediately adjacent to the op_mode bits (0-2) tested above via `tst w8,#0x7`.
    // Same byte, adjacent bitfield -- this one is NOT mislabeled.
    if (hw.ne_config.mac_cfg.kernel_mode != Kernel) return false;

    // Only these three (kernel_width, stride) shapes are Winograd-eligible
    if (!((kw == 3 && sx == 1) ||
          (kw == 5 && sx == 2) ||
          (kw == 6 && sx == 2)))
        return false;

    if (!(skh <= 5)) return false;

    // --- sparse_fmt / asym_quant_en / ssm: ALSO alternative branches, not three
    // independent sequential ifs, and re-using the SAME (mode_sel, fmt_sel)
    // selector pair from the accumulator-budget block above:
    if (mode_sel == 1 || fmt_sel >= 2) {
        // ssm: ZinSmallSourceMode enum = [Normal=0, SSM=1, SSM_Tiny=2, NP2_6=3,
        // NP2_10=4, SSM_Diminutive=5]. ssm==SSM(1) satisfies NEITHER disjunct
        // (ssm==Normal is false, and ssm>1 is false) -- so ssm==SSM is an
        // UNCONDITIONAL reject, distinct from the other four non-Normal modes,
        // which are allowed but only for in_fmt < 2 (INT8/UINT8).
        if (!(ssm == Normal || (ssm > 1 /* Tiny, NP2_6, NP2_10, Diminutive */ && in_fmt < 2)))
            return false;  // cold.8
    } else if (bit24_of_0x4cc != 0) {
        if (hw.ne_config.kernel_cfg.asym_quant_en != 0) return false;  // cold.9
    } else {
        // The `(reg & 0x1fffff00) & 0xf00001ff == 0x100` pattern fully decodes:
        // 0x1fffff00 = bits[8:28], 0xf00001ff = bits{0-8, 28-31}; intersected,
        // only bit8 and bit28 survive. So the test is exactly `bit8==1 && bit28==0`
        // on the same register ([0x4cc] at v20/24, [0x65c] at v36) that also
        // carries kernel_fmt (bits 0-1/0-2) and asym_quant_en (bit24):
        //   bit8  = sparse_fmt   (nonzero/"enabled" bit -- bit8==1 means sparse_fmt!=0)
        //   bit28 = detect_zeros (bit28==0 means detect_zeros!=1)
        // The remaining `cbz w8` (w8 built via a csinc from double_int8 and a
        // `cmp in_fmt,#2` (FP16)) collapses to exactly "double_int8 || in_fmt==FP16",
        // i.e. the negation of "!double_int8 && in_fmt != FP16". Reject fires
        // only when ALL THREE of the assert string's disjuncts are false at
        // once -- fully consistent, bit-for-bit, with the literal cold.14 string.
        if (!(hw.ne_config.kernel_cfg.sparse_fmt == 0 ||
              (!double_int8 && in_fmt != FP16) ||
              hw.ne_config.kernel_cfg.detect_zeros == 1))
            return false;  // cold.14
    }

    // Weight format: reachable only when kernel_fmt == UINT8 (raw 0) -- the
    // `cbnz` guarding this branch skips it entirely for INT8/FP16/anything
    // else. So this is NOT "UINT8 is fine, everything else is checked"; it's
    // "UINT8 requires double_int8, and nothing else is gated here at all."
    // RE-VERIFIED by tracing the actual guard bits (not just string-trust):
    // reached exactly when `double_int8==false` (tested via `tbnz w20,#0`,
    // where x20 == the function's own `double_int8` argument) AND the raw
    // 2-bit kernel_fmt field at `[0x4cc] & 0x3 == 0`.
    // *** raw 0 = UINT8, raw 1 = INT8 -- see the [!IMPORTANT] correction below;
    // this reverses an assumption held throughout every earlier pass at this guide. ***
    if (hw.ne_config.kernel_cfg.kernel_fmt == UInt8 && !double_int8) return false;  // cold.10

    // Separate, unconditional check missing from earlier passes at this guide:
    // kernel_fmt == E4M3 is rejected outright, regardless of double_int8.
    if (hw.ne_config.kernel_cfg.kernel_fmt == E4M3) return false;  // cold.13

    if (hw.common_config.ch_cfg.in_fmt == E4M3) return false;  // cold.12, activation fmt

    if (hw.common_config.ne_cfg.half_wu != 0) return false;  // cold.11

    return true;  // Winograd is valid for this task descriptor
}
```

> [!IMPORTANT]
> **Correction to an earlier pass at this analysis.** The disassembly contains a branch whose `.cold` function embeds the string `"kernel_fmt != ane_ne_kernel_cfg_kernel_fmt_uint8_v20"`, and it is only reachable when the raw `kernel_fmt` register field equals 0 — the code explicitly skips this branch (`cbnz w8, [skip]`) for every other `kernel_fmt` value. Read literally, the embedded string says "reject unless UINT8"; read from the actual control flow, the real condition is "reject raw-value-0 unless `double_int8` is set." **This turns out to be entirely consistent, not mislabeled** — see the second correction below: raw `kernel_fmt` value 0 genuinely *is* UINT8, and value 1 is INT8, the reverse of what every earlier pass at this guide (including the original version of this very note) assumed. So the embedded string was right all along; what was wrong was this guide's own name-to-raw-value mapping. The pseudocode above is corrected accordingly: UINT8 (raw 0) requires `double_int8`; INT8 (raw 1) and FP16 pass through unconditionally.
>
> [!IMPORTANT]
> **Second correction, found via empirical verification against real compiled `.hwx` output (see the "No local samples" item in §7): `kernel_fmt` raw value 0 is UINT8, and raw value 1 is INT8 — the reverse of the ordering this guide (and this repo's `hwx_dump/hwx_parsing.py::get_ch_fmt_name`) assumed throughout.** This was pinned down definitively by decompiling `GetHWKernelFormat(ZinKernelFormat, ZinHWKernelFmt&)` (`0x20bbbd214`) — the actual compiler function that translates the IR-level `ZinKernelFormat` enum into this exact hardware register field. Its jump table is exhaustive and unambiguous:
> ```
> ZinKernelFormat::int8  (IR raw 1) -> hw kernel_fmt = 1
> ZinKernelFormat::uint8 (IR raw 2) -> hw kernel_fmt = 0
> ZinKernelFormat::fp16  (IR raw 4) -> hw kernel_fmt = 2
> ZinKernelFormat::e4m3  (IR raw 5) -> hw kernel_fmt = 3
> ZinKernelFormat::int4  (IR raw 31)-> hw kernel_fmt = 4
> ZinKernelFormat::e2m1  (IR raw 41)-> hw kernel_fmt = 5
> ```
> (values 2-5 were already correct in this guide; only the 0/1 pair was swapped.) Confirmed three independent ways: (1) this jump table itself, (2) LLDB-tracing 824 real calls to `ZinMirConvUtils::CanUseWinogradMode` during an actual compile of `ResNet50SymmetricPerChannel.mlpackage` (a real W8A8 model) — every single call passed IR `kernel_fmt=1`, and `ZinKernelFormatGetName(1)` resolves to `"int8"`, matching the model's own MIL source (`output_dtype = "int8"`, signed, as expected for symmetric per-channel quantization), and (3) the resulting compiled `.hwx` for H17/H18/H19 shows raw hardware `kernel_fmt=1` on every one of its Winograd-enabled tasks — which, per the corrected mapping, is INT8, exactly matching the model's real weight dtype. `hwx_dump/hwx_parsing.py`'s existing `get_ch_fmt_name(1) -> "UINT8"` label is therefore likely wrong for the kernel-format field (it may be correct for the *activation*-side `ch_fmt`/`in_fmt` field, which has not yet been independently re-verified — flagged as a follow-up in §7, not assumed either way).
>
> **#3 follow-up (re-verification pass):** independently re-traced two other checks flagged as at-risk of the same mislabeling. `kernel_mode != Kernel` checks out fine — it's a direct, adjacent bitfield read, not a suspect shared string. The `sparse_fmt`/`asym_quant_en`/`ssm` trio turned out to have a *different* problem: they aren't mislabeled, but they *are* alternative branches (same `mode_sel`/`fmt_sel` selector reused from the accumulator-budget block), not three independent sequential `if`s as earlier drafts of this guide implied — restructured above. This pass also turned up a genuinely missing check (unconditional `kernel_fmt == E4M3` rejection, `cold.13`) that no earlier draft of this pseudocode included at all.
>
> The same caveat applies in reverse to the accumulator-budget block above: the three thresholds (32/16/8) are correctly attributed to distinct `.cold` sites with distinct, self-consistent strings (`<= 32`, `<= 16`, `<= 8`), confirmed by resolving each `.cold.N` independently — so unlike the kernel_fmt case, there is no mislabeling here, just a branchy/alternative structure that a flat sequential reading of the disassembly obscures.

### 4.1 What changes at v36

`ZinValidateTd<36u>::Validate1DWinograd` reorders/restates a few checks but keeps the same shape:

- The input-format check becomes a **positive whitelist** instead of an fp8-specific blacklist:
  `in_fmt == UInt8 || in_fmt == SInt8 || in_fmt == FP16` — E4M3 is still excluded, just by omission rather than by name. (This one *is* a direct comparison against the real `in_fmt`-carrying register, not a suspect shared cold-path — verified by tracing `cmp w23, #3` back to the same field read used for the dimension-format checks earlier in the function. **`in_fmt`'s raw 0/1 ordering is now confirmed via `GetHWChannelFormat` (§7): raw 0 = UInt8, raw 1 = Int8 — the same convention as `kernel_fmt`, not an independent swap — so the `UInt8`/`SInt8` naming here is accurate.**)
- The kernel-format gate widens into an explicit `kfmt_allowed` membership check, traced directly (not from a suspect string) in `ZinValidateTd<36u>::Validate1DWinograd`'s disassembly at `0x20bb8fd78`:
  ```cpp
  uint32_t kfmt = hw.ne_config.kernel_cfg.kernel_fmt;   // 3-bit field, [0x664]&0x7 in the internal object
  if (kfmt > 5 || kfmt == E4M3 /* == 3 */) return false;         // kfmt_allowed fails, cold.14
  if (kfmt == UInt8 /* raw == 0, see §4's correction */ && !double_int8) return false;  // same shared-cold-path pattern as v20/v24, cold.10
  // kfmt == Int8(raw 1), FP16(2), Int4(4), or E2M1(5): all pass through unconditionally
  ```
  This is now confirmed by more than circumstantial cross-referencing: the binary contains a **directly enum-named** condition string, `"kernel_fmt == ...kernel_fmt_int4 || kernel_fmt == ...kernel_fmt_e2_m1"`, i.e. `int4` and `e2_m1` are literal named enumerators of `kernel_fmt` itself (not inferred from a setter's identity-mapping behavior alone). **So at v36, Winograd's weight-format eligibility set expands to `{INT8, FP16, INT4, E2M1}` unconditionally, plus `UINT8` when `double_int8` is set.** (Raw values here use the corrected 0=UINT8/1=INT8 mapping established in §4 — the original pass at this section had them backwards, matching the same error corrected there.)
  > [!NOTE]
  > **Correction/refinement to an earlier pass:** an earlier draft of this guide described format 5 as "E2M1/MX", implying the MX (microscaled/block-scaled) variants live at raw values 4/5 of `kernel_fmt` itself. That's not quite right. The binary also has a **separate, orthogonal** 2-bit field — `ZinAneTd<36u>::SetKernelFmtMx(ZinHWKernelFmtMx)`, writing `[+0x334] bits[8:9]` — plus a distinct condition string `"ne_cfg.kernel_fmt_mx == ...kernel_fmt_mx_mx"` and a `DoHWKernelAndTensorFormatMatch(kernel_fmt_enum, in_fmt_enum, is_mx_kernel)` helper, confirming "is this kernel microscaled" is tracked as its own flag alongside the base `kernel_fmt` value, not folded into it. Separately, the activation/`in_fmt` side has a much larger, fully-named MX family: `mxint2`, `mxint4`, `mxint6`, `mxint8`, `mxe2_m1`, `mxe2_m3` — none of which appear anywhere in `Validate1DWinograd<36u>`'s in_fmt whitelist (`UInt8`/`SInt8`/`FP16` only). **So no MX/microscaled activation format is Winograd-eligible at v36**, and `Validate1DWinograd<36u>` never reads the `kernel_fmt_mx` bit at all — whether a microscaled INT4/E2M1 *weight* is Winograd-eligible is therefore unchecked/unclear from this function alone (flagged in §7).
  >
  > A separate string, `"kernel_fmt != ...fp16 && kernel_fmt != ...bf16"`, confirms **BF16** is also a real named `kernel_fmt` enumerator at v36 — but since `kfmt_allowed` rejects any raw value `> 5`, and INT8/UINT8/FP16/E4M3/INT4/E2M1 already account for values 0-5, **BF16 is almost certainly raw value 6 (or higher) and is therefore *not* Winograd-eligible** — consistent with the `> 5` cutoff, not contradicting it.
- One new gate is added: `hw.common_config.ne_cfg.dp2_add_en == 0` — bit7 of the same byte (`[+0x32c]`) whose bit6 re-checks `half_wu == 0` immediately after, both reached only once `in_fmt` passes its whitelist check (`cmp w23,#3; b.hs` false-branch) — consistent with `DP2AddMode` also only becoming real at v36 (see the feature-support guide's "permanently dead API surface" list).
- `ValidateHalfWUMode<36u>` (chained immediately after) additionally checks `wu_stack == 0`, re-checks `winograd1_d_en == 0` (see caveat below), `sh_max <= 3`, and a small-source-mode compatibility condition.

> [!NOTE]
> **The `winograd1_d_en == 0` check inside `ValidateHalfWUMode` — resolved, not actually contradictory.** `ValidateHalfWUMode<36u>`'s own disassembly opens with `tbnz [+0x32c] bit6, ...; else return success` — i.e. bit6 of that byte is `half_wu` itself (the same bit `Validate1DWinograd` checks to reject Winograd when HalfWU is on), and the entire function is a no-op success when `half_wu` is *not* set. So `ValidateHalfWUMode` is simply **the dedicated validator for HalfWU mode**, only meaningfully engaged when HalfWU is in use; it is not "chained inside" `Validate1DWinograd`'s own success path, and checking `winograd1_d_en == 0` inside it is exactly the straightforward mutual-exclusion check §4.2 describes — no contradiction, no shared/misattributed code path. (Also confirmed while re-tracing: `winograd1_d_en` is bit27 of `[+0x328]`, `sh_max` compares `ubfx([+0x328],2,2)` against `{0,3}`, and `fat_tile_enable`/`wu_stack` are bits 3 and 4-5 of `[+0x32c]` respectively. One more v36-specific detail surfaced here: `ValidateHalfWUMode<36u>`'s own in_fmt whitelist is `UInt8 || SInt8 || E4M3` — E4M3/fp8 **is** HalfWU-eligible at v36, unlike Winograd, which always rejects it.)

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
| **INT8** (kernel raw `kernel_fmt`=1) | ✅ allowed unconditionally | ✅ allowed under `Normal` or `SSM_Tiny`/`NP2_6`/`NP2_10`/`SSM_Diminutive`; ❌ rejected under `SSM` specifically |
| **UINT8** (kernel raw `kernel_fmt`=0) | ✅ allowed **only with `double_int8` mode enabled** — and see §7's `CanUseWinogradMode` note: the compiler's own decision logic (`ShouldEnableWinogradMode`) excludes UInt8 weights at the cost-model layer too, so this combination is unlikely to ever be chosen in practice, empirically confirmed by real compiled `.hwx` output (see §7) showing 100% of Winograd tasks using INT8, never UInt8 | ✅ allowed under `Normal` or `SSM_Tiny`/`NP2_6`/`NP2_10`/`SSM_Diminutive`; ❌ rejected under `SSM` specifically |
| **FP16** | ✅ allowed unconditionally | ✅ allowed under `Normal` only — ❌ rejected under **any** non-`Normal` small-source-mode (`SSM`, `SSM_Tiny`, `NP2_6`, `NP2_10`, `SSM_Diminutive` all reject FP16, not just `SSM`) |
| **E4M3 (fp8)** | ❌ rejected | ❌ rejected |
| **INT4** (v36 only) | ✅ allowed unconditionally | not applicable (activation-side INT4 not checked here) |
| **E2M1** (v36 only, plain/non-microscaled) | ✅ allowed unconditionally | not applicable |

**Both columns' raw values are now confirmed.** Kernel-column: via `GetHWKernelFormat`'s exhaustive translation table and empirical `.hwx` output (§4, §7) — `kernel_fmt` raw 0=UINT8, 1=INT8, reversing this guide's original assumption. Activation-column: via `GetHWChannelFormat`'s jump table (`0x20acd94cc`), which gives the **same** raw ordering — `in_fmt`/`ch_fmt` raw 0=UINT8, 1=INT8, not a separate swap — cross-checked against the real compiled `.hwx` (§7): the same Winograd-enabled task shows `InDim Type=raw0` and `KernelCfg Fmt=raw1` on one and the same task, and the source MIL confirms exactly that split (post-ReLU activations quantized to `uint8`, symmetric-per-channel weights quantized to `int8`). So the two 1-byte activation-format rows below can now be read as confirmed raw-value identities, not provisional labels.

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

- ~~v36's `kfmt_allowed` helper~~ — **resolved**: traced to a widened kernel-format membership check allowing UINT8/FP16/INT4/E2M1, rejecting only E4M3 and out-of-range values (§4.1).
- ~~What `skd`/`skh` are~~ — **resolved**: both are the return value of `perfmodel::SubchannelKernelDimension(...)`, called twice with different bit-slices of the packed registers at `[0x24c]` (depth) and `[0x248]` (height) — see §4.
- ~~Whether the accumulator-budget checks (32/16/8) are simultaneous or alternative~~ — **resolved**: they are alternative branches over a single computed cost value, selected by a 2-bit mode field (`ubfx([0x25c],2,2)`) and a 3-bit format field (`[0x220]&0x7`); at most one threshold applies per task descriptor — see §4.
- ~~The exact `ssm`/`in_fmt` edge case for `ssm==1`~~ — **resolved**: `ZinSmallSourceMode` enum is `[Normal, SSM, SSM_Tiny, NP2_6, NP2_10, SSM_Diminutive]`; `ssm==SSM(1)` is unconditionally rejected (satisfies neither disjunct of `ssm==Normal || (ssm>1 && in_fmt<2)`), while `SSM_Tiny`/`NP2_6`/`NP2_10`/`SSM_Diminutive` are allowed only for INT8/UINT8 — see §4 and §5.
- ~~Independent re-verification of the shared-cold-path risk for `kernel_mode != Kernel` and the `sparse_fmt` compound check~~ — **resolved**: `kernel_mode` is a direct, adjacent-bitfield read, not mislabeled. The `sparse_fmt`/`asym_quant_en`/`ssm` trio isn't mislabeled either, but turned out to be alternative branches sharing the accumulator-budget's selector fields, not three sequential `if`s — restructured in §4. Also surfaced a previously-missing unconditional `kernel_fmt == E4M3` rejection now added to the pseudocode.
- ~~Exact bitmask semantics of the `sparse_fmt` branch's selector test~~ — **resolved**: `0x1fffff00 & 0xf00001ff` intersects to exactly bits {8, 28} of the same register that also carries `kernel_fmt` (bits 0-1) and `asym_quant_en` (bit 24) — `[0x4cc]` at v20/v24, `[0x65c]` at v36. Bit 8 = `sparse_fmt`, bit 28 = `detect_zeros`; the accompanying `csinc`-built flag collapses to `double_int8 || in_fmt==FP16`. All three pieces line up bit-for-bit with the three disjuncts of the `cold.14` assert string — see §4.
- ~~The exact numeric identity of v36 kernel-format values 4 and 5~~ — **resolved, with a correction**: confirmed via a directly enum-named condition string (`kernel_fmt == ...kernel_fmt_int4 || kernel_fmt == ...kernel_fmt_e2_m1`) that raw values 4 and 5 are literally **INT4** and **E2M1**. However, an earlier draft's "E2M1/**MX**" label was imprecise: MX/microscaled support is a *separate*, orthogonal field (`ZinHWKernelFmtMx`, `kernel_fmt_mx`), not folded into these two `kernel_fmt` raw values — see the corrected §4.1.
- **Microscaled INT4/E2M1 Winograd eligibility — narrowed further, still not fully closed**: a whole-binary search turned up **zero** references anywhere that combine Winograd with `kernel_fmt_mx`/MX/microscaled/int4/e2m1 in the same condition string, and no code anywhere (searched for the bit-8/9 extraction pattern of the `[+0x334]` field across the *entire* `__text` section, ~1.8M instructions) reads `kernel_fmt_mx` at all outside its own setter. That's about as strong as static string/pattern search can get: there is no explicit cross-check gating microscaled weights out of (or into) Winograd anywhere in this binary. This doesn't prove the combination is *supported* — it could equally mean the MIR-level cost model (§6) simply never considers Winograd for MX-format layers for unrelated reasons, with no need for an explicit gate. But at the `ZinValidateTd` layer specifically, the answer is now as settled as it can be from static analysis alone: **unconstrained, not merely "unchecked because we stopped looking."**
- ~~The `ValidateHalfWUMode<36u>` cross-check on `winograd1_d_en`~~ — **resolved**: not a contradiction. `ValidateHalfWUMode` is HalfWU's own dedicated validator (a no-op success when `half_wu` itself is unset), and `winograd1_d_en == 0` inside it is a plain, expected mutual-exclusion check — see the updated note in §4.1.
- **2D Winograd's actual format contract, at any version — narrowed, still not found**: `ZinIrTdValidationUtil::ValidateWinograd2DMode<HWVersion>` is a **real function that exists only as a `__PRETTY_FUNCTION__`-style string literal**, not as an out-of-line symbol — it was fully inlined at every call site, which is why `nm` never turns it up. Tracing every cross-reference to that string's page in the binary (~40 xrefs, all checked) found exactly **one** real consumer: `ZinValidateTd<36u>::ValidateDoubleMacMode`, which reads the `winograd2d_en` bit as a single OR-clause exemption. No other function anywhere in the binary reads this bit. So the honest conclusion is no longer just "not found yet": there appears to be **no dedicated format/shape gate for 2D Winograd at the `ZinValidateTd` layer, at any version** — consistent with its assert-string reading as dead/stub code through v31, and, even at v36 where the feature is finally real, its only cross-reference is this one incidental exemption clause in an unrelated validator.
  > [!IMPORTANT]
  > **Correction, now fully decoded: `ValidateDoubleMacMode<36u>` does NOT require FP16/BF16 — it hard-rejects them.** A previous pass at this guide (and the curated table in [GUIDE_ANE_FEATURE_SUPPORT_BY_GENERATION.md](GUIDE_ANE_FEATURE_SUPPORT_BY_GENERATION.md)) misread two of this function's assert strings as a positive whitelist. Tracing every branch's actual polarity (not just the embedded string) gives:
  > ```cpp
  > // ZinValidateTd<36u>::ValidateDoubleMacMode  (0x20bb8e350)
  > bool ValidateDoubleMacMode(const ZinAneTdHw_v36& hw) {
  >     if (hw.ne_config.mac_cfg.double_mac_en == 0) return true;   // bit26 of [+0x664]; no-op if unset
  >
  >     // Checked FIRST, before any format/op/kernel check -- this IS the winograd2d_en
  >     // exemption clause, and it decodes to a 4-way AND whose last three terms match
  >     // the assert string's three OR-disjuncts one-for-one:
  >     if (hw.ne_config.mac_cfg.binary_point != 0 && both_are_int8 && !winograd2d_en)
  >         return false;  // cold.5: "binary_point==0 || !both_are_int8 || winograd2d_en"
  >     //   binary_point  = bits[8:13] of [+0x664] (6-bit fixed-point scale field)
  >     //   winograd2d_en = bit26 of [+0x328]
  >     //   both_are_int8 = NOT(in_fmt_nibble ∈ {0,1,13,15} OR (in_fmt_nibble & 9)==8)
  >     //                   AND (kernel_fmt register's bit1 == 0)
  >     //   -- a compound bit-test over packed internal-object nibbles, not a clean
  >     //   single enum compare; the exact named-enumerator identity of the {0,1,13,15}
  >     //   set isn't resolved (see caveat below), but the 4-term structure is confirmed
  >     //   bit-for-bit against the assert string.
  >
  >     // in_fmt and kernel_fmt must NOT be FP16 or BF16 -- opposite of the earlier draft.
  >     // (kernel_fmt's check tests its low 2 bits == 0b10, which is true for BOTH raw
  >     // value 2 (FP16) and raw value 6 (BF16) -- a deliberate truncation trick, not
  >     // a coincidence, matching the assert string's "kernel_fmt != fp16 && != bf16".)
  >     if (in_fmt == FP16 || in_fmt == BF16) return false;         // cold.1
  >     if (kernel_fmt == FP16 || kernel_fmt == BF16) return false; // cold.4
  >
  >     if (hw.ne_config.mac_cfg.op_mode != Conv) return false;     // cold.2
  >
  >     // bit3 of [+0x664] is a precomputed single-bit "kernel_mode == Unity" flag,
  >     // not a multi-value enum compare at this call site.
  >     if (kernel_mode_is_unity) return false;                     // cold.3
  >
  >     return true;
  > }
  > ```
  > This is now independently corroborated by the cost-model helper `ZinDoubleMacMode::CanUseDoubleMacModeBasedOnFormats(ZinTensorFormat, ZinKernelFormat)`, decompiled from `0x20bfcc3c8`:
  > ```cpp
  > bool CanUseDoubleMacModeBasedOnFormats(ZinTensorFormat in_fmt, ZinKernelFormat kernel_fmt) {
  >     if (IsMicroscaledFormat(in_fmt)) return false;
  >     if (!IsPrimaryFormat(in_fmt)) return false;
  >     if (ZinTensorFormatGetSizeInBytes(in_fmt) > 1) return false;              // rules out FP16/BF16 (2 bytes)
  >     if (ZinKernelFormatGetUnderlyingTypeSizeInBytes(kernel_fmt) > 1) return false;
  >     return IsFloatFormat(in_fmt) == ZinKernelFormatIsFloat(kernel_fmt);       // matched float/non-float class
  > }
  > ```
  > A ≤1-byte format requirement is flatly incompatible with FP16/BF16 (both 2 bytes) — so this helper agrees with the corrected register-level trace, not the earlier "FP16/BF16 only" claim. **DoubleMacMode is an INT8-class throughput-doubling feature (the same family as `DoubleInt8Enable`), not an FP16/BF16 one** — which also makes far more sense of the `both_are_int8` clause name: DoubleMac's own eligible-format space *is* int8-class, so a clause specifically about "both operands being int8" is a meaningful, reachable condition inside it, not dead code as the earlier (incorrect) tension implied.
  > The only remaining loose end: the exact named-enumerator identity of `both_are_int8`'s `{0,1,13,15}` in_fmt-nibble set isn't resolved — those values don't obviously correspond to a plain 0-3 in_fmt enum, and may fold in extra bits packed into the same internal-object nibble (possibly related to the wider MX/microscaled `in_fmt` family documented in §4.1, which `CanUseDoubleMacModeBasedOnFormats` explicitly excludes via `IsMicroscaledFormat`). This is a genuinely open, low-priority detail, not a correctness concern for the "not FP16/BF16" conclusion above.
  > **`DoubleMacMode` and `DoubleInt8Enable` are not independent features — `DoubleInt8Enable`'s own eligibility check calls `DoubleMacMode`'s format-compatibility helper as a subroutine.** Decompiling `ZinNEConvLayer::CanUseDoubleInt8Mode(ZinTensorFormat, ZinKernelFormat, bool, ZinSmallSourceMode, ZinNamedType<bool,HalfWorkUnitModeTag>)` (`0x20aabbcbc`) shows it literally does `bl CanUseDoubleMacModeBasedOnFormats` partway through its own logic, alongside its own extra gates (a per-SoC HAL capability flag at `hal_params->byte[0x558]`, a small-source-mode condition, a vector-palettized-weight exception, and an output-channel-group-size heuristic via `CalculateOCGSize`). So `DoubleInt8Enable` is the older, compiler-cost-model-driven feature (`MacCfg` bit 26, real since H16/v17, **no dedicated `ZinValidateTd` hardware validator at any version**) whose format-eligibility test happens to be the same building block `DoubleMacMode` uses; `DoubleMacMode` is the newer, more general hardware mechanism that only got its own dedicated register-level validator (`ZinValidateTd<36u>::ValidateDoubleMacMode`) at v36. They read as the same underlying "pack two narrow-format MACs" trick implemented at two different layers/eras, not two competing mechanisms.
- **Where fp8/E4M3 legality actually lives — resolved, and it's mostly not `ZinValidateTd`**: a full-binary cross-reference sweep (every `adrp`/`add` pair across all of `__text` targeting one of ~20 distinct E4M3-related assert/error strings, mapped to its enclosing function) found **zero hits inside any `ZinValidateTd<Nu>::*` method, at any version**. fp8/E4M3 format legality is instead enforced almost entirely at the point a format is first assigned — `ZinAneTd<Nu>::SetCommonInFmt`/`SetCommonOutFmt`/`SetCommonSrc2InFmt`/`SetL2Src{1,2}DmaFormat` reject E4M3 (or `MxE4M3`) directly in the setter, across nearly every ISA version — plus other IR-layer classes entirely outside the `ZinValidateTd`/`ZinAneTd` hierarchy: `ZinQuantLayer`/`ZinDeQuantLayer::ValidateSemantics_Impl`, `ZinPadLayer::ValidateBackgroundPaddingValue`, a free function `ValidateKernelFormat(...)`, and several `anec`-dialect MLIR lowering patterns (`ConvertMatMul`, `ConvertFusionOp`, `ConvertConv`). Within `ZinValidateTd` itself, E4M3 only ever shows up as one unnamed clause folded into a more general validator — exactly the two cases this guide already decodes: unconditional rejection in `Validate1DWinograd`, and explicit allowance in `ValidateHalfWUMode<36u>`. No dedicated `ValidateFp8*`/`ValidateE4M3*` method exists anywhere in the class, at any version — confirmed both by this string-xref sweep and by an exhaustive `nm`+demangle scan of every `ZinValidateTd` method name.
  > [!NOTE]
  > **fp8/E4M3 handling in `ZinAneTd` setters, and a separate compiler-side format gate in `ZinNEConvLayer`/`ZinMirConvUtils`.** The `ZinAneTd<Nu>::SetCommonInFmt`/`SetCommonOutFmt` rejection above tracks the known v20 fp8 landing point exactly: v4-v19 hard-reject both plain `E4M3` and `MxE4M3` inline in the setter; starting exactly at v20 (through v31) only the `MxE4M3` reject remains — independent, setter-level corroboration of "fp8 real since v20" via a different code path than the one originally used to establish that claim. By v36, `SetCommonInFmt<36u>` is a pure 27-way jump-table dispatch with no reject path left at all.
  >
  > Separately, `ZinNEConvLayer::CanUseWinogradMode` forwards to `ZinMirConvUtils::CanUseWinogradMode` (`0x20ab51310`), which runs its **own** kernel-format gate via `ZinKernelFormatGetUnderlyingType(kernel_fmt)`, entirely independent of `ZinValidateTd`'s hardware check.
  > **Correction to an earlier pass at this note**: an initial reading of `GetUnderlyingType`'s 35-entry lookup table indexed it against the simple 6-value *hardware* `kernel_fmt` register field (where raw E4M3=3), which produced a spurious "this function rejects FP16, not E4M3" result. That was wrong — this function actually operates on `ZinKernelFormat`, a much richer **IR-level** enum (recovered directly from `ZinKernelFormatGetName`'s string table, after correctly decoding its chained-fixup pointer array as `target_vm = 0x180000000 + (ptr & 0x7FFFFFFFFFF)`): `1=int8, 2=uint8, 3=int16, 4=fp16, 5=e4m3, 6=fp32, 7..27=palettized/unity variants of the above at 1/2/3/4/6/8-bit depths, 31=int4, 32..35=MX-block-scaled variants`. Re-running `GetUnderlyingType` against this correct enum:
  > - **category 5 = E4M3 and every one of its variants** (`e4m3`, `p1e4m3`...`p6e4m3`, `pal*mxe6m3`) — all rejected by `CanUseWinogradMode`. This *does* match `Validate1DWinograd`'s hard E4M3 rejection — no contradiction after all, and no tension with the hardware layer.
  > - category 4 = FP16/FP32 and their variants — **not** rejected, consistent with FP16 being Winograd-eligible everywhere else in this guide.
  > - **category 2 = UInt8 and every one of its variants** (`uint8`, `p1u8`...`p6u8`, `unityu8`) — also rejected here, unconditionally (no `double_int8` escape hatch at this cost-model layer, unlike the hardware validator).
  >
  > **This is the general decision path, not a narrow one-off heuristic — confirmed by tracing all 4 real callers of this gate** (both the `ZinNEConvLayer` wrapper and the direct `ZinMirConvUtils` entry point):
  > - `ZinNEConvLayer::ShouldEnableWinogradMode(...)` — **the** general "should we use Winograd for this layer" decision function this guide's §6 already documents as the top-level cost-model entry point.
  > - `ZinNEConvLayer::IsValidMulticastConfiguration(...)` — an unrelated multicast-validity check that happens to reuse the same eligibility test.
  > - the lambda inside `ZinMirOpt::EnableLargeKernelModeFor1DWinograd(...)` — confirms my original large-kernel-mode hypothesis was *one* real caller, just not the only one.
  > - `ZinMirNERastParamsOpt::EnumerateWorkUnitCandidates(...)` — work-unit split-candidate enumeration.
  >
  > Since `ShouldEnableWinogradMode` is a real caller, this isn't a narrow-optimization quirk: **ANECompiler's compiler-side decision logic will never choose Winograd for UInt8-weight (or E4M3-weight) convolutions, unconditionally rejecting UInt8 even in the `double_int8`-enabled case where the hardware validator would allow it.** This was independently, empirically confirmed below: every real Winograd task in a real compiled model uses INT8, never UInt8.
- ~~No local `.hwx` samples exist for H17/H18/H19~~ — **resolved: real samples generated and inspected.** Compiled `ResNet50SymmetricPerChannel.mlpackage` (a real W8A8 model) to `.hwx` for h17/h18/h19 via this repo's own `mil/mil_to_hwx.cc` and inspected the output with `hwx_dump/hwx_parsing.py -r`. Results: **11/96 tasks (H17), 11/98 (H18), and 187/1281 (H19, bonded+nonbonded)** have `Wino1D=1` set — real, empirical confirmation that 1D Winograd is genuinely used by the compiler on real hardware targets, not just theoretically eligible. Every single one of those Winograd tasks uses kernel format raw value 1 — which, per the `GetHWKernelFormat` correction two items above, is **INT8**, matching this model's real (signed, symmetric-per-channel-quantized) weight dtype exactly, and consistent with the just-confirmed compiler-side UInt8 exclusion. This cross-check is also what surfaced the `kernel_fmt` 0/1 swap in the first place: the real compiled output initially looked like it contradicted static analysis, until dynamic LLDB tracing plus `GetHWKernelFormat`'s decompile resolved it — a good example of why this empirical-verification gap was worth closing.
- ~~Does the *activation-side* `ch_cfg.in_fmt`/`ZinTensorFormat` field have the same raw 0/1 (UInt8/Int8) swap that `kernel_cfg.kernel_fmt` turned out to have?~~ — **resolved: no separate swap, `in_fmt` uses the identical raw ordering as `kernel_fmt`.** Fully decompiled `GetHWChannelFormat` (`0x20acd94cc`) the same way as `GetHWKernelFormat`: its 30-entry jump table maps `ZinTensorFormat` case 1 → hw raw **1**, case 2 → hw raw **0**. Recovered `ZinTensorFormat`'s own names via `ZinTensorFormatToString` (`0x20ac405c8`, a char-by-char string builder rather than a simple pointer table, but still decodable): case 1 = `"int8"`, case 2 = `"uint8"` — the same raw-value convention `ZinKernelFormat` uses. So the hardware truth is **`in_fmt`/`ch_fmt` raw 0 = UInt8, raw 1 = Int8** — exactly mirroring the corrected `kernel_fmt` mapping, not an independent/reversed swap.
  Empirically cross-checked against the real `.hwx` output: the same Winograd-enabled H17 task (`[ANE Task 4]`) that showed `KernelCfg: Fmt=UINT8 ... DblInt8=1` (raw kernel_fmt=1, truly Int8, per the earlier correction) also shows `InDim Type=INT8` (`hwx_parsing.py`'s label for raw **0**, meaning the true value is UInt8). That split — Int8 weights, UInt8 activations on the same conv — exactly matches this model's own MIL source: `dequantize_1`/`dequantize_4`/`dequantize_6`... (weights, `constexpr_affine_dequantize` from `int8` blobs, symmetric per-channel, matching the model's `SymmetricPerChannel` name) vs. `quantize_2`/`quantize_3`/`quantize_5`/`quantize_7`... (post-ReLU activations, `output_dtype = "uint8"`, the standard asymmetric-UInt8-after-ReLU pattern). Both independent lines of evidence agree.
  **Consequence:** `hwx_dump/hwx_parsing.py`'s `get_ch_fmt_name()` (line ~502) has the same raw-0/1-swap bug as the kernel-format label did, for its H16/H17/H18/H19 call sites (`print_common_h16`/`print_ne_h16`, i.e. every `report_hwx_state` branch with `instr_ver > 11` and `subtype != 6`) — `INT8`/`UINT8` are swapped for both the `ch_fmt` (activation) and `kernel_fmt` (weight) fields it labels there. Its H13/H14/H15 call sites (`print_common_h13/h14`, `print_ne_h13/h14/h15`) were **not** touched or re-verified here — those are older, structurally different register layouts (§ above already noted H14's `ChCfg.InFmt` uses a distinct 3-value `0=FP16,1=INT8,2=INT16` scheme in the raw register-map docs), so whether they share this same swap or are genuinely different is still unconfirmed and out of scope of this check. Not fixed in `hwx_parsing.py` itself this pass — flagged here for a future, generation-scoped fix.
