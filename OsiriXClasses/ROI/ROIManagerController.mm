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

#import "ROIManagerController.h"
#import "Notifications.h"

@implementation ROIManagerController

- (id) initWithViewer:(ViewerController*) v
{
	viewer = nil;
	
	self = [super initWithWindowNibName:@"ROIManager"];
	
	[[self window] setFrameAutosaveName:@"ROIManagerWindow"];
	
	// register to notification
	NSNotificationCenter *nc;
    nc = [NSNotificationCenter defaultCenter];	
	[nc addObserver: self
           selector: @selector(CloseViewerNotification:)
               name: OsirixCloseViewerNotification
             object: nil];
	[nc addObserver: self
           selector: @selector(roiListModification:)
               name: OsirixROIChangeNotification
             object: nil];
	[nc addObserver: self
           selector: @selector(fireUpdate:)
               name: OsirixRemoveROINotification
             object: nil];
	[nc addObserver: self
           selector: @selector(roiListModification:)
               name: OsirixDCMUpdateCurrentImageNotification
             object: nil];
	[nc addObserver: self
           selector: @selector(roiListModification:)
               name: OsirixROISelectedNotification
             object: nil];
		 
	viewer = v;
	DCMPix	*curPix = [[viewer pixList] objectAtIndex:0];
	pixelSpacingZ = [curPix sliceInterval];
	
	[self fireUpdate: nil];
	
	return self;
}

- (void)tableView:(NSTableView *)aTableView
   setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)aTableColumn
			  row:(NSInteger)rowIndex
{
	NSMutableArray *curRoiList2 = [[viewer roiList] objectAtIndex: [[viewer imageView] curImage]];
	ROI *editedROI = [curRoiList2 objectAtIndex: rowIndex];
	

//	[editedROI setName:anObject];
//	[[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification object:editedROI userInfo: nil];
	
	[viewer renameSeriesROIwithName: [editedROI name] newName:anObject];
	
	[tableView reloadData];
}

- (void) keyDown:(NSEvent *)event
{
    if( [[event characters] length] == 0)
        return;
    
	unichar c = [[event characters] characterAtIndex:0];
	
    if( c == NSDeleteFunctionKey || c == NSDeleteCharacter || c == NSBackspaceCharacter || c == NSDeleteCharFunctionKey)
	{
		[self deleteROI: self];
	}
}

- (IBAction)deleteROI:(id)sender
{
	NSInteger index;
	NSIndexSet* indexSet = [tableView selectedRowIndexes];
	index = [indexSet lastIndex];
	
	if ((index == NSNotFound) || index < 0)
        return;
	
	NSMutableArray *curRoiList3 = [[viewer roiList] objectAtIndex: [[viewer imageView] curImage]];
	
	while ( index != NSNotFound) 
	{
		ROI	*selectedRoi = [curRoiList3 objectAtIndex:index];
	
		[viewer deleteSeriesROIwithName: [selectedRoi name]];
	
//		[[NSNotificationCenter defaultCenter] postNotificationName: OsirixRemoveROINotification object:selectedRoi userInfo: nil];
//		[curRoiList3 removeObject:selectedRoi];
		
		index = [indexSet indexLessThanIndex:index];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName: OsirixUpdateViewNotification object:nil userInfo: nil];
}

//- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
//{
//	NSMutableArray	*curRoiList4 = [[viewer roiList] objectAtIndex: [[viewer imageView] curImage]];
//	
//	long i;
//	
//	for( i = 0; i < [curRoiList4 count]; i++)
//	{
//		ROI	*curROI = [curRoiList4 objectAtIndex: i];
//		
//		if( [tableView isRowSelected: i])
//		{
//			[curROI setROIMode: ROI_selected];
//		}
//		else
//		{
//			[curROI setROIMode: ROI_sleep];
//		}
//		
//		[[NSNotificationCenter defaultCenter] postNotificationName: OsirixROIChangeNotification object:curROI userInfo: nil];
//	}
//}

- (void) roiListModification: (NSNotification*) note
{
	[tableView reloadData];
}

- (void) fireUpdate: (NSNotification*) note
{
	[NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(roiListModification:) userInfo:nil repeats:NO];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	NSMutableArray *curRoiList5 = [[viewer roiList] objectAtIndex: [[viewer imageView] curImage]];
	
    return [curRoiList5 count];
}

- (id)tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
            row:(NSInteger)row
{
	if( viewer == nil)
        return nil;
	
	NSMutableArray *curRoiList6 = [[viewer roiList] objectAtIndex: [[viewer imageView] curImage]];
	
	if( [curRoiList6 count] <= row)
		return nil;

	if( [[tableColumn identifier] isEqualToString:@"Index"])
	{
		return [NSString stringWithFormat:@"%d", (int) row+1];
	}
	
	if( [[tableColumn identifier] isEqualToString:@"Name"])
	{
		return [[curRoiList6 objectAtIndex:row] name];
	}
	
	if( [[tableColumn identifier] isEqualToString:@"area"])
	{
		return [NSNumber numberWithFloat:[[curRoiList6 objectAtIndex:row] roiArea]];
	}
	
	if( [[tableColumn identifier] isEqualToString:@"volume"])
	{
#ifndef MIELE_LIGHT
		float volume = [viewer computeVolume:[curRoiList6 objectAtIndex:row] points:nil error: nil];
		
		if( volume)
		{
			if( volume < 10)
				return [NSString stringWithFormat:@"%2.5f", volume];
			else
				return [NSString stringWithFormat:@"%2.2f", volume];
		}
		else
#endif
			return [NSString stringWithString: NSLocalizedString( @"n/a", @"Abbreviation for not available")];
	}
	
	return nil;
}

// delegate method setROIMode

-(void) CloseViewerNotification:(NSNotification*) note
{	
	if( [note object] == viewer)
	{
        viewer = nil;
        
		NSLog( @"ROIManager CloseViewerNotification");
		
		[[self window] close];
	}
}

- (void)windowWillClose:(NSNotification *)notification
{
	[[self window] setAcceptsMouseMovedEvents: NO];
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
 
	NSLog( @"ROIManager windowWillClose");
	
	[self autorelease];
}

- (void) dealloc
{
	NSLog( @"ROIManager dealloc");
	[tableView setDataSource: nil];
	viewer = nil;
	
    [[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[super dealloc];
}
@end
