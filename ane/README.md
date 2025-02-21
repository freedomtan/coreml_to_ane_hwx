# run_hwx_with_ane_client
a little program to load and run an Apple ANE hwx file on Apple Silicon
device 

# HWX
HWX is a proprietary modified Mach-O file format to pass models to AppleH11ANEInterface, an I/O Kit kernel driver in macOS and iOS when Apple Neural Engine is available.

To run a .hwx file directly with ANEServices functions 
as described by @geohot needs some hacks (https://github.com/tinygrad/tinygrad/tree/master/extra/accel/ane) which won't work on non-jailbroken iPhones.

# How to use this little progam
Simply `make run_hwx_with_ane_client` on Apple Silicon machines. 

Choose a platform dependent .hwx model, e.g.,
```
/System/Library//PrivateFrameworks/VideoProcessing.framework/Versions/A/Resources/cnn_frame_enhancer_320p.H13.espresso.hwx
```
on a M1 MacBook Pro, I can run

```
$ ./run_hwx_with_ane_client /System/Library//PrivateFrameworks/VideoProcessing.framework/Versions/A/Resources/cnn_frame_enhancer_320p.H13.espresso.hwx 
```

And get results like

```
2025-02-21 16:19:32.823 run_hwx_with_ane_client[52577:18421917] client shared connection <_ANEClient: 0x6000005cc320>
2025-02-21 16:19:32.824 run_hwx_with_ane_client[52577:18421917] is RootDaemon 1
2025-02-21 16:19:32.825 run_hwx_with_ane_client[52577:18421917] is connections {
}
2025-02-21 16:19:32.825 run_hwx_with_ane_client[52577:18421917] is q (
    "<OS_dispatch_queue_serial: com.apple.anef.p0>",
    "<OS_dispatch_queue_serial: com.apple.anef.p1>",
    "<OS_dispatch_queue_serial: com.apple.anef.p2>",
    "<OS_dispatch_queue_serial: com.apple.anef.p3>",
    "<OS_dispatch_queue_serial: com.apple.anef.p4>",
    "<OS_dispatch_queue_serial: com.apple.anef.p5>",
    "<OS_dispatch_queue_serial: com.apple.anef.p6>",
    "<OS_dispatch_queue_serial: com.apple.anef.p7>"
)
2025-02-21 16:19:32.825 run_hwx_with_ane_client[52577:18421917] model: _ANEModel: { modelURL=file:///System/Library/PrivateFrameworks/VideoProcessing.framework/Versions/A/Resources/cnn_frame_enhancer_320p.H13.espresso.hwx : sourceURL=(null) : UUID UUIDString=EAF97B1B-6E49-4C2D-9200-F2D9920C96A0 : UUID=EAF97B1B-6E49-4C2D-9200-F2D9920C96A0 : key=ANE_model : identifierSource=1 : cacheURLIdentifier=(null) : string_id=0x00000000 : string_id=0 : program=(null) : state=1 : programHandle=0 :intermediateBufferHandle=0 : queueDepth=0 : attr={
} : perfStatsMask=0 }
2025-02-21 16:19:32.838 run_hwx_with_ane_client[52577:18421917] model: _ANEModel: { modelURL=file:///System/Library/PrivateFrameworks/VideoProcessing.framework/Versions/A/Resources/cnn_frame_enhancer_320p.H13.espresso.hwx : sourceURL=(null) : UUID UUIDString=EAF97B1B-6E49-4C2D-9200-F2D9920C96A0 : UUID=EAF97B1B-6E49-4C2D-9200-F2D9920C96A0 : key=ANE_model : identifierSource=1 : cacheURLIdentifier=7ED11736238B1CD6FDBFE5CD173642A83B28685CE9952C0FEBF4A09CA6699B01_8055C3CF4DF8937B66D794D3358AEC77E9BCBCF5D112A25BEB76DADDB7FFE8AE : string_id=0x00000000 : string_id=0 : program=_ANEProgramForEvaluation: { programHandle=13180918199944 : intermediateBufferHandle=13180918268745 : queueDepth=127 } : state=3 : programHandle=13180918199944 :intermediateBufferHandle=13180918268745 : queueDepth=127 : attr={
    ANEFModelDescription =     {
        ANEFModelInput16KAlignmentArray =         (
            0,
            0
        );
        ANEFModelOutput16KAlignmentArray =         (
            0,
            0
        );
        ANEFModelProcedures =         (
                        {
                ANEFModelInputSymbolIndexArray =                 (
                    0
                );
                ANEFModelOutputSymbolIndexArray =                 (
                    0
                );
                ANEFModelProcedureID = 0;
            },
                        {
                ANEFModelInputSymbolIndexArray =                 (
                    1
                );
                ANEFModelOutputSymbolIndexArray =                 (
                    1
                );
                ANEFModelProcedureID = 1;
            }
        );
        kANEFModelInputSymbolsArrayKey =         (
            "input_tensor",
            "input_tensor"
        );
        kANEFModelOutputSymbolsArrayKey =         (
            "output_tensor@output",
            "output_tensor@output"
        );
        kANEFModelProcedureNameToIDMapKey =         {
            "0@default" = 1;
            "0@res_320x320" = 0;
        };
    };
    NetworkStatusList =     (
                {
            LiveInputList =             (
                                {
                    4CCFormat = 875704438;
                    Height = 320;
                    Name = "input_tensor";
                    PlaneDescriptor =                     (
                                                {
                            PlaneID = 0;
                            RowStride = 320;
                        },
                                                {
                            PlaneID = 1;
                            RowStride = 320;
                        }
                    );
                    Symbol = "input_tensor";
                    Width = 320;
                }
            );
            LiveOutputList =             (
                                {
                    4CCFormat = 875704438;
                    Height = 640;
                    Name = "output_tensor@output";
                    PlaneDescriptor =                     (
                                                {
                            PlaneID = 0;
                            RowStride = 640;
                        },
                                                {
                            PlaneID = 1;
                            RowStride = 640;
                        }
                    );
                    Symbol = "output_tensor@output";
                    Width = 640;
                }
            );
            Name = "0@res_320x320";
        },
                {
            LiveInputList =             (
                                {
                    4CCFormat = 875704438;
                    Height = 480;
                    Name = "input_tensor";
                    PlaneDescriptor =                     (
                                                {
                            PlaneID = 0;
                            RowStride = 512;
                        },
                                                {
                            PlaneID = 1;
                            RowStride = 512;
                        }
                    );
                    Symbol = "input_tensor";
                    Width = 480;
                }
            );
            LiveOutputList =             (
                                {
                    4CCFormat = 875704438;
                    Height = 960;
                    Name = "output_tensor@output";
                    PlaneDescriptor =                     (
                                                {
                            PlaneID = 0;
                            RowStride = 960;
                        },
                                                {
                            PlaneID = 1;
                            RowStride = 960;
                        }
                    );
                    Symbol = "output_tensor@output";
                    Width = 960;
                }
            );
            Name = "0@default";
        }
    );
} : perfStatsMask=0 }
2025-02-21 16:19:32.838 run_hwx_with_ane_client[52577:18421917] loading error: <_ANEErrors: 0x6000024d8010>
2025-02-21 16:19:32.838 run_hwx_with_ane_client[52577:18421917] is connections {
    0x6000026dcbe0 = "<_ANEDaemonConnection: 0x6000026dcbe0>";
}
2025-02-21 16:19:32.838 run_hwx_with_ane_client[52577:18421917] 0@res_320x320
2025-02-21 16:19:32.838 run_hwx_with_ane_client[52577:18421917] 0, input_tensor
2025-02-21 16:19:32.838 run_hwx_with_ane_client[52577:18421917] 
{
    4CCFormat = 875704438;
    Height = 320;
    Name = "input_tensor";
    PlaneDescriptor =     (
                {
            PlaneID = 0;
            RowStride = 320;
        },
                {
            PlaneID = 1;
            RowStride = 320;
        }
    );
    Symbol = "input_tensor";
    Width = 320;
}
2025-02-21 16:19:32.838 run_hwx_with_ane_client[52577:18421917] (null)
2025-02-21 16:19:32.838 run_hwx_with_ane_client[52577:18421917] keyArray (
    IOSurfacePlaneWidth,
    IOSurfacePlaneHeight,
    IOSurfacePlaneBytesPerRow,
    IOSurfaceAllocSize,
    IOSurfacePlaneOffset
)
2025-02-21 16:19:32.838 run_hwx_with_ane_client[52577:18421917] info (
        {
        IOSurfaceAllocSize = 102400;
        IOSurfacePlaneBytesPerRow = 320;
        IOSurfacePlaneHeight = 320;
        IOSurfacePlaneOffset = 0;
        IOSurfacePlaneWidth = 320;
    },
        {
        IOSurfaceAllocSize = 102400;
        IOSurfacePlaneBytesPerRow = 320;
        IOSurfacePlaneHeight = 320;
        IOSurfacePlaneOffset = 102400;
        IOSurfacePlaneWidth = 320;
    }
)
2025-02-21 16:19:32.843 run_hwx_with_ane_client[52577:18421917] ios <IOSurface: 0x6000024dc190>
    id =  0x00000112 
    width =  320 
    height =  320 
    pixelFormat =  420v 
    name =  input_tensor
2025-02-21 16:19:32.843 run_hwx_with_ane_client[52577:18421917] 0, output_tensor@output
2025-02-21 16:19:32.843 run_hwx_with_ane_client[52577:18421917] 
{
    4CCFormat = 875704438;
    Height = 640;
    Name = "output_tensor@output";
    PlaneDescriptor =     (
                {
            PlaneID = 0;
            RowStride = 640;
        },
                {
            PlaneID = 1;
            RowStride = 640;
        }
    );
    Symbol = "output_tensor@output";
    Width = 640;
}
2025-02-21 16:19:32.843 run_hwx_with_ane_client[52577:18421917] (null)
2025-02-21 16:19:32.843 run_hwx_with_ane_client[52577:18421917] keyArray (
    IOSurfacePlaneWidth,
    IOSurfacePlaneHeight,
    IOSurfacePlaneBytesPerRow,
    IOSurfaceAllocSize,
    IOSurfacePlaneOffset
)
2025-02-21 16:19:32.843 run_hwx_with_ane_client[52577:18421917] info (
        {
        IOSurfaceAllocSize = 409600;
        IOSurfacePlaneBytesPerRow = 640;
        IOSurfacePlaneHeight = 640;
        IOSurfacePlaneOffset = 0;
        IOSurfacePlaneWidth = 640;
    },
        {
        IOSurfaceAllocSize = 409600;
        IOSurfacePlaneBytesPerRow = 640;
        IOSurfacePlaneHeight = 640;
        IOSurfacePlaneOffset = 409600;
        IOSurfacePlaneWidth = 640;
    }
)
2025-02-21 16:19:32.844 run_hwx_with_ane_client[52577:18421917] ios <IOSurface: 0x6000024d01e0>
    id =  0x00000115 
    width =  640 
    height =  640 
    pixelFormat =  420v 
    name =  output_tensor@output
2025-02-21 16:19:32.844 run_hwx_with_ane_client[52577:18421917] request: _ANERequest: { inputArray=(
    "_ANEIOSurfaceObject: { ioSurface=0x6000024dc190 ; startOffset=0 }"
) ; inputIndexArray=(
    0
) ; outputArray=(
    "_ANEIOSurfaceObject: { ioSurface=0x6000024d01e0 ; startOffset=0 }"
) ; outputIndexArray=(
    0
) ; weightsBuffer=(null) ; procedureIndex=0 ; perfStatsArray=(
) ; sharedEvents=(null) ; transactionHandle=(null)}
2025-02-21 16:19:32.849 run_hwx_with_ane_client[52577:18421917] error: <_ANEErrors: 0x6000024d8010>
2025-02-21 16:19:32.849 run_hwx_with_ane_client[52577:18421917] 0@default
2025-02-21 16:19:32.849 run_hwx_with_ane_client[52577:18421917] 1, input_tensor
2025-02-21 16:19:32.849 run_hwx_with_ane_client[52577:18421917] 
{
    4CCFormat = 875704438;
    Height = 480;
    Name = "input_tensor";
    PlaneDescriptor =     (
                {
            PlaneID = 0;
            RowStride = 512;
        },
                {
            PlaneID = 1;
            RowStride = 512;
        }
    );
    Symbol = "input_tensor";
    Width = 480;
}
2025-02-21 16:19:32.849 run_hwx_with_ane_client[52577:18421917] (null)
2025-02-21 16:19:32.849 run_hwx_with_ane_client[52577:18421917] keyArray (
    IOSurfacePlaneWidth,
    IOSurfacePlaneHeight,
    IOSurfacePlaneBytesPerRow,
    IOSurfaceAllocSize,
    IOSurfacePlaneOffset
)
2025-02-21 16:19:32.849 run_hwx_with_ane_client[52577:18421917] info (
        {
        IOSurfaceAllocSize = 245760;
        IOSurfacePlaneBytesPerRow = 512;
        IOSurfacePlaneHeight = 480;
        IOSurfacePlaneOffset = 0;
        IOSurfacePlaneWidth = 480;
    },
        {
        IOSurfaceAllocSize = 245760;
        IOSurfacePlaneBytesPerRow = 512;
        IOSurfacePlaneHeight = 480;
        IOSurfacePlaneOffset = 245760;
        IOSurfacePlaneWidth = 480;
    }
)
2025-02-21 16:19:32.849 run_hwx_with_ane_client[52577:18421917] ios <IOSurface: 0x6000024d0260>
    id =  0x00000180 
    width =  480 
    height =  480 
    pixelFormat =  420v 
    name =  input_tensor
2025-02-21 16:19:32.849 run_hwx_with_ane_client[52577:18421917] 1, output_tensor@output
2025-02-21 16:19:32.850 run_hwx_with_ane_client[52577:18421917] 
{
    4CCFormat = 875704438;
    Height = 960;
    Name = "output_tensor@output";
    PlaneDescriptor =     (
                {
            PlaneID = 0;
            RowStride = 960;
        },
                {
            PlaneID = 1;
            RowStride = 960;
        }
    );
    Symbol = "output_tensor@output";
    Width = 960;
}
2025-02-21 16:19:32.850 run_hwx_with_ane_client[52577:18421917] (null)
2025-02-21 16:19:32.850 run_hwx_with_ane_client[52577:18421917] keyArray (
    IOSurfacePlaneWidth,
    IOSurfacePlaneHeight,
    IOSurfacePlaneBytesPerRow,
    IOSurfaceAllocSize,
    IOSurfacePlaneOffset
)
2025-02-21 16:19:32.850 run_hwx_with_ane_client[52577:18421917] info (
        {
        IOSurfaceAllocSize = 921600;
        IOSurfacePlaneBytesPerRow = 960;
        IOSurfacePlaneHeight = 960;
        IOSurfacePlaneOffset = 0;
        IOSurfacePlaneWidth = 960;
    },
        {
        IOSurfaceAllocSize = 921600;
        IOSurfacePlaneBytesPerRow = 960;
        IOSurfacePlaneHeight = 960;
        IOSurfacePlaneOffset = 921600;
        IOSurfacePlaneWidth = 960;
    }
)
2025-02-21 16:19:32.850 run_hwx_with_ane_client[52577:18421917] ios <IOSurface: 0x6000024d02e0>
    id =  0x00000196 
    width =  960 
    height =  960 
    pixelFormat =  420v 
    name =  output_tensor@output
2025-02-21 16:19:32.850 run_hwx_with_ane_client[52577:18421917] request: _ANERequest: { inputArray=(
    "_ANEIOSurfaceObject: { ioSurface=0x6000024d0260 ; startOffset=0 }"
) ; inputIndexArray=(
    1
) ; outputArray=(
    "_ANEIOSurfaceObject: { ioSurface=0x6000024d02e0 ; startOffset=0 }"
) ; outputIndexArray=(
    1
) ; weightsBuffer=(null) ; procedureIndex=1 ; perfStatsArray=(
) ; sharedEvents=(null) ; transactionHandle=(null)}
2025-02-21 16:19:32.859 run_hwx_with_ane_client[52577:18421917] error: <_ANEErrors: 0x6000024d8010>
```

# _ANE classes and methods in AppleNeuralEngine 
To get more detailed classes and methods, Objective-C `class-dump` tools, such
as `ipsw` [1] and `Runtime Browser` [2], are what you need.

Usage examples of 
```
AppleNeuralEngine`-[_ANEClient loadModel:options:qos:error:]
```
and
```
AppleNeuralEngine`-[_ANEClient evaluateWithModel:options:request:qos:error:]
```
could be found in the Espresso private framework.

[1] https://github.com/blacktop/ipsw
[2] https://github.com/nst/RuntimeBrowser

# Credits
@geohot reverse-engineered lots ANE related information, including HWX format. See [ane code](https://github.com/geohot/tinygrad/tree/master/extra/accel/ane) in tinygrad and his hacking videos.
