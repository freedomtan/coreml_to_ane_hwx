#import <Foundation/Foundation.h>

#import "coreml_util.h"

int main(int argc, char* argv[]) {
  NSString* lastModelcDirName = [[[NSString stringWithUTF8String:argv[1]] lastPathComponent]
      stringByDeletingPathExtension];
  NSString* espressonet = [NSString stringWithUTF8String:argv[1]];
  NSLog(@"espresso model: %@ ", espressonet);

  int ret = mlmodelc_to_espresso_ir(espressonet);
  if (ret)
    exit(ret);

  if (argc > 2)
    ret = espresso_ir_hwx(lastModelcDirName, true);
  else
    ret = espresso_ir_hwx(lastModelcDirName, false);

  return ret;
}
