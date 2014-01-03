//
//  GIWriter.m
//  GITest
//
//  Created by Mackey on 21.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "GIWriter.h"
#import "GIChannel.h"
#import "StompFrame.h"
#import "AFHTTPRequestOperation.h"


@implementation GIWriter

@synthesize channel, client;

- (NSMutableDictionary *)defaultHeaders:(NSString *) reciept Subscription:(NSString *) subscriptionId {
    if (self.channel.sessionId) {
        if (subscriptionId)
            return [@{@"session" : self.channel.sessionId, @"id" : subscriptionId, @"receipt" : reciept} mutableCopy];
        return [@{@"session" : self.channel.sessionId, @"receipt" : reciept} mutableCopy];
    }
    return [@{@"receipt" : reciept} mutableCopy];
#warning session here
}

- (void) genericSend:(StompCommand) sc Receipt:(NSString *) receipt Destination:(NSString *) destination Method:(NSString *) method Selector:(NSString *) selector Subscription:(NSString *) subscriptionId {
    NSMutableDictionary *headers = [self defaultHeaders:receipt Subscription:subscriptionId];
    [headers addEntriesFromDictionary: @{@"destination" : destination}];
    if (selector)
        [headers addEntriesFromDictionary: @{@"selector" : selector}];
    else
        [headers setValue:nil forKey:@"session"];
    StompFrame *f = [[StompFrame alloc] initWithCommand:sc Headers:headers];
    
    NSURL *url = [NSURL URLWithString:[self.channel.status sessioned:method] relativeToURL:self.channel.targetURL];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:@"POST"];
    //[request setAllHTTPHeaderFields:headers];
    
    [request setValue:@"text/plain" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"" forHTTPHeaderField:@"Accept-Encoding"];
    
    [request setHTTPBody: [f makeBufferWith:nil]];
    
    __block GIChannel *ch = self.channel;
    __block NSString *rec = receipt;
    AFHTTPRequestOperation *ro = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    [ro setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSString *res = [NSString stringWithCString:[operation.responseData bytes] encoding:NSUTF8StringEncoding];
        if (![res isEqualToString:@"OK"])
            NSLog(@"Strange response for %@: %@", rec, res);
        [ch writerSuccededForReceipt:rec];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [ch writerFailedForReceipt:rec WithError:error];
    }];
    [ro start];
}

- (void) sendGetTickers:(NSString *) selector {
    [self genericSend: scREQUEST Receipt:@"tickersReceipt" Destination:@"list" Method:@"send" Selector:selector Subscription:nil];
}

- (void) sendSubscribe:(NSString *) table Param:(NSString *)param Receipt:(NSString *)receipt SubscriptionId:(NSString *)subscription {
    [self genericSend: scSUBSCRIBE Receipt:receipt Destination:table Method:@"send" Selector:param Subscription:subscription];
}

- (void) sendUnsubscribe:(NSString *) table Param:(NSString *) param Receipt:(NSString *)receipt SubscriptionId:(NSString *)subscription {
    [self genericSend: scUNSUBSCRIBE Receipt:receipt Destination:table Method:@"send" Selector:param Subscription:subscription];
}

- (void) sendConnect:(NSString *)login Password:(NSString *)pwd {
    NSMutableDictionary *headers = [self defaultHeaders:@"connectRec" Subscription:nil];
    [headers addEntriesFromDictionary:@{@"login" : login, @"channel" : self.channel.channelId, @"passcode" : pwd}];//, @"destination" : @"connect"}];
    StompFrame *f = [[StompFrame alloc] initWithCommand:scCONNECT Headers:headers];
    
    NSURL *url = [NSURL URLWithString:[self.channel.status sessioned:@"send"] relativeToURL:self.channel.targetURL];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"" forHTTPHeaderField:@"Accept-Encoding"];
            
    [request setValue:@"text/plain" forHTTPHeaderField:@"Content-Type"];
    
    [request setHTTPBody: [f makeBufferWith:nil]];
    
    //__block GIWriter *this = self;
    AFHTTPRequestOperation *ro = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    [ro setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSString *res = [NSString stringWithCString:[operation.responseData bytes] encoding:NSUTF8StringEncoding];
        if ([res isEqualToString:@"OK"]) {
            //[this performSelector:@selector(sendGetTickers) withObject:nil afterDelay:3.0];
        } else
            NSLog(@"ak %@", res);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"al %@", error);
    }];
    [ro start];
//    [self.client enqueueHTTPRequestOperation:ro];

}

- (void) sendDisconnect {
    NSMutableDictionary *headers = [self defaultHeaders:@"discRec" Subscription:nil];
    StompFrame *f = [[StompFrame alloc] initWithCommand:scDISCONNECT Headers:headers];
    
    NSURL *url = [NSURL URLWithString:[self.channel.status sessioned:@"send"] relativeToURL:self.channel.targetURL];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"" forHTTPHeaderField:@"Accept-Encoding"];
    
    [request setValue:@"text/plain" forHTTPHeaderField:@"Content-Type"];
    
    [request setHTTPBody: [f makeBufferWith:nil]];
    
    //__block GIWriter *this = self;
    AFHTTPRequestOperation *ro = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    [ro setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSString *res = [NSString stringWithCString:[operation.responseData bytes] encoding:NSUTF8StringEncoding];
        NSLog(@"disconnect response: %@", res);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"an %@", error);
    }];
    [ro start];

}

- (void) sendTransaction:(NSString *) name Ticker:(NSString *) ticker Param:(NSString *) param Receipt:(NSString *)receipt {
    NSMutableDictionary *headers = [self defaultHeaders:receipt Subscription:nil];
    [headers addEntriesFromDictionary: @{@"destination" : @"orders.add"/*destination*/}];
    //NSMutableDictionary *body = [@{@"TICKER": ticker, @"BUYSELL": @"B", @"PRICE": @[@6000, @0], @"QUANTITY": @2} mutableCopy];
    NSMutableDictionary *body = [@{@"columns": @[@"ACCOUNT", @"TICKER", @"BUYSELL", @"PRICE", @"QUANTITY"], @"data": @[@[@"D000200ZERNB", ticker,  @"B", @[@6000, @0], @2]]} mutableCopy];
    StompFrame *f = [[StompFrame alloc] initWithCommand:scSEND Headers:headers];
    
    NSURL *url = [NSURL URLWithString:[self.channel.status sessioned:@"send"] relativeToURL:self.channel.targetURL];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:@"POST"];
    //[request setAllHTTPHeaderFields:headers];
    
    [request setValue:@"text/plain" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"" forHTTPHeaderField:@"Accept-Encoding"];
    NSError *error = nil;
    [request setHTTPBody: [f makeBufferWith:[NSJSONSerialization dataWithJSONObject:body options:0 error:&error]]];
    
    __block GIChannel *ch = self.channel;
    __block NSString *rec = receipt;
    AFHTTPRequestOperation *ro = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    [ro setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSString *res = [NSString stringWithCString:[operation.responseData bytes] encoding:NSUTF8StringEncoding];
        if (![res isEqualToString:@"OK"])
            NSLog(@"Strange response for %@: %@", rec, res);
        [ch writerSuccededForReceipt:rec];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [ch writerFailedForReceipt:rec WithError:error];
    }];
    [ro start];
}

- (id) initWithChannel:(GIChannel *)ch {
    
    self = [super init];
    if (self) {
        self.channel = ch;

    }
    return self;
}

@end
