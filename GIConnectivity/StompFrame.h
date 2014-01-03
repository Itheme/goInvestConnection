//
//  StompFrame.h
//  GITest
//
//  Created by Mackey on 21.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef enum StompCommandsEnum {
    scUNKNOWN       =  0,
    scCONNECT       =  1,
    scCONNECTED     =  2,
    scDISCONNECT    =  3,
    scSEND          =  4,
    scREQUEST       =  5,
    scSUBSCRIBE     =  6,
    scUNSUBSCRIBE   =  7,
    scRECEIPT       =  8,
    scREPLY         =  9,
    scMESSAGE       = 10,
    scERROR         = 11,
    scCLOSED        = 12,
    scInvalidSID    = 90,
    scGenericError  = 91
} StompCommand;


@interface NSString (HexValue)

-(int) hexValue;
-(NSString *) headerValueForName:(NSString *) name;

@end


@interface StompFrame : NSObject {

}

@property (nonatomic) int seqnum;
@property (nonatomic, readonly) StompCommand command;
@property (nonatomic, readonly, retain) NSString *receipt;
@property (nonatomic, readonly, retain) NSString *destination;
@property (nonatomic, readonly, retain) NSString *requestId;
@property (nonatomic, readonly, retain) NSString *sessionId;
@property (nonatomic, readonly, retain) NSString *message;
@property (nonatomic, readonly, retain) NSString *subscription;
@property (nonatomic, readonly, retain) id jsonData;


- (id) initWithCommand:(StompCommand) sc Headers:(NSDictionary *) h;
- (void) addHeader:(id)value forKey:(id)key;
- (NSData *)makeBufferWith:(NSData *) addendum;
+ (StompFrame *)feed:(void *)d ContentLength:(NSInteger)contentLength MaxLength:(NSUInteger)len;
//+ (NSData *) frameDataWithCommand:(StompCommand) sc;
+ (NSInteger) extractContentLength:(void *)d Length:(NSUInteger)len;

@end

typedef void(^StompSuccessBlock)(StompFrame *f);
typedef void(^StompFailureBlock)(NSString *errorMessage);
