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

#import "PluginFilter.h"

@implementation PluginFilter

+ (PluginFilter *)filter
{
    return [[[self alloc] init] autorelease];
}

- (id)init {
	if (self = [super init])
	{
		[self initPlugin];
	}
	return self;
}

- (void) willUnload
{
    // Subclass this function if needed: Plugin will unload : prepare for dealloc: release memory and kill sub-process
}

- (void) dealloc
{
	NSLog( @"PluginFilter dealloc");
	
	[super dealloc];
}

- (void) initPlugin
{
	return;
}

- (void)setMenus {  // Opportunity for plugins to make Menu changes if necessary
	return;
}

- (long) prepareFilter:(ViewerController*) vC
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
	viewerController = vC;
	
	return 0;
}

- (BOOL) isCertifiedForMedicalImaging
{
    return NO;
}

- (ViewerController*) duplicateCurrent2DViewerWindow
{
	return [viewerController copyViewerWindow];
}

- (NSArray*) viewerControllersList
{
	return [ViewerController getDisplayed2DViewers];
}

- (long) filterImage:(NSString*) menuName
{
    NSLog(@"%s %d Error, you should not be here!: %@", __FUNCTION__, __LINE__, menuName);
    return -1;
}

- (long) processFiles: (NSMutableArray*) files
{	
	return 0;
}

- (id) report: (NSManagedObject*) study action:(NSString*) action
{
	return 0;
}

// Following stubs are to be subclassed.  Included here to remove compile-time warning messages.

- (id)reportDateForStudy: (NSManagedObject*)study {
	return nil;
}

- (BOOL)deleteReportForStudy: (NSManagedObject*)study {
	return NO;
}

- (BOOL)createReportForStudy: (NSManagedObject*)study {
	return NO;
}

@end
