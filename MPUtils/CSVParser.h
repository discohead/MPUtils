//
//  CSVParser.h
//  MPUtils
//
//  Created by Jared McFarland on 3/29/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CSVParser : NSObject

- (instancetype)initForWritingToFile:(NSString *)filePath;
- (void)eventsToCSVWithPeopleProperties:(BOOL)peopleProperties;
- (void)peopleToCSV;
- (void)transactionsToCSV;
- (void)peopleFromEventsToCSV;

@end
