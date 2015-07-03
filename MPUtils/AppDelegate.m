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
#import <YapDatabase/YapDatabase.h>
#import <Mixpanel-OSX-Community/Mixpanel.h>

@interface AppDelegate () <NSOpenSavePanelDelegate>

@property (strong, nonatomic) NSString *basePath;
@property (strong, nonatomic) NSString *databasePath;

@end

@implementation AppDelegate

- (NSString *)basePath {
    
    if (!_basePath)
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSFileManager *fileManager= [NSFileManager defaultManager];
        NSString *mputilsDirectory = [documentsDirectory stringByAppendingPathComponent:@"MPUtils"];
        NSError *error = nil;
        if(![fileManager createDirectoryAtPath:mputilsDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
            // An error has occurred
            [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"Failed to create directory \"%@\". Error: %@ - Falling back to ~/Documents", mputilsDirectory, error.localizedDescription] attributes:@{NSForegroundColorAttributeName:[NSColor redColor]}]];
            _basePath = documentsDirectory;
        } else {
            _basePath = mputilsDirectory;
        }
    }
    return _basePath;
}

- (NSString *)databasePath
{
    if (!_databasePath)
    {
        NSFileManager *fileManager= [NSFileManager defaultManager];
        NSString *databaseDirectory = [self.basePath stringByAppendingPathComponent:@"database"];
        NSError *error = nil;
        if(![fileManager createDirectoryAtPath:databaseDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
            // An error has occurred
            [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"Failed to create directory \"%@\". Error: %@ - Falling back to ~/Documents", databaseDirectory, error.localizedDescription] attributes:@{NSForegroundColorAttributeName:[NSColor redColor]}]];
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = [paths objectAtIndex:0];
            _databasePath = [documentsDirectory stringByAppendingPathComponent:@"database.sqlite"];
        } else {
            _databasePath = [databaseDirectory stringByAppendingPathComponent:@"database.sqlite"];
        }
    }
    return _databasePath;
}

- (YapDatabase *)sharedYapDatabase {
    static YapDatabase *_sharedYapDatabase = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedYapDatabase = [[YapDatabase alloc]initWithPath:self.databasePath];
    });
    
    return _sharedYapDatabase;
}

#pragma mark - App Life Cycle

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    // Setup Database and connection
    self.database = [self sharedYapDatabase];
    [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"Database created at %@",[[NSURL fileURLWithPath:self.databasePath]absoluteString]]]];
    self.connection = [self.database newConnection];
    
    //Ensure we're starting with a clean database
    [self updateStatusWithString:[[NSAttributedString alloc] initWithString:@"Initializing Database..." attributes:@{NSForegroundColorAttributeName:[NSColor grayColor]}]];
    [self.connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [transaction removeAllObjectsInAllCollections];
    }];
    [self updateStatusWithString:[[NSAttributedString alloc] initWithString:@"Database Initialized!" attributes:@{NSForegroundColorAttributeName:[NSColor grayColor]}]];
    
    Mixpanel *mixpanel = [Mixpanel sharedInstanceWithToken:@"412b93fb1e3b8204fedf7cdc22d2b570"];
    [mixpanel flush];
    mixpanel.flushInterval = 30.0;
    [mixpanel identify:mixpanel.distinctId];
    NSDictionary *created = @{@"$created":[NSDate date]};
    [mixpanel.people setOnce:created];
    [mixpanel registerSuperPropertiesOnce:created];
    [mixpanel.people increment:@{@"App Opens":@1}];
    [mixpanel registerSuperProperties:@{@"App Opens":@([[[[mixpanel currentSuperProperties] objectsForKeys:@[@"App Opens"] notFoundMarker:@0] objectAtIndex:0] integerValue] + 1)}];
    [mixpanel track:@"$app_open"];
    [mixpanel flush];

}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    
}


#pragma mark - Export Menu IBActions

- (IBAction)exportEvents:(NSMenuItem *)sender {
    NSSavePanel *savePanel = [self makeSavePanel];
    
    NSWindow *window = [NSApplication sharedApplication].windows[0];
    
    [savePanel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
        [savePanel orderOut:nil];
        
        if (result == NSFileHandlingPanelOKButton)
        {
            CSVParser *parser = [[CSVParser alloc] initForWritingToFile:savePanel.URL.path];
            // Export->Events->Raw
            if (sender.tag == 0)
            {
                Mixpanel *mixpanel = [Mixpanel sharedInstance];
                [mixpanel.people increment:@{@"Raw Event CSV Exports":@1,@"Total CSV Exports":@1}];
                [mixpanel registerSuperProperties:@{@"Raw Event CSV Exports":@([[[[mixpanel currentSuperProperties] objectsForKeys:@[@"Raw Event CSV Exports"] notFoundMarker:@0] objectAtIndex:0] integerValue] + 1)}];
                [mixpanel registerSuperProperties:@{@"Total CSV Exports":@([[[[mixpanel currentSuperProperties] objectsForKeys:@[@"Total CSV Exports"] notFoundMarker:@0] objectAtIndex:0] integerValue] + 1)}];
                
                dispatch_async(dispatch_queue_create("csv", NULL), ^{
                    [parser eventsToCSVWithPeopleProperties:NO];
                });
                
            // Export->Events->w/People Props
            } else if (sender.tag == 1)
            {
                dispatch_async(dispatch_queue_create("csv", NULL), ^{
                    Mixpanel *mixpanel = [Mixpanel sharedInstance];
                    [mixpanel.people increment:@{@"Combined Event CSV Exports":@1,@"Total CSV Exports":@1}];
                    [mixpanel registerSuperProperties:@{@"Combined Event CSV Exports":@([[[[mixpanel currentSuperProperties] objectsForKeys:@[@"Combined Event CSV Exports"] notFoundMarker:@0] objectAtIndex:0] integerValue] + 1)}];
                    [mixpanel registerSuperProperties:@{@"Total CSV Exports":@([[[[mixpanel currentSuperProperties] objectsForKeys:@[@"Total CSV Exports"] notFoundMarker:@0] objectAtIndex:0] integerValue] + 1)}];
                    
                    [parser eventsToCSVWithPeopleProperties:YES];
                });
            }
        }
    }];

}

- (IBAction)exportPeopleProfiles:(NSMenuItem *)sender {
    NSSavePanel *savePanel = [self makeSavePanel];
    
    NSWindow *window = [NSApplication sharedApplication].windows[0];
    
    [savePanel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
        [savePanel orderOut:nil];
        
        // Export->People->Profiles
        if (result == NSFileHandlingPanelOKButton)
        {
            Mixpanel *mixpanel = [Mixpanel sharedInstance];
            [mixpanel.people increment:@{@"People Profile CSV Exports":@1,@"Total CSV Exports":@1}];
            [mixpanel registerSuperProperties:@{@"People Profile CSV Exports":@([[[[mixpanel currentSuperProperties] objectsForKeys:@[@"People Profile CSV Exports"] notFoundMarker:@0] objectAtIndex:0] integerValue] + 1)}];
            [mixpanel registerSuperProperties:@{@"Total CSV Exports":@([[[[mixpanel currentSuperProperties] objectsForKeys:@[@"Total CSV Exports"] notFoundMarker:@0] objectAtIndex:0] integerValue] + 1)}];
            
            CSVParser *parser = [[CSVParser alloc] initForWritingToFile:savePanel.URL.path];
            dispatch_async(dispatch_queue_create("csv", NULL), ^{
                [parser peopleToCSV];
            });
        }
    }];
}

- (IBAction)exportTransactions:(NSMenuItem *)sender {
    NSSavePanel *savePanel = [self makeSavePanel];
    
    NSWindow *window = [NSApplication sharedApplication].windows[0];
    
    [savePanel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
        [savePanel orderOut:nil];
        
        // Export->People->Transactions
        if (result == NSFileHandlingPanelOKButton)
        {
            Mixpanel *mixpanel = [Mixpanel sharedInstance];
            [mixpanel.people increment:@{@"Transactions CSV Exports":@1,@"Total CSV Exports":@1}];
            [mixpanel registerSuperProperties:@{@"Transactions CSV Exports":@([[[[mixpanel currentSuperProperties] objectsForKeys:@[@"Transactions CSV Exports"] notFoundMarker:@0] objectAtIndex:0] integerValue] + 1)}];
            [mixpanel registerSuperProperties:@{@"Total CSV Exports":@([[[[mixpanel currentSuperProperties] objectsForKeys:@[@"Total CSV Exports"] notFoundMarker:@0] objectAtIndex:0] integerValue] + 1)}];
            
            CSVParser *parser = [[CSVParser alloc] initForWritingToFile:savePanel.URL.path];
            dispatch_async(dispatch_queue_create("csv", NULL), ^{
                [parser transactionsToCSV];
            });
        }
    }];
}

- (IBAction)exportPeopleFromEvents:(NSMenuItem *)sender {
    NSSavePanel *savePanel = [self makeSavePanel];
    
    NSWindow *window = [NSApplication sharedApplication].windows[0];
    
    [savePanel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
        [savePanel orderOut:nil];
        
        // Export->People->From Events
        if (result == NSFileHandlingPanelOKButton)
        {
            Mixpanel *mixpanel = [Mixpanel sharedInstance];
            [mixpanel.people increment:@{@"People From Events CSV Exports":@1,@"Total CSV Exports":@1}];
            [mixpanel registerSuperProperties:@{@"People From Events CSV Exports":@([[[[mixpanel currentSuperProperties] objectsForKeys:@[@"People From Events CSV Exports"] notFoundMarker:@0] objectAtIndex:0] integerValue] + 1)}];
            [mixpanel registerSuperProperties:@{@"Total CSV Exports":@([[[[mixpanel currentSuperProperties] objectsForKeys:@[@"Total CSV Exports"] notFoundMarker:@0] objectAtIndex:0] integerValue] + 1)}];
            
            CSVParser *parser = [[CSVParser alloc] initForWritingToFile:savePanel.URL.path];
            dispatch_async(dispatch_queue_create("csv", NULL), ^{
                [parser peopleFromEventsToCSV];
            });
        }
    }];
}

- (IBAction)launchExportURLinBrowser:(id)sender
{
    Mixpanel *mixpanel = [Mixpanel sharedInstance];
    [mixpanel.people increment:@{@"Documentation Opens":@1}];
    [mixpanel registerSuperProperties:@{@"Documentation Opens":@([[[[mixpanel currentSuperProperties] objectsForKeys:@[@"Documentation Opens"] notFoundMarker:@0] objectAtIndex:0] integerValue] + 1)}];
    [[Mixpanel sharedInstance] track:@"Opened Documentation"];
    
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://mixpanel.com/docs/api-documentation/data-export-api"]];
}

#pragma mark - Utility Methods

- (void)updateStatusWithString:(NSAttributedString *)status
{
    NSDictionary *statusInfo = @{kMPUserInfoKeyType:kMPStatusUpdate,kMPUserInfoKeyStatus:status};
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPStatusUpdate object:nil userInfo:statusInfo];
}

- (NSSavePanel *)makeSavePanel
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.canCreateDirectories = YES;
    savePanel.delegate = self;
    savePanel.allowedFileTypes = @[@"csv",@"CSV"];
    savePanel.directoryURL = [NSURL URLWithString:self.basePath];
    
    return savePanel;
}


@end
