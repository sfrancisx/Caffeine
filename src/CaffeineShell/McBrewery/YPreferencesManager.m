//
//  YPreferencesManager.m
//  McBrewery
//
//  Created by Fernando Pereira on 7/1/14.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import "YPreferencesManager.h"
#import <ExceptionHandling/ExceptionHandling.h>
#import <CoreData/CoreData.h>
#import "BreweryPrefs.h"
#import "YLog.h"
#import "CommonDefs.h"

static NSString* kPrefsTable = @"BreweryPrefs";
static NSString* kPrefsModel = @"prefs";


// save every kCommitSavedChangesEach ocurrences
static const int kCommitSavedChangesEach   = 1;

@interface YPreferencesManager ()

@property    int unsavedCount;

- (NSArray*) getObjectsForKey:(NSString*) key;

- (bool) insertPreferenceValue:(NSString*) value forKey:(NSString*) key;
- (bool) save;

@end

@implementation YPreferencesManager

@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize managedObjectContext = _managedObjectContext;


+ (id) sharedManager
{
    static YPreferencesManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (id)init
{
    if (self = [super init])
    {
        self.unsavedCount = 0;
    }
    return self;
}

- (void) saveUnsavedChanges
{
    if ( ! _managedObjectContext ) return;
    
    YLog(LOG_NORMAL, @"Prefs: Closing datastore - items to be saved: %d", self.unsavedCount);
    if ( self.unsavedCount > 0 )
    {
        self.unsavedCount = kCommitSavedChangesEach - 1;
        [self save];
    }
}

- (bool) save
{
    @try
    {
        if ( (++ self.unsavedCount) < kCommitSavedChangesEach )
        {
            return true;
        }
        
        NSError* error = nil;
        bool rt = [self.managedObjectContext save:&error];
        
        if ( error )
        {
            YLog(LOG_MAXIMUM, @"Prefs: Error saving data - %@", [error description]);
            return false;
        }
        self.unsavedCount = 0;
        return rt;
        
    } @catch (NSException *e) {
        
        YLog(LOG_MAXIMUM, @"Prefs: exception in save");
        return false;
    }
}

- (NSDictionary*) getAllPrefs
{
    YLog(LOG_NORMAL, @"Prefs: getAllPrefs called");
    
    if ( self.managedObjectContext )
    {
        NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
        NSFetchRequest* allPrefs = [[NSFetchRequest alloc] init];
        [allPrefs setEntity:[NSEntityDescription entityForName:kPrefsTable inManagedObjectContext:self.managedObjectContext]];
        
        NSError * error = nil;
        NSArray * prefs = [self.managedObjectContext executeFetchRequest:allPrefs error:&error];
        
        if ( error )
        {
            YLog(LOG_MAXIMUM, @"Prefs: getAllPrefs error retrieving preferences: %@", [error description]);
            return nil;
        }
        
        for (BreweryPrefs* pref in prefs) {
            [dict setValue: pref.pvalue forKey:pref.pkey];
        }
        
        return [NSDictionary dictionaryWithDictionary: dict];
    }
    else
    {
        YLog(LOG_MAXIMUM, @"Prefs: getAllPrefs error - no managed Context");
        return nil;
    }
}

- (NSArray*) getObjectsForKey:(NSString*) key
{
    if ( !self.managedObjectContext )
    {
        YLog(LOG_MAXIMUM, @"Prefs: Error in getObjectsForKey - no managedObjectContext");
        return nil;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName: kPrefsTable];
    NSPredicate* filter = [NSPredicate predicateWithFormat:@ "pkey == %@",  key];
    [request setPredicate: filter];
    [request setPropertiesToFetch: @[@"pkey", @"pvalue"] ];
    
    NSError* error = nil;
    NSArray *fetchedArray = [self.managedObjectContext executeFetchRequest:request error:&error];
    
    if ( error )
    {
        YLog(LOG_MAXIMUM, @"Prefs: Error fetching value for %@ - %@", key, [error description]);
        return nil;
    }
    return fetchedArray;
}

- (NSString*) getPrefValueFor: (NSString*) key
{
    if ( !self.managedObjectContext )
    {
        YLog(LOG_MAXIMUM, @"Prefs: Error in getPrefValueFor - no managedObjectContext");
        return nil;
    }
    
    YLog(LOG_NORMAL, @"Prefs: getPrefValueFor called for key=%@", key);
    NSArray* fetchedArray = [self getObjectsForKey:key];
    if ( fetchedArray && [fetchedArray count]> 0)
    {
        BreweryPrefs* prefs = [fetchedArray objectAtIndex:0];
        YLog(LOG_ONLY_IN_DEBUG, @"Prefs: getPrefValue: %@, %@", key, prefs.pvalue);
        return  prefs.pvalue;
    }
    else
    {
        YLog(LOG_NORMAL, @"Prefs: Didn't find value for key %@", key);
    }
    
    return nil;
}

- (bool) setPrefValue:(NSString*)value forKey:(NSString *)key
{
    if ( !self.managedObjectContext )
    {
        YLog(LOG_MAXIMUM, @"Prefs: Error in setPrefValue - no managedObjectContext");
        return nil;
    }
    
    YLog(LOG_NORMAL, @"Prefs: setPrefValue called for key=%@", key);
    
    NSArray* fetchedArray = [self getObjectsForKey:key];
    if ( fetchedArray && [fetchedArray count]> 0)
    {
        BreweryPrefs* prefs = [fetchedArray objectAtIndex:0];
        prefs.pvalue = value;
        if ( ! [self save] )
        {
            YLog(LOG_MAXIMUM, @"Prefs: Error saving value %@ for %@", value, key);
            return false;
        }
        return true;
    }
    else
        return [self insertPreferenceValue:value forKey:key];
}

- (bool) insertPreferenceValue:(NSString*) value forKey:(NSString*) key
{
    YLog(LOG_NORMAL, @"Prefs: insertPreferenceValue called for key=%@", key);
    
    NSEntityDescription *prefEntity = [[self.managedObjectModel entitiesByName] objectForKey:kPrefsTable];
    BreweryPrefs* prefs = [[BreweryPrefs alloc] initWithEntity:prefEntity insertIntoManagedObjectContext:self.managedObjectContext];
    
    prefs.pkey = key;
    prefs.pvalue = value;
    
    if ( ! [self save] )
    {
        YLog(LOG_MAXIMUM, @"Prefs: Error inserting value %@ for %@", value, key);
        return false;
    }
    else
    {
        YLog(LOG_ONLY_IN_DEBUG, @"Prefs: Saving key,value %@,%@ ", key, value);
        return true;
    }
}

- (bool) removePref:(NSString*) key
{
    if ( !self.managedObjectContext )
    {
        YLog(LOG_MAXIMUM, @"Prefs: Error in removePref - no managedObjectContext");
        return nil;
    }
    YLog(LOG_NORMAL, @"Prefs: removePref called for key=%@", key);
    
    NSArray* fetchedArray = [self getObjectsForKey:key];
    if ( fetchedArray && [fetchedArray count]> 0)
    {
        for ( BreweryPrefs* prefs in fetchedArray )
        {
            [self.managedObjectContext deleteObject: prefs];
        }
        
        NSError* error = nil;
        [self.managedObjectContext save:&error];
        if ( error )
        {
            YLog(LOG_MAXIMUM, @"Prefs: Error deleting key %@ - %@", key, [error description]);
            return false;
        }
    }
    return true;
}

- (bool) removeAllPrefs
{
    if ( !self.managedObjectContext )
    {
        YLog(LOG_MAXIMUM, @"Prefs: Error in removeAllPrefs - no managedObjectContext");
        return nil;
    }
    YLog(LOG_NORMAL, @"Prefs: removeAllPrefs called");
    
    NSFetchRequest* allPrefs = [[NSFetchRequest alloc] init];
    [allPrefs setEntity:[NSEntityDescription entityForName:kPrefsTable inManagedObjectContext:self.managedObjectContext]];
    [allPrefs setIncludesPropertyValues:NO]; //only fetch the managedObjectID
    
    NSError * error = nil;
    NSArray * prefs = [self.managedObjectContext executeFetchRequest:allPrefs error:&error];
    
    if ( error )
    {
        YLog(LOG_MAXIMUM, @"Prefs: removeAllPrefs error retrieving preferences: %@", [error description]);
        return nil;
    }
    
    for (NSManagedObject* pref in prefs) {
        [self.managedObjectContext deleteObject:pref];
    }
    NSError *saveError = nil;
    [self.managedObjectContext save:&saveError];
    
    if ( saveError )
    {
        YLog(LOG_MAXIMUM, @"Prefs: removeAllPrefs error removing preferences: %@", [saveError description]);
        return nil;
    }
    return true;
}

#pragma mark - Core Data stack

// Returns the directory the application uses to store the Core Data store file. This code uses a directory named "Caffeine" in the user's Application Support directory.
- (NSURL *)applicationFilesDirectory
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *appSupportURL = [[[fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject] URLByAppendingPathComponent:kAppTitle];
    YLog(LOG_NORMAL, @"Prefs: Application DB dir = %@", appSupportURL );
    return appSupportURL;
}


// Creates if necessary and returns the managed object model for the application.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel) {
        return _managedObjectModel;
    }
	
    YLog(LOG_NORMAL, @"Prefs: Initializing Object Model" );
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:kPrefsModel withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    if ( ! _managedObjectModel )
    {
        YLog(LOG_MAXIMUM, @"Prefs: failed to initialize %@", modelURL);
        return nil;
    }
    return _managedObjectModel;
}


// Returns the persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.)
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator) {
        return _persistentStoreCoordinator;
    }
    
    NSManagedObjectModel *mom = [self managedObjectModel];
    if (!mom) {
        YLog(LOG_MAXIMUM, @"Prefs: %@:%@ No model to generate a store from", [self class], NSStringFromSelector(_cmd));
        return nil;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *applicationFilesDirectory = [self applicationFilesDirectory];
    NSError *error = nil;
    
    NSDictionary *properties = [applicationFilesDirectory resourceValuesForKeys:@[NSURLIsDirectoryKey] error:&error];
    
    if (!properties) {
        BOOL ok = NO;
        if ([error code] == NSFileReadNoSuchFileError) {
            ok = [fileManager createDirectoryAtPath:[applicationFilesDirectory path] withIntermediateDirectories:YES attributes:nil error:&error];
        }
        if (!ok) {
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    } else {
        if (![properties[NSURLIsDirectoryKey] boolValue]) {
            // Customize and localize this error.
            NSString *failureDescription = [NSString stringWithFormat:@"Expected a folder to store application data, found a file (%@).", [applicationFilesDirectory path]];
            
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            [dict setValue:failureDescription forKey:NSLocalizedDescriptionKey];
            error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:101 userInfo:dict];
            
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    }
    
    NSURL *url = [applicationFilesDirectory URLByAppendingPathComponent: [NSString stringWithFormat:@"%@.db", kPrefsModel] ];
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    if (![coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:url options:nil error:&error]) {
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    _persistentStoreCoordinator = coordinator;
    
    return _persistentStoreCoordinator;
}

// Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.)
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext) {
        return _managedObjectContext;
    }
    
    YLog(LOG_NORMAL, @"Prefs: creating managedObjectContext");
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        YLog(LOG_MAXIMUM, @"Prefs: Failed to initialize managedObjectContext");
        
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:@"Failed to initialize the Preferences store" forKey:NSLocalizedDescriptionKey];
        [dict setValue:@"There was an error building up the data file." forKey:NSLocalizedFailureReasonErrorKey];
        NSError *error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        
        YLog(LOG_MAXIMUM, @"Prefs: Error initializing managedObjectContext - %@", [error description]);
        
        /*
        [[NSApplication sharedApplication] presentError:error];
        */
        return nil;
    }
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    
    return _managedObjectContext;
}

@end
