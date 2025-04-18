//
//  LycheeObjC.h
//  Lychee
//
//  Created by Jarrod Norwell on 26/11/2024.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LycheeObjC : NSObject
@property (nonatomic, strong, nullable) void (^bgr555) (void*,
                                                              uint32_t /* dsp width */,
                                                              uint32_t /* dsp height */,
                                                              uint32_t /* img width */,
                                                              uint32_t /* img height */);
@property (nonatomic, strong, nullable) void (^rgb888) (void*,
                                                             uint32_t /* dsp width */,
                                                             uint32_t /* dsp height */,
                                                             uint32_t /* img width */,
                                                             uint32_t /* img height */);

+(LycheeObjC *) sharedInstance NS_SWIFT_NAME(shared());

-(void) insert:(NSURL *)url NS_SWIFT_NAME(insert(from:));

-(void) step;
-(void) stop;

-(void) input:(int)slot button:(uint32_t)button pressed:(BOOL)pressed;

-(NSString *) id:(NSURL *)url NS_SWIFT_NAME(id(from:));
@end

NS_ASSUME_NONNULL_END
