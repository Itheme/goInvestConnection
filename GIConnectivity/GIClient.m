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
    int substate;
}

@property (nonatomic, setter = setState:) GIClientState state;
@property (nonatomic, retain) NSString *login;
@property (nonatomic, retain) NSString *pwd;
@property (nonatomic, retain) NSString *lastStatusMessage;

@property (nonatomic, retain) GIChannel *channel;

// parsing stuff
@property (nonatomic, retain) id tickerList;
@property (nonatomic, retain) id tradeTimeList;

@property (nonatomic, retain) NSDictionary *minisessions;

@end

@implementation GIClient

@synthesize state, login, pwd;
@synthesize channel;
@synthesize lastStatusMessage;

@synthesize tickerList, tradeTimeList, minisessions;

static NSString *kEendPoint = @"https://goinvest.micex.ru";//@"http://172.20.9.167:8080";//@"https://goinvest.micex.ru";

static NSString *kStatusMessage01 = @"Could not download marketplaces!";
static NSString *kStatusMessage02 = @"Could not find MXZERNO in marketplaces!";
static NSString *kStatusMessage03 = @"Channel failed to startup (%@)";
static NSString *kStatusMessage04 = @"Failed to download marketplaces (error: %@, reply: %@)";
static NSString *kStatusMessage05 = @"Connection is lost";
static NSString *kStatusMessage06 = @"";
static NSString *kStatusMessage07 = @"";
static NSString *kStatusMessage08 = @"";
static NSString *kStatusMessage09 = @"";
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
    if ((state == csConnecting) || (substate == 0)) {
        for (NSDictionary *mp in marketPlaces)
            if ([[mp valueForKey:@"id"] isEqualToString:@"MXZERNO"]) {
                self.channel.channelId = [mp valueForKey:@"channel"];
                self.channel.caption = [mp valueForKey:@"caption"];
                NSLog(@"ZERNO is on %@ channel called %@", self.channel.channelId, self.channel.caption);
                if (![self.channel connect:login Password:pwd]) {
                    self.lastStatusMessage = kStatusMessage01;
                    self.state = csDisconnectedWithProblem;
                } else {
                    substate = 1;
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
        substate = 0;
        __block GIClient *this = self;
        NSURL *url = [NSURL URLWithString:@"https://goinvest.micex.ru/statics/marketplaces.json"];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
            NSArray *marketPlaces = [JSON valueForKey:@"marketplaces"];
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
    }
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

- (void) buildMiniSessionsTable {
    NSDictionary *tickers = tickerList;
    NSDictionary *times = tradeTimeList;
    NSArray *columns = [tickers valueForKey:@"columns"];
    NSUInteger stindex = [columns indexOfObject:@"TICKER"];
    NSUInteger scindex = [columns indexOfObject:@"CAPTION"];
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
        NSMutableDictionary *t = [[NSMutableDictionary alloc] init];
        for (NSArray *timeRow in timesRows)
            if ([[timeRow objectAtIndex:tTickerIndex] isEqualToString:s.shortId]) {
                if (s.instrid == nil)
                    s.instrid = [timeRow objectAtIndex:tInstrIndex];
                NSMutableDictionary *xd = [@{@"time" : [timeRow objectAtIndex:tTimeIndex], @"status" : [timeRow objectAtIndex:tStatusIndex]} mutableCopy];
                [t setValue:xd forKey:[timeRow objectAtIndex:tTypeIndex]];
                [s setEvent:[timeRow objectAtIndex:tTypeIndex] EventStatus:[timeRow objectAtIndex:tStatusIndex] AtTime:[timeRow objectAtIndex:tTimeIndex]];
            }
        //[s importTimeTable:t];
        [res setValue:s forKey:s.longId];
    }
    self.minisessions = res;
}

- (void) gotFrame:(StompFrame *)f {
    __block GIClient *this = self;
    switch (f.command) {
        case scCONNECTED: {
            self.state = csConnected;
#warning parse out account data in f.jsonString
            [self.channel.writer sendGetTickers:@"marketplace=MXZERNO"];
            //[self.channel scheduleSubscriptionRequest:@"lasttrades" Param:[NSString stringWithFormat:@"ticker='%@'", @"MXZERNO.GSEL.LOT121025010", nil]];
            [self.channel scheduleSubscriptionRequest:@"tradetime" Param:@"marketplace=MXZERNO" Success:^(StompFrame *f) {
                this.tradeTimeList = f.jsonData;
                [this.channel unsubscribe:@"tradetime" Param:@"marketplace=MXZERNO"];
                if (this.tickerList)
                    [this buildMiniSessionsTable];
            } Failure:^(NSString *errorMessage) {
                NSLog(@"Failure block 2");
            }];//[NSString stringWithFormat:@"ticker='%@'", @"MXZERNO.GSEL.LOT121025101" /*@"MXZERNO.GSEL.LOT121025010"*/, nil]];
            [self.channel scheduleSubscriptionRequest:@"tesystime" Param:@"marketplace=MXZERNO" Success:^(StompFrame *f) {
                //this.tradeTimeList = f.jsonData;
                //[this.channel unsubscribe:@"tradetime" Param:@"marketplace=MXZERNO"];
                //if (this.tickerList)
                    //[this buildMiniSessionsTable];
#warning Parse time here:
                
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
                [this.channel unsubscribe:@"tesystime" Param:@"marketplace=MXZERNO"];
            } Failure:^(NSString *errorMessage) {
                NSLog(@"Failure block 3");
            }];//[NSString stringWithFormat:@"ticker='%@'", @"MXZERNO.GSEL.LOT121025101" /*@"MXZERNO.GSEL.LOT121025010"*/, nil]];
            break;
        }
        case scREPLY:
            if ([f.destination isEqualToString:@"list"]) { // tickers
                this.tickerList = f.jsonData;
                if (this.tradeTimeList)
                    [this buildMiniSessionsTable];
            }
            break;
        case scCLOSED:
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
    substate = 0;
    //[self didChangeValueForKey:kKeyState];
}

@end
