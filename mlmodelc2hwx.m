#import <Foundation/Foundation.h>

#import "coreml_util.h"

int main(int argc, char* argv[]) {
  char* modelc_dir;
  const char* chinese_v2 = "/System/Library/PrivateFrameworks/CoreHandwriting.framework/Versions/A/Resources/zh.bundle";

  if (argc < 2) {
    modelc_dir = (char*)chinese_v2;
  } else {
    modelc_dir = argv[1];
  }

  NSString* lastModelcDirName = [[[NSString stringWithUTF8String:modelc_dir] lastPathComponent]
      stringByDeletingPathExtension];

  // NSURL* compiledURL = [MLModel compileModelAtURL:testURL error:nil];
  NSString* espressonet = [[NSString stringWithUTF8String:modelc_dir] stringByAppendingString:@"/model.espresso.net"];
  NSLog(@"espresso model in mlmodelc directory: %@ ", espressonet);

  int ret = mlmodelc_to_espresso_ir(espressonet);
  if (ret)
    exit(ret);

  if (argc > 2)
    ret = espresso_ir_hwx(lastModelcDirName, true);
  else
    ret = espresso_ir_hwx(lastModelcDirName, false);

  return ret;
}
