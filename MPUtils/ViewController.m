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


@end

@implementation ViewController

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

- (void)awakeFromNib
{
    [super awakeFromNib];
    NSTimeInterval minusOneDay = -24*60*60;
    NSTimeInterval minusThirtyDays = minusOneDay*30;
    NSDate *yesterday = [[NSDate date] dateByAddingTimeInterval:minusOneDay];
    NSDate *monthAgo = [[NSDate date] dateByAddingTimeInterval:minusThirtyDays];
    self.fromDatePicker.dateValue = monthAgo;
    self.toDatePicker.dateValue = yesterday;
    
    
}


- (void)updateCountLabels {
    self.eventCountLabel.stringValue = [NSString stringWithFormat:@"%@ Events Loaded", [self eventCount]];
    self.peopleCountLabel.stringValue = [NSString stringWithFormat:@"%@ People Loaded", [self peopleCount]];
}

- (NSNumber *)eventCount
{
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    __block CBLManager *manager = appDelegate.manager;
    __block NSNumber *eventCount;
    
    dispatch_sync(manager.dispatchQueue, ^{
        NSError *dbError;
        
        CBLDatabase *database = [manager databaseNamed:kMPCBLDatabaseName error:&dbError];
        if (dbError)
        {
            NSLog(@"Error loading database. Error message: %@", dbError.localizedDescription);
        } else
        {
            CBLView *eventView = [database viewNamed:kMPCBLViewNameEvents];
            CBLQuery *eventQuery = [eventView createQuery];
            NSError *eventError;
            CBLQueryEnumerator *eventEnum = [eventQuery run:&eventError];
            if (eventError)
            {
                NSLog(@"Error querying events. Error messsage: %@",eventError.localizedDescription);
                eventCount = @(-1);
            } else
            {
                if ([eventEnum count])
                {
                    eventCount = [[eventEnum rowAtIndex:0] value];
                } else
                {
                    eventCount = @0;
                }
            }
        }
    });
    return eventCount;
    
}

- (NSNumber *)peopleCount
{
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    __block CBLManager *manager = appDelegate.manager;
    __block NSNumber *peopleCount;
    
    dispatch_sync(manager.dispatchQueue, ^{
        NSError *dbError;
        
        CBLDatabase *database = [manager databaseNamed:kMPCBLDatabaseName error:&dbError];
        if (dbError)
        {
            NSLog(@"Error loading database. Error message: %@", dbError.localizedDescription);
        } else
        {
            
            NSError *peopleError;
            CBLView *peopleView = [database viewNamed:kMPCBLViewNamePeople];
            CBLQuery *peopleQuery = [peopleView createQuery];
            CBLQueryEnumerator *peopleEnum = [peopleQuery run:&peopleError];
            if (peopleError)
            {
                NSLog(@"Error querying people. Error message: %@",peopleError.localizedDescription);
                peopleCount = @(-1);
            } else
            {
                if ([peopleEnum count])
                {
                    peopleCount = [[peopleEnum rowAtIndex:0] value];
                } else
                {
                    peopleCount = @0;
                }
                
            }
        }
        
    });
    
    return peopleCount;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveCSVNotification:) name:kMPCSVWritingBegan object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveCSVNotification:) name:kMPCSVWritingEnded object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveExportNotification:) name:kMPExportBegan object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveExportNotification:) name:kMPExportUpdate object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveExportNotification:) name:kMPExportEnd object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveStatusUpdate:) name:kMPStatusUpdate object:nil];

}

- (IBAction)projectSelected:(NSPopUpButton *)sender {
    NSDictionary *project = self.projects[sender.indexOfSelectedItem];
    [self appendToStatusLog:[NSString stringWithFormat:@"Selected Project = %@", project]];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
    
}

- (IBAction)loadEventsButtonPressed:(id)sender {
    [self.progressIndicator startAnimation:sender];
    ExportRequest *request = [ExportRequest requestWithAPIKey:self.apiKey secret:self.apiSecret];
    [request requestForEvents:self.eventsArray fromDate:self.fromDatePicker.dateValue toDate:self.toDatePicker.dateValue where:[self.whereTextField stringValue]];
}
- (IBAction)loadPeopleButtonPressed:(id)sender {
    [self.progressIndicator startAnimation:sender];
    ExportRequest *request = [ExportRequest requestWithAPIKey:self.apiKey secret:self.apiSecret];
    [request requestForPeopleWhere:[self.whereTextField stringValue] sessionID:@"" page:0];
}
- (IBAction)resetButtonPressed:(id)sender {
    [self.progressIndicator startAnimation:sender];
    
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    __block CBLManager *manager = appDelegate.manager;
    
    dispatch_sync(manager.dispatchQueue, ^{
        NSError *dbError;
        CBLDatabase *database = [manager databaseNamed:kMPCBLDatabaseName error:&dbError];
        if (!dbError)
        {
            NSError *deletionError;
            [database deleteDatabase:&deletionError];
            if (!deletionError)
            {
                NSError *creationError;
                [appDelegate.manager databaseNamed:kMPCBLDatabaseName error:&creationError];
                if (!creationError)
                {
                    [appDelegate setupCouchbaseLite];
                } else
                {
                    [self appendToStatusLog:[NSString stringWithFormat:@"Error creating new database. Error message: %@", creationError.localizedDescription]];
                }
            } else
            {
                [self appendToStatusLog:[NSString stringWithFormat:@"Error deleting database. Error message: %@", deletionError.localizedDescription]];
            }
        } else
        {
            [self appendToStatusLog:[NSString stringWithFormat:@"Error getting database. Error message: %@",dbError.localizedDescription]];
        }
        
    });
    
    [self updateCountLabels];
    [self.progressIndicator stopAnimation:sender];
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

- (void)appendToStatusLog:(NSString*)text
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString* attr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n",text]];
        
        [[self.statusLogTextView textStorage] appendAttributedString:attr];
        [self.statusLogTextView scrollRangeToVisible:NSMakeRange([[self.statusLogTextView string] length], 0)];
    });
}
@end
