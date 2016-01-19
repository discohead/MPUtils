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
NSString *const kMPValueEventsNamesTypeUnique  = @"unique";
NSString *const kMPValueEventsNamesTypeAverage = @"average";

#pragma mark - Export Results Keys

NSString *const kMPPeopleKeyResults   = @"results";
NSString *const kMPPeopleKeySessionID = @"session_id";
NSString *const kMPPeopleKeyPage      = @"page";

#pragma mark - NSUserDefaults Keys

NSString *const kMPUserDefaultsProjectsKey         = @"projects";
NSString *const kMPUserDefaultsProjectAPIKeyKey    = @"apiKey";
NSString *const kMPUserDefaultsProjectAPISecretKey = @"apiSecret";
NSString *const kMPUserDefaultsProjectTokenKey     = @"projectToken";
NSString *const kMPUserDefaultsProjectNameKey      = @"projectName";
NSString *const kMPuserDefaultsUIProjectNamesKey   = @"UIprojectNames";
NSString *const kMPUserDefaultsSelectedProjectKey  = @"SelectedProjectKey";
NSString *const kMPUserDefaultsWhereClauseKey      = @"WhereClauseKey";
NSString *const kMPUserDefaultsEventsKey           = @"EventsKey";
NSString *const kMPUserDefaultsFromDateKey         = @"FromDateKey";
NSString *const kMPUserDefaultsToDateKey           = @"ToDateKey";

#pragma mark - File Export Types

NSString *const kMPExportObjectEvents         = @"Events";
NSString *const kMPExportObjectPeople         = @"People";
NSString *const kMPExportObjectTransactions   = @"Transactions";
NSString *const kMPExportFormatCSV            = @"CSV";
NSString *const kMPExportFormatJSON           = @"JSON";
NSString *const kMPExportTypeEventsRaw        = @"Raw Events";
NSString *const kMPExportTypeEventsCombined   = @"Combined Events";
NSString *const kMPExportTypePeopleProfiles   = @"People Profiles";
NSString *const kMPExportTypePeopleFromEvents = @"People from Events";
NSString *const kMPExportTypeTransactions     = @"Transactions";

#pragma mark - NSNotificationCenter

NSString *const kMPDBWritingBegan           = @"DatabaseWritingBegan";
NSString *const kMPDBWritingUpdate          = @"DatabaseWritingUpdate";
NSString *const kMPDBWritingEnded           = @"DatabaseWritingEnded";
NSString *const kMPFileWritingBegan         = @"FileWritingBegan";
NSString *const kMPFileWritingUpdate        = @"FileWritingUpdate";
NSString *const kMPFileWritingEnded         = @"FileWritingEnded";
NSString *const kMPFileWritingExportObjectKey    = @"FileWritingExportType";
NSString *const kMPFileWritingExportTypeKey = @"FileWritingExportSubType";
NSString *const kMPFileWritingFormatKey        = @"FileWritingFormat";
NSString *const kMPFileWritingCount         = @"FileWritingCount";
NSString *const kMPAPIRequestBegan          = @"APIRequestBega";
NSString *const kMPAPIRequestUpdate         = @"APIRequestUpdate";
NSString *const kMPAPIRequestEnded          = @"APIRequestEnded";
NSString *const kMPAPIRequestCancelled      = @"APIRequestCancelled";
NSString *const kMPAPIRequestFailed         = @"APIRequestFailed";
NSString *const kMPUserInfoKeyCount         = @"UserInfoKeyCount";
NSString *const kMPUserInfoKeyType          = @"UserInfoKeyType";
NSString *const kMPUserInfoKeyHighVolume    = @"UserInfoKeyHighVolume";
NSString *const kMPStatusUpdate             = @"StatusUpdate";
NSString *const kMPUserInfoKeyStatus        = @"UserInfoKeyStatus";

#pragma mark - YapDatabase

NSString *const kMPDBCollectionNameEvents                 = @"eventsCollection";
NSString *const kMPDBCollectionNamePeople                 = @"peopleCollection";
NSString *const kMPDBCollectionNamePropertiesPeople       = @"peoplePropertiesCollection";
NSString *const kMPDBCollectionNamePropertiesEvents       = @"eventPropertiesCollection";
NSString *const kMPDBCollectionNamePropertiesTransactions = @"transactionsPropertiesCollection";
NSString *const kMPDBPropertiesKeyTransactions            = @"transactionPropertiesObjectKey";
NSString *const kMPDBPropertiesKeyPeople                  = @"peoplePropertiesObjectKey";
NSString *const kMPDBPropertiesKeyEvents                  = @"eventPropertiesObjectKey";


@end
