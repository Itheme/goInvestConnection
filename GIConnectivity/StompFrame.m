//
//  StompFrame.m
//  GITest
//
//  Created by Mackey on 21.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "StompFrame.h"




@implementation NSString (HexValue)

- (int) hexValue {
    int n = 0;
    sscanf([self UTF8String], "%x", &n);
    return n;
}

-(NSString *) headerValueForName:(NSString *) name {
    if ([self hasPrefix:name])
        return [self substringFromIndex:[name length]];
    return nil;
}

@end
@interface StompFrame () {
}

@property (nonatomic, retain) NSMutableDictionary *headers;
@property (nonatomic) StompCommand command;
@property (nonatomic, retain) NSString *receipt;
@property (nonatomic, retain) NSString *destination;
@property (nonatomic, retain) NSString *requestId;
@property (nonatomic, retain) NSString *sessionId;
@property (nonatomic, retain) NSString *message;
@property (nonatomic, retain) NSString *subscription;
@property (nonatomic, retain) id jsonData;

@end

@implementation StompFrame

@synthesize headers;
@synthesize seqnum, receipt, destination, requestId, sessionId, message, subscription, jsonData;
@synthesize command;

static char contentLengthHeader[] = "content-length:";

- (NSString *)encodedHeaders:(NSUInteger) contentLength {
    __block NSString *res = @"";
    if (contentLength > 0) res = [NSString stringWithFormat:@"content-length:%d\n", contentLength];
    [headers enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (![key isEqualToString:@"content-length"])
            if (res)
                res = [NSString stringWithFormat:@"%@%@:%@\n", res, key, obj];
            else
                res = [NSString stringWithFormat:@"%@:%@\n", key, obj];
    }];
    return res;
}

- (NSData *)encodedBodyWith:(NSData *) addendum {
    NSString *res;
    switch (command) {
        case scCONNECT:
            res = @"CONNECT";
            break;
        case scREQUEST:
            res = @"REQUEST";
            break;
        case scSUBSCRIBE:
            res = @"SUBSCRIBE";
            break;
        case scUNSUBSCRIBE:
            res = @"UNSUBSCRIBE";
            break;
        case scSEND:
            res = @"SEND";
            break;
        default:
            return nil;
    }
    if (addendum) {
        int l = [addendum length];
        res = [NSString stringWithFormat:@"%@\n%@\n", res, [self encodedHeaders:l + 1], nil];
        char b[l + 2];
        memcpy(b, [addendum bytes], l);
        //NSLog(@"Output: %@", res);
        //return [res dataUsingEncoding:NSUTF8StringEncoding];
        NSMutableData *d = [[res dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
        NSLog(@"%c%c%c", b[l - 2], b[l - 1], b[l]);
        b[l] = '\n';
        b[l + 1] = 0;
        [d appendBytes:b length:l + 2];
//        [d appendBytes:"\n\n\0" length:3];
        NSLog(@"Output: %@", [NSString stringWithUTF8String:[d bytes]]);
        return d;
    }
    NSString *output = [NSString stringWithFormat:@"%@\n%@\n\0", res, [self encodedHeaders:0], nil];
    NSLog(@"Output: %@", output);
    return [output dataUsingEncoding:NSUTF8StringEncoding];
}

- (id) initWithCommand:(StompCommand) sc Headers:(NSDictionary *) h {
    self = [super init];
    if (self) {
        command = sc;
        if (h)
            self.headers = [h mutableCopy];
        else
            self.headers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void) addHeader:(id)value forKey:(id)key {
    [headers setValue:value forKey:key];
}

- (NSData *)makeBufferWith:(NSData *) addendum {
    //NSString *tmp = ;
    //NSLog(@"%@", tmp);
    return [self encodedBodyWith:addendum];
}

- (id) initWithSeqNum:(int) aseqnum FirstByte:(char *) rawdata ByteCount:(uint) bytesTotal ContentLength:(uint) contentLength {
    if (contentLength > 0) {
        if (contentLength > bytesTotal) {
            NSLog(@"Crab %d > %d !!!!!!!!!!!!!!!!!!!!!!", contentLength, bytesTotal);
            return nil;
        }
    }
    self = [super init];
    if (self) {
        self.seqnum = aseqnum;
        __block int collected = 0;
        __block StompFrame *this = self;
        __block NSString *isid = nil;
        //__block NSString *alreadySubscribed = nil;
        NSString *content = [[NSString alloc] initWithBytes:rawdata length:bytesTotal - contentLength - 1 encoding:NSUTF8StringEncoding];
        [content enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
            isid = [line headerValueForName:@"Invalid session ID:"];
            if (isid) {
                this.command = scInvalidSID;
                *stop = YES;
            } else {
                if ([line hasPrefix:@"RECEIPT"]) {// handling for simple messages
                    this.command = scRECEIPT;
                } else
                    if ([line hasPrefix:@"CONNECTED"]) {
                        this.command = scCONNECTED;
                    } else
                        if ([line hasPrefix:@"ERROR"]) {
                            this.command = scERROR;
                        } else
                            if ([line hasPrefix:@"MESSAGE"])
                                this.command = scMESSAGE;
                            else
                                if ([line hasPrefix:@"CLOSED"])
                                    this.command = scCLOSED;
            }
        }];
        if (isid)
            return self;
        if (contentLength > 0) {
            NSError *error = nil;
            self.jsonData = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:rawdata + bytesTotal - contentLength - 1 length:contentLength] options:0 error:&error];
            if (error) {
                NSLog(@"JSON parsing error: %@", error);
                self.message = [NSString stringWithUTF8String:rawdata + bytesTotal - contentLength - 1];
                NSLog(@"JSON raw data: %@", self.message);
                self.command = scGenericError;
            }
            //NSLog(@"JSON: %@", self.jsonData);
        }
        [content enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
            NSString *v = [line headerValueForName:@"receipt-id:"];
            if (v)
                this.receipt = v;
            else {
                v = [line headerValueForName:@"destination:"];
                if (v)
                    this.destination = v;
                else {
                    v = [line headerValueForName:@"request-id:"];
                    if (v)
                        this.requestId = v;
                    else {
                        v = [line headerValueForName:@"session:"];
                        if (v)
                            this.sessionId = v;
                        else {
                            v = [line headerValueForName:@"message:"];
                            if (v)
                                this.message = v;
                            else {
                                v = [line headerValueForName:@"subscription:"];
                                if (v)
                                    this.subscription = v;
                                else {
                                    //@"message-id:"
                                    //NSLog(@"UNKNOWN HEADER: %@", line);
                                }
                            }
                        }
                    }
                }
            }
            if (v) collected++;
        }];
        NSLog(@"Start of frame: %@", content);
        if (self.command != scUNKNOWN) return self;
        if (collected < 2) {
            NSLog(@"insufficient headers list");
            return nil;
        }
        if ([content hasPrefix:@"REPLY"]) {
            self.command = scREPLY;
        } else {
            NSLog(@"Oh!");
#warning CLOSED!!!!
            return nil;
        }
            /*NSRange r = [content rangeOfString:@"receipt-id:"];
            if (r.location == NSNotFound) return nil;
            self.receipt = [[content substringFromIndex:NSMaxRange(r)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
                return nil;*/
                
        
/*        NSError *e = nil;
        NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:@"receipt-id:\\d+" options:0 error:&e];
        NSTextCheckingResult *res = [regexp firstMatchInString:content options:NSMatchingAnchored range:NSMakeRange(0, [content length])];
        NSLog(@"%@ :: %@", res, res.replacementString);
        */
    }
    return self;
}

+ (NSInteger) extractContentLength:(void *)d Length:(NSUInteger)len {
    __block int contentLength = 0;
    char *c = d;
    for (int i = len; i--; c++)
        if (*c == 'c') {
            if (memcmp(c, contentLengthHeader, 15) == 0) {
                c += 15;
                int cl = 0;
                sscanf(c, "%d", &cl);
                return cl;
            }
        }
    /*NSString *content = [[NSString alloc] initWithBytes:d length:MIN(1000, len) encoding:NSUTF8StringEncoding];
    [content enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        NSString *v = [line headerValueForName:@"content-length:"];
        if (v) {
            contentLength = [v intValue];
            *stop = YES;
        }
    }];*/
    return contentLength;
}

+ (StompFrame *)feed:(void *)d ContentLength:(NSInteger)contentLength MaxLength:(NSUInteger)len {
    StompFrame *f = nil;
    if (d)
        f = [[StompFrame alloc] initWithSeqNum:0 FirstByte:d ByteCount:len ContentLength:contentLength];
    return f;    
}



@end
