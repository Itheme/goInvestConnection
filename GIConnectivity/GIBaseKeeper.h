//
//  GIBaseKeeper.h
//  GITest
//
//  Created by Itheme on 12/11/12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (PriceFormatting)

+ (NSString *) stringWithPrice:(id) price;

@end

@interface GIBaseKeeper : NSObject

@property (nonatomic, retain) UITableView *tableToUse;

- (void) beginUpdate;
- (void) endUpdate;

@end
