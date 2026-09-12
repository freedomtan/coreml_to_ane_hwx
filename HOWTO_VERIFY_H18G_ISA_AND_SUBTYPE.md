# Reverse-Engineering Apple Neural Engine: Determining H18g's CPU Subtype and Instruction Set Version (ISA)

This document provides a step-by-step walkthrough explaining how to discover and verify the **CPU Subtype** and **Instruction Set Architecture (ISA) version** for Apple Neural Engine (ANE) targets—using `h18g` (M6) as a concrete case study.

---

## 1. Background

When Apple's compiler tools (via `ANECompiler.framework`) compile a CoreML MIL model down to hardware execution binaries (`.hwx`), they output a customized Mach-O 64-bit binary.

Every `.hwx` binary specifies:
1. **CPU Type**: Standard ANE identifier `0x00000080`.
2. **CPU Subtype**: A small integer indicating hardware generation (`4` for H13/M1, `5` for H14/M2, `7` for H16/M4, `10` for H18/A19, etc.).
3. **Instruction Set Version ($n$)**: The internal ISA template parameter used by `ZinAneTd<n u>` and `CodegenCreateInstructions<n u>`.

While `h18` (A19) and `h18g` (M6) share the `h18*` naming prefix, **`h18g` does not use ISA v20 or subtype 10**. Below is the reverse-engineering methodology used to verify its true subtype (`11`) and ISA version (`24`).

---

## 2. Method 1: Analyzing `model.hwx` Mach-O Headers

The most direct verification is compiling a model for `h18g` using `mil_to_hwx` and inspecting the resulting Mach-O header.

### Step 1: Compile with `mil_to_hwx`
```bash
./mil_to_hwx -a h18g -i /tmp/ResNet50.mlmodelc/ -o /tmp/test_h18g/ ResNet50
```

### Step 2: Read the Mach-O Header Fields
In a 64-bit Mach-O header, the first 12 bytes contain:
- Bytes 0–3: `magic` (`0xbeefface` for ANE)
- Bytes 4–7: `cputype` (`0x00000080`)
- Bytes 8–11: `cpusubtype` (little-endian 32-bit integer)

We can inspect it with a simple Python script:
```python
import struct

with open('/tmp/test_h18g/ResNet50_h18g/model.hwx', 'rb') as f:
    data = f.read(12)
    magic, cputype, cpusubtype = struct.unpack('<3I', data)
    print(f"Magic:       {hex(magic)}")
    print(f"CPU Type:    {hex(cputype)}")
    print(f"CPU Subtype: {cpusubtype} (0x{cpusubtype:x})")
```

### Output:
```text
Magic:       0xbeefface
CPU Type:    0x80
CPU Subtype: 11 (0xb)
```

Comparing the output across architectures:
| Target | Chip | CPU Subtype (Mach-O) |
|:---|:---|:---|
| `h18` | A19 | `10` (`0x0a`) |
| `h18a` | A19 | `10` (`0x0a`) |
| `h18g` | M6 | **`11` (`0x0b`)** |
| `h19` | A20 Pro | **`11` (`0x0b`)** |

Notice that `h18g` emits **CPU Subtype 11**, identical to `h19` and distinct from `h18` (`10`).

---

## 3. Method 2: Disassembling `ANECompiler` Implementation

To understand *why* `h18g` gets subtype 11 and what ISA version that maps to, we inspect `ANECompiler.framework` in the dyld shared cache.

### Step 1: Extract `ANECompiler` using `ipsw`
```bash
DSC=/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/dyld_shared_cache_arm64e
ipsw dyld extract "$DSC" ANECompiler -o /tmp/ane_compiler_extract/
```

### Step 2: Trace `TargetH18g` Construction
Search for target creation logic in `ANECompiler`:
```bash
strings /tmp/ane_compiler_extract/ANECompiler | grep -E "^h18g$"
```

Disassembling the target string parser shows:
```asm
; String comparison against "h18g"
bl   __ZNSt3__1eq...               ; compare input string with "h18g"
cbz  w0, check_next_target
bl   __ZN10TargetH18gC2Ev          ; construct TargetH18g
```

Disassembling `TargetH18g::TargetH18g()` (`__ZN10TargetH18gC2Ev`):
```asm
__ZN10TargetH18gC2Ev:
    ...
    ; Sets up TargetH18g vtable pointing to ZinIrHal2026BaseLine!
    adrp    x16, ...
    add     x16, x16, #0x820       ; __ZTV20ZinIrHal2026BaseLine
    ...
    bl      __ZN21ZinIrSocVariantParams15Soc2026BaseLineEv
    ...
```
- `TargetH18` instantiates **`ZinIrHalH18`**
- `TargetH18g` instantiates **`ZinIrHal2026BaseLine`**
- `TargetH19` instantiates **`ZinIrHalH19`** (which also inherits from `ZinIrHal2026BaseLine`)

### Step 3: Inspect `ZinIrHal2026BaseLine::GetParams()`
Disassembling `ZinIrHal2026BaseLine::GetParams()` (`__ZZNK20ZinIrHal2026BaseLine9GetParamsEvENK3$_0clEv`):
```asm
    bl      __ZNK11ZinIrHalH189GetParamsEv  ; inherits baseline
    ...
    bl      __ZN21ZinIrSocVariantParams15Soc2026BaseLineEv
    str     x0, [x19]
    mov     w8, #0xb                        ; 0xb = 11!
    str     w8, [x19, #0x8]                 ; store subtype = 11 into ZinIrHalParameters
```
In contrast, `ZinIrHalH18::GetParams()` explicitly stores:
```asm
    mov     w8, #0xa                        ; 0xa = 10!
    str     w8, [x19, #0x8]                 ; store subtype = 10
```

### Step 4: Map CPU Subtype to ISA Version via `ZinCpuSubtypeToArchValuei`
During instruction generation (`ZinIrCreateInstructions`), `ANECompiler` maps the CPU subtype to an internal enum `AneArchEnum`:
```asm
__ZL24ZinCpuSubtypeToArchValuei:
    cmp     w0, #0x14                       ; bounds check (subtype <= 20)
    b.hi    default_case
    adrp    x8, ...
    add     x8, x8, #0xde4                  ; lookup table address
    ldr     w0, [x8, w0, uxtw #2]           ; w0 = table[subtype]
    ret
```

Dumping this lookup table directly from the binary reveals the exact 1:1 mapping:
```text
Subtype  0 -> AneArchEnum  5  (ISA v5)
Subtype  1 -> AneArchEnum  5  (ISA v5)  [H11 / A12]
Subtype  3 -> AneArchEnum  6  (ISA v6)  [H12 / A13]
Subtype  4 -> AneArchEnum  7  (ISA v7)  [H13 / A14 / M1]
Subtype  5 -> AneArchEnum 11  (ISA v11) [H14 / A15 / M2]
Subtype  6 -> AneArchEnum  8  (ISA v8)  [H15 / A16 / M3]
Subtype  7 -> AneArchEnum 17  (ISA v17) [H16 / A17 Pro / M4]
Subtype  9 -> AneArchEnum 19  (ISA v19) [H17 / A18 / M5]
Subtype 10 -> AneArchEnum 20  (ISA v20) [H18 / A19]
Subtype 11 -> AneArchEnum 24  (ISA v24) [H18g / H19 / M6 / A20 Pro]
```

And examining `arch_dispatch<CodegenCreateInstructionsDispatcher>` confirms:
- `AneArchEnum 20` $\rightarrow$ calls `CodegenCreateInstructions<20u>()`
- `AneArchEnum 24` $\rightarrow$ calls `CodegenCreateInstructions<24u>()`

---

## 4. Method 3: Dynamic Verification with LLDB

We can definitively confirm runtime execution behavior using `lldb` with conditional breakpoints.

### Commands:
```bash
lldb --batch \
  -o "target create ./mil_to_hwx" \
  -o "b ANECCompile" \
  -o "r -a h18g -i /tmp/ResNet50.mlmodelc/ -o /tmp/test_h18g/ ResNet50" \
  -o "image lookup -vn CodegenCreateInstructions" \
  -o "b <address_of_CodegenCreateInstructions<20u>>" \
  -o "b <address_of_CodegenCreateInstructions<24u>>" \
  -o "c" \
  -o "bt 3" \
  -o "quit"
```

### Execution Result for `h18g`:
```text
Process stopped
* thread #3, stop reason = breakpoint 3.1
    frame #0: 0x000000021cb38cc4 ANECompiler`ZinInstructionList CodegenCreateInstructions<24u>(...)
    frame #1: 0x000000021cace080 ANECompiler`ZinIrCreateInstructions(...) + 92
```

Breakpoint 3 (`CodegenCreateInstructions<24u>`) was hit, while Breakpoint 2 (`CodegenCreateInstructions<20u>`) was never reached.

### Execution Result for `h18`:
```text
Process stopped
* thread #1, stop reason = breakpoint 2.1
    frame #0: 0x000000021cb2d0c0 ANECompiler`ZinInstructionList CodegenCreateInstructions<20u>(...)
    frame #1: 0x000000021cace080 ANECompiler`ZinIrCreateInstructions(...) + 92
```

---

## 5. Summary

| Target Name | Marketing Name | HAL Implementation | CPU Subtype | ISA Version | Template Dispatch |
|:---|:---|:---|:---|:---|:---|
| **`h18`** | A19 (generic) | `ZinIrHalH18` | **`10`** | **`20`** | `CodegenCreateInstructions<20u>` |
| **`h18a`** | A19 | `ZinIrHalH18` | **`10`** | **`20`** | `CodegenCreateInstructions<20u>` |
| **`h18p`** | A19 Pro | `ZinIrHalH18` | **`10`** | **`20`** | `CodegenCreateInstructions<20u>` |
| **`h18g`** | M6 | `ZinIrHal2026BaseLine` | **`11`** | **`24`** | `CodegenCreateInstructions<24u>` |
| **`h19`** | A20 Pro | `ZinIrHalH19` | **`11`** | **`24`** | `CodegenCreateInstructions<24u>` |

Although `h18g` shares the "18" generation prefix in compiler target flags, it belongs to the **`ZinIrHal2026BaseLine`** hardware profile, making it a **CPU Subtype 11 / ISA Version 24** architecture along with `h19`.
