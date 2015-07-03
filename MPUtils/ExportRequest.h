//
//  ExportRequest.h
//  MPUtils
//
//  Created by Jared McFarland on 3/28/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ExportRequest : NSObject

+ (instancetype)requestWithAPIKey:(NSString *)apiKey secret:(NSString *)secret;
- (void)requestWithURL:(NSURL *)baseURL params:(NSDictionary *)URLParams;
- (void)requestForEvents:(NSArray *)events fromDate:(NSDate *)fromDate toDate:(NSDate *)toDate where:(NSString *)whereClause;
- (void)requestForPeopleWhere:(NSString *)whereClause sessionID:(NSString *)sessionID page:(NSUInteger)page;
- (void)cancel;

@end
