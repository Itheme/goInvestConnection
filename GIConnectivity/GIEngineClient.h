//
//  GIEngineClient.h
//  GITest
//
//  Created by Mackey on 27.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "GIClient.h"
#import "GIMinisession.h"

@protocol OrderQueueDelegate


@end

@interface GIEngineClient : GIClient


@property (nonatomic, retain, setter = setTarget:) GIMinisession *target;
@property (nonatomic) id<OrderQueueDelegate> targetSubscriber;

+ (GIEngineClient *) sharedClient;
+ (GIEngineClient *) setupSharedClient;

- (void) setupOQDelegatesFor:(UITableView *)table;

@end
