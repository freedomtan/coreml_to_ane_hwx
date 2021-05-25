#import <CoreML/CoreML.h>
#import <Foundation/Foundation.h>
#import <os/log.h>
#import <sys/stat.h>

extern void* espresso_create_context(uint64_t a1, uint64_t a2);
extern void* espresso_create_plan(void* ctx, uint64_t a2);
extern int espresso_plan_add_network(void* plan, char* path, uint64_t a3, uint64_t a4[2]);
extern int espresso_plan_build(void* plan);
extern int espresso_dump_ir(void* plan, char** ppath);
extern int espresso_plan_destroy(void* plan);
extern int espresso_context_destroy(void* ctx);

typedef unsigned int ANECStatus;
int ANECCompile(NSDictionary* param_1, NSDictionary* param_2,
                void (^param_3)(ANECStatus status, NSDictionary* statusDictionary));

int main(int argc, char* argv[]) {
  char* coreml_model_file;
  const char* mobilenet = "/tmp/MobileNet.mlmodel";
  const char* output_base = "/tmp/hwx_output/";

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

  void* ctx = espresso_create_context(0x2718LL, 0xFFFFFFFFLL);
  void* plan = espresso_create_plan(ctx, 0LL);

  uint64_t vals[2];
  int ret = espresso_plan_add_network(
      plan, (char*)[espressonet cStringUsingEncoding:NSUTF8StringEncoding], 0x10010LL, vals);
  if (ret) {
    NSLog(@"espresso_plan_add_network ret %d\n", ret);
    exit(-1);
  }

  ret = espresso_plan_build(plan);
  if (ret) {
    NSLog(@"espresso_plan_build ret %d\n", ret);
    exit(-1);
  }

  NSString* temp = @"/tmp/espresso_ir_dump/";
  char* foo = (char*)[temp cStringUsingEncoding:NSUTF8StringEncoding];
  ret = espresso_dump_ir(plan, &foo);
  if (ret) {
    NSLog(@"espressor_dump_ir ret %d\n", ret);
    exit(-1);
  }

  espresso_plan_destroy(plan);
  espresso_context_destroy(ctx);

  os_log(OS_LOG_DEFAULT, "start compiler");

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

  if (argc > 2) {
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

  ret = ANECCompile(optionsDictionary, flagsDictionary, simpleBlock);
  if (!ret) {
    NSLog(@"options:\n%@", optionsDictionary);
    NSLog(@"result at %@%@", optionsDictionary[@"OutputFilePath"],
          optionsDictionary[@"OutputFileName"]);
    if (flagsDictionary[@"CompileANEProgramForDebugging"])
      NSLog(@"other debug information at %@", optionsDictionary[@"OutputFilePath"]);
  }

  return ret;
}
