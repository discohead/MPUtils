//
//  AppDelegate.m
//  MPUtils
//
//  Created by Jared McFarland on 3/29/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import "AppDelegate.h"
#import "MPUConstants.h"
#import "CSVWriter.h"
#import "JSONWriter.h"
#import "ViewController.h"
#import <YapDatabase/YapDatabase.h>
#import <Mixpanel-OSX-Community/Mixpanel.h>

@interface AppDelegate () <NSOpenSavePanelDelegate>

@property (strong, nonatomic) NSString *basePath;
@property (strong, nonatomic) NSString *databasePath;
@property (weak, nonatomic) NSWindow *mainWindow;

@end

@implementation AppDelegate

- (NSWindow *)mainWindow
{
    return [[NSApplication sharedApplication] mainWindow];
}

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


#pragma mark - Export Menu IBActions

- (IBAction)exportEventsRawToCSV:(NSMenuItem *)sender
{
    NSSavePanel *savePanel = [self makeSavePanelForFileTypes:@[@"csv",@"CSV"]];
    
    [savePanel beginSheetModalForWindow:self.mainWindow completionHandler:^(NSInteger result) {
        [savePanel orderOut:nil];
        
        if (result == NSFileHandlingPanelOKButton)
        {
            [self exportOfType:kMPExportTypeEventsRaw usingWriter:[[CSVWriter alloc] initForWritingToFile:savePanel.URL.path]];
        }
    }];
    
}

- (IBAction)exportEventsRawToJSON:(NSMenuItem *)sender
{
    NSSavePanel *savePanel = [self makeSavePanelForFileTypes:@[@"json",@"JSON"]];
    
    [savePanel beginSheetModalForWindow:self.mainWindow completionHandler:^(NSInteger result) {
        [savePanel orderOut:nil];
        
        if (result == NSFileHandlingPanelOKButton)
        {
            [self exportOfType:kMPExportTypeEventsRaw usingWriter:[[JSONWriter alloc] initForWritingToFile:savePanel.URL.path]];
        }
    }];
}

- (IBAction)exportEventsCombinedToCSV:(NSMenuItem *)sender
{
    NSSavePanel *savePanel = [self makeSavePanelForFileTypes:@[@"csv",@"CSV"]];
    
    [savePanel beginSheetModalForWindow:self.mainWindow completionHandler:^(NSInteger result) {
        [savePanel orderOut:nil];
        
        if (result == NSFileHandlingPanelOKButton)
        {
            [self exportOfType:kMPExportTypeEventsCombined usingWriter:[[CSVWriter alloc] initForWritingToFile:savePanel.URL.path]];
        }
    }];
}

- (IBAction)exportEventsCombinedToJSON:(NSMenuItem *)sender
{
    NSSavePanel *savePanel = [self makeSavePanelForFileTypes:@[@"json",@"JSON"]];
    
    [savePanel beginSheetModalForWindow:self.mainWindow completionHandler:^(NSInteger result) {
        [savePanel orderOut:nil];
        
        if (result == NSFileHandlingPanelOKButton)
        {
            [self exportOfType:kMPExportTypeEventsCombined usingWriter:[[JSONWriter alloc] initForWritingToFile:savePanel.URL.path]];
        }
    }];
}

- (IBAction)exportPeopleProfilesToCSV:(NSMenuItem *)sender
{
    NSSavePanel *savePanel = [self makeSavePanelForFileTypes:@[@"csv",@"CSV"]];
    
    [savePanel beginSheetModalForWindow:self.mainWindow completionHandler:^(NSInteger result) {
        [savePanel orderOut:nil];
        
        if (result == NSFileHandlingPanelOKButton)
        {
            [self exportOfType:kMPExportTypePeopleProfiles usingWriter:[[CSVWriter alloc] initForWritingToFile:savePanel.URL.path]];
        }
    }];
}

- (IBAction)exportPeopleProfilesToJSON:(NSMenuItem *)sender
{
    NSSavePanel *savePanel = [self makeSavePanelForFileTypes:@[@"json",@"JSON"]];
    
    [savePanel beginSheetModalForWindow:self.mainWindow completionHandler:^(NSInteger result) {
        [savePanel orderOut:nil];
        
        if (result == NSFileHandlingPanelOKButton)
        {
            [self exportOfType:kMPExportTypePeopleProfiles usingWriter:[[JSONWriter alloc] initForWritingToFile:savePanel.URL.path]];
        }
    }];
}

- (IBAction)exportPeopleFromEventsToCSV:(NSMenuItem *)sender
{
    NSSavePanel *savePanel = [self makeSavePanelForFileTypes:@[@"csv",@"CSV"]];
    
    [savePanel beginSheetModalForWindow:self.mainWindow completionHandler:^(NSInteger result) {
        [savePanel orderOut:nil];
        
        if (result == NSFileHandlingPanelOKButton)
        {
            [self exportOfType:kMPExportTypePeopleFromEvents usingWriter:[[CSVWriter alloc] initForWritingToFile:savePanel.URL.path]];
        }
    }];
}

- (IBAction)exportPeopleFromEventsToJSON:(NSMenuItem *)sender
{
    NSSavePanel *savePanel = [self makeSavePanelForFileTypes:@[@"json",@"JSON"]];
    
    [savePanel beginSheetModalForWindow:self.mainWindow completionHandler:^(NSInteger result) {
        [savePanel orderOut:nil];
        
        if (result == NSFileHandlingPanelOKButton)
        {
            [self exportOfType:kMPExportTypePeopleFromEvents usingWriter:[[JSONWriter alloc] initForWritingToFile:savePanel.URL.path]];
        }
    }];
}

- (IBAction)exportTransactionsToCSV:(NSMenuItem *)sender
{
    NSSavePanel *savePanel = [self makeSavePanelForFileTypes:@[@"csv",@"CSV"]];
    
    [savePanel beginSheetModalForWindow:self.mainWindow completionHandler:^(NSInteger result) {
        [savePanel orderOut:nil];
        
        if (result == NSFileHandlingPanelOKButton)
        {
            [self exportOfType:kMPExportTypeTransactions usingWriter:[[CSVWriter alloc] initForWritingToFile:savePanel.URL.path]];
        }
    }];
}

- (void)exportOfType:(NSString *)exportType usingWriter:(id)writer
{
    NSString *format = [NSString string];
    dispatch_queue_t exportQueue = dispatch_queue_create("export", NULL);
    
    if ([writer isKindOfClass:[CSVWriter class]])
    {
        writer = (CSVWriter *)writer;
        format = @"CSV";
        
    } else if ([writer isKindOfClass:[JSONWriter class]])
    {
        writer = (JSONWriter *)writer;
        format = @"JSON";
    }
    
    void (^exportBlock)() = ^void() {};
    
    if ([exportType isEqualToString:kMPExportTypeEventsRaw])
    {
        exportBlock = ^void() {[writer eventsWithPeopleProperties:NO];};

    } else if ([exportType isEqualToString:kMPExportTypeEventsCombined])
    {
        exportBlock = ^void() {[writer eventsWithPeopleProperties:YES];};
        
    } else if ([exportType isEqualToString:kMPExportTypePeopleProfiles])
    {
        exportBlock = ^void() {[writer peopleProfiles];};
        
    } else if ([exportType isEqualToString:kMPExportTypePeopleFromEvents])
    {
        exportBlock = ^void() {[writer peopleFromEvents];};
        
    } else if ([exportType isEqualToString:kMPExportTypeTransactions])
    {
        exportBlock = ^void() {[writer transactions];};
    }
    
    dispatch_async(exportQueue, exportBlock);
    
    [self incrementMixpanelPropertiesForExportofType:exportType andFormat:format];
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

- (NSSavePanel *)makeSavePanelForFileTypes:(NSArray *)fileTypes;
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.canCreateDirectories = YES;
    savePanel.delegate = self;
    savePanel.allowedFileTypes = fileTypes;
    savePanel.directoryURL = [NSURL URLWithString:self.basePath];
    
    return savePanel;
}

- (void)incrementMixpanelPropertiesForExportofType:(NSString *)exportType andFormat:(NSString *)format
{
    Mixpanel *mixpanel = [Mixpanel sharedInstance];
    NSString *specificCount = [NSString stringWithFormat:@"%@ %@ Exports", exportType, format];
    NSString *formatCount = [NSString stringWithFormat:@"Total %@ Exports", format];
    NSString *typeCount = [NSString stringWithFormat:@"Total %@ Exports", exportType];
    [mixpanel.people increment:@{specificCount:@1,formatCount:@1,typeCount:@1, @"Total Exports":@1}];
    [mixpanel registerSuperProperties:@{specificCount:@([[[[mixpanel currentSuperProperties] objectsForKeys:@[specificCount] notFoundMarker:@0] objectAtIndex:0] integerValue] + 1),
                                        formatCount:@([[[[mixpanel currentSuperProperties] objectsForKeys:@[formatCount] notFoundMarker:@0] objectAtIndex:0] integerValue] + 1),
                                        typeCount:@([[[[mixpanel currentSuperProperties] objectsForKeys:@[typeCount] notFoundMarker:@0] objectAtIndex:0] integerValue] + 1),
                                        @"Total Exports":@([[[[mixpanel currentSuperProperties] objectsForKeys:@[@"Total Exports"] notFoundMarker:@0] objectAtIndex:0] integerValue] + 1)}];
}
@end
