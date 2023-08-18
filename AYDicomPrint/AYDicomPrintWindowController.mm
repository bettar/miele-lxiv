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

#import "QueryController.h"
#import "AYDicomPrintWindowController.h"
#import "AYDicomPrintPref.h"
#import "NSFont_OpenGL/NSFont+OpenGL.h"
#import "AYNSImageToDicom.h"
#import "Notifications.h"
#import "OSIWindow.h"
#import "ThreadsManager.h"
#import "NSUserDefaults+OsiriX.h"
#import "N2Debug.h"
#import "AppController.h"
#import "tmp_locations.h"

#define VERSIONNUMBERSTRING	@"v1.00.000"
#define ECHOTIMEOUT 5

NSString *filmOrientationTag[] = {@"Portrait", @"Landscape"};
NSString *filmDestinationTag[] = {@"Processor", @"Magazine"};
NSString *filmSizeTag[] = {@"8 IN x 10 IN", @"8.5 IN x 11 IN", @"10 IN x 12 IN", @"10 IN x 14 IN", @"11 IN x 14 IN", @"11 IN x 17 IN", @"14 IN x 14 IN", @"14 IN x 17 IN", @"24 CM x  24 CM", @"24 CM x  30 CM", @"A4", @"A3"};
NSString *magnificationTypeTag[] = {@"NONE", @"BILINEAR", @"CUBIC", @"REPLICATE"};
NSString *trimTag[] = {@"NO", @"YES"};
NSString *imageDisplayFormatTag[] = {@"Standard 1,1",@"Standard 1,2",@"Standard 2,1",@"Standard 2,2",@"Standard 2,3",@"Standard 2,4",@"Standard 3,3",@"Standard 3,4",@"Standard 3,5",@"Standard 4,4",@"Standard 4,5",@"Standard 4,6",@"Standard 5,6",@"Standard 5,7"};
int imageDisplayFormatNumbers[] = {1,2,2,4,6,8,9,12,15,16,20,24,30,35};  // elements cannot have value 0
int imageDisplayFormatRows[] =    {1,1,2,2,2,2,3, 3, 3, 4, 4, 4, 5, 5};
int imageDisplayFormatColumns[] = {1,2,1,2,3,4,3, 4, 5, 4, 5, 6, 6, 7};
NSString *borderDensityTag[] = {@"BLACK", @"WHITE"};
NSString *emptyImageDensityTag[] = {@"BLACK", @"WHITE"};
NSString *priorityTag[] = {@"HIGH", @"MED", @"LOW"};
NSString *mediumTag[] = {@"Blue Film", @"Clear Film", @"Paper"};

@interface AYDicomPrintWindowController (Private)
- (void) _createPrintjob: (id) object;
- (void) _sendPrintjob: (NSString *) jsonPath;
- (BOOL) _verifyConnection: (NSDictionary *) dict;
- (void) _verifyConnections: (id) object;
- (void) _setProgressMessage: (NSString *) message;
- (ViewerController *) _currentViewer;
- (NSString *) currentTime;
@end

@implementation AYDicomPrintWindowController

#define NUM_OF(x) (sizeof (x) / sizeof *(x))

+ (NSString*) tagForKey: (NSString*) v array: (NSString *[]) array size: (int) size
{
	for( int i = 0 ; i < size; i++)
	{
		if ([array[ i] isEqualToString: v])
			return [NSString stringWithFormat: @"%d", i];
	}
	
	NSLog( @"*** not found updateAllPreferencesFormat : %@", v);
	
	return @"0";
}

+ (void) updateAllPreferencesFormat
{
	BOOL updated = NO;
	NSMutableArray *printers = [[[[NSUserDefaults standardUserDefaults] arrayForKey: @"AYDicomPrinter"] mutableCopy] autorelease];
	
	for( int i = 0 ; i < [printers count] ; i++)
	{
		NSDictionary *dict = [printers objectAtIndex: i];
		
		if ([dict valueForKey: @"imageDisplayFormatTag"] == nil)
		{
			NSMutableDictionary *mDict = [NSMutableDictionary dictionaryWithDictionary: dict];
			
			[mDict setObject: [AYDicomPrintWindowController tagForKey: [dict valueForKey: @"filmOrientation"] array: filmOrientationTag size: NUM_OF(filmOrientationTag)] forKey: @"filmOrientationTag"];
             
			[mDict setObject: [AYDicomPrintWindowController tagForKey: [dict valueForKey: @"filmDestination"] array: filmDestinationTag size: NUM_OF(filmDestinationTag)] forKey: @"filmDestinationTag"];
			[mDict setObject: [AYDicomPrintWindowController tagForKey: [dict valueForKey: @"filmSize"] array: filmSizeTag size: NUM_OF(filmSizeTag)] forKey: @"filmSizeTag"];
			[mDict setObject: [AYDicomPrintWindowController tagForKey: [dict valueForKey: @"magnificationType"] array: magnificationTypeTag size: NUM_OF(magnificationTypeTag)] forKey: @"magnificationTypeTag"];
			[mDict setObject: [AYDicomPrintWindowController tagForKey: [dict valueForKey: @"trim"] array: trimTag size: NUM_OF(trimTag)] forKey: @"trimTag"];
			[mDict setObject: [AYDicomPrintWindowController tagForKey: [dict valueForKey: @"imageDisplayFormat"] array: imageDisplayFormatTag size: NUM_OF(imageDisplayFormatTag)] forKey: @"imageDisplayFormatTag"];
			[mDict setObject: [AYDicomPrintWindowController tagForKey: [dict valueForKey: @"borderDensity"] array: borderDensityTag size: NUM_OF(borderDensityTag)] forKey: @"borderDensityTag"];
			[mDict setObject: [AYDicomPrintWindowController tagForKey: [dict valueForKey: @"emptyImageDensity"] array: emptyImageDensityTag size: NUM_OF(emptyImageDensityTag)] forKey: @"emptyImageDensityTag"];
			[mDict setObject: [AYDicomPrintWindowController tagForKey: [dict valueForKey: @"priority"] array: priorityTag size: NUM_OF(priorityTag)] forKey: @"priorityTag"];
			[mDict setObject: [AYDicomPrintWindowController tagForKey: [dict valueForKey: @"medium"] array: mediumTag size: NUM_OF(mediumTag)] forKey: @"mediumTag"];
			
			[printers replaceObjectAtIndex: i withObject: mDict];
			
			updated = YES;
		}
	}
	
	if (updated)
	{
		[[NSUserDefaults standardUserDefaults] setObject: printers forKey: @"AYDicomPrinter"];
	}
}

- (id) init
{
	if (self = [super init])
	{
		[AYDicomPrintWindowController updateAllPreferencesFormat];
		
		// fetch current viewer
		m_CurrentViewer = [self _currentViewer];
        
		// initialize printer state images
		m_PrinterOnImage = [[NSImage imageNamed: @"available"] retain];
		m_PrinterOffImage = [[NSImage imageNamed: @"away"] retain];
		
		printing = [[NSLock alloc] init];
        
        windowFrameToRestore = NSZeroRect;
        scaleFitToRestore = m_CurrentViewer.imageView.isScaledFit;
        
        if ([[NSUserDefaults standardUserDefaults] boolForKey: @"SquareWindowForPrinting"])
        {
            bool AlwaysScaleToFit = [[NSUserDefaults standardUserDefaults] boolForKey: @"AlwaysScaleToFit"];
            [[NSUserDefaults standardUserDefaults] setBool: NO forKey: @"AlwaysScaleToFit"];
            
            windowFrameToRestore = m_CurrentViewer.window.frame;
            NSRect newFrame = [AppController usefulRectForScreen: m_CurrentViewer.window.screen];
            
            if (newFrame.size.width < newFrame.size.height)
                newFrame.size.height = newFrame.size.width;
            else
                newFrame.size.width = newFrame.size.height;
            
            [AppController resizeWindowWithAnimation: m_CurrentViewer.window newSize: newFrame];
            if (scaleFitToRestore)
                [m_CurrentViewer.imageView scaleToFit];
            
            [[NSUserDefaults standardUserDefaults] setBool: AlwaysScaleToFit forKey: @"AlwaysScaleToFit"];
        }
        
        for( ViewerController *v in [ViewerController getDisplayed2DViewers])
        {
            if (v != m_CurrentViewer)
                [v.window orderOut: self];
        }
        
        [[self window] center];
	}

	return self;
}

//- (void) windowWillClose: (NSNotification*) n
//{
//    if (NSIsEmptyRect( windowFrameToRestore) == NO)
//        [AppController resizeWindowWithAnimation: m_CurrentViewer.window newSize: windowFrameToRestore];
//}

- (void) dealloc
{
	[printing release];
	[m_PrinterOnImage release];
	[m_PrinterOffImage release];
	
	[super dealloc];
}

- (NSString *) windowNibName
{
	return @"AYDicomPrint";
}

- (void) awakeFromNib
{
	NSArray *printers = [m_PrinterController arrangedObjects];

	// show dialog if no printers are configured OR open modal print dialog
	if ([printers count] == 0)
	{
		NSRunAlertPanel(NSLocalizedString(@"DICOM Print", nil),
                        NSLocalizedString(@"No DICOM printers were found, please add a dicom printer in the preferences.", nil),
                        NSLocalizedString(@"OK", nil),
                        nil,
                        nil);
		[self close];
		return;
	}

	// set default printer & printer state to off
	NSMutableDictionary *printerDict;
	for (int i = 0; i < [printers count]; i++)
	{
		printerDict = [printers objectAtIndex: i];
		[printerDict setValue: m_PrinterOffImage forKey: @"state"];

		if ([[printerDict valueForKey: @"defaultPrinter"] isEqualTo: @"1"])
			[m_PrinterController setSelectionIndex: i];
	}

	[m_ProgressIndicator setUsesThreadedAnimation: YES];
	[m_ProgressIndicator startAnimation: self];
	[m_VersionNumberTextField setStringValue: VERSIONNUMBERSTRING];
    
	[NSThread detachNewThreadSelector: @selector(_verifyConnections:)
                             toTarget: self
                           withObject: [m_PrinterController arrangedObjects]];
	
	[entireSeriesFrom setMaxValue: [[m_CurrentViewer pixList] count]];
	[entireSeriesTo setMaxValue: [[m_CurrentViewer pixList] count]];
	
	[entireSeriesFrom setNumberOfTickMarks: [[m_CurrentViewer pixList] count]];
	[entireSeriesTo setNumberOfTickMarks: [[m_CurrentViewer pixList] count]];
	
	if ([[m_CurrentViewer pixList] count] < 20)
	{
		[entireSeriesFrom setIntValue: 1];
		[entireSeriesTo setIntValue: [[m_CurrentViewer pixList] count]];
		[entireSeriesInterval setIntValue: 1];
	}
	else
	{
		if ([[m_CurrentViewer imageView] flippedData])
            [entireSeriesFrom setIntValue: [[m_CurrentViewer pixList] count] - [[m_CurrentViewer imageView] curImage]];
		else
            [entireSeriesFrom setIntValue: 1+ [[m_CurrentViewer imageView] curImage]];
        
		[entireSeriesTo setIntValue: [[m_CurrentViewer pixList] count]];
	}
	
	[entireSeriesToText setIntValue: [entireSeriesTo intValue]];
	[entireSeriesFromText setIntValue: [entireSeriesFrom intValue]];
	[entireSeriesIntervalText setIntValue: [entireSeriesInterval intValue]];
	
	[self setPages: self];
	
	[NSApp runModalForWindow: [self window]];
}

#pragma mark -

- (NSString *) currentTime
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyyMMdd-HHmmss";
    [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    return [dateFormatter stringFromDate:[NSDate date]];
}

#pragma mark - Actions

- (IBAction) cancel: (id) sender
{
	[NSApp stopModal];
	
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey: @"SquareWindowForPrinting"] && NSIsEmptyRect( windowFrameToRestore) == NO)
    {
        bool AlwaysScaleToFit = [[NSUserDefaults standardUserDefaults] boolForKey: @"AlwaysScaleToFit"];
        [[NSUserDefaults standardUserDefaults] setBool: NO forKey: @"AlwaysScaleToFit"];
        
        [AppController resizeWindowWithAnimation: m_CurrentViewer.window newSize: windowFrameToRestore];
        
        if (scaleFitToRestore)
            [m_CurrentViewer.imageView scaleToFit];
        
        [[NSUserDefaults standardUserDefaults] setBool: AlwaysScaleToFit forKey: @"AlwaysScaleToFit"];
    }
    
    for( ViewerController *v in [ViewerController get2DViewers])
        [v.window orderFront: self];
    
    [m_CurrentViewer.window makeKeyAndOrderFront: self];
    
    [self close];
}

- (IBAction) printImages: (id) sender
{
	if ([m_pages intValue] > 10 &&
        [[m_ImageSelection selectedCell] tag] == eAllImages)
	{
		if (NSRunInformationalAlertPanel(NSLocalizedString(@"DICOM Print", nil),
                                         NSLocalizedString(@"Are you really sure you want to print %d pages?", nil),
                                         NSLocalizedString(@"OK", nil),
                                         NSLocalizedString(@"Cancel", nil),
                                         nil,
                                         [m_pages intValue]
                                         ) != NSAlertDefaultReturn)
        {
            return;
        }
	}
	
	[sender setEnabled: NO];
	[self _createPrintjob: nil];	
	[self cancel: self];
}

- (IBAction) verifyConnection: (id) sender
{
	[NSThread detachNewThreadSelector: @selector(_verifyConnections:)
                             toTarget: self
                           withObject: [m_PrinterController selectedObjects]];
}

- (IBAction) closeSheet: (id) sender
{
	[NSApp endSheet: m_ProgressSheet];
	[m_ProgressSheet orderOut: self];
	[m_PrintButton setEnabled: YES];
	[m_PrintButton setNeedsDisplay: YES];
}

- (void)checkView:(NSView *)aView :(BOOL) OnOff
{
    id view;
    NSEnumerator *enumerator;
  
    if ([aView isKindOfClass: [NSControl class] ])
	{
       [(NSControl*) aView setEnabled: OnOff];
	   return;
    }
	
	// Recursively check all the subviews in the view
    enumerator = [ [aView subviews] objectEnumerator];
    while (view = [enumerator nextObject])
	{
        [self checkView:view :OnOff];
    }
}

- (IBAction) exportDICOMSlider:(id) sender
{
	if ([[m_ImageSelection selectedCell] tag] == eAllImages)
	{
		[entireSeriesFromText takeIntValueFrom: entireSeriesFrom];
		[entireSeriesToText takeIntValueFrom: entireSeriesTo];
		
		if ([[m_CurrentViewer imageView] flippedData])
            [[m_CurrentViewer imageView] setIndex: [[m_CurrentViewer pixList] count] - [sender intValue]];
		else
            [[m_CurrentViewer imageView] setIndex:  [sender intValue]-1];
		
		[[m_CurrentViewer imageView] sendSyncMessage:0];
		[m_CurrentViewer adjustSlider];
		[self setPages: self];
	}
}

- (IBAction) setPages:(id) sender
{
	int no_of_images = 0;
	
	NSDictionary *dict = [[m_PrinterController selectedObjects] objectAtIndex: 0];
	
	if ([[formatPopUp menu] itemWithTag: [[dict valueForKey: @"imageDisplayFormatTag"] intValue]] == nil)
	{
		[[[m_PrinterController selectedObjects] objectAtIndex: 0] setObject: @"0" forKey:@"imageDisplayFormat"];
	}
	
	int ipp = imageDisplayFormatNumbers[[[dict valueForKey: @"imageDisplayFormatTag"] intValue]];
	
	if ([[m_ImageSelection selectedCell] tag] == eAllImages)
	{
		if (sender == entireSeriesTo) [entireSeriesToText setIntValue: [entireSeriesTo intValue]];
		if (sender == entireSeriesFrom) [entireSeriesFromText setIntValue: [entireSeriesFrom intValue]];
		
		if (sender == entireSeriesToText) [entireSeriesTo setIntValue: [entireSeriesToText intValue]];
		if (sender == entireSeriesFromText) [entireSeriesFrom setIntValue: [entireSeriesFromText intValue]];
		
		int from = [entireSeriesFrom intValue]-1;
		int to = [entireSeriesTo intValue];
		
		if (from >= to)
		{
			to = [entireSeriesFrom intValue];
			from = [entireSeriesTo intValue]-1;
		}
		
		for( int i = from; i < to; i += [entireSeriesInterval intValue])
		{
			no_of_images++;
		}
		
//		no_of_images = (to - from) / [entireSeriesInterval intValue];
	}
	else if ([[m_ImageSelection selectedCell] tag] == eCurrentImage) no_of_images = 1;
	else if ([[m_ImageSelection selectedCell] tag] == eKeyImages)
	{
		NSArray *fileList2 = [m_CurrentViewer fileList];
        NSArray *roiList2 = [m_CurrentViewer roiList];
		no_of_images = 0;
		for (int i = 0; i < [fileList2 count]; i++)
		{
			if ([[[fileList2 objectAtIndex: i] valueForKey: @"isKeyImage"] boolValue] || [[roiList2 objectAtIndex: i] count]) no_of_images++;
		}
	}
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"autoAdjustPrintingFormat"])
	{
		NSInteger index = 0, no;
		do
		{
			no = imageDisplayFormatNumbers[[[[formatPopUp menu] itemAtIndex: index] tag]];
			index++;
		}
		while( no_of_images > no && index < [[formatPopUp menu] numberOfItems]);
		
		NSMutableDictionary *currentPrinter = [[m_PrinterController selectedObjects] objectAtIndex: 0];
		
		if (no == 2)
		{
			if ([[filmOrientationTag[[[dict valueForKey: @"filmOrientationTag"] intValue]] uppercaseString] isEqualToString: @"PORTRAIT"])
				[currentPrinter setObject: @"1" forKey:@"imageDisplayFormatTag"];
			else
				[currentPrinter setObject: @"2" forKey:@"imageDisplayFormatTag"];
		}
		else
		{
			[currentPrinter setObject: [NSString stringWithFormat: @"%d", (int) index-1]  forKey:@"imageDisplayFormatTag"];
			ipp = imageDisplayFormatNumbers[[[dict valueForKey: @"imageDisplayFormatTag"] intValue]];
		}
	}
	
	if (no_of_images == 0)
        [m_pages setIntValue: 1];
	else if (no_of_images % ipp == 0)
        [m_pages setIntValue: no_of_images / ipp];
	else
        [m_pages setIntValue: 1 + (no_of_images / ipp)];
}

- (IBAction) setExportMode:(id) sender
{
	if ([[sender selectedCell] tag] == eAllImages)
        [self checkView: entireSeriesBox :YES];
	else
        [self checkView: entireSeriesBox :NO];
	
	[self setPages: self];
}

- (ViewerController *) _currentViewer
{
	NSArray *windows = [NSApp windows];
	for(int i = 0; i < [windows count]; i++)
	{
		if([[[windows objectAtIndex: i] windowController] isKindOfClass: [ViewerController class]] &&
			[[windows objectAtIndex: i] isMainWindow])
		{
			return [[windows objectAtIndex: i] windowController];
			break;
		}
	}

	return nil;
}

- (void) _createPrintjob: (id) object
{
    // show progress sheet
	[self _setProgressMessage: nil];
	[NSApp beginSheet: m_ProgressSheet
       modalForWindow: [self window]
        modalDelegate: self
       didEndSelector: nil
          contextInfo: nil];

	// dictionary for selected printer
	NSDictionary *dict = [[m_PrinterController selectedObjects] objectAtIndex: 0];
    //NSLog(@"%s %d, dict:%@", __FUNCTION__, __LINE__, dict);
    
    //--------------------------------------------------------------------------
	// printjob
    NSMutableDictionary *printjobDict = [[NSMutableDictionary alloc] init];

    //--------------------------------------------------------------------------
	// association
    NSString *aeTitle = [NSUserDefaults defaultAETitle];
    if (!aeTitle)
        aeTitle = @"MIELE_LXIV_DICOM_PRINT";

    NSMutableDictionary *associationDict = [[NSMutableDictionary alloc] init];
    [associationDict setObject:[dict valueForKey: @"host"] forKey:@"host"];
    [associationDict setObject:[dict valueForKey: @"port"] forKey:@"port"];
    [associationDict setObject:aeTitle forKey:@"aetitle_sender"];
    [associationDict setObject:[dict valueForKey: @"aeTitle"] forKey:@"aetitle_receiver"];
    if ([[dict valueForKey: @"colorPrint"] boolValue])
        [associationDict setObject:@"YES" forKey:@"colorprint"];
    
    //--------------------------------------------------------------------------
	// filmsession
    NSString *copies = [NSString stringWithFormat: @"%d", [[dict valueForKey: @"copies"] intValue]];
    NSMutableDictionary *filmsessionDict = [[NSMutableDictionary alloc] init];
    [filmsessionDict setObject:copies forKey:@"number_of_copies"];
    [filmsessionDict setObject:priorityTag[ [[dict valueForKey: @"priorityTag"] intValue]] forKey:@"print_priority"];
    [filmsessionDict setObject:[mediumTag[ [[dict valueForKey: @"mediumTag"] intValue]] uppercaseString] forKey:@"medium_type"];
    [filmsessionDict setObject:[filmDestinationTag[[[dict valueForKey: @"filmDestinationTag"] intValue]] uppercaseString] forKey:@"film_destination"];

    NSMutableArray *filmboxArray = [[NSMutableArray alloc] init];

    //--------------------------------------------------------------------------
	// filmbox
	
	// show alert, if displayFormat is invalid
    if ([[formatPopUp menu] itemWithTag: [[dict valueForKey: @"imageDisplayFormatTag"] intValue]] == nil) {
		[self _setProgressMessage: NSLocalizedString( @"The Format you selected is not valid.", nil)];
        [self closeSheet: self];
        return; ////////////////////////////////////////////////////////////////
    }

    NSMutableString *imageDisplayFormat = [NSMutableString stringWithString: imageDisplayFormatTag[[[dict valueForKey: @"imageDisplayFormatTag"] intValue]]];
    [imageDisplayFormat replaceOccurrencesOfString: @" " withString: @"\\" options: 0 range: NSMakeRange(0, [imageDisplayFormat length])];
    
    int ipp = imageDisplayFormatNumbers[[[dict valueForKey: @"imageDisplayFormatTag"] intValue]];
    int rows = imageDisplayFormatRows[[[dict valueForKey: @"imageDisplayFormatTag"] intValue]];
    int columns = imageDisplayFormatColumns[[[dict valueForKey: @"imageDisplayFormatTag"] intValue]];

    NSString *pathDicomPrint = [NSTemporaryDirectory() stringByAppendingPathComponent:@"dicomPrint/"];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    // remove destination directory
    if ([fileManager fileExistsAtPath: pathDicomPrint])
        [fileManager removeItemAtPath: pathDicomPrint error: nil];

    // create destination directory
    if ([fileManager fileExistsAtPath: pathDicomPrint] ||
        ![fileManager createDirectoryAtPath:pathDicomPrint withIntermediateDirectories:YES attributes:nil error:nil])
    {
        [self _setProgressMessage: NSLocalizedString( @"Can't write to temporary directory.", nil)];
        [self closeSheet: self];
        return; ////////////////////////////////////////////////////////////////
    }

    int from = [entireSeriesFrom intValue]-1;
    int to = [entireSeriesTo intValue];

    if (to < from)
    {
        to = [entireSeriesFrom intValue];
        from = [entireSeriesTo intValue]-1;
    }

    if (from < 0) from = 0;
    if (to == from) to = from+1;

    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithInt: columns], @"columns",
                             [NSNumber numberWithInt: rows], @"rows",
                             [NSNumber numberWithInt: [[m_ImageSelection selectedCell] tag]], @"mode",
                             [NSNumber numberWithInt: from], @"from",
                             [NSNumber numberWithInt: to], @"to",
                             [NSNumber numberWithInt: [entireSeriesInterval intValue]], @"interval",
                             nil];

    // collect images for printing
    AYNSImageToDicom *dicomConverter = [[[AYNSImageToDicom alloc] init] autorelease];
    NSArray *images = [dicomConverter dicomFileListForViewer: m_CurrentViewer
                                             destinationPath: pathDicomPrint
                                                     options: options
                                                asColorPrint: [[dict valueForKey: @"colorPrint"] intValue]
                                             withAnnotations: NO];

    // check, if images were collected
    if ([images count] == 0) {
        [self _setProgressMessage: NSLocalizedString( @"There are no images selected.", nil)];
        [self closeSheet: self];
        return; ////////////////////////////////////////////////////////////////
    }

    for (int i = 0; i <= ([images count] - 1) / ipp; i++)
    {
        NSMutableString *filmSize = [NSMutableString stringWithString: filmSizeTag[[[dict valueForKey: @"filmSizeTag"] intValue]]];
        [filmSize replaceOccurrencesOfString: @" " withString: @"" options: 0 range: NSMakeRange(0, [filmSize length])];
        [filmSize replaceOccurrencesOfString: @"." withString: @"_" options: 0 range: NSMakeRange(0, [filmSize length])];

        NSMutableDictionary *filmboxDict = [[NSMutableDictionary alloc] init];
        [filmboxDict setObject:[imageDisplayFormat uppercaseString] forKey:@"image_display_format"];
        [filmboxDict setObject:[filmOrientationTag[[[dict valueForKey: @"filmOrientationTag"] intValue]] uppercaseString] forKey:@"film_orientation"];
        [filmboxDict setObject:[filmSize uppercaseString] forKey:@"film_size_id"];
        [filmboxDict setObject:borderDensityTag[[[dict valueForKey: @"borderDensityTag"] intValue]] forKey:@"border_density"];
        [filmboxDict setObject:emptyImageDensityTag[[[dict valueForKey: @"emptyImageDensityTag"] intValue]] forKey:@"empty_image_density"];
        if ([dict valueForKey: @"requestedResolution"])
            [filmboxDict setObject:[dict valueForKey: @"requestedResolution"] forKey:@"requested_resolution_id"];
        [filmboxDict setObject:magnificationTypeTag[[[dict valueForKey: @"magnificationTypeTag"] intValue]] forKey:@"magnification_type"];
        [filmboxDict setObject:trimTag[[[dict valueForKey: @"trimTag"] intValue]] forKey:@"trim"];
        if ([dict valueForKey: @"configurationInformation"])
            [filmboxDict setObject:[dict valueForKey: @"configurationInformation"] forKey:@"configuration_information"];

        NSMutableArray *imageboxArray = [NSMutableArray new];

        //--------------------------------------------------------------------------
        // imagebox
        int k = 1;
        for (int j = i * ipp; j < MIN(i * ipp + ipp, [images count]); j++)
        {
            NSMutableDictionary *imageboxDict = [[NSMutableDictionary alloc] init];
            [imageboxDict setObject:[images objectAtIndex: j] forKey:@"image_file"];
            [imageboxDict setObject:[NSString stringWithFormat: @"%d", k++] forKey:@"image_position"];
            
            if ([[images objectAtIndex: j] length] > 0) {
//                [filmboxDict setObject:imageboxDict forKey:@"imagebox"];
                [imageboxArray addObject:imageboxDict];
            }
        }

        [filmboxDict setObject:imageboxArray forKey:@"imagebox"];
        [filmboxArray addObject: filmboxDict];
    }

    [filmsessionDict setObject:filmboxArray forKey:@"filmbox"];
    [associationDict setObject:filmsessionDict forKey:@"filmsession"];
    [printjobDict setObject:associationDict forKey:@"association"];

    NSString *timeStamp = [self currentTime];
    NSError *error = nil;
    NSData *jsonObject = [NSJSONSerialization dataWithJSONObject:printjobDict
                                                         options:NSJSONWritingPrettyPrinted
                                                           error:&error];
    NSString *jsonStr = [[NSString alloc] initWithData:jsonObject encoding:NSUTF8StringEncoding];

    NSString *jsonPath = [NSString stringWithFormat: @"%@/printjob-%@.json", pathDicomPrint, timeStamp];

    BOOL success = [jsonStr writeToFile: jsonPath
                             atomically: YES
                               encoding: NSUTF8StringEncoding
                                  error: &error];
    if (!success) {
        NSLog(@"Line %d Error: %@", __LINE__, [error userInfo]);
        [self _setProgressMessage: NSLocalizedString( @"Can't write to temporary directory.", nil)];
        [self closeSheet: self];
        return; // /////////////////////////////////////////////////////////////
    }

    // send printjob
    NSThread* t = [[[NSThread alloc] initWithTarget:self
                                           selector:@selector(_sendPrintjob:)
                                             object:jsonPath] autorelease];

    t.name = NSLocalizedString( @"DICOM Printing...", nil);
    [[ThreadsManager defaultManager] addThreadAndStart: t];
    
    [self closeSheet: self];
}

- (void) errorMessage:(NSArray*) msg
{
	NSRunCriticalAlertPanel([msg objectAtIndex: 0],
                            @"%@",
                            [msg objectAtIndex: 2],
                            nil,
                            nil,
                            [msg objectAtIndex: 1]) ;
}

// It runs in a separate thread
- (void) _sendPrintjob: (NSString *) jsonPath;
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[printing lock];
	
	@try 
	{
		NSString *logPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/AYDicomPrint"];
		NSString *baseName = @"AYDicomPrint";

		// create log directory, if it does not exist
		NSFileManager *fileManager = [NSFileManager defaultManager];
		if (![fileManager fileExistsAtPath: logPath])
        {
			[fileManager createDirectoryAtPath: logPath
                   withIntermediateDirectories: YES
                                    attributes: nil
                                         error: nil];
        }
		
		NSTask *theTask = [[NSTask alloc] init];
		
        NSString *dicPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"dicom.dic"];
        [theTask setEnvironment:[NSDictionary dictionaryWithObject:dicPath forKey:@"DCMDICTPATH"]];

		[theTask setArguments: [NSArray arrayWithObjects: logPath, baseName, jsonPath, nil]];
        NSString *launchPath = [[[NSBundle mainBundle] URLForAuxiliaryExecutable:@"DICOMPrint"] path];
        //NSLog(@"%s %d, launchPath: %@", __FUNCTION__, __LINE__, launchPath);
        [theTask setLaunchPath:launchPath];
		[theTask launch];

        while ([theTask isRunning])
            [NSThread sleepForTimeInterval: 0.01];

        //	[theTask waitUntilExit];	<- The problem with this: it calls the current running loop.... problems with current Lock !
		
		int status = [theTask terminationStatus];
		[theTask release];

		if (status != EXIT_SUCCESS)
		{
            NSLog(@"%s %d, task termination status: %d", __FUNCTION__, __LINE__, status);
			[self performSelectorOnMainThread:@selector(errorMessage:)
                                   withObject:[NSArray arrayWithObjects:
                                               NSLocalizedString(@"Print failed", nil),
                                               NSLocalizedString(@"Couldn't print images.", nil),
                                               NSLocalizedString(@"OK", nil),
                                               nil]
                                waitUntilDone:NO];
		}

#ifdef NDEBUG
        // Remove temporary files
        [[NSFileManager defaultManager] removeItemAtPath: [jsonPath stringByDeletingLastPathComponent] error: nil];
#else
        NSLog(@"%s %d, TODO: removeItemAtPath: %@", __FUNCTION__, __LINE__, [jsonPath stringByDeletingLastPathComponent]);
        [[NSWorkspace sharedWorkspace] openFile: jsonPath];
#endif

	}
	@catch (NSException * e) 
	{
		N2LogExceptionWithStackTrace(e);
	}
	
	[printing unlock];
	[pool release];
}

- (void) _setProgressMessage: (NSString *) message
{
	[m_ProgressMessage setStringValue: @""];
	[m_ProgressMessage setNeedsDisplay: YES];

	if (!message)
	{
		[m_ProgressTabView selectFirstTabViewItem: self];
		[m_ProgressMessage setStringValue: NSLocalizedString( @"Printing images...", nil)];
	}
	else
	{
		[m_ProgressTabView selectLastTabViewItem: self];
		[m_ProgressMessage setStringValue: message];
	}

	[m_ProgressMessage setNeedsDisplay: YES];
}

-(void) setVerifyButton: (NSNumber*) enabled
{
    [m_VerifyConnectionButton setEnabled: enabled.boolValue];
}

-(void) setPrinterStateOn: (NSMutableDictionary*) printer
{
    [printer setValue: m_PrinterOnImage forKey: @"state"];
}

-(void) setPrinterStateOff: (NSMutableDictionary*) printer
{
    [printer setValue: m_PrinterOffImage forKey: @"state"];
}

- (void) _verifyConnections: (NSArray *) printers
{
	@autoreleasepool
    {
        [self retain];
        
        @try
        {
            [self performSelectorOnMainThread: @selector( setVerifyButton:)
                                   withObject: @NO
                                waitUntilDone: YES];
            
            for (NSMutableDictionary *printer in printers)
            {
                if ([self _verifyConnection: printer])
                    [self performSelectorOnMainThread: @selector( setPrinterStateOn:)
                                           withObject: printer
                                        waitUntilDone: NO];
                else
                    [self performSelectorOnMainThread: @selector( setPrinterStateOff:)
                                           withObject: printer
                                        waitUntilDone: NO];
            }
        }
        @catch (NSException *exception) {
            N2LogException( exception);
        }

        [self performSelectorOnMainThread: @selector( setVerifyButton:)
                               withObject: @YES
                            waitUntilDone: YES];
        
        [NSThread sleepForTimeInterval: 5];
        
        [self autorelease];
	}
}

- (BOOL) _verifyConnection: (NSDictionary *) dict
{
	return [QueryController echo: [dict valueForKey: @"host"]
                            port: [[dict valueForKey: @"port"] intValue]
                             AET: [dict valueForKey: @"aeTitle"]];
}

- (void) drawerDidOpen: (NSNotification *) notification
{
	[m_ToggleDrawerButton setTitle: NSLocalizedString(@"Hide Printers...", nil)];
}

- (void) drawerDidClose: (NSNotification *) notification
{
	[m_ToggleDrawerButton setTitle: NSLocalizedString(@"Show Printers...", nil)];
}

@end
