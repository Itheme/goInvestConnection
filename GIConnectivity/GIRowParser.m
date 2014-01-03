//
//  GIRowParser.m
//  GITest
//
//  Created by Itheme on 12/14/12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "GIRowParser.h"

@interface GIRowParser () {
    NSUInteger colIndexes[10];
    int colNum;
}

@end

@implementation GIRowParser

@synthesize rows;

- (id) initWithDictionary:(NSDictionary *)d ColumnNames:(NSArray *) cols {
    NSArray *columns = [d valueForKey:@"columns"];
    NSArray *rowsData = [d valueForKey:@"data"];
    if (columns && rowsData) {
        self = [super init];
        if (self) {
            for (NSString *columnName in cols)
                if ((colIndexes[colNum++] = [columns indexOfObject:columnName]) == NSNotFound) {
                    NSLog(@"OH GOSH! no %@ in table %@", columnName, d);
                    return nil;
                }
            self.rows = rowsData;
        }
        return self;
    }
    return nil;
}

- (void) enumRowsUsingBlock2:(RowEnum2) block {
    for (NSArray *row in self.rows)
        block([row objectAtIndex:colIndexes[0]], [row objectAtIndex:colIndexes[1]]);
}

- (void) enumRowsUsingBlock5:(RowEnum5) block {
    for (NSArray *row in self.rows)
        block([row objectAtIndex:colIndexes[0]], [row objectAtIndex:colIndexes[1]], [row objectAtIndex:colIndexes[2]], [row objectAtIndex:colIndexes[3]], [row objectAtIndex:colIndexes[4]]);
}

@end
