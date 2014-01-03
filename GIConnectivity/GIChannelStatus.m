//
//  GIChannelStatus.m
//  GITest
//
//  Created by Mackey on 19.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "GIChannelStatus.h"

@implementation GIChannelStatus {
    CFAbsoluteTime timeStamp;
}

@synthesize session;
@synthesize delay;

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
            self.session = hSession;
            NSLog(@"Session: %@", self.session);
            return self;
        }
    }
    return nil;
}

- (void) touch {
    timeStamp = CFAbsoluteTimeGetCurrent();
}

- (NSString *)sessioned:(NSString*)resource {
    return [NSString stringWithFormat:@"%@/%@", self.session, resource, nil];
}

@end
