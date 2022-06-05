#import "SimplebluePlugin.h"
#if __has_include(<simpleblue/simpleblue-Swift.h>)
#import <simpleblue/simpleblue-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "simpleblue-Swift.h"
#endif

@implementation SimplebluePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftSimplebluePlugin registerWithRegistrar:registrar];
}
@end
