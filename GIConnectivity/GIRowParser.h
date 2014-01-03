//
//  GIRowParser.h
//  GITest
//
//  Created by Itheme on 12/14/12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^RowEnum2)(id v0, id v1);
typedef void(^RowEnum5)(id v0, id v1, id v2, id v3, id v4);

@interface GIRowParser : NSObject // NSEnumerator

@property (nonatomic, retain) NSArray *rows;

- (id) initWithDictionary:(NSDictionary *)d ColumnNames:(NSArray *) cols;
- (void) enumRowsUsingBlock2:(RowEnum2) block;
- (void) enumRowsUsingBlock5:(RowEnum5) block;


@end
