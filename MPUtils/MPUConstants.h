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

#pragma mark - Export Results Keys

extern NSString *const kMPPeopleKeyResults;
extern NSString *const kMPPeopleKeySessionID;
extern NSString *const kMPPeopleKeyPage;

#pragma mark - NSUserDefaults Keys

extern NSString *const kMPUserDefaultsProjectsKey;
extern NSString *const kMPUserDefaultsProjectAPIKeyKey;
extern NSString *const kMPUserDefaultsProjectAPISecretKey;
extern NSString *const kMPUserDefaultsProjectTokenKey;
extern NSString *const kMPUserDefaultsProjectNameKey;
extern NSString *const kMPuserDefaultsUIProjectNamesKey;

#pragma mark - NSNotificationCenter

extern NSString *const kMPCSVWritingBegan;
extern NSString *const kMPCSVWritingEnded;
extern NSString *const kMPExportBegan;
extern NSString *const kMPExportUpdate;
extern NSString *const kMPExportEnd;
extern NSString *const kMPUserInfoKeyCount;
extern NSString *const kMPUserInfoKeyType;
extern NSString *const kMPStatusUpdate;
extern NSString *const kMPUserInfoKeyStatus;

#pragma mark - Couchbase Lite

extern NSString *const kMPCBLDatabaseName;
extern NSString *const kMPCBLThreadName;

extern NSString *const kMPCBLDocumentTypeEvent;
extern NSString *const kMPCBLDocumentTypePeopleProfile;
extern NSString *const kMPCBLDocumentTypeEventProperties;
extern NSString *const kMPCBLDocumentTypePeopleProperties;

extern NSString *const kMPCBLDocumentKeyType;
extern NSString *const kMPCBLDocumentKeyID;
extern NSString *const kMPCBLDocumentKeyEventPropertyKeys;
extern NSString *const kMPCBLDocumentKeyPeoplePropertyKeys;
extern NSString *const kMPCBLDocumentKeyTransactionPropertyKeys;

extern NSString *const kMPCBLPeopleDocumentKeyDistinctID;
extern NSString *const kMPCBLPeopleDocumentKeyProperties;
extern NSString *const kMPCBLPeopleDocumentKeyTransactions;

extern NSString *const kMPCBLEventDocumentKeyEvent;
extern NSString *const kMPCBLEventDocumentKeyProperties;
extern NSString *const kMPCBLEventDocumentKeyDistinctID;

extern NSString *const kMPCBLDocumentIDEventProperties;
extern NSString *const kMPCBLDocumentIDPeopleProperties;
extern NSString *const kMPCBLDocumentIDTransactionProperties;

extern NSString *const kMPCBLViewNameEvents;
extern NSString *const kMPCBLViewNameEventDistinctIDs;
extern NSString *const kMPCBLViewNamePeople;
extern NSString *const kMPCBLViewNameCombined;
extern NSString *const kMPCBLViewNameTransactions;
extern NSString *const kMPCBLViewNameEventCount;
extern NSString *const kMPCBLViewNameEventProperties;
extern NSString *const kMPCBLViewNamePeopleCount;
extern NSString *const kmPCBlViewNamePeopleProperties;

@end

