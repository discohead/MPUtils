//
//  JSONWriter.m
//  MPUtils
//
//  Created by Jared McFarland on 7/3/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import "JSONWriter.h"
#import "MPUConstants.h"
#import "AppDelegate.h"
#import <YapDatabase/YapDatabase.h>

@interface JSONWriter ()

@property (strong, nonatomic) NSString *filePath;

@end

@implementation JSONWriter
{
    NSOutputStream *_stream;
    NSStringEncoding _streamEncoding;
}

- (NSString *)filePath
{
    if (!_filePath)
    {
        _filePath = [NSString string];
    }
    return _filePath;
}

-(instancetype)initForWritingToFile:(NSString *)filePath
{
    
    NSOutputStream *outputStream = [NSOutputStream outputStreamToFileAtPath:filePath append:NO];
    
    [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"JSON writer path = %@",[[NSURL fileURLWithPath:filePath] absoluteString]] attributes:@{NSForegroundColorAttributeName:[NSColor darkGrayColor]}]];

    return [self initWithOutputStream:outputStream];
}

- (instancetype)initWithOutputStream:(NSOutputStream *)stream
{
    self = [super init];
    if (self) {
        _stream = stream;
        
        if ([_stream streamStatus] == NSStreamStatusNotOpen) {
            [_stream open];
        }
    }
    return self;
}

- (void)eventsWithPeopleProperties:(BOOL)peopleProps
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingBegan object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatJSON}];
    
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    __block NSUInteger index = 1;
    
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        NSUInteger count = [transaction numberOfKeysInCollection:kMPDBCollectionNameEvents];

        NSData *openBracket = [[NSString stringWithFormat:@"["] dataUsingEncoding:NSUTF8StringEncoding];
        NSData *closeBracket = [[NSString stringWithFormat:@"]"] dataUsingEncoding:NSUTF8StringEncoding];
        NSData *comma = [[NSString stringWithFormat:@","] dataUsingEncoding:NSUTF8StringEncoding];
        
        [_stream write:[openBracket bytes] maxLength:[openBracket length]];
        
        [transaction enumerateKeysAndObjectsInCollection:kMPDBCollectionNameEvents usingBlock:^(NSString *key, NSDictionary *event, BOOL *stop) {
            NSError *error;
            
            if (peopleProps && event[@"properties"][@"distinct_id"])
            {
                if ([transaction hasObjectForKey:event[@"properties"][@"distinct_id"] inCollection:kMPDBCollectionNamePeople])
                {
                    NSDictionary *profile = [transaction objectForKey:event[@"properties"][@"distinct_id"] inCollection:kMPDBCollectionNamePeople];
                    NSMutableDictionary *mutableEvent = [event mutableCopy];
                    mutableEvent[@"$properties"] = profile[@"$properties"];
                    event = mutableEvent;
                }
            }
            
            [NSJSONSerialization writeJSONObject:event toStream:_stream options:NSJSONWritingPrettyPrinted error:&error];
            
            if (error)
            {
                [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"Error serializing JSON for event: %@",event] attributes:@{NSForegroundColorAttributeName:[NSColor redColor]}]];
            }
            
            if (!(index == count)) {
                [_stream write:[comma bytes] maxLength:[comma length]];
            }
            index++;
        }];
        
        [_stream write:[closeBracket bytes] maxLength:[closeBracket length]];
    }];
    
    NSString *subType = peopleProps ? kMPExportTypeEventsCombined : kMPExportTypeEventsRaw;
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingEnded object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatJSON, kMPFileWritingExportObjectKey:kMPExportObjectEvents,kMPFileWritingExportTypeKey:subType, kMPFileWritingCount:@(index-1)}];
}

- (void)peopleProfiles
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingBegan object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatJSON}];
    
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    __block NSUInteger index = 1;
    
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        NSUInteger count = [transaction numberOfKeysInCollection:kMPDBCollectionNamePeople];
        
        NSData *openBracket = [[NSString stringWithFormat:@"["] dataUsingEncoding:NSUTF8StringEncoding];
        NSData *closeBracket = [[NSString stringWithFormat:@"]"] dataUsingEncoding:NSUTF8StringEncoding];
        NSData *comma = [[NSString stringWithFormat:@","] dataUsingEncoding:NSUTF8StringEncoding];
        
        [_stream write:[openBracket bytes] maxLength:[openBracket length]];
        
        [transaction enumerateKeysAndObjectsInCollection:kMPDBCollectionNamePeople usingBlock:^(NSString *key, id profile, BOOL *stop) {
            NSError *error;
            [NSJSONSerialization writeJSONObject:profile toStream:_stream options:NSJSONWritingPrettyPrinted error:&error];
            if (!(index == count))
            {
                [_stream write:[comma bytes] maxLength:[comma length]];
            }
            index++;
        }];
        
        [_stream write:[closeBracket bytes] maxLength:[closeBracket length]];
    }];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingEnded object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatJSON, kMPFileWritingExportObjectKey:kMPExportObjectPeople,kMPFileWritingExportTypeKey:kMPExportTypePeopleProfiles, kMPFileWritingCount:@(index-1)}];
}

- (void)peopleFromEvents
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingBegan object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatJSON}];
    
    AppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    __block NSUInteger index = 1;
    
    NSMutableSet *distinctIDs = [NSMutableSet set];
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [transaction enumerateKeysAndObjectsInCollection:kMPDBCollectionNameEvents usingBlock:^(NSString *key, NSDictionary *event, BOOL *stop) {
            if (event[@"properties"][@"distinct_id"])
            {
                [distinctIDs addObject:event[@"properties"][@"distinct_id"]];
            }
        }];
    }];
    
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        NSError *error;
        NSData *openBracket = [[NSString stringWithFormat:@"["] dataUsingEncoding:NSUTF8StringEncoding];
        NSData *closeBracket = [[NSString stringWithFormat:@"]"] dataUsingEncoding:NSUTF8StringEncoding];
        NSData *comma = [[NSString stringWithFormat:@","] dataUsingEncoding:NSUTF8StringEncoding];
        
        [_stream write:[openBracket bytes] maxLength:[openBracket length]];
        
        NSMutableArray *idsWithProfiles = [NSMutableArray array];
        
        for (NSString *distinctID in distinctIDs)
        {
            if ([transaction hasObjectForKey:distinctID inCollection:kMPDBCollectionNamePeople])
            {
                [idsWithProfiles addObject:distinctID];
            }
        }
        
        
        NSUInteger count = [idsWithProfiles count];
        
        for (NSString *idWithProfile in idsWithProfiles)
        {
            NSDictionary *profile = [transaction objectForKey:idWithProfile inCollection:kMPDBCollectionNamePeople];
            [NSJSONSerialization writeJSONObject:profile toStream:_stream options:NSJSONWritingPrettyPrinted error:&error];
            if (!(index == count))
            {
                [_stream write:[comma bytes] maxLength:[comma length]];
            }
            index++;
        }
        
        [_stream write:[closeBracket bytes] maxLength:[closeBracket length]];
    }];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingEnded object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatJSON, kMPFileWritingExportObjectKey:kMPExportObjectPeople, kMPFileWritingExportTypeKey:kMPExportTypePeopleFromEvents, kMPFileWritingCount:@(index-1)}];
    
}

- (void)updateStatusWithString:(NSAttributedString *)status
{
    NSDictionary *statusInfo = @{kMPUserInfoKeyType:kMPStatusUpdate,kMPUserInfoKeyStatus:status};
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPStatusUpdate object:nil userInfo:statusInfo];
}

@end
