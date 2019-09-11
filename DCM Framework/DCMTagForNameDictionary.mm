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

static DCMTagForNameDictionary *sharedTagForNameDictionary; 

@implementation DCMTagForNameDictionary

+(id)sharedTagForNameDictionary
{
	if (!sharedTagForNameDictionary)
	{
		NSBundle *bundle;
		if (DCMFramework_compile)
			bundle  = [NSBundle bundleForClass:NSClassFromString(@"DCMTagForNameDictionary")];
		else
			bundle = [NSBundle mainBundle];
			
		NSString *path = [bundle pathForResource:@"nameDictionary" ofType:@"plist"];
		if( path == nil)
		{
			
		}
		
		sharedTagForNameDictionary = (DCMTagForNameDictionary *)[[NSDictionary dictionaryWithContentsOfFile:path] retain];
	}

    return sharedTagForNameDictionary;
}

- (void) dealloc {
	[sharedTagForNameDictionary release];
	[super dealloc];
}

@end
