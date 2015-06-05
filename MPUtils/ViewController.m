//
//  ViewController.m
//  MPUtils
//
//  Created by Jared McFarland on 3/28/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import "ViewController.h"
#import "MPUConstants.h"
#import "ExportRequest.h"
#import "AppDelegate.h"
#import <YapDatabase/YapDatabase.h>

@interface ViewController ()

@property (weak) IBOutlet NSPopUpButton *projectPopUpButton;
@property (strong, nonatomic) NSUserDefaultsController *userDefaultsController;
@property (strong, nonatomic) NSArrayController *projectsArrayController;
@property (strong, nonatomic) NSArray *projects;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSTextField *eventsTextField;
@property (weak) IBOutlet NSDatePicker *fromDatePicker;
@property (weak) IBOutlet NSDatePicker *toDatePicker;
@property (weak) IBOutlet NSTextField *whereTextField;
@property (strong, nonatomic) NSString *apiKey;
@property (strong, nonatomic) NSString *apiSecret;
@property (strong, nonatomic) NSArray *eventsArray;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@property (weak) IBOutlet NSTextField *eventCountLabel;
@property (weak) IBOutlet NSTextField *peopleCountLabel;
@property (unsafe_unretained) IBOutlet NSTextView *statusLogTextView;
@property (weak) IBOutlet NSTableView *tableView;


@end

@implementation ViewController

#pragma mark - Lazy Properties

- (NSDateFormatter *)dateFormatter
{
    if (!_dateFormatter) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"YYYY-MM-dd"];
    }
    return _dateFormatter;
}

- (NSArray *)eventsArray
{
    NSArray *events = [NSArray array];
    if (![[self.eventsTextField stringValue] isEqualToString:@""]) {
        events = [[[self.eventsTextField stringValue] stringByReplacingOccurrencesOfString:@", " withString:@"," ] componentsSeparatedByString:@","];
    }
    return events;
}

- (NSString *)apiKey
{
    return self.projects[self.tableView.selectedRow][kMPUserDefaultsProjectAPIKeyKey];
}

- (NSString *)apiSecret
{
    return self.projects[self.tableView.selectedRow][kMPUserDefaultsProjectAPISecretKey];
}

- (NSArray *)projects
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:kMPUserDefaultsProjectsKey];
}

- (NSUserDefaultsController *)userDefaultsController
{
    return [NSUserDefaultsController sharedUserDefaultsController];
}

#pragma mark - View Life Cycle

- (void)awakeFromNib
{
    [super awakeFromNib];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self registerForNotifications];
    [self restorePreviousSettings];

}

#pragma mark - IBActions

- (IBAction)projectSelected:(NSPopUpButton *)sender {
    NSDictionary *project = self.projects[sender.indexOfSelectedItem];
    [self appendToStatusLog:[NSString stringWithFormat:@"Selected Project = %@", project]];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:@(sender.indexOfSelectedItem) forKey:kMPUserDefaultsSelectedProjectKey];
    [userDefaults synchronize];
}

- (IBAction)loadEventsButtonPressed:(id)sender {
    [self.progressIndicator startAnimation:sender];
    ExportRequest *request = [ExportRequest requestWithAPIKey:self.apiKey secret:self.apiSecret];
    [request requestForEvents:self.eventsArray fromDate:self.fromDatePicker.dateValue toDate:self.toDatePicker.dateValue where:[self.whereTextField stringValue]];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:[self.whereTextField stringValue] forKey:kMPUserDefaultsWhereClauseKey];
    [userDefaults setObject:[self.eventsArray componentsJoinedByString:@", "] forKey:kMPUserDefaultsEventsKey];
    [userDefaults setObject:self.fromDatePicker.dateValue forKey:kMPUserDefaultsFromDateKey];
    [userDefaults setObject:self.toDatePicker.dateValue forKey:kMPUserDefaultsToDateKey];
    [userDefaults synchronize];
}
- (IBAction)loadPeopleButtonPressed:(id)sender {
    [self.progressIndicator startAnimation:sender];
    ExportRequest *request = [ExportRequest requestWithAPIKey:self.apiKey secret:self.apiSecret];
    [request requestForPeopleWhere:[self.whereTextField stringValue] sessionID:@"" page:0];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:[self.whereTextField stringValue] forKey:kMPUserDefaultsWhereClauseKey];
    [userDefaults synchronize];
}
- (IBAction)resetButtonPressed:(id)sender {
    [self.progressIndicator startAnimation:sender];
    
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    
    [appDelegate.connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [transaction removeAllObjectsInAllCollections];
    }];
    
    [self appendToStatusLog:@"Database Reset!"];
    
    [self updateCountLabelOfType:@"event" withCount:@0];
    [self updateCountLabelOfType:@"people" withCount:@0];
    [self.progressIndicator stopAnimation:sender];
}

#pragma mark - NSNotification Methods

- (void)registerForNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveCSVNotification:) name:kMPCSVWritingBegan object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveCSVNotification:) name:kMPCSVWritingEnded object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveExportNotification:) name:kMPExportBegan object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveExportNotification:) name:kMPExportUpdate object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveExportNotification:) name:kMPExportEnd object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveStatusUpdate:) name:kMPStatusUpdate object:nil];
}

- (void)receiveExportNotification:(NSNotification *)notification
{
    if ([[notification name] isEqualToString:kMPExportBegan])
    {
        [self.progressIndicator startAnimation:self];
    } else if ([[notification name] isEqualToString:kMPExportUpdate] || [[notification name] isEqualToString:kMPExportEnd])
    {
        NSNumber *count = [notification userInfo][kMPUserInfoKeyCount];
        NSString *type = [notification userInfo][kMPUserInfoKeyType];
        [self updateCountLabelOfType:type withCount:count];
        if ([[notification name] isEqualToString:kMPExportEnd])
        {
            [self.progressIndicator stopAnimation:self];
        }
    }
}

- (void)receiveCSVNotification:(NSNotification *)notification
{
    if ([[notification name] isEqualToString:kMPCSVWritingBegan])
    {
        [self.progressIndicator startAnimation:self];
        [self appendToStatusLog:@"CSV Export Began"];
    } else if ([[notification name] isEqualToString:kMPCSVWritingEnded])
    {
        [self.progressIndicator stopAnimation:self];
        [self appendToStatusLog:@"CSV Export Ended"];
    }
}

- (void)receiveStatusUpdate:(NSNotification *)notification
{
    if ([[notification name] isEqualToString:kMPStatusUpdate])
    {
        [self appendToStatusLog:[notification userInfo][kMPUserInfoKeyStatus]];
    }
}

#pragma mark - Utility Methods

- (void)restorePreviousSettings
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    //NSNumber *selectedProjectIndex = [userDefaults objectForKey:kMPUserDefaultsSelectedProjectKey];
    //if (selectedProjectIndex) [self setSelectedProjectIndex:[selectedProjectIndex integerValue]];
    
    NSDate *fromDate = [userDefaults objectForKey:kMPUserDefaultsFromDateKey];
    NSDate *toDate = [userDefaults objectForKey:kMPUserDefaultsToDateKey];

    if (fromDate && toDate)
    {
        self.fromDatePicker.dateValue = fromDate;
        self.toDatePicker.dateValue = toDate;
    } else
    {
        [self resetDateRange];
    }
    
    NSString *whereClause = [userDefaults objectForKey:kMPUserDefaultsWhereClauseKey];
    if (whereClause) self.whereTextField.stringValue = whereClause;
    
    NSString *eventString = [userDefaults objectForKey:kMPUserDefaultsEventsKey];
    if (eventString) self.eventsTextField.stringValue = eventString;
}

- (void)resetDateRange
{
    NSTimeInterval minusOneDay = -24*60*60;
    NSTimeInterval minusThirtyDays = minusOneDay*30;
    NSDate *yesterday = [[NSDate date] dateByAddingTimeInterval:minusOneDay];
    NSDate *monthAgo = [[NSDate date] dateByAddingTimeInterval:minusThirtyDays];
    self.fromDatePicker.dateValue = monthAgo;
    self.toDatePicker.dateValue = yesterday;
}

- (void)updateCountLabels {
    self.eventCountLabel.stringValue = [NSString stringWithFormat:@"%lu Events Loaded", [self eventCount]];
    self.peopleCountLabel.stringValue = [NSString stringWithFormat:@"%lu People Loaded", [self peopleCount]];
}

- (void)updateCountLabelOfType:(NSString *)type withCount:(NSNumber *)count
{
    if ([type isEqualToString:@"event"])
    {
        self.eventCountLabel.stringValue = [NSString stringWithFormat:@"%@ Events Loaded",count];
    } else if ([type isEqualToString:@"people"])
    {
        self.peopleCountLabel.stringValue = [NSString stringWithFormat:@"%@ People Loaded", count];
    }
}

- (void)appendToStatusLog:(NSString*)text
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString* attr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n",text]];
        
        [[self.statusLogTextView textStorage] appendAttributedString:attr];
        [self.statusLogTextView scrollRangeToVisible:NSMakeRange([[self.statusLogTextView string] length], 0)];
    });
}

- (NSUInteger)eventCount
{
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    __block NSUInteger count;
    
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        count = [transaction numberOfKeysInCollection:kMPDBCollectionNameEvents];
    }];
    
    return count;
}

- (NSUInteger)peopleCount
{
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    __block NSUInteger count;
    
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        count = [transaction numberOfKeysInCollection:kMPDBCollectionNamePeople];
    }];
    
    return count;
}

@end
