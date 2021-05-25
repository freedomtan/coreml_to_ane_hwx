# coreml_to_ane_hwx
a quick and dirty little program to convert Apple CoreML model to ANE hwx file

# CoreML model
CoreML format is publicly available, https://mlmodel.readme.io/reference/model

# HWX
HWX is a proprietary modified Mach-O file format to pass models to AppleH11ANEInterface, an I/O Kit kernel driver in macOS and iOS when Apple Neural Engine is available.

# How to use this little progam
Simply `make` it on macOS either x86_64 or Apple Silicon machines. YES, Apple ships ANE related x86_64 binaries on machines without ANE, so we can compile and run this on x86_64 machines.

Get a coreml model, e.g., `wget https://ml-assets.apple.com/coreml/models/Image/ImageClassification/MobileNetV2/MobileNetV2.mlmodel` or use [coremltools](https://github.com/apple/coremltools) to convert one. Then, we can convert the model by
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

# Credits
@geohot reverse-engineered lots ANE related information, including HWX format. See [ane code](https://github.com/geohot/tinygrad/tree/master/ane) in tinygrad and his hacking videos.

@geekwish provided useful Espresso related information in his [ANETools](https://github.com/antgroup-arclab/ANETools)
