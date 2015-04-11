//
//  AppDelegate.m
//  MPUtils
//
//  Created by Jared McFarland on 3/29/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import "AppDelegate.h"
#import "MPUConstants.h"
#import "CSVParser.h"
#import "ViewController.h"

@interface AppDelegate () <NSOpenSavePanelDelegate>

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    [self setupCouchbaseLite];
}

- (void)setupCouchbaseLite
{
    dispatch_queue_t cblQueue = dispatch_queue_create("cbl", NULL);
    _manager = [[CBLManager alloc] init];
    if (!_manager)
    {
        [self updateStatusWithString:@"Cannot create instance of CBLManager"];
    } else
    {
        [self updateStatusWithString:@"CBLManager created"];
        _manager.dispatchQueue = cblQueue;
        dispatch_sync(cblQueue, ^{
            [self createTheDatabase];
        });
    }
    
}

- (BOOL)createTheDatabase {
    
    NSError *error;
    
    _database = [_manager databaseNamed:kMPCBLDatabaseName error:&error];
    if (!_database)
    {
        [self updateStatusWithString:[NSString stringWithFormat:@"Cannot create database. Error message: %@", error.localizedDescription]];
        return NO;
    } else
    {
        [self createViews];
    }
    
    NSString *databaseLocation = [NSString stringWithFormat:@"%@/Library/Application Support/%@/CouchbaseLite",NSHomeDirectory(),[[NSBundle mainBundle] bundleIdentifier]];
    [self updateStatusWithString:[NSString stringWithFormat:@"Database %@ created at %@",kMPCBLDatabaseName, [NSString stringWithFormat:@"%@/%@%@",databaseLocation, kMPCBLDatabaseName, @".cblite2"]]];
    
    return YES;
}

- (void)createViews
{
    // Raw Events View w/ Count Reduce
    CBLView *eventsView = [_database viewNamed:kMPCBLViewNameEvents];
    [eventsView setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit) {
        if ([doc[kMPCBLDocumentKeyType] isEqualToString:kMPCBLDocumentTypeEvent])
        {
            emit(doc[kMPCBLDocumentKeyID], NULL);
        }
    } reduceBlock:^id(NSArray *keys, NSArray *values, BOOL rereduce) {
        return @(values.count);
    } version:@"3"];
    
    // Distinct ID's of Events view w/ Unique Reduce
    CBLView *eventDistinctIDsView = [_database viewNamed:kMPCBLViewNameEventDistinctIDs];
    [eventDistinctIDsView setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit) {
        if ([doc[kMPCBLDocumentKeyType] isEqualToString:kMPCBLDocumentTypeEvent])
        {
            emit(doc[kMPCBLEventDocumentKeyProperties][kMPCBLEventDocumentKeyDistinctID], NULL);
        }
    } reduceBlock:^id(NSArray *keys, NSArray *values, BOOL rereduce) {
        NSMutableSet *distinctIDSet = [NSMutableSet set];
        for (NSString *distinctID in keys)
        {
            [distinctIDSet addObject:distinctID];
        }
        return [distinctIDSet allObjects];
    } version:@"1"];
    
    CBLView *eventPropertiesView = [_database viewNamed:kMPCBLViewNameEventProperties];
    [eventPropertiesView setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit) {
        if ([doc[kMPCBLDocumentKeyType] isEqualToString:kMPCBLDocumentTypeEvent])
        {
            emit(doc[kMPCBLDocumentKeyID], doc[kMPCBLEventDocumentKeyProperties]);
        }
    } reduceBlock:^id(NSArray *keys, NSArray *values, BOOL rereduce) {
        NSMutableSet *propKeys = [NSMutableSet set];
        for (NSDictionary *props in values)
        {
            [propKeys addObjectsFromArray:props.allKeys];
        }
        return [propKeys allObjects];
    } version:@"1"];
    
    // Raw People View w/ Count Reduce
    CBLView *peopleView = [_database viewNamed:kMPCBLViewNamePeople];
    [peopleView setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit) {
        if ([doc[kMPCBLDocumentKeyType] isEqualToString:kMPCBLDocumentTypePeopleProfile])
        {
            emit(doc[kMPCBLDocumentKeyID], NULL);
        }
    } reduceBlock:^id(NSArray *keys, NSArray *values, BOOL rereduce) {
        return @(values.count);
    } version:@"3"];
    
    // People property keys view
    
    CBLView *peoplPropertiesView = [_database viewNamed:kmPCBlViewNamePeopleProperties];
    [peoplPropertiesView setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit) {
        if ([doc[kMPCBLDocumentKeyType] isEqualToString:kMPCBLDocumentTypePeopleProfile])
        {
            emit(doc[kMPCBLDocumentKeyID], doc[kMPCBLPeopleDocumentKeyProperties]);
        }
    } reduceBlock:^id(NSArray *keys, NSArray *values, BOOL rereduce) {
        NSMutableSet *propKeys = [NSMutableSet set];
        for (NSDictionary *props in values)
        {
            [propKeys addObjectsFromArray:props.allKeys];
        }
        return [propKeys allObjects];
    } version:@"1"];
    
    // $transactions view w/ property keys reduce
    CBLView *transactionsView = [_database viewNamed:kMPCBLViewNameTransactions];
    [transactionsView setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit) {
        if ([doc[kMPCBLDocumentKeyType] isEqualToString:kMPCBLDocumentTypePeopleProfile])
        {
            if (doc[kMPCBLPeopleDocumentKeyProperties][kMPCBLPeopleDocumentKeyTransactions])
            {
                emit(doc[kMPCBLDocumentKeyID],doc[kMPCBLPeopleDocumentKeyProperties][kMPCBLPeopleDocumentKeyTransactions]);
            }
        }
    } reduceBlock:^id(NSArray *keys, NSArray *values, BOOL rereduce) {
        NSMutableSet *propKeySet = [NSMutableSet set];
        for (NSArray *transactions in values)
        {
            for (NSDictionary *transaction in transactions)
            {
                [propKeySet addObjectsFromArray:transaction.allKeys];
            }
        }
        return [propKeySet allObjects];
    } version:@"2"];
    

}

- (IBAction)exportEvents:(NSMenuItem *)sender {
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.canCreateDirectories = YES;
    savePanel.delegate = self;
    savePanel.allowedFileTypes = @[@"csv",@"CSV"];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    savePanel.directoryURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@", paths[0]]];
    
    NSWindow *window = [NSApplication sharedApplication].windows[0];
    
    [savePanel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
        [savePanel orderOut:nil];
        if (result == NSFileHandlingPanelOKButton)
        {
            if (sender.tag == 0)
            {
                CSVParser *parser = [[CSVParser alloc] initForWritingToFile:savePanel.URL.path];
                [parser eventsToCSVWithPeopleProperties:NO];
            } else if (sender.tag == 1)
            {
                CSVParser *parser = [[CSVParser alloc] initForWritingToFile:savePanel.URL.path];
                [parser eventsToCSVWithPeopleProperties:YES];
            }
        }
    }];

}

- (IBAction)exportPeopleProfiles:(NSMenuItem *)sender {
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.canCreateDirectories = YES;
    savePanel.delegate = self;
    savePanel.allowedFileTypes = @[@"csv",@"CSV"];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    savePanel.directoryURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@", paths[0]]];
    
    NSWindow *window = [NSApplication sharedApplication].windows[0];
    
    [savePanel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
        [savePanel orderOut:nil];
        if (result == NSFileHandlingPanelOKButton)
        {
            CSVParser *parser = [[CSVParser alloc] initForWritingToFile:savePanel.URL.path];
            [parser peopleToCSV];
        }
    }];
}

- (IBAction)exportTransactions:(NSMenuItem *)sender {
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.canCreateDirectories = YES;
    savePanel.delegate = self;
    savePanel.allowedFileTypes = @[@"csv",@"CSV"];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    savePanel.directoryURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@", paths[0]]];
    
    NSWindow *window = [NSApplication sharedApplication].windows[0];
    
    [savePanel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
        [savePanel orderOut:nil];
        if (result == NSFileHandlingPanelOKButton)
        {
            CSVParser *parser = [[CSVParser alloc] initForWritingToFile:savePanel.URL.path];
            [parser transactionsToCSV];
        }
    }];
}

- (IBAction)exportPeopleFromEvents:(NSMenuItem *)sender {
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.canCreateDirectories = YES;
    savePanel.delegate = self;
    savePanel.allowedFileTypes = @[@"csv",@"CSV"];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    savePanel.directoryURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@", paths[0]]];
    
    NSWindow *window = [NSApplication sharedApplication].windows[0];
    
    [savePanel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
        [savePanel orderOut:nil];
        if (result == NSFileHandlingPanelOKButton)
        {
            CSVParser *parser = [[CSVParser alloc] initForWritingToFile:savePanel.URL.path];
            [parser peopleFromEventsToCSV];
        }
    }];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
    __block CBLManager *manager = self.manager;
    
    dispatch_sync(manager.dispatchQueue, ^{
        NSError *dbError;
        CBLDatabase *database = [manager databaseNamed:kMPCBLDatabaseName error:&dbError];
        if (!dbError)
        {
            NSError *deleteError;
            [database deleteDatabase:&deleteError];
            if (deleteError)
            {
                NSLog(@"Error deleting database: %@", deleteError.localizedDescription);
            }
        } else
        {
            NSLog(@"Error getting database. Error message: %@", dbError.localizedDescription);
        }
    });
}

- (void)updateStatusWithString:(NSString *)status
{
    NSDictionary *statusInfo = @{kMPUserInfoKeyType:kMPStatusUpdate,kMPUserInfoKeyStatus:status};
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPStatusUpdate object:nil userInfo:statusInfo];
}

@end
