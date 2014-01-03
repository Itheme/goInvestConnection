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
#import "StompFrame.h"

@protocol ChannelDelegate
@required

- (void) connectionFailed:(NSError *)error;
- (void) connectionLost;
- (void) disconnected; // called in every disconnection case
- (void) gotFrame:(StompFrame *)f;
//- (void) requestCompleted:(NSString *)table Data:(NSString *) data;

@end

@interface GIChannel : NSObject {
    
}

@property (nonatomic, readonly) NSURL *targetURL;
@property (nonatomic, retain) id channelId;
@property (nonatomic, retain) NSString *caption;
@property (nonatomic, readonly, retain) GIChannelStatus *status;
@property (nonatomic, readonly, getter = getClosed) BOOL closed;
@property (nonatomic, readonly, retain) GIReader *reader;
@property (nonatomic, readonly, retain) GIWriter *writer;
@property (nonatomic, readonly, retain) NSString *sessionId;

- (id) initWithURL:(NSURL *) URL Options:(id) optionsProvider Delegate:(id<ChannelDelegate>) master;

- (BOOL) connect:(NSString *)login Password:(NSString *)pwd;
//- (void) ping;
//- (void) send:(NSData *)data;
- (void) disconnect;
- (void) disconnectCSP; // in case of imminent termination
- (void) gotFrame:(StompFrame *)f;
- (BOOL) scheduleSubscriptionRequest:(NSString *) table Param:(NSString *) param Success:(StompSuccessBlock) successBlock Failure:(StompFailureBlock) failureBlock;//callBackMethod:(SEL) callback;
- (void) unsubscribe:(NSString *) table Param:(NSString *) param;
- (void) writerSuccededForReceipt:(NSString *)receipt;
- (void) writerFailedForReceipt:(NSString *)receipt WithError:(NSError *)error;
- (BOOL) performTransaction:(NSString *) trans Ticker:(NSString *) ticker Body:(NSDictionary *) body Success:(StompSuccessBlock) successBlock Failure:(StompFailureBlock) failureBlock;

@end
