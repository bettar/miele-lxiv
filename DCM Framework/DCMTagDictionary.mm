//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//
//  At the end of 2014 the project was forked from OsiriX to become Miele-LXIV
//  The original header follows:
/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - LGPL
  
  See http://www.osirix-viewer.com/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

#import "DCM.h"

static DCMTagDictionary *sharedTagDictionary; 

@implementation DCMTagDictionary

+(id)sharedTagDictionary
{
	if (!sharedTagDictionary)
    {
        //NSDate *date = [NSDate date];
		NSBundle *bundle = [NSBundle bundleForClass:NSClassFromString(@"DCMTagDictionary")];

#if 1
        NSMutableDictionary *combinedDict = [[NSMutableDictionary alloc] init];
        NSArray *array = @[ @"tagDictionary", @"privateTagDictionary" ];
        for (id aa in array)
        {
            NSString *path = [bundle pathForResource:aa ofType:@"plist"];
            if (path == nil) {
                NSLog(@"Cannot find dictionary %@", aa);
                continue;
            }

            // dictionaryWithContentsOfFile is deprecated
            NSURL *url = [NSURL fileURLWithPath:path]; // ng with URLWithString
            if (url == nil) {
                NSLog(@"Cannot find url %@", path);
                continue;
            }
            NSError *err;
            NSDictionary *dd = [NSDictionary dictionaryWithContentsOfURL:url error:&err];
            //NSLog(@"dd count %lu, %@", (unsigned long)dd.count, err);

            [combinedDict addEntriesFromDictionary: dd];
        }
        
        //NSLog(@"combinedDict count %lu", (unsigned long)combinedDict.count);

        sharedTagDictionary = [combinedDict copy];
#else
        sharedTagDictionary = [[DCMTagDictionary alloc] initWithContentsOfFile:path]; // deprecated, use initWithContentsOfURL
#endif
		
//		NSLog( @"%@", sharedTagDictionary);
		
		//NSTimeInterval time = [[NSDate date] timeIntervalSinceDate:date];
	}
	
//	NSEnumerator *enumerator = [sharedTagDictionary objectEnumerator];	THIS LOOP IS EXTREMELY SLOW!
//	NSDictionary *dict;
//	while (dict = [enumerator nextObject]){
//		if (![dict objectForKey:@"VR"])
//			NSLog([dict description]);
//	}
	
	return sharedTagDictionary;	
}

- (void) dealloc {
	[super dealloc];
}

@end
