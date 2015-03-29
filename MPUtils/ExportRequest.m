//
//  ExportRequest.m
//  MPUtils
//
//  Created by Jared McFarland on 3/28/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import "ExportRequest.h"
#import "MPUConstants.h"
#import "NSString+Hashes.h"

@interface ExportRequest ()

@property (strong, nonatomic) NSString *apiKey;
@property (strong, nonatomic) NSString *apiSecret;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;

@end

@implementation ExportRequest

+ (instancetype)requestWithAPIKey:(NSString *)apiKey secret:(NSString *)secret
{
    ExportRequest *exportRequest = [[ExportRequest alloc] init];
    exportRequest.apiKey = apiKey;
    exportRequest.apiSecret = secret;
    return exportRequest;
}

- (NSDateFormatter *)dateFormatter
{
    if (!_dateFormatter) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"YYYY-MM-dd"];
    }
    return _dateFormatter;
}

- (NSString *)expire
{
    return [NSString stringWithFormat:@"%li", (long)[[NSDate date] timeIntervalSince1970] + 600];
}

- (NSString *)signatureForParams:(NSMutableDictionary *)URLParams
{
    if (URLParams[@"sig"]) {
        [URLParams removeObjectForKey:@"sig"];
    }
    NSArray *alphabeticalKeys = [URLParams.allKeys sortedArrayUsingSelector:@selector(compare:)];

    NSString *hashString = [NSString string];
    for (NSString *key in alphabeticalKeys) {
        hashString = [hashString stringByAppendingString:[NSString stringWithFormat:@"%@=%@",key,URLParams[key]]];
    }
    hashString = [hashString stringByAppendingString:self.apiSecret];

    return [hashString md5];
}

- (void)requestWithURL:(NSURL *)baseURL params:(NSDictionary *)URLParams
{
    /* Configure session, choose between:
     * defaultSessionConfiguration
     * ephemeralSessionConfiguration
     * backgroundSessionConfigurationWithIdentifier:
     And set session-wide properties, such as: HTTPAdditionalHeaders,
     HTTPCookieAcceptPolicy, requestCachePolicy or timeoutIntervalForRequest.
     */
    NSURLSessionConfiguration* sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    /* Create session, and optionally set a NSURLSessionDelegate. */
    NSURLSession* session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:nil delegateQueue:nil];
    
    // Update params with API Key, expire and sig
    NSMutableDictionary *params = [URLParams mutableCopy];
    [params setObject:self.apiKey forKey:kMPParameterAPIKey];
    [params setObject:self.expire forKey:kMPParameterExpire];
    NSString *sig = [self signatureForParams:params];
    [params setObject:sig forKey:kMPParameterSig];
    
    /* Create the Request:
     Export (GET https://data.mixpanel.com/api/2.0/export/)
     */
    
    NSURL *URL = NSURLByAppendingQueryParameters(baseURL, params);
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"GET";

    /* Start a new Task */
    NSURLSessionDataTask* task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error == nil) {
            // Success
            NSLog(@"response = %@",data);
            if ([response.URL.absoluteString isEqualToString:kMPURLRawExport])
            {
                [self.delegate eventsResultsHandler:data];
            } else if ([response.URL.absoluteString isEqualToString:kMPURLEngageExport])
            {
                [self.delegate peopleResultsHandler:data];
            } else
            {
                [self.delegate dataResultsHandler:data fromURL:response.URL];
            }
        }
        else {
            // Failure
            NSLog(@"URL Session Task Failed: %@", [error localizedDescription]);
        }
    }];
    [task resume];
    
}

- (void)requestForEvents:(NSArray *)events fromDate:(NSDate *)fromDate toDate:(NSDate *)toDate where:(NSString *)whereClause
{
    
    NSString *fromDateString = [self.dateFormatter stringFromDate:fromDate];
    NSString *toDateString = [self.dateFormatter stringFromDate:toDate];
    
    NSMutableDictionary *URLParams = [NSMutableDictionary dictionaryWithDictionary:@{kMPParameterFromDate:fromDateString,
                                                                                     kMPParameterToDate:toDateString}];
    
    if (events) [URLParams setObject:[self eventsStringFromArray:events] forKey:kMPParameterRawExportEvent];
    if (whereClause && ![whereClause isEqualToString:@""]) [URLParams setObject:whereClause forKey:kMPParameterWhere];
    
    [self requestWithURL:[NSURL URLWithString:kMPURLRawExport] params:URLParams];
}

- (void)requestForPeopleWhere:(NSString *)whereClause sessionID:(NSString *)sessionID page:(NSUInteger)page
{
    NSMutableDictionary *URLParams = [NSMutableDictionary dictionary];
    if (whereClause && ![whereClause isEqualToString:@""]) [URLParams setObject:whereClause forKey:kMPParameterWhere];
    if (sessionID && ![sessionID isEqualToString:@""]) [URLParams setObject:sessionID forKey:kMPParameterEngageSessionID];
    if (page > 0) [URLParams setObject:[NSString stringWithFormat:@"%li", page] forKey:kMPParameterEngagePage];
    
    [self requestWithURL:[NSURL URLWithString:kMPURLEngageExport] params:URLParams];
}

- (void)requestForProfileWithDistinctID:(NSString *)distinctID
{
    [self requestWithURL:[NSURL URLWithString:kMPURLEngageExport] params:@{kMPParameterEngageDistinctID:distinctID}];
}

/*
 * Utils: Add this section before your class implementation
 */

/**
 This creates a new query parameters string from the given NSDictionary. For
 example, if the input is @{@"day":@"Tuesday", @"month":@"January"}, the output
 string will be @"day=Tuesday&month=January".
 @param queryParameters The input dictionary.
 @return The created parameters string.
 */
static NSString* NSStringFromQueryParameters(NSDictionary* queryParameters)
{
    NSMutableArray* parts = [NSMutableArray array];
    [queryParameters enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        NSString *part = [NSString stringWithFormat: @"%@=%@",
                          [key stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding],
                          [value stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]
                          ];
        [parts addObject:part];
    }];
    return [parts componentsJoinedByString: @"&"];
}

/**
 Creates a new URL by adding the given query parameters.
 @param URL The input URL.
 @param queryParameters The query parameter dictionary to add.
 @return A new NSURL.
 */
static NSURL* NSURLByAppendingQueryParameters(NSURL* URL, NSDictionary* queryParameters)
{
    NSString* URLString = [NSString stringWithFormat:@"%@?%@",
                           [URL absoluteString],
                           NSStringFromQueryParameters(queryParameters)
                           ];
    return [NSURL URLWithString:URLString];
}


- (NSString *)eventsStringFromArray:(NSArray *)events
{
    NSString *eventsString = @"[";
    for (NSString *event in events) {
        eventsString = [eventsString stringByAppendingString:[NSString stringWithFormat:@"\"%@\",",event]];
    }
    eventsString = [eventsString substringToIndex:eventsString.length-1];
    eventsString = [eventsString stringByAppendingString:@"]"];
    
    return eventsString;
}


@end
