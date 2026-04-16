# HWX Parsing Guide

This document describes the structure of Apple Neural Engine (ANE) hardware executable files (`.hwx`) and the protocol for parsing task descriptors (TDs) across all ANE architectures (H11-H18).

## 1. Architectural Support & Reference

| Platform (SoCs) | ANE CPU Subtype ($s$) | Inst Version ($n$) | Logic Class | Reference Map |
| :--- | :--- | :--- | :--- | :--- |
| H11 (A12) | 1 | 5 | `ZinAneTd<5u>` | - |
| H12 (A13) | 3 | 6 | `ZinAneTd<6u>` | - |
| H13 (A14/M1) | 4 | 7 | `ZinAneTd<7u>` | [h13_register_map.md](h13_register_map.md) |
| H14 (A15/M2) | 5 | 11 | `ZinAneTd<11u>` | - |
| H15 (A16/M3) | 6 | 13 | `ZinAneTd<13u>` | - |
| H16 (A17 Pro/M4) | 7 | 17 | `ZinAneTd<17u>` | [h16_register_map.md](h16_register_map.md) |
| H17 (A18 Pro/M5) | 9 | 19 | `ZinAneTd<19u>` | [h17_register_map.md](h17_register_map.md) |
| H18 (A19 Pro) | 10 | 20 | `ZinAneTd<20u>` | [h18_register_map.md](h18_register_map.md) |

> [!NOTE]
> The **Instruction Set Version** $n$ corresponds directly to the template parameter in the **`ZinAneTd<n u>`** class within the ANECompiler binary. For example, M4 (subtype 7) uses version 17, processed by `ZinAneTd<17u>`.

## 2. Tool Overview: `hwx_dump`

`hwx_dump` is a diagnostic tool that parses `.hwx` binaries and reconstructs the ANE hardware state. It features a **version-aware dispatcher** that automatically selects the correct architectural structs based on the detected instruction version.

### Key Capabilities
- **Mach-O Container Parsing**: Unpacks `.hwx` files (Magic: `0xbeefface`).
- **Dense Instruction Decoding**: Supports Burst and Scatter command formats used in H14-H18.
- **Architectural Parity**: Full register-level decoding for Common, Neural Engine (NE), and Planar Engine (PE) blocks.

### Getting Started

#### Build
Ensure you are on macOS or an iOS environment with standard build tools.
```bash
make clean && make
```

#### Usage
```bash
./hwx_dump path/to/compiled_model.hwx
```

## 3. Directory Structure

| File | Description |
| :--- | :--- |
| `hwx_parsing.m` | Core parser logic with version-aware architectural dispatching. |
| `ane_hwx_regs.h` | Audited C-struct definitions for H11-H18 hardware blocks. |
| `h13_register_map.md` | Bit-accurate register map for H13 (A14/M1). |
| `h16_register_map.md` | Bit-accurate register map for H16 (A17 Pro/M4). |
| `h17_register_map.md` | Bit-accurate register map for H17 (A18 Pro/M5). |
| `h18_register_map.md` | Bit-accurate register map for H18 (A19 Pro). |

## 4. Reverse Engineering Discovery

To discover register names and bit-accurate fields for new architectures (e.g., H18), analyze the `ANECompiler` binary using two primary classes: `ZinAneTd<n u>` (setters/descriptor state) and `ZinGetRegisterProgramming<n u>` (getters/hardware constraints).

### structural Mapping
The compiler uses an internal array within `ZinAneTd<n u>` to store the Task Descriptor state.
- **Offsets**: Internal word offsets correlate directly to hardware addresses: `Addr = Offset * 4`.
- **Bitfields**: Identified via `bfi` (Bit Field Insert) and `ubfx` (Unsigned Bit Field Extract) in the getters/setters.

## 5. Mach-O HWX Container Section
... (Existing sections on Mach-O and Dense Instruction formats remain valid for H16+)
