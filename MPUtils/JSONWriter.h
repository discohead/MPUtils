//
//  JSONWriter.h
//  MPUtils
//
//  Created by Jared McFarland on 7/3/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JSONWriter : NSObject

- (instancetype)initForWritingToFile:(NSString *)filePath;

- (void)eventsWithPeopleProperties:(BOOL)peopleProps;
- (void)peopleProfiles;
- (void)peopleFromEvents;

@end
