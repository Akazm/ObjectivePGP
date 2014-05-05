//
//  PGPPacket.h
//  OpenPGPKeyring
//
//  Created by Marcin Krzyzanowski on 04/05/14.
//  Copyright (c) 2014 Marcin Krzyżanowski. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PGPTypes.h"

@protocol PGPPacket <NSObject>
@required
@property (assign, readonly, nonatomic) PGPPacketTag tag;
- (void) parsePacketBody:(NSData *)packetBody;
@end

@interface PGPPacket : NSObject

- (NSUInteger) parsePacketHeader:(NSData *)headerData bodyLength:(NSUInteger *)length packetTag:(PGPPacketTag *)tag;

@end
