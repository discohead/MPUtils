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

@interface AppDelegate () <NSOpenSavePanelDelegate>

@property (strong, nonatomic) NSString *databasePath;

@end

@implementation AppDelegate

- (NSString *)databasePath
{
    return [NSString stringWithFormat:@"%@/Library/Application Support/%@/YapDatabase/MPUtils.sqlite",NSHomeDirectory(),[[NSBundle mainBundle] bundleIdentifier]];
}

- (NSString *)filePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    return [documentDirectory stringByAppendingPathComponent:@"database.sqlite"];
}

- (YapDatabase *)sharedYapDatabase {
    static YapDatabase *_sharedYapDatabase = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedYapDatabase = [[YapDatabase alloc]initWithPath:[self filePath]];
    });
    
    return _sharedYapDatabase;
}

#pragma mark - App Life Cycle

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Setup Database and connection
    self.database = [self sharedYapDatabase];
    [self updateStatusWithString:[NSString stringWithFormat:@"Database created at %@",self.databasePath]];
    self.connection = [self.database newConnection];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Delete Database on Termination

}


#pragma mark - Export Menu IBActions

- (IBAction)exportEvents:(NSMenuItem *)sender {
    NSSavePanel *savePanel = [self makeSavePanel];
    
    NSWindow *window = [NSApplication sharedApplication].windows[0];
    
    [savePanel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
        [savePanel orderOut:nil];
        
        if (result == NSFileHandlingPanelOKButton)
        {
            // Export->Events->Raw
            if (sender.tag == 0)
            {
                CSVParser *parser = [[CSVParser alloc] initForWritingToFile:savePanel.URL.path];
                [parser eventsToCSVWithPeopleProperties:NO];
            
            // Export->Events->w/People Props
            } else if (sender.tag == 1)
            {
                CSVParser *parser = [[CSVParser alloc] initForWritingToFile:savePanel.URL.path];
                [parser eventsToCSVWithPeopleProperties:YES];
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
            CSVParser *parser = [[CSVParser alloc] initForWritingToFile:savePanel.URL.path];
            [parser peopleToCSV];
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
            CSVParser *parser = [[CSVParser alloc] initForWritingToFile:savePanel.URL.path];
            [parser transactionsToCSV];
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
            CSVParser *parser = [[CSVParser alloc] initForWritingToFile:savePanel.URL.path];
            [parser peopleFromEventsToCSV];
        }
    }];
}

#pragma mark - Utility Methods

- (void)updateStatusWithString:(NSString *)status
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
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    savePanel.directoryURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@", paths[0]]];
    
    return savePanel;
}


@end
