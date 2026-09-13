# Technical Guide: H18g / H19 Multi-Engine Bonded Networks in Apple Neural Engine (.hwx)

This guide documents the architectural and binary container changes introduced in Apple's **ISA v24** generation (**H18g / M6** and **H19 / A20 Pro**) for supporting **Bonded Networks** and cooperative multi-engine execution.

---

## 1. Executive Summary

In pre-H18g architectures (H14 through H18, including M2, M3, M4, M5, and A19), ANECompiler emits a **single nonbonded network** targeting a single ANE engine (`ANE 0`). Even on multi-core / multi-slice hardware, spatial splitting was disabled by default for typical models, resulting in coarse-grained single-engine execution plans (~126 tasks for ResNet-50).

Starting with the **2026BaseLine architecture family** (CPU Subtype 11, ISA v24: `h18g` and `h19`):
1. **Dual-Network Bundling**: A single `.hwx` Mach-O binary now packs **two distinct operational modes**:
   - `main__nonbonded` (single-engine fallback execution plan)
   - `main__bonded` (multi-engine cooperative parallel execution plan)
2. **Multi-Engine Scheduling**: The bonded network distributes tasks across multiple physical ANE instances (`ANE 0` and `ANE 1`).
3. **Spatial DAG Slicing**: Layers are tiled in 2D space (`--fspatial-split=generic-dag`), multiplying the number of tasks per layer by up to 32× (~1,642 to 2,063 tasks for ResNet-50).
4. **Mach-O Container Changes**:
   - Introduction of the `__RUNTIME` segment containing procedure maps (`rt_op_map_text...`) and kick commands (`rt_op_ane_kick...`).
   - Sliced task streams stored consecutively within `__TEXT, __text`, demarcated by Task ID (`TID`) resets and 16 KB page-aligned padding.
   - Partitioned analytics buffers emitted per network variant (`analytics_main__bonded.json` vs `analytics_main__nonbonded.json`).

---

## 2. Compiler Optimization Flags Comparison

Comparing the embedded compilation metadata (`LC_IDENT`) of `h16` (M4) vs `h19` (A20 Pro) / `h18g` (M6):

```diff
  ModuleCompilationFlags: 
- -t h16
+ -t h19  (or -t h18g)
  --fno-fold-scale=true
  --fdram-allocator=ffreuse
  --fdram-tensor-priority=sizebyliverange
  --fl2-allocator=ffreuse
  --fl3-allocator=ffreuse
  --fl2-cache-mode=resident
  -g 
  --fsignature=ident
- --fdisable-bonded-networks=true
+ --fdisable-bonded-networks=false
  --enable-param-and-map-rtgraph-refactor=false
  --enable-work-stealing-for-bonded-networks=false
  --memcache-size=4194304
- --fspatial-split=disabled
+ --fspatial-split=generic-dag
  --fenable-circular-buffer-in-spatial-split=-1
  --fkernel-rewind=enabled
  --fuse-runtime-matmul-scaling=false
  --max-td-latency=10000.000000
  --generate-static-perf-analytics
  --generate-analytics-buffer
  ...
+ --compiler-multithreading=true
+ --use-extended-macho-format
  --enable-l2-batch-splitting=true
  --enable-global-cw-optimization=true
  ...
- --enable-nonbonded-networks=false
+ --enable-nonbonded-networks=true
```

Key takeaways:
- `--fdisable-bonded-networks=false` + `--enable-nonbonded-networks=true`: Directs the compiler to emit **both** execution modes into the same artifact.
- `--fspatial-split=generic-dag`: Slices large convolutions and element-wise ops across width/height and splits workloads between ANE 0 and ANE 1.

---

## 3. Mach-O Layout: The `__RUNTIME` and `__TEXT` Segments

### 3.1 Segment Layout in `.hwx`

Prior to H18g/H19, the `.hwx` file typically contained:
- `__PAGEZERO`
- `__DEBUG` (`__debug_info`)
- `__DATA` (`__bss`, `__bss_sh`)
- `__TEXT` (`__text`, `__const`)
- `__KERN_0` (weights / LUT coefficients)

In H18g/H19, an explicit **`__RUNTIME` segment** precedes `__TEXT`:

```text
Segment __DEBUG:   VM 0x30000000, File Off 0x164000, Size 0x040000
Segment __DATA:    VM 0x30040000, File Off 0x000000, Size 0x000000
  Section __bss:    VM 0x30040000, Size 0x1260000
  Section __bss_sh: VM 0x312a0000, Size 0x1260000
Segment __RUNTIME: VM 0x32500000, File Off 0x1a4000, Size 0x004000
  Section __runtime: VM 0x32500000, Size 0x0016ac
Segment __TEXT:    VM 0x32504000, File Off 0x1a8000, Size 0x090000
  Section __text:   VM 0x32504000, Size 0x08b228  <-- Task streams
  Section __const:  VM 0x32590000, Size 0x004000
Segment __KERN_0:  VM 0x32594000, File Off 0x238000, Size 0x361c000
```

### 3.2 `__RUNTIME` Procedure Mappings

The runtime operation table in `__runtime` defines how each network variant maps into virtual memory:

| Runtime Symbol | Op Type | Target Engine | Mapped Virtual Address | Size in `__text` |
|:---|:---:|:---:|:---|:---|
| `rt_op_map_text__ane0_P_main__nonbonded` | `0x1a` | `ANE 0` | `0x32504000` (`+0x00000`) | `0x424d8` (271,576 B) |
| `rt_op_map_text__ane0_P_main__bonded` | `0x1e` | `ANE 0` | `0x32548000` (`+0x44000`) | `0x24000` (147,456 B) |
| `rt_op_map_text__ane1_P_main__bonded` | `0x1a` | `ANE 1` | `0x3256c000` (`+0x68000`) | `0x23228` (143,912 B) |

Corresponding kick operations trigger hardware dispatch:
- `rt_op_ane_kick_main__nonbonded_bb_0_segment_0_ane_0`: Kicks single-engine execution.
- `rt_op_ane_kick_main__bonded_bb_0_segment_0_ane_0`: Kicks bonded partition on Engine 0.
- `rt_op_ane_kick_main__bonded_bb_0_segment_0_ane_1`: Kicks bonded partition on Engine 1.

---

## 4. `__text` Structure: Sliced Task Streams

Inside the single `__text` section, tasks are packed as three contiguous streams separated by 16 KB page-aligned zero padding:

```
+-------------------------------------------------------------------------+
| Section __TEXT, __text (Base: 0x32504000 / File Offset: 0x1a8000)       |
+-------------------------------------------------------------------------+
| Stream 0: main__nonbonded (Engine 0)                                    |
|   Offset: 0x00010 .. 0x424d8 (804 tasks, TID: 0x0000 -> 0x0323)        |
+-------------------------------------------------------------------------+
| Zero-fill padding (0x424d8 .. 0x44000, 6,952 bytes)                     |
+-------------------------------------------------------------------------+
| Stream 1: main__bonded (Engine 0)                                       |
|   Offset: 0x44010 .. 0x670e0 (418 tasks, TID: 0x0001 -> 0x01a2)        |
+-------------------------------------------------------------------------+
| Zero-fill padding (0x670e0 .. 0x68000, 3,872 bytes)                     |
+-------------------------------------------------------------------------+
| Stream 2: main__bonded (Engine 1)                                       |
|   Offset: 0x68010 .. 0x8b228 (420 tasks, TID: 0x0001 -> 0x01a4)        |
+-------------------------------------------------------------------------+
```

### 4.1 Task ID (`TID`) Discontinuity Detection

Within each stream, task logic IDs (`TID`) increment monotonically:
- `main__nonbonded` (ANE 0): `TID = 0x0000` up to `0x0323` (804 tasks).
- Transition to `main__bonded` (ANE 0): **TID resets from `803` back to `1`**.
- Transition to `main__bonded` (ANE 1): **TID resets from `418` back to `1`**.

Hardware decoders and tools (such as `hwx_parsing`) track this reset condition:
```c
if (prev_tid != -1 && m4h->tid <= prev_tid && (prev_tid - m4h->tid > 10 || m4h->tid <= 1)) {
    // Reached boundary of next network stream
    stream_idx++;
}
```

---

## 5. Task Count Explosion: Spatial Slicing Analysis

For a standard `ResNet50` model, the task count changes dramatically between `h16` and `h19`/`h18g`:

| Model Layer / Group | H16 Tasks (ANE 0) | H19 Tasks (ANE 0 Nonbonded) | H19 Tasks (ANE 0 Bonded) | H19 Tasks (ANE 1 Bonded) |
|:---|:---:|:---:|:---:|:---:|
| **Group #0 (Conv 7x7)** | 1 | 4 | 2 | 2 |
| **Group #4–#14 (Conv 3x3/1x1)** | 1 each | 16 each | 8 each | 8 each |
| **Group #59 (Late Conv)** | 16 | 16 | 8 | 8 |
| **Group #68 (Conv Block)** | 4 | 4 | 2 | 2 |
| **Group #70–#72 (Classifier)** | 1 each | 1 each | 1 each | 1 each |
| **Total Tasks** | **126** | **804** | **418** | **420** |

### Why Spatial Slicing Multiplies Tasks:
1. **L2 Tiling**: Convolutions that exceed ANE L2 cache tile boundaries are split into multiple tiles.
2. **Channel-Width Slicing**: Operations are divided into sub-slices executed concurrently or sequentially with fine-grained dependencies.
3. **Engine Affinity**: In the bonded network, half of the spatial tiles are assigned to `AneIdx: 0` and the other half to `AneIdx: 1`.

---

## 6. Partitioned Performance Analytics

Pre-H18g compilations produced a single monolithic analytics dump:
- `analytics.json`
- `model.hwx_AnalyticsBuffer_main`

Because H18g and H19 contain two distinct network graphs, `mil_to_hwx` exports **two separate analytics sets**:
1. **`analytics_main__bonded.json`** & **`model.hwx_AnalyticsBuffer_main__bonded`**
   - Performance counters and static cycle estimations assuming dual-engine parallel execution.
2. **`analytics_main__nonbonded.json`** & **`model.hwx_AnalyticsBuffer_main__nonbonded`**
   - Performance counters assuming single-engine fallback execution.

---

## 7. Tooling Support in `hwx_dump`

`hwx_parsing` (both Objective-C and Python implementations) has been enhanced to detect and report these multi-stream structures:

```bash
./hwx_dump/hwx_parsing /tmp/hwx_output/ResNet50_h19/model.hwx
```

Output:
```text
      [ANE Task 0 (Stream 0) @ 0x10] (Size: 0x1a0 bytes)
        TID: 0x0000 TaskSize: 0x68 ExeCycles: 13 ENE: 5 DTID: 0x1540
        ...
      [ANE Task 803 (Stream 0) @ 0x42340] (Size: 0x198 bytes)
        TID: 0x0323 TaskSize: 0x66 ...

    ================================================================
    [Network Stream #1 Transition @ offset 0x44010] (TID reset: 803 -> 1)
    ================================================================

      [ANE Task 804 (Stream 1) @ 0x44010] (Size: 0x1a0 bytes)
        TID: 0x0001 TaskSize: 0x68 ExeCycles: 13 ENE: 5 DTID: 0x1540
        ...
      [ANE Task 1221 (Stream 1) @ 0x66f10] (Size: 0x1d0 bytes)
        TID: 0x01a2 TaskSize: 0x74 ...

    ================================================================
    [Network Stream #2 Transition @ offset 0x68010] (TID reset: 418 -> 1)
    ================================================================

      [ANE Task 1222 (Stream 2) @ 0x68010] (Size: 0x1a0 bytes)
        TID: 0x0001 TaskSize: 0x68 ExeCycles: 13 ENE: 5 DTID: 0x1540
        ...
      [ANE Task 1641 (Stream 2) @ 0x8b050] (Size: 0x1d8 bytes)
        TID: 0x01a4 TaskSize: 0x76 ...
```

---

## 8. Summary Comparison Table

| Feature | H14 – H18 (M2–M5, A15–A19) | H18g / H19 (M6, A20 Pro) |
|:---|:---|:---|
| **ANE Instruction Set Version** | 11, 8, 17, 19, 20 | **24** (`ZinAneTd<24u>`) |
| **CPU Subtype** | 5, 6, 7, 9, 10 | **11** (`0x0b`) |
| **Network Packaging** | Single (`main`) | Dual (`main__nonbonded` + `main__bonded`) |
| **Targeted ANE Engines** | `ANE 0` only | `ANE 0` + `ANE 1` |
| **Spatial Splitting** | Disabled (`--fspatial-split=disabled`) | Enabled (`--fspatial-split=generic-dag`) |
| **Runtime Control** | Inline in load commands | Dedicated `__RUNTIME` segment |
| **Task Count (ResNet50)** | 126 | **1,642 (H19) / 2,063 (H18g)** |
| **Analytics Output** | Single buffer (`_main`) | Partitioned (`_bonded` and `_nonbonded`) |
