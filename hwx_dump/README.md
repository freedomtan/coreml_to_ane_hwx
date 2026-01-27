# hwx_dump

`hwx_dump` is a utility tool for inspecting and dumping the contents of HWX files (Mach-O based files used by the Apple Neural Engine).

## Overview

The `hwx_parsing` tool parses HWX files and displays detailed information about their structure, including:

*   **Mach-O Headers**: CPU type, file type, flags, etc.
*   **Load Commands**: standard Mach-O load commands and custom ones like `LC_ANE_MAPPED_REGION`.
*   **Segments & Sections**: memory mapping and file offsets.
*   **Symbols**: symbol table entries.
*   **Thread States**: register states for threads.
*   **Text Segment**: To be added.

## Building

To build the tool, simply run `make` in this directory:

```bash
make
```

This will produce the `hwx_parsing` executable.

## Usage

```bash
./hwx_parsing [-s] [-t] <path_to_hwx>
```

### Options

*   `-s`: Dump all symbols (default helps avoid spam by hiding them if there are many).
*   `-t`: Dump thread states (flavors and register values).
*   `<path_to_hwx>`: Path to the input HWX file.

### Example

```bash
./hwx_parsing /tmp/hwx_output/MobileNetV2/model.hwx
```
