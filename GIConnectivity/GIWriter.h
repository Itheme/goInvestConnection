//
//  GIWriter.h
//  GITest
//
//  Created by Mackey on 21.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFHTTPClient.h"
#import "StompFrame.h"



@class GIChannel;

@interface GIWriter : NSObject

@property (nonatomic, retain) GIChannel *channel;
@property (nonatomic, retain) AFHTTPClient *client;

- (id) initWithChannel:(GIChannel *)ch;
- (void) sendConnect:(NSString *)login Password:(NSString *)pwd;
- (void) sendDisconnect;
- (void) sendGetTickers:(NSString *) selector;
- (void) sendSubscribe:(NSString *) table Param:(NSString *)param Receipt:(NSString *)receipt;
- (void) sendUnsubscribe:(NSString *) table Param:(NSString *) param Receipt:(NSString *)receipt;

@end
