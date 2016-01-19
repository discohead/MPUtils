//
//  NewProjectViewController.m
//  MPUtils
//
//  Created by Jared McFarland on 3/28/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import "NewProjectViewController.h"
#import "MPUConstants.h"
#import "ViewController.h"
#import <Mixpanel-OSX-Community/Mixpanel.h>

@interface NewProjectViewController ()
@property (weak) IBOutlet NSTextField *apiKeyTextField;
@property (weak) IBOutlet NSTextField *apiSecretTextField;
@property (weak) IBOutlet NSTextField *projectTokenTextField;
@property (weak) IBOutlet NSTextField *projectNameTextField;
@end

@implementation NewProjectViewController

- (IBAction)saveButtonPressed:(id)sender
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    if ([[self.apiKeyTextField stringValue] isEqualToString:@""] ||
        [[self.apiSecretTextField stringValue] isEqualToString:@""] ||
        [[self.projectTokenTextField stringValue] isEqualToString:@""] ||
        [[self.projectNameTextField stringValue] isEqualToString:@""])
    {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"All Fields Required!";
        alert.informativeText = @"API Key, API Secret, Project Token and Name are all required to save Project.";
        return;
    } else
    {
        NSMutableArray *projects = [[userDefaults arrayForKey:kMPUserDefaultsProjectsKey] mutableCopy];
        NSMutableArray *projectNames = [[userDefaults arrayForKey:kMPuserDefaultsUIProjectNamesKey] mutableCopy];
        if (!projects) projects = [NSMutableArray array];
        if (!projectNames)
        {
            projectNames = [NSMutableArray array];
            for (NSDictionary *project in projects)
            {
                [projectNames addObject:project[kMPUserDefaultsProjectNameKey]];
            }
        }
        
        [projects addObject:@{kMPUserDefaultsProjectAPIKeyKey:   [self.apiKeyTextField stringValue],
                              kMPUserDefaultsProjectAPISecretKey:[self.apiSecretTextField stringValue],
                              kMPUserDefaultsProjectTokenKey:    [self.projectTokenTextField stringValue],
                              kMPUserDefaultsProjectNameKey:     [self.projectNameTextField stringValue]}];
        
        [projectNames addObject:[self.projectNameTextField stringValue]];
        
        [userDefaults setObject:projects forKey:kMPUserDefaultsProjectsKey];
        [userDefaults setObject:projectNames forKey:kMPuserDefaultsUIProjectNamesKey];
        [userDefaults synchronize];
        Mixpanel *mixpanel = [Mixpanel sharedInstance];
        [mixpanel.people increment:@"Projects Added" by:@1];
        [mixpanel registerSuperProperties:@{@"Projects Added":@([[[[mixpanel currentSuperProperties] objectsForKeys:@[@"Projects Added"] notFoundMarker:@0] objectAtIndex:0] integerValue] + 1)}];
        
        [[Mixpanel sharedInstance] track:@"Project Added"];
        
        NSWindow *mainWindow = [NSApplication sharedApplication].windows[0];
        ViewController *vc = (ViewController *)[mainWindow contentViewController];
        [vc setSelectedProjectIndex:projects.count-1];
        
        NSWindow *kWindow = [[NSApplication sharedApplication] keyWindow];
        [kWindow performClose:sender];
    }
    
}
@end
