//
//  GIWonOrdersKeeper.m
//  GITest
//
//  Created by Itheme on 12/11/12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "GIWonOrdersKeeper.h"
#import "GIOrderQueueCell.h"

@interface GIWonOrdersKeeper ()

@property (nonatomic, retain) NSMutableDictionary *records;
@property (nonatomic) BOOL loaded;

@end

@implementation GIWonOrdersKeeper

@synthesize records;
@synthesize loaded;

- (id) init {
    self = [super init];
    if (self) {
        self.records = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (BOOL) needsDataForTradeNo:(NSString *) tradeNo {
    id v = [self.records valueForKey:tradeNo];
    return v == nil;
}

- (void) gotDataForTradeNo:(id) tradeNo At:(NSString *)time Price:(id)price Qty:(id)qty Value:(id)value {
    [self.records setValue:@[time, [NSString stringWithPrice:price], qty, [NSString stringWithPrice:value]] forKey:tradeNo];
}

- (void) endUpdate {
    [super endUpdate];
    if ([self.records count] > 0) self.loaded = YES;
}

// UITableViewDataSource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0)
        return [self.records count];
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    GIOrderQueueCell *res = [tableView dequeueReusableCellWithIdentifier:@"wonorder"];//[NSString stringWithFormat:@"order%d", indexPath.row, nil]];
#warning temporary class. Should be separate class
    /*if (res == nil) {
     res = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[NSString stringWithFormat:@"order%d", indexPath.row, nil]];
     }*/
    int i = indexPath.row;
    [res setupAsTrade:[self.records allValues][i]];
    //[res.textLabel setText:[NSString stringWithFormat:@"%d: %f %d %d", order[i].orderNo, order[i].price, order[i].qty, order[i].mqty, nil]];
    return res;
}

// UITableViewDelegate methods

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSArray * nibViews = [[NSBundle mainBundle] loadNibNamed:@"GIOrderQueueHeadeView" owner:self options:nil];
#warning temporary nib.
    return [nibViews objectAtIndex:0];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 32;
}

@end
