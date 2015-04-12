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
#import <CouchbaseLite/CouchbaseLite.h>

@interface CSVParser ()

@property (strong, nonatomic) CHCSVWriter *writer;

@end

@implementation CSVParser

- (instancetype)initForWritingToFile:(NSString *)filePath
{
    [self updateStatusWithString:[NSString stringWithFormat:@"CSV writer path = %@",filePath]];
    CSVParser *parser = [[CSVParser alloc] init];
    parser.writer = [[CHCSVWriter alloc] initForWritingToCSVFile:filePath];
    return parser;
}

- (void)eventsToCSVWithPeopleProperties:(BOOL)peopleProperties
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPCSVWritingBegan object:nil];
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    __block CBLManager *manager = appDelegate.manager;
    __block CBLDatabase *database = appDelegate.database;
    
    dispatch_async(manager.dispatchQueue, ^{
        NSError *databaseError;
        if (!databaseError)
        {
            CBLView *eventPropsView = [database viewNamed:kMPCBLViewNameEventProperties];
            CBLQuery *eventPropsQuery = [eventPropsView createQuery];
            NSError *eventPropsError;
            CBLQueryEnumerator *eventPropsEnum = [eventPropsQuery run:&eventPropsError];
            NSMutableArray *eventPropsArray = [NSMutableArray array];
            if ([eventPropsEnum count])
            {
                eventPropsArray = [[[eventPropsEnum rowAtIndex:0] value] mutableCopy];
            }
            
            [eventPropsArray insertObject:kMPCBLEventDocumentKeyEvent atIndex:0];
            
            for (NSString *propKey in eventPropsArray)
            {
                [self.writer writeField:propKey];
            }
            [eventPropsArray removeObjectAtIndex:0];
            
            NSArray *peoplePropsArray = [NSArray array];
            if (peopleProperties)
            {
                CBLView *peoplePropsView = [database viewNamed:kmPCBlViewNamePeopleProperties];
                CBLQuery *peoplePropsQuery = [peoplePropsView createQuery];
                NSError *peoplePropsError;
                CBLQueryEnumerator *peoplePropsEnum = [peoplePropsQuery run:&peoplePropsError];
                if (peoplePropsEnum.count)
                {
                    peoplePropsArray = [[peoplePropsEnum rowAtIndex:0] value];
                    for (NSString *profileKey in peoplePropsArray)
                    {
                        [self.writer writeField:[NSString stringWithFormat:@"profile_%@",profileKey]];
                    }
                }
            }
            [self.writer finishLine];
            
            CBLView *eventsView = [database viewNamed:kMPCBLViewNameEvents];
            NSError *queryError;
            CBLQuery *query = [eventsView createQuery];
            query.mapOnly = YES;
            CBLQueryEnumerator *queryEnumerator = [query run:&queryError];
            for (CBLQueryRow *eventRow in queryEnumerator)
            {
                CBLDocument *eventDoc = eventRow.document;
                NSDictionary *eventDocProps = eventDoc.properties;
                [self.writer writeField:eventDocProps[kMPCBLEventDocumentKeyEvent]];
                NSDictionary *eventProps = eventDocProps[kMPCBLEventDocumentKeyProperties];
                
                for (NSString *eventProp in eventPropsArray)
                {
                    if (eventProps[eventProp])
                    {
                        [self.writer writeField:eventProps[eventProp]];
                    } else
                    {
                        [self.writer writeField:@""];
                    }
                }
                
                if (peopleProperties)
                {
                    CBLDocument *peopleDoc = [database existingDocumentWithID:eventProps[@"distinct_id"]];
                    NSDictionary *peoplePropValues = [NSDictionary dictionary];
                    if (peopleDoc)
                    {
                        peoplePropValues = peopleDoc.properties[kMPCBLPeopleDocumentKeyProperties];
                    }
                    
                    for (NSString *key in peoplePropsArray)
                    {
                        if (peoplePropValues[key])
                        {
                            [self.writer writeField:peoplePropValues[key]];
                        } else
                        {
                            [self.writer writeField:@""];
                        }
                    }
                }
                [self.writer finishLine];
            }
        } else
        {
            [self updateStatusWithString:[NSString stringWithFormat:@"Error loading database. Error message: %@", databaseError.localizedDescription]];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kMPCSVWritingEnded object:nil];
    });
    
    
}


- (void)peopleToCSV
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPCSVWritingBegan
                                                        object:nil];
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    __block CBLManager *manager = appDelegate.manager;
    
    dispatch_async(manager.dispatchQueue, ^{
        NSError *databaseError;
        CBLDatabase *database = [manager databaseNamed:kMPCBLDatabaseName error:&databaseError];
        NSUInteger count = 0;
        if (!databaseError)
        {
            CBLView *peoplePropsView = [database viewNamed:kmPCBlViewNamePeopleProperties];
            CBLQuery *peoplePropsQuery = [peoplePropsView createQuery];
            NSError *peoplePropsError;
            CBLQueryEnumerator *peoplePropsEnum = [peoplePropsQuery run:&peoplePropsError];
            NSMutableArray *propsArray = [NSMutableArray array];
            if (peoplePropsEnum.count)
            {
                propsArray = [[[peoplePropsEnum rowAtIndex:0] value] mutableCopy];
            }
            [propsArray insertObject:kMPCBLPeopleDocumentKeyDistinctID atIndex:0];
            [self.writer writeLineOfFields:propsArray];
            [propsArray removeObjectAtIndex:0];
            CBLView *peopleView = [database viewNamed:kMPCBLViewNamePeople];
            NSError *queryError;
            CBLQuery *query = [peopleView createQuery];
            query.mapOnly = YES;
            CBLQueryEnumerator *queryEnumerator = [query run:&queryError];
            count = queryEnumerator.count;
            for (CBLQueryRow *peopleRow in queryEnumerator)
            {
                CBLDocument *peopleDoc = peopleRow.document;
                NSDictionary *peopleDocProps = peopleDoc.properties;
                [self.writer writeField:peopleDocProps[kMPCBLPeopleDocumentKeyDistinctID]];
                NSDictionary *peopleProps = peopleDocProps[kMPCBLPeopleDocumentKeyProperties];
                
                for (NSString *peopleProp in propsArray)
                {
                    if (peopleProps[peopleProp])
                    {
                        [self.writer writeField:peopleProps[peopleProp]];
                    } else
                    {
                        [self.writer writeField:@""];
                    }
                }
                [self.writer finishLine];
            }
        } else
        {
            [self updateStatusWithString:[NSString stringWithFormat:@"Error loading database. Error message: %@", databaseError.localizedDescription]];
        }
        [self updateStatusWithString:[NSString stringWithFormat:@"%lu People profiles written to CSV",count]];
        [[NSNotificationCenter defaultCenter] postNotificationName:kMPCSVWritingEnded object:nil];
    });
    
}
- (void)transactionsToCSV
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPCSVWritingBegan object:nil];
    
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    __block CBLManager *manager = appDelegate.manager;
    
    dispatch_async(manager.dispatchQueue, ^{
        NSError *dbError;
        CBLDatabase *database = [manager databaseNamed:kMPCBLDatabaseName error:&dbError];
        if (!dbError)
        {
            CBLView *transactionView = [database viewNamed:kMPCBLViewNameTransactions];
            NSError *keyQueryError;
            CBLQuery *keyQuery = [transactionView createQuery];
            CBLQueryEnumerator *keyQueryEnum = [keyQuery run:&keyQueryError];
            NSMutableArray *transactionKeys;
            if (!keyQueryError)
            {
                if (keyQueryEnum.count)
                {
                    transactionKeys = [[[keyQueryEnum rowAtIndex:0] value] mutableCopy];
                    [transactionKeys insertObject:kMPCBLPeopleDocumentKeyDistinctID atIndex:0];
                }
            } else
            {
                [self updateStatusWithString:[NSString stringWithFormat:@"Error querying transaction properties. Error message: %@", keyQueryError.localizedDescription]];
            }
            [self.writer writeLineOfFields:transactionKeys];
            [transactionKeys removeObjectAtIndex:0];
            keyQuery.mapOnly = YES;
            NSError *transactionQueryError;
            CBLQueryEnumerator *transactionQueryEnum = [keyQuery run:&transactionQueryError];
            if (!transactionQueryError)
            {
                for (CBLQueryRow *transactions in transactionQueryEnum)
                {
                    for (NSDictionary *transaction in transactions.value)
                    {
                        [self.writer writeField:transactions.key];
                        for (NSString *propKey in transactionKeys)
                        {
                            if (transaction[propKey])
                            {
                                [self.writer writeField:transaction[propKey]];
                            } else
                            {
                                [self.writer writeField:@""];
                            }
                        }
                        [self.writer finishLine];
                    }
                }
            } else
            {
                [self updateStatusWithString:[NSString stringWithFormat:@"Error querying transactions. Error message: %@", transactionQueryError.localizedDescription]];
            }
        } else
        {
            [self updateStatusWithString:[NSString stringWithFormat:@"Error loading database. Error message: %@", dbError.localizedDescription]];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kMPCSVWritingEnded object:nil];
    });
}

- (void)peopleFromEventsToCSV
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPCSVWritingBegan object:nil];
    
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    __block CBLManager *manager = appDelegate.manager;
    
    dispatch_async(manager.dispatchQueue, ^{
        NSError *dbError;
        CBLDatabase *database = [manager databaseNamed:kMPCBLDatabaseName error:&dbError];
        if (!dbError)
        {
            CBLView *distinctIDView = [database viewNamed:kMPCBLViewNameEventDistinctIDs];
            CBLQuery *distinctIDQuery = [distinctIDView createQuery];
            NSError *queryError;
            CBLQueryEnumerator *distinctIDEnum = [distinctIDQuery run:&queryError];
            if (!queryError)
            {
                if (distinctIDEnum.count)
                {
                    CBLView *peoplePropsView = [database viewNamed:kmPCBlViewNamePeopleProperties];
                    CBLQuery *peoplePropsQuery = [peoplePropsView createQuery];
                    NSError *peoplePropsError;
                    CBLQueryEnumerator *peoplePropsEnum = [peoplePropsQuery run:&peoplePropsError];
                    NSMutableArray *propsArray = [NSMutableArray array];
                    if (peoplePropsEnum.count)
                    {
                        propsArray = [[[peoplePropsEnum rowAtIndex:0] value] mutableCopy];
                    }
                    [propsArray insertObject:kMPCBLPeopleDocumentKeyDistinctID atIndex:0];
                    [self.writer writeLineOfFields:propsArray];
                    [propsArray removeObjectAtIndex:0];                    CBLQueryRow *distinctIDs = [distinctIDEnum rowAtIndex:0];
                    for (NSString *distinctID in distinctIDs.value)
                    {
                        [self.writer writeField:distinctID];
                        CBLDocument *profileDoc = [database documentWithID:distinctID];
                        NSDictionary *properties = profileDoc[kMPCBLPeopleDocumentKeyProperties];
                        for (NSString *propKey in propsArray)
                        {
                            if (properties[propKey])
                            {
                                [self.writer writeField:properties[propKey]];
                            } else
                            {
                                [self.writer writeField:@""];
                            }
                        }
                        [self.writer finishLine];
                    }
                }
            } else
            {
                [self updateStatusWithString:[NSString stringWithFormat:@"Error querying for distinct ID's from Events. Error message: %@",queryError.localizedDescription]];
            }
        } else
        {
            [self updateStatusWithString:[NSString stringWithFormat:@"Error loading database. Error message: %@", dbError.localizedDescription]];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kMPCSVWritingEnded object:nil];
    });
}

- (void)updateStatusWithString:(NSString *)status
{
    NSDictionary *statusInfo = @{kMPUserInfoKeyType:kMPStatusUpdate,kMPUserInfoKeyStatus:status};
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPStatusUpdate object:nil userInfo:statusInfo];
}

@end
