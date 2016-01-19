//
//  CSVWriter.h
//  MPUtils
//
//  Created by Jared McFarland on 3/29/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CSVWriter : NSObject

@property (strong, nonatomic, readonly) NSString *filePath;

- (instancetype)initForWritingToFile:(NSString *)filePath;
- (void)eventsWithPeopleProperties:(BOOL)peopleProperties;
- (void)peopleProfiles;
- (void)transactions;
- (void)peopleFromEvents;


- (void)writeHeadersForType:(NSString *)type withProperties:(NSArray *)properties;
- (void)writeProfile:(NSDictionary *)profile withProperties:(NSArray *)properties;
- (void)writeEvent:(NSDictionary *)event withProperties:(NSArray *)properties finishLine:(BOOL)finishLine;

@end
