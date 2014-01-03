//
//  GIOrderQueueKeeper.m
//  GITest
//
//  Created by Itheme on 12/6/12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "GIOrderQueueKeeper.h"
#import "GIOrderQueueCell.h"

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

//@synthesize targetOrders, sortedOrderNos;

- (id) initForBuy:(BOOL) buying {
    self = [super init];
    if (self) {
        buy = buying;
        ocapacity = 10;
        ocount = 0;
        int bytes = ocapacity*sizeof(OQRecord);
        order = malloc(bytes);
        
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

- (void) endUpdate {
    for (int i = ocount; i--; ) {
        int maxj = i;
        for (int j = i; j-- > 0; ) {
            float delta = order[maxj].price - order[j].price;
            if ((delta > 0.00001) || ((delta > -0.00001) && (order[maxj].mqty < order[j].decimals)))
            //if (order[j].price < order[maxj].price)
                maxj = j;
        }
        if (maxj != i) {
            OQRecord r = order[i];
            order[i] = order[maxj];
            order[maxj] = r;
        }
    }
    [super endUpdate];
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
    GIOrderQueueCell *res = [tableView dequeueReusableCellWithIdentifier:@"order"];//[NSString stringWithFormat:@"order%d", indexPath.row, nil]];
    /*if (res == nil) {
        res = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[NSString stringWithFormat:@"order%d", indexPath.row, nil]];
    }*/
    int i = indexPath.row;
    [res setupWith:&(order[i])];
    //[res.textLabel setText:[NSString stringWithFormat:@"%d: %f %d %d", order[i].orderNo, order[i].price, order[i].qty, order[i].mqty, nil]];
    return res;
}

// UITableViewDelegate methods

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSArray * nibViews = [[NSBundle mainBundle] loadNibNamed:@"GIOrderQueueHeadeView" owner:self options:nil];
    return [nibViews objectAtIndex:0];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 32;
}


@end
