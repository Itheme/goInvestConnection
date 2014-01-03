//
//  GIOrderQueueKeeper.m
//  GITest
//
//  Created by Itheme on 12/6/12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "GIOrderQueueKeeper.h"

typedef struct OQRecordStruct {
    int orderNo;
    double price;
    int decimals;
    int qty;
    int mqty;
} OQRecord, *OQRecordPtr;

@interface GIOrderQueueKeeper () {
    BOOL buy;
    int ocapacity, ocount;
    OQRecordPtr order;
    bool tableReloadingIsScheduled;
}

//@property (nonatomic, retain) NSMutableDictionary *targetOrders;
//@property (nonatomic, retain) NSMutableArray *sortedOrderNos;

@end

@implementation GIOrderQueueKeeper

@synthesize tableToUse;
//@synthesize targetOrders, sortedOrderNos;

- (id) initForBuy:(BOOL) buying {
    self = [super init];
    if (self) {
        buy = buying;
        ocapacity = 10;
        ocount = 0;
        order = malloc(ocapacity*sizeof(OQRecord));
        
        //self.targetOrders = [[NSMutableDictionary alloc] init];
        //self.sortedOrderNos = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) dealloc {
    free(order);
}

- (void) gotDataForOrderNo:(int) orderNo Status:(QOrderStatus) status Price:(id)price Qty:(int)qty MatchingQty:(int)matchingQty {
    /*if (status == qoActive) {
        NSMutableDictionary *d = [targetOrders valueForKey:orderNo];
        if (d) {
            [d setValue:price forKey:@"price"];
            [d setValue:qty forKey:@"qty"];
            [d setValue:matchingQty forKey:@"mqty"];
        } else {
            d = [@{@"price" : price, @"qty" : qty, @"mqty" : matchingQty} mutableCopy];
            [targetOrders setValue:d forKey:orderNo];
        }
    } else
        [targetOrders setValue:nil forKey:orderNo];*/
    if (status == qoActive) {
        for (int i = ocount; i--; )
            if (order[i].orderNo == orderNo) {
                order[i].qty = qty; // price won't change
                order[i].mqty = matchingQty;
                return;
            }
        if (ocount == ocapacity) {
            ocapacity *= 2;
            OQRecordPtr xorder = malloc(ocapacity*sizeof(OQRecord));
            memcpy(xorder, order, ocount * sizeof(OQRecord));
            free(order);
            order = xorder;
        }
        order[ocount].orderNo = orderNo;
        order[ocount].qty = qty;
        order[ocount].mqty = matchingQty;
        order[ocount].price = [[price objectAtIndex:0] floatValue];
        order[ocount].decimals = [[price objectAtIndex:1] intValue];
        ocount++;
        //[sortedOrderNos addObject:[NSNumber numberWithInt:orderNo]];
    } else
        for (int i = ocount; i--; )
            if (order[i].orderNo == orderNo) {
                memcpy(&(order[i]), &(order[--ocount]), sizeof(OQRecord));
                //[sortedOrderNos removeObjectIdenticalTo:[NSNumber numberWithInt:orderNo]];
                return;
            }
}

- (void) beginUpdate {
}

- (void) doReloadTable {
    [self.tableToUse reloadData];
    tableReloadingIsScheduled = false;
}

- (void) tableNeedsReloading {
    if (tableReloadingIsScheduled) return;
    tableReloadingIsScheduled = true;
    [self performSelector:@selector(doReloadTable) withObject:nil afterDelay:0.2];
}

- (void) endUpdate {
    for (int i = ocount; i--; ) {
        int maxj = i;
        for (int j = i; j-- > 0; )
            if (order[j].price > order[maxj].price)
                maxj = j;
        if (maxj != i) {
            OQRecord r = order[i];
            order[i] = order[maxj];
            order[maxj] = r;
        }
    }
    [self tableNeedsReloading];
    /*NSMutableArray *a = [[self.targetOrders allKeys] mutableCopy];
    if (buy)
    [a sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSMutableDictionary *d1 = [targetOrders valueForKey:obj1];
        NSMutableDictionary *d2 = [targetOrders valueForKey:obj2];
        
    }];*/
}

// UITableViewDataSource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0)
        return ocount;
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *res = [tableView dequeueReusableCellWithIdentifier:@"order"];
    if (res == nil) {
        res = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"order"];
    }
    int i = indexPath.row;
    [res.textLabel setText:[NSString stringWithFormat:@"%d: %f %d %d", order[i].orderNo, order[i].price, order[i].qty, order[i].mqty, nil]];
    return res;
}

// UITableViewDelegate methods

@end
