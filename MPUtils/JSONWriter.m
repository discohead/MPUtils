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

@property (strong, nonatomic, readwrite) NSString *filePath;

@end

@implementation JSONWriter
{
    NSOutputStream *_stream;
    NSStringEncoding _streamEncoding;
    NSData *_openBracket;
    NSData *_closeBracket;
    NSData *_comma;
    
}

-(instancetype)initForWritingToFile:(NSString *)filePath
{
    self = [super init];
    
    if (self) {
        NSOutputStream *outputStream = [NSOutputStream outputStreamToFileAtPath:filePath append:NO];
        _stream = outputStream;
        _openBracket = [[NSString stringWithFormat:@"["] dataUsingEncoding:NSUTF8StringEncoding];
        _closeBracket = [[NSString stringWithFormat:@"]"] dataUsingEncoding:NSUTF8StringEncoding];
        _comma = [[NSString stringWithFormat:@","] dataUsingEncoding:NSUTF8StringEncoding];
        _filePath = filePath;
        
        if ([_stream streamStatus] == NSStreamStatusNotOpen) {
            [_stream open];
        }
        
        [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"JSON writer path = %@",[[NSURL fileURLWithPath:filePath] absoluteString]] attributes:@{NSForegroundColorAttributeName:[NSColor darkGrayColor]}]];
    }
    return self;
}

- (instancetype)initWithOutputStream:(NSOutputStream *)stream
{
    self = [super init];
    if (self) {
        _stream = stream;
        _openBracket = [[NSString stringWithFormat:@"["] dataUsingEncoding:NSUTF8StringEncoding];
        _closeBracket = [[NSString stringWithFormat:@"]"] dataUsingEncoding:NSUTF8StringEncoding];
        _comma = [[NSString stringWithFormat:@","] dataUsingEncoding:NSUTF8StringEncoding];
        
        if ([_stream streamStatus] == NSStreamStatusNotOpen) {
            [_stream open];
        }
    }
    return self;
}

- (void)writeEvent:(NSDictionary *)event
{
    NSError *error;
    [NSJSONSerialization writeJSONObject:event toStream:_stream options:NSJSONWritingPrettyPrinted error:&error];
    
    if (error)
    {
        [self updateStatusWithString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"Error serializing JSON for event: %@\nError Message: %@",event,error.localizedDescription] attributes:@{NSForegroundColorAttributeName:[NSColor redColor]}]];
    }
}

- (void)eventsWithPeopleProperties:(BOOL)peopleProps
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingBegan object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatJSON}];
    
    AppDelegate *appDelegate = (AppDelegate *) [[NSApplication sharedApplication] delegate];
    __block NSUInteger index = 1;
    
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        NSUInteger count = [transaction numberOfKeysInCollection:kMPDBCollectionNameEvents];
        
        [self writeOpenBracket];
        
        [transaction enumerateKeysAndObjectsInCollection:kMPDBCollectionNameEvents usingBlock:^(NSString *key, NSDictionary *event, BOOL *stop) {
            
            
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
            [self writeEvent:event];
            
            if (!(index == count)) {
                [self writeComma];
            }
            index++;
        }];
        
        [self writeCloseBracket];
    }];
    
    // Notify ViewController
    NSString *subType = peopleProps ? kMPExportTypeEventsCombined : kMPExportTypeEventsRaw;
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingEnded object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatJSON, kMPFileWritingExportObjectKey:kMPExportObjectEvents,kMPFileWritingExportTypeKey:subType, kMPFileWritingCount:@(index-1)}];
    
    // Notify user
    [self postUserNotificationWithTitle:@"JSON Export Complete" andInfoText:[NSString stringWithFormat:@"%lu events exported",index-1]];
}

- (void)peopleProfiles
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingBegan object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatJSON}];
    
    AppDelegate *appDelegate = (AppDelegate *) [[NSApplication sharedApplication] delegate];
    __block NSUInteger index = 1;
    
    [appDelegate.connection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        NSUInteger count = [transaction numberOfKeysInCollection:kMPDBCollectionNamePeople];
        
        [self writeOpenBracket];
        
        [transaction enumerateKeysAndObjectsInCollection:kMPDBCollectionNamePeople usingBlock:^(NSString *key, id profile, BOOL *stop) {
            [self writeProfile:profile];
            
            if (!(index == count))
            {
                [self writeComma];
            }
            index++;
        }];
        
        [self writeCloseBracket];
    }];
    
    // Notify ViewController
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingEnded object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatJSON, kMPFileWritingExportObjectKey:kMPExportObjectPeople,kMPFileWritingExportTypeKey:kMPExportTypePeopleProfiles, kMPFileWritingCount:@(index-1)}];
    
    // Notify user
    [self postUserNotificationWithTitle:@"JSON Export Complete" andInfoText:[NSString stringWithFormat:@"%lu profiles exported",index-1]];
}

- (void)writeProfile:(NSDictionary *)profile
{
    NSError *error;
    [NSJSONSerialization writeJSONObject:profile toStream:_stream options:NSJSONWritingPrettyPrinted error:&error];
    if (error)
    {
        NSString *message = [NSString stringWithFormat:@"Error writing profile: %@\n Error message: %@",profile,error.localizedDescription];
        [self updateStatusWithString:[[NSAttributedString alloc] initWithString:message attributes:@{NSForegroundColorAttributeName:[NSColor redColor]}]];
    }
}

- (void)writeOpenBracket
{
    [_stream write:[_openBracket bytes] maxLength:[_openBracket length]];
}

- (void)writeCloseBracket
{
    [_stream write:[_closeBracket bytes] maxLength:[_closeBracket length]];
}

- (void)writeComma
{
    [_stream write:[_comma bytes] maxLength:[_comma length]];
}

- (void)peopleFromEvents
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingBegan object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatJSON}];
    
    AppDelegate *appDelegate = (AppDelegate *) [[NSApplication sharedApplication] delegate];
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
        
        [self writeOpenBracket];
        
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
                [self writeComma];
            }
            index++;
        }
        
        [self writeCloseBracket];
    }];
    
    // Notify ViewController
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPFileWritingEnded object:nil userInfo:@{kMPFileWritingFormatKey:kMPExportFormatJSON, kMPFileWritingExportObjectKey:kMPExportObjectPeople, kMPFileWritingExportTypeKey:kMPExportTypePeopleFromEvents, kMPFileWritingCount:@(index-1)}];
    
    // Notify user
    [self postUserNotificationWithTitle:@"JSON Export Complete" andInfoText:[NSString stringWithFormat:@"%lu profiles exported",index-1]];
    
}

- (void)updateStatusWithString:(NSAttributedString *)status
{
    NSDictionary *statusInfo = @{kMPUserInfoKeyType:kMPStatusUpdate,kMPUserInfoKeyStatus:status};
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPStatusUpdate object:nil userInfo:statusInfo];
}

- (void)postUserNotificationWithTitle:(NSString *)title andInfoText:(NSString *)infoText
{
    // Display desktop user notification
    NSUserNotification *userNotification = [[NSUserNotification alloc] init];
    userNotification.title = title;
    userNotification.informativeText = infoText;
    userNotification.soundName = NSUserNotificationDefaultSoundName;
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:userNotification];
}

@end
