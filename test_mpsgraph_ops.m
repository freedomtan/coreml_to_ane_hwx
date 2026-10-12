/**
 * test_mpsgraph_ops.m
 *
 * Systematic sweep across MPSGraph operations to test ANE HWX binary compilation
 * on target architectures (e.g. h18p for A19 Pro).
 */

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShadersGraph/MetalPerformanceShadersGraph.h>

@interface MPSGraphDeviceDescriptor : NSObject
- (instancetype)initWithSerializedProperties:(NSArray *)props;
@end

@interface MPSGraphDevice (TargetArch)
- (instancetype)initWithDeviceDescriptor:(MPSGraphDeviceDescriptor *)desc;
@end

@interface MPSGraphCompilationDescriptor (Private)
@property (nonatomic, assign) unsigned long long preferredDevice;
- (void)setEnableCompileResourcesForPackage:(BOOL)val;
@end

@interface MPSGraphExecutableSerializationDescriptor (Private)
@property (readwrite, assign) BOOL serializeOriginalModule;
@end

@interface MPSGraphExecutable (Package)
- (void)serializeToMPSGraphPackageAtURL:(NSURL *)url descriptor:(id)desc;
@end

typedef MPSGraphTensor * (^OpBuilderBlock)(MPSGraph *graph, NSArray *shape, MPSDataType dtype, NSDictionary **outFeeds);

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *targetArch = @"h18p";
        NSString *singleOp = nil;
        BOOL listOnly = NO;
        BOOL dumpHwx = NO;

        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "--arch") == 0 && i + 1 < argc) {
                targetArch = [NSString stringWithUTF8String:argv[++i]];
            } else if (strcmp(argv[i], "--op") == 0 && i + 1 < argc) {
                singleOp = [NSString stringWithUTF8String:argv[++i]];
            } else if (strcmp(argv[i], "--list") == 0) {
                listOnly = YES;
            } else if (strcmp(argv[i], "--dump") == 0) {
                dumpHwx = YES;
            } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
                printf("Usage: test_mpsgraph_ops [options]\n");
                printf("  --arch <target>  Target ANE architecture (default: h18p)\n");
                printf("  --op <name>      Test only the specified operation\n");
                printf("  --list           List all registered MPSGraph operations\n");
                printf("  --dump           Run hwx_dump on generated .hwx binary\n");
                printf("  --help, -h       Display this help message\n");
                return 0;
            }
        }

        NSArray *shape4D = @[@(1), @(16), @(16), @(16)];
        MPSDataType fp16 = MPSDataTypeFloat16;

        NSMutableArray *entries = [NSMutableArray array];

        // Helper macro for unary elementwise ops
        #define ADD_UNARY(op_name, category, sel_call) \
        [entries addObject:@{ \
            @"name": @#op_name, \
            @"cat": @#category, \
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) { \
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:dt name:@"x"]; \
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt]}; \
                return [g sel_call]; \
            } \
        }]

        // Helper macro for binary elementwise ops
        #define ADD_BINARY(op_name, category, sel_call) \
        [entries addObject:@{ \
            @"name": @#op_name, \
            @"cat": @#category, \
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) { \
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:dt name:@"x"]; \
                MPSGraphTensor *y = [g placeholderWithShape:s dataType:dt name:@"y"]; \
                *feeds = @{ \
                    x: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt], \
                    y: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt] \
                }; \
                return [g sel_call]; \
            } \
        }]

        // 1. Activations
        ADD_UNARY(reLU, Activation, reLUWithTensor:x name:@"out");
        ADD_UNARY(sigmoid, Activation, sigmoidWithTensor:x name:@"out");
        ADD_UNARY(tanh, Activation, tanhWithTensor:x name:@"out");
        ADD_UNARY(leakyReLU, Activation, leakyReLUWithTensor:x alpha:0.2 name:@"out");

        // 2. Unary Arithmetic & Math
        ADD_UNARY(absolute, Math, absoluteWithTensor:x name:@"out");
        ADD_UNARY(negative, Math, negativeWithTensor:x name:@"out");
        ADD_UNARY(sign, Math, signWithTensor:x name:@"out");
        ADD_UNARY(square, Math, squareWithTensor:x name:@"out");
        ADD_UNARY(squareRoot, Math, squareRootWithTensor:x name:@"out");
        ADD_UNARY(reciprocal, Math, reciprocalWithTensor:x name:@"out");
        ADD_UNARY(reciprocalSquareRoot, Math, reciprocalSquareRootWithTensor:x name:@"out");
        ADD_UNARY(exponent, Math, exponentWithTensor:x name:@"out");
        ADD_UNARY(exponentBase2, Math, exponentBase2WithTensor:x name:@"out");
        ADD_UNARY(exponentBase10, Math, exponentBase10WithTensor:x name:@"out");
        ADD_UNARY(logarithm, Math, logarithmWithTensor:x name:@"out");
        ADD_UNARY(logarithmBase2, Math, logarithmBase2WithTensor:x name:@"out");
        ADD_UNARY(logarithmBase10, Math, logarithmBase10WithTensor:x name:@"out");
        ADD_UNARY(floor, Math, floorWithTensor:x name:@"out");
        ADD_UNARY(ceil, Math, ceilWithTensor:x name:@"out");
        ADD_UNARY(round, Math, roundWithTensor:x name:@"out");
        ADD_UNARY(erf, Math, erfWithTensor:x name:@"out");

        // 3. Trigonometric & Hyperbolic
        ADD_UNARY(sin, Trigonometric, sinWithTensor:x name:@"out");
        ADD_UNARY(cos, Trigonometric, cosWithTensor:x name:@"out");
        ADD_UNARY(tan, Trigonometric, tanWithTensor:x name:@"out");
        ADD_UNARY(asin, Trigonometric, asinWithTensor:x name:@"out");
        ADD_UNARY(acos, Trigonometric, acosWithTensor:x name:@"out");
        ADD_UNARY(atan, Trigonometric, atanWithTensor:x name:@"out");
        ADD_UNARY(sinh, Hyperbolic, sinhWithTensor:x name:@"out");
        ADD_UNARY(cosh, Hyperbolic, coshWithTensor:x name:@"out");
        ADD_UNARY(asinh, Hyperbolic, asinhWithTensor:x name:@"out");
        ADD_UNARY(acosh, Hyperbolic, acoshWithTensor:x name:@"out");
        ADD_UNARY(atanh, Hyperbolic, atanhWithTensor:x name:@"out");

        // 4. Binary Elementwise Arithmetic
        ADD_BINARY(addition, BinaryArithmetic, additionWithPrimaryTensor:x secondaryTensor:y name:@"out");
        ADD_BINARY(subtraction, BinaryArithmetic, subtractionWithPrimaryTensor:x secondaryTensor:y name:@"out");
        ADD_BINARY(multiplication, BinaryArithmetic, multiplicationWithPrimaryTensor:x secondaryTensor:y name:@"out");
        ADD_BINARY(division, BinaryArithmetic, divisionWithPrimaryTensor:x secondaryTensor:y name:@"out");
        ADD_BINARY(power, BinaryArithmetic, powerWithPrimaryTensor:x secondaryTensor:y name:@"out");
        ADD_BINARY(modulo, BinaryArithmetic, moduloWithPrimaryTensor:x secondaryTensor:y name:@"out");
        ADD_BINARY(maximum, BinaryArithmetic, maximumWithPrimaryTensor:x secondaryTensor:y name:@"out");
        ADD_BINARY(minimum, BinaryArithmetic, minimumWithPrimaryTensor:x secondaryTensor:y name:@"out");

        // 5. Comparison Operations
        ADD_BINARY(equal, Comparison, equalWithPrimaryTensor:x secondaryTensor:y name:@"out");
        ADD_BINARY(notEqual, Comparison, notEqualWithPrimaryTensor:x secondaryTensor:y name:@"out");
        ADD_BINARY(lessThan, Comparison, lessThanWithPrimaryTensor:x secondaryTensor:y name:@"out");
        ADD_BINARY(lessThanOrEqualTo, Comparison, lessThanOrEqualToWithPrimaryTensor:x secondaryTensor:y name:@"out");
        ADD_BINARY(greaterThan, Comparison, greaterThanWithPrimaryTensor:x secondaryTensor:y name:@"out");
        ADD_BINARY(greaterThanOrEqualTo, Comparison, greaterThanOrEqualToWithPrimaryTensor:x secondaryTensor:y name:@"out");

        // 6. Logic & Bitwise
        ADD_UNARY(not, Logic, notWithTensor:x name:@"out");
        ADD_BINARY(logicalAND, Logic, logicalANDWithPrimaryTensor:x secondaryTensor:y name:@"out");
        ADD_BINARY(logicalOR, Logic, logicalORWithPrimaryTensor:x secondaryTensor:y name:@"out");
        ADD_BINARY(logicalXOR, Logic, logicalXORWithPrimaryTensor:x secondaryTensor:y name:@"out");

        // Bitwise operations (require Int32 tensors)
        #define ADD_BITWISE_BINARY(op_name, sel_call) \
        [entries addObject:@{ \
            @"name": @#op_name, \
            @"cat": @"Bitwise", \
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) { \
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:MPSDataTypeInt32 name:@"x"]; \
                MPSGraphTensor *y = [g placeholderWithShape:s dataType:MPSDataTypeInt32 name:@"y"]; \
                *feeds = @{ \
                    x: [[MPSGraphShapedType alloc] initWithShape:s dataType:MPSDataTypeInt32], \
                    y: [[MPSGraphShapedType alloc] initWithShape:s dataType:MPSDataTypeInt32] \
                }; \
                return [g sel_call]; \
            } \
        }]
        ADD_BITWISE_BINARY(bitwiseAND, bitwiseANDWithPrimaryTensor:x secondaryTensor:y name:@"out");
        ADD_BITWISE_BINARY(bitwiseOR, bitwiseORWithPrimaryTensor:x secondaryTensor:y name:@"out");
        ADD_BITWISE_BINARY(bitwiseXOR, bitwiseXORWithPrimaryTensor:x secondaryTensor:y name:@"out");
        [entries addObject:@{
            @"name": @"bitwiseNOT",
            @"cat": @"Bitwise",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:MPSDataTypeInt32 name:@"x"];
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:MPSDataTypeInt32]};
                return [g bitwiseNOTWithTensor:x name:@"out"];
            }
        }];

        // 7. Reductions
        [entries addObject:@{
            @"name": @"reductionSum",
            @"cat": @"Reduction",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:dt name:@"x"];
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt]};
                return [g reductionSumWithTensor:x axis:1 name:@"out"];
            }
        }];
        [entries addObject:@{
            @"name": @"reductionMean",
            @"cat": @"Reduction",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:dt name:@"x"];
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt]};
                return [g meanOfTensor:x axes:@[@(1)] name:@"out"];
            }
        }];
        [entries addObject:@{
            @"name": @"reductionMaximum",
            @"cat": @"Reduction",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:dt name:@"x"];
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt]};
                return [g reductionMaximumWithTensor:x axis:1 name:@"out"];
            }
        }];
        [entries addObject:@{
            @"name": @"reductionMinimum",
            @"cat": @"Reduction",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:dt name:@"x"];
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt]};
                return [g reductionMinimumWithTensor:x axis:1 name:@"out"];
            }
        }];
        [entries addObject:@{
            @"name": @"reductionProduct",
            @"cat": @"Reduction",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:dt name:@"x"];
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt]};
                return [g reductionProductWithTensor:x axis:1 name:@"out"];
            }
        }];
        [entries addObject:@{
            @"name": @"cumulativeSum",
            @"cat": @"Reduction",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:dt name:@"x"];
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt]};
                return [g cumulativeSumWithTensor:x axis:1 name:@"out"];
            }
        }];

        // 8. Pooling
        [entries addObject:@{
            @"name": @"maxPooling2D",
            @"cat": @"Pooling",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:dt name:@"x"];
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt]};
                MPSGraphPooling2DOpDescriptor *d = [MPSGraphPooling2DOpDescriptor
                    descriptorWithKernelWidth:2 kernelHeight:2 strideInX:2 strideInY:2
                                 paddingStyle:MPSGraphPaddingStyleTF_SAME
                                   dataLayout:MPSGraphTensorNamedDataLayoutNCHW];
                return [g maxPooling2DWithSourceTensor:x descriptor:d name:@"out"];
            }
        }];
        [entries addObject:@{
            @"name": @"avgPooling2D",
            @"cat": @"Pooling",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:dt name:@"x"];
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt]};
                MPSGraphPooling2DOpDescriptor *d = [MPSGraphPooling2DOpDescriptor
                    descriptorWithKernelWidth:2 kernelHeight:2 strideInX:2 strideInY:2
                                 paddingStyle:MPSGraphPaddingStyleTF_SAME
                                   dataLayout:MPSGraphTensorNamedDataLayoutNCHW];
                return [g avgPooling2DWithSourceTensor:x descriptor:d name:@"out"];
            }
        }];

        // 9. Spatial / Convolutions (Constant weights as required by ANE)
        [entries addObject:@{
            @"name": @"convolution2D",
            @"cat": @"Spatial / Conv",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:dt name:@"x"];
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt]};
                
                NSArray *wShape = @[@(16), @(16), @(3), @(3)];
                NSMutableData *wData = [NSMutableData dataWithLength:16 * 16 * 3 * 3 * sizeof(uint16_t)];
                uint16_t *p = (uint16_t *)wData.mutableBytes;
                for (int i = 0; i < 16 * 16 * 9; i++) p[i] = 0x3c00;
                MPSGraphTensor *w = [g constantWithData:wData shape:wShape dataType:dt];

                MPSGraphConvolution2DOpDescriptor *cd = [MPSGraphConvolution2DOpDescriptor
                    descriptorWithStrideInX:1 strideInY:1 dilationRateInX:1 dilationRateInY:1
                                     groups:1 paddingStyle:MPSGraphPaddingStyleTF_SAME
                                 dataLayout:MPSGraphTensorNamedDataLayoutNCHW
                              weightsLayout:MPSGraphTensorNamedDataLayoutOIHW];
                return [g convolution2DWithSourceTensor:x weightsTensor:w descriptor:cd name:@"out"];
            }
        }];

        [entries addObject:@{
            @"name": @"depthwiseConvolution2D",
            @"cat": @"Spatial / Conv",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:dt name:@"x"];
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt]};
                
                NSArray *wShape = @[@(1), @(16), @(3), @(3)];
                NSMutableData *wData = [NSMutableData dataWithLength:1 * 16 * 3 * 3 * sizeof(uint16_t)];
                uint16_t *p = (uint16_t *)wData.mutableBytes;
                for (int i = 0; i < 16 * 9; i++) p[i] = 0x3c00;
                MPSGraphTensor *w = [g constantWithData:wData shape:wShape dataType:dt];

                MPSGraphDepthwiseConvolution2DOpDescriptor *cd = [MPSGraphDepthwiseConvolution2DOpDescriptor
                    descriptorWithDataLayout:MPSGraphTensorNamedDataLayoutNCHW
                               weightsLayout:MPSGraphTensorNamedDataLayoutOIHW];
                cd.strideInX = 1;
                cd.strideInY = 1;
                cd.paddingStyle = MPSGraphPaddingStyleTF_SAME;
                return [g depthwiseConvolution2DWithSourceTensor:x weightsTensor:w descriptor:cd name:@"out"];
            }
        }];

        // 10. Linear Algebra & Normalization
        [entries addObject:@{
            @"name": @"matrixMultiplication",
            @"cat": @"Linear Algebra",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                NSArray *s2D = @[@(16), @(16)];
                MPSGraphTensor *x = [g placeholderWithShape:s2D dataType:dt name:@"x"];
                MPSGraphTensor *y = [g placeholderWithShape:s2D dataType:dt name:@"y"];
                *feeds = @{
                    x: [[MPSGraphShapedType alloc] initWithShape:s2D dataType:dt],
                    y: [[MPSGraphShapedType alloc] initWithShape:s2D dataType:dt]
                };
                return [g matrixMultiplicationWithPrimaryTensor:x secondaryTensor:y name:@"out"];
            }
        }];

        [entries addObject:@{
            @"name": @"softMax",
            @"cat": @"Normalization",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:dt name:@"x"];
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt]};
                return [g softMaxWithTensor:x axis:1 name:@"out"];
            }
        }];

        // 11. Quantization (INT8 & FP8 E4M3)
        [entries addObject:@{
            @"name": @"quantizeTensor_INT8",
            @"cat": @"Quantization",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:dt name:@"x"];
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt]};
                return [g quantizeTensor:x scale:0.1 zeroPoint:0.0 dataType:MPSDataTypeInt8 name:@"out"];
            }
        }];

        [entries addObject:@{
            @"name": @"dequantizeTensor_INT8",
            @"cat": @"Quantization",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:MPSDataTypeInt8 name:@"x"];
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:MPSDataTypeInt8]};
                return [g dequantizeTensor:x scale:0.1 zeroPoint:0.0 dataType:MPSDataTypeFloat16 name:@"out"];
            }
        }];

        [entries addObject:@{
            @"name": @"quantizeTensor_FP8",
            @"cat": @"Quantization",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:dt name:@"x"];
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt]};
                return [g quantizeTensor:x scale:0.1 zeroPoint:0.0 dataType:MPSDataTypeFloat8e4m3 name:@"out"];
            }
        }];

        [entries addObject:@{
            @"name": @"dequantizeTensor_FP8",
            @"cat": @"Quantization",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:MPSDataTypeFloat8e4m3 name:@"x"];
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:MPSDataTypeFloat8e4m3]};
                return [g dequantizeTensor:x scale:0.1 zeroPoint:0.0 dataType:MPSDataTypeFloat16 name:@"out"];
            }
        }];

        // 12. Attention
        [entries addObject:@{
            @"name": @"scaledDotProductAttention",
            @"cat": @"Attention",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                NSArray *sdpaShape = @[@(1), @(4), @(16), @(32)];
                MPSGraphTensor *q = [g placeholderWithShape:sdpaShape dataType:dt name:@"q"];
                MPSGraphTensor *k = [g placeholderWithShape:sdpaShape dataType:dt name:@"k"];
                MPSGraphTensor *v = [g placeholderWithShape:sdpaShape dataType:dt name:@"v"];
                *feeds = @{
                    q: [[MPSGraphShapedType alloc] initWithShape:sdpaShape dataType:dt],
                    k: [[MPSGraphShapedType alloc] initWithShape:sdpaShape dataType:dt],
                    v: [[MPSGraphShapedType alloc] initWithShape:sdpaShape dataType:dt]
                };
                return [g scaledDotProductAttentionWithQueryTensor:q keyTensor:k valueTensor:v scale:0.125 name:@"out"];
            }
        }];

        // 13. Shape Ops & Tensor Manipulation
        [entries addObject:@{
            @"name": @"reshapeTensor",
            @"cat": @"Tensor Manipulation",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:dt name:@"x"];
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt]};
                return [g reshapeTensor:x withShape:@[@(1), @(16), @(256)] name:@"out"];
            }
        }];

        [entries addObject:@{
            @"name": @"transposeTensor",
            @"cat": @"Tensor Manipulation",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:dt name:@"x"];
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt]};
                return [g transposeTensor:x permutation:@[@(0), @(1), @(3), @(2)] name:@"out"];
            }
        }];

        [entries addObject:@{
            @"name": @"sliceTensor",
            @"cat": @"Tensor Manipulation",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:dt name:@"x"];
                *feeds = @{x: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt]};
                return [g sliceTensor:x dimension:1 start:0 length:8 name:@"out"];
            }
        }];

        [entries addObject:@{
            @"name": @"concatTensors",
            @"cat": @"Tensor Manipulation",
            @"block": ^MPSGraphTensor *(MPSGraph *g, NSArray *s, MPSDataType dt, NSDictionary **feeds) {
                MPSGraphTensor *x = [g placeholderWithShape:s dataType:dt name:@"x"];
                MPSGraphTensor *y = [g placeholderWithShape:s dataType:dt name:@"y"];
                *feeds = @{
                    x: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt],
                    y: [[MPSGraphShapedType alloc] initWithShape:s dataType:dt]
                };
                return [g concatTensors:@[x, y] dimension:1 name:@"out"];
            }
        }];

        if (listOnly) {
            printf("Registered MPSGraph Operations (%lu total):\n", (unsigned long)entries.count);
            for (NSDictionary *item in entries) {
                printf("  %-30s [%s]\n", [item[@"name"] UTF8String], [item[@"cat"] UTF8String]);
            }
            return 0;
        }

        printf("=================================================================\n");
        printf("    MPSGraph Op Support & HWX Generation Benchmark on ANE       \n");
        printf("=================================================================\n");
        printf("Target Architecture: %s (iPhone 17 Pro / A19 Pro)\n", targetArch.UTF8String);

        MPSGraphDeviceDescriptor *devDesc = [[MPSGraphDeviceDescriptor alloc]
            initWithSerializedProperties:@[@(0), @(6), targetArch]];
        MPSGraphDevice *targetDev = [[MPSGraphDevice alloc] initWithDeviceDescriptor:devDesc];
        if (!targetDev) {
            fprintf(stderr, "Error: Failed to create MPSGraphDevice for %s\n", targetArch.UTF8String);
            return 1;
        }

        // Compilation Runner
        printf("\n%-30s | %-20s | %-15s | %s\n", "Operation Name", "Category", "Result", "HWX Generated");
        printf("---------------------------------------------------------------------------------------------\n");

        NSFileManager *fm = [NSFileManager defaultManager];
        int succeeded = 0;
        int failed = 0;
        int ran = 0;

        for (NSDictionary *item in entries) {
            NSString *opName = item[@"name"];
            NSString *category = item[@"cat"];
            OpBuilderBlock builder = item[@"block"];

            if (singleOp && ![singleOp isEqualToString:opName]) {
                continue;
            }
            ran++;

            @try {
                MPSGraph *graph = [MPSGraph new];
                NSDictionary *feeds = nil;
                MPSGraphTensor *target = builder(graph, shape4D, fp16, &feeds);

                MPSGraphCompilationDescriptor *cd = [MPSGraphCompilationDescriptor new];
                cd.preferredDevice = 2; // ANE
                cd.optimizationLevel = MPSGraphOptimizationLevel1;
                if ([cd respondsToSelector:@selector(setEnableCompileResourcesForPackage:)]) {
                    [cd setEnableCompileResourcesForPackage:YES];
                }

                MPSGraphExecutable *exe = [graph compileWithDevice:targetDev
                                                             feeds:feeds
                                                     targetTensors:@[target]
                                                  targetOperations:nil
                                             compilationDescriptor:cd];
                if (!exe) {
                    printf("%-30s | %-20s | ❌ Comp Failed  | No\n", opName.UTF8String, category.UTF8String);
                    failed++;
                    continue;
                }

                NSString *pkgPath = [NSString stringWithFormat:@"/tmp/mpsgraph_%@.mpsgraphpackage", opName];
                [fm removeItemAtPath:pkgPath error:nil];

                MPSGraphExecutableSerializationDescriptor *sDesc = [MPSGraphExecutableSerializationDescriptor new];
                if ([sDesc respondsToSelector:@selector(setSerializeOriginalModule:)]) {
                    sDesc.serializeOriginalModule = YES;
                }
                [exe serializeToMPSGraphPackageAtURL:[NSURL fileURLWithPath:pkgPath] descriptor:sDesc];

                NSString *hwxPath = [pkgPath stringByAppendingPathComponent:@"binary_0.hwx"];
                BOOL hasHwx = [fm fileExistsAtPath:hwxPath];

                if (hasHwx) {
                    printf("%-30s | %-20s | ✅ ANE Succeeded | YES (binary_0.hwx)\n", opName.UTF8String, category.UTF8String);
                    succeeded++;
                    if (dumpHwx) {
                        printf(">>> Dumping HWX Tasks for %s:\n", opName.UTF8String);
                        fflush(stdout);
                        NSString *cmd = [NSString stringWithFormat:@"./hwx_dump/hwx_parsing '%@' | grep -E 'ANE Task [0-9]+' | head -n 10", hwxPath];
                        system(cmd.UTF8String);
                    }
                } else {
                    printf("%-30s | %-20s | ⚠️ Fallback GPU  | No (GPU Only)\n", opName.UTF8String, category.UTF8String);
                    failed++;
                }
            } @catch (NSException *e) {
                printf("%-30s | %-20s | ❌ Exception    | %s\n", opName.UTF8String, category.UTF8String, e.reason.UTF8String);
                failed++;
            }
        }

        printf("---------------------------------------------------------------------------------------------\n");
        printf("Summary: Total Tested: %d | Succeeded on ANE: %d | Fallback/Failed: %d\n\n",
               ran, succeeded, failed);
    }
    return 0;
}
