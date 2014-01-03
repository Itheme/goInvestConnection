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

@interface GIEngineClient ()

@property (nonatomic, retain) GIOrderQueueKeeper *orders;

@end

@implementation GIEngineClient

@synthesize target, targetSubscriber, orders;

- (void) gotProblemsWithOQ:(NSString *)errorMessage {
#warning undone
}

- (void) setTarget:(GIMinisession *)t {
    if (target) {
        if ([target isEqual:t]) return;
        [self.channel unsubscribe:@"orderqueue" Param:[target subscriptionParams]];
    }
    target = t;
    if (t) {
        self.orders = [[GIOrderQueueKeeper alloc] init];
        __block GIEngineClient *this = self;
        [self.channel scheduleSubscriptionRequest:@"orderqueue" Param:[t subscriptionParams] Success:^(StompFrame *f) {
            NSArray *columns = [f.jsonData valueForKey:@"columns"];
            NSUInteger orderNoIndex = [columns indexOfObject:@"ORDERNO"];
            NSUInteger orderStatusIndex = [columns indexOfObject:@"ORDERSTATUS"];
            NSUInteger priceIndex = [columns indexOfObject:@"PRICE"];
            NSUInteger qtyIndex = [columns indexOfObject:@"QUANTITY"];
            NSUInteger matchingQtyIndex = [columns indexOfObject:@"MATCHINGQTY"];
            NSArray *data = [f.jsonData valueForKey:@"data"];
            [this.orders beginUpdate];
            for (NSArray *row in data) {
                NSString *v = [row objectAtIndex:orderStatusIndex];
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
                int qty = [[row objectAtIndex:qtyIndex] intValue];
                int mqty = [[row objectAtIndex:matchingQtyIndex] intValue];
                [this.orders gotDataForOrderNo:[[row objectAtIndex:orderNoIndex] intValue] Status:stat Price:[row objectAtIndex:priceIndex] Qty:qty MatchingQty:mqty];
            }
            [this.orders endUpdate];
            //NSLog(@"OQOQOQOQOQOQOQOQOQOQOQOQ %@", f.jsonData);
        } Failure:^(NSString *errorMessage) {
            [this gotProblemsWithOQ:errorMessage];
        }];
    }
}

+ (GIEngineClient *) sharedClient {
    GIAppDelegate *d = [UIApplication sharedApplication].delegate;
    return d.client;
}

+ (GIEngineClient *) setupSharedClient {
    GIAppDelegate *d = [UIApplication sharedApplication].delegate;
   //d.client = [[GIEngineClient alloc] initWithUser:@"MXZERNO.D001701B" Pwd:@""];
    d.client = [[GIEngineClient alloc] initWithUser:@"MXZERNO.D0006013" Pwd:@""];
    return d.client;
}

- (void) setupOQDelegatesFor:(UITableView *)table {
    if (table) {
        table.dataSource = self.orders;
        table.delegate = self.orders;
    } else {
        if (self.orders.tableToUse) {
            self.orders.tableToUse.delegate = nil;
            self.orders.tableToUse.dataSource = nil;
        }
    }
    self.orders.tableToUse = table;
}

@end
