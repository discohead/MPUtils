//
//  CSVParser.m
//  MPUtils
//
//  Created by Jared McFarland on 3/29/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import "CSVParser.h"
#import "CHCSVParser.h"
#import "AppDelegate.h"
#import "MPUConstants.h"
#import <YapDatabase/YapDatabase.h>

@interface CSVParser ()

@property (strong, nonatomic) CHCSVWriter *writer;
@property (strong, nonatomic) YapDatabaseConnection *concurrentConnection;

@end

@implementation CSVParser

- (YapDatabaseConnection *)concurrentConnection
{
    if (!_concurrentConnection)
    {
        AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        _concurrentConnection = [appDelegate.database newConnection];
    }
    return _concurrentConnection;
}

#pragma mark - Convenience Initializer

- (instancetype)initForWritingToFile:(NSString *)filePath
{
    [self updateStatusWithString:[NSString stringWithFormat:@"CSV writer path = %@",filePath]];
    CSVParser *parser = [[CSVParser alloc] init];
    parser.writer = [[CHCSVWriter alloc] initForWritingToCSVFile:filePath];
    return parser;
}

#pragma mark - Main Writing Methods

- (void)eventsToCSVWithPeopleProperties:(BOOL)peopleProperties
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPCSVWritingBegan object:nil];
    __weak CSVParser *weakSelf = self;
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    __block NSArray *eventProps = [NSArray array];
    __block NSArray *peopleProps = [NSArray array];
    NSMutableArray *headers = [NSMutableArray array];
    
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
            [weakSelf writeEvent:event withProperties:eventProps];
            
            if (peopleProperties)
            {
                [weakSelf writePeoplePropertiesForEvent:event withProperties:peopleProps usingTransaction:weakTransaction];
            }
            
            [weakSelf.writer finishLine];
        }];
    }];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPCSVWritingEnded object:nil];
}


- (void)peopleToCSV
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPCSVWritingBegan object:nil];
    __weak CSVParser *weakSelf = self;
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    __block NSArray *peopleProps = [NSArray array];
    
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        peopleProps = [transaction objectForKey:kMPDBPropertiesKeyPeople inCollection:kMPDBCollectionNamePropertiesPeople];
    }];
    
    [self writeHeadersForType:@"people" withProperties:peopleProps];
    
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [transaction enumerateKeysAndObjectsInCollection:kMPDBCollectionNamePeople usingBlock:^(NSString *key, id profile, BOOL *stop) {
            [weakSelf writeProfile:profile withProperties:peopleProps];
        }];
    }];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPCSVWritingEnded object:nil];
    
}

- (void)writePeoplePropertiesForEvent:(NSDictionary *)event withProperties:(NSArray *)peopleProperties usingTransaction:(YapDatabaseReadTransaction *)transaction
{
    __weak CSVParser *weakSelf = self;
    
    if (event[@"properties"][@"distinct_id"])
    {
        if ([transaction hasObjectForKey:event[@"properties"][@"distinct_id"] inCollection:kMPDBCollectionNamePeople])
        {
            NSDictionary *profile = [transaction objectForKey:event[@"properties"][@"distinct_id"] inCollection:kMPDBCollectionNamePeople];
            
            for (NSString *peopleProp in peopleProperties)
            {
                if (profile[@"$properties"][peopleProp])
                {
                    [weakSelf.writer writeField:peopleProp];
                } else
                {
                    [weakSelf.writer writeField:@""];
                }
            }
        }
    }
}

- (void)writeEvent:(NSDictionary *)event withProperties:(NSArray *)properties
{
    __weak CSVParser *weakSelf = self;
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
    
    // We do not finish line here, allowing the addition of People properties
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
    __weak CSVParser *weakSelf = self;
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
- (void)transactionsToCSV
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPCSVWritingBegan object:nil];
    __weak CSVParser *weakSelf = self;
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
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
                }
            }
        }];
    }];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPCSVWritingEnded object:nil];
}

- (void)peopleFromEventsToCSV
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPCSVWritingBegan object:nil];
    
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    __weak CSVParser *weakSelf = self;
    __block NSMutableSet *distinctIDs = [NSMutableSet set];
    __block NSArray *properties = [NSArray array];
    
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
            }
            [weakSelf.writer finishLine];
        }
    }];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPCSVWritingEnded object:nil];
}

#pragma mark - Utility Methods

- (void)updateStatusWithString:(NSString *)status
{
    NSDictionary *statusInfo = @{kMPUserInfoKeyType:kMPStatusUpdate,kMPUserInfoKeyStatus:status};
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPStatusUpdate object:nil userInfo:statusInfo];
}

@end
