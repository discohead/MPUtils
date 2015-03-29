//
//  MPUConstants.h
//  MPUtils
//
//  Created by Jared McFarland on 3/28/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPUConstants : NSObject

#pragma mark - Base URL's

extern NSString *const kMPURLRawExport;
extern NSString *const kMPURLEngageExport;
extern NSString *const kMPURLEventsNames;

#pragma mark - URL Parameters Names

extern NSString *const kMPParameterAPIKey;
extern NSString *const kMPParameterSig;
extern NSString *const kMPParameterExpire;
extern NSString *const kMPParameterFromDate;
extern NSString *const kMPParameterToDate;
extern NSString *const kMPParameterRawExportEvent;
extern NSString *const kMPParameterWhere;
extern NSString *const kMPParameterEngageSessionID;
extern NSString *const kMPParameterEngagePage;
extern NSString *const kMPParameterEngageDistinctID;
extern NSString *const kMPParameterEventsNamesType;
extern NSString *const kMPParameterEventsNamesLimit;

#pragma mark - URL Parameter Values

extern NSString *const kMPValueEventsNamesTypeGeneral;
extern NSString *const kMPValueEventsNamesTypeUnique;
extern NSString *const kMPValueEventsNamesTypeAverage;

#pragma mark - NSUserDefaults Keys

extern NSString *const kMPUserDefaultsProjectsKey;
extern NSString *const kMPUserDefaultsProjectAPIKeyKey;
extern NSString *const kMPUserDefaultsProjectAPISecretKey;
extern NSString *const kMPUserDefaultsProjectTokenKey;
extern NSString *const kMPUserDefaultsProjectNameKey;
extern NSString *const kMPuserDefaultsUIProjectNamesKey;

@end
