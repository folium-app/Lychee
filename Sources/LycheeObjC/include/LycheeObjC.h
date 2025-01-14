//
//  LycheeObjC.h
//  Lychee
//
//  Created by Jarrod Norwell on 26/11/2024.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LycheeObjC : NSObject
@property (nonatomic, strong, nullable) void (^bufferBGR555) (uint16_t*, uint32_t, uint32_t);
@property (nonatomic, strong, nullable) void (^bufferRGB24) (uint32_t*, uint32_t, uint32_t);

+(LycheeObjC *) sharedInstance NS_SWIFT_NAME(shared());

-(void) insertCartridge:(NSURL *)url;

-(void) step;
-(void) stop;

-(void) input:(int)slot button:(uint32_t)button pressed:(BOOL)pressed;

-(NSString *) gameID:(NSURL *)url;
@end

NS_ASSUME_NONNULL_END
