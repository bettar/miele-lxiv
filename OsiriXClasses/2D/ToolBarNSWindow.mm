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

#import "ToolBarNSWindow.h"
#import "ToolbarPanel.h"
#import "ViewerController.h"
#import "N2Debug.h"
#import "AppController.h"

@implementation ToolBarNSWindow

//- (id) initWithContentRect:(NSRect)contentRect
//                 styleMask:(NSWindowStyleMask)style
//                   backing:(NSBackingStoreType)backingStoreType
//                     defer:(BOOL)flag
//{
//    NSLog(@"%s styleMask: 0x%lx\n\t 0x%lx, 0x%lx, 0x%lx, 0x%lx",
//          __PRETTY_FUNCTION__,
//          (unsigned long)style,                 // 0x191
//          NSWindowStyleMaskTitled,              // 1 << 0 0x001
//          NSWindowStyleMaskUtilityWindow,       // 1 << 4 0x010
//          NSWindowStyleMaskNonactivatingPanel,  // 1 << 7 0x080
//          NSWindowStyleMaskTexturedBackground); // 1 << 8 0x100
//
//    if ((self = [super initWithContentRect:contentRect
//                                 styleMask:style
//                                   backing:backingStoreType
//                                     defer:flag])) {
//
//        [self setShowsToolbarButton: YES];
//    }
//
//    return self;
//}

- (void) resignMainWindow
{
}

- (BOOL) canBecomeMainWindow
{
	return YES;
}

- (BOOL) canBecomeKeyWindow
{
	return YES;
}

- (void) orderBack:(id)sender
{
    ViewerController *v = (ViewerController*) self.toolbar.delegate;
    
    if( v.window.isVisible)
    {
        NSDisableScreenUpdates();
        [super orderBack: self];
        [v.toolbarPanel applicationDidChangeScreenParameters: nil];
        [self orderWindow: NSWindowAbove relativeTo: v.window.windowNumber];
        NSEnableScreenUpdates();
    }
}

- (void) orderOut:(id)sender
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey: @"hideToolbarIfNotActive"] == NO && [AppController useToolBarPanel] == YES)
    {
        NSDisableScreenUpdates();
        
        ViewerController *v = [ViewerController frontMostDisplayed2DViewerForScreen: self.screen];
        
        if (v.toolbarPanel.window != self)
        {
            if ([self.toolbar customizationPaletteIsRunning] == NO)
                [super orderOut:sender];
        }
        
        if (v) {
            if( [v.toolbarPanel.window.toolbar customizationPaletteIsRunning] == NO)
                [v.toolbarPanel.window orderBack: self];
        }
        NSEnableScreenUpdates();
    }
    else
        [super orderOut:sender];
}

-(NSTimeInterval)animationResizeTime:(NSRect)newFrame {
	return 0;
}

-(NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen*)screen {
	return frameRect; // not movable, and OsiriX knows where to place toolbars ;)
}

@end
