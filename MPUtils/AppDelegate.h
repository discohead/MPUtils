//
//  AppDelegate.h
//  MPUtils
//
//  Created by Jared McFarland on 3/29/15.
//  Copyright (c) 2015 Jared McFarland. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CouchbaseLite/CouchbaseLite.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong, nonatomic) CBLManager *manager;
@property (strong, nonatomic) CBLDatabase *database;

- (void)setupCouchbaseLite;
@end

