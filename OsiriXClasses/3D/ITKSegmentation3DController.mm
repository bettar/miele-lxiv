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

#import "mgl.h" // include first

#import "GLRenderer.h"
#import "GLProgramOverlayLine.h"
#import "GLScene.h"

#import "ITKSegmentation3D.h"
#import "ViewerController.h"
#import "DCMPix.h"
#import "DCMView.h"
#import "Notifications.h"

#import "ITKSegmentation3DController.h"
#import "alertTransition.h"

enum algorithmTypes { intervalSegmentationType, thresholdSegmentationType, neighborhoodSegmentationType, confidenceSegmentationType};

@implementation ITKSegmentation3DController

- (BOOL) dataVolumic
{
	return [viewer isDataVolumicIn4D: NO];
}

+(id) segmentationControllerForViewer:(ViewerController*) v
{
	NSArray *winList = [NSApp windows];
	
	for( id loopItem in winList)
	{
		if( [[[loopItem windowController] windowNibName] isEqualToString:@"ITKSegmentation"])
		{
			if( [[loopItem windowController] viewer] == v)
			{
				return [loopItem windowController];
			}
		}
	}
	
	return nil;
}

-(void) dealloc
{
	NSLog(@"ITKSegmentation3DController dealloc");
	[algorithms release];
	[parameters release];
	[defaultsParameters release];
	[urlHelp release];
	[super dealloc];
}

- (void)windowWillClose:(NSNotification *)notification
{
	[[self window] setAcceptsMouseMovedEvents: NO];
	
	[viewer roiDeleteWithName: NSLocalizedString( @"Segmentation Preview", nil)];
	
	NSLog(@"windowWillClose");
	
    [[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[self autorelease];
}

- (NSPoint) startingPoint
{
	return startingPoint;
}

- (ViewerController*) viewer
{
	return viewer;
}

- (id) initWithViewer:(ViewerController*) v
{
	// Is it already available for this viewer??
	id seg = [ITKSegmentation3DController segmentationControllerForViewer: v];
	if( seg)
        return [seg retain];
	
	// Else create a new one !

	self = [super initWithWindowNibName:@"ITKSegmentation"];
	
	viewer = v;
	resultsViewer = nil;
	startingPoint = NSZeroPoint;
	
	algorithms = [NSArray arrayWithObjects:	NSLocalizedString( @"Threshold (interval)", nil),
											NSLocalizedString( @"Threshold (lower/upper bounds)", nil),
											NSLocalizedString( @"Neighborhood", nil),
											NSLocalizedString( @"Confidence", nil),
											nil];
	[algorithms retain];
	
	parameters = [NSArray arrayWithObjects:	[NSArray arrayWithObjects:NSLocalizedString( @"Interval", nil), nil],
											[NSArray arrayWithObjects:NSLocalizedString( @"Lower Threshold", nil), NSLocalizedString( @"Upper Threshold", nil), nil],
											[NSArray arrayWithObjects:NSLocalizedString( @"Lower Threshold", nil), NSLocalizedString( @"Upper Threshold", nil), NSLocalizedString( @"Radius (pix.)", nil), nil],
											[NSArray arrayWithObjects:NSLocalizedString( @"Multiplier", nil), NSLocalizedString( @"Num. of Iterations", nil), NSLocalizedString( @"Initial Radius (pix.)", nil), nil],
											nil];
	[parameters retain];
	
	defaultsParameters = [NSArray arrayWithObjects:	[NSArray arrayWithObjects:@"100", nil],
											[NSArray arrayWithObjects:@"", @"", nil],
											[NSArray arrayWithObjects:@"", @"", @"2", nil],
											[NSArray arrayWithObjects:@"2.5", @"5", @"2", nil],
											nil];
	[defaultsParameters retain];
	
	urlHelp = [NSArray arrayWithObjects:	@"http://www.itk.org/Doxygen16/html/classitk_1_1ConnectedThresholdImageFilter.html#_details",
											@"http://www.itk.org/Doxygen16/html/classitk_1_1ConnectedThresholdImageFilter.html#_details",
											@"http://www.itk.org/Doxygen16/html/classitk_1_1NeighborhoodConnectedImageFilter.html#_details",
											@"http://www.itk.org/Doxygen16/html/classitk_1_1ConfidenceConnectedImageFilter.html#_details",
											nil];
	[urlHelp retain];
	
	
	NSNotificationCenter *nc;
    nc = [NSNotificationCenter defaultCenter];
    [nc addObserver: self
           selector: @selector(mouseViewerDown:)
               name: OsirixMouseDownNotification
             object: nil];
			 
	[nc addObserver: self
           selector: @selector(CloseViewerNotification:)
               name: OsirixCloseViewerNotification
             object: nil];
	
	[nc addObserver: self
			selector: @selector(drawStartingPoint:)
               name: OsirixDrawObjectsNotification
             object: nil];
	
	return self;
}

-(void) CloseViewerNotification:(NSNotification*) note
{
	if( [note object] == resultsViewer) resultsViewer = nil;
	
	if( [note object] == viewer)
	{
		[[self window] close];
	}
}

- (void) drawStartingPoint:(NSNotification*) note
{
	if ([note object] == [viewer imageView])
	{
		if ( startingPoint.x != 0 && startingPoint.y != 0)
		{
			NSDictionary *userInfo = [note userInfo];
			
			CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
            if (cgl_ctx == nil)
                return;
            
            float scaleValue = [[userInfo valueForKey:@"scaleValue"] floatValue];
            float crossx = startingPoint.x - [[userInfo valueForKey:@"offsetx"] floatValue];
            float crossy = startingPoint.y - [[userInfo valueForKey:@"offsety"] floatValue];
#ifdef WITH_OPENGL_32
            GLScene *scene = [GLScene currentScene];
            renderer_setProgram(scene.overlayLineProgram.programHandle, __LINE__);
#endif
            renderer_setLineWidth(2.0 * self.window.backingScaleFactor);
            renderer_set_rgb(0.0f, 1.0f, 0.5f);

            {
                const int nPoints = 8;
                glm::vec2 pA[nPoints];
                pA[0] = glm::vec2( scaleValue * (crossx - 40), scaleValue*(crossy));
                pA[1] = glm::vec2( scaleValue * (crossx -  5), scaleValue*(crossy));
                pA[2] = glm::vec2( scaleValue * (crossx + 40), scaleValue*(crossy));
                pA[3] = glm::vec2( scaleValue * (crossx +  5), scaleValue*(crossy));
                
                pA[4] = glm::vec2( scaleValue * (crossx), scaleValue*(crossy - 40));
                pA[5] = glm::vec2( scaleValue * (crossx), scaleValue*(crossy -  5));
                pA[6] = glm::vec2( scaleValue * (crossx), scaleValue*(crossy +  5));
                pA[7] = glm::vec2( scaleValue * (crossx), scaleValue*(crossy + 40));

                NSMutableArray *pArray = [NSMutableArray array];
                for (int i=0; i<nPoints; i++)
                    [pArray addObject: [NSValue valueWithBytes:&pA[i] objCType:@encode(glm::vec2)]];

                renderer_drawLine_xy([pArray copy], GL_LINES);
            }
		}
	}
}

- (void) mouseViewerDown:(NSNotification*) note
{
	if([note object] == viewer)
	{
		int xpx, ypx, zpx; // coordinate in pixels
		float xmm, ymm, zmm; // coordinate in millimeters
		
		xpx = [[[note userInfo] objectForKey:@"X"] intValue];
		ypx = [[[note userInfo] objectForKey:@"Y"] intValue];
		zpx = [[viewer imageView] curImage];
		
		float location[3];
		[[[viewer imageView] curDCM] convertPixX: (float) xpx pixY: (float) ypx toDICOMCoords: (float*) location pixelCenter: YES];
		xmm = location[0];
		ymm = location[1];
		zmm = location[2];
		
		[startingPointPixelPosition setStringValue:[NSString stringWithFormat:NSLocalizedString(@"px:\t\tx:%d y:%d", nil), xpx, ypx]];
		[startingPointWorldPosition setStringValue:[NSString stringWithFormat:NSLocalizedString(@"mm:\t\tx:%2.2f y:%2.2f z:%2.2f", nil), xmm, ymm, zmm]];
		[startingPointValue setStringValue:[NSString stringWithFormat:NSLocalizedString(@"value:\t%2.2f", nil), [[[viewer imageView] curDCM] getPixelValueX: xpx Y:ypx]]];
		startingPoint = NSMakePoint(xpx, ypx);
		
		[self preview: viewer];
		
		[[note userInfo] setValue: @YES forKey: @"stopMouseDown"];
	}
}

- (ViewerController*) duplicateCurrent2DViewerWindow
{
    return [viewer copyViewerWindow];
}

- (void) windowDidLoad
{
	[self fillAlgorithmPopup];
	[self changeAlgorithm:self];
}

-(IBAction) preview:(id) sender
{
	BOOL parametersProvided = YES;
	
	float f = [[NSUserDefaults standardUserDefaults] floatForKey: @"growingRegionInterval"];
	int fd = f * 1000.;
	f = fd / 1000.;
	[[NSUserDefaults standardUserDefaults] setFloat: f forKey: @"growingRegionInterval"];
	
	NSString *name = NSLocalizedString( @"Segmentation Preview", nil);
	
	[viewer roiDeleteWithName: name];
	
	if (sender == viewer)
	{
		if ([[growingMode selectedCell] tag] != 1)
		{
			if( [[NSUserDefaults standardUserDefaults] boolForKey: @"segmentationDirectlyGenerate"])
				name = [newName stringValue];
		}
	}
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"previewGrowingRegion"] == NO && [[NSUserDefaults standardUserDefaults] boolForKey: @"segmentationDirectlyGenerate"] == NO)
        return;
	
	for (int p=0; p<[params numberOfRows]; p++)
	{
		parametersProvided = parametersProvided && (![[[params cellAtRow:p column:0] stringValue] isEqualToString:@""]);
	}
	
	if (!parametersProvided)
		return;
	
	if (startingPoint.x == 0 && startingPoint.y == 0)
		return;

	long slice;
	int previousMovieIndex = [viewer curMovieIndex];
	
	slice = [[viewer imageView] curImage];
	
	for( int i = 0; i < [viewer maxMovieIndex]; i++)
	{
		if( [[NSUserDefaults standardUserDefaults] boolForKey: @"growingRegionPropagateIn4D"])
			[viewer setMovieIndex: i];
		
		if( i == [viewer curMovieIndex])
		{
			ITKSegmentation3D	*itk = [[ITKSegmentation3D alloc] initWith:[viewer pixList] :[viewer volumePtr] :slice];
			if( itk)
			{
				// an array for the parameters
				int algo = [[algorithmPopup selectedItem] tag];
				int parametersCount = [[parameters objectAtIndex:algo] count];
				NSMutableArray *parametersArray = [NSMutableArray arrayWithCapacity:parametersCount];
				for(int i=0; i<parametersCount; i++)
					[parametersArray addObject:[NSNumber numberWithFloat:[[params cellAtRow:i column:0] floatValue]]];
				
				[itk regionGrowing3D	: viewer
										: nil
										: slice
										: startingPoint
										: algo //[[params cellAtIndex: 1] floatValue]
										: parametersArray //[[params cellAtIndex: 2] floatValue]
										: [[pixelsSet cellWithTag:0] state]==NSControlStateValueOn
										: [[pixelsValue cellWithTag:0] floatValue]
										: [[pixelsSet cellWithTag:1] state]==NSControlStateValueOn
										: [[pixelsValue cellWithTag:1] floatValue]
										: (ToolMode)[[NSUserDefaults standardUserDefaults] integerForKey: @"growingRegionROIType"]
										: ((long)[roiResolution maxValue] + 1) - [roiResolution intValue]
										: name
										: [[NSUserDefaults standardUserDefaults] boolForKey: @"mergeWithExistingROIs"]
										];
				
				[itk release];
			}
		}
	}
	
	if( [[NSUserDefaults standardUserDefaults] boolForKey: @"growingRegionPropagateIn4D"])
		[viewer setMovieIndex: previousMovieIndex];
}

-(IBAction) compute:(id) sender
{
	BOOL parametersProvided = YES;
	
	for (int p=0; p<[params numberOfRows]; p++)
	{
		parametersProvided = parametersProvided && (![[[params cellAtRow:p column:0] stringValue] isEqualToString:@""]);
	}
	
	if (!parametersProvided)
	{
		NSRunCriticalAlertPanel2(NSLocalizedString(@"Segmentation Error", nil),
                                NSLocalizedString(@"Please provide a value for each parameter.", nil),
                                NSLocalizedString(@"OK", nil),
                                nil,
                                nil);
		return;
	}
	
	if ( startingPoint.x == 0 && startingPoint.y == 0)
	{
		NSRunCriticalAlertPanel2(NSLocalizedString(@"Segmentation Error", nil),
                                NSLocalizedString(@"Select a starting point by clicking in the image.", nil),
                                NSLocalizedString(@"OK", nil),
                                nil,
                                nil);
		return;
	}
	
	[viewer roiDeleteWithName: NSLocalizedString( @"Segmentation Preview", nil)];
	
    [viewer addToUndoQueue: @"roi"];
    
	long slice;
	int previousMovieIndex = [viewer curMovieIndex];
	
	if( [[growingMode selectedCell] tag] == 1)
	{
		slice = -1;
	}
	else
        slice = [[viewer imageView] curImage];

	for( int i = 0; i < [viewer maxMovieIndex]; i++)
	{
		if( [[NSUserDefaults standardUserDefaults] boolForKey: @"growingRegionPropagateIn4D"])
			[viewer setMovieIndex: i];
		
		if( i == [viewer curMovieIndex])
		{
			ITKSegmentation3D	*itk = [[ITKSegmentation3D alloc] initWith:[viewer pixList] :[viewer volumePtr] :slice];
			if( itk)
			{
				ViewerController	*v = nil;
				
				if( [[outputResult selectedCell] tag] == 1)
				{
					if( resultsViewer == nil)
					{
						long currentImageIndex = [[viewer imageView] curImage];
						resultsViewer = [self duplicateCurrent2DViewerWindow];
						[[viewer imageView] setIndex:currentImageIndex];
						
						if( [[pixelsSet cellWithTag:1] state] == NSControlStateValueOn)	// FILL THE IMAGE WITH THE VALUE
						{
							float *dstImage, value = [[pixelsValue cellWithTag:1] floatValue];
							
							for (long i = 0; i < [[resultsViewer pixList] count]; i++)
							{
								DCMPix	*curPix = [[resultsViewer pixList] objectAtIndex: i];
								dstImage = [curPix fImage];
								long tot = [curPix pwidth] * [curPix pheight];
								
								for (long x = 0; x < tot; x++)
								{
									*dstImage++ = value;
								}
							}
						}
					}
					
					v = resultsViewer;
				}
				
				// an array for the parameters
				int algo = [[algorithmPopup selectedItem] tag];
				int parametersCount = [[parameters objectAtIndex:algo] count];
				NSMutableArray *parametersArray = [NSMutableArray arrayWithCapacity:parametersCount] ;
				for(int i=0; i<parametersCount; i++)
					[parametersArray addObject:[NSNumber numberWithFloat:[[params cellAtRow:i column:0] floatValue]]];
				
				[itk regionGrowing3D	: viewer
										: v
										: slice
										: startingPoint
										: algo //[[params cellAtIndex: 1] floatValue]
										: parametersArray //[[params cellAtIndex: 2] floatValue]
										: [[pixelsSet cellWithTag:0] state]==NSControlStateValueOn
										: [[pixelsValue cellWithTag:0] floatValue]
										: [[pixelsSet cellWithTag:1] state]==NSControlStateValueOn
										: [[pixelsValue cellWithTag:1] floatValue]
										: (ToolMode)[[NSUserDefaults standardUserDefaults] integerForKey: @"growingRegionROIType"]
										: ((long)[roiResolution maxValue] + 1) - [roiResolution intValue]
										: [newName stringValue]
										: [[NSUserDefaults standardUserDefaults] boolForKey: @"mergeWithExistingROIs"]
										];
						
				if( v)
				{
					float wl, ww;
					
					[v needsDisplayUpdate];
					[[viewer imageView] getWLWW:&wl :&ww];
					[[v imageView] setWLWW:wl :ww];
				}
				
				[itk release];
			}
		}
	}
	
	if( [[NSUserDefaults standardUserDefaults] boolForKey: @"growingRegionPropagateIn4D"])
		[viewer setMovieIndex: previousMovieIndex];
    
    [[viewer window] makeKeyAndOrderFront: self]; //For easier undo/redo on ViewerController
}

- (void) fillAlgorithmPopup
{
	NSMenu *items = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	
	for (int i=0; i<[algorithms count]; i++)
	{
		NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];				
		[item setTitle: [algorithms objectAtIndex: i]];
		[item setTag:i];
		[items addItem:item];
	}
    
	[algorithmPopup removeAllItems];
	[algorithmPopup setMenu:items];
	[algorithmPopup bind:@"selectedIndex" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:@"values.growingRegionAlgorithm" options:nil];
}

- (IBAction) changeAlgorithm: (id) sender
{
	[self setNumberOfParameters: [[parameters objectAtIndex:[[algorithmPopup selectedItem] tag]] count]];

	int algorithmType = [[algorithmPopup selectedItem] tag];
	NSArray *titles= [parameters objectAtIndex:algorithmType];
	NSArray *defaultValuesArray = [defaultsParameters objectAtIndex:algorithmType];
	NSFormCell *cell = nil;
	switch (algorithmType)
	{
		case intervalSegmentationType:	
            cell = [params cellAtRow:0 column:0] ;
            [cell setTitleWidth:-1];
            [cell setTitle:[titles objectAtIndex:0]];
            [cell setStringValue:[defaultValuesArray objectAtIndex:0]];
            [cell bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:@"values.growingRegionInterval" options:nil];
            break;

		case thresholdSegmentationType:
            cell = [params cellAtRow:0 column:0] ;
            [cell setTitleWidth:-1];
            [cell setTitle:[titles objectAtIndex:0]];
            [cell setStringValue:[defaultValuesArray objectAtIndex:0]];
            [cell bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:@"values.growingRegionLowerThreshold" options:nil];
            
            cell = [params cellAtRow:1 column:0] ;
            [cell setTitleWidth:-1];
            [cell setTitle:[titles objectAtIndex:1]];
            [cell setStringValue:[defaultValuesArray objectAtIndex:1]];
            [cell bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:@"values.growingRegionUpperThreshold" options:nil];
            break;
				
		case neighborhoodSegmentationType:
            cell = [params cellAtRow:0 column:0] ;
            [cell setTitleWidth:-1];
            [cell setTitle:[titles objectAtIndex:0]];
            [cell setStringValue:[defaultValuesArray objectAtIndex:0]];
            [cell bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:@"values.growingRegionLowerThreshold" options:nil];
            
            cell = [params cellAtRow:1 column:0] ;
            [cell setTitleWidth:-1];
            [cell setTitle:[titles objectAtIndex:1]];
            [cell setStringValue:[defaultValuesArray objectAtIndex:1]];
            [cell bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:@"values.growingRegionUpperThreshold" options:nil];
            
            cell = [params cellAtRow:2 column:0] ;
            [cell setTitleWidth:-1];
            [cell setTitle:[titles objectAtIndex:2]];
            [cell setStringValue:[defaultValuesArray objectAtIndex:2]];
            [cell bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:@"values.growingRegionRadius" options:nil];
            break;

        case confidenceSegmentationType:
            cell = [params cellAtRow:0 column:0] ;
            [cell setTitleWidth:-1];
            [cell setTitle:[titles objectAtIndex:0]];
            [cell setStringValue:[defaultValuesArray objectAtIndex:0]];
            [cell bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:@"values.growingRegionMultiplier" options:nil];
            
            cell = [params cellAtRow:1 column:0] ;
            [cell setTitleWidth:-1];
            [cell setTitle:[titles objectAtIndex:1]];
            [cell setStringValue:[defaultValuesArray objectAtIndex:1]];
            [cell bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:@"values.growingRegionIterations" options:nil];
            
            cell = [params cellAtRow:2 column:0] ;
            [cell setTitleWidth:-1];
            [cell setTitle:[titles objectAtIndex:2]];
            [cell setStringValue:[defaultValuesArray objectAtIndex:2]];
            [cell bind:@"value" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:@"values.growingRegionRadius" options:nil];
            break;
	}
	
	/*
	for(i=0; i<[[parameters objectAtIndex:[[algorithmPopup selectedItem] tag]] count]; i++)
	{
		[[params cellAtRow:i column:0] setTitleWidth:-1];
		[[params cellAtRow:i column:0] setTitle:[[parameters objectAtIndex:[[algorithmPopup selectedItem] tag]] objectAtIndex:i]];
		[[params cellAtRow:i column:0] setStringValue:[[defaultsParameters objectAtIndex:[[algorithmPopup selectedItem] tag]] objectAtIndex:i]];
	}
	*/

    [self preview: self];
}

- (void) setNumberOfParameters: (int) n
{
    params.translatesAutoresizingMaskIntoConstraints = YES;
    
	NSRect frameBefore = [params frame];
	// change the number of field in the matrix
	while (!([params numberOfRows]==0))
		[params removeRow:0];
	while (!([params numberOfRows]==n))
		[params addRow];
	// adjust the size of the matrix
	[params sizeToCells];
	NSRect frameAfter = [params frame];
	float deltaY = frameBefore.size.height - frameAfter.size.height;
	frameAfter.origin.y = frameBefore.origin.y + deltaY;
	[params setFrame:frameAfter];
//
    if( [[self.window.contentView constraints] count] == 0) //backward compatibility : prior auto-layout xib
    {
        NSDisableScreenUpdates();
        
    //	//adjust the size of the parameters box
        NSRect parametersBoxFrameBefore = [parametersBox frame];
        [parametersBox setContentViewMargins:NSMakeSize(4, 12)];
        [parametersBox sizeToFit];
        [parametersBox setFrame: NSMakeRect( parametersBoxFrameBefore.origin.x, [parametersBox frame].origin.y, parametersBoxFrameBefore.size.width, [parametersBox frame].size.height) ];
        
        // frames
        NSRect parametersBoxFrame = [parametersBox frame];
        NSRect resultsBoxFrame = [resultsBox frame];
        NSRect computeButtonFrame = [computeButton frame];
        
        //adjust the size & position of the window
        NSRect windowFrame = [[self window] frame];
        float newWindowHeight = parametersBoxFrame.size.height+resultsBoxFrame.size.height+computeButtonFrame.size.height+20+15;
        float deltaHeight = newWindowHeight-windowFrame.size.height;
        windowFrame.origin.y -= deltaHeight;
        windowFrame.size.height = newWindowHeight;
        [[self window] setFrame:windowFrame display:NO];
        
        //adjust the position of the parameters box
        parametersBoxFrame.origin.y = windowFrame.size.height - parametersBoxFrame.size.height - 20;
        [parametersBox setFrame:parametersBoxFrame];

        //adjust the position of the results box and the compute button
        resultsBoxFrame.origin.y = parametersBoxFrame.origin.y - resultsBoxFrame.size.height - 5;
        [resultsBox setFrame:resultsBoxFrame];
        computeButtonFrame.origin.y = resultsBoxFrame.origin.y - computeButtonFrame.size.height - 5;
        [computeButton setFrame:computeButtonFrame];
        
        [[self window] display];
        
        NSEnableScreenUpdates();
    }
}

- (IBAction) algorithmGetHelp:(id) sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[urlHelp objectAtIndex:[[algorithmPopup selectedItem] tag]]]];
}
@end
