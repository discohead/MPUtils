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
#import <CouchbaseLite/CouchbaseLite.h>
#import <SBJson/SBJson4.h>

@interface ExportRequest () <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

@property (strong, nonatomic) NSString *apiKey;
@property (strong, nonatomic) NSString *apiSecret;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@property (strong, nonatomic) NSNumber *totalProfiles;
@property (strong, nonatomic) NSMutableSet *peoplePropsSet;
@property (strong, nonatomic) NSMutableSet *transactionPropsSet;
@property (strong, nonatomic) NSString *whereClause;
@property (nonatomic) dispatch_queue_t downloadQueue;
@property (strong, nonatomic) NSMutableArray *events;
@property (strong, nonatomic) SBJson4Parser *jsonParser;
@property (strong, nonatomic) NSString *requestType;
@property (nonatomic) NSUInteger batchIndex;
@property (nonatomic) NSUInteger eventCount;
@end

@implementation ExportRequest

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

-(NSMutableSet *)transactionPropsSet
{
    if (!_transactionPropsSet)
    {
        _transactionPropsSet = [NSMutableSet set];
    }
    return _transactionPropsSet;
}

- (NSMutableSet *)peoplePropsSet
{
    if (!_peoplePropsSet)
    {
        _peoplePropsSet = [NSMutableSet set];
    }
    return _peoplePropsSet;
}

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
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPExportBegan object:nil];
    
    /* Configure session, choose between:
     * defaultSessionConfiguration
     * ephemeralSessionConfiguration
     * backgroundSessionConfigurationWithIdentifier:
     And set session-wide properties, such as: HTTPAdditionalHeaders,
     HTTPCookieAcceptPolicy, requestCachePolicy or timeoutIntervalForRequest.
     */
    NSURLSessionConfiguration* sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    /* Create session, and optionally set a NSURLSessionDelegate. */
    NSURLSession* session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:nil];
    
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
    [self updateStatusWithString:URL.absoluteString];
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"GET";

    /* Start a new Task */
    NSURLSessionDataTask *task;
    
    if ([self.requestType isEqualToString:@"people"])
    {
        task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            [self updateStatusWithString:[NSString stringWithFormat:@"HTTP Status Code = %lu", httpResponse.statusCode]];
            
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

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    if ([self.requestType isEqualToString:@"events"])
    {
        switch ([self.jsonParser parse:data])
        {
            case SBJson4ParserStopped:
            case SBJson4ParserComplete:
                [self updateStatusWithString:[NSString stringWithFormat:@"%lu Events Parsed", self.events.count]];
                break;
            case SBJson4ParserWaitingForData:
                [self updateStatusWithString:[NSString stringWithFormat:@"SBJSON4ParserWaitingForData, %lu events", self.events.count]];
                break;
            case SBJson4ParserError:
                [self updateStatusWithString:@"SBJSON4ParserError!"];
                break;
            default:
                break;
        }
        NSArray *eventBatch = [self.events copy];
        self.eventCount += eventBatch.count;
        [self.events removeObjectsInArray:eventBatch];
        [self storeEvents:eventBatch];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    [self updateStatusWithString:[NSString stringWithFormat:@"HTTP Status Code = %lu", httpResponse.statusCode]];
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
    }
    [session invalidateAndCancel];
    NSDictionary *userInfo = @{kMPUserInfoKeyCount:@(self.eventCount),kMPUserInfoKeyType:@"event"};
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPExportEnd object:nil userInfo:userInfo];
}

- (void)storeEvents:(NSArray *)eventBatch
{
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    __block CBLManager *manager = appDelegate.manager;
    __block CBLDatabase *database = appDelegate.database;
    
    dispatch_async(manager.dispatchQueue, ^{
        NSError *dbError;
        if (!dbError)
        {
            BOOL transaction = [database inTransaction:^BOOL{
                for (NSDictionary *event in eventBatch)
                {
                    CBLDocument *document = [database createDocument];
                    NSError *documentError;
                    NSMutableDictionary *mutableEvent = [event mutableCopy];
                    [mutableEvent setObject:kMPCBLDocumentTypeEvent forKey:kMPCBLDocumentKeyType];
                    [document putProperties:mutableEvent error:&documentError];
                    if (documentError)
                    {
                        [self updateStatusWithString:[NSString stringWithFormat:@"Error putting properties into document. Error Message: %@", documentError.localizedDescription]];
                        return NO;
                    }
                }
                return YES;
            }];
            if (transaction)
            {
                [self updateStatusWithString:[NSString stringWithFormat:@"Event Batch %lu saved successfully!", self.batchIndex]];
                self.batchIndex++;
                NSDictionary *userInfo = @{kMPUserInfoKeyCount:@(self.eventCount),kMPUserInfoKeyType:@"event"};
                [[NSNotificationCenter defaultCenter] postNotificationName:kMPExportEnd object:nil userInfo:userInfo];
            } else
            {
                [self updateStatusWithString:[NSString stringWithFormat:@"Failed to save event batch %lu! Rolling back...", self.batchIndex]];
                self.batchIndex++;
            }
        } else
        {
            [self updateStatusWithString:[NSString stringWithFormat:@"Error getting database. Error message: %@", dbError.localizedDescription]];
        }
        
    });
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

- (void)eventsResultsHandler:(NSData *)data
{
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    __block CBLManager *manager = appDelegate.manager;
    __block CBLDatabase *database = appDelegate.database;
    
    NSError *jsonError;
    NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSMutableArray *resultsArray = [[jsonString componentsSeparatedByString:@"\n"] mutableCopy];
    [resultsArray removeObjectAtIndex:[resultsArray count]-1];
    NSMutableArray *jsonArray = [NSMutableArray array];
    int errorIndex = 0;
    for (NSString *result in resultsArray) {
        NSDictionary *jsonEvent = [NSJSONSerialization JSONObjectWithData:[result dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&jsonError];
        if (errorIndex < 2)
        {
            if (jsonEvent[@"error"])
            {
                [self updateStatusWithString:[NSString stringWithFormat:@"API Error Message: %@", jsonEvent[@"error"]]];
            }
            errorIndex++;
        }
        [jsonArray addObject:jsonEvent];
        
        if (jsonError) {
            [self updateStatusWithString:[NSString stringWithFormat:@"Error serializing raw export JSON response: %@", jsonError.localizedDescription]];
        }
    }
    
    dispatch_sync(manager.dispatchQueue, ^{
        NSError *dbError;
        
        if (!dbError)
        {
            BOOL transaction = [database inTransaction:^BOOL{
                for (NSDictionary *event in jsonArray)
                {
                    CBLDocument *document = [database createDocument];
                    NSError *documentError;
                    NSMutableDictionary *mutableEvent = [event mutableCopy];
                    [mutableEvent setObject:kMPCBLDocumentTypeEvent forKey:kMPCBLDocumentKeyType];
                    [document putProperties:mutableEvent error:&documentError];
                    if (documentError)
                    {
                        [self updateStatusWithString:[NSString stringWithFormat:@"Error putting properting into document. Error Message: %@", documentError.localizedDescription]];
                        return NO;
                    }
                }
                return YES;
            }];
            if (transaction)
            {
                [self updateStatusWithString:@"All events saved successfully!"];
            } else
            {
                [self updateStatusWithString:@"Failed to save events! Rolling back..."];
            }
        } else
        {
            [self updateStatusWithString:[NSString stringWithFormat:@"Error getting database. Error message: %@", dbError.localizedDescription]];
        }
        
    });
    
    NSDictionary *userInfo = @{kMPUserInfoKeyCount:@([jsonArray count]),kMPUserInfoKeyType:@"event"};
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPExportEnd object:nil userInfo:userInfo];
}

- (void)savePeopleToDatabase:(NSDictionary *)people
{
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    __block CBLManager *manager = appDelegate.manager;
    __block CBLDatabase *database = appDelegate.database;
    
    dispatch_sync(manager.dispatchQueue, ^{
        BOOL transaction = [database inTransaction:^BOOL{
            for (NSDictionary *profile in people[kMPPeopleKeyResults])
            {
                CBLDocument *document = [database documentWithID:profile[kMPCBLPeopleDocumentKeyDistinctID]];
                CBLUnsavedRevision *revision = [document newRevision];
                NSError *documentError;
                NSMutableDictionary *mutableProfile = [profile mutableCopy];
                [mutableProfile setObject:kMPCBLDocumentTypePeopleProfile forKey:kMPCBLDocumentKeyType];
                [revision.properties addEntriesFromDictionary:mutableProfile];
                if (![revision save:&documentError])
                {
                    [self updateStatusWithString:[NSString stringWithFormat:@"Error saving profile revision. Error Message: %@", documentError.localizedDescription]];
                    return NO;
                }
            }
            return YES;
        }];
        
        if (!transaction)
        {
            [self updateStatusWithString:@"Failed to store People profiles. Rolling back..."];
        } else
        {
            NSNumber *page = people[kMPPeopleKeyPage];
            [self updateStatusWithString:[NSString stringWithFormat:@"Page %@ of %lu saved",page,[self.totalProfiles integerValue]/1000]];
            NSDictionary *userInfo = @{kMPUserInfoKeyType:@"people",kMPUserInfoKeyCount:@([page integerValue] * 1000)};
            [[NSNotificationCenter defaultCenter] postNotificationName:kMPExportUpdate object:nil userInfo:userInfo];
        }
    });
}

- (void)peopleResultsHandler:(NSData *)data
{
    NSError *peopleError;
    __block NSDictionary *people = [NSDictionary dictionary];
    people = [NSJSONSerialization JSONObjectWithData:data options:0 error:&peopleError];
    

    if (!peopleError)
    {
        if (people[@"error"])
        {
           [self updateStatusWithString:[NSString stringWithFormat:@"Error message: %@",people[@"error"]]];
            return;
        }
        if ([self.totalProfiles integerValue] == 0)
        {
            self.totalProfiles = people[@"total"];
        }
        if ([people[kMPPeopleKeyResults] count] >= 1000)
        {
            dispatch_async(self.downloadQueue, ^{
                [self requestForPeopleWhere:self.whereClause sessionID:people[kMPPeopleKeySessionID] page:[people[kMPPeopleKeyPage] integerValue]+1];
            });
            
            [self savePeopleToDatabase:people];
        } else
        {
            [self savePeopleToDatabase:people];
            NSDictionary *userInfo = @{kMPUserInfoKeyCount:self.totalProfiles,kMPUserInfoKeyType:@"people"};
            [[NSNotificationCenter defaultCenter] postNotificationName:kMPExportEnd object:nil userInfo:userInfo];
        }
    } else
    {
        [self updateStatusWithString:[NSString stringWithFormat:@"Error serializing People data. Error message: %@",peopleError.localizedDescription]];
    }

}

- (void)dataResultsHandler:(NSData *)data fromURL:(NSURL *)URL
{
    NSLog(@"Data Results Hanlder Called!");
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

- (void)updateStatusWithString:(NSString *)status
{
    NSDictionary *statusInfo = @{kMPUserInfoKeyType:kMPStatusUpdate,kMPUserInfoKeyStatus:status};
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPStatusUpdate object:nil userInfo:statusInfo];
}
@end
