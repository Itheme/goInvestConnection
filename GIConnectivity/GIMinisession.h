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
    msStartingSoon = 2,
    msRunning = 3,
    msEnded = 4
} GIMinisessionStatus;

typedef enum GIMinisessionTradingStatusEnum {
    tsNA = 0,
    tsOpening = 1,
    tsCanceled = 2,
    tsClosing = 3,
    tsBreak = 4,
    tsTrading = 5
} GIMinisessionTradingStatus;

static NSString *reuseIdUnknown = @"bad session state";
static NSString *reuseIdWaiting = @"waiting for ms";
static NSString *reuseIdStartingSoon = @"session starting soon";
static NSString *reuseIdEnded = @"session is ended";

static NSString *kSessionStatusKey = @"status";

@interface GIMinisession : NSObject

@property (nonatomic, readonly, retain) NSString *longId;
@property (nonatomic, readonly, retain) NSString *shortId;
@property (nonatomic, readonly, retain) NSString *caption;
@property (nonatomic, retain) NSString *secName;
@property (nonatomic, retain) NSString *notes;
@property (nonatomic, retain) NSString *sectorName;
@property (nonatomic) BOOL buy;
@property (nonatomic) GIMinisessionTradingStatus tradingStatus;

@property (nonatomic, readonly, getter = getScheduleString) NSString *scheduleString;
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
- (NSString *) subscriptionParams;
- (NSComparisonResult) comareWith:(GIMinisession *)s;

@end

void setMedvedevDelta(CFTimeInterval medvDelta);

CFAbsoluteTime CFAbsoluteTimeGetMedvedev();
