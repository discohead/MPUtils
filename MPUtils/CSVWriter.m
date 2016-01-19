//
//  CSVWriter.m
//  MPUtils
//
//  Created by Jared McFarland on 3/29/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import "CSVWriter.h"
#import "CHCSVParser.h"
#import "AppDelegate.h"
#import "MPUConstants.h"
#import <YapDatabase/YapDatabase.h>

@interface CSVWriter ()

@property (strong, nonatomic, readwrite) NSString *filePath;
@property (strong, nonatomic) CHCSVWriter *writer;
@property (strong, nonatomic) YapDatabaseConnection *concurrentConnection;

@end

@implementation CSVWriter

- (YapDatabaseConnection *)concurrentConnection
{
    if (!_concurrentConnection)
    {
        AppDelegate *appDelegate = (AppDelegate *) [[NSApplication sharedApplication] delegate];
        _concurrentConnection = [appDelegate.database newConnection];
    }
    return _concurrentConnection;
}

#pragma mark - Convenience Initializer

- (instancetype)initForWritingToFile:(NSString *)filePath
{
    [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"CSV file path = %@",[[NSURL fileURLWithPath:filePath] absoluteString]] attributes:@{NSForegroundColorAttributeName:[NSColor darkGrayColor]}]];
    CSVWriter *parser = [[CSVWriter alloc] init];
    parser.writer = [[CHCSVWriter alloc] initForWritingToCSVFile:filePath];
    parser.filePath = filePath;
    return parser;
}

#pragma mark - Main Writing Methods

- (void)eventsWithPeopleProperties:(BOOL)peopleProperties
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingBegan object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatCSV}];
    __weak CSVWriter *weakSelf = self;
    AppDelegate *appDelegate = (AppDelegate *) [[NSApplication sharedApplication] delegate];
    __block NSArray *eventProps = [NSArray array];
    __block NSArray *peopleProps = [NSArray array];
    NSMutableArray *headers = [NSMutableArray array];
    __block int rows = 0;
    
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        eventProps = [transaction objectForKey:kMPDBPropertiesKeyEvents inCollection:kMPDBCollectionNamePropertiesEvents];
    }];
    [headers addObjectsFromArray:eventProps];
    
    if (peopleProperties)
    {
        
        [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            peopleProps = [transaction objectForKey:kMPDBPropertiesKeyPeople inCollection:kMPDBCollectionNamePropertiesPeople];
        }];
        for (NSString *propName in peopleProps)
        {
            [headers addObject:[NSString stringWithFormat:@"profile_%@",propName]];
        }
    }
    
    [self writeHeadersForType:@"events" withProperties:headers];
    
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        __weak YapDatabaseReadTransaction *weakTransaction = transaction;
        [transaction enumerateKeysAndObjectsInCollection:kMPDBCollectionNameEvents usingBlock:^(NSString *key, id event, BOOL *stop) {
            [weakSelf writeEvent:event withProperties:eventProps finishLine:NO];
            
            if (peopleProperties)
            {
                [weakSelf writePeoplePropertiesForEvent:event withProperties:peopleProps usingTransaction:weakTransaction];
            }
            
            [weakSelf.writer finishLine];
            rows++;
        }];
    }];
    
    // Notifiy ViewController
    NSString *subType = peopleProperties ? kMPExportTypeEventsCombined : kMPExportTypeEventsRaw;
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingEnded object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatCSV, kMPFileWritingExportObjectKey:kMPExportObjectEvents,kMPFileWritingExportTypeKey:subType, kMPFileWritingCount:@(rows)}];
    
    // Notify User
    [self postUserNotificationWithTitle:@"CSV Export Complete" andInfoText:[NSString stringWithFormat:@"%i events exported", rows]];

}


- (void)peopleProfiles
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingBegan object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatCSV}];
    __weak CSVWriter *weakSelf = self;
    AppDelegate *appDelegate = (AppDelegate *) [[NSApplication sharedApplication] delegate];
    __block int rows = 0;
    
    __block NSArray *peopleProps = [NSArray array];
    
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        peopleProps = [transaction objectForKey:kMPDBPropertiesKeyPeople inCollection:kMPDBCollectionNamePropertiesPeople];
    }];
    
    [self writeHeadersForType:@"people" withProperties:peopleProps];
    
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [transaction enumerateKeysAndObjectsInCollection:kMPDBCollectionNamePeople usingBlock:^(NSString *key, id profile, BOOL *stop) {
            [weakSelf writeProfile:profile withProperties:peopleProps];
            rows++;
        }];
    }];
    
    // Notify ViewController
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingEnded object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatCSV, kMPFileWritingExportObjectKey:kMPExportObjectPeople,kMPFileWritingExportTypeKey:kMPExportTypePeopleProfiles,kMPFileWritingCount:@(rows)}];
    
    // Notify User
    [self postUserNotificationWithTitle:@"CSV Export Complete" andInfoText:[NSString stringWithFormat:@"%i profiles exported", rows]];
    
}

- (void)writePeoplePropertiesForEvent:(NSDictionary *)event withProperties:(NSArray *)peopleProperties usingTransaction:(YapDatabaseReadTransaction *)transaction
{
    __weak CSVWriter *weakSelf = self;
    
    if (event[@"properties"][@"distinct_id"])
    {
        if ([transaction hasObjectForKey:event[@"properties"][@"distinct_id"] inCollection:kMPDBCollectionNamePeople])
        {
            NSDictionary *profile = [transaction objectForKey:event[@"properties"][@"distinct_id"] inCollection:kMPDBCollectionNamePeople];
            
            for (NSString *peopleProp in peopleProperties)
            {
                if (profile[@"$properties"][peopleProp])
                {
                    [weakSelf.writer writeField:profile[@"$properties"][peopleProp]];
                } else
                {
                    [weakSelf.writer writeField:@""];
                }
            }
        }
    }
}

- (void)writeEvent:(NSDictionary *)event withProperties:(NSArray *)properties finishLine:(BOOL)finishLine
{
    __weak CSVWriter *weakSelf = self;
    [weakSelf.writer writeField:event[@"event"]];
    for (NSString *eventProp in properties)
    {
        if (event[@"properties"][eventProp])
        {
            [weakSelf.writer writeField:event[@"properties"][eventProp]];
        } else
        {
            [weakSelf.writer writeField:@""];
        }
    }
    if (finishLine)
    {
        [weakSelf.writer finishLine];
    }
}

- (void)writeHeadersForType:(NSString *)type withProperties:(NSArray *)properties
{
    NSString *firstHeader = [type isEqualToString:@"events"] ? @"event" : @"$distinct_id";
    [self.writer writeField:firstHeader];
    if ([type isEqualToString:@"transactions"])
    {
        [self.writer writeField:@"$amount"];
        [self.writer writeField:@"$time"];
    }
    for (NSString *propName in properties)
    {
        [self.writer writeField:propName];
    }
    [self.writer finishLine];
}

- (void)writeProfile:(NSDictionary *)profile withProperties:(NSArray *)properties
{
    __weak CSVWriter *weakSelf = self;
    [weakSelf.writer writeField:profile[@"$distinct_id"]];
    
    for (NSString *peopleProp in properties)
    {
        if (profile[@"$properties"][peopleProp])
        {
            [weakSelf.writer writeField:profile[@"$properties"][peopleProp]];
        } else
        {
            [weakSelf.writer writeField:@""];
        }
    }
    
    [weakSelf.writer finishLine];
}
- (void)transactions
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingBegan object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatCSV}];
    __weak CSVWriter *weakSelf = self;
    AppDelegate *appDelegate = (AppDelegate *) [[NSApplication sharedApplication] delegate];
    __block int rows = 0;
    
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        NSArray *keys = [transaction objectForKey:kMPDBPropertiesKeyTransactions inCollection:kMPDBCollectionNamePropertiesTransactions];
        [weakSelf writeHeadersForType:@"transactions" withProperties:keys];
        
        [transaction enumerateKeysAndObjectsInCollection:kMPDBCollectionNamePeople usingBlock:^(NSString *key, id profile, BOOL *stop) {

            if (profile[@"$properties"][@"$transactions"])
            {
                NSDictionary *transactions = profile[@"$properties"][@"$transactions"];
                for (NSDictionary *t in transactions)
                {
                    [weakSelf.writer writeField:profile[@"$distinct_id"]];
                    [weakSelf.writer writeField:t[@"$amount"]];
                    [weakSelf.writer writeField:t[@"$time"]];
                    for (NSString *key in keys)
                    {
                        if (t[key])
                        {
                            [weakSelf.writer writeField:t[key]];
                        } else
                        {
                            [weakSelf.writer writeField:@""];
                        }
                    }
                    [weakSelf.writer finishLine];
                    rows++;
                }
            }
        }];
    }];
    
    // Notify ViewController
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingEnded object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatCSV, kMPFileWritingExportObjectKey:kMPExportObjectTransactions,kMPFileWritingExportTypeKey:kMPExportTypeTransactions,kMPFileWritingCount:@(rows)}];
    
    // Notify User
    [self postUserNotificationWithTitle:@"CSV Export Complete" andInfoText:[NSString stringWithFormat:@"%i transactions exported", rows]];
}

- (void)peopleFromEvents
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingBegan object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatCSV}];
    
    AppDelegate *appDelegate = (AppDelegate *) [[NSApplication sharedApplication] delegate];
    __weak CSVWriter *weakSelf = self;
    __block NSMutableSet *distinctIDs = [NSMutableSet set];
    __block NSArray *properties = [NSArray array];
    __block int rows = 0;
    
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [transaction enumerateKeysAndObjectsInCollection:kMPDBCollectionNameEvents usingBlock:^(NSString *key, id object, BOOL *stop) {
            if (object[@"properties"][@"distinct_id"])
            {
                [distinctIDs addObject:object[@"properties"][@"distinct_id"]];
            }
        }];
    }];
    
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        properties = [transaction objectForKey:kMPDBPropertiesKeyPeople inCollection:kMPDBCollectionNamePropertiesPeople];
    }];
    
    [self writeHeadersForType:@"people" withProperties:properties];
    
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        for (NSString *distinctID in distinctIDs)
        {
            if ([transaction hasObjectForKey:distinctID inCollection:kMPDBCollectionNamePeople])
            {
                NSDictionary *profile = [transaction objectForKey:distinctID inCollection:kMPDBCollectionNamePeople];
                [weakSelf.writer writeField:profile[@"$distinct_id"]];
                for (NSString *prop in properties)
                {
                    if (profile[@"$properties"][prop])
                    {
                        [weakSelf.writer writeField:profile[@"$properties"][prop]];
                    } else
                    {
                        [weakSelf.writer writeField:@""];
                    }
                }
                [weakSelf.writer finishLine];
                rows++;
            }
        }
    }];
    
    // Notify ViewController
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingEnded object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatCSV,kMPFileWritingExportObjectKey:kMPExportObjectPeople,kMPFileWritingExportTypeKey:kMPExportTypePeopleFromEvents,kMPFileWritingCount:@(rows)}];
    
    // Notify User
    [self postUserNotificationWithTitle:@"CSV Export Complete" andInfoText:[NSString stringWithFormat:@"%i profiles exported", rows]];
}

#pragma mark - Utility Methods

- (void)updateStatusWithString:(NSAttributedString *)status
{
    NSDictionary *statusInfo = @{kMPUserInfoKeyType:kMPStatusUpdate,kMPUserInfoKeyStatus:status};
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPStatusUpdate object:nil userInfo:statusInfo];
}

- (void)postUserNotificationWithTitle:(NSString *)title andInfoText:(NSString *)infoText
{
    // Display desktop user notification
    NSUserNotification *userNotification = [[NSUserNotification alloc] init];
    userNotification.title = title;
    userNotification.informativeText = infoText;
    userNotification.soundName = NSUserNotificationDefaultSoundName;
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:userNotification];
}

@end
