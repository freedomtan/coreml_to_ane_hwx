# Investigation: ANE Task Descriptor Header (H16+) & Event Logging Fields

**Status: confirmed via binary disassembly (`ANECompiler`, `aned`) and empirical execution.**

---

## 1. Executive Summary

In `hwx_dump/ane_hwx_regs.h`, `hwx_dump/hwx_parsing.m`, and `hwx_dump/hwx_parsing.py`, word 6 (offset `0x018`) of the H16+ Task Descriptor Header was previously labeled as `live_outs : 24` with the comment `// Active outputs map`.

Through binary reverse engineering of `ANECompiler.framework` and `/usr/libexec/aned`, this field has been definitively identified as **`dram_log_events`** (`hw.td_header6.dram_log_events` in internal Apple telemetry schemas). Together with `Header[2]` (`log_events`) and `Header[4]` (`debug_log_events`), it forms the hardware sequencer's three-tier telemetry event mask.

Furthermore, disassembly of `/usr/libexec/aned` explains why runtime macho patching (`_ANEMachoPatcher`) is applied to precompiled models (`isPreCompiled == 1`) but skipped for JIT/MIL models (`isPreCompiled == 0`), detailing the exact visitor callback that stamps `debug_log_events |= 0x7E` and `dram_log_events |= 0x7E`.

---

## 2. Binary Disassembly Proof

### 2.1 `ANECompiler`: `ZinLogEventFlags::EventFlagsV6::GetDramLogEventFlags`

In `ANECompiler.framework` (arm64e slice at `0x1e43670bc`):
`__ZNK16ZinLogEventFlags12EventFlagsV620GetDramLogEventFlagsERKNS_23LogEventConfigureParamsEPK11ZinANELayerRK18ZinIrHalParameters`

```assembly
00000001e43670ec  mov   w23, #0x0             ; default dram_log_events = 0
00000001e43670f0  str   wzr, [sp, #0xc]
00000001e43670f4  ldrb  w8, [x1, #0x1]        ; check EnableDramLogEvents flag
00000001e43670f8  cmp   w8, #0x1
00000001e43670fc  b.ne  0x1e4367144
00000001e4367100  mov   w23, #0x20            ; base bit 0x20
...
00000001e4367160  ldrb  w8, [x22, #0x3]       ; check EnableDramLogEventsOnly
00000001e4367164  cmp   w8, #0x1
00000001e4367168  b.ne  0x1e4367190
00000001e436716c  ldrb  w8, [x22, #0x4]
00000001e4367170  cmp   w8, #0x1
00000001e4367174  b.ne  0x1e4367180
00000001e4367178  mov   w8, #0x28
00000001e436717c  b     0x1e4367188
00000001e4367180  mov   w8, #0xf87e           ; full mask: 0x00fff87e
00000001e4367184  movk  w8, #0xff, lsl #16
00000001e4367188  orr   w23, w23, w8
```

The computed 24-bit value `w23` is passed directly to `ZinAneTdInstruction::HandleEventLogs` (`0x1e4565514`), which writes it to word offset `0x018` in the Task Descriptor Header.

### 2.2 `aned`: `_ANEMachoPatcher` In-Place Telemetry Stamping

In `/usr/libexec/aned`, `-[_ANEMachoPatcher patchModelFromURL:toDestination:withConfiguration:error:]` registers a visitor callback over the model's Mach-O task descriptors:

```c
// Decompiled visitor callback in _ANEMachoPatcher:
// x0 = pointer to task descriptor header (Header[0])
uint32_t *hdr = (uint32_t *)task_descriptor_base;
hdr[4] |= 0x7E;   // Header[4] @ 0x010: debug_log_events |= 0x7E
hdr[6] |= 0x7E;   // Header[6] @ 0x018: dram_log_events  |= 0x7E
```

This visitor unmasks events:
- Bit 1 (`0x02`): Task Start
- Bit 2 (`0x04`): Task End
- Bit 3 (`0x08`): Kernel Read Start/End
- Bit 4 (`0x10`): DMA Input Finish
- Bit 5 (`0x20`): DMA Output Finish
- Bit 6 (`0x40`): Sub-unit Switch

---

## 3. The Complete H16+ Task Descriptor Header (40 Bytes / 10 Words)

| Word | Byte Offset | Field Name | Width | Semantics |
| :--- | :--- | :--- | :--- | :--- |
| **0** | `0x000` | `tid` | 16 bits | Task Identifier (0-indexed per stream) |
| | `0x002` | `task_size` | 11 bits | Total Task Size in 32-bit words (payload words + header) |
| | `0x002` | `pad0` | 5 bits | Alignment padding |
| **1** | `0x004` | `exe_cycles` | 16 bits | Hardware Sequencer estimated execution cycles |
| | `0x006` | `pad1` | 16 bits | Alignment padding |
| **2** | `0x008` | `log_events` | 24 bits | Hardware sequencer basic log events mask |
| | `0x00b` | `pad2` | 8 bits | Alignment padding |
| **3** | `0x00c` | `exceptions` | 24 bits | Hardware exception reporting mask |
| | `0x00f` | `pad3` | 8 bits | Alignment padding |
| **4** | `0x010` | `debug_log_events` | 24 bits | Debug log events mask (dynamic trace selection) |
| | `0x013` | `pad4` | 8 bits | Alignment padding |
| **5** | `0x014` | `debug_exceptions` | 24 bits | Debug exceptions reporting mask |
| | `0x017` | `pad5` | 8 bits | Alignment padding |
| **6** | `0x018` | `dram_log_events` | 24 bits | DRAM event ring buffer flush mask (previously misidentified as `live_outs`) |
| | `0x01b` | `pad_lo` | 8 bits | Alignment padding |
| **7** | `0x01c` | `unknown_flags` | 32 bits | Reserved hardware control flags |
| **8** | `0x020` | `ctrl_flags` | 32 bits | Control flags: `tsr` (bit 0), `tde` (bit 1), `pad` (bit 2), `unknown` (bit 3), `pad0` (bits 4-15), `ene` (bits 16-18), `pad1` (bits 19-31) |
| **9** | `0x024` | `dtid` | 16 bits | Dependent Task ID (H16+ cross-task barrier synchronization) |
| | `0x026` | `pad8` | 16 bits | Alignment padding |

---

## 4. `aned` Execution Path: Why `patchedModel=NO` on iOS Sandboxed Apps

Disassembly of `-[_ANEServer loadModel:sandboxExtension:options:qos:withReply:]` at `0x10001e0d4`:

```assembly
000000010001e0d4  ldr   w8, [sp, #0x110]      ; w8 = isPreCompiled
000000010001e0d8  cbz   w8, 0x10001e208       ; if isPreCompiled == 0 -> jump to MIL path!
...
; PRECOMPILED PATH (isPreCompiled == 1):
000000010001e4fc  bl    _objc_msgSend$applyMachoPatchingIfNeeded:modelFilePath:csIdentity:options:
...
; JIT / MIL PATH (isPreCompiled == 0):
000000010001e208  ...
000000010001e244  bl    _objc_msgSend$compileAsNeededAndLoadCachedModel:...
000000010001e27c  adrp  x21, 141
000000010001e280  add   x21, x21, #0x358      ; x21 = @"NO"
000000010001e284  b     0x10001e6a4           ; branches PAST applyMachoPatchingIfNeeded!
```

**Consequences**:
1. When sandboxed apps load MIL models (`isPreCompiled == 0`), `aned` explicitly skips `applyMachoPatchingIfNeeded`.
2. Third-party sandboxed apps on iOS cannot pass `isPreCompiled == 1` with a user-supplied `.hwx` binary (blocked by `_ANESandboxingHelper` security validation).
3. To enable `dram_log_events` and `debug_log_events` for sandboxed models, compiler options (`EnableDramLogEvents`, `EnableDramLogEventsOnly`) must be injected during `compileModel:` rather than relying on `aned`'s runtime macho patcher.
