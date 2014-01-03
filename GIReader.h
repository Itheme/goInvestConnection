//
//  GIReader.h
//  GITest
//
//  Created by Mackey on 20.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GIChannel;

@interface GIReader : NSOutputStream <NSStreamDelegate, NSURLConnectionDelegate, NSURLConnectionDataDelegate> { // <NSURLConnectionDownloadDelegate, NSURLConnectionDataDelegate> {
    
}

@property (nonatomic, retain) GIChannel *channel;

- (id) initWithChannel:(GIChannel *)ch;
- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len;
- (BOOL)hasSpaceAvailable;

- (void) close;

@end