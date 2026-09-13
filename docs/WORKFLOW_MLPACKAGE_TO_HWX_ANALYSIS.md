# Complete Workflow: MLPackage → MIL → HWX Analysis

**Purpose**: An end-to-end, beginner-friendly walkthrough guide for compiling, tracing, and analyzing Apple Neural Engine (ANE) compilation layers, targetting the H16 architecture (A17 Pro / M4) and other modern generations.

---

## Table of Contents

1. [Understanding the Compilation Pipeline](#1-understanding-the-compilation-pipeline)
2. [Glossary of Terms](#2-glossary-of-terms)
3. [Prerequisites & Build Tools Breakdown](#3-prerequisites--build-tools-breakdown)
4. [Step 1: Obtaining the MLPackage Files](#4-step-1-obtaining-the-mlpackage-files)
5. [Step 2: Compiling MLPackage to MLModelC](#5-step-2-compiling-mlpackage-to-mlmodelc)
6. [Step 3: Extracting & Inspecting MIL (Model Intermediate Language)](#6-step-3-extracting--inspecting-mil)
7. [Step 4: Compiling MIL to HWX Machine Code](#7-step-4-compiling-mil-to-hwx)
8. [Step 5: Parsing and Analyzing HWX Files](#8-step-5-parsing-and-analyzing-hwx-files)
9. [Troubleshooting & Debugging Guide](#9-troubleshooting--debugging-guide)

---

## 1. Understanding the Compilation Pipeline

When you write a machine learning model in a framework like **PyTorch** or **TensorFlow**, you define a graph of mathematical equations. You describe how matrices are multiplied and added together.

However, the physical **Apple Neural Engine (ANE) hardware chip** cannot run Python, PyTorch, or high-level graphs directly. It needs to know:
* Which registers to load to configure a 3x3 convolution?
* What stride sizes to set in the DMA (Direct Memory Access) engine?
* Where in local L2 Cache memory to read the inputs and write the outputs?
* How are weights formatted (FP16, INT8, etc.)?

To convert your Python model into hardware instructions, it must go through Apple's compilation pipeline:

```
┌─────────────────────┐
│  PyTorch/TF Model   │  (Mathematical graph defined in Python)
└──────────┬──────────┘
           │ coremltools conversion
           ▼
┌─────────────────────┐
│     .mlpackage      │  (CoreML high-level serialization format)
└──────────┬──────────┘
           │ coremlc compiler (Xcode tools)
           ▼
┌─────────────────────┐
│     .mlmodelc       │  (Compiled model directory ready for execution)
│   ├── model.mil     │  (Intermediate representation: MIL text)
│   └── ...           │  
└──────────┬──────────┘
           │ ANECompiler private framework
           ▼
┌─────────────────────┐
│      model.hwx      │  (ANE machine-executable instruction stream)
└──────────┬──────────┘
           │ hwx_parsing tool
           ▼
┌─────────────────────┐
│ Layer Analysis Report│ (Task-by-task breakdown: cycles, strides, fusions)
└─────────────────────┘
```

---

## 2. Glossary of Terms

For developers new to the Apple compiler ecosystem, here are the key concepts:

* **CoreML**: Apple's framework for integrating machine learning models into iOS/macOS applications.
* **MLPackage (`.mlpackage`)**: The modern CoreML model container format, structured as a folder containing JSON configurations and weight files.
* **MIL (Model Intermediate Language)**: A platform-independent intermediate language. Like LLVM IR for general code, MIL acts as a bridge: front-ends (PyTorch/TensorFlow) translate into MIL, and back-ends (ANE/GPU/CPU compilers) compile MIL into machine instructions.
* **MLModelC (`.mlmodelc`)**: A compiled bundle that iOS/macOS can load. It contains weights optimized for runtime, metadata, and compilation assets.
* **HWX (`.hwx`)**: Hardware eXecution file. This is the binary format containing ANE instruction streams (bytecode) and configuration packets. It is the raw program executed by the ANE hardware coprocessor.
* **ANECompiler**: Apple's private system library (`ANECompiler.framework`) that takes MIL and compiles it into hardware-specific `.hwx` instructions.

---

## 3. Prerequisites & Build Tools Breakdown

### Required CLI Tools

1. **Xcode Command Line Tools**
   These provide essential compilation tools like `clang` (the compiler) and `make` (the build automation tool).
   ```bash
   xcode-select --install
   ```

2. **Python 3 & CoreMLTools**
   Used to convert models from PyTorch or TensorFlow into `.mlpackage` format.
   ```bash
   python3 -m pip install coremltools
   ```

3. **Private Framework Libraries**
   Apple places ANE development frameworks in private system paths. The programs we build will link to:
   * `AppleNeuralEngine.framework` (Controls interaction with the ANE driver)
   * `ANECompiler.framework` (Translates MIL to HWX)
   * `ANEServices.framework` (Core utility functions for ANE)

---

### Compiling the Analysis Tools

We need to build two C/C++ helper programs located in this repository. Let's look at the compilation commands to understand how they work under the hood.

#### 1. Compile `hwx_parsing` (Task Inspector)
This tool parses `.hwx` Mach-O binaries and prints out readable configurations (dimensions, activations, memory stride registers).

```bash
cd hwx_dump
make
cd ..
```

**What the compilation command does:**
```bash
clang -Wall -O2 -framework IOSurface -framework Foundation \
    -F /System/Library/PrivateFrameworks -framework AppleNeuralEngine \
    hwx_parsing.m -o hwx_parsing
```
* `clang`: The C/Objective-C compiler.
* `-Wall -O2`: Enables all warning alerts and applies level 2 performance optimization.
* `-framework Foundation`: Links Apple's core software libraries (data arrays, string processing).
* `-F /System/Library/PrivateFrameworks -framework AppleNeuralEngine`: Tells the compiler to search Apple's hidden private framework folder and link to the Neural Engine framework so we can communicate with ANE drivers.

#### 2. Compile `mil_to_hwx` (Framework Wrapper)
This tool wraps the private `ANECompiler.framework` to convert MIL files directly into `.hwx` binaries.

```bash
make
```

**What the compilation command does:**
```bash
clang++ -std=c++17 -O2 -Wall -Wextra -x objective-c++ \
    -framework Foundation -framework CoreFoundation \
    -F/System/Library/PrivateFrameworks -framework ANECompiler \
    -framework ANEServices mil/mil_to_hwx.cc -o mil_to_hwx
```
* `clang++ -std=c++17`: Compiles C++ code using the modern C++17 language standard.
* `-framework ANECompiler`: Links the private compiler framework that handles the backend translation.

---

## 4. Step 1: Obtaining the MLPackage Files

We will use two standard models for this guide: **ResNet50** (a classic image classification model) and **MobileNetV2** (a lightweight model designed for mobile efficiency).

### Download Pre-converted Models
Download official, pre-converted CoreML models directly from Apple:

```bash
# Download ResNet50
curl -L -o ResNet50.mlpackage.zip "https://ml-assets.apple.com/coreml/quantized_models/uncompressed/ResNet50.mlpackage.zip"
unzip ResNet50.mlpackage.zip

# Download MobileNetV2
curl -L -o MobileNetV2Alpha1.mlpackage.zip "https://ml-assets.apple.com/coreml/quantized_models/uncompressed/MobileNetV2Alpha1.mlpackage.zip"
unzip MobileNetV2Alpha1.mlpackage.zip
```

### Alternatively: Convert a PyTorch Model
If you want to compile your own PyTorch model, run this Python script:

```python
import torch
import torchvision
import coremltools as ct

# 1. Load a pre-trained PyTorch model
pytorch_model = torchvision.models.resnet50(pretrained=True)
pytorch_model.eval() # Put the model in evaluation mode

# 2. Create sample input (batch size=1, channels=3, height=224, width=224)
dummy_input = torch.rand(1, 3, 224, 224)

# 3. Trace the execution graph of the model
traced_model = torch.jit.trace(pytorch_model, dummy_input)

# 4. Translate into CoreML package format
mlmodel = ct.convert(
    traced_model,
    inputs=[ct.TensorType(name="image", shape=(1, 3, 224, 224))],
    compute_units=ct.ComputeUnit.ALL # Enable CPU, GPU, and ANE
)

# 5. Save output folder
mlmodel.save("ResNet50.mlpackage")
print("Model saved successfully as ResNet50.mlpackage!")
```

---

## 5. Step 2: Compiling MLPackage to MLModelC

The first step in compilation is using Apple's system utility, `coremlc`, to compile the `.mlpackage` directory into an executable `.mlmodelc` bundle.

```bash
# General Syntax:
# xcrun coremlc compile <input.mlpackage> <output_directory>

# Compile ResNet50:
xcrun coremlc compile ResNet50.mlpackage /tmp/
```

### What Happens During this Step?
The compiler analyzes the model layers, quantizes weights if requested, and outputs a `/tmp/ResNet50.mlmodelc/` folder structure:
* `model.mil`: The Model Intermediate Language text representation.
* `model.espresso.net`: Espresso graph configuration (internal CoreML format).
* `coremldata.bin`: Packaged weights, biases, and parameters.
* `metadata.json`: Information about input names, output formats, and hardware targets.

---

## 6. Step 3: Extracting & Inspecting MIL

MIL is a human-readable text file that describes every layer of the neural network. You can find it inside the compiled directory:

```bash
# View the first 50 lines of the intermediate model representation
cat /tmp/ResNet50.mlmodelc/model.mil | head -50
```

### Identifying Operations
To inspect what operations the model contains, we search the MIL file. For example, let's filter for tensor declarations:

```bash
grep -E "^\s+tensor" /tmp/ResNet50.mlmodelc/model.mil | head -20
```

**Example MIL Snippet:**
```
tensor<fp16, [1, 3, 224, 224]> input_cast = cast(dtype = "fp16", x = image);
tensor<fp16, [64, 3, 7, 7]> conv1_weights = const();
tensor<fp16, [1, 64, 112, 112]> conv1 = conv(dilations = [1, 1], groups = 1, pad = [3, 3, 3, 3], strides = [2, 2], ...);
```
* This shows the model taking an input image, casting it to 16-bit floating point precision (`fp16`), and running a **2D convolution** (`conv`) layer with a 7x7 filter, a stride of 2, and 3-pixel padding on all sides.

### Counting Layer Types
You can count the operations using standard shell processing tools:
```bash
grep -oE "= [a-z_]+\(" /tmp/ResNet50.mlmodelc/model.mil | \
    sed 's/= //' | sed 's/(//' | sort | uniq -c | sort -nr
```
This tells you exactly how many Convolutions, ReLUs, Additions, and Pooling operations are inside your model graph.

---

## 7. Step 4: Compiling MIL to HWX

Now we compile the platform-independent MIL representations into hardware-specific binary execution files using our `mil_to_hwx` tool.

```bash
# Syntax: ./mil_to_hwx <model_name_prefix_in_tmp> [target_architecture]
# Default target architecture is H16 (A17 Pro / M4)

./mil_to_hwx ResNet50
```

### Compiling for Different ANE Hardware Generations
Because registers and instructions differ between Apple chips, you can specify target architectures. This generates different bytecode output directories under `/tmp/hwx_output/`:

```bash
# Compile for M2 (H14)
./mil_to_hwx ResNet50 h14

# Compile for A16 Bionic (H15)
./mil_to_hwx ResNet50 h15

# Compile for A17 Pro / M4 (H16)
./mil_to_hwx ResNet50 h16

# Compile for A18 / M5 (H17)
./mil_to_hwx ResNet50 h17

# Compile for A19 (H18)
./mil_to_hwx ResNet50 h18
```

The output file is written to:
`/tmp/hwx_output/ResNet50_h16/model.hwx`

---

## 8. Step 5: Parsing and Analyzing HWX Files

We run the compiled `hwx_parsing` binary to inspect the resulting hardware execution code.

```bash
./hwx_dump/hwx_parsing /tmp/hwx_output/ResNet50_h16/model.hwx
```

### Analyzing the Output

#### 1. File Metadata
The parser prints out details from the Mach-O header:
```
Magic verified: 0xbeefface
CPU Type: 0x0080
CPU Subtype: 0x0007 (H16)
Number of Load Commands: 14
```
* This tells us the binary was compiled specifically for **H16 (A17 Pro/M4)** hardware.

#### 2. Analyzing Tasks (Layer Operations)
The ANE breaks the model down into **Tasks**. Let's check **Task 0**:
```
[ANE Task 0 @ 0x10] (Size: 0x1ac bytes)
  TID: 0x0000 TaskSize: 0x6b ExeCycles: 107 ENE: 5 DTID: 0x1540
  --- Common (0x0000) ---
  InDim     : W=224 H=224 C=3 D=0 Type=FLOAT16
  OutDim    : W=112 H=112 C=64 D=0 Type=FLOAT16
  NumGroups : 8
  ConvCfg   : K=7x7 S=2x2 P(left/top)=3x3 O=1x1
```
* **ExeCycles: 107**: The hardware expects to execute this convolution in just 107 clock cycles.
* **InDim / OutDim**: The input was a `224x224` image with 3 color channels. The output is `112x112` with 64 channels.
* **ConvCfg**: The hardware registers were programmed for a 7x7 kernel (`K=7x7`), a stride of 2 (`S=2x2`), and a padding of 3 (`P=3x3`).

### Profiling Performance
You can sum up the expected execution cycles of all tasks in the network using this script to see the relative cost of your model:

```bash
./hwx_dump/hwx_parsing /tmp/hwx_output/ResNet50_h16/model.hwx | \
    grep "ExeCycles:" | \
    awk '{for(i=1;i<=NF;i++) if($i=="ExeCycles:") print $(i+1)}' | \
    awk '{sum+=$1} END {print "Total Expected ANE Cycles:", sum}'
```

---

## 9. Troubleshooting & Debugging Guide

### Issue 1: Compiler tool `coremlc` is not found
* **Error message**: `xcrun: error: unable to find utility "coremlc"`
* **Cause**: Xcode developer tools are not correctly set up, or the active developer directory is set to a standard command-line tools directory instead of Xcode.
* **Fix**:
  1. Open Xcode app and agree to license terms.
  2. Run this command to reset the active developer tool paths:
     ```bash
     sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
     ```

### Issue 2: Compilation fails inside private frameworks
* **Error message**: `ANECCompile failed with code 1`
* **Causes**:
  1. **Unsupported Operations**: You are trying to compile a model containing operations that the Neural Engine chip does not support (e.g., complex control flow, custom dynamic resizing, or unsupported activations like Swish).
  2. **Dimension Constraints**: ANE hardware requires certain alignments. For example, some layers fail to compile if tensor channel sizes are not multiples of 8 or 16.
* **Fix**:
  * Run compilation in verbose mode to view compiler logs:
    ```bash
    ./mil_to_hwx -v ResNet50
    ```
  * Search the verbose logs for warnings containing the string `Fall back to GPU` or `Unsupported`.
  * Adjust your PyTorch model to use ANE-friendly layers (e.g., standard convolutions, ReLUs, and pooling).

### Issue 3: hwx_parsing returns "Segmentation Fault"
* **Error message**: `Segmentation fault: 11`
* **Cause**: The parser tried to read outside the limits of the `.hwx` file. This usually happens if the file was corrupted during compilation, or the `.hwx` format header differed from expected structures.
* **Fix**:
  1. Check the integrity of the file:
     ```bash
     file /tmp/hwx_output/ResNet50_h16/model.hwx
     ```
     It must report: `Mach-O 64-bit executable arm64e`.
  2. If the file is extremely small (< 1 KB), the compilation failed. Verify that your `/tmp/` files exist and re-run compilation.
