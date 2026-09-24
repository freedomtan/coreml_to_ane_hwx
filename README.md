# coreml_to_ane_hwx
a quick and dirty little program to convert Apple CoreML model to ANE hwx file

# CoreML model
CoreML format is publicly available, https://apple.github.io/coremltools/mlmodel/index.html

# HWX
HWX is a proprietary modified Mach-O file format to pass models to AppleH11ANEInterface, an I/O Kit kernel driver in macOS and iOS when Apple Neural Engine is available.

# How to use this little program

## Quick Start

Simply `make` it on macOS either x86_64 or Apple Silicon machines. YES, Apple ships ANE related x86_64 binaries on machines without ANE, so we can compile and run this on x86_64 machines.

Get a CoreML model, e.g., `wget https://ml-assets.apple.com/coreml/models/Image/ImageClassification/MobileNetV2/MobileNetV2.mlmodel` or use [coremltools](https://github.com/apple/coremltools) to convert one. Then, we can convert the model by
```
./coreml2hwx MobileNetV2.mlmodel debug
```
And get results like

```
./coreml2hwx MobileNetV2.mlmodel debug
2021-05-24 18:47:38.549 coreml2hwx[44933:4104983] original mlmodel file: file:///Users/freedom/work/coreml_to_ane_hwx/MobileNetV2.mlmodel 
2021-05-24 18:47:39.175 coreml2hwx[44933:4104983] espresso model in mlmodelc directory: /var/folders/w5/979yc47d3xd7217w52w_59tm0000gn/T/MobileNetV2_BBAC2D27-E28E-4135-ABB4-E5B8C81C395B.mlmodelc/model.espresso.net 
2021-05-24 18:47:40.064 coreml2hwx[44933:4104983] options:
{
    InputNetworks =     (
                {
            NetworkPlistName = "net.plist";
            NetworkPlistPath = "/tmp/espresso_ir_dump/";
        }
    );
    OutputFileName = "model.hwx";
    OutputFilePath = "/tmp/hwx_output/MobileNetV2/";
}
2021-05-24 18:47:40.064 coreml2hwx[44933:4104983] result at /tmp/hwx_output/MobileNetV2/model.hwx
2021-05-24 18:47:40.064 coreml2hwx[44933:4104983] other debug information at /tmp/hwx_output/MobileNetV2/
```

## Documentation & Technical Guides

Comprehensive guides and architecture deep dives are available in the [`docs/`](docs/) directory:

- 📖 **[WORKFLOW_MLPACKAGE_TO_HWX_ANALYSIS.md](docs/WORKFLOW_MLPACKAGE_TO_HWX_ANALYSIS.md)**: End-to-end compilation pipeline walkthrough (PyTorch/TensorFlow $\rightarrow$ CoreML `.mlpackage` $\rightarrow$ `.mlmodelc` $\rightarrow$ MIL $\rightarrow$ `.hwx` generation and parsing).
- 📖 **[GUIDE_ANE_HWX_FORMAT.md](docs/GUIDE_ANE_HWX_FORMAT.md)**: Comprehensive architectural reference on the `.hwx` Mach-O container, task descriptor headers, and instruction stream formatting across generations (H11–H19).
- 📖 **[GUIDE_H18G_H19_BONDED_NETWORKS.md](docs/GUIDE_H18G_H19_BONDED_NETWORKS.md)**: Architectural analysis of the major shift in H18g/H19: dual-network bundling (`main__nonbonded` + `main__bonded`), cooperative multi-engine execution across ANE 0/1, 2D spatial DAG slicing, and the new `__RUNTIME` segment.
- 📖 **[HOWTO_VERIFY_H18G_ISA_AND_SUBTYPE.md](docs/HOWTO_VERIFY_H18G_ISA_AND_SUBTYPE.md)**: Step-by-step reverse-engineering guide explaining how to discover and verify `h18g`'s true CPU subtype and ISA version.
  > [!NOTE]
  > **Why a dedicated guide for H18g?**
  > In all previous generations, M-series variants shared the exact same CPU subtype and ISA version as their companion A-series base chip. For example, **H17g (M5)** and **H17 (A18 Pro)** both share **CPU Subtype 9 / ISA v19** (`ZinIrHalH17*`).
  >
  > However, **H18g (M6) breaks this convention**: despite its `h18*` naming prefix, it does *not* share Subtype 10 / ISA v20 with H18 (A19). Instead, `TargetH18g` instantiates `ZinIrHal2026BaseLine`, making it a **CPU Subtype 11 / ISA v24** architecture alongside H19 (A20 Pro). The guide details how this was proven via Mach-O header analysis, `ANECompiler` static disassembly, and dynamic LLDB tracing.

# mlmodelc to hwx
There are many compiled CoreML models in macOS and iOS. Some have meta infomation; some do not. For those
who do not have meta information, we still can dump information with ANECCompile/Zin compiler.

```
./mlmodelc2hwx /System/Library/PrivateFrameworks/CoreHandwriting.framework/Versions/A/Resources/zh.bundle debug
2021-06-14 15:00:23.145 mlmodelc2hwx[36034:2122508] espresso model in mlmodelc directory: /System/Library/PrivateFrameworks/CoreHandwriting.framework/Versions/A/Resources/zh.bundle/model.espresso.net 
2021-06-14 15:00:24.063 mlmodelc2hwx[36034:2122508] options:
{
    InputNetworks =     (
                {
            NetworkPlistName = "net.plist";
            NetworkPlistPath = "/tmp/espresso_ir_dump/";
        }
    );
    OutputFileName = "model.hwx";
    OutputFilePath = "/tmp/hwx_output/zh/";
}
2021-06-14 15:00:24.063 mlmodelc2hwx[36034:2122508] result at /tmp/hwx_output/zh/model.hwx
2021-06-14 15:00:24.063 mlmodelc2hwx[36034:2122508] other debug information at /tmp/hwx_output/zh/
```
In the DOT graph files in /tmp/hwx_output/zh/, we can see easily see the Chinese handwritten recongition CNN model takes a 48x48 bitmap and outputs a 29,321 array.  

# Credits
@geohot reverse-engineered lots ANE related information, including HWX format. See [ane code](https://github.com/tinygrad/tinygrad/tree/v0.10.3/extra/accel/ane) in tinygrad and his hacking videos.

@geekwish provided useful Espresso related information in his [ANETools](https://github.com/antgroup-arclab/ANETools).

---

## 🌐 Web-Based HWX Analyzer

Try the **interactive web-based parser** (no installation needed):

👉 **[https://freedomtan.github.io/coreml_to_ane_hwx/hwx_dump_js/](https://freedomtan.github.io/coreml_to_ane_hwx/hwx_dump_js/)**

Features:
- Drag & drop `.hwx` files directly in your browser
- Client-side parsing (no files uploaded to servers)
- Visual register inspector for all hardware blocks
- Supports H13-H19 architectures (A14-A20 Pro / M1-M6 chips)
- Generated by Antigravity CLI from the [ANE HWX Format Guide](docs/GUIDE_ANE_HWX_FORMAT.md)
