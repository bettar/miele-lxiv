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

#import <AppKit/AppKit.h>
#import "ViewerController.h"

/** Window Controller for Toolbar */
@interface ToolbarPanelController : NSWindowController <NSToolbarDelegate>
{	
	NSToolbar *toolbar;
	BOOL dontReenter;
}

@property (readonly) ViewerController *viewer;

+ (int) hiddenHeight;
+ (int) exposedHeight;

- (id)initForViewer: (ViewerController*) v withToolbar: (NSToolbar*) t;
- (NSToolbar*) toolbar;
+ (void) checkForValidToolbar;
- (void)applicationDidChangeScreenParameters:(NSNotification*)aNotification;

@end
