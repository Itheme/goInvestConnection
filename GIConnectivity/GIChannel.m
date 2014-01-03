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
    
}

@property (nonatomic, retain) GIChannelStatus *status;
@property (nonatomic, retain) GIReader *reader;
@property (nonatomic, retain) GIWriter *writer;
@property (nonatomic, assign) id<ChannelDelegate> delegate;

@end

@implementation GIChannel {
    
}

@synthesize status, targetURL, closed, reader, writer, channelId, caption;
@synthesize delegate;

- (id) initWithURL:(NSURL *)URL Options:(id)optionsProvider Delegate:(id<ChannelDelegate>) master {
    self = [super init];
    if (self) {
        targetURL = URL;
        self.delegate = master;
    }
    return self;
}

- (BOOL) getClosed {
    return self.status == NULL;
}

- (BOOL) connect {
    if (!self.closed) return NO;
    status = nil;
    NSURL *url = [NSURL URLWithString:@"connect" relativeToURL:targetURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSLog(@"Connecting...");
    __block GIChannel *this = self;
    AFHTTPRequestOperation *connectionOp = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    [connectionOp setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        this.status = [[GIChannelStatus alloc] initWithResponse:operation.response];
        NSLog(@"Starting reader...");
        this.reader = [[GIReader alloc] initWithChannel:this];
        NSLog(@"Starting writer...");
        this.writer = [[GIWriter alloc] initWithChannel:this];
        [self performSelector:@selector(ping) withObject:nil afterDelay:this.status.delay / 1000.0];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        this.status = NULL;
        [this.delegate connectionFailed:error];
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
    if (self.closed) return;
    NSURL *url = [NSURL URLWithString:[status sessioned:@"send"] relativeToURL:targetURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
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

- (void) gotFrame:(StompFrame *)f {
    switch (f.command) {
        case scCONNECTED:
            [writer sendGetTickers];
            break;
            
        default:
            break;
    }
}

@end

