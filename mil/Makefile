# Makefile for mil_to_hwx compiler
#
# Located in: mil/ subdirectory
# Output binary: ../mil_to_hwx (project root)

CC = clang++
CFLAGS = -std=c++17 -O2 -Wall -Wextra -x objective-c++
DEBUG_FLAGS = -g -DDEBUG

# Core frameworks
FRAMEWORKS = -framework Foundation -framework CoreFoundation

# Private frameworks - only ANECompiler and ANEServices are needed
PRIVATE_FW = -F/System/Library/PrivateFrameworks \
	-framework ANECompiler \
	-framework ANEServices

# Output to project root
OUTPUT = ../mil_to_hwx

# Default target
all: mil_to_hwx

# Main compiler tool (enhanced version)
mil_to_hwx: mil_to_hwx.cc
	$(CC) $(CFLAGS) $(FRAMEWORKS) $(PRIVATE_FW) $< -o $(OUTPUT)
	@echo "✓ Built mil_to_hwx"
	@echo ""
	@echo "Usage examples:"
	@echo "  ../mil_to_hwx -h                    # Show help"
	@echo "  ../mil_to_hwx -l                    # List architectures"
	@echo "  ../mil_to_hwx MobileNetV2           # Compile for M4"
	@echo "  ../mil_to_hwx -a h13 -v ResNet50    # Compile for M1 (verbose)"

# Legacy build target (same as main target)
mil_to_hwx_enhanced: mil_to_hwx.cc
	$(CC) $(CFLAGS) $(FRAMEWORKS) $(PRIVATE_FW) $< -o $(OUTPUT)
	@echo "✓ Built mil_to_hwx (legacy target name)"

# Debug build
debug: CFLAGS += $(DEBUG_FLAGS)
debug: mil_to_hwx

# Install to /usr/local/bin (requires sudo)
install: mil_to_hwx
	install -m 755 $(OUTPUT) /usr/local/bin/mil_to_hwx
	@echo "✓ Installed to /usr/local/bin/mil_to_hwx"

# Clean build artifacts
clean:
	rm -f $(OUTPUT)
	rm -rf *.dSYM ../*.dSYM
	@echo "✓ Cleaned build artifacts"

# Clean output files
clean-output:
	rm -rf /tmp/hwx_output/
	@echo "✓ Cleaned output directory"

# Full clean
distclean: clean clean-output

# Test with MobileNetV2 (if available)
test: mil_to_hwx
	@if [ -d "/tmp/MobileNetV2.mlmodelc" ]; then \
		./mil_to_hwx -v MobileNetV2; \
	else \
		echo "Error: /tmp/MobileNetV2.mlmodelc not found"; \
		echo "Compile a model first with: xcrun coremlcompiler compile model.mlpackage /tmp/"; \
	fi

# Help target
help:
	@echo "Available targets:"
	@echo "  all              Build mil_to_hwx (default)"
	@echo "  mil_to_hwx       Build main compiler tool"
	@echo "  debug            Build with debug symbols"
	@echo "  install          Install to /usr/local/bin"
	@echo "  test             Test with MobileNetV2 model"
	@echo "  clean            Remove build artifacts"
	@echo "  clean-output     Remove compiled HWX files"
	@echo "  distclean        Remove all generated files"
	@echo "  help             Show this help message"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - macOS 11+ with Apple Silicon"
	@echo "  - Xcode Command Line Tools"
	@echo "  - Private frameworks: ANECompiler, ANEServices"
	@echo ""
	@echo "Frameworks linked:"
	@echo "  Foundation, CoreFoundation (system)"
	@echo "  ANECompiler, ANEServices (private)"

.PHONY: all debug install clean clean-output distclean test help
