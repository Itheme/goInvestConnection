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


@interface FrameRequest : NSObject {
    CFAbsoluteTime accessTime;
}

@property (copy) StompSuccessBlock success;
@property (copy) StompFailureBlock failure;
@property (nonatomic, retain) NSString *param;

- (id) initWithParam:(NSString *) p Success:(StompSuccessBlock) successBlock Failure:(StompFailureBlock) failureBlock;
- (void) touch;

@end


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

- (void) disconnectCSP {
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
    [self.reader close];
    self.reader = nil;
    self.writer = nil;
}

- (void) disconnect {
    [self.writer sendDisconnect];
}

- (void) writerSuccededForReceipt:(NSString *)receipt {
    
}

- (void) writerFailedForReceipt:(NSString *)receipt WithError:(NSError *)error {
    
}

- (NSString *) addPendingRequest:(FrameRequest *) frq Table:(NSString *) table { // callBackMethod:(SEL) callback {
    NSString *receipt = [NSString stringWithFormat:@"a%d", rqnum++, nil];
    NSMutableDictionary *d = [pendingRequests valueForKey:table];
    if (frq) {
        if (d)
            [d setValue:frq forKey:receipt];
        else
            [pendingRequests setValue:[@{receipt : frq} mutableCopy] forKey:table];
    }
    return receipt;
}

- (NSString *) generateReceipt {
    return [NSString stringWithFormat:@"b%d", rqnum++, nil];
}

- (BOOL) scheduleSubscriptionRequest:(NSString *) table Param:(NSString *) param Success:(StompSuccessBlock) successBlock Failure:(StompFailureBlock) failureBlock { // callBackMethod:(SEL) callback {
    if (self.closed) return NO;
    FrameRequest *fr = nil;
    if (successBlock || failureBlock)
        fr = [[FrameRequest alloc] initWithParam:param Success:successBlock Failure:failureBlock];
    [self.writer sendSubscribe:table Param:param Receipt:[self addPendingRequest:fr Table:table]];
    return YES;
}

- (void) unsubscribe:(NSString *) table Param:(NSString *) param {
    if (self.closed) return;
    NSMutableDictionary *d = [pendingRequests valueForKey:table];
    if (d) {
        __block id keyToKill = nil;
        [d enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            FrameRequest *frq = obj;
            if ([frq.param isEqualToString:param]) {
                *stop = YES;
                keyToKill = key;
            }
        }];
        if (keyToKill) {
            if ([[d allValues] count] > 1)
                [d setValue:nil forKey:keyToKill];
            else
                [pendingRequests setValue:nil forKey:table];
        }
    }
    [self.writer sendUnsubscribe:table Param:param Receipt:[self generateReceipt]];
}

- (void) gotFrame:(StompFrame *)f {
    if ((f.command == scInvalidSID) || (f.command == scCLOSED)) {
        [self.clie connectionLost];
        return;
    }
    if (f.command == scCLOSED) {
        [self disconnectCSP];
        return;
    }
    if (f.sessionId) {
        self.sessionId = f.sessionId;
    }
    if (f.destination) {
        NSMutableDictionary *d = [self.pendingRequests valueForKey:f.destination];
        if (d) {
            if (f.receipt) {
                FrameRequest *frq = [d valueForKey:f.receipt];
                if (f.command == scRECEIPT) {
                    NSLog(@"Skipping receipt %@", f.receipt);
                    [frq touch];
                    return;
                }
            }
#warning ticker subscription here too!
            int c = [d count];
            if (c > 1)
                NSLog(@"Skipping message %@ (r1)", f.receipt);
            else
                if (c == 1) {
                    FrameRequest *frq = [[d allValues] lastObject];
                    if (frq.success)
                        frq.success(f);
#warning other types too!
                } else
                    NSLog(@"Skipping message %@ (r2)", f.receipt);
            return;
        }
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


@implementation FrameRequest

@synthesize param, success, failure;

- (id) initWithParam:(NSString *) p Success:(StompSuccessBlock) successBlock Failure:(StompFailureBlock) failureBlock {
    self = [super init];
    if (self) {
        self.param = p;
        self.success = successBlock;
        self.failure = failureBlock;
        [self touch];
    }
    return self;
}

- (void) touch {
    
}

@end