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


enum CspFrameParseResult {
    prNotAFrame = 0,
    prIncompleteFrame = -1,
    prBadSeqNum = -2
};

@interface GIReader () {
    char *rawAccData, *gluedAccData;
    int rcapacity, rused, gcapacity, gused, gseqnum, seqnum;
}

//@property (atomic, retain) NSMutableData *accumulator;
@property (nonatomic, retain) NSMutableURLRequest *theRequest;
@property (nonatomic, retain) AFURLConnectionOperation *readerOperation;

@property (atomic) CFHTTPMessageRef httpMessageRef;
@property (atomic) BOOL closed;

@end

@implementation GIReader

@synthesize channel;
@synthesize httpMessageRef, closed;
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
    self.httpMessageRef = CFHTTPMessageCreateRequest(NULL, CFSTR("GET"), cfURL, kCFHTTPVersion1_0);
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
        if (!self.closed)
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
        rawAccData = malloc(16384);
        gluedAccData = malloc(16384);
        rcapacity = 16384;
        gcapacity = 16384;
        self.channel = ch;
        [self hang];
    }
    return self;
}

- (void) dealloc {
    free(rawAccData);
    free(gluedAccData);
    
}

- (void) doHang {
    [self performSelector:@selector(hang) withObject:nil afterDelay:1.0];
}

- (void) close {
    if (closed) return;
    closed = YES;
    CFRelease(httpMessageRef);
}

- (BOOL) tryExtractFrameWith:(NSInteger) contentLength {
    char *ptr = gluedAccData;
    for (int limit = contentLength; limit < gused; limit++)
        if (ptr[limit] == 0) {
            limit++;
            StompFrame *f = [StompFrame feed:ptr ContentLength:contentLength MaxLength:limit];
            if (f) {
                [self.channel gotFrame:f];
            } else {
                NSLog(@"What a pitty! fake frame!");
            }
            ptr += limit;
            gused -= limit;
            if (gused > 0) {
                memcpy(gluedAccData, ptr, gused);
            }
            return TRUE;
        }
    return FALSE;
}

- (BOOL) writeGluedData:(char *)buffer Length:(NSUInteger) len {
    while (gused + len > gcapacity) {
        gcapacity *= 2;
        void *temp = malloc(gcapacity);
        if (gused > 0) memcpy(temp, gluedAccData, gused);
        free(gluedAccData);
        gluedAccData = temp;
    }
    memcpy(gluedAccData + gused, buffer, len);
    gused += len;

    char *ptr = gluedAccData;
    
    BOOL gotFrame = FALSE;
    while (gused > 0) {
        NSUInteger clength = [StompFrame extractContentLength:ptr Length:gused];
        if (clength > gused) {
            NSLog(@"incomplete stomp frame. Expected %d. Got %d", clength, gused);
            break;
        }
        if ([self tryExtractFrameWith:clength])
            gotFrame = TRUE;
    }
    return gotFrame;
}

- (int) bufferHasStompFrame:(const uint8_t *)buffer maxLength:(NSUInteger)len {
    if (len > 20) {
        NSString *s = [[NSString alloc] initWithBytes:buffer length:20 encoding:NSUTF8StringEncoding];
        if (s)
            if ([s hasPrefix:@"0010"]) {
                NSString *xs = [NSString stringWithFormat:@"0x%@", [s substringWithRange:NSMakeRange(4, 8)], nil];
                int aseqnum = [xs hexValue];
                if ((aseqnum >= seqnum - 20) && (aseqnum < seqnum + 20)) {
                    xs = [NSString stringWithFormat:@"0x%@", [s substringWithRange:NSMakeRange(12, 8)], nil];
                    int length = [xs hexValue];
                    if (length + 20 - 1 > len) {
                        //NSLog(@"incomplete csp frame. Expected %d + 20. Got %d", length, rused);
                        return prIncompleteFrame;
                    }
                    NSLog(@"seqnum = %d", aseqnum);
                    seqnum = aseqnum;
                    return length;
                } else
                    return prBadSeqNum;
            }
    }
    return prNotAFrame;
}

- (NSInteger)writeKnownBuffer:(const uint8_t *)buffer cspLength:(NSUInteger) cspLen maxLength:(NSUInteger)maxLen {
    const uint8_t *ptr = buffer + 20;
    [self writeGluedData:(char *)ptr Length:cspLen];
    int xlen = cspLen + 20;
    if (xlen < maxLen)
        return xlen + [self write:ptr + cspLen maxLength:maxLen - xlen];
    return maxLen;
}
#warning make 20 a constant

// stream methods

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len {
    if (len == 0) return 0;
    int res = [self bufferHasStompFrame:buffer maxLength:len];
    if (rused > 0) {
        if (res == prIncompleteFrame)
            @throw [NSException exceptionWithName:@"CSP layer exception" reason:@"Got two incomplete CSP frames in a row!" userInfo:nil];
        if (res != prBadSeqNum) // assuming just misstaken header match
            if (res != prNotAFrame)
                return [self writeKnownBuffer:buffer cspLength:res maxLength:len];
        // else adding to rawAccData
    } else {
        if (res == prNotAFrame) {
            NSLog(@"whole lot of problems: %@", [[NSString alloc] initWithBytes:rawAccData length:rused encoding:NSUTF8StringEncoding]);
            @throw [NSException exceptionWithName:@"Wrong prefix in csp protocol" reason:@"Wrong prefix in csp protocol" userInfo:nil];
        }
        if (res == prBadSeqNum)
            @throw [NSException exceptionWithName:@"CSP layer exception" reason:@"Got bad seqnum!" userInfo:nil];
        if (res != prIncompleteFrame)
            return [self writeKnownBuffer:buffer cspLength:res maxLength:len];
    }
    while (rused + len > rcapacity) {
        rcapacity *= 2;
        void *temp = malloc(rcapacity);
        if (rused > 0) memcpy(temp, rawAccData, rused);
        free(rawAccData);
        rawAccData = temp;
    }
    memcpy(rawAccData + rused, buffer, len);
    rused += len;
    char *ptr = rawAccData;
    while (rused > 20) {
        int res = [self bufferHasStompFrame:(uint8_t *)ptr maxLength:rused];
        if ((res == prNotAFrame) || (res == prBadSeqNum))
            @throw [NSException exceptionWithName:@"CSP layer exception" reason:@"WTF!?" userInfo:nil];
        if (res == prIncompleteFrame) break;
        ptr += 20;
        [self writeGluedData:ptr Length:res];
        rused -= res + 20;
        ptr += res;
    }
    if (rused > 0) {
        memcpy(rawAccData, ptr, rused);
    }
    
    NSString *s = [NSString stringWithCString:(const char *)buffer encoding:NSUTF8StringEncoding];
    NSLog(@"written: %@", s);
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

@end
