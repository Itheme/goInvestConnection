//
//  GIMinisession.h
//  GITest
//
//  Created by Mackey on 26.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum GIMinisessionStatusEnum {
    msUnknown = 0,
    msWaiting = 1,
    msRunning = 2,
    msEnded = 3
} GIMinisessionStatus;

static NSString *reuseIdUnknown = @"bad session state";
static NSString *reuseIdWaiting = @"waiting for ms";
static NSString *reuseIdStartingSoon = @"session starting soon";
static NSString *reuseIdEnded = @"session is ended";

@interface GIMinisession : NSObject

@property (nonatomic, readonly, retain) NSString *longId;
@property (nonatomic, readonly, retain) NSString *shortId;
@property (nonatomic, readonly, retain) NSString *caption;
@property (nonatomic, retain) NSString *instrid;
@property (nonatomic, readonly, retain) NSMutableDictionary *times;
@property (nonatomic, readonly, getter = getStatus) GIMinisessionStatus status;
@property (nonatomic, readonly, getter = getTimeTillRun) CFAbsoluteTime timeTillRun;
@property (nonatomic, readonly, getter = getTimeTillEnd) CFAbsoluteTime timeTillStop;
@property (nonatomic, readonly, getter = getPercentDone) float percentDone;

- (id) initWithLongId:(NSString *)alongId Caption:(NSString *)cap;
- (void) setEvent:(NSString *)event EventStatus:(NSString *)eventStatus AtTime:(NSString *)timeStr;
- (BOOL) hasNextUIRefreshTime:(CFAbsoluteTime *)t;
- (NSString *) reuseId;

@end

CFAbsoluteTime CFAbsoluteTimeGetMedvedev();
