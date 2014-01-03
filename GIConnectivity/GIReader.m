//
//  GIReader.m
//  GITest
//
//  Created by Mackey on 20.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "GIReader.h"
#import "GIChannel.h"
#import "StompFrame.h"
#import "AFURLConnectionOperation.h"

@interface GIReader () {
    char *accData;
    int capacity, used, seqnum;
    BOOL closed;
}

//@property (atomic, retain) NSMutableData *accumulator;
@property (nonatomic, retain) NSMutableURLRequest *theRequest;
@property (nonatomic, retain) AFURLConnectionOperation *readerOperation;

@end

@implementation GIReader

@synthesize channel;
@synthesize theRequest, readerOperation;
//@synthesize accumulator;

- (void) loadistr:(id) iistr {
    NSInputStream *istr = iistr;
    while (true) {
        while (![istr hasBytesAvailable]) [NSThread sleepForTimeInterval:0.1];
        uint8_t x[256];
        int l = [istr read:x maxLength:256];
        x[l] = 0;
        NSLog(@"Wow! %s", x);
    }
}

- (void) cfStreamRun:(NSURL *)url {
    CFURLRef cfURL = (__bridge CFURLRef)url;
    CFHTTPMessageRef httpMessageRef = CFHTTPMessageCreateRequest(NULL, CFSTR("GET"), cfURL, kCFHTTPVersion1_0);
    CFReadStreamRef stream = CFReadStreamCreateForHTTPRequest(CFAllocatorGetDefault(), httpMessageRef);
    if (!CFReadStreamOpen(stream)) {
        CFStreamError myErr = CFReadStreamGetError(stream);
        if (myErr.domain == kCFStreamErrorDomainPOSIX) {
            // Interpret myErr.error as a UNIX errno.
        } else if (myErr.domain == kCFStreamErrorDomainMacOSStatus) {
            // Interpret myErr.error as a MacOS error code.
            OSStatus macError = (OSStatus)myErr.error;
            // Check other error domains.
        }
    } else {
        CFIndex numBytesRead;
        do {
            UInt8 buf[10240]; // define myReadBufferSize as desired
            numBytesRead = CFReadStreamRead(stream, buf, sizeof(buf));
            if( numBytesRead > 0 ) {
                //handleBytes(buf, numBytesRead);
                [self write:buf maxLength:numBytesRead];
            } else if( numBytesRead < 0 ) {
                CFStreamError error = CFReadStreamGetError(stream);
                //reportError(error);
            }
        } while( numBytesRead > 0 );
        [self performSelectorOnMainThread:@selector(doHang) withObject:nil waitUntilDone:NO];        
    }
}

- (void) hang {
    closed = NO;
    NSURL *url = [NSURL URLWithString:[channel.status sessioned:@"receive"] relativeToURL:self.channel.targetURL];
    /*theRequest = [NSMutableURLRequest requestWithURL:url
                                         cachePolicy:NSURLRequestReloadIgnoringCacheData
                                     timeoutInterval:30.0];
    [theRequest setHTTPMethod:@"GET"];
    [theRequest setValue:@"" forHTTPHeaderField:@"Accept-Encoding"];
    [theRequest setValue:[NSString stringWithFormat:@"%d", seqnum, nil] forHTTPHeaderField:@"X-CspHub-Seqnum"];
    [theRequest setHTTPShouldUsePipelining:YES];*/
    [self performSelectorInBackground:@selector(cfStreamRun:) withObject:url];
    return;
    self.readerOperation = [[AFURLConnectionOperation alloc] initWithRequest:theRequest];
    self.readerOperation.outputStream.delegate = self;
    /*[readerOperation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
        NSLog(@"Wha???? %lld", totalBytesRead);
    }];*/
    readerOperation.outputStream = self;
    [readerOperation start];

//    NSURLConnectionQueuedLoading
//    NSURLConnection *theConnection= [[NSURLConnection alloc] initWithRequest:theRequest delegate:self startImmediately:NO];
    
/*    [NSURLConnection sendAsynchronousRequest:theRequest queue:[NSOperationQueue currentQueue] completionHandler:^(NSURLResponse*r, NSData*d, NSError*e) {
        if (d) {
            StompFrame *sf = [StompFrame feed:&d];
        }
        if (e) {
            NSLog(@"reader error: %@", e);
        } else {
            
        }
    }];*/
#warning temporary
    
    //NSRunLoop *rl = [NSRunLoop currentRunLoop];
    //[theConnection scheduleInRunLoop:rl forMode:NSRunLoopCommonModes];
    //[theConnection start];
/*    if (theConnection) {
        // Create the NSMutableData to hold the received data.
        // receivedData is an instance variable declared elsewhere.
        receivedData = [[NSMutableData data] retain];
    } else {
        // Inform the user that the connection failed.
    }*/
}

- (void) scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
}

- (id) initWithChannel:(GIChannel *)ch {
    self = [super init];
    if (self) {
        
        //self.accumulator = [[NSMutableData alloc] init];
        accData = malloc(16384);
        capacity = 16384;
        self.channel = ch;
        [self hang];
    }
    return self;
}

- (void) dealloc {
    free(accData);
    
}

- (void)open {
}


- (void) doHang {
    [self performSelector:@selector(hang) withObject:nil afterDelay:1.0];
}

- (void) close {
    if (closed) return;
    closed = YES;
    //NSLog(@"reopening");
    //[self performSelector:@selector(hang) withObject:nil afterDelay:5.0];
    [self performSelectorOnMainThread:@selector(doHang) withObject:nil waitUntilDone:NO];
}

// stream methods

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len {
    while (used + len > capacity) {
        capacity *= 2;
        void *temp = malloc(capacity);
        if (used > 0) memcpy(temp, accData, used);
        free(accData);
        accData = temp;
    }
    memcpy(accData + used, buffer, len);
    used += len;
    int i0 = 0;
    NSString *s = [NSString stringWithCString:(const char *)buffer encoding:NSUTF8StringEncoding];
    NSLog(@"written: %@", s);
    for (int i = i0; i < used; i++)
        if (accData[i] == 0) {
            StompFrame *f = [StompFrame feed:&(accData[i0]) Length:i - i0];
            if (f) {
                i0 = i + 1;
                [self.channel gotFrame:f];
                seqnum = f.seqnum;
            }
        }
    if (i0 > 0) {
        used -= i0;
        if (used > 0)
            memcpy(accData, &(accData[i0]), used);
    }
    return len;
}

- (BOOL)hasSpaceAvailable {
    return YES;
}

- (NSStreamStatus)streamStatus {
    return NSStreamStatusOpen;
}

- (id) propertyForKey:(NSString *)key {
//    NSLog(@"P 4 K %@", key);
 //   if (key isEqual NSStreamDataWrittenToMemoryStreamKey)
    return nil;
}
// delegate methods

- (void)connection:(NSURLConnection *)connection didWriteData:(long long)bytesWritten totalBytesWritten:(long long)totalBytesWritten expectedTotalBytes:(long long) expectedTotalBytes {
    NSLog(@"dddddd");
}

- (void)connectionDidResumeDownloading:(NSURLConnection *)connection totalBytesWritten:(long long)totalBytesWritten expectedTotalBytes:(long long) expectedTotalBytes {
    NSLog(@"Wut?");
    
}

- (void)connectionDidFinishDownloading:(NSURLConnection *)connection destinationURL:(NSURL *) destinationURL {
    NSLog(@"Boom!");
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSLog(@"ae");
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    NSLog(@"af");
    
}

- (NSInputStream *)connection:(NSURLConnection *)connection needNewBodyStream:(NSURLRequest *)request {
    NSLog(@"ag");
    
}

@end
