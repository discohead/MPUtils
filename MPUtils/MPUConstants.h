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
extern NSString *const kMPUserDefaultsSelectedProjectKey;
extern NSString *const kMPUserDefaultsWhereClauseKey;
extern NSString *const kMPUserDefaultsEventsKey;
extern NSString *const kMPUserDefaultsFromDateKey;
extern NSString *const kMPUserDefaultsToDateKey;

#pragma mark - File Export Types

extern NSString *const kMPExportObjectEvents;
extern NSString *const kMPExportObjectPeople;
extern NSString *const kMPExportObjectTransactions;
extern NSString *const kMPExportFormatCSV;
extern NSString *const kMPExportFormatJSON;
extern NSString *const kMPExportTypeEventsRaw;
extern NSString *const kMPExportTypeEventsCombined;
extern NSString *const kMPExportTypePeopleProfiles;
extern NSString *const kMPExportTypePeopleFromEvents;
extern NSString *const kMPExportTypeTransactions;

#pragma mark - NSNotificationCenter

extern NSString *const kMPDBWritingBegan;
extern NSString *const kMPDBWritingUpdate;
extern NSString *const kMPDBWritingEnded;
extern NSString *const kMPFileWritingBegan;
extern NSString *const kMPFileWritingUpdate;
extern NSString *const kMPFileWritingEnded;
extern NSString *const kMPFileWritingExportObjectKey;
extern NSString *const kMPFileWritingExportTypeKey;
extern NSString *const kMPFileWritingFormatKey;
extern NSString *const kMPFileWritingCount;
extern NSString *const kMPAPIRequestBegan;
extern NSString *const kMPAPIRequestUpdate;
extern NSString *const kMPAPIRequestEnded;
extern NSString *const kMPAPIRequestCancelled;
extern NSString *const kMPAPIRequestFailed;
extern NSString *const kMPUserInfoKeyCount;
extern NSString *const kMPUserInfoKeyType;
extern NSString *const kMPUserInfoKeyHighVolume;
extern NSString *const kMPStatusUpdate;
extern NSString *const kMPUserInfoKeyStatus;

#pragma mark - YapDatabase

extern NSString *const kMPDBCollectionNameEvents;
extern NSString *const kMPDBCollectionNamePeople;
extern NSString *const kMPDBCollectionNamePropertiesPeople;
extern NSString *const kMPDBCollectionNamePropertiesEvents;
extern NSString *const kMPDBCollectionNamePropertiesTransactions;
extern NSString *const kMPDBPropertiesKeyTransactions;
extern NSString *const kMPDBPropertiesKeyPeople;
extern NSString *const kMPDBPropertiesKeyEvents;

@end

