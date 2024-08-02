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

#import "ToolbarPanel.h"
#import "ToolBarNSWindow.h"
#import "ViewerController.h"
#import "AppController.h"
#import "NSWindow+N2.h"
#import "N2Debug.h"
#import "Notifications.h"

// Height of the toolbar window
#define FIXED_HEIGHT    97  // was 92

@implementation ToolbarPanelController

// Move up the toolbar so that its title is hidden under the system menu bar
// and there is more room to display other windows
+ (int) hiddenHeight {
    return 20; // The window title "2D Toolbar" nicely disappears off the top of the screen.
}

+ (int) exposedHeight {
	return FIXED_HEIGHT - [ToolbarPanelController hiddenHeight];
}

+ (void) checkForValidToolbar
{
    // Check that a toolbar is visible for all screens
    for (NSScreen *s in [NSScreen screens])
    {
        ViewerController *v = [ViewerController frontMostDisplayed2DViewerForScreen: s];
        
        if (v) {
            if ([v.toolbarPanel.window.toolbar customizationPaletteIsRunning] == NO)
                [v.toolbarPanel.window orderBack: self];
        }
    }
}

-(void)applicationDidChangeScreenParameters:(NSNotification*)aNotification
{
	NSRect screenRect = [self.viewer.window.screen visibleFrame];
	
	NSRect dstframe;
	dstframe.size.height = FIXED_HEIGHT;
	dstframe.size.width = screenRect.size.width;
	dstframe.origin.x = NSMinX(screenRect);
	dstframe.origin.y = NSMaxY(screenRect) - dstframe.size.height + [ToolbarPanelController hiddenHeight];

    if (NSEqualRects( dstframe, self.window.frame) == NO)
        [[self window] setFrame:dstframe display:YES];
}

- (id)initForViewer:(ViewerController *)v withToolbar:(NSToolbar *)t
{
    self = [super initWithWindowNibName:@"ToolbarPanel"];
	if (self)
	{
		toolbar = [t retain];
        _viewer = [v retain];

        [[self window] setAnimationBehavior: NSWindowAnimationBehaviorNone];
        [[self window] setToolbar: toolbar];
        [[self window] setLevel: NSNormalWindowLevel];
        [[self window] makeMainWindow];
        
        [toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
        [toolbar setShowsBaselineSeparator: NO];
        [toolbar setVisible: YES];
        
        [self applicationDidChangeScreenParameters: nil];
        
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidChangeScreenParameters:) name:NSApplicationDidChangeScreenParametersNotification object:NSApp];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewerWillClose:) name: OsirixCloseViewerNotification object: nil];
		
        [[self window] setCollectionBehavior: NSWindowCollectionBehaviorIgnoresCycle];
		
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeMain:) name:NSWindowDidBecomeMainNotification object:0];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:0];
        
        [self.window safelySetMovable:NO];
        //[self.window setShowsToolbarButton:NO];
	}
	
	return self;
}

- (void) close
{
    [self.window orderOut: self];
    
    [super close];
    
    self.window.toolbar = nil;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
    
    [self.viewer release];
    [toolbar release];
	[super dealloc];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
	if( [aNotification object] == [self window])
	{
        if( [[self.viewer window] isVisible])
        {
            if( [self.window.toolbar customizationPaletteIsRunning] == NO)
            {
                [[self.viewer window] makeKeyAndOrderFront: self];
                [self.window orderBack: self];
            }
        }
        else
            [self.window orderOut: self];
	}
}

- (void)windowDidBecomeMain:(NSNotification *)aNotification
{
	if( [aNotification object] == [self window])
	{
        if( [[self.viewer window] isVisible])
        {
            if( [self.window.toolbar customizationPaletteIsRunning] == NO)
            {
                [[self.viewer window] makeKeyAndOrderFront: self];
                [self.window orderBack: self];
            }
        }
        else
            [self.window orderOut: self];
	}
}

- (NSToolbar*) toolbar
{
	return toolbar;
}

- (void) viewerWillClose: (NSNotification*) n
{
    if( [n object] == self.viewer)
        [self.window orderOut: self];
}
@end
