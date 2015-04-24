//
//  ProjectEditViewController.m
//  MPUtils
//
//  Created by Jared McFarland on 4/8/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import "ProjectEditViewController.h"
#import "MPUConstants.h"

@interface ProjectEditViewController ()

@property (weak) IBOutlet NSPopUpButton *projectPopUpButton;
@property (weak) IBOutlet NSTextField *apiKeyTextField;
@property (weak) IBOutlet NSTextField *apiSecretTextField;
@property (weak) IBOutlet NSTextField *projectTokenTextField;
@property (weak) IBOutlet NSTextField *projectNameTextField;
@property (weak, nonatomic) NSArray *projects;
@property (weak, nonatomic) NSDictionary *selectedProject;
@property (strong, nonatomic) NSArrayController *projectsArrayController;

@end

@implementation ProjectEditViewController

- (NSArrayController *)projectsArrayController
{
    if (!_projectsArrayController)
    {
        _projectsArrayController = [[NSArrayController alloc] init];
        [_projectsArrayController bind:@"contentArray" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[NSString stringWithFormat:@"%@.%@",@"values",kMPUserDefaultsProjectsKey] options:nil];
    }
    return _projectsArrayController;
}

- (NSUserDefaultsController *)userDefaultsController
{
    return [NSUserDefaultsController sharedUserDefaultsController];
}

- (NSArray *)projects
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:kMPUserDefaultsProjectsKey];
}

- (NSDictionary *)selectedProject
{
    return self.projects[self.projectPopUpButton.indexOfSelectedItem];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self.projectPopUpButton bind:@"content" toObject:self.projectsArrayController withKeyPath:@"arrangedObjects" options:nil];
    [self.projectPopUpButton bind:@"contentValues" toObject:self.projectsArrayController withKeyPath:[NSString stringWithFormat:@"%@.%@",@"arrangedObjects",kMPUserDefaultsProjectNameKey] options:nil];
    [self.projectPopUpButton bind:@"selectedIndex" toObject:self.projectsArrayController withKeyPath:@"selection.count" options:nil];
    [self updateTextFields];
}

- (IBAction)projectSelected:(NSPopUpButton *)sender {
    [self updateTextFields];
}

- (void)updateTextFields
{
    self.apiKeyTextField.stringValue = self.selectedProject[kMPUserDefaultsProjectAPIKeyKey];
    self.apiSecretTextField.stringValue = self.selectedProject[kMPUserDefaultsProjectAPISecretKey];
    self.projectTokenTextField.stringValue = self.selectedProject[kMPUserDefaultsProjectTokenKey];
    self.projectNameTextField.stringValue = self.selectedProject[kMPUserDefaultsProjectNameKey];
}

- (IBAction)saveButtonPressed:(id)sender
{
    NSMutableDictionary *updatedProject = [self.selectedProject mutableCopy];
    updatedProject[kMPUserDefaultsProjectAPIKeyKey] = self.apiKeyTextField.stringValue;
    updatedProject[kMPUserDefaultsProjectAPISecretKey] = self.apiSecretTextField.stringValue;
    updatedProject[kMPUserDefaultsProjectTokenKey] = self.projectTokenTextField.stringValue;
    updatedProject[kMPUserDefaultsProjectNameKey] = self.projectNameTextField.stringValue;
    NSMutableArray *updatedProjects = [self.projects mutableCopy];
    [updatedProjects replaceObjectAtIndex:self.projectPopUpButton.indexOfSelectedItem withObject:updatedProject];
    [[NSUserDefaults standardUserDefaults] setObject:updatedProjects forKey:kMPUserDefaultsProjectsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction)deleteButtonPressed:(id)sender
{
    NSMutableArray *updatedProjecs = [self.projects mutableCopy];
    [updatedProjecs removeObjectAtIndex:self.projectPopUpButton.indexOfSelectedItem];
    [[NSUserDefaults standardUserDefaults] setObject:updatedProjecs forKey:kMPUserDefaultsProjectsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self updateTextFields];
}
@end
