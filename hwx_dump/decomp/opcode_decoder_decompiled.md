# Decompiled: `ZinIrEnumToStringUtil::OpCodeToString()`

This utility method provides the symbolic name for a given `ZinIrOpLayerOpCodeType`. It is implemented as a direct index-based lookup into a static table of string pointers.

## C++ Reconstruction

```cpp
/**
 * Resolves a Zinc IR OpCode ID to its symbolic string name.
 * 
 * @param opcode The integer ID of the OpCode (0-124).
 * @return A std::string containing the human-readable name.
 */
std::string ZinIrEnumToStringUtil::OpCodeToString(ZinIrOpLayerOpCodeType opcode) {
    // The table is located at 0x1e757f4c0 in the ANECompiler binary.
    // Each entry is an 8-byte pointer to a null-terminated C-string.
    static const char* const OpCodeNames[] = {
        /* 0   */ "CONV",
        /* 1   */ "POOL",
        /* 2   */ "SCALE_BIAS",
        /* 3   */ "TERNARY_DYN",
        /* 4   */ "ACTIVATION",
        /* 5   */ "EW",
        /* 6   */ "SCALED_EW",
        /* 7   */ "CONCAT",
        /* 8   */ "SPLIT",
        /* ... */
        /* 89  */ "PEFUSED_ELEMENTWISE",
        /* 90  */ "PEFUSED_SECUREFLUSH",
        /* 91  */ "PEFUSED_POOL",
        /* 92  */ "PEFUSED_GOC",
        /* 93  */ "NEFUSED_CONV",
        /* 94  */ "NEFUSED_KERNEL_RASTERIZER",
        /* 95  */ "NEFUSED_CROSS_CORRELATION",
        /* 96  */ "NEFUSED_MATMUL",
        /* 97  */ "NEFUSED_POOL",
        /* 98  */ "NEFUSED_EW",
        /* 99  */ "NEFUSED_DUAL_SOURCE_EW",
        /* 100 */ "NEFUSED_BYPASS",
        /* 101 */ "NEFUSED_RCAS",
        /* 102 */ "TRANSPOSE_ENGINE_OP",
        /* ... */
        /* 124 */ "INVALID"
    };

    // The binary uses a single LDR instruction with scale-by-8 to index the table.
    // Address: 0x1a69c36dc
    const char* name = OpCodeNames[static_cast<uint32_t>(opcode)];
    
    // Construct and return std::string
    return std::string(name);
}
```

## Assembly Walkthrough

| Address | Instruction | Description |
| :--- | :--- | :--- |
| `0x1a69c36dc` | `adrp x9, 0x1e757f000` | Load page of the jump table |
| `0x1a69c36e0` | `add x9, x9, #0x4c0` | `x9 = 0x1e757f4c0` (Base of Table) |
| `0x1a69c36e4` | `ldr x1, [x9, w0, sxtw #3]` | `x1 = Table[opcode * 8]` (Get string pointer) |
| `0x1a69c36ec` | `b std::string::ctor` | Jump to string constructor with pointer in `x1` |

---

## Exhaustive Zinc IR OpCode List (0–124)

| ID | Symbolic Name | ID | Symbolic Name | ID | Symbolic Name |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **0** | `CONV` | **42** | `LIVEIN_PARAM` | **84** | `SAMPLER` |
| **1** | `POOL` | **43** | `CONST_IN` | **85** | `GRID_SAMPLE` |
| **2** | `SCALE_BIAS` | **44** | `LIVE_STATE` | **86** | `ONE_HOT` |
| **3** | `TERNARY_DYN` | **45** | `REDUCTION` | **87** | `TOP_K` |
| **4** | `ACTIVATION` | **46** | `LIVE_OUT` | **88** | `CUMULATIVE_SUM` |
| **5** | `EW` | **47** | `REINTERPRET_INNER_DIM` | **89** | `PEFUSED_ELEMENTWISE` |
| **6** | `SCALED_EW` | **48** | `REINTERPRET_CAST` | **90** | `PEFUSED_SECUREFLUSH` |
| **7** | `CONCAT` | **49** | `RESHAPE` | **91** | `PEFUSED_POOL` |
| **8** | `SPLIT` | **50** | `TRANSPOSE` | **92** | `PEFUSED_GOC` |
| **9** | `FLATTEN` | **51** | `SPACE_TO_BATCH` | **93** | `NEFUSED_CONV` |
| **10** | `UNFLATTEN` | **52** | `BATCH_TO_SPACE` | **94** | `NEFUSED_KERNEL_RAST` |
| **11** | `CROSS_CORRELATION` | **53** | `SPACE_TO_CHANNEL` | **95** | `NEFUSED_CROSS_CORR` |
| **12** | `CROSS_PRODUCT` | **54** | `CHANNEL_TO_SPACE` | **96** | `NEFUSED_MATMUL` |
| **13** | `KERNEL_RASTERIZER` | **55** | `LRN` | **97** | `NEFUSED_POOL` |
| **14** | `ARG_MIN_MAX` | **56** | `SOFTMAX` | **98** | `NEFUSED_EW` |
| **15** | `GLOBAL_ARG_MIN_MAX` | **57** | `MINMAX_NORM` | **99** | `NEFUSED_DUAL_SRC_EW` |
| **16** | `MATRIX_MULT` | **58** | `COST_VOLUME` | **100** | `NEFUSED_BYPASS` |
| **17** | `BROADCAST` | **59** | `PIXEL_SHUFFLE` | **101** | `NEFUSED_RCAS` |
| **18** | `FLATTEN_COMPOSITE` | **60** | `MATRIX_DECOMP` | **102** | `TRANSPOSE_ENGINE_OP` |
| **19** | `UNFLATTEN_COMP` | **61** | `RS` | **103** | `TE_RESAMPLE` |
| **20** | `FPS_RADIUS_COMP` | **62** | `RESAMPLE` | **104** | `TE_AFFINE_TRANSFORM` |
| **21** | `PIXEL_SHUFFLE_COMP` | **63** | `GATHER` | **105** | `TE_PAD` |
| **22** | `PIXEL_UNSHUFFLE_COMP` | **64** | `TILE` | **106** | `TE_CROP_RESIZE` |
| **23** | `CONV_COMPOSITE` | **65** | `SLICE` | **107** | `TE_SLICE` |
| **24** | `MATDECOMP_MATMULT` | **66** | `PAD` | **108** | `TE_GATHER` |
| **25** | `CHAN_TO_SPACE_LRG` | **67** | `RESIZE` | **109** | `TE_RESIZE` |
| **26** | `LIVE_IN` | **68** | `RESIZEAS` | **110** | `TM_WAIT_FOR_EVENT` |
| **27** | `ARGMIN` | **69** | `CROP_RESIZE` | **111** | `TM_SIGNAL_EVENT` |
| **28** | `ARGMAX` | **70** | `AFFINE_TRANSFORM` | **112** | `TM_BRANCH` |
| **29** | `SVD` | **71** | `PLANE_READER` | **113** | `TM_FETCH` |
| **30** | `LST_SQ_FIT` | **72** | `PLANE_WRITER` | **114** | `TM_STORE` |
| **31** | `QR` | **73** | `SORT` | **115** | `TM_USER_SLOT_LOAD` |
| **32** | `EIGEN` | **74** | `TOP_K` | **116** | `TM_OPERATE` |
| **33** | `CHOLESKY` | **75** | `RCAS` | **117** | `DMA_CONVERT` |
| **34** | `MATRIX_INV` | **76** | `INDEX` | **118** | `QUANT` |
| **35** | `MATRIX_LOGARITHM` | **77** | `TYPE_CAST` | **119** | `DEQUANT` |
| **36** | `MATRIX_SQRT` | **78** | `STOCHASTIC_ROUND` | **120** | `WAIT_FOR_EVENT` |
| **37** | `EXPAND_DIMS` | **79** | `LINEAR` | **121** | `SIGNAL_EVENT` |
| **38** | `SQUEEZE` | **80** | `RINGBUFFER_READER` | **122** | `ALL_SLICE` |
| **39** | `FLATTEN` | **81** | `RINGBUFFER_WRITE` | **123** | `ALL_GATHER` |
| **40** | `PERMUTE` | **82** | `CONDITION` | **124** | `INVALID` |
| **41** | `REVERSE` | **83** | `PHI` | | |
