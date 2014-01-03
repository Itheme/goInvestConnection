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
    prNotAFrame = -1,
    prIncompleteFrame = -2,
    prBadSeqNum = -3,
    prSessionClosed = -4,
    prInvalidSID = -5
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

static char cspHeader[] = {'0', '0', '1', '0'};
static char cspClosed[] = "Session closed";//{'S', 'e', 's', 's', 'i', 'o', 'n', ' ', 'c', 'l', 'o', 's', 'e', 'd'};
static char cspInvSID[] = "Invalid session ID";//{'S', 'e', 's', 's', 'i', 'o', 'n', ' ', 'c', 'l', 'o', 's', 'e', 'd'};


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
    if (seqnum > 0)
        CFHTTPMessageSetHeaderFieldValue(self.httpMessageRef, (__bridge CFStringRef)@"X-CspHub-Seqnum",  (__bridge CFStringRef)[NSString stringWithFormat:@"%d", seqnum, nil])
        ;
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
    [channel disconnectCSP];
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
    if (len > kTOTALCSPHLEN) {
        if (memcmp(cspHeader, buffer, 4) == 0) {
            int aseqnum, length;
            char *x = (char *)(buffer + 4);
            sscanf(x, "%8x%8x", &aseqnum, &length);
            if ((aseqnum >= seqnum - 20) && (aseqnum < seqnum + 20)) {
                if (length + kTOTALCSPHLEN - 1 > len) {
                    NSLog(@"inc. frame (seqnum = %d)", aseqnum);
                    return prIncompleteFrame;
                }
                NSLog(@"seqnum = %d", aseqnum);
                seqnum = aseqnum;
                return length;
            } else {
                NSLog(@"f");
                return prBadSeqNum;
            }
        } else {
            if (memcmp(cspClosed, buffer, 14) == 0)
                return prSessionClosed;
            if (memcmp(cspInvSID, buffer, 18) == 0)
                return prInvalidSID;
        }
            //if ((*buffer == '0') && (*(buffer+1) == '0') && (*(buffer+2) == '1') && (*(buffer+3) == '0')) {
            //    @throw @"DAFAQUE!!!";
            //}
            /*if (*buffer == '0') { // could be unicode crap happening
                NSString *s = [[NSString alloc] initWithBytes:buffer length:len encoding:NSUTF8StringEncoding];
                if ([s hasPrefix:@"0010"]) {
                    NSString *xs = [s substringWithRange:NSMakeRange(4, 8)];
                    int aseqnum = [xs hexValue];
                    if ((aseqnum >= seqnum - 20) && (aseqnum < seqnum + 20)) {
                        xs = [s substringWithRange:NSMakeRange(12, 8)];
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
            }*/
    } else {
        NSLog(@"ding!");
        return prIncompleteFrame;
    }


/*        NSString *s = [[NSString alloc] initWithBytes:buffer length:20 encoding:NSUTF8StringEncoding];
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
            }*/
    return prNotAFrame;
}

- (NSInteger)writeKnownBuffer:(const uint8_t *)buffer cspLength:(NSUInteger) cspLen maxLength:(NSUInteger)maxLen {
    const uint8_t *ptr = buffer + kTOTALCSPHLEN;
    [self writeGluedData:(char *)ptr Length:cspLen];
    int xlen = cspLen + kTOTALCSPHLEN;
    if (xlen < maxLen)
        return xlen + [self write:ptr + cspLen maxLength:maxLen - xlen];
    return maxLen;
}

- (NSInteger) addBufferToRawAccData:(const uint8_t *)buffer maxLength:(NSUInteger)len {
    while (rused + len > rcapacity) {
        rcapacity *= 2;
        void *temp = malloc(rcapacity);
        if (rused > 0) memcpy(temp, rawAccData, rused);
        free(rawAccData);
        rawAccData = temp;
    }
    memcpy(rawAccData + rused, buffer, len);
    rused += len;
    return len;
}

// stream methods

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len {
    if (len == 0) return 0;
    if (self.closed) return 0;
    NSString *s = [[NSString alloc] initWithBytes:buffer length:len encoding:NSUTF8StringEncoding];
    //NSLog(@"rused: %d, written: "/*%@"*/, rused);//, s);
    if (rused == 0) {
        int res = [self bufferHasStompFrame:buffer maxLength:len];
        if (res > 0) {
            char *ptr = (char *)buffer;
            ptr += kTOTALCSPHLEN;
            [self writeGluedData:(char *)ptr Length:res];
            ptr += res;
            res += kTOTALCSPHLEN;
            if (res < len) {
                NSLog(@"Rewriting");
                return res + [self write:(uint8_t *)ptr maxLength:len - res];
            }
            return len;
        }
    }
    [self addBufferToRawAccData:buffer maxLength:len];
    char *ptr = rawAccData;
    while (rused > 0) {
        int res = [self bufferHasStompFrame:(uint8_t *)ptr maxLength:rused];
        switch (res) {
            case prIncompleteFrame:
                if (rawAccData != ptr)
                    memcpy(rawAccData, ptr, rused);
                return len;
            case prNotAFrame:
                NSLog(@"whole lot of problems: %@", [[NSString alloc] initWithBytes:buffer length:len encoding:NSUTF8StringEncoding]);
                @throw [NSException exceptionWithName:@"Wrong prefix in csp protocol" reason:@"Wrong prefix in csp protocol" userInfo:nil];
            case prBadSeqNum:
                @throw [NSException exceptionWithName:@"CSP layer exception" reason:@"Got bad seqnum!" userInfo:nil];
            case prSessionClosed:
            case prInvalidSID:
                [self close];
#warning Release VCs on closing!
                return 0;
            default:
                ptr += kTOTALCSPHLEN;
                [self writeGluedData:ptr Length:res];
                rused -= res + kTOTALCSPHLEN;
                ptr += res;
                break;
        }
    }
    //NSString *s = [NSString stringWithCString:(const char *)buffer encoding:NSUTF8StringEncoding];
    return len;
}

- (BOOL)hasSpaceAvailable {
    return YES;
}

- (NSStreamStatus)streamStatus {
    return NSStreamStatusOpen;
}

@end
