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
*****************************************************************/

#include "options.h"
#import "SplashScreen.h"

#include <mach/mach.h>
#include <mach/mach_host.h>
#include <mach/host_info.h>
#include <mach/machine.h>
#include <sys/sysctl.h>

//BOOL IsPPC()
//{
//   host_basic_info_data_t hostInfo;
//   mach_msg_type_number_t infoCount;
//
//   infoCount = HOST_BASIC_INFO_COUNT;
//   host_info(mach_host_self(), HOST_BASIC_INFO, (host_info_t)&hostInfo, &infoCount);
//
//	return (hostInfo.cpu_type == CPU_TYPE_POWERPC);
//} 

//int GetAltiVecTypeAvailable( void )
//{
//    int sels[2] = { CTL_HW, HW_VECTORUNIT };
//    int vType = 0; //0 == scalar only
//    size_t length = sizeof(vType);
//    int error = sysctl(sels, 2, &vType, &length, NULL, 0);
//    if( 0 == error )
//        return vType;
//
//    return 0;
//}

#pragma mark -

@implementation SplashScreen

- (void)windowDidLoad
{ 
	[[self window] center];
	versionType  = 0;
	[self switchVersion: self];
		
	[[self window] setDelegate:self];
	[[self window] setAlphaValue:0.0];
}

- (IBAction) switchVersion:(id) sender
{
	NSMutableString *currVersionNumber = nil;
    NSDictionary *d = [[NSBundle mainBundle] infoDictionary];
    
	switch( versionType)
    {
        case 0:
            currVersionNumber = [NSMutableString stringWithFormat:@"%@ %@",
                                 [d objectForKey:@"CFBundleName"],
                                 [d objectForKey:@"CFBundleShortVersionString"]];
            break;
        
        case 1:
            currVersionNumber = [NSMutableString stringWithFormat:@"Revision %@",
                                 [d objectForKey:@"CFBundleVersion"]];
            break;
        
        case 2:
            currVersionNumber = [d objectForKey:@"GitHash"];
            
            [[NSPasteboard generalPasteboard] clearContents];
            [[NSPasteboard generalPasteboard] writeObjects:[NSArray arrayWithObject: currVersionNumber]];
            break;
	}
	
	[version setTitle: currVersionNumber];

    versionType++;
    if (versionType >= 3)
        versionType = 0;
}

- (IBAction)showWindow:(id)sender{
	[super showWindow:sender];	
//	if (useQuartz())
//		[self startRendering];
	//
	//NSLog(@"show Splash screen");
}

//- (void)startRendering
//{
//	NSString *path = [[NSBundle mainBundle] pathForResource:@"About" ofType:@"qtz"];
//	[view loadCompositionFromFile:path];
//	[view setAutostartsRendering:YES];
//	[view startRendering];
//}

- (void) affiche
{
	timerIn = [[NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(fadeIn:) userInfo:nil repeats:YES] retain];
//	[[NSRunLoop currentRunLoop] addTimer:timerIn forMode:NSModalPanelRunLoopMode];
//	[[NSRunLoop currentRunLoop] addTimer:timerIn forMode:NSEventTrackingRunLoopMode];
}

-(id) init
{
    self = [super initWithWindowNibName:@"Splash"];
    return self;
}

- (BOOL)windowShouldClose:(id)sender
{
	[timerIn invalidate];
	[timerIn release];
	timerIn = nil;
	
    // Set up our timer to periodically call the fade: method.
    timerOut = [[NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(fade:) userInfo:nil repeats:YES] retain];
//	[[NSRunLoop currentRunLoop] addTimer:timerOut forMode:NSModalPanelRunLoopMode];
//	[[NSRunLoop currentRunLoop] addTimer:timerOut forMode:NSEventTrackingRunLoopMode];

//	[timer fire];
	
    // Don't close just yet.
    return NO;
}

- (void)fade:(NSTimer *)theTimer
{
    if ([[self window] alphaValue] > 0.0)
	{
        [[self window] setAlphaValue:[[self window] alphaValue] - 0.1];
    }
	else
	{
        [timerOut invalidate];
        [timerOut release];
        timerOut = nil;
		
        [[self window] close];
    }
}

- (void)fadeIn:(NSTimer *)theTimer
{
	if ([[self window] alphaValue] < 1.0)
	{
        [[self window] setAlphaValue:[[self window] alphaValue] + 0.1];
    }
	else
	{
        [timerIn invalidate];
        [timerIn release];
        timerIn = nil;
		
		[[self window] setAlphaValue:1.0];
    }
}


@end
