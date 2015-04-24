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

#pragma mark - NSNotificationCenter

NSString *const kMPCSVWritingBegan   = @"CSVWritingBegan";
NSString *const kMPCSVWritingEnded   = @"CSVWritingEnded";
NSString *const kMPExportBegan       = @"ExportBegan";
NSString *const kMPExportUpdate      = @"ExportUpdate";
NSString *const kMPExportEnd         = @"ExportEnd";
NSString *const kMPUserInfoKeyCount  = @"UserInfoKeyCount";
NSString *const kMPUserInfoKeyType   = @"UserInfoKeyType";
NSString *const kMPStatusUpdate      = @"StatusUpdate";
NSString *const kMPUserInfoKeyStatus = @"UserInfoKeyStatus";

#pragma mark - Couchbase Lite

NSString *const kMPCBLDatabaseName                  = @"mputils-database";
NSString *const kMPCBLThreadName                    = @"couchbaseLiteThread";

NSString *const kMPCBLDocumentTypeEvent             = @"event";
NSString *const kMPCBLDocumentTypePeopleProfile     = @"people profile";
NSString *const kMPCBLDocumentTypeEventProperties   = @"event properties";
NSString *const kMPCBLDocumentTypePeopleProperties  = @"people properties";

NSString *const kMPCBLDocumentKeyType                    = @"type";
NSString *const kMPCBLDocumentKeyID                      = @"_id";
NSString *const kMPCBLDocumentKeyEventPropertyKeys       = @"eventPropertyKeys";
NSString *const kMPCBLDocumentKeyPeoplePropertyKeys      = @"peoplePropertyKeys";
NSString *const kMPCBLDocumentKeyTransactionPropertyKeys = @"transactionPropertyKeys";

NSString *const kMPCBLEventDocumentKeyEvent         = @"event";
NSString *const kMPCBLEventDocumentKeyProperties    = @"properties";
NSString *const kMPCBLEventDocumentKeyDistinctID    = @"distinct_id";

NSString *const kMPCBLPeopleDocumentKeyDistinctID   = @"$distinct_id";
NSString *const kMPCBLPeopleDocumentKeyProperties   = @"$properties";
NSString *const kMPCBLPeopleDocumentKeyTransactions = @"$transactions";

NSString *const kMPCBLDocumentIDEventProperties       = @"eventPropertiesDocumentID";
NSString *const kMPCBLDocumentIDPeopleProperties      = @"peoplePropertiesDocumentID";
NSString *const kMPCBLDocumentIDTransactionProperties = @"transactionPropertiesDocumentID";

NSString *const kMPCBLViewNameEvents                = @"eventsView";
NSString *const kMPCBLViewNamePeople                = @"peopleView";
NSString *const kMPCBLViewNameCombined              = @"combinedView";
NSString *const kMPCBLViewNameTransactions          = @"transactionsView";
NSString *const kMPCBLViewNameEventCount            = @"eventCountView";
NSString *const kMPCBLViewNameEventProperties       = @"eventPropertiesView";
NSString *const kMPCBLViewNamePeopleCount           = @"peopleCountView";
NSString *const kMPCBLViewNameEventDistinctIDs      = @"eventDistinctIDsView";
NSString *const kmPCBlViewNamePeopleProperties      = @"peoplePropertiesView";

@end
