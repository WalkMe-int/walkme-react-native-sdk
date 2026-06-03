#if __has_include(<React/RCTBridgeModule.h>)
#import <React/RCTBridgeModule.h>
#else
#import "RCTBridgeModule.h"
#endif

@interface RCT_EXTERN_MODULE(RNWalkMeSdk, NSObject)

RCT_EXTERN_METHOD(start:(NSDictionary *)options)
RCT_EXTERN_METHOD(stop)
RCT_EXTERN_METHOD(startItemByID:(nonnull NSNumber *)itemId deepLink:(NSString *)deepLink)
RCT_EXTERN_METHOD(dismissItem)
RCT_EXTERN_METHOD(setUserId:(NSString *)userId)
RCT_EXTERN_METHOD(setVariable:(NSString *)key value:(NSString *)value)
RCT_EXTERN_METHOD(setEventUserVars:(NSDictionary *)vars)
RCT_EXTERN_METHOD(setLanguage:(NSString *)language)
RCT_EXTERN_METHOD(sendEvent:(NSString *)name attributes:(NSDictionary *)attributes)

+ (BOOL)requiresMainQueueSetup { return NO; }

@end
