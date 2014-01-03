//
//  StompFrame.m
//  GITest
//
//  Created by Mackey on 21.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "StompFrame.h"

@interface NSString (HexValue)

-(int) hexValue;
-(NSString *) headerValueForName:(NSString *) name;

@end


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
@property (nonatomic, retain) NSString *jsonString;

@end

@implementation StompFrame

@synthesize headers;
@synthesize seqnum, receipt, destination, requestId, sessionId, message, jsonString;
@synthesize command;

- (NSString *)encodedHeaders {
    __block NSString *l = [headers valueForKey:@"content-length"];
    __block NSString *res = l;
    if (res)
        res = [NSString stringWithFormat:@"content-length:%@\n", res];
    else
        res = @"";
    [headers enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (![key isEqual:l])
            res = [NSString stringWithFormat:@"%@%@:%@\n", res, key, obj];
    }];
    return res;
}

- (NSString *)encodedBody {
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
        default:
            return nil;
    }
    return [NSString stringWithFormat:@"%@\n%@\n\0", res, [self encodedHeaders], nil];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
#warning unimplemented
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

- (NSData *)makeBuffer {
    NSString *tmp = [self encodedBody];
    //NSLog(@"%@", tmp);
    return [tmp dataUsingEncoding:NSUTF8StringEncoding];
}

- (id) initWithSeqNum:(int) aseqnum Contents:(NSString *) content {
    self = [super init];
    if (self) {
        self.seqnum = aseqnum;
        __block int collected = 0;
        __block StompFrame *this = self;
        __block int contentLength = 0;
        __block NSString *isid = nil;
        [content enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
            /*NSRange r = [line rangeOfString:@"receipt-id:"];
            if (r.location == NSNotFound) {
                r = [line rangeOfString:@"content-length:"];
                if (r.location == NSNotFound) {
                    r = [line rangeOfString:@"destination:"];
                    if (r.location == NSNotFound) {
                        r = [line rangeOfString:@"request-id:"];
                        if (r.location == NSNotFound) {
                            r = [line rangeOfString:@"session:"];
                            if (r.location == NSNotFound) {
                                if ([line hasPrefix:@"RECEIPT"]) {// handling for simple messages
                                    this.command = scRECEIPT;
                                } else
                                    if ([line hasPrefix:@"CONNECTED"]) {
                                        this.command = scCONNECTED;
                                    }
                            } else {
                                this.sessionId = [line substringFromIndex:NSMaxRange(r)];
                            }
                        } else {
                            this.requestId = [line substringFromIndex:NSMaxRange(r)];
                            collected++;
                        }
                    } else {
                        this.destination = [line substringFromIndex:NSMaxRange(r)];
                        collected++;
                    }
                } else {
                    contentLength = [[line substringFromIndex:NSMaxRange(r)] intValue];
                    collected++;
                }
            } else {
                this.receipt = [line substringFromIndex:NSMaxRange(r)];
                collected++;
            }*/
            NSString *v = [line headerValueForName:@"receipt-id:"];
            if (v)
                this.receipt = v;
            else {
                v = [line headerValueForName:@"content-length:"];
                if (v)
                    contentLength = [v intValue];
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
                                    v = [line headerValueForName:@"Invalid session ID:"];
                                    if (v) {
                                        isid = v;
                                        this.command = scInvalidSID;
                                        *stop = YES;
                                    } else
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
                                }
                            }
                        }
                    }
                }
            }
            if (v) collected++;
            if (collected == 4) *stop = YES;
        }];
        if (isid)
            return self;
        if (contentLength > 0) {
            if (contentLength > [content length]) {
                NSLog(@"Crab %d > %d", contentLength, [content length]);
                return nil;
            } else
                self.jsonString = [content substringFromIndex:[content length] - contentLength];
        }
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

+ (StompFrame *)feed:(void *)d Length:(NSUInteger)len {
    StompFrame *f = nil;
    if (d) {
        NSString *s = [[NSString alloc] initWithBytes:d length:len encoding:NSUTF8StringEncoding];
        if (s)
            if ([s hasPrefix:@"0010"]) {
                NSString *xs = [NSString stringWithFormat:@"0x%@", [s substringWithRange:NSMakeRange(4, 8)], nil];
                int seqnum = [xs hexValue];
                xs = [NSString stringWithFormat:@"0x%@", [s substringWithRange:NSMakeRange(12, 8)], nil];
                int length = [xs hexValue];
                NSLog(@"seqnum = %d", seqnum);
                if (length + 20 - 1 > len) {
                    NSLog(@"incomplete stomp frame. Expected %d + 20. Got %d", length, len);
                    return nil;
                }
                s = [s substringWithRange:NSMakeRange(20, /*length - 1*/[s length] - 20)];
                f = [[StompFrame alloc] initWithSeqNum:seqnum Contents:s];
                //NSLog(@"s = %@", s);
            } else {
                NSLog(@"%@", s);
                NSLog(@" BAD CSP HEADER!!!!!!!");
                //@throw [NSException exceptionWithName:@"bad csp header!" reason:s userInfo:nil];
            }
        
    }
    return f;    
}


@end



@implementation StompCoder

- (void) encodeValueOfObjCType:(const char *)type at:(const void *)addr {
    NSLog(@"aa %s", type);
}

- (void) decodeArrayOfObjCType:(const char *)itemType count:(NSUInteger)count at:(void *)array {
    NSLog(@"ab");
}

- (void) encodeDataObject:(NSData *)data {
    NSLog(@"ac");
}

- (NSData *) decodeDataObject {
    NSLog(@"ad");
}

- (NSInteger)versionForClassName:(NSString *)className {
    return 1;
}


@end
