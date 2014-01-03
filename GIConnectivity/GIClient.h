//
//  GIClient.h
//  GITest
//
//  Created by Mackey on 23.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GIChannel.h"
#import "GIMinisession.h"


typedef enum GIClientStateEnum {
    csDisconnected = 0,
    csDisconnectedWithProblem = 1,
    csConnecting = 2,
    csConnected = 3,
    csDisconnecting = 4,
    csPseudoConnect = 5 // connection emulation using cache
} GIClientState;

@interface GIClient : NSObject <ChannelDelegate>

@property (nonatomic, readonly) GIClientState state;
@property (nonatomic, readonly, retain) NSString *lastStatusMessage;
@property (nonatomic, readonly, retain) NSDictionary *minisessions;

- (id) initWithUser:(NSString *)alogin Pwd:(NSString *)apwd;
- (void) connect;
- (void) disconnect;
- (void) pseudoConnect;


@end
