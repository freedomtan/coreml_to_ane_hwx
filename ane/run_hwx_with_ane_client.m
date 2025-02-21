#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#import <IOSurface/IOSurfaceObjc.h>

@interface _ANEClient : NSObject
+ (id)sharedConnection;

- (bool)loadModel:(id)model options:(id)options qos:(unsigned int)qos error:(id *)error;
- (bool)loadModelNewInstance:(id)instance
                     options:(id)options
             modelInstParams:(id)params
                         qos:(unsigned int)qos
                       error:(id *)error;
- (_Bool)evaluateWithModel:(id)model
                   options:(id)options
                   request:(id)request
                       qos:(unsigned int)qos
                     error:(id *)error;
- (id)connections;
- (bool)isRootDaemon;
- (id)priorityQ;
@end

@interface _ANEModel : NSObject
@property(retain, nonatomic) NSDictionary *modelAttributes;
@property(copy, nonatomic) NSString *cacheURLIdentifier;
@property(readonly, nonatomic) NSUUID *UUID;

+ (id)modelAtURL:(id)url key:(id)key;
+ (id)modelWithCacheURLIdentifier:(id)id;
@end

@interface _ANEWeight : NSObject <NSCopying, NSSecureCoding>
+ (id)weightWithSymbolAndURL:(id)url weightURL:(id)url;
@end

@interface _ANEProcedureData : NSObject <NSCopying, NSSecureCoding>
+ (id)procedureDataWithSymbol:(id)symbol weightArray:(id)array;
@end

@interface _ANEModelInstanceParameters : NSObject <NSCopying, NSSecureCoding>
+ (id)withProcedureData:(id)data procedureArray:(id)array;
@end

@interface _ANEIOSurfaceObject : NSObject
+ (id)objectWithIOSurface:(IOSurface *)iosurface;
@end

@interface _ANERequest : NSObject
+ (id)requestWithInputs:(id)inputs
           inputIndices:(id)indices
                outputs:(id)outputs
          outputIndices:(id)indices
              perfStats:(id)stats
         procedureIndex:(id)index;
@end

@interface _ANEErrors : NSObject
@end

IOSurface *create_iosurface_from_dict(NSDictionary *dict, NSString *name) {
  id ios = [IOSurface alloc];

  id type = dict[@"Type"];
  OSType pixelFormat = 0;
  NSLog(@"%@", type);
  if ([type isEqualToString:@"Float16"]) {
    pixelFormat = kCVPixelFormatType_OneComponent16Half;
  } else if (([type isEqualToString:@"Int8"]) || ([type isEqualToString:@"UInt8"])) {
    pixelFormat = kCVPixelFormatType_OneComponent8;
  } else if ([type isEqualToString:@"Int32"]) {
    pixelFormat = kCVPixelFormatType_32ARGB;
  }

  if ([dict objectForKey:@"Batches"]) {
    id batches_stride = dict[@"BatchStride"];
    id input_dict = nil;

    // assuming that tensor size = num_batch * batch_stride allocate tensor of tensor size instead
    // of trying to to have "correct" height and width values
    id tensor_size =
        [NSNumber numberWithInt:[dict[@"Batches"] intValue] * [batches_stride intValue]];
    input_dict = @{
      IOSurfacePropertyKeyWidth : tensor_size,
      IOSurfacePropertyKeyHeight : @1,
      IOSurfacePropertyKeyName : name,
      IOSurfacePropertyKeyPixelFormat : [NSNumber numberWithInt:pixelFormat],
    };

    // create IOSurface with public class method
    [ios initWithProperties:input_dict];
    NSLog(@"ios %@", ios);
  } else {
    id height = dict[@"Height"];
    id width = dict[@"Width"];
    id plane_descriptor = dict[@"PlaneDescriptor"];
    id input_dict = nil;

    // for no @"Batches" cases, if there is no @"PlaneDescriptor", there could be single element
    // cases
    if (plane_descriptor == nil) {
      int bytes_per_element = 0;
      id type = dict[@"Type"];
      if ([type isEqualToString:@"Int32"]) bytes_per_element = 4;
      input_dict = @{
        IOSurfacePropertyKeyWidth : @1,
        IOSurfacePropertyKeyHeight : @1,
        IOSurfacePropertyKeyBytesPerElement : [NSNumber numberWithInt:bytes_per_element],
        IOSurfacePropertyKeyPixelFormat : [NSNumber numberWithInt:pixelFormat],
      };
    } else {
      NSMutableArray *infoArray = [[NSMutableArray alloc] init];
      NSArray *keyArray = @[
        (id)kIOSurfacePlaneWidth, (id)kIOSurfacePlaneHeight, (id)kIOSurfacePlaneBytesPerRow,
        (id)kIOSurfaceAllocSize, (id)kIOSurfacePlaneOffset
      ];
      NSLog(@"keyArray %@", keyArray);
      id plane_count = [NSNumber numberWithInt:[plane_descriptor count]];

      for (int i = 0; i < [plane_count intValue]; i++) {
        id row_stride = plane_descriptor[i][@"RowStride"];
        id plane_stride = [NSNumber numberWithInt:[height intValue] * [row_stride intValue]];
        NSArray *valueArray = @[
          width, height, row_stride, plane_stride,
          [NSNumber numberWithInt:[plane_stride intValue] * i]
        ];
        id foo = [NSDictionary dictionaryWithObjects:valueArray forKeys:keyArray];
        [infoArray addObject:foo];
      }
      NSLog(@"info %@", infoArray);
      input_dict = @{
        IOSurfacePropertyKeyWidth : width,
        IOSurfacePropertyKeyHeight : height,
        IOSurfacePropertyKeyName : name,
        IOSurfacePropertyKeyPixelFormat : dict[@"4CCFormat"],
        IOSurfacePropertyKeyPlaneInfo : infoArray
      };
    }
    [ios initWithProperties:input_dict];
    NSLog(@"ios %@", ios);
  }

  return ios;
}

void test_ane_client(char *model_path) {
  id ac = [_ANEClient sharedConnection];
  NSLog(@"client shared connection %@", ac);
  NSLog(@"is RootDaemon %d", [ac isRootDaemon]);
  NSLog(@"is connections %@", [ac connections]);
  NSLog(@"is q %@", [ac priorityQ]);

  NSString *model = [NSString stringWithUTF8String:model_path];
  NSString *key = @"ANE_model";

  id am = [_ANEModel modelAtURL:[NSURL fileURLWithPath:model] key:key];
  NSLog(@"model: %@", am);

  NSDictionary *optionDict = @{
    @"kANEFModelIdentityStrKey" : @"test_inference_by_freedom",
    @"kANEFModelType" : @"kANEFModelPreCompiled",
  };

  id e = [[_ANEErrors alloc] init];
  [ac loadModel:am options:optionDict qos:21 error:&e];
  NSLog(@"model: %@", am);
  NSLog(@"loading error: %@", e);
  NSLog(@"is connections %@", [ac connections]);

  id attr = [am modelAttributes];

  id procedures = attr[@"ANEFModelDescription"][@"ANEFModelProcedures"];
  // NSLog(@"name %@", procedures[0]);
  for (int proc_id = 0; proc_id < [procedures count]; proc_id++) {
    int index = [procedures[proc_id][@"ANEFModelProcedureID"] intValue];
    NSLog(@"%@", attr[@"NetworkStatusList"][index][@"Name"]);

    long input_count = [procedures[proc_id][@"ANEFModelInputSymbolIndexArray"] count];
    //    objectAtIndex:0][@"ANEFModelInputSymbolIndexArray"] count];

    id inputSymbols = attr[@"ANEFModelDescription"][@"kANEFModelInputSymbolsArrayKey"];
    id outputSymbols = attr[@"ANEFModelDescription"][@"kANEFModelOutputSymbolsArrayKey"];

    long input_param_count = [attr[@"NetworkStatusList"][proc_id][@"LiveInputParamList"] count];
    // NSLog(@"num param: %ld", input_param_count);
    long input_list_count = [attr[@"NetworkStatusList"][proc_id][@"LiveInputList"] count];
    // NSLog(@"num input: %ld", input_list_count);
    long state_list_count = [attr[@"NetworkStatusList"][proc_id][@"LiveStateList"] count];
    // NSLog(@"num states: %ld", state_list_count);
    long output_list_count = [attr[@"NetworkStatusList"][proc_id][@"LiveOutputList"] count];
    // NSLog(@"num output: %ld", output_list_count);

    NSMutableArray *input_surface_array = [[NSMutableArray alloc] init];
    NSMutableArray *output_surface_array = [[NSMutableArray alloc] init];
    NSMutableArray *input_index_array = [[NSMutableArray alloc] init];
    NSMutableArray *output_index_array = [[NSMutableArray alloc] init];

    for (int i = 0; i < input_count; i++) {
      id index = procedures[proc_id][@"ANEFModelInputSymbolIndexArray"][i];
      NSLog(@"%@, %@", index, inputSymbols[i]);
      for (int j = 0; j < input_param_count; j++) {
        if ([attr[@"NetworkStatusList"][proc_id][@"LiveInputParamList"][j][@"Name"]
                isEqualToString:inputSymbols[i]]) {
          NSLog(@"\n%@", attr[@"NetworkStatusList"][proc_id][@"LiveInputParamList"][j]);
          [input_surface_array
              addObject:[_ANEIOSurfaceObject
                            objectWithIOSurface:create_iosurface_from_dict(
                                                    attr[@"NetworkStatusList"][proc_id]
                                                        [@"LiveInputParamList"][j],
                                                    inputSymbols[i])]];
          [input_index_array addObject:index];
        }
      }
      for (int j = 0; j < input_list_count; j++) {
        if ([attr[@"NetworkStatusList"][proc_id][@"LiveInputList"][j][@"Name"]
                isEqualToString:inputSymbols[i]]) {
          NSLog(@"\n%@", attr[@"NetworkStatusList"][proc_id][@"LiveInputList"][j]);
          [input_surface_array
              addObject:[_ANEIOSurfaceObject
                            objectWithIOSurface:create_iosurface_from_dict(
                                                    attr[@"NetworkStatusList"][proc_id]
                                                        [@"LiveInputList"][j],
                                                    inputSymbols[i])]];
          [input_index_array addObject:index];
        }
      }
      for (int j = 0; j < state_list_count; j++) {
        if ([attr[@"NetworkStatusList"][proc_id][@"LiveStateList"][j][@"Name"]
                isEqualToString:inputSymbols[i]]) {
          NSLog(@"\n%@", attr[@"NetworkStatusList"][proc_id][@"LiveStateList"][j]);
          [input_surface_array
              addObject:[_ANEIOSurfaceObject
                            objectWithIOSurface:create_iosurface_from_dict(
                                                    attr[@"NetworkStatusList"][proc_id]
                                                        [@"LiveStateList"][j],
                                                    inputSymbols[i])]];
          [input_index_array addObject:index];
        }
      }
    }
    long output_count = [[attr[@"ANEFModelDescription"][@"ANEFModelProcedures"]
        objectAtIndex:index][@"ANEFModelOutputSymbolIndexArray"] count];
    for (int i = 0; i < output_count; i++) {
      id index = [[attr[@"ANEFModelDescription"][@"ANEFModelProcedures"]
          objectAtIndex:proc_id][@"ANEFModelOutputSymbolIndexArray"] objectAtIndex:i];
      NSLog(@"%@, %@", index, outputSymbols[i]);
      for (int j = 0; j < output_list_count; j++) {
        if ([attr[@"NetworkStatusList"][proc_id][@"LiveOutputList"][j][@"Name"]
                isEqualToString:outputSymbols[i]]) {
          NSLog(@"\n%@", attr[@"NetworkStatusList"][proc_id][@"LiveOutputList"][j]);
          [output_surface_array
              addObject:[_ANEIOSurfaceObject
                            objectWithIOSurface:create_iosurface_from_dict(
                                                    attr[@"NetworkStatusList"][proc_id]
                                                        [@"LiveOutputList"][j],
                                                    outputSymbols[i])]];
          [output_index_array addObject:index];
        }
      }
    }

    id request = [_ANERequest requestWithInputs:input_surface_array
                                   inputIndices:input_index_array
                                        outputs:output_surface_array
                                  outputIndices:output_index_array
                                      perfStats:[[NSArray alloc] init]
                                 procedureIndex:[NSNumber numberWithInt:proc_id]];

    optionDict = @{
      @"kANEFDisableIOFencesUseSharedEventsKey" : @0,
    };
    NSLog(@"request: %@", request);
    for (int i = 0; i < 5; i++)
      [ac evaluateWithModel:am options:optionDict request:request qos:0x21 error:&e];
    NSLog(@"error: %@", e);
  }
}

int main(int argc, char *argv[]) { test_ane_client(argv[1]); }
