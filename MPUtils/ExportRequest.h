//
//  ExportRequest.h
//  MPUtils
//
//  Created by Jared McFarland on 3/28/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ExportRequestProtocol <NSObject>

- (void)eventsResultsHandler:(NSData *)data;
- (void)peopleResultsHandler:(NSData *)data;
- (void)dataResultsHandler:(NSData *)data fromURL:(NSURL *)URL;

@end

@interface ExportRequest : NSObject

@property (weak) id<ExportRequestProtocol> delegate;

+ (instancetype)requestWithAPIKey:(NSString *)apiKey secret:(NSString *)secret;
- (void)requestWithURL:(NSURL *)baseURL params:(NSDictionary *)URLParams;
- (void)requestForEvents:(NSArray *)events fromDate:(NSDate *)fromDate toDate:(NSDate *)toDate where:(NSString *)whereClause;

@end
