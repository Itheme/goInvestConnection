//
//  GIWonOrdersKeeper.h
//  GITest
//
//  Created by Itheme on 12/11/12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GIBaseKeeper.h"

@interface GIWonOrdersKeeper : GIBaseKeeper <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, readonly) BOOL loaded;

- (void) gotDataForTradeNo:(id) tradeNo At:(NSString *)time Price:(id)price Qty:(id)qty Value:(id)value ;
- (BOOL) needsDataForTradeNo:(NSString *) tradeNo;

@end
