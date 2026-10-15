# Netron Extension for Apple Neural Engine (.hwx) Files

> [!NOTE]
> **Work In Progress (WIP)**: This Netron extension is actively under development. While it supports parsing and DAG reconstruction for architectures H11 through H19, dynamic DAG reconstruction and multi-channel gather heuristics (Option A vs Option B modules) are evolving as more diverse network topologies are evaluated.

This extension enables [Netron](https://github.com/lutzroeder/netron) to open, visualize, and inspect compiled Apple Neural Engine (ANE) `.hwx` binary files.


---

## Features

1. **Native Netron Integration**:
   - Opens `.hwx` files directly using Netron CLI (`netron <model.hwx>`) or the Netron web / desktop app.
   - Automatically identifies Mach-O containers with magic `0xBEEFFACE` or `0xFEEDFACF`.

2. **Broad Architecture Support**:
   - **H11** (A12 Bionic)
   - **H12** (A13 Bionic)
   - **H13** (A14 / Apple M1) — linked list task descriptors at fixed offsets
   - **H14** (A15 / Apple M2) — sequential instruction stream
   - **H15** (A16 / Apple M3)
   - **H16** (A17 Pro / Apple M4)
   - **H17** (A18 Pro)
   - **H18** (A19) — FP8 E4M3 support
   - **H19** (A20 Pro / M6)

3. **Dataflow & Computational DAG Reconstruction**:
   - Automatically tracks **TileDMA** source and destination buffer addresses.
   - Tracks **L2 SRAM cache** `Src1Base`, `Src2Base`, and `ResBase` addresses.
   - Automatically detects and wires residual / shortcut branches (e.g. ResNet residual adds, MobileNet inverted residual blocks).
   - Generates input and output tensor shapes `[Batch/Depth, Channels, Height, Width]` and data types (`float16`, `int8`, `uint8`, `e4m3`).

4. **Rich Sidebar Inspection**:
   - **Task Summary**: Task ID (TID), size in words/bytes, and hardware execution cycles estimation.
   - **Neural Engine (NE)**: Operation mode (`Conv`, `MatMul`, `TransposedConv`, `Bypass`, `ElemWise`, `RCAS`, etc.), Kernel Format, Kernel Mode (Unity vs Kernel), Activation / Non-linear mode (ReLU, Sigmoid, Tanh, GELU, etc.), Bias enable, Asymmetric quantization, Weight reuse, Zero detection.
   - **Planar Engine (PE)**: Operation mode (`Add`, `Mul`, `Max`, `Min`, `SumSqr`), Pooling mode (`Avg`, `Max`), Condition, LUT enable, Reduction flags.
   - **Convolution Config**: Kernel size `[KW, KH]`, Stride `[SX, SY]`, Padding `[PL, PT]`.
   - **Memory Mapping**: TileDMA source/destination addresses and L2 cache base addresses.
   - **Full Register Dump**: Complete list of all active hardware registers decoded by functional block (Common, L2 Cache, Planar Engine, Neural Engine, TileDMA, KernelDMA).

---

## Quick Start

### 1. Install Extension into Netron
Run the installer script:
```bash
python3 netron_hwx/patch_netron.py --install
```

To verify the installation:
```bash
python3 netron_hwx/patch_netron.py --status
```

### 2. Visualize any `.hwx` model
```bash
netron ./resnet50_fp16_m4/864A55188C0CF96F9B8AC6F768721ED331239D2D6235C0F9C02D14C9EF047E1F/model.hwx
```
or
```bash
netron ./pytorch_fp8_conv.mlmodelc/model.hwx
```

### 3. Uninstall / Restore Netron
To restore Netron back to original state:
```bash
python3 netron_hwx/patch_netron.py --uninstall
```

---

## Architecture

- [`hwx.js`](./hwx.js): Self-contained Netron format module exporting `ModelFactory`. Implements `match(context)` and `open(context)` constructing Netron `Model`, `Graph`, `Node`, `Argument`, `Value`, `TensorType`, and `TensorShape`.
- [`patch_netron.py`](./patch_netron.py): Automatic installer and patch tool for Netron environments.
- [`test_netron_hwx.mjs`](./test_netron_hwx.mjs): Test suite verifying model loading, graph connectivity, and residual join detection across multiple ANE generations (M1, M4, A19).
