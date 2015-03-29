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

@interface ViewController () <ExportRequestProtocol>

@property (weak) IBOutlet NSPopUpButton *projectPopUpButton;
@property (nonatomic, strong) NSUserDefaultsController *userDefaultsController;
@property (strong, nonatomic) NSArrayController *projectsArrayController;
@property (strong) IBOutlet NSObjectController *selectedProjectObjectController;
@property (strong, nonatomic) NSArray *eventNames;
@property (strong) IBOutlet NSArrayController *eventNamesArrayController;
@property (strong, nonatomic) NSArray *projects;

@end

@implementation ViewController

- (NSArray *)projects
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:kMPUserDefaultsProjectsKey];
}

- (NSArray *)eventNames
{
    if (!_eventNames)
    {
        _eventNames = [NSArray array];
    }
    return _eventNames;
}

- (NSUserDefaultsController *)userDefaultsController
{
    return [NSUserDefaultsController sharedUserDefaultsController];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"selected project = %@", [self.selectedProjectObjectController.content valueForKey:kMPUserDefaultsProjectNameKey]);
    

    [self updateEvents];
}

- (void)updateEvents
{
    NSString *apiKey = self.projects[self.projectPopUpButton.indexOfSelectedItem][kMPUserDefaultsProjectAPIKeyKey];
    NSString *apiSecret = self.projects[self.projectPopUpButton.indexOfSelectedItem][kMPUserDefaultsProjectAPISecretKey];
    NSLog(@"apiKey = %@ and apiSecret = %@", apiKey, apiSecret);
    
    ExportRequest *exportRequest = [ExportRequest requestWithAPIKey:apiKey secret:apiSecret];
    exportRequest.delegate = self;
    [exportRequest requestWithURL:[NSURL URLWithString:kMPURLEventsNames] params:@{kMPParameterEventsNamesType:kMPValueEventsNamesTypeUnique,
                                                                                   kMPParameterEventsNamesLimit:[NSString stringWithFormat:@"%i",500],
                                                                                   
                                                                                   }];
    
}

- (void)dataResultsHandler:(NSData *)data fromURL:(NSURL *)URL
{
    NSLog(@"Response URL = %@", URL.absoluteString);
    NSLog(@"data = %@", data);
    if (YES)
    {
        NSError *error;
        NSArray *eventNamesResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (!error)
        {
            NSLog(@"Event Names = %@", eventNamesResponse);
            self.eventNames = eventNamesResponse;
        } else
        {
            NSLog(@"Error de-serializing event names data. Error message: %@", error.localizedDescription);
        }
    }
}
- (IBAction)projectSelected:(NSPopUpButton *)sender {
    NSString *projectName = self.projects[sender.indexOfSelectedItem];
    NSLog(@"Selected Project Name = %@",projectName);
    [self updateEvents];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

@end
