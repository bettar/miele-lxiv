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

#import "mgl.h"

#import "OSIWindowController.h"
#import "ToolbarPanel.h"
#import "ThumbnailsListPanel.h"
#import "NavigatorView.h"
//#import "NavigatorWindowController.h"
#import "AppController.h"
#import "ViewerController.h"
#import "BrowserController.h"
#import "Notifications.h"
#import <Carbon/Carbon.h>
#import "DCMPix.h"
#import "DicomStudy.h"
#import "DicomSeries.h"
#import "DicomImage.h"
#import "DicomDatabase.h"
#import "N2Debug.h"

static	BOOL dontEnterMagneticFunctions = NO;
static	BOOL dontWindowDidChangeScreen = NO;
//extern  BOOL USETOOLBARPANEL;
//extern  ToolbarPanelController  *toolbarPanel[ MAXSCREENS ];
extern int delayedTileWindows;

static BOOL protectedReentryWindowDidResize = NO;

@implementation OSIWindowController

@synthesize database = _database;

-(void)setDatabase:(DicomDatabase*)database {
	if (database != _database) {
		if (_database) {
			[[NSNotificationCenter defaultCenter] removeObserver:self name:OsirixAddToDBNotification object:_database];
			[[NSNotificationCenter defaultCenter] removeObserver:self name:OsirixDatabaseObjectsMayBecomeUnavailableNotification object:_database];
			[[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextObjectsDidChangeNotification object:_database.managedObjectContext];
            
            [_database release];
            _database = nil;
		}
		
		_database = [database retain];
		
		if (_database) {
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observeDatabaseAddNotification:) name:OsirixAddToDBNotification object:_database];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observeDatabaseObjectsMayFaultNotification:) name:OsirixDatabaseObjectsMayBecomeUnavailableNotification object:_database];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observeManagedObjectContextObjectsDidChangeNotification:) name:NSManagedObjectContextObjectsDidChangeNotification object:_database.managedObjectContext];
		}
	}
}

-(void)refreshDatabase:(NSArray*)newImages {
}

-(void)observeDatabaseAddNotification:(NSNotification*)notification {
	[self refreshDatabase:[[notification userInfo] objectForKey:OsirixAddToDBCompleteNotificationImagesArray]];
}

-(void)observeManagedObjectContextObjectsDidChangeNotification:(NSNotification*)notification {
}

-(void)observeDatabaseObjectsMayFaultNotification:(NSNotification*)notification {
	[self close];
}

#pragma mark - Magnetic Windows & Tiling

#ifndef MIELE_LIGHT
- (IBAction) paste:(id) sender
{
	if ([[self pixList] count])
	{
		DCMPix *pix = [[self pixList] lastObject];
		
		if ([pix seriesObj])
			[[BrowserController currentBrowser] selectThisStudy: [[pix seriesObj] valueForKey: @"study"]];
		
		[[BrowserController currentBrowser] pasteImageForSourceFile: [pix sourceFile]];
	}
}
#endif

- (void) setMagnetic:(BOOL) a
{
	magneticWindowActivated = a;
}

- (BOOL) magnetic
{
	return magneticWindowActivated;
}

+ (void) setDontEnterMagneticFunctions:(BOOL) a
{
	dontEnterMagneticFunctions = a;
}

+ (BOOL) dontWindowDidChangeScreen
{
	return dontWindowDidChangeScreen;
}

+ (void) setDontEnterWindowDidChangeScreen:(BOOL) a
{
	dontWindowDidChangeScreen = a;
}

- (void) windowDidResize:(NSNotification *)aNotification
{
	if (protectedReentryWindowDidResize)
        return;
	
	protectedReentryWindowDidResize = YES;

    if (magneticWindowActivated)
	{
		if (dontEnterMagneticFunctions == NO &&
            Button() != 0)
		{
			if ([[NSUserDefaults standardUserDefaults] boolForKey:@"MagneticWindows"])
			{
                NSWindow *theWindow = [aNotification object];
                NSRect myFrame = [theWindow frame];
				
				float gravityX = 30;
				float gravityY = 30;
				
				if ([[NSApp currentEvent] modifierFlags] & NSEventModifierFlagOption)
				{
					protectedReentryWindowDidResize = NO;
					return;
				}
				
				NSMutableArray *rects = [NSMutableArray array];
				
				// Add the viewers
                NSWindow *window;
                NSEnumerator *e = [[NSApp windows] objectEnumerator];
				while (window = [e nextObject])
				{
					if (window != theWindow &&
                        [window isVisible] &&
                        [[window windowController] isKindOfClass: [OSIWindowController class]] &&
                        [window.screen isEqualTo: theWindow.screen])
					{
						if ([[window windowController] magnetic])
							[rects addObject: [NSValue valueWithRect: [window frame]]];
					}
				}
				
				// Add the current screen ONLY
	//			e = [[NSScreen screens] objectEnumerator];
	//			while (screen = [e nextObject])
				{
					NSRect frame2 = [AppController usefulRectForScreen: [[self window] screen]];
					frame2 = [NavigatorView adjustIfScreenAreaIf4DNavigator: frame2];
					[rects addObject: [NSValue valueWithRect: frame2]];
				}
				
				NSRect dstFrame = myFrame;

                for (NSValue *value in rects)
				{
                    NSRect frame3 = [value rectValue];

                    /* Horizontal magnet */

                    float dx2 = fabs(NSMinX(frame3) - NSMaxX(myFrame));
					if (gravityX >= dx2)	// LEFT
                    {
						gravityX = dx2;
						dstFrame.size.width = frame3.origin.x - myFrame.origin.x;
					}
					
					/* Vertical magnet */

                    float dy1 = fabs(NSMinY(frame3) - NSMinY(myFrame));
					if (gravityY >= dy1)	// TOP
                    {
						gravityY = dy1;
						
						NSRect previous = dstFrame;
						dstFrame.origin.y = NSMinY(frame3);
						dstFrame.size.height = dstFrame.size.height - (dstFrame.origin.y - previous.origin.y);
					}
				}
				
				for (NSValue *value in rects)
				{
                    NSRect frame3 = [value rectValue]; // bug fix ?

                    float dx4 = fabs(NSMaxX(frame3) - NSMaxX(myFrame));
                    if (gravityX >= dx4)	// RIGHT
                    {
						gravityX = dx4;
						dstFrame.size.width = NSMaxX(frame3) - NSMinX(myFrame);
					}
				
                    float dy3 = fabs(NSMaxY(frame3) - NSMinY(myFrame));
					if (gravityY >= dy3)	// BOTTOM
                    {
						gravityY = dy3;
						
						NSRect previous = dstFrame;
						dstFrame.origin.y = NSMaxY(frame3);
						dstFrame.size.height = dstFrame.size.height - (dstFrame.origin.y - previous.origin.y);
					}
				}
				
				dontEnterMagneticFunctions = YES;
				[theWindow setFrame:dstFrame display:YES];
				dontEnterMagneticFunctions = NO;
			}
			
			if ([self isKindOfClass: [ViewerController class]])
			{
				if ([aNotification object] == [self window])
				{
                    ViewerController *vv = (ViewerController*) self;
					[vv showCurrentThumbnail: self];
				}
			}
			
			if ([[NSApp currentEvent] modifierFlags] & NSEventModifierFlagShift)
			{
				// Apply the same size to all displayed windows
				
				NSArray	*viewers = [ViewerController getDisplayed2DViewers];
				
				for (id loopItem in viewers)
				{
					if (loopItem != self)
					{
						NSWindow *theWindow = [loopItem window];
						
						NSRect dstFrame = [theWindow frame];
						dstFrame.size = [[self window] frame].size;
						dstFrame.origin.y -= dstFrame.size.height - [theWindow frame].size.height;
						
						dontEnterMagneticFunctions = YES;
						[theWindow setFrame: dstFrame display:YES];
						dontEnterMagneticFunctions = NO;
					}
				}
			} // if SHIFT
		}
		else
		{
			NSRect dstFrame = [[self window] frame];
			NSRect visibleRect = [AppController usefulRectForScreen: self.window.screen];
            
            if (dstFrame.size.height >= visibleRect.size.height)
                dstFrame.size.height = visibleRect.size.height;
            
            if (dstFrame.size.width >= visibleRect.size.width)
                dstFrame.size.width = visibleRect.size.width;
			
			if (dstFrame.size.height < [[self window] contentMinSize].height)
                dstFrame.size.height = [[self window] contentMinSize].height;

            if (dstFrame.size.width < [[self window] contentMinSize].width)
                dstFrame.size.width = [[self window] contentMinSize].width;
			
			dstFrame = [NavigatorView adjustIfScreenAreaIf4DNavigator: dstFrame];
			
			if (NSEqualRects( dstFrame, [[self window] frame]) == NO)
				[[self window] setFrame: dstFrame display:YES];
		}
		
        if ([[NSUserDefaults standardUserDefaults] boolForKey: @"UseFloatingThumbnailsList"] == NO)
        {
            if ([self isKindOfClass: [ViewerController class]])
                [(ViewerController*)self showCurrentThumbnail: self];
        }
	}
	
	protectedReentryWindowDidResize = NO;
}

- (void) autoHideMatrix
{
}

- (void) syncThumbnails
{
}

- (void) refreshToolbar
{
}

- (id) imageView
{
	return nil;
}

- (void) propagateSettings
{
}

- (NSArray*) fileList
{
	return nil;
}

- (void)setWindowFrame:(NSRect)rect showWindow:(BOOL) showWindow animate: (BOOL) animate
{
	[[self window] setFrame: rect display: NO];
}

- (BOOL) windowWillClose
{
	return NO;
}

- (void)windowWillMove:(NSNotification *)notification
{
	if (!magneticWindowActivated)
        return;

    windowIsMovedByTheUserO = NO;
    
    if (dontEnterMagneticFunctions == NO)
    {
        savedWindowsFrameO = [[self window] frame];
        
        if (Button())
            windowIsMovedByTheUserO = YES;
    }
}

- (void)windowDidMove:(NSNotification *)notification
{
    if (!magneticWindowActivated)
        return;

    if (/*!Button() && */
        windowIsMovedByTheUserO == YES &&
        dontEnterMagneticFunctions == NO &&
        [[NSUserDefaults standardUserDefaults] boolForKey:@"MagneticWindows"] &&
        NSIsEmptyRect( savedWindowsFrameO) == NO)
    {
        if (Button() == 0)
            windowIsMovedByTheUserO = NO;
        
        NSWindow *theWindow = [self window];
        NSRect myFrame = [theWindow frame];
        
        float gravityX = myFrame.size.width/4;
        float gravityY = myFrame.size.height/4;
        
        if ([[NSApp currentEvent] modifierFlags] & NSEventModifierFlagOption)
            return;
        
        NSMutableArray *rects = [NSMutableArray array];
        
        // Add the viewers
        NSWindow *window;
        NSEnumerator *e = [[NSApp windows] objectEnumerator];
        while (window = [e nextObject])
        {
            if (window != theWindow &&
                [window isVisible] &&
                [[window windowController] isKindOfClass: [OSIWindowController class]] &&
                [window.screen isEqualTo: theWindow.screen])
            {
                if ([[window windowController] magnetic])
                    [rects addObject: [NSValue valueWithRect: [window frame]]];
            }
        }
        
        // Add the current screen ONLY
//		e = [[NSScreen screens] objectEnumerator];
//		while (screen = [e nextObject])
        {
            NSRect frame2 = [AppController usefulRectForScreen: [[self window] screen]];
            frame2 = [NavigatorView adjustIfScreenAreaIf4DNavigator: frame2];
            [rects addObject: [NSValue valueWithRect: frame2]];
        }
        
        NSRect dstFrame = myFrame;
        
        for (NSValue *value in rects)
        {
            NSRect frame3 = [value rectValue];
            
            /* Horizontal magnet */

            float dx1 = fabs(NSMinX(frame3) - NSMinX(myFrame));
            if (gravityX >= dx1)
            {
                gravityX = dx1;
                dstFrame.origin.x = NSMinX(frame3);
            }
            
            float dx2 = fabs(NSMinX(frame3) - NSMaxX(myFrame));
            if (gravityX >= dx2)
            {
                gravityX = dx2;
                dstFrame.origin.x = NSMinX(frame3) - NSWidth(myFrame);
            }
            
            float dx3 = fabs(NSMaxX(frame3) - NSMinX(myFrame));
            if (gravityX >= dx3)
            {
                gravityX = dx3;
                dstFrame.origin.x = NSMaxX(frame3);
            }
            
            float dx4 = fabs(NSMaxX(frame3) - NSMaxX(myFrame));
            if (gravityX >= dx4)
            {
                gravityX = dx4;
                dstFrame.origin.x = NSMaxX(frame3) - NSWidth(myFrame);
            }
            
            /* Vertical magnet */

            float dy1 = fabs(NSMinY(frame3) - NSMinY(myFrame));
            if (gravityY >= dy1)
            {
                gravityY = dy1;
                dstFrame.origin.y = NSMinY(frame3);
            }
            
            float dy2 = fabs(NSMinY(frame3) - NSMaxY(myFrame));
            if (gravityY >= dy2)
            {
                gravityY = dy2;
                dstFrame.origin.y = NSMinY(frame3) - NSHeight(myFrame);
            }
            
            float dy3 = fabs(NSMaxY(frame3) - NSMinY(myFrame));
            if (gravityY >= dy3)
            {
                gravityY = dy3;
                dstFrame.origin.y = NSMaxY(frame3);
            }
            
            float dy4 = fabs(NSMaxY(frame3) - NSMaxY(myFrame));
            if (gravityY >= dy4)
            {
                gravityY = dy4;
                dstFrame.origin.y = NSMaxY(frame3) - NSHeight(myFrame);
            }
        }
        
        myFrame = dstFrame;
        
        dontEnterMagneticFunctions = YES;
        [AppController resizeWindowWithAnimation: theWindow newSize: myFrame];
        dontEnterMagneticFunctions = NO;
        
        if ([self isKindOfClass: [ViewerController class]])
            [(ViewerController*) self updateNavigator];
        
        // Is the Origin identical? If yes, switch both windows
        e = [[NSApp windows] objectEnumerator];
        while (window = [e nextObject])
        {
            if (window != theWindow &&
                [window isVisible] &&
                [[window windowController] isKindOfClass: [OSIWindowController class]])
            {
                if ([[window windowController] magnetic])
                {
                    NSRect frame4 = [window frame];
                    
                    if (fabs( frame4.origin.x - myFrame.origin.x) < 30 &&
                        fabs( NSMaxY(frame4) - NSMaxY(myFrame)) < 30)
                    {
                        dontEnterMagneticFunctions = YES;
                        
                        [window orderWindow: NSWindowBelow relativeTo: [theWindow windowNumber]];
                        [AppController resizeWindowWithAnimation: window newSize: savedWindowsFrameO];
                        
                        savedWindowsFrameO = frame4;
                        
                        [AppController resizeWindowWithAnimation: theWindow newSize: frame4];
                        
                        dontEnterMagneticFunctions = NO;
                        
                        if ([self isKindOfClass: [ViewerController class]]) {
                            NSNotification *notification = nil; //[NSNotification notificationWithName:NSWindowDidChangeScreenNotification object:theWindow];
                            [theWindow.windowController windowDidChangeScreen:notification];
                        }
                        
//    					[window makeKeyAndOrderFront: self];
//    					[theWindow makeKeyAndOrderFront: self];
                        
                        return;
                    }
                }
            }
        } // while
    }
}

- (void) dealloc
{
#ifndef NDEBUG
    //NSLog(@"OSIWindowController.mm:%d %@ dealloc %p", __LINE__, NSStringFromClass([self class]), self);
#endif
    
    self.database = nil;
    
    [NSObject cancelPreviousPerformRequestsWithTarget: self];
    
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    
	[super dealloc];
}

- (void) windowWillCloseNotification: (NSNotification*) notification
{
	if ([notification object] == [self window] &&
        [[NSUserDefaults standardUserDefaults] boolForKey: @"AUTOTILING"] &&
        magneticWindowActivated)
	{
		if (delayedTileWindows)
        {
			[NSObject cancelPreviousPerformRequestsWithTarget: [AppController sharedAppController]
                                                     selector: @selector(tileWindows:)
                                                       object: nil];
        }

        delayedTileWindows = YES;
		[[AppController sharedAppController] performSelector: @selector(tileWindows:) withObject:nil afterDelay: 0.3];
	}
}

#pragma mark - Misc

- (short) orthogonalOrientation
{
	return 0;
}

- (BOOL) isEverythingLoaded
{
	return YES;
}

//- (IBAction) updateAutoAdjustPrinting: (id) sender
//{
//
//}

- (ViewerController*) registeredViewer
{
	return nil;
}

#ifndef MIELE_LIGHT
- (IBAction)querySelectedStudy: (id)sender
{
	[[BrowserController currentBrowser] querySelectedStudy: self];
}
#endif

- (id)initWithWindowNibName:(NSString *)windowNibName
{
	if (self = [super initWithWindowNibName:(NSString *)windowNibName])
	{
        [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(windowWillCloseNotification:) name: NSWindowWillCloseNotification object: nil];
	}
	return self;
}

- (BOOL) FullScreenON
{
	return NO;
}

- (void) removeLastItemFromUndoQueue
{
	NSLog( @"OSIWindowController removeLastItemFromUndoQueue CALL SUPER ??");
}

- (void) addToUndoQueue:(NSString*) what
{
	NSLog( @"OSIWindowController addToUndoQueue CALL SUPER ??");
}

- (IBAction) redo:(id) sender
{
	NSLog( @"OSIWindowController redo CALL SUPER ??");
}

- (IBAction) undo:(id) sender
{
	NSLog( @"OSIWindowController undo CALL SUPER ??");
}

- (NSMutableArray*) pixList
{
	// let subclasses handle it for now
	return nil;
}

- (int)blendingType{
	return _blendingType;
}

- (void) applyShading:(id) sender
{
	NSLog( @"OSIWindowController applyShading - CALL SUPER ??");
}

- (void) ApplyOpacityString: (NSString*) s
{
    N2LogStackTrace( @"ApplyOpacityString - CALL SUPER ??");
}

#pragma mark - current Core Data Objects

- (DicomStudy *)currentStudy
{
	return nil;
}
- (DicomSeries *)currentSeries
{
	return nil;
}
- (Dicom_Image *)currentImage
{
	return nil;
}

-(float)curWW{
	return 0.0;
}

-(float)curWL{
	return 0.0;
}
	

@end
