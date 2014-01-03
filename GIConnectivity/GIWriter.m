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

- (NSMutableDictionary *)defaultHeaders:(NSString *) reciept {
    if (self.channel.sessionId)
        return [@{@"session" : self.channel.sessionId, @"id" : self.channel.channelId, @"receipt" : reciept} mutableCopy];
    return [@{@"id" : self.channel.channelId, @"receipt" : reciept} mutableCopy];
#warning session here
}

- (void) genericSend:(StompCommand) sc Receipt:(NSString *) receipt Destination:(NSString *) destination Method:(NSString *) method Selector:(NSString *) selector {
    NSMutableDictionary *headers = [self defaultHeaders:receipt];
    [headers addEntriesFromDictionary: @{@"destination" : destination}];
    if (selector)
        [headers addEntriesFromDictionary: @{@"selector" : selector}];
    StompFrame *f = [[StompFrame alloc] initWithCommand:sc Headers:headers];
    
    NSURL *url = [NSURL URLWithString:[self.channel.status sessioned:method] relativeToURL:self.channel.targetURL];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:@"POST"];
    //[request setAllHTTPHeaderFields:headers];
    
    [request setValue:@"text/plain" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"" forHTTPHeaderField:@"Accept-Encoding"];
    
    [request setHTTPBody: [f makeBuffer]];
    
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
    [self genericSend: scREQUEST Receipt:@"tickersReceipt" Destination:@"list" Method:@"send" Selector:selector];
}

- (void) sendSubscribe:(NSString *) table Param:(NSString *)param Receipt:(NSString *)receipt {
    [self genericSend: scSUBSCRIBE Receipt:receipt Destination:table Method:@"send" Selector:param];
}

- (void) sendUnsubscribe:(NSString *) table Param:(NSString *) param Receipt:(NSString *)receipt {
    [self genericSend: scUNSUBSCRIBE Receipt:receipt Destination:table Method:@"send" Selector:param];
}


- (void) sendConnect:(NSString *)login Password:(NSString *)pwd {
    NSMutableDictionary *headers = [self defaultHeaders:@"connectRec"];
    [headers addEntriesFromDictionary:@{@"login" : login, @"channel" : self.channel.channelId, @"passcode" : pwd}];//, @"destination" : @"connect"}];
    StompFrame *f = [[StompFrame alloc] initWithCommand:scCONNECT Headers:headers];
    
    NSURL *url = [NSURL URLWithString:[self.channel.status sessioned:@"send"] relativeToURL:self.channel.targetURL];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"" forHTTPHeaderField:@"Accept-Encoding"];
            
    [request setValue:@"text/plain" forHTTPHeaderField:@"Content-Type"];
    
    [request setHTTPBody: [f makeBuffer]];
    
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
    NSMutableDictionary *headers = [self defaultHeaders:@"discRec"];
    StompFrame *f = [[StompFrame alloc] initWithCommand:scDISCONNECT Headers:headers];
    
    NSURL *url = [NSURL URLWithString:[self.channel.status sessioned:@"send"] relativeToURL:self.channel.targetURL];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"" forHTTPHeaderField:@"Accept-Encoding"];
    
    [request setValue:@"text/plain" forHTTPHeaderField:@"Content-Type"];
    
    [request setHTTPBody: [f makeBuffer]];
    
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

- (id) initWithChannel:(GIChannel *)ch {
    
    self = [super init];
    if (self) {
        self.channel = ch;

    }
    return self;
}

@end
