//
//  BreweryPrefs.h
//  McBrewery
//
//  Created by Fernando Pereira on 7/2/14.
//  Copyright (c) 2014 Caffeine!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface BreweryPrefs : NSManagedObject

@property (nonatomic, retain) NSString * pkey;
@property (nonatomic, retain) NSString * pvalue;

@end
