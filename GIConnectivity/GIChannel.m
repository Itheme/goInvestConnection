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
@property (nonatomic, retain) NSString *receipt;
@property (nonatomic, retain) NSString *subscriptionId;

- (id) initWithParam:(NSString *) p Success:(StompSuccessBlock) successBlock Failure:(StompFailureBlock) failureBlock receipt:(NSString *)rec;
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
@property (nonatomic, retain) NSMutableDictionary *subscriptions;
@property (nonatomic, retain) id<ChannelDelegate> clie;

@property (nonatomic, retain) NSTimer *pingTimer;
@end

@implementation GIChannel {
    
}

@synthesize status, targetURL, closed, reader, writer, channelId, sessionId, caption, pingTimer;
@synthesize clie, pendingRequests, subscriptions;

- (id) initWithURL:(NSURL *)URL Options:(id)optionsProvider Delegate:(id<ChannelDelegate>) master {
    self = [super init];
    if (self) {
        targetURL = URL;
        self.clie = master;
        self.pendingRequests = [[NSMutableDictionary alloc] init];
        self.subscriptions = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (BOOL) getClosed {
    return self.status == NULL;
}

- (void) startPingThread {
    [self stopPingThread];
    self.pingTimer = [NSTimer scheduledTimerWithTimeInterval:status.delay target:self selector:@selector(ping:) userInfo:nil repeats:YES];
}

- (void) stopPingThread {
    [self.pingTimer invalidate];
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
        [this startPingThread];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        this.status = NULL;
        [this.clie connectionFailed:error];
    }];
    [connectionOp start];
    return YES;
}

- (void) ping:(id) userInfo {
    if (self.closed) return;
#warning we should kill undone requests here probably
    
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
    };
#pragma clang diagnostic pop
    [operation start];
}

/*- (void) send:(NSData *)data {
    if (self.closed) return;
    NSURL *url = [NSURL URLWithString:[status sessioned:@"send"] relativeToURL:targetURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
}*/

- (void) disconnectCSP {
    [self stopPingThread];
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
    NSLog(@"****NEW RECEIPT: %@ FOR %@ ****", receipt, table);
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

- (NSString *) generateSubsReceipt {
    return [NSString stringWithFormat:@"s%d", rqnum++, nil];
}

- (NSString *) addPendingSubsRequest:(FrameRequest *) frq Table:(NSString *) table { // callBackMethod:(SEL) callback {
    NSString *receipt = [NSString stringWithFormat:@"a%d", rqnum++, nil];
    NSMutableDictionary *d = [self.subscriptions valueForKey:table];
    NSLog(@"****NEW RECEIPT: %@ FOR %@ ****", receipt, table);
    if (frq) {
        if (d)
            [d setValue:frq forKey:receipt];
        else
            [self.subscriptions setValue:[@{receipt : frq} mutableCopy] forKey:table];
    }
    return receipt;
}


- (BOOL) scheduleSubscriptionRequest:(NSString *) table Param:(NSString *) param Success:(StompSuccessBlock) successBlock Failure:(StompFailureBlock) failureBlock { // callBackMethod:(SEL) callback {
    if (self.closed) return NO;
    FrameRequest *fr = nil;
    //if (successBlock || failureBlock)
    NSString *rec = [self generateSubsReceipt];
    fr = [[FrameRequest alloc] initWithParam:param Success:successBlock Failure:failureBlock receipt:rec];
    fr.subscriptionId = [self addPendingSubsRequest:fr Table:table];
    [self.writer sendSubscribe:table Param:param Receipt:rec SubscriptionId:fr.subscriptionId];
    return YES;
}

- (void) unsubscribe:(NSString *) table Param:(NSString *) param {
    if (self.closed) return;
    /*NSMutableDictionary *d = [pendingRequests valueForKey:table];
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
    [self.writer sendUnsubscribe:table Param:param Receipt:[self generateReceipt]];*/
    NSMutableDictionary *d = [subscriptions valueForKey:table];
    __block FrameRequest *frqToKill = nil;
    if (d) {
        __block id keyToKill = nil;
        [d enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            frqToKill = obj;
            if ([frqToKill.param isEqualToString:param]) {
                *stop = YES;
                keyToKill = key;
            }
        }];
        if (keyToKill) {
            if ([[d allValues] count] > 1)
                [d setValue:nil forKey:keyToKill];
            else
                [subscriptions setValue:nil forKey:table];
        }
    }
    if (frqToKill)
        [self.writer sendUnsubscribe:table Param:param Receipt:[self generateReceipt] SubscriptionId:frqToKill.subscriptionId];
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
    if ((f.command == scERROR) || (f.command == scGenericError)) {
        //__block NSString *rec = f.receipt;
        __block GIChannel *this = self;
        __block NSString *subsId = nil;
        [self.subscriptions enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            NSMutableDictionary *d = obj;
            [d enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                FrameRequest *frq = obj;
                if ([frq.receipt isEqualToString:f.receipt]) {
                    if (frq.failure)
                        frq.failure(f.message);
                    subsId = key;// is equal to frq.subscriptionId;
                    *stop = YES;
                }
            }];
            if (subsId) {
                *stop = YES;
                [d setValue:nil forKey:subsId];
            }
        }];
        if (subsId)
            return;
    }
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
                [frq touch];
                if ((f.command == scERROR) || (f.command == scGenericError)) {
                    if (frq.failure)
                        frq.failure(f.message);
                } else
                    if (frq.success)
                        frq.success(f);
    #warning other types too!
            } else
                NSLog(@"Skipping message %@ (r2)", f.receipt);
            return;
        }
    d = [self.subscriptions valueForKey:f.destination];
    if (d) {
        if (f.subscription) {
            FrameRequest *frq = [d valueForKey:f.subscription];
            if (f.command == scMESSAGE) {
                [frq touch];
                if (frq.success)
                    frq.success(f);
                return;
            }
        }
    }
    [self.clie gotFrame:f];
}

- (BOOL) performTransaction:(NSString *) trans Param:(NSString *) param Success:(StompSuccessBlock) successBlock Failure:(StompFailureBlock) failureBlock {
    if (self.closed) return NO;
    FrameRequest *fr = nil;
    NSString *rec = [self generateReceipt];
    fr = [[FrameRequest alloc] initWithParam:param Success:successBlock Failure:failureBlock receipt:rec];
    fr.subscriptionId = [self addPendingRequest:fr Table:trans];
    [self.writer sendTransaction:trans Ticker:param Param:param Receipt:rec];
    return YES;

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

@synthesize param, success, failure, subscriptionId, receipt;

- (id) initWithParam:(NSString *) p Success:(StompSuccessBlock) successBlock Failure:(StompFailureBlock) failureBlock receipt:(NSString *)rec {
    self = [super init];
    if (self) {
        self.param = p;
        self.success = successBlock;
        self.failure = failureBlock;
        self.receipt = rec;
        [self touch];
    }
    return self;
}

- (void) touch {
    
}

@end