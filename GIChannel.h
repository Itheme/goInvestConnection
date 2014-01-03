//
//  GIChannel.h
//  GITest
//
//  Created by Mackey on 19.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GIChannelStatus.h"

@interface GIChannel : NSObject {
    
}

@property (nonatomic, readonly) NSURL *targetURL;
@property (nonatomic, readonly) GIChannelStatus *status;
@property (nonatomic, readonly, getter = getClosed) BOOL closed;


- (id) initWithURL:(NSURL *) URL Options:(id) optionsProvider;

- (void) connect;
- (void) ping;
- (void) disconnect;

@end
