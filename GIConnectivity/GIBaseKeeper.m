//
//  GIBaseKeeper.m
//  GITest
//
//  Created by Itheme on 12/11/12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "GIBaseKeeper.h"

@implementation GIBaseKeeper

@synthesize tableToUse;

- (void) doReloadTable {
    [self.tableToUse reloadData];
}

- (void) beginUpdate {
    
}

- (void) endUpdate {
    [self performSelectorOnMainThread:@selector(doReloadTable) withObject:nil waitUntilDone:YES];
}

@end


@implementation NSString (PriceFormatting)

+ (NSString *) stringWithPrice:(id) price {
    NSString *f = [NSString stringWithFormat:@"%%.%df", [price[1] intValue], nil];
    return [NSString stringWithFormat:f, [price[0] doubleValue], nil];
}

@end

