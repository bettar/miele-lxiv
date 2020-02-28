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

#import <PreferencePanes/PreferencePanes.h>

@interface PreferencesView : NSControl
{
	NSMutableArray* groups;
	id buttonActionTarget;
	SEL buttonActionSelector;
}

@property(retain) id buttonActionTarget;
@property(assign) SEL buttonActionSelector;

-(void)addItemWithTitle: (NSString*)title
                  image: (NSImage*)image
        toGroupWithName: (NSString*)groupName
                context: (id)context;

-(NSUInteger)itemsCount;
-(id)contextForItemAtIndex: (NSUInteger)index;
-(NSInteger)indexOfItemWithContext: (id)context;
-(void)removeItemWithBundle: (NSBundle*) bundle;

@end
