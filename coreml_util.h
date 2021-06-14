#ifndef __COREML_UTIL__
#define __COREML_UTIL__

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
extern int ANECCompile(NSDictionary* param_1, NSDictionary* param_2,
                void (^param_3)(ANECStatus status, NSDictionary* statusDictionary));

extern int mlmodelc_to_espresso_ir(NSString *espressonet);
extern int espresso_ir_hwx(NSString *baseModelName, bool debug);

#endif // __COREML_UTIL__
