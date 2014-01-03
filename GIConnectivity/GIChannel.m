//
//  GIChannel.m
//  GITest
//
//  Created by Mackey on 19.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "GIChannel.h"

#import "AFURLConnectionOperation.h"
#import "AFJSONRequestOperation.h"

@interface GIChannel () {
    int rqnum;
}

@property (nonatomic, retain, setter = setStatus:) GIChannelStatus *status;
@property (nonatomic, retain) GIReader *reader;
@property (nonatomic, retain) GIWriter *writer;
@property (nonatomic, retain) NSString *sessionId;
@property (nonatomic, retain) NSMutableDictionary *pendingRequests;
@property (nonatomic, retain) id<ChannelDelegate> clie;

@end

@implementation GIChannel {
    
}

@synthesize status, targetURL, closed, reader, writer, channelId, sessionId, caption;
@synthesize clie, pendingRequests;

- (id) initWithURL:(NSURL *)URL Options:(id)optionsProvider Delegate:(id<ChannelDelegate>) master {
    self = [super init];
    if (self) {
        targetURL = URL;
        self.clie = master;
        self.pendingRequests = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (BOOL) getClosed {
    return self.status == NULL;
}

- (BOOL) connect:(NSString *)login Password:(NSString *)pwd {
    if (!self.closed) return NO;
    self.status = nil;
    NSURL *url = [NSURL URLWithString:@"connect" relativeToURL:targetURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSLog(@"Connecting...");
    __block GIChannel *this = self;
    __block NSString *lgn = login;
    __block NSString *pw  = pwd;
    AFHTTPRequestOperation *connectionOp = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    [connectionOp setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        this.status = [[GIChannelStatus alloc] initWithResponse:operation.response];
        NSLog(@"Starting reader...");
        this.reader = [[GIReader alloc] initWithChannel:this];
        NSLog(@"Starting writer...");
        this.writer = [[GIWriter alloc] initWithChannel:this];
        [this.writer sendConnect:lgn Password:pw];
        [self performSelector:@selector(ping) withObject:nil afterDelay:this.status.delay / 1000.0];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        this.status = NULL;
        [this.clie connectionFailed:error];
    }];
    [connectionOp start];
    return YES;
}

- (void) doPing {
    [self performSelector:@selector(ping) withObject:nil afterDelay:self.status.delay / 1000.0];
}

- (void) ping {
    if (self.closed) return;
#warning maybe here should be some kind of a block
    NSURL *url = [NSURL URLWithString:[status sessioned:@"ping"] relativeToURL:targetURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    __block AFURLConnectionOperation *operation = [[AFURLConnectionOperation alloc] initWithRequest:request];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    __block GIChannel *this = self;
    operation.completionBlock = ^ {
        if ([operation isCancelled]) {
            return;
        }
        if (operation.error) {
            NSLog(@"ping fail: %@", operation.error.description);
            return;
        }
        [this.status touch];
        NSLog(@"pinged");
        [this performSelectorOnMainThread:@selector(doPing) withObject:nil waitUntilDone:NO];
    };
#pragma clang diagnostic pop
    [operation start];
}

- (void) send:(NSData *)data {
    /*if (self.closed) return;
    NSURL *url = [NSURL URLWithString:[status sessioned:@"send"] relativeToURL:targetURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];*/
    
}

- (void) close {
    NSURL *url = [NSURL URLWithString:[status sessioned:@"disconnect"] relativeToURL:targetURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    __block AFURLConnectionOperation *operation = [[AFURLConnectionOperation alloc] initWithRequest:request];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    __block GIChannel *this = self;
    operation.completionBlock = ^ {
        if ([operation isCancelled]) {
            return;
        }
        if (operation.error)
            return;
        this.status = NULL;
        [this.reader close];

    };
#pragma clang diagnostic pop
    [operation start];
}

- (void) writerSuccededForReceipt:(NSString *)receipt {
    
}

- (void) writerFailedForReceipt:(NSString *)receipt WithError:(NSError *)error {
    
}

- (NSString *) addPendingRequest:(NSString *) table Param:(NSString *) param { // callBackMethod:(SEL) callback {
    NSString *receipt = [NSString stringWithFormat:@"a%d", rqnum++, nil];
    NSMutableDictionary *d = [pendingRequests valueForKey:table];
    if (d)
        [d setValue:(param?param:@" ") forKey:receipt];
    else
        [pendingRequests setValue:[@{receipt : (param?param:@" ")} mutableCopy] forKey:table];
    return receipt;
}

- (BOOL) scheduleSubscriptionRequest:(NSString *) table Param:(NSString *) param { // callBackMethod:(SEL) callback {
    if (self.closed) return NO;
    [self.writer sendSubscribe:table Param:param Receipt:[self addPendingRequest:table Param:param]];
    return YES;
}

- (void) gotFrame:(StompFrame *)f {
    if (f.sessionId) {
        self.sessionId = f.sessionId;
    }
    if (f.command == scRECEIPT) {
        NSLog(@"Skipping receipt %@", f.receipt);
        return;
    }
    if (f.destination) {
        if (f.receipt) {
            NSMutableDictionary *d = [self.pendingRequests valueForKey:f.destination];
            NSString *param = [d valueForKey:f.receipt];
            if (d.count == 1) {
                [self.pendingRequests removeObjectForKey:f.destination];
            } else {
                [d removeObjectForKey:f.receipt];
            }
            [self.clie requestCompleted:f.destination Param:param Data:f.jsonString];
        } else
            NSLog(@"lost receipt for %@", f.destination);
    }
    [self.clie gotFrame:f];
}

- (void) setStatus:(GIChannelStatus *)astatus {
    status = astatus;
    if (!astatus) {
        self.sessionId = nil;
        [self.pendingRequests removeAllObjects];
    }
}
@end

