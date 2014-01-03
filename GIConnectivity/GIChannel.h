//
//  GIChannel.h
//  GITest
//
//  Created by Mackey on 19.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GIChannelStatus.h"
#import "GIReader.h"
#import "GIWriter.h"

@interface GIChannel : NSObject {
    
}

@property (nonatomic, readonly) NSURL *targetURL;
@property (nonatomic, retain) id channelId;
@property (nonatomic, readonly, retain) GIChannelStatus *status;
@property (nonatomic, readonly, getter = getClosed) BOOL closed;
@property (nonatomic, readonly, retain) GIReader *reader;
@property (nonatomic, readonly, retain) GIWriter *writer;

- (id) initWithURL:(NSURL *) URL Options:(id) optionsProvider;

- (void) connect;
- (void) ping;
- (void) send:(NSData *)data;
- (void) close;

@end
