//
//  GIChannelStatus.h
//  GITest
//
//  Created by Mackey on 19.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GIChannelStatus : NSObject

@property (nonatomic) id session;
@property (nonatomic) int delay;

- (id) initWithResponse:(NSHTTPURLResponse *)response;

- (void) touch;

- (NSString *)sessioned:(NSString*)resource;

@end
