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
    scSEND          =  3,
    scREQUEST       =  4,
    scSUBSCRIBE     =  5,
    scUNSUBSCRIBE   =  6,
    scRECEIPT       =  7,
    scREPLY         =  8,
    scMESSAGE       =  9,
    scERROR         = 10,
    scInvalidSID    = 90
} StompCommand;


@interface StompCoder : NSCoder {
    
}

- (void) encodeValueOfObjCType:(const char *)type at:(const void *)addr;
- (void) decodeArrayOfObjCType:(const char *)itemType count:(NSUInteger)count at:(void *)array;
- (void) encodeDataObject:(NSData *)data;
- (NSData *) decodeDataObject;
- (NSInteger)versionForClassName:(NSString *)className;

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
@property (nonatomic, readonly, retain) NSString *jsonString;


- (id) initWithCommand:(StompCommand) sc Headers:(NSDictionary *) h;
- (void) addHeader:(id)value forKey:(id)key;
- (NSData *)makeBuffer;
+ (StompFrame *)feed:(void *)d Length:(NSUInteger)len;
//+ (NSData *) frameDataWithCommand:(StompCommand) sc;

@end
