//
//  GIClient.m
//  GITest
//
//  Created by Mackey on 23.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "GIClient.h"
#import "GIClientStates.h"

#import "AFJSONRequestOperation.h"

@interface GIClient () {
    int timeDeltaCount;
    CFTimeInterval timeDelta[5];
}

@property (nonatomic, setter = setState:) GIClientState state;
@property (nonatomic, retain) NSString *login;
@property (nonatomic, retain) NSString *pwd;
@property (nonatomic, retain) NSString *lastStatusMessage;
@property (nonatomic, retain) NSString *disconnectionReason;
@property (nonatomic) int substate;
@property (nonatomic, retain) GIChannel *channel;

// parsing stuff
@property (nonatomic, retain) id tickerList;
@property (nonatomic, retain) NSArray *tradeTimeLists;
@property (nonatomic, retain) NSArray *secInfoLists;

@property (nonatomic) BOOL minisessionsWasBuilt;

@property (nonatomic, retain) NSDictionary *minisessions;

@end

@implementation GIClient

@synthesize state, login, pwd;
@synthesize channel;
@synthesize lastStatusMessage, disconnectionReason;
@synthesize substate;

@synthesize tickerList, tradeTimeLists, secInfoLists, minisessions;

static NSString *kEendPoint = @"https://goinvest.micex.ru";//@"http://172.20.9.167:8080";//@"https://goinvest.micex.ru";

static NSString *kStatusMessage01 = @"Could not download marketplaces!";
static NSString *kStatusMessage02 = @"Could not find MXZERNO in marketplaces!";
static NSString *kStatusMessage03 = @"Channel failed to startup (%@)";
static NSString *kStatusMessage04 = @"Failed to download marketplaces (error: %@, reply: %@)";
static NSString *kStatusMessage05 = @"Connection is lost";
static NSString *kStatusMessage06 = @"Could not get minisessions' info (%@)";
static NSString *kStatusMessage07 = @"Could not get systime (%@)";
static NSString *kStatusMessage08 = @"Could not get tradetimes (%@)";
static NSString *kStatusMessage09 = @"Could not acquire system log (%@)";
static NSString *kStatusMessage10 = @"";
static NSString *kStatusMessage11 = @"";
static NSString *kStatusMessage12 = @"";
static NSString *kStatusMessage13 = @"";
static NSString *kStatusMessage14 = @"";
static NSString *kStatusMessage15 = @"";


- (id) initWithUser:(NSString *)alogin Pwd:(NSString *)apwd {
    self = [super init];
    if (self) {
        self.login = alogin;
        self.pwd = apwd;
        self.channel = [[GIChannel alloc] initWithURL:[NSURL URLWithString:kEendPoint] Options:nil Delegate:self];
    }
    return self;
}

- (void) marketLoaded:(NSArray *)marketPlaces {
    if ((state == csConnecting) || (substate == 1)) {
        for (NSDictionary *mp in marketPlaces)
            if ([[mp valueForKey:@"id"] isEqualToString:@"MXZERNO"]) {
                self.channel.channelId = [mp valueForKey:@"channel"];
                self.channel.caption = [mp valueForKey:@"caption"];
                NSLog(@"ZERNO is on %@ channel called %@", self.channel.channelId, self.channel.caption);
                if (![self.channel connect:login Password:pwd]) {
                    self.lastStatusMessage = kStatusMessage01;
                    self.state = csDisconnectedWithProblem;
                } else {
                    substate = 2;
                }
                return;
            }
        self.lastStatusMessage = kStatusMessage02;
        self.state = csDisconnectedWithProblem;
    }
}

- (void) connectionFailed:(NSError *)error {
    self.lastStatusMessage = [NSString stringWithFormat:kStatusMessage03, error.description, nil];
    self.state = csDisconnectedWithProblem;
}

- (void) connect {
    if ((state == csDisconnected) || (state == csDisconnectedWithProblem)) {
        self.state = csConnecting;
        self.substate = 0;
        __block GIClient *this = self;
        NSURL *url = [NSURL URLWithString:@"https://goinvest.micex.ru/statics/marketplaces.json"];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
            NSArray *marketPlaces = [JSON valueForKey:@"marketplaces"];
            self.substate = 1;
            [this marketLoaded:marketPlaces];
        } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
            self.lastStatusMessage = [NSString stringWithFormat:kStatusMessage04, error, JSON, nil];
            self.state = csDisconnectedWithProblem;
        }];
        operation.JSONReadingOptions |= NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves | NSJSONReadingAllowFragments;
        [operation start];

    }
}

- (void) disconnect {
    if (self.state == csConnected) {
        self.state = csDisconnecting;
        [self.channel disconnect];
        [self.channel disconnectCSP];
    }
}

- (void) disconnectWithMessage:(NSString *)message {
    self.disconnectionReason = message;
    [self disconnect];
}

- (void) pseudoConnect {
    NSArray *dummyTickers = @[@[@"MXZERNO.GSEL.LOT121025092", @"92 W4 S452"],
                              @[@"MXZERNO.GSEL.LOT121025093", @"93 W3 S479"],
                              @[@"MXZERNO.GSEL.LOT121025094", @"94 W4 S628"]];

    NSMutableDictionary *res = [[NSMutableDictionary alloc] init];
    //NSDateFormatter *df = [NSDateFormatter dateFormatFromTemplate:@"HH:mm" options:0 locale:[NSLocale currentLocale]];
    double x = -60.0;
    for (NSArray *tickerRow in dummyTickers) {
        GIMinisession *s = [[GIMinisession alloc] initWithLongId:[tickerRow objectAtIndex:0] Caption:[tickerRow objectAtIndex:1]];
        //NSString *t = [df stringFromDate:[NSDate dateWithTimeIntervalSinceNow:-1.0]];
        NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"HH:mm";
        NSDate *d = [NSDate dateWithTimeIntervalSinceNow:x];
        NSString *t = [dateFormatter stringFromDate:d];
        x += 60;
        NSLog(@"Pseudo T:%@", t);
        [s setEvent:@"4" EventStatus:@"A" AtTime:t];
        [s setEvent:@"5" EventStatus:@"A" AtTime:[dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:x]]];
        [res setValue:s forKey:s.longId];
        x += 60;
    }
    self.minisessions = res;
    self.state = csPseudoConnect;
}

- (NSDictionary *) extractTimes {
    NSArray *t = tradeTimeLists;
    NSDictionary *times = nil;
    for (id x in t)
        if ([x isKindOfClass:[NSDictionary class]])
            times = x;
        else
            self.tradeTimeLists = x;
    if ([self.tradeTimeLists isEqual:t]) self.tradeTimeLists = nil; // only one dictionary
    return times;
}

- (NSDictionary *) extractSecInfos {
    NSArray *i = secInfoLists;
    NSDictionary *infos = nil;
    for (id x in i)
        if ([x isKindOfClass:[NSDictionary class]])
            infos = x;
        else
            self.secInfoLists = x;
    if ([self.secInfoLists isEqual:i]) self.secInfoLists = nil;
    return infos;
}

- (void) addUnparsedLists {
    if (self.minisessionsWasBuilt) {
        NSDictionary *times = [self extractTimes];
        if (times) {
            @try {
            NSArray *columns = [times valueForKey:@"columns"];
            NSUInteger tTickerIndex = [columns indexOfObject:@"TICKER"];
            NSUInteger tTimeIndex = [columns indexOfObject:@"TIME"];
            NSUInteger tTypeIndex = [columns indexOfObject:@"TYPE"];
            NSUInteger tInstrIndex = [columns indexOfObject:@"INSTRID"];
            NSUInteger tStatusIndex = [columns indexOfObject:@"STATUS"];
            NSArray *timesRows = [times valueForKey:@"data"];
            for (NSArray *timeRow in timesRows) {
                NSString *longId = [[timeRow objectAtIndex:tTickerIndex] stringByReplacingOccurrencesOfString:@".." withString:@".GSEL."];
                GIMinisession *s = [self.minisessions valueForKey:longId];
                if (s.instrid == nil)
                    s.instrid = [timeRow objectAtIndex:tInstrIndex];
                [s setEvent:[timeRow objectAtIndex:tTypeIndex] EventStatus:[timeRow objectAtIndex:tStatusIndex] AtTime:[timeRow objectAtIndex:tTimeIndex]];
            }
            }
            @catch (NSException *exception) {
                NSLog(@"Don't care...");
            }
        }
        NSDictionary *secInfos = [self extractSecInfos];
        if (secInfos) {
            @try {
                NSArray *columns = [secInfos valueForKey:@"columns"];
                NSUInteger tTickerIndex = [columns indexOfObject:@"TICKER"];
                NSUInteger tTradingStatusIndex = [columns indexOfObject:@"TRADINGSTATUS"];
                NSUInteger tSessionStateIndex = [columns indexOfObject:@"SESSIONSTATE"];
                NSUInteger tAuctionTypeIndex = [columns indexOfObject:@"AUCTIONTYPE"];
                NSUInteger tSectorNameIndex = [columns indexOfObject:@"SECTORNAME"];
                NSUInteger tSecNameIndex = [columns indexOfObject:@"SECNAME"];
                NSUInteger tNotesIndex = [columns indexOfObject:@"NOTES"];
                NSArray *infoRows = [secInfos valueForKey:@"data"];
                for (NSArray *infoRow in infoRows) {
                    GIMinisession *s = [self.minisessions valueForKey:[infoRow objectAtIndex:tTickerIndex]];
                    if (s.secName == nil) {
                        s.sectorName = [infoRow objectAtIndex:tSectorNameIndex];
                        s.secName = [infoRow objectAtIndex:tSecNameIndex];
                        s.notes = [infoRow objectAtIndex:tNotesIndex];
                        s.buy = [[infoRow objectAtIndex:tAuctionTypeIndex] hasPrefix:@"B"];
                    }
                    NSString *status = [infoRow objectAtIndex:tTradingStatusIndex];
                    switch ([status characterAtIndex:0]) {
                        case 'O':
                            s.tradingStatus = tsOpening;
                            break;
                        case 'C':
                            s.tradingStatus = tsCanceled;
                            break;
                        case 'F':
                            s.tradingStatus = tsClosing;
                            break;
                        case 'B':
                            s.tradingStatus = tsBreak;
                            break;
                        case 'T':
                            s.tradingStatus = tsTrading;
                            break;
                        default:
                            s.tradingStatus = tsNA;
                            break;
                    }
                }
            }
            @catch (NSException *exception) {
                NSLog(@"^^^^^^^^^SECINFOS: %@", secInfos);
            }
        }
        if ((times) || (secInfos))
            [self addUnparsedLists];
        return;
    }
    if (self.tickerList)
        if (self.secInfoLists)
            if (self.tradeTimeLists)
                [self buildMiniSessionsTable];
}

- (void) buildMiniSessionsTable {
    NSDictionary *tickers = tickerList;
    NSArray *columns = [tickers valueForKey:@"columns"];
    NSUInteger stindex = [columns indexOfObject:@"TICKER"];
    NSUInteger scindex = [columns indexOfObject:@"CAPTION"];

    NSDictionary *times = [self extractTimes];
    columns = [times valueForKey:@"columns"];
    NSUInteger tTickerIndex = [columns indexOfObject:@"TICKER"];
    NSUInteger tTimeIndex = [columns indexOfObject:@"TIME"];
    NSUInteger tInstrIndex = [columns indexOfObject:@"INSTRID"];
    NSUInteger tTypeIndex = [columns indexOfObject:@"TYPE"];
    NSUInteger tStatusIndex = [columns indexOfObject:@"STATUS"];
    
    NSArray *tickerRows = [tickers valueForKey:@"data"];
    NSArray *timesRows = [times valueForKey:@"data"];
    NSMutableDictionary *res = [[NSMutableDictionary alloc] init];
    for (NSArray *tickerRow in tickerRows) {
        GIMinisession *s = [[GIMinisession alloc] initWithLongId:[tickerRow objectAtIndex:stindex] Caption:[tickerRow objectAtIndex:scindex]];
        for (NSArray *timeRow in timesRows)
            if ([[timeRow objectAtIndex:tTickerIndex] isEqualToString:s.shortId]) {
                if (s.instrid == nil)
                    s.instrid = [timeRow objectAtIndex:tInstrIndex];
                [s setEvent:[timeRow objectAtIndex:tTypeIndex] EventStatus:[timeRow objectAtIndex:tStatusIndex] AtTime:[timeRow objectAtIndex:tTimeIndex]];
            }
        //[s importTimeTable:t];
        [res setValue:s forKey:s.longId];
    }
    self.minisessions = res;
    self.minisessionsWasBuilt = YES;
    [self addUnparsedLists];
}

- (BOOL) enoughTimeData:(NSDictionary *)timeData {
    // like
    //                2012-12-03 15:56:35.205 GITest[13921:16e03] TESYSTIME: {
    //                    columns =     (
    //                                   DATE,
    //                                   TIME
    //                                   );
    //                    data =     (
    //                                (
    //                                 "2012-12-03",
    //                                 "15:56:29"
    //                                 )
    //                                );
    //                    properties =     {
    //                        seqnum = 0;
    //                        type = snapshot;
    //                    };

    NSArray *columns = [timeData valueForKey:@"columns"];
    NSArray *data = [timeData valueForKey:@"data"];
    data = [data lastObject];
    NSUInteger timeIndex = [columns indexOfObject:@"TIME"];
    //NSUInteger dateIndex = [columns indexOfObject:@"DATE"];
    NSString *timeValue = [data objectAtIndex:timeIndex];
    //NSString *dateValue = [data objectAtIndex:dateIndex];

    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    //dateFormatter.dateFormat = @"YYYY-MM-DDHH:mm:ss";
    dateFormatter.dateFormat = @"HH:mm:ss";
    dateFormatter.defaultDate = [NSDate date];
    NSDate *d = [dateFormatter dateFromString:timeValue];//[NSString stringWithFormat:@"%@%@", dateValue, timeValue, nil]];
    timeDelta[timeDeltaCount++] = [d timeIntervalSinceReferenceDate] - CFAbsoluteTimeGetCurrent();
    if (timeDeltaCount > 4) {
        CFTimeInterval t = timeDelta[--timeDeltaCount];
        while (timeDeltaCount)
            t += timeDelta[--timeDeltaCount];
        setMedvedevDelta(t / 5);
        return YES;
    }
    return NO;
}

- (void) gotFrame:(StompFrame *)f {
    __block GIClient *this = self;
    if (self.substate < 4) self.substate = self.substate + 1;
    switch (f.command) {
        case scCONNECTED: {
            self.state = csConnected;
#warning parse out account data in f.jsonString
            [self.channel scheduleSubscriptionRequest:@"syslog" Param:nil Success:^(StompFrame *f) {
                NSLog(@"SYSLOG MESSAGE: %@", f.message);
                NSLog(@"SYSLOG MESSAGE: %@", f.jsonData);
            } Failure:^(NSString *errorMessage) {
                [this disconnectWithMessage:[NSString stringWithFormat:kStatusMessage09, errorMessage, nil]];
            }];
            [self.channel.writer sendGetTickers:kDefaultSubscriptionParam];
            [self.channel scheduleSubscriptionRequest:@"tradetime" Param:kDefaultSubscriptionParam Success:^(StompFrame *f) {
                if (this.tradeTimeLists)
                    this.tradeTimeLists = @[this.tradeTimeLists, f.jsonData];
                else
                    this.tradeTimeLists = @[f.jsonData];
                [this addUnparsedLists];
            } Failure:^(NSString *errorMessage) {
                [this disconnectWithMessage:[NSString stringWithFormat:kStatusMessage08, errorMessage, nil]];
            }];//[NSString stringWithFormat:@"ticker='%@'", @"MXZERNO.GSEL.LOT121025101" /*@"MXZERNO.GSEL.LOT121025010"*/, nil]];
            [self.channel scheduleSubscriptionRequest:@"minisessions" Param:kDefaultSubscriptionParam Success:^(StompFrame *f) {
                if (this.secInfoLists)
                    this.secInfoLists = @[this.secInfoLists, f.jsonData];
                else
                    if (f.jsonData)
                        this.secInfoLists = @[f.jsonData];
                    else {
                        NSLog(@"Minisession loading problem.");
                    }
                [this addUnparsedLists];
            } Failure:^(NSString *errorMessage) {
                [this disconnectWithMessage:[NSString stringWithFormat:kStatusMessage06, errorMessage, nil]];
            }];
            [self.channel scheduleSubscriptionRequest:@"systime" Param:kDefaultSubscriptionParam Success:^(StompFrame *f) {
                if ([this enoughTimeData:f.jsonData])
                    [this.channel unsubscribe:@"systime" Param:@"marketplace=MXZERNO"];
            } Failure:^(NSString *errorMessage) {
                [this disconnectWithMessage:[NSString stringWithFormat:kStatusMessage07, errorMessage, nil]];
            }];
            break;
        }
        case scREPLY:
            if ([f.destination isEqualToString:@"list"]) { // tickers
                this.tickerList = f.jsonData;
                [this addUnparsedLists];
            } else {
                NSLog(@"OTHER REPLY: %@", f.jsonData);
            }
            break;
        case scCLOSED:
            //[self.channel disconnectCSP];
            self.state = csDisconnected;
            NSLog(@"BANG!");
            break;
        default:
            break;
    }
}

/*- (void) requestCompleted:(NSString *)table Param:(NSString *)param Data:(NSString *)data {
    NSLog(@"rq done.");
}*/

- (void) connectionLost {
    self.lastStatusMessage = kStatusMessage05;
    self.state = csDisconnectedWithProblem;
}

- (void) setState:(GIClientState)astate {
    if (state == astate) return;
    state = astate;
    self.substate = 0;
    //[self didChangeValueForKey:kKeyState];
}

@end
