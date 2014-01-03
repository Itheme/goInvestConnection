//
//  GIMinisession.h
//  GITest
//
//  Created by Mackey on 26.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GIMinisession : NSObject

@property (nonatomic, retain) NSString *longId;
@property (nonatomic, retain) NSString *shortId;
@property (nonatomic, retain) NSString *caption;
@property (nonatomic, retain) NSString *instrid;
@property (nonatomic, retain) NSMutableDictionary *times;

@end
