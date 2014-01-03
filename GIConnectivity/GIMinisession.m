//
//  GIMinisession.m
//  GITest
//
//  Created by Mackey on 26.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "GIMinisession.h"

@interface GIMinisession () {
    CFAbsoluteTime endTime;
    BOOL started, ended;
    GIMinisessionStatus lastCheckedStatus;
    CFAbsoluteTime lastCheckedTime;
}

@property (nonatomic, retain) NSString *longId;
@property (nonatomic, retain) NSString *shortId;
@property (nonatomic, retain) NSString *caption;
//@property (nonatomic, retain) NSString *instrid;
@property (nonatomic, retain) NSMutableDictionary *times;
@property (nonatomic) CFAbsoluteTime startTime;

@end

CFTimeInterval medvedDelta = 0.0;

void setMedvedevDelta(CFTimeInterval medvDelta) {
    medvedDelta = medvDelta;
}

CFAbsoluteTime CFAbsoluteTimeGetMedvedev() {
    return CFAbsoluteTimeGetCurrent() + medvedDelta;// (60.0*60.0);
}

@implementation GIMinisession

@synthesize longId, shortId, caption, times, instrid;
@synthesize status;
@synthesize startTime;
@synthesize timeTillRun, timeTillStop, percentDone;
@synthesize scheduleString;

- (id) initWithLongId:(NSString *)alongId Caption:(NSString *)cap {
    self = [super init];
    if (self) {
        self.longId = alongId;
        self.shortId = [alongId stringByReplacingOccurrencesOfString:@"GSEL" withString:@""];
        self.caption = cap;
        startTime = -1;
        endTime = -1;
    }
    return self;
}

- (void) setEvent:(NSString *)event EventStatus:(NSString *)eventStatus AtTime:(NSString *)timeStr OfDate:(NSDate *)date {
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"HH:mm:ss";
    //NSTimeZone *localZone = [NSTimeZone localTimeZone];
    //dateFormatter.timeZone = localZone;//[NSTimeZone localTimeZone];
    dateFormatter.defaultDate = date;
    NSDate *d = [dateFormatter dateFromString:timeStr];
    //NSLog(@"%@", d);
    if ([event hasPrefix:@"H"]) {
#warning add other events here
        return;
    }
    BOOL active = [eventStatus hasPrefix:@"A"];
    if (!active)
        if (![eventStatus hasPrefix:@"L"])
            @throw [NSException exceptionWithName:@"wrong status" reason:[NSString stringWithFormat:@"%@ at %@", eventStatus, timeStr, nil] userInfo:nil];
    if ([event hasPrefix:@"4"]) {
        started = !active;
        self.startTime = [d timeIntervalSinceReferenceDate];
        //startTime -= 60.0*60.0;
        //startTime += [localZone secondsFromGMT];
        //startTime -= CFAbsoluteTimeGetCurrent();
        return;
    }
    if ([event hasPrefix:@"5"]) {
        ended = !active;
        endTime = [d timeIntervalSinceReferenceDate];// + [localZone secondsFromGMT];
        //endTime -= 60.0*60.0;
        //endTime += [localZone secondsFromGMT];
        return;
    }
    NSLog(@"What an event: %@ ???", event);
    return;

}

- (void) setEvent:(NSString *)event EventStatus:(NSString *)eventStatus AtTime:(NSString *)timeStr {
    [self setEvent:event EventStatus:eventStatus AtTime:timeStr OfDate:[NSDate date]];
}

- (GIMinisessionStatus) getStatus {
    if ((startTime < 0) || (endTime < 0))
        return msUnknown;
    if (started) {
        if (ended)
            return msEnded;
        CFTimeInterval d = endTime - CFAbsoluteTimeGetMedvedev();
        if (d < 0) {
            NSLog(@"timetable updating problem");
            ended = true;
            return msEnded;
        }
        return msRunning;
    }
    CFTimeInterval d = startTime - CFAbsoluteTimeGetMedvedev();
    if (d < 0) {
        NSLog(@"timetable updating problem");
        started = true;
        return [self getStatus];
    }
    if (d < 5*60)
        return msStartingSoon;
    return msWaiting;
}

- (CFAbsoluteTime) getTimeTillRun {
    return self.startTime - CFAbsoluteTimeGetMedvedev();
}

- (CFAbsoluteTime) getTimeTillEnd {
    return endTime - CFAbsoluteTimeGetMedvedev();
}

- (float) getPercentDone {
    CFTimeInterval total = endTime - startTime;
    return (CFAbsoluteTimeGetMedvedev() - self.startTime) / total;
}

- (BOOL) hasNextUIRefreshTime:(CFAbsoluteTime *)t {
    GIMinisessionStatus ns = [self getStatus];
    *t = -1.0;
    CFAbsoluteTime n = CFAbsoluteTimeGetMedvedev();
    if ((lastCheckedStatus == ns) || (lastCheckedStatus == msUnknown))
        switch (ns) {
            case msUnknown:  return NO;
            case msStartingSoon:
                *t = 1.0;
                break;
            case msWaiting: // more than five minutes till start
                *t = startTime - 5*60 + 1;
                break;
            case msRunning: break;
            case msEnded:   return NO;
        }
    lastCheckedStatus = ns;
    lastCheckedTime = n;
    return YES;
}

- (NSString *) reuseId {
    switch (lastCheckedStatus) {
        case msUnknown:      return reuseIdUnknown;
        case msWaiting:      return reuseIdWaiting;
        case msStartingSoon: return reuseIdStartingSoon;
        case msRunning:      return self.longId;
        case msEnded:        return reuseIdEnded;
    }
}

- (NSString *) getScheduleString {
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"HH:mm";
    NSString *res;
    if (startTime > 0) {
        res = [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:startTime]];
        if (endTime > 0)
            return [NSString stringWithFormat:@"%@ - %@", res, [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:endTime]], nil];
        return [NSString stringWithFormat:@"%@ - ...", res, nil];
    }
    if (endTime > 0)
        return [NSString stringWithFormat:@"... - %@", [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:endTime]], nil];
    return @"";
}

- (NSComparisonResult) comareWith:(GIMinisession *)s {
    if (startTime > s.startTime + .9)
        return 1;
    if (startTime > s.startTime - 0.9)
        return 0;
    return -1;
}

@end
