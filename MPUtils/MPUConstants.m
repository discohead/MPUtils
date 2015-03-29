//
//  MPUConstants.m
//  MPUtils
//
//  Created by Jared McFarland on 3/28/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import "MPUConstants.h"

@implementation MPUConstants

#pragma mark - Base URL's

NSString *const kMPURLRawExport    = @"https://data.mixpanel.com/api/2.0/export/";
NSString *const kMPURLEngageExport = @"http://mixpanel.com/api/2.0/engage/";
NSString *const kMPURLEventsNames  = @"http://mixpanel.com/api/2.0/events/names/";

#pragma mark - URL Parameters

NSString *const kMPParameterAPIKey           = @"api_key";
NSString *const kMPParameterSig              = @"sig";
NSString *const kMPParameterExpire           = @"expire";
NSString *const kMPParameterFromDate         = @"from_date";
NSString *const kMPParameterToDate           = @"to_date";
NSString *const kMPParameterRawExportEvent   = @"event";
NSString *const kMPParameterWhere            = @"where";
NSString *const kMPParameterEngageSessionID  = @"session_id";
NSString *const kMPParameterEngagePage       = @"page";
NSString *const kMPParameterEngageDistinctID = @"distinct_id";
NSString *const kMPParameterEventsNamesType  = @"type";
NSString *const kMPParameterEventsNamesLimit = @"limit";

#pragma mark - URL Parameter Values

NSString *const kMPValueEventsNamesTypeGeneral = @"general";
NSString *const kMPValueEventsNamesTypeUnique = @"unique";
NSString *const kMPValueEventsNamesTypeAverage = @"average";

#pragma mark - NSUserDefaults Keys

NSString *const kMPUserDefaultsProjectsKey         = @"projects";
NSString *const kMPUserDefaultsProjectAPIKeyKey    = @"apiKey";
NSString *const kMPUserDefaultsProjectAPISecretKey = @"apiSecret";
NSString *const kMPUserDefaultsProjectTokenKey     = @"projectToken";
NSString *const kMPUserDefaultsProjectNameKey      = @"projectName";
NSString *const kMPuserDefaultsUIProjectNamesKey   = @"UIprojectNames";
@end
