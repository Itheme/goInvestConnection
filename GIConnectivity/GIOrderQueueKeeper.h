//
//  GIOrderQueueKeeper.h
//  GITest
//
//  Created by Itheme on 12/6/12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum QOrderStatusEnum {
    qoActive = 0,
    qoMatched = 1,
    qoWithdrawn = 2,
    qoCPRejected = 3,
    qoTERejected = 4,
    qoTECancel = 5
} QOrderStatus;

@interface GIOrderQueueKeeper : NSObject <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, retain) UITableView *tableToUse;

- (void) gotDataForOrderNo:(int) orderNo Status:(QOrderStatus) status Price:(id)price Qty:(int)qty MatchingQty:(int)matchingQty;
- (void) beginUpdate;
- (void) endUpdate;

- (id) initForBuy:(BOOL) buying;

@end
