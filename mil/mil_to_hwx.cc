/**
 * mil_to_hwx - Enhanced MIL to HWX Compiler
 *
 * Compiles CoreML MIL (Machine Intermediate Language) files to ANE HWX
 * (Hardware Executable) format using Apple's ANECompiler framework.
 *
 * Features:
 * - Support for all ANE architectures (H11-H18)
 * - Comprehensive debug output and analytics
 * - Flexible command-line options
 * - Performance tracing configuration
 * - JSON analytics export
 *
 * Author: Enhanced from original mil_to_hwx.cc
 * Date: 2026-05-20
 */

#include <Foundation/Foundation.h>
#include <getopt.h>
#include <os/log.h>
#include <sys/stat.h>
#include <iostream>
#include <string>

// ANECompiler C API
extern "C" {
    typedef unsigned int ANECStatus;

    /**
     * Compile MIL to HWX
     * @param options Compilation options (input/output paths)
     * @param flags Compiler flags (architecture, debug, optimizations)
     * @param callback Completion callback with status
     */
    extern int ANECCompile(
        NSDictionary* options,
        NSDictionary* flags,
        void (^callback)(ANECStatus status, NSDictionary* statusDict)
    );

    /**
     * Get size of analytics buffer in HWX
     */
    extern int ANECGetAnalyticsBufferSize(
        const void* hwx_data,
        unsigned long hwx_size,
        char* buffer_name,
        unsigned long* buffer_size
    );
}

// Zin Analytics API - available when linking with ANECompiler AND ANEServices
// ANECompiler alone is not sufficient - you must link with both frameworks
// Returns true on success, false on failure
extern bool ZinDumpAnalytics(const void* buffer, size_t size);
extern bool ZinDumpAnalyticsInJSON(const void* buffer, size_t size, const char* output_path);

// Architecture mapping
struct ArchInfo {
    const char* name;
    const char* chip;
    int isa_version;
};

static const ArchInfo ARCHITECTURES[] = {
    {"h11", "A12", 5},
    {"h12", "A13", 6},
    {"h13", "A14/M1", 7},
    {"h14", "A15/M2", 11},
    {"h15", "A16/M3", 8},
    {"h16", "A17 Pro/M4", 17},
    {"h17", "A18/A18 Pro", 19},
    {"h18", "A19", 20},
};

static const int NUM_ARCHITECTURES = sizeof(ARCHITECTURES) / sizeof(ArchInfo);

// Configuration structure
struct CompilerConfig {
    std::string model_name;
    std::string input_path;
    std::string output_path;
    std::string target_arch;
    bool debug;
    bool generate_analytics;
    bool disable_optimizations;
    int debug_mask;
    std::string perf_tracer1;
    std::string perf_tracer2;
    bool verbose;
};

/**
 * Print usage information
 */
void print_usage(const char* prog_name) {
    std::cout << "Usage: " << prog_name << " [OPTIONS] <model_name>\n\n"
              << "Compile CoreML MIL files to ANE HWX format\n\n"
              << "Required:\n"
              << "  model_name              Base name of model (expects /tmp/<name>.mlmodelc/)\n\n"
              << "Options:\n"
              << "  -a, --arch ARCH         Target architecture (default: h16)\n"
              << "                          Valid: h11, h12, h13, h14, h15, h16, h17, h18\n"
              << "  -i, --input PATH        Input directory (default: /tmp/<name>.mlmodelc/)\n"
              << "  -o, --output PATH       Output directory (default: /tmp/hwx_output/)\n"
              << "  -d, --debug             Enable debug mode (default: on)\n"
              << "  -m, --debug-mask MASK   Debug mask value (default: 0x7fffffff)\n"
              << "  -A, --analytics         Generate analytics buffer (default: on)\n"
              << "  -O, --no-optimize       Disable compiler optimizations\n"
              << "  -t, --tracer1 CONFIG    Performance tracer 1 config\n"
              << "                          Example: l2:l2_src1_read_active_cycle:dma_src1_read_active_cycle\n"
              << "  -T, --tracer2 CONFIG    Performance tracer 2 config\n"
              << "                          Example: pe:pe_cycle:read_stall\n"
              << "  -v, --verbose           Verbose output\n"
              << "  -l, --list-archs        List available architectures\n"
              << "  -h, --help              Show this help message\n\n"
              << "Examples:\n"
              << "  # Compile for M4 (default)\n"
              << "  " << prog_name << " MobileNetV2\n\n"
              << "  # Compile for M1 with performance tracing\n"
              << "  " << prog_name << " -a h13 --tracer1 l2:l2_src1_read_active_cycle:dma_src1_read_active_cycle MobileNetV2\n\n"
              << "  # Compile without optimizations for debugging\n"
              << "  " << prog_name << " -O -v ResNet50\n\n"
              << "Input file structure:\n"
              << "  /tmp/<model_name>.mlmodelc/\n"
              << "  └── model.mil            MIL source file\n\n"
              << "Output file structure:\n"
              << "  /tmp/hwx_output/<model_name>/\n"
              << "  ├── model.hwx                   Compiled binary\n"
              << "  ├── model.hwx_AnalyticsBuffer_main  Performance data\n"
              << "  ├── analytics.json              JSON analytics export\n"
              << "  └── (debug info if -d enabled)\n";
}

/**
 * List available architectures
 */
void list_architectures() {
    std::cout << "Available ANE Architectures:\n\n";
    std::cout << "  Arch   Chip            ISA Version\n";
    std::cout << "  -------------------------------------\n";
    for (int i = 0; i < NUM_ARCHITECTURES; i++) {
        printf("  %-6s %-15s V%-2d\n",
               ARCHITECTURES[i].name,
               ARCHITECTURES[i].chip,
               ARCHITECTURES[i].isa_version);
    }
    std::cout << "\nRecommended: h16 (M4) or h17 (A18 Pro) for latest features\n";
}

/**
 * Validate architecture name
 */
bool is_valid_architecture(const std::string& arch) {
    for (int i = 0; i < NUM_ARCHITECTURES; i++) {
        if (arch == ARCHITECTURES[i].name) {
            return true;
        }
    }
    return false;
}

/**
 * Get architecture info
 */
const ArchInfo* get_arch_info(const std::string& arch) {
    for (int i = 0; i < NUM_ARCHITECTURES; i++) {
        if (arch == ARCHITECTURES[i].name) {
            return &ARCHITECTURES[i];
        }
    }
    return nullptr;
}

/**
 * Parse command-line arguments
 */
bool parse_arguments(int argc, char* argv[], CompilerConfig& config) {
    // Default configuration
    config.output_path = "/tmp/hwx_output/";
    config.target_arch = "h16";  // M4 as default
    config.debug = true;
    config.generate_analytics = true;
    config.disable_optimizations = false;
    config.debug_mask = 0x7fffffff;
    config.verbose = false;

    static struct option long_options[] = {
        {"arch",         required_argument, 0, 'a'},
        {"input",        required_argument, 0, 'i'},
        {"output",       required_argument, 0, 'o'},
        {"debug",        no_argument,       0, 'd'},
        {"debug-mask",   required_argument, 0, 'm'},
        {"analytics",    no_argument,       0, 'A'},
        {"no-optimize",  no_argument,       0, 'O'},
        {"tracer1",      required_argument, 0, 't'},
        {"tracer2",      required_argument, 0, 'T'},
        {"verbose",      no_argument,       0, 'v'},
        {"list-archs",   no_argument,       0, 'l'},
        {"help",         no_argument,       0, 'h'},
        {0, 0, 0, 0}
    };

    int opt;
    int option_index = 0;

    while ((opt = getopt_long(argc, argv, "a:i:o:dm:AOt:T:vlh",
                              long_options, &option_index)) != -1) {
        switch (opt) {
            case 'a':
                config.target_arch = optarg;
                if (!is_valid_architecture(config.target_arch)) {
                    std::cerr << "Error: Invalid architecture: " << config.target_arch << "\n";
                    std::cerr << "Use -l to list valid architectures\n";
                    return false;
                }
                break;
            case 'i':
                config.input_path = optarg;
                break;
            case 'o':
                config.output_path = optarg;
                break;
            case 'd':
                config.debug = true;
                break;
            case 'm':
                config.debug_mask = (int)strtol(optarg, nullptr, 0);
                break;
            case 'A':
                config.generate_analytics = true;
                break;
            case 'O':
                config.disable_optimizations = true;
                break;
            case 't':
                config.perf_tracer1 = optarg;
                break;
            case 'T':
                config.perf_tracer2 = optarg;
                break;
            case 'v':
                config.verbose = true;
                break;
            case 'l':
                list_architectures();
                exit(0);
            case 'h':
                print_usage(argv[0]);
                exit(0);
            default:
                print_usage(argv[0]);
                return false;
        }
    }

    // Get model name (required positional argument)
    if (optind >= argc) {
        std::cerr << "Error: Missing required argument <model_name>\n\n";
        print_usage(argv[0]);
        return false;
    }

    config.model_name = argv[optind];

    // Set default input path if not specified
    if (config.input_path.empty()) {
        config.input_path = "/tmp/" + config.model_name + ".mlmodelc/";
    }

    return true;
}

/**
 * Create directory recursively
 */
bool create_directory(const std::string& path) {
    return mkdir(path.c_str(), 0755) == 0 || errno == EEXIST;
}

/**
 * Compile MIL to HWX
 */
int compile_mil_to_hwx(const CompilerConfig& config) {
    const ArchInfo* arch_info = get_arch_info(config.target_arch);

    if (config.verbose) {
        std::cout << "\n=== MIL to HWX Compiler ===\n";
        std::cout << "Model:        " << config.model_name << "\n";
        std::cout << "Input:        " << config.input_path << "\n";
        std::cout << "Output:       " << config.output_path << "\n";
        std::cout << "Architecture: " << config.target_arch
                  << " (" << arch_info->chip << ", ISA V" << arch_info->isa_version << ")\n";
        std::cout << "Debug:        " << (config.debug ? "enabled" : "disabled") << "\n";
        std::cout << "Analytics:    " << (config.generate_analytics ? "enabled" : "disabled") << "\n";
        std::cout << "Optimize:     " << (config.disable_optimizations ? "disabled" : "enabled") << "\n";
        if (!config.perf_tracer1.empty()) {
            std::cout << "Tracer 1:     " << config.perf_tracer1 << "\n";
        }
        if (!config.perf_tracer2.empty()) {
            std::cout << "Tracer 2:     " << config.perf_tracer2 << "\n";
        }
        std::cout << "\n";
    }

    // Create output directories
    if (!create_directory(config.output_path)) {
        std::cerr << "Error: Failed to create output directory: " << config.output_path << "\n";
        return 1;
    }

    std::string model_output_dir = config.output_path + config.model_name + "/";
    if (!create_directory(model_output_dir)) {
        std::cerr << "Error: Failed to create model output directory: " << model_output_dir << "\n";
        return 1;
    }

    // Prepare input dictionary
    NSString* nsInputPath = [NSString stringWithUTF8String:config.input_path.c_str()];
    NSDictionary* inputNetwork = @{
        @"NetworkSourceFileName": @"model.mil",
        @"NetworkSourcePath": nsInputPath,
    };

    NSArray* inputNetworks = @[inputNetwork];

    // Prepare options dictionary
    NSMutableDictionary* optionsDict = [NSMutableDictionary dictionaryWithCapacity:4];
    optionsDict[@"InputNetworks"] = inputNetworks;
    optionsDict[@"OutputFilePath"] = [NSString stringWithUTF8String:model_output_dir.c_str()];
    optionsDict[@"OutputFileName"] = @"model.hwx";

    // Prepare flags dictionary
    NSMutableDictionary* flagsDict = [NSMutableDictionary dictionaryWithCapacity:8];

    // Set target architecture
    flagsDict[@"TargetArchitecture"] = [NSString stringWithUTF8String:config.target_arch.c_str()];

    // Debug flags
    if (config.debug) {
        flagsDict[@"CompileANEProgramForDebugging"] = @YES;
        flagsDict[@"DebugMask"] = @(config.debug_mask);
    }

    // Analytics flags
    if (config.generate_analytics) {
        flagsDict[@"GenerateStaticPerfAnalytics"] = @YES;
        flagsDict[@"GenerateAnalyticsBuffer"] = @YES;
    }

    // Optimization flags
    if (config.disable_optimizations) {
        flagsDict[@"DisableOptimizations"] = @YES;
    }

    // Performance tracer configuration
    if (!config.perf_tracer1.empty()) {
        flagsDict[@"PerfTracer1Config"] = [NSString stringWithUTF8String:config.perf_tracer1.c_str()];
    }
    if (!config.perf_tracer2.empty()) {
        flagsDict[@"PerfTracer2Config"] = [NSString stringWithUTF8String:config.perf_tracer2.c_str()];
    }

    if (config.verbose) {
        NSLog(@"Compilation options:\n%@", optionsDict);
        NSLog(@"Compilation flags:\n%@", flagsDict);
    }

    // Compilation callback
    __block ANECStatus final_status = 0;
    void (^callback)(ANECStatus, NSDictionary*) = ^(ANECStatus status, NSDictionary* statusDict) {
        final_status = status;
        if (status != 0) {
            NSLog(@"Compilation error (status=%u):\n%@", status, statusDict);
        }
    };

    // Compile
    os_log(OS_LOG_DEFAULT, "Starting ANE compilation...");
    int ret = ANECCompile(optionsDict, flagsDict, callback);

    if (ret != 0) {
        std::cerr << "Error: ANECCompile failed with code " << ret << "\n";
        return ret;
    }

    if (final_status != 0) {
        std::cerr << "Error: Compilation failed with status " << final_status << "\n";
        return final_status;
    }

    std::cout << "✓ Compilation successful!\n";
    std::cout << "Output: " << model_output_dir << "model.hwx\n";

    if (config.debug) {
        std::cout << "Debug info: " << model_output_dir << "\n";
    }

    return 0;
}

/**
 * Extract and analyze analytics
 */
int extract_analytics(const CompilerConfig& config) {
    std::string model_output_dir = config.output_path + config.model_name + "/";
    std::string hwx_path = model_output_dir + "model.hwx";
    std::string analytics_path = model_output_dir + "model.hwx_AnalyticsBuffer_main";
    std::string json_path = model_output_dir + "analytics.json";

    // Load HWX file
    NSData* hwxData = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:hwx_path.c_str()]];
    if (!hwxData) {
        std::cerr << "Warning: Could not load HWX file for analytics\n";
        return 1;
    }

    // Get analytics buffer size
    unsigned long bufferLength = 0;
    int ret = ANECGetAnalyticsBufferSize(
        [hwxData bytes],
        [hwxData length],
        (char*)"@default",
        &bufferLength
    );

    if (ret == 0 && config.verbose) {
        std::cout << "Analytics buffer size: " << bufferLength << " bytes\n";
    }

    // Load analytics buffer
    NSData* analyticsData = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:analytics_path.c_str()]];
    if (!analyticsData) {
        std::cerr << "Warning: Analytics buffer not found (compilation may not have generated it)\n";
        return 1;
    }

    std::cout << "\n=== Performance Analytics ===\n";

    // Dump analytics in human-readable format
    bool success = ZinDumpAnalytics([analyticsData bytes], [analyticsData length]);
    if (!success) {
        std::cerr << "Warning: Failed to dump analytics\n";
    }

    // Export to JSON
    success = ZinDumpAnalyticsInJSON(
        [analyticsData bytes],
        [analyticsData length],
        json_path.c_str()
    );

    if (success) {
        std::cout << "\n✓ Analytics exported to: " << json_path << "\n";
    } else {
        std::cerr << "Warning: Failed to export analytics to JSON\n";
    }

    std::cout << "Analytics buffer: " << analytics_path << "\n";
    std::cout << "Buffer size: " << [analyticsData length] << " bytes\n";

    return 0;
}

/**
 * Main entry point
 */
int main(int argc, char* argv[]) {
    @autoreleasepool {
        CompilerConfig config;

        // Parse arguments
        if (!parse_arguments(argc, argv, config)) {
            return 1;
        }

        // Compile MIL to HWX
        int ret = compile_mil_to_hwx(config);
        if (ret != 0) {
            return ret;
        }

        // Extract and analyze analytics (if enabled)
        if (config.generate_analytics) {
            extract_analytics(config);
        }

        std::cout << "\n✓ All done!\n";
        return 0;
    }
}
