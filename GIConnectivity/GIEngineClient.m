//
//  GIEngineClient.m
//  GITest
//
//  Created by Mackey on 27.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "GIEngineClient.h"
#import "GIAppDelegate.h"

@implementation GIEngineClient

+ (GIEngineClient *) sharedClient {
    GIAppDelegate *d = [UIApplication sharedApplication].delegate;
    return d.client;
}

+ (GIEngineClient *) setupSharedClient {
    GIAppDelegate *d = [UIApplication sharedApplication].delegate;
    d.client = [[GIEngineClient alloc] initWithUser:@"MXZERNO.D001701B" Pwd:@""];
    return d.client;
}

@end
