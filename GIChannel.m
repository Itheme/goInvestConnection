//
//  GIChannel.m
//  GITest
//
//  Created by Mackey on 19.11.12.
//  Copyright (c) 2012 Mackey. All rights reserved.
//

#import "GIChannel.h"

#import "AFURLConnectionOperation.h"
#import "AFJSONRequestOperation.h"

@interface GIChannel () {
    
}

@property (nonatomic) GIChannelStatus *status;

@end

@implementation GIChannel {
    
}

@synthesize status, targetURL, closed;

- (id) initWithURL:(NSURL *)URL Options:(id)optionsProvider {
    self = [super init];
    if (self) {
        targetURL = URL;
    }
    return self;
}

- (BOOL) getClosed {
    return self.status == NULL;
}

- (void) connect {
    status = nil;
    NSURL *url = [NSURL URLWithString:@"connect" relativeToURL:targetURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        self.status = [[GIChannelStatus alloc] initWithResponse:response];
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
        self.status = NULL;
    }];
    [operation start];
}

- (void) ping {
    if (self.closed) return;
    AFURLConnectionOperation
}
                                        
                                         - (void) disconnect {
                                             `8788888
                                         }
@end

