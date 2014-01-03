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
    NSString *content = [[NSString alloc] initWithBytes:d length:MIN(1000, len) encoding:NSUTF8StringEncoding];
    [content enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        NSString *v = [line headerValueForName:@"content-length:"];
        if (v) {
            contentLength = [v intValue];
            *stop = YES;
        }
    }];
    return contentLength;
}

+ (StompFrame *)feed:(void *)d ContentLength:(NSInteger)contentLength MaxLength:(NSUInteger)len {
    StompFrame *f = nil;
    if (d)
        f = [[StompFrame alloc] initWithSeqNum:0 FirstByte:d ByteCount:len ContentLength:contentLength];
    return f;    
}



@end
