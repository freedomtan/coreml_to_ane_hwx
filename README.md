# coreml_to_ane_hwx
a quick and dirty little program to convert Apple CoreML model to ANE hwx file

# CoreML model
CoreML format is publicly available, https://mlmodel.readme.io/reference/model

# HWX
HWX is a proprietary modified Mach-O file format to pass models to AppleH11ANEInterface, an I/O Kit kernel driver in macOS and iOS when Apple Neural Engine is available.


# Credits
@geohot reverse-engineered lots ANE related information, including HWX format. See [ane code](https://github.com/geohot/tinygrad/tree/master/ane) in tinygrad and his hacking videos.

@geekwish provided useful Espresso related information in his [ANETools](https://github.com/antgroup-arclab/ANETools)
