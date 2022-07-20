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

#import "OSIWindow.h"

static BOOL dontConstrainWindow = NO;

@implementation OSIWindow

+ (void) setDontConstrainWindow: (BOOL) v
{
	dontConstrainWindow = v;
}

- (NSRect) constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen
{
	if( dontConstrainWindow)
		return frameRect;
	
	return [super constrainFrameRect: frameRect toScreen: screen]; 
}

- (void) dealloc
{
    //NSLog(@"%s %d, %p", __FUNCTION__, __LINE__, self);
    [NSObject cancelPreviousPerformRequestsWithTarget: self];
    [super dealloc];
}

@end
