//
//  AppDelegate.h
//  MPUtils
//
//  Created by Jared McFarland on 3/29/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class YapDatabase, YapDatabaseConnection;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong, nonatomic) YapDatabase *database;
@property (strong, nonatomic) YapDatabaseConnection *connection;

@end

