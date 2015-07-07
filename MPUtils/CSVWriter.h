//
//  CSVWriter.h
//  MPUtils
//
//  Created by Jared McFarland on 3/29/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CSVWriter : NSObject

- (instancetype)initForWritingToFile:(NSString *)filePath;
- (void)eventsWithPeopleProperties:(BOOL)peopleProperties;
- (void)peopleProfiles;
- (void)transactions;
- (void)peopleFromEvents;

@end
