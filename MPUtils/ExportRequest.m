//
//  ExportRequest.m
//  MPUtils
//
//  Created by Jared McFarland on 3/28/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import "ExportRequest.h"
#import "MPUConstants.h"
#import "CSVWriter.h"
#import "JSONWriter.h"
#import "NSString+Hashes.h"
#import "AppDelegate.h"
#import <YapDatabase/YapDatabase.h>
#import <SBJson/SBJson4.h>
#import <Mixpanel-OSX-Community/Mixpanel.h>

@interface ExportRequest () <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

// Basic String Properties

@property (strong, nonatomic) NSString *apiKey;
@property (strong, nonatomic) NSString *apiSecret;
@property (strong, nonatomic) NSString *whereClause;
@property (strong, nonatomic) NSString *requestType;
@property (strong, nonatomic) NSString *outputType;

// Collection Properties

@property (strong, nonatomic) NSMutableArray *events;
@property (strong, nonatomic) NSMutableArray *profiles;
@property (strong, nonatomic) NSMutableSet *propertyKeys;
@property (strong, nonatomic) NSMutableSet *transactionKeys;
@property (strong, nonatomic) NSMutableArray *highVolumeDatesArray;
@property (strong, nonatomic) NSArray *eventsQueryArray;

// Dispatch Queues

@property (strong, nonatomic) dispatch_queue_t downloadQueue;
@property (strong, nonatomic) dispatch_queue_t dataProcessingQueue;
@property (strong, nonatomic) dispatch_queue_t writeQueue;
@property (strong, nonatomic) dispatch_queue_t propQueue;
@property (strong, nonatomic) NSOperationQueue *sessionQueue;

// Count properties

@property (strong, nonatomic) NSNumber *totalProfiles;
@property (nonatomic) NSUInteger savedEventCount;
@property (nonatomic) NSUInteger parsedEventCount;
@property (nonatomic) int counter;

// Misc. Utility Properties

@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@property (strong, nonatomic) SBJson4Parser *jsonParser;
@property (strong, nonatomic) id writer;
@property (weak, nonatomic) NSURLSession *session;
@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic) BOOL cancelled;

@end

@implementation ExportRequest

#pragma mark - Lazy Properties

- (NSArray *)eventsQueryArray
{
    if (!_eventsQueryArray)
    {
        _eventsQueryArray = [NSArray array];
    }
    return _eventsQueryArray;
}

- (NSMutableArray *)highVolumeDatesArray
{
    if (!_highVolumeDatesArray)
    {
        _highVolumeDatesArray = [NSMutableArray array];
    }
    return _highVolumeDatesArray;
}

- (id)writer
{
    if (!_writer)
    {
        _writer = [[NSObject alloc] init];
    }
    return _writer;
}

- (NSMutableArray *)profiles
{
    if (!_profiles)
    {
        _profiles = [NSMutableArray array];
    }
    return _profiles;
}

- (NSString *)outputType
{
    if (!_outputType)
    {
        _outputType = [NSString string];
    }
    return _outputType;
}

- (NSTimeInterval)startTime
{
    if (!_startTime)
    {
        _startTime = [[NSDate date] timeIntervalSince1970];
    }
    return _startTime;
}

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

- (dispatch_queue_t)dataProcessingQueue
{
    if (!_dataProcessingQueue)
    {
        _dataProcessingQueue = dispatch_queue_create("eventDataQ", NULL);
    }
    return _dataProcessingQueue;
}

- (dispatch_queue_t)writeQueue
{
    if (!_writeQueue)
    {
        _writeQueue = dispatch_queue_create("writeQ", NULL);
    }
    return _writeQueue;
}

- (NSOperationQueue *)sessionQueue
{
    if (!_sessionQueue)
    {
        _sessionQueue = [[NSOperationQueue alloc] init];
    }
    return _sessionQueue;
}

- (NSUInteger)parsedEventCount
{
    if (!_parsedEventCount)
    {
        _parsedEventCount = 0;
    }
    return _parsedEventCount;
}

- (NSUInteger)savedEventCount
{
    if (!_savedEventCount)
    {
        _savedEventCount = 0;
    }
    return _savedEventCount;
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

- (SBJson4Parser *)jsonParser
{
    if (!_jsonParser)
    {
        _jsonParser = [SBJson4Parser multiRootParserWithBlock:^(id event, BOOL *stop) {
            [self.events addObject:event];
            if ([self.outputType isEqualToString:@"CSV"] || [self.outputType isEqualToString:@"DB"])
            {
                dispatch_async(self.propQueue, ^{
                    [self.propertyKeys addObjectsFromArray:[event[@"properties"] allKeys]];
                });
            }
        } errorHandler:^(NSError *error) {
            [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"JSON Parser error: %@", error.localizedDescription] attributes:@{NSForegroundColorAttributeName:[NSColor redColor]}]];
        }];
    }
    return _jsonParser;
}


#pragma mark - Convenience Initializer

+ (instancetype)requestWithAPIKey:(NSString *)apiKey secret:(NSString *)secret outputType:(NSString *)outputType
{
    ExportRequest *exportRequest = [[ExportRequest alloc] init];
    exportRequest.apiKey = apiKey;
    exportRequest.apiSecret = secret;
    exportRequest.startTime = [[NSDate date] timeIntervalSince1970];
    exportRequest.outputType = outputType;
    exportRequest.cancelled = NO;
    if (![outputType isEqualToString:@"DB"])
    {
        exportRequest.counter = 0;
        AppDelegate *appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
        NSString *filePath = [appDelegate.basePath stringByAppendingPathComponent:[NSString stringWithFormat:@"Export_%.0f",[[NSDate date] timeIntervalSince1970]]];
        id writer;
        if ([outputType isEqualToString:@"CSV"])
        {
            writer = [[CSVWriter alloc] initForWritingToFile:[filePath stringByAppendingPathExtension:@"csv"]];
        } else if ([outputType isEqualToString:@"JSON"])
        {
            writer = [[JSONWriter alloc] initForWritingToFile:[filePath stringByAppendingPathExtension:@"json"]];
        }
        exportRequest.writer = writer;
    }
    
    return exportRequest;
}

#pragma mark - Main Request Methods

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

- (void)highVolumeRequestForEvents:(NSArray *)events withArrayOfDates:(NSArray *)datesArray where:(NSString *)whereClause
{
    self.eventsQueryArray = events;
    self.whereClause = whereClause;
    self.highVolumeDatesArray = [datesArray mutableCopy];
    NSDate *firstDate = [datesArray firstObject];
    [self requestForEvents:events fromDate:firstDate toDate:firstDate where:whereClause];
    [self.highVolumeDatesArray removeObjectAtIndex:0];
}

- (void)requestForProfileWithDistinctID:(NSString *)distinctID
{
    [self requestWithURL:[NSURL URLWithString:kMPURLEngageExport] params:@{kMPParameterEngageDistinctID:distinctID}];
}

- (void)requestWithURL:(NSURL *)baseURL params:(NSDictionary *)URLParams
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPAPIRequestBegan object:nil];
    
    NSURLSessionConfiguration* sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    sessionConfig.timeoutIntervalForRequest = 360000.0;
    
    /* Create session, and set a NSURLSessionDelegate. */
    NSURLSession* session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:self.sessionQueue];
    self.session = session;
    
    // Update params with API Key, expire and sig
    NSMutableDictionary *params = [URLParams mutableCopy];
    [params setObject:self.apiKey forKey:kMPParameterAPIKey];
    [params setObject:self.expire forKey:kMPParameterExpire];
    NSString *sig = [self signatureForParams:params];
    [params setObject:sig forKey:kMPParameterSig];
    
    NSURL *URL = NSURLByAppendingQueryParameters(baseURL, params);
    [self updateStatusWithString:[[NSAttributedString alloc] initWithString:URL.absoluteString attributes:@{NSForegroundColorAttributeName:[NSColor blueColor]}]];
    
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
                //[self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"HTTP Status Code = %lu", httpResponse.statusCode] attributes:@{NSForegroundColorAttributeName:[NSColor greenColor]}]];
            } else
            {
                [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"BAD HTTP STATUS: %@", [httpResponse description]] attributes:@{NSForegroundColorAttributeName:[NSColor redColor]}]];
                
                [self cancel];
            }
            
            [session invalidateAndCancel];
            
            if (error == nil) {
                // Success
                dispatch_async(self.dataProcessingQueue, ^{
                    [self peopleResultsHandler:data];
                });
            } else {
                // Failure
                [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"URL Session Task Failed: %@", [error localizedDescription]] attributes:@{NSForegroundColorAttributeName:[NSColor redColor]}]];
                [[Mixpanel sharedInstance] track:@"Engage URL Session Task Error" properties:@{@"Error Message":error.description}];
            }
        }];
    } else if ([self.requestType isEqualToString:@"events"])
    {
        task = [session dataTaskWithRequest:request];
    }
    [task resume];
    
}

#pragma mark - NSURLSession Delegate

// This is where we handle the raw events data as it streams in

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    if ([self.requestType isEqualToString:@"events"])
    {
        dispatch_sync(self.dataProcessingQueue, ^{
            [self processEventDataChunk:data dataTask:dataTask];
        });
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode == 200)
    {
        [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"HTTP Status Code = %lu", httpResponse.statusCode] attributes:@{NSForegroundColorAttributeName:[NSColor greenColor]}]];
    } else
    {
        [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"BAD HTTP STATUS: %@", [httpResponse description]] attributes:@{NSForegroundColorAttributeName:[NSColor redColor]}]];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kMPAPIRequestFailed object:nil];
        
        [self cancel];
    }
    
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    
    if (error)
    {
        [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"NSURLSessionTask Error: %@", error.localizedDescription] attributes:@{NSForegroundColorAttributeName:[NSColor redColor]}]];
        [[Mixpanel sharedInstance] track:@"Export URL Session Task Error" properties:@{@"Error Message":error.description}];
    } else
    {
        Mixpanel *mixpanel = [Mixpanel sharedInstance];
        [mixpanel.people increment:@"Export API Requests" by:@1];
        [mixpanel registerSuperProperties:@{@"Export API Requests":@([[[[mixpanel currentSuperProperties] objectsForKeys:@[@"Export API Requests"] notFoundMarker:@0] objectAtIndex:0] integerValue] + 1)}];
        NSUInteger rows = ([self.outputType isEqualToString:@"DB"]) ? self.parsedEventCount : [self.events count];
        [mixpanel track:@"API Request" properties:@{@"Type":@"Events",@"Rows":@(rows),@"$duration":@([[NSDate date] timeIntervalSince1970] - self.startTime)}];
        
        [self updateStatusWithString:[[NSAttributedString alloc] initWithString:@"NSURLSessionTask Complete" attributes:@{NSForegroundColorAttributeName:[NSColor greenColor]}]];
        
        
        if ([self.highVolumeDatesArray count] > 0 && !self.cancelled)
        {
            [self requestForEvents:self.eventsQueryArray fromDate:[self.highVolumeDatesArray firstObject] toDate:[self.highVolumeDatesArray firstObject]  where:self.whereClause];
            [self.highVolumeDatesArray removeObjectAtIndex:0];
            [[NSNotificationCenter defaultCenter] postNotificationName:kMPAPIRequestUpdate object:nil userInfo:@{kMPUserInfoKeyType:@"event",kMPUserInfoKeyHighVolume:@(YES)}];
        } else {
            dispatch_sync(self.propQueue, ^{});
            dispatch_sync(self.dataProcessingQueue, ^{});
            dispatch_sync(self.writeQueue, ^{});
            
            if ([self.outputType isEqualToString:@"DB"])
            {
                NSArray *propKeys = [[self.propertyKeys allObjects] copy];
                
                AppDelegate *appDelegate = (AppDelegate *) [[NSApplication sharedApplication] delegate];
                [appDelegate.connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
                    [transaction setObject:propKeys forKey:kMPDBPropertiesKeyEvents inCollection:kMPDBCollectionNamePropertiesEvents];
                }];
                
            } else
            {
                [self writeEventsToFile];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:kMPAPIRequestEnded object:nil userInfo:@{kMPUserInfoKeyType:@"event"}];
            [self postUserNotificationWithTitle:@"Export API Request Complete" andInfoText:[NSString stringWithFormat:@"%lu events received", rows]];
        }
    }
    [session invalidateAndCancel];
    
}

#pragma mark - Event Data Chunk Processing

- (void)processEventDataChunk:(NSData *)data dataTask:(NSURLSessionDataTask *)dataTask
{
    // Check for API Error message on first pass
    if (self.events.count == 0)
    {
        NSError *error;
        NSDictionary *firstResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (firstResponse[@"error"])
        {
            [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"API ERROR MESSAGE: %@", firstResponse[@"error"]] attributes:@{NSForegroundColorAttributeName:[NSColor redColor]}]];
            
            // Notifiy ViewController
            [[NSNotificationCenter defaultCenter] postNotificationName:kMPAPIRequestFailed object:nil userInfo:@{kMPUserInfoKeyType:@"event",kMPUserInfoKeyHighVolume:@NO}];
            
            // Notifiy user
            [self postUserNotificationWithTitle:@"Export API Error!" andInfoText:firstResponse[@"error"]];
            
            [self cancel];
            
            return;
        }
    }
    
    if (dataTask.countOfBytesExpectedToReceive > 0)
    {
        [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%.2f%% received",(double)dataTask.countOfBytesReceived/(double)dataTask.countOfBytesExpectedToReceive*100] attributes:@{NSForegroundColorAttributeName:[NSColor grayColor]}]];
    }
    
    // Parse current chunk of data
    switch ([self.jsonParser parse:data])
    {
        case SBJson4ParserStopped:
        case SBJson4ParserComplete:
            [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%lu Events Parsed", self.events.count] attributes:@{NSForegroundColorAttributeName:[NSColor grayColor]}]];
            break;
        case SBJson4ParserWaitingForData:
            break;
        case SBJson4ParserError:
            return;
        default:
            break;
    }
    
    if ([self.outputType isEqualToString:@"DB"])
    {
        
        // Store current batch of elements and remove them from the self.events queue
        NSArray *eventBatch = [self.events copy];
        self.parsedEventCount += eventBatch.count;
        [self.events removeObjectsInArray:eventBatch];
        dispatch_async(self.writeQueue, ^{
            [self saveEventsToDatabase:eventBatch];
        });
    } else
    {
        [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%lu events received",[self.events count]] attributes:@{NSForegroundColorAttributeName:[NSColor grayColor]}]];
    }
}

#pragma mark - People Results handler

- (void)peopleResultsHandler:(NSData *)data
{
    NSError *jsonError;
    __block NSDictionary *people = [NSDictionary dictionary];
    people = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    
    
    if (!jsonError)
    {
        // If the API response object has an error key, update status and return
        if (people[@"error"])
        {
            [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"API Error message: %@",people[@"error"]] attributes:@{NSForegroundColorAttributeName:[NSColor redColor]}]];
            
            // Notify ViewController
            [[NSNotificationCenter defaultCenter] postNotificationName:kMPAPIRequestFailed object:nil userInfo:@{kMPUserInfoKeyType:@"people"}];
            
            //Notify user
            [self postUserNotificationWithTitle:@"Engage API Error!" andInfoText:people[@"error"]];
            
            [self cancel];
            
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
            if (!self.cancelled)
            {
                [self requestForPeopleWhere:self.whereClause sessionID:people[kMPPeopleKeySessionID] page:[people[kMPPeopleKeyPage] integerValue]+1];
            }
            
            if ([self.outputType isEqualToString:@"DB"])
            {
                dispatch_async(self.writeQueue, ^{
                    [self savePeopleToDatabase:people lastBatch:NO];
                });
            } else
            {
                dispatch_async(self.writeQueue, ^{
                    [self savePeopleToFile:people lastBatch:NO];
                });
            }
            
        } else
        {
            Mixpanel *mixpanel = [Mixpanel sharedInstance];
            [mixpanel.people increment:@"Engage API Requests" by:@1];
            [mixpanel registerSuperProperties:@{@"Engage API Requests":@([[[[mixpanel currentSuperProperties] objectsForKeys:@[@"Engage API Requests"] notFoundMarker:@0] objectAtIndex:0] integerValue] + 1)}];
            [mixpanel track:@"API Request" properties:@{@"Type":@"People",@"Rows":self.totalProfiles,@"$duration":@([[NSDate date] timeIntervalSince1970] - self.startTime)}];
            
            // This is the last page of profiles
            if ([self.outputType isEqualToString:@"DB"])
            {
                dispatch_async(self.writeQueue, ^{
                    [self savePeopleToDatabase:people lastBatch:YES];
                });
            } else
            {
                dispatch_async(self.writeQueue, ^{
                    [self savePeopleToFile:people lastBatch:YES];
                });
            }
            
        }
    } else
    {
        [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"Error serializing People data. Error message: %@",jsonError.localizedDescription] attributes:@{NSForegroundColorAttributeName:[NSColor redColor]}]];
    }
 
    
}

#pragma mark - Database Writing

- (void)saveEventsToDatabase:(NSArray *)eventBatch
{
    __weak ExportRequest *weakSelf = self;

    AppDelegate *appDelegate = (AppDelegate *) [[NSApplication sharedApplication] delegate];
    
    [appDelegate.connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        for (NSDictionary *event in eventBatch)
        {
            [transaction setObject:event forKey:[[NSUUID UUID] UUIDString] inCollection:kMPDBCollectionNameEvents];
            weakSelf.savedEventCount++;
        }
        
        [weakSelf updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%lu events saved to database", self.savedEventCount] attributes:@{NSForegroundColorAttributeName:[NSColor grayColor]}]];
        
        // Post notification with new Event Count
        NSDictionary *userInfo = @{kMPUserInfoKeyCount:@([eventBatch count]),kMPUserInfoKeyType:@"event"};
        [[NSNotificationCenter defaultCenter] postNotificationName:kMPDBWritingUpdate object:nil userInfo:userInfo];
    }];
}

- (void)savePeopleToDatabase:(NSDictionary *)people lastBatch:(BOOL)lastBatch
{
    __weak ExportRequest *weakSelf = self;
    AppDelegate *appDelegate = (AppDelegate *) [[NSApplication sharedApplication] delegate];
    
    [appDelegate.connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        
        for (NSDictionary *profile in people[kMPPeopleKeyResults])
        {
            dispatch_async(weakSelf.propQueue, ^{
                NSArray *keys = [profile[@"$properties"] allKeys];
                [weakSelf.propertyKeys addObjectsFromArray:keys];
                if ([keys containsObject:@"$transactions"])
                {
                    [weakSelf getTransactionKeysForProfile:profile];
                }
            });
            [transaction setObject:profile forKey:profile[@"$distinct_id"] inCollection:kMPDBCollectionNamePeople];
        }
        
        NSNumber *page = people[kMPPeopleKeyPage];
        [weakSelf updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"Page %lu of %lu saved",[page integerValue] + 1,[weakSelf.totalProfiles integerValue]/1000+1] attributes:@{NSForegroundColorAttributeName:[NSColor grayColor]}]];
        
        // Post notification with new People count
        NSDictionary *userInfo = @{kMPUserInfoKeyType:@"people",kMPUserInfoKeyCount:@([people[kMPPeopleKeyResults] count])};
        [[NSNotificationCenter defaultCenter] postNotificationName:kMPDBWritingUpdate object:nil userInfo:userInfo];
        
        if (lastBatch)
        {
            dispatch_sync(self.propQueue, ^{});
            [transaction setObject:[weakSelf.propertyKeys allObjects] forKey:kMPDBPropertiesKeyPeople inCollection:kMPDBCollectionNamePropertiesPeople];
            [transaction setObject:[weakSelf.transactionKeys allObjects] forKey:kMPDBPropertiesKeyTransactions inCollection:kMPDBCollectionNamePropertiesTransactions];
            
            // Notify ViewController
            [[NSNotificationCenter defaultCenter] postNotificationName:kMPAPIRequestEnded object:nil userInfo:@{kMPUserInfoKeyType:@"people"}];
            
            // Notify user
            [self postUserNotificationWithTitle:@"Engage API Request Complete" andInfoText:[NSString stringWithFormat:@"%@ profiles received",self.totalProfiles]];
        }
    }];
    
}

#pragma mark - File Writing

- (void)writeEventsToFile
{
    [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"Writing %@ file...",self.outputType] attributes:@{NSForegroundColorAttributeName:[NSColor magentaColor]}]];
    
    NSUInteger index = 0;
    
    if ([self.outputType isEqualToString:@"CSV"])
    {
        NSArray *propKeys = [self.propertyKeys allObjects];
        
        [self.writer writeHeadersForType:@"events" withProperties:propKeys];
        for (NSDictionary *event in self.events)
        {
            [self.writer writeEvent:event withProperties:propKeys finishLine:YES];
            index++;
            if (index % 1000 == 0)
            {
                [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%lu events written",(unsigned long)index] attributes:@{NSForegroundColorAttributeName:[NSColor grayColor]}]];
            }
        }
    } else if ([self.outputType isEqualToString:@"JSON"])
    {
        [self.writer writeOpenBracket];
        
        for (NSDictionary *event in self.events)
        {
            [self.writer writeEvent:event];
            index++;
            if (!(index == [self.events count]))
            {
                [self.writer writeComma];
            } else
            {
                [self.writer writeCloseBracket];
            }
            if (index % 1000 == 0)
            {
                [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%lu events written",(unsigned long)index] attributes:@{NSForegroundColorAttributeName:[NSColor grayColor]}]];
            }
        }
    }
    
    NSString *filePath = [self.writer valueForKey:@"filePath"];
    filePath = [[NSURL fileURLWithPath:filePath] absoluteString];
    [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"Quick Events %@ Export Complete\nTotal Events Written: %lu\nFile: %@",self.outputType, [self.events count], filePath] attributes:@{NSForegroundColorAttributeName:[NSColor magentaColor]}]];
    
    [self postUserNotificationWithTitle:[NSString stringWithFormat:@"Quick Events %@ Export Complete",self.outputType] andInfoText:[NSString stringWithFormat:@"%lu events received", [self.events count]]];
}


- (void)savePeopleToFile:(NSDictionary *)people lastBatch:(BOOL)lastBatch
{
    if ([self.outputType isEqualToString:@"CSV"])
    {
        for (NSDictionary *profile in people[kMPPeopleKeyResults])
        {
            [self.profiles addObject:profile];
            self.counter++;
            [self.propertyKeys addObjectsFromArray:[profile[@"$properties"] allKeys]];
        }
        [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%i profiles received",self.counter] attributes:@{NSForegroundColorAttributeName:[NSColor grayColor]}]];
        if (lastBatch)
        {
            NSArray *propKeys = [self.propertyKeys allObjects];
            
            [self.writer writeHeadersForType:@"people" withProperties:propKeys];
            for (NSDictionary *profile in self.profiles)
            {
                [self.writer writeProfile:profile withProperties:propKeys];
            }
        }
    } else if ([self.outputType isEqualToString:@"JSON"])
    {
        if (self.counter == 0)
        {
            [self.writer writeOpenBracket];
        }
        
        for (NSDictionary *profile in people[kMPPeopleKeyResults])
        {
            [self.writer writeProfile:profile];
            self.counter++;
            if (!(self.counter == [self.totalProfiles intValue]))
            {
                [self.writer writeComma];
            } else
            {
                [self.writer writeCloseBracket];
            }
        }
        [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%i profiles received",self.counter] attributes:@{NSForegroundColorAttributeName:[NSColor grayColor]}]];
    }
    if (lastBatch)
    {
        NSString *filePath = [self.writer valueForKey:@"filePath"];
        filePath = [[NSURL fileURLWithPath:filePath] absoluteString];
        [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"Quick People %@ Export Complete\nTotal Profiles Written: %@\nFile: %@",self.outputType, self.totalProfiles, filePath] attributes:@{NSForegroundColorAttributeName:[NSColor magentaColor]}]];
        
        // Notify View Controll
        [[NSNotificationCenter defaultCenter] postNotificationName:kMPAPIRequestEnded object:nil userInfo:@{kMPUserInfoKeyType:@"people"}];
        
        // Notify user
        [self postUserNotificationWithTitle:@"Quick People Export Complete" andInfoText:[NSString stringWithFormat:@"%@ profiles received",self.totalProfiles]];

    }
}

#pragma mark - Utility Methods

- (void)getTransactionKeysForProfile:(NSDictionary *)profile
{
    for (NSDictionary *transaction in profile[@"$properties"][@"$transactions"])
    {
        [self.transactionKeys addObjectsFromArray:[transaction[@"$properties"] allKeys]];
    }
}

- (void)postUserNotificationWithTitle:(NSString *)title andInfoText:(NSString *)infoText
{
    // Display desktop user notification
    NSUserNotification *userNotification = [[NSUserNotification alloc] init];
    userNotification.title = title;
    if ([title containsString:@"Error"])
    {
        userNotification.contentImage = [NSImage imageNamed:NSImageNameCaution];
    }
    userNotification.informativeText = infoText;
    userNotification.soundName = NSUserNotificationDefaultSoundName;
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:userNotification];
}

- (void)cancel
{
    self.cancelled = YES;
    if (self.session)
    {
        [self.session invalidateAndCancel];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:kMPAPIRequestCancelled object:nil];
    
}

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

- (void)updateStatusWithString:(NSAttributedString *)status
{
    NSDictionary *statusInfo = @{kMPUserInfoKeyType:kMPStatusUpdate,kMPUserInfoKeyStatus:status};
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPStatusUpdate object:nil userInfo:statusInfo];
}

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
