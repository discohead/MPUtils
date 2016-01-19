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
#import "ProjectEditViewController.h"
#import <YapDatabase/YapDatabase.h>
#import <Mixpanel-OSX-Community/Mixpanel.h>

@interface ViewController ()

@property (weak) IBOutlet NSPopUpButton *projectPopUpButton;
@property (strong, nonatomic) NSUserDefaultsController *userDefaultsController;
@property (strong, nonatomic) IBOutlet NSArrayController *projectsArrayController;
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
@property (strong, nonatomic) NSDate *maxDate;
@property (weak, nonatomic) ExportRequest *currentExport;
@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic) NSUInteger eventTempCount;
@property (nonatomic) NSUInteger peopleTempCount;
@property (nonatomic) BOOL highVolume;
@property (strong, nonatomic) NSMutableArray *highVolumeDateArray;

@end

@implementation ViewController

#pragma mark - Lazy Properties

- (BOOL)highVolume
{
    if (!_highVolume)
    {
        _highVolume = NO;
    }
    return _highVolume;
}

- (NSMutableArray *)highVolumeDateArray
{
    if (!_highVolumeDateArray)
    {
        _highVolumeDateArray = [NSMutableArray array];
    }
    return _highVolumeDateArray;
}

- (NSUInteger)eventTempCount
{
    if (!_eventTempCount)
    {
        _eventTempCount = 0;
    }
    return _eventTempCount;
}

- (NSUInteger)peopleTempCount
{
    if (!_peopleTempCount)
    {
        _peopleTempCount = 0;
    }
    return _peopleTempCount;
}

- (NSTimeInterval)startTime
{
    if (!_startTime)
    {
        _startTime = [[NSDate date] timeIntervalSince1970];
    }
    return _startTime;
}

- (NSDate *)maxDate
{
    return [NSDate date];
}

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
    return self.projects[self.projectPopUpButton.indexOfSelectedItem][kMPUserDefaultsProjectAPIKeyKey];
}

- (NSString *)apiSecret
{
    return self.projects[self.projectPopUpButton.indexOfSelectedItem][kMPUserDefaultsProjectAPISecretKey];
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
    
    [self updateCountLabelOfType:@"event" withCount:@0];
    [self updateCountLabelOfType:@"people" withCount:@0];
}

-(void)setSelectedProjectIndex:(NSUInteger)index
{
    [self.projectPopUpButton selectItemAtIndex:index];
}

#pragma mark - IBActions

- (IBAction)projectSelected:(NSPopUpButton *)sender {
    NSDictionary *project = self.projects[sender.indexOfSelectedItem];
    [self appendToStatusLog:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"Selected Project = %@", project] attributes:@{NSForegroundColorAttributeName:[NSColor purpleColor]}]];
    
    [[Mixpanel sharedInstance] track:@"Selected Project"];
    
    [self syncUserDefaults];
}

- (void)syncUserDefaults {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:@(self.projectPopUpButton.indexOfSelectedItem) forKey:kMPUserDefaultsSelectedProjectKey];
    [userDefaults setObject:[self.whereTextField stringValue] forKey:kMPUserDefaultsWhereClauseKey];
    [userDefaults setObject:[self.eventsArray componentsJoinedByString:@", "] forKey:kMPUserDefaultsEventsKey];
    [userDefaults setObject:self.fromDatePicker.dateValue forKey:kMPUserDefaultsFromDateKey];
    [userDefaults setObject:self.toDatePicker.dateValue forKey:kMPUserDefaultsToDateKey];
    [userDefaults synchronize];
}

- (IBAction)loadEventsButtonPressed:(id)sender {
    [self.progressIndicator startAnimation:sender];
    
    ExportRequest *request = [ExportRequest requestWithAPIKey:self.apiKey secret:self.apiSecret outputType:@"DB"];
    self.currentExport = request;
    
    if ([NSEvent modifierFlags] & NSAlternateKeyMask)
    {
        self.highVolume = YES;
        NSMutableArray *datesArray = [NSMutableArray array];
        NSDate *dateToAdd = self.fromDatePicker.dateValue;
        do {
            [datesArray addObject:dateToAdd];
            dateToAdd = [NSDate dateWithTimeInterval:60*60*24 sinceDate:dateToAdd];
        } while ([dateToAdd timeIntervalSinceDate:self.toDatePicker.dateValue] < 1);
        
        [request highVolumeRequestForEvents:self.eventsArray withArrayOfDates:datesArray where:[self.whereTextField stringValue]];
    } else
    {
        [request requestForEvents:self.eventsArray fromDate:self.fromDatePicker.dateValue toDate:self.toDatePicker.dateValue where:[self.whereTextField stringValue]];
    }

    [self syncUserDefaults];
}
- (IBAction)loadPeopleButtonPressed:(id)sender {
    [self.progressIndicator startAnimation:sender];
    ExportRequest *request = [ExportRequest requestWithAPIKey:self.apiKey secret:self.apiSecret outputType:@"DB"];
    self.currentExport = request;
    [request requestForPeopleWhere:[self.whereTextField stringValue] sessionID:@"" page:0];
    
    [self syncUserDefaults];
}
- (IBAction)resetButtonPressed:(id)sender {
    [self.progressIndicator startAnimation:sender];
    
    [[Mixpanel sharedInstance] track:@"Reset Pressed"];
    
    AppDelegate *appDelegate = (AppDelegate *) [[NSApplication sharedApplication] delegate];
    
    [appDelegate.connection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [transaction removeAllObjectsInAllCollections];
    }];
    [self appendToStatusLog:[[NSAttributedString alloc] initWithString:@"Database Reset!" attributes:@{NSForegroundColorAttributeName:[NSColor orangeColor]}]];
    
    [self updateCountLabelOfType:@"event" withCount:@0];
    [self updateCountLabelOfType:@"people" withCount:@0];
    self.eventTempCount = 0;
    self.peopleTempCount = 0;
    
    [self.progressIndicator stopAnimation:sender];
}

- (IBAction)quickEventsExportPressed:(NSButton *)sender {
    [self.progressIndicator startAnimation:sender];

    NSString *outputType = (sender.tag == 0) ? @"CSV" : @"JSON";
    ExportRequest *request = [ExportRequest requestWithAPIKey:self.apiKey secret:self.apiSecret outputType:outputType];
    self.currentExport = request;
    
    if ([NSEvent modifierFlags] & NSAlternateKeyMask)
    {
        self.highVolume = YES;
        NSMutableArray *datesArray = [NSMutableArray array];
        NSDate *dateToAdd = self.fromDatePicker.dateValue;
        do {
            [datesArray addObject:dateToAdd];
            dateToAdd = [NSDate dateWithTimeInterval:60*60*24 sinceDate:dateToAdd];
        } while ([dateToAdd timeIntervalSinceDate:self.toDatePicker.dateValue] < 1);
        
        [request highVolumeRequestForEvents:self.eventsArray withArrayOfDates:datesArray where:[self.whereTextField stringValue]];
    } else
    {
        [request requestForEvents:self.eventsArray fromDate:self.fromDatePicker.dateValue toDate:self.toDatePicker.dateValue where:[self.whereTextField stringValue]];
    }
    
    [self syncUserDefaults];
}

- (IBAction)quickPeopleExportPressed:(NSButton *)sender {
    [self.progressIndicator startAnimation:sender];
    NSString *outputType = (sender.tag == 0) ? @"CSV" : @"JSON";
    ExportRequest *request = [ExportRequest requestWithAPIKey:self.apiKey secret:self.apiSecret outputType:outputType];
    self.currentExport = request;
    [request requestForPeopleWhere:[self.whereTextField stringValue] sessionID:@"" page:0];
    
    [self syncUserDefaults];
}

- (IBAction)cancelRequestPressed:(id)sender {
    if (self.currentExport)
    {
        [self.currentExport cancel];
        self.currentExport = nil;
        [self.progressIndicator stopAnimation:sender];
    }
}

#pragma mark - NSNotification Methods

- (void)registerForNotifications {
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editingDidEnd:)
                                                 name:NSControlTextDidEndEditingNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveDBWritingNotification:) name:kMPDBWritingUpdate object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveDBWritingNotification:) name:kMPDBWritingEnded object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveFileWritingNotification:) name:kMPFileWritingBegan object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveFileWritingNotification:) name:kMPFileWritingUpdate object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveFileWritingNotification:) name:kMPFileWritingEnded object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveAPIRequestNotification:) name:kMPAPIRequestBegan object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveAPIRequestNotification:) name:kMPAPIRequestUpdate object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveAPIRequestNotification:) name:kMPAPIRequestEnded object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveAPIRequestNotification:) name:kMPAPIRequestCancelled object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveAPIRequestNotification:) name:kMPAPIRequestFailed object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveStatusUpdate:) name:kMPStatusUpdate object:nil];
}

- (void)receiveAPIRequestNotification:(NSNotification *)notification
{
    if ([[notification name] isEqualToString:kMPAPIRequestBegan])
    {
        // [self.progressIndicator startAnimation:self];
    } else if ([[notification name] isEqualToString:kMPAPIRequestUpdate] || [[notification name] isEqualToString:kMPAPIRequestEnded])
    {
        if ([[notification name] isEqualToString:kMPAPIRequestEnded])
        {
            self.currentExport = nil;
            [self.progressIndicator stopAnimation:self];
            if ([notification userInfo][kMPUserInfoKeyType])
            {
                NSString *type = [notification userInfo][kMPUserInfoKeyType];
                if ([type isEqualToString:@"people"])
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self updateCountLabelOfType:@"people" withCount:@([self peopleCount])];
                    });
                } else if ([type isEqualToString:@"event"])
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self updateCountLabelOfType:@"event" withCount:@([self eventCount])];
                    });
                }
            }
        }
    } else if ([[notification name] isEqualToString:kMPAPIRequestCancelled])
    {
        [self appendToStatusLog:[[NSAttributedString alloc] initWithString:@"API Request Cancelled!" attributes:@{NSForegroundColorAttributeName:[NSColor orangeColor]}]];
    }
}

- (void)receiveDBWritingNotification:(NSNotification *)notification
{
    if ([notification userInfo])
    {
        NSDictionary *userInfo = [notification userInfo];
        NSString *type = [NSString string];
        NSNumber *count = @0;
        if (userInfo[kMPUserInfoKeyType]) type = userInfo[kMPUserInfoKeyType];
        if (userInfo[kMPUserInfoKeyCount]) count = userInfo[kMPUserInfoKeyCount];
        
        if ([[notification name] isEqualToString:kMPDBWritingUpdate] || [[notification name] isEqualToString:kMPDBWritingEnded])
        {
            
            
            
//            NSUInteger currentTempCount = [type isEqualToString:@"event"] ? self.eventTempCount : self.peopleTempCount;
//            NSUInteger updatedTempCount = currentTempCount + [count integerValue];
//            [self updateCountLabelOfType:type withCount:@(updatedTempCount)];
//            if ([type isEqualToString:@"event"])
//            {
//                self.eventTempCount = updatedTempCount;
//            } else
//            {
//                self.peopleTempCount = updatedTempCount;
//            }
            
//            if ([[notification name] isEqualToString:kMPDBWritingEnded])
//            {
//                if ([type isEqualToString:@"people"])
//                {
//                    dispatch_async(dispatch_get_main_queue(), ^{
//                        [self updateCountLabelOfType:@"people" withCount:@([self peopleCount])];
//                    });
//                } else if ([type isEqualToString:@"event"])
//                {
//                    dispatch_async(dispatch_get_main_queue(), ^{
//                        [self updateCountLabelOfType:@"event" withCount:@([self eventCount])];
//                    });
//                }
//                
//                [self.progressIndicator stopAnimation:self];
//            }
        }
    }
    
}

- (void)receiveFileWritingNotification:(NSNotification *)notification
{
    NSString *format = [[notification userInfo] objectForKey:kMPFileWritingFormatKey];
    if ([[notification name] isEqualToString:kMPFileWritingBegan])
    {
        self.startTime = [[NSDate date] timeIntervalSince1970];
        [self.progressIndicator startAnimation:self];
        [self appendToStatusLog:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ export began",format] attributes:@{NSForegroundColorAttributeName:[NSColor magentaColor]}]];
    } else if ([[notification name] isEqualToString:kMPFileWritingEnded])
    {
        NSString *exportObject = [[notification userInfo] objectForKey:kMPFileWritingExportObjectKey];
        NSString *exportType = [[notification userInfo] objectForKey:kMPFileWritingExportTypeKey];
        NSNumber *rows = [[notification userInfo] objectForKey:kMPFileWritingCount];
        [[Mixpanel sharedInstance] track:@"File Export" properties:@{@"$duration":@([[NSDate date] timeIntervalSince1970] - self.startTime),@"Object":exportObject,@"Type":exportType,@"Rows":rows}];
        [self.progressIndicator stopAnimation:self];
        [self appendToStatusLog:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ export ended - %@ %@ exported",format,rows,exportObject] attributes:@{NSForegroundColorAttributeName:[NSColor magentaColor]}]];
    }
}

- (void)editingDidEnd:(NSNotification *)notification
{
    [self.userDefaultsController save:self];
}

- (void)receiveStatusUpdate:(NSNotification *)notification
{
    if ([[notification name] isEqualToString:kMPStatusUpdate])
    {
        [self appendToStatusLog:[notification userInfo][kMPUserInfoKeyStatus]];
    }
}

- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"editProject"])
    {
        ProjectEditViewController *pvc = (ProjectEditViewController *)segue.destinationController;
        [pvc.projectPopUpButton selectItemAtIndex:self.projectPopUpButton.indexOfSelectedItem];
    }
}


#pragma mark - Utility Methods

- (void)restorePreviousSettings
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSNumber *selectedProjectIndex = [userDefaults objectForKey:kMPUserDefaultsSelectedProjectKey];
    if (selectedProjectIndex) [self setSelectedProjectIndex:[selectedProjectIndex integerValue]];
    
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

- (void)appendToStatusLog:(NSAttributedString*)text
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [[self.statusLogTextView textStorage] appendAttributedString:text];
        
        NSAttributedString* newLine = [[NSAttributedString alloc] initWithString:@"\n\n"];
        [[self.statusLogTextView textStorage] appendAttributedString:newLine];
        
        [self.statusLogTextView setEditable:YES];
        [self.statusLogTextView checkTextInDocument:nil];
        [self.statusLogTextView setEditable:NO];
        
        [self.statusLogTextView scrollRangeToVisible:NSMakeRange([[self.statusLogTextView string] length], 0)];
    });
}

- (NSUInteger)eventCount
{
    AppDelegate *appDelegate = (AppDelegate *) [[NSApplication sharedApplication] delegate];
    __block NSUInteger count;
    
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        count = [transaction numberOfKeysInCollection:kMPDBCollectionNameEvents];
    }];
    
    return count;
}

- (NSUInteger)peopleCount
{
    AppDelegate *appDelegate = (AppDelegate *) [[NSApplication sharedApplication] delegate];
    __block NSUInteger count;
    
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        count = [transaction numberOfKeysInCollection:kMPDBCollectionNamePeople];
    }];
    
    return count;
}

@end
