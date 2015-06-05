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
#import "AppDelegate.h"
#import <YapDatabase/YapDatabase.h>
#import <SBJson/SBJson4.h>

@interface ExportRequest () <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

@property (strong, nonatomic) NSString *apiKey;
@property (strong, nonatomic) NSString *apiSecret;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@property (strong, nonatomic) NSNumber *totalProfiles;
@property (strong, nonatomic) NSString *whereClause;
@property (nonatomic) dispatch_queue_t downloadQueue;
@property (strong, nonatomic) NSMutableArray *events;
@property (strong, nonatomic) SBJson4Parser *jsonParser;
@property (strong, nonatomic) NSString *requestType;
@property (nonatomic) NSUInteger batchIndex;
@property (nonatomic) NSUInteger eventCount;
@property (strong, nonatomic) dispatch_queue_t propQueue;
@property (strong, nonatomic) NSMutableSet *propertyKeys;
@property (strong, nonatomic) NSMutableSet *transactionKeys;

@end

@implementation ExportRequest

#pragma mark - Lazy Properties

- (NSMutableSet *)propertyKeys
{
    if (!_propertyKeys)
    {
        _propertyKeys = [NSMutableSet set];
    }
    return _propertyKeys;
}

- (dispatch_queue_t)propQueue
{
    if (!_propQueue)
    {
        _propQueue = dispatch_queue_create("propertyThread", NULL);
    }
    
    return _propQueue;
}

- (NSUInteger)eventCount
{
    if (!_eventCount)
    {
        _eventCount = 0;
    }
    return _eventCount;
}

- (NSUInteger)batchIndex
{
    if (!_batchIndex)
    {
        _batchIndex = 0;
    }
    return _batchIndex;
}

- (NSString *)requestType
{
    if (!_requestType)
    {
        _requestType = [NSString string];
    }
    return _requestType;
}

- (NSMutableArray *)events
{
    if (!_events)
    {
        _events = [NSMutableArray array];
    }
    return _events;
}

- (SBJson4Parser *)jsonParser
{
    if (!_jsonParser)
    {
        _jsonParser = [SBJson4Parser multiRootParserWithBlock:^(id item, BOOL *stop) {
            [self.events addObject:item];
        } errorHandler:^(NSError *error) {
            [self updateStatusWithString:[NSString stringWithFormat:@"SBJson4Parser error: %@", error.localizedDescription]];
        }];
    }
    return _jsonParser;
}

- (NSNumber *)totalProfiles
{
    if (!_totalProfiles)
    {
        _totalProfiles = [NSNumber numberWithInt:0];
    }
    return _totalProfiles;
}

- (dispatch_queue_t)downloadQueue
{
    if (!_downloadQueue)
    {
        _downloadQueue = dispatch_queue_create("download", NULL);
    }
    return _downloadQueue;
}

-(NSString *)whereClause
{
    if (!_whereClause)
    {
        _whereClause = [NSString stringWithFormat:@""];
    }
    return _whereClause;
}

- (NSDateFormatter *)dateFormatter
{
    if (!_dateFormatter) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"YYYY-MM-dd"];
    }
    return _dateFormatter;
}


#pragma mark - Convenience Initializer

+ (instancetype)requestWithAPIKey:(NSString *)apiKey secret:(NSString *)secret
{
    ExportRequest *exportRequest = [[ExportRequest alloc] init];
    exportRequest.apiKey = apiKey;
    exportRequest.apiSecret = secret;
    return exportRequest;
}

#pragma mark - Main Request Methods

- (void)requestWithURL:(NSURL *)baseURL params:(NSDictionary *)URLParams
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPExportBegan object:nil];
    
    NSURLSessionConfiguration* sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    /* Create session, and set a NSURLSessionDelegate. */
    NSURLSession* session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:nil];
    
    // Update params with API Key, expire and sig
    NSMutableDictionary *params = [URLParams mutableCopy];
    [params setObject:self.apiKey forKey:kMPParameterAPIKey];
    [params setObject:self.expire forKey:kMPParameterExpire];
    NSString *sig = [self signatureForParams:params];
    [params setObject:sig forKey:kMPParameterSig];
    
    /* Create the Request:
     Export (GET https://data.mixpanel.com/api/2.0/export/)
     Engage (GET https://mixpanel.com/api/2.0/engage/)
     */
    
    NSURL *URL = NSURLByAppendingQueryParameters(baseURL, params);
    [self updateStatusWithString:URL.absoluteString];
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"GET";

    /* Start a new Task */
    NSURLSessionDataTask *task;
    
    if ([self.requestType isEqualToString:@"people"])
    {
        task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode == 200)
            {
                [self updateStatusWithString:[NSString stringWithFormat:@"HTTP Status Code = %lu", httpResponse.statusCode]];
            } else
            {
                [self updateStatusWithString:[NSString stringWithFormat:@"BAD HTTP STATUS: %@", [httpResponse description]]];
            }
            
            
            if (error == nil) {
                // Success
                [self peopleResultsHandler:data];
            }
            else {
                // Failure
                [self updateStatusWithString:[NSString stringWithFormat:@"URL Session Task Failed: %@", [error localizedDescription]]];
            }
            [session invalidateAndCancel];
        }];
    } else if ([self.requestType isEqualToString:@"events"])
    {
        task = [session dataTaskWithRequest:request];
    }
    [task resume];
    
}

- (void)requestForEvents:(NSArray *)events fromDate:(NSDate *)fromDate toDate:(NSDate *)toDate where:(NSString *)whereClause
{
    self.requestType = @"events";
    
    NSString *fromDateString = [self.dateFormatter stringFromDate:fromDate];
    NSString *toDateString = [self.dateFormatter stringFromDate:toDate];
    
    NSMutableDictionary *URLParams = [NSMutableDictionary dictionaryWithDictionary:@{kMPParameterFromDate:fromDateString,
                                                                                     kMPParameterToDate:toDateString}];
    
    if ([events count]) [URLParams setObject:[self eventsStringFromArray:events] forKey:kMPParameterRawExportEvent];
    if (whereClause && ![whereClause isEqualToString:@""]) [URLParams setObject:whereClause forKey:kMPParameterWhere];
    
    [self requestWithURL:[NSURL URLWithString:kMPURLRawExport] params:URLParams];
}

- (void)requestForPeopleWhere:(NSString *)whereClause sessionID:(NSString *)sessionID page:(NSUInteger)page
{
    self.requestType = @"people";
    self.whereClause = whereClause;
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

#pragma mark - NSURLSession Delegate

// This is where we handle the raw events data as it streams in

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    if ([self.requestType isEqualToString:@"events"])
    {
        // Check for API Error message on first pass
        if (self.events.count == 0)
        {
            NSError *error;
            NSDictionary *firstResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (firstResponse[@"error"])
            {
                [self updateStatusWithString:[NSString stringWithFormat:@"API ERROR MESSAGE: %@", firstResponse[@"error"]]];
                return;
            }
        }
        
        // Parse current chunk of data
        switch ([self.jsonParser parse:data])
        {
            case SBJson4ParserStopped:
            case SBJson4ParserComplete:
                [self updateStatusWithString:[NSString stringWithFormat:@"%lu Events Parsed", self.events.count]];
                break;
            case SBJson4ParserWaitingForData:
                break;
            case SBJson4ParserError:
                return;
            default:
                break;
        }
        
        // Store current batch of elements and remove them from the self.events queue
        NSArray *eventBatch = [self.events copy];
        self.eventCount += eventBatch.count;
        [self.events removeObjectsInArray:eventBatch];
        [self storeEvents:eventBatch];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode == 200)
    {
        [self updateStatusWithString:[NSString stringWithFormat:@"HTTP Status Code = %lu", httpResponse.statusCode]];
    } else
    {
        [self updateStatusWithString:[NSString stringWithFormat:@"BAD HTTP STATUS: %@", [httpResponse description]]];
    }
    
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    
    if (error)
    {
        [self updateStatusWithString:[NSString stringWithFormat:@"NSURLSessionTask Error: %@", error.localizedDescription]];
    } else
    {
        [self updateStatusWithString:@"NSURLSessionTask Complete"];
        //
        dispatch_sync(self.propQueue, ^{});
        __weak ExportRequest *weakSelf = self;
        AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        [appDelegate.connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            [transaction setObject:[weakSelf.propertyKeys allObjects] forKey:kMPDBPropertiesKeyEvents inCollection:kMPDBCollectionNamePropertiesEvents];
        }];
    }
    [session invalidateAndCancel];
    NSDictionary *userInfo = @{kMPUserInfoKeyCount:@(self.eventCount),kMPUserInfoKeyType:@"event"};
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPExportEnd object:nil userInfo:userInfo];
}

#pragma mark - People Results handler

- (void)peopleResultsHandler:(NSData *)data
{
    NSError *peopleError;
    __block NSDictionary *people = [NSDictionary dictionary];
    people = [NSJSONSerialization JSONObjectWithData:data options:0 error:&peopleError];
    
    
    if (!peopleError)
    {
        // If the API response object has an error key, update status and return
        if (people[@"error"])
        {
            [self updateStatusWithString:[NSString stringWithFormat:@"API Error message: %@",people[@"error"]]];
            return;
        }
        
        // Set total number of profiles to be returned on first pass
        if ([self.totalProfiles integerValue] == 0)
        {
            self.totalProfiles = people[@"total"];
        }
        
        // If the number of results is >= 1000 request the next page
        if ([people[kMPPeopleKeyResults] count] >= 1000)
        {
            dispatch_async(self.downloadQueue, ^{
                [self requestForPeopleWhere:self.whereClause sessionID:people[kMPPeopleKeySessionID] page:[people[kMPPeopleKeyPage] integerValue]+1];
            });
            
            [self savePeopleToDatabase:people lastBatch:NO];
        } else
        {
            // This is the last page of profiles
            [self savePeopleToDatabase:people lastBatch:YES];
        }
    } else
    {
        [self updateStatusWithString:[NSString stringWithFormat:@"Error serializing People data. Error message: %@",peopleError.localizedDescription]];
    }
    
    
    
}

#pragma mark - Save to database

- (void)storeEvents:(NSArray *)eventBatch
{
    __weak ExportRequest *weakSelf = self;
    __block dispatch_queue_t propertyQueue = dispatch_queue_create("propertyThread", NULL);

    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [appDelegate.connection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        for (NSDictionary *event in eventBatch)
        {
            dispatch_async(propertyQueue, ^{
                [weakSelf.propertyKeys addObjectsFromArray:[event[@"properties"] allKeys]];
            });
            
            [transaction setObject:event forKey:[[NSUUID UUID] UUIDString] inCollection:kMPDBCollectionNameEvents];
        }
    } completionBlock:^{
        [weakSelf updateStatusWithString:[NSString stringWithFormat:@"Event Batch %lu saved successfully!", self.batchIndex]];
        weakSelf.batchIndex++;
        
        // Post notification with new Event Count
        NSDictionary *userInfo = @{kMPUserInfoKeyCount:@(weakSelf.eventCount),kMPUserInfoKeyType:@"event"};
        [[NSNotificationCenter defaultCenter] postNotificationName:kMPExportEnd object:nil userInfo:userInfo];
    }];
}

- (void)savePeopleToDatabase:(NSDictionary *)people lastBatch:(BOOL)lastBatch
{
    __weak ExportRequest *weakSelf = self;
    __block dispatch_queue_t propertyQueue = dispatch_queue_create("propertyThread", NULL);
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [appDelegate.connection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        for (NSDictionary *profile in people[kMPPeopleKeyResults])
        {
            dispatch_async(propertyQueue, ^{
                NSArray *keys = [profile[@"$properties"] allKeys];
                [weakSelf.propertyKeys addObjectsFromArray:keys];
                if ([keys containsObject:@"$transactions"])
                {
                    [weakSelf getTransactionKeysForProfile:profile];
                }
            });
            [transaction setObject:profile forKey:profile[@"$distinct_id"] inCollection:kMPDBCollectionNamePeople];
        }
    } completionBlock:^{
        NSNumber *page = people[kMPPeopleKeyPage];
        [weakSelf updateStatusWithString:[NSString stringWithFormat:@"Page %@ of %lu saved",page,[weakSelf.totalProfiles integerValue]/1000]];
        
        // Post notification with new People count
        NSDictionary *userInfo = @{kMPUserInfoKeyType:@"people",kMPUserInfoKeyCount:@([page integerValue] * 1000)};
        [[NSNotificationCenter defaultCenter] postNotificationName:kMPExportUpdate object:nil userInfo:userInfo];
        
        if (lastBatch)
        {
            // Ensure queue is empty by submitting empty synchronous block
            dispatch_sync(propertyQueue, ^{});
            
            [appDelegate.connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
                [transaction setObject:[weakSelf.propertyKeys allObjects] forKey:kMPDBPropertiesKeyPeople inCollection:kMPDBCollectionNamePropertiesPeople];
                [transaction setObject:[weakSelf.transactionKeys allObjects] forKey:kMPDBPropertiesKeyTransactions inCollection:kMPDBCollectionNamePropertiesTransactions];
            }];
            
            // Post notification with total count
            NSDictionary *userInfo = @{kMPUserInfoKeyCount:self.totalProfiles,kMPUserInfoKeyType:@"people"};
            [[NSNotificationCenter defaultCenter] postNotificationName:kMPExportEnd object:nil userInfo:userInfo];
        }
    }];
}

- (void)getTransactionKeysForProfile:(NSDictionary *)profile
{
    for (NSDictionary *transaction in profile[@"$properties"][@"$transactions"])
    {
        [self.transactionKeys addObjectsFromArray:[transaction[@"$properties"] allKeys]];
    }
}
#pragma mark - Utility Methods

- (NSString *)signatureForParams:(NSMutableDictionary *)URLParams
{
    // Mixpanel API Signature Creator
    
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

- (NSString *)expire
{
    // Return timestamp of +10 mins
    return [NSString stringWithFormat:@"%li", (long)[[NSDate date] timeIntervalSince1970] + 600];
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

- (void)updateStatusWithString:(NSString *)status
{
    NSDictionary *statusInfo = @{kMPUserInfoKeyType:kMPStatusUpdate,kMPUserInfoKeyStatus:status};
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPStatusUpdate object:nil userInfo:statusInfo];
}

/*
 * Utils
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

@end
