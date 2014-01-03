//
//  GIEngineClient.m
//  GITest
//
//  Created by Mackey on 27.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "GIEngineClient.h"
#import "GIAppDelegate.h"
#import "GIOrderQueueKeeper.h"
#import "GIOrderQueueCell.h"
#import "GIWonOrdersKeeper.h"
#import "GIRowParser.h"

@interface GIEngineClient ()

@property (nonatomic, retain) GIOrderQueueKeeper *xorders;
@property (nonatomic, retain) GIWonOrdersKeeper *xwonOrders;
@property (nonatomic, retain, setter = setTarget:) GIMinisession *target;
@property (nonatomic, retain) UITableView *currentTable;

@end

@implementation GIEngineClient

@synthesize target, targetSubscriber, xorders, xwonOrders;
@synthesize currentTable;

- (void) gotProblemsWithOQ:(NSString *)errorMessage {
#warning undone
}

- (void) setTarget:(GIMinisession *)t {
    if (target) {
        if ([target isEqual:t]) return;
        [self.channel unsubscribe:@"orderqueue" Param:[target subscriptionParams]];
        [self.channel unsubscribe:@"lasttrades" Param:[target subscriptionParams]];
        [target dropTableConnection];
    }
    target = t;
    if (t == nil) return;
    __block GIEngineClient *this = self;
    if (t.status == msRunning) {
        self.xorders = [t setupOrderQueueKeeper:YES Table:self.currentTable];
        #warning AUCTION TYPE HERE!
        [self.channel scheduleSubscriptionRequest:@"orderqueue" Param:[t subscriptionParams] Success:^(StompFrame *f) {
            GIRowParser *oqParser = [[GIRowParser alloc] initWithDictionary:f.jsonData ColumnNames:@[@"ORDERNO", @"ORDERSTATUS", @"PRICE", @"QUANTITY", @"MATCHINGQTY"]];
            [this.xorders beginUpdate];
            [oqParser enumRowsUsingBlock5:^(id orderNo, id orderStatus, id price, id qtyV, id mqtyV) {
                NSString *v = orderStatus;
                unichar c = [v characterAtIndex:0];
                QOrderStatus stat;
                switch (c) {
                    case 'M':
                        stat = qoMatched;
                        break;
                    case 'W':
                        stat = qoWithdrawn;
                        break;
                    case 'F':
                        stat = qoCPRejected;
                        break;
                    case 'R':
                        stat = qoTERejected;
                        break;
                    case 'C':
                        stat = qoTECancel;
                        break;
                    default:
                        stat = qoActive;
                        break;
                }
                int qty = [qtyV intValue];
                int mqty = [mqtyV intValue];
                [this.xorders gotDataForOrderNo:[orderNo intValue] Status:stat Price:price Qty:qty MatchingQty:mqty];
            }];
            [this.xorders endUpdate];
            //NSLog(@"OQOQOQOQOQOQOQOQOQOQOQOQ %@", f.jsonData);
        } Failure:^(NSString *errorMessage) {
            [this gotProblemsWithOQ:errorMessage];
        }];
        self.xwonOrders = nil;
    } else {
        if ((t.status == msEnded) || (t.status == msUnknown)) {
            self.xwonOrders = [t setupWonOrdersKeeperFor:self.currentTable];
            if (!self.xwonOrders.loaded)
                [self.channel scheduleSubscriptionRequest:@"lasttrades" Param:[t subscriptionParams] Success:^(StompFrame *f) {
                    GIRowParser *wonOrdersParser = [[GIRowParser alloc] initWithDictionary:f.jsonData ColumnNames:@[@"TRADENO", @"TRADETIME", @"PRICE", @"QUANTITY", @"VALUE"]];

                    [this.xwonOrders beginUpdate];
                    [wonOrdersParser enumRowsUsingBlock5:^(id tradeNo, id tradeTime, id price, id qty, id value) {
                        if ([this.xwonOrders needsDataForTradeNo:[NSString stringWithFormat:@"%@", tradeNo, nil]])
                            [this.xwonOrders gotDataForTradeNo:tradeNo At:tradeTime Price:price Qty:qty Value:value];
                    }];
                    [this.xwonOrders endUpdate];

                } Failure:^(NSString *errorMessage) {
                    [this gotProblemsWithOQ:errorMessage];
                }];
            else
                [this.xwonOrders endUpdate];
            self.xorders = nil;
        } else {
            self.xorders = nil;
            self.xwonOrders = nil;
        }
    }
}

+ (GIEngineClient *) sharedClient {
    GIAppDelegate *d = [UIApplication sharedApplication].delegate;
    return d.client;
}

+ (GIEngineClient *) setupSharedClient {
    GIAppDelegate *d = [UIApplication sharedApplication].delegate;
   //d.client = [[GIEngineClient alloc] initWithUser:@"MXZERNO.D001701B" Pwd:@""];
    d.client = [[GIEngineClient alloc] initWithUser:/**@"MXZERNO.D0006013"/**/@"MXZERNO.D0002016"/**/ Pwd:@""];
    return d.client;
}

- (void) setupOQDelegatesFor:(UITableView *)table session:(GIMinisession *)s {
    if (table) {
        [table registerClass:[GIOrderQueueCell class] forCellReuseIdentifier:@"order"];
        [table registerNib:[UINib nibWithNibName:@"GIOrderQueueCelliPad" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:@"order"];
        [table registerClass:[GIOrderQueueCell class] forCellReuseIdentifier:@"wonorder"];
        [table registerNib:[UINib nibWithNibName:@"GIOrderQueueCelliPad" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:@"wonorder"];
    }
    self.currentTable = table;
    self.target = s;
}

@end
