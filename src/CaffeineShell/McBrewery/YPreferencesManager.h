//
//  YPreferencesManager.h
//  McBrewery
//
//  Created by Fernando Pereira on 7/1/14.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface YPreferencesManager : NSObject

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

+ (id)sharedManager;

- (NSString*) getPrefValueFor: (NSString*) key;
- (NSDictionary*) getAllPrefs;

- (bool) setPrefValue:(NSString*)value forKey:(NSString *)key;

- (bool) removePref:(NSString*) key;
- (bool) removeAllPrefs;

- (void) saveUnsavedChanges;

@end
