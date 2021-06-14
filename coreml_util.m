#include "coreml_util.h"

int mlmodelc_to_espresso_ir(NSString *espressonet)
{
  int ret = 0;
  void* ctx = espresso_create_context(0x2718LL, 0xFFFFFFFFLL);
  void* plan = espresso_create_plan(ctx, 0LL);

  uint64_t vals[2];
  ret = espresso_plan_add_network(
      plan, (char*)[espressonet cStringUsingEncoding:NSUTF8StringEncoding], 0x10010LL, vals);
  if (ret) {
    NSLog(@"espresso_plan_add_network ret %d\n", ret);
    return ret;
  }

  ret = espresso_plan_build(plan);
  if (ret) {
    NSLog(@"espresso_plan_build ret %d\n", ret);
    return ret;
  }

  NSString* temp = @"/tmp/espresso_ir_dump/";
  char* foo = (char*)[temp cStringUsingEncoding:NSUTF8StringEncoding];
  ret = espresso_dump_ir(plan, &foo);
  if (ret) {
    NSLog(@"espressor_dump_ir ret %d\n", ret);
    return ret;
  }

  espresso_plan_destroy(plan);
  espresso_context_destroy(ctx);
  return ret;
}

int espresso_ir_hwx(NSString *baseModelName, bool debug)
{
  const char* output_base = "/tmp/hwx_output/";

  os_log(OS_LOG_DEFAULT, "start compiler");
  NSString* temp = @"/tmp/espresso_ir_dump/";
  NSDictionary* iDictionary = @{
    @"NetworkPlistName" : @"net.plist",
    @"NetworkPlistPath" : temp,
  };
  NSArray* plistArray = @[ iDictionary ];

  NSMutableDictionary* optionsDictionary = [NSMutableDictionary dictionaryWithCapacity:4];
  NSMutableDictionary* flagsDictionary = [NSMutableDictionary dictionaryWithCapacity:4];
  optionsDictionary[@"InputNetworks"] = plistArray;

  mkdir(output_base, 0755);
  optionsDictionary[@"OutputFilePath"] = [NSString
      stringWithFormat:@"%@%@/", [NSString stringWithUTF8String:output_base], baseModelName];

  mkdir([optionsDictionary[@"OutputFilePath"] cStringUsingEncoding:NSUTF8StringEncoding], 0755);
  optionsDictionary[@"OutputFileName"] = @"model.hwx";

  if (debug) {
    flagsDictionary[@"CompileANEProgramForDebugging"] = [NSNumber numberWithBool:YES];
    int debug_mask = 0x7fffffff;
    flagsDictionary[@"DebugMask"] = [NSNumber numberWithInt:debug_mask];
  }

  // h11 (or anything?) works here too, and creates different outputs that don't
  // run
  flagsDictionary[@"TargetArchitecture"] = @"h13";

  void (^simpleBlock)(ANECStatus status, NSDictionary* statusDictionary) =
      ^(ANECStatus status, NSDictionary* statusDictionary) {
        // NSLog(@"status = %d\n", status);
        // when status != 0 dump the dictionary
        if (status) NSLog(@"%@", statusDictionary);
      };

  int ret = ANECCompile(optionsDictionary, flagsDictionary, simpleBlock);
  if (!ret) {
    NSLog(@"options:\n%@", optionsDictionary);
    NSLog(@"result at %@%@", optionsDictionary[@"OutputFilePath"],
          optionsDictionary[@"OutputFileName"]);
    if (flagsDictionary[@"CompileANEProgramForDebugging"])
      NSLog(@"other debug information at %@", optionsDictionary[@"OutputFilePath"]);
  }
  return ret;
}

