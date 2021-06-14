#import <Foundation/Foundation.h>

#import "coreml_util.h"

int main(int argc, char* argv[]) {
  char* coreml_model_file;
  const char* mobilenet = "/tmp/MobileNet.mlmodel";

  if (argc < 2) {
    coreml_model_file = (char*)mobilenet;
  } else {
    coreml_model_file = argv[1];
  }

  NSURL* testURL = [NSURL fileURLWithPath:[NSString stringWithUTF8String:coreml_model_file]];
  NSLog(@"original mlmodel file: %@ ", [testURL absoluteURL]);
  NSString* baseModelName = [[[NSString stringWithUTF8String:coreml_model_file] lastPathComponent]
      stringByDeletingPathExtension];

  NSURL* compiledURL = [MLModel compileModelAtURL:testURL error:nil];
  NSString* espressonet = [[compiledURL path] stringByAppendingString:@"/model.espresso.net"];
  NSLog(@"espresso model in mlmodelc directory: %@ ", espressonet);

  int ret = mlmodelc_to_espresso_ir(espressonet);
  if (ret)
    exit(ret);

  if (argc > 2)
    ret = espresso_ir_hwx(baseModelName, true);
  else
    ret = espresso_ir_hwx(baseModelName, false);

  return ret;
}
