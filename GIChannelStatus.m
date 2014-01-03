//
//  GIChannelStatus.m
//  GITest
//
//  Created by Mackey on 19.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "GIChannelStatus.h"

@implementation GIChannelStatus {
    id session;
    int delay;
    CFAbsoluteTime timeStamp;
}

- (id) initWithResponse:(NSHTTPURLResponse *)response {
    NSDictionary *d = [response allHeaderFields];
    id hSession = [d valueForKey:@"X-CspHub-Session"];
    if (hSession) {
        self = [super init];
        if (self) {
            NSNumber *ping = [d valueForKey:@"X-CspHub-Ping"];
            if (ping) {
                delay = ping.intValue * 1000;
            } else {
                delay = 1000;
            }
            timeStamp = CFAbsoluteTimeGetCurrent();
            session = hSession;
            NSLog(@"Session: %@", session);
            return self;
        }
    }
    return nil;
}

@end
