//
//  GIEngineClient.h
//  GITest
//
//  Created by Mackey on 27.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "GIClient.h"


@interface GIEngineClient : GIClient

+ (GIEngineClient *) sharedClient;
+ (GIEngineClient *) setupSharedClient;

@end
