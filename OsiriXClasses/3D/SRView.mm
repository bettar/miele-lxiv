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

#import "options.h"
#import "mgl.h" // include first

#import "mieleTypes.h"

#import "SRView.h"
#import "SRController.h"
#import "DCMPix.h"
#import "DCMView.h"
#import "DCMCursor.h"
#import "DICOMExport.h"
#import "Notifications.h"
#import "Wait.h"

#include "math.h"
#include "vtkImageFlip.h"
#import "QuicktimeExport.h"
#import "AppController.h"
#import "BrowserController.h"
#import "DicomDatabase.h"
#include "vtkRIBExporter.h"
#include "vtkIVExporter.h"
#include "vtkOBJExporter.h"
#include "vtkSTLWriter.h"
#include "vtkVRMLExporter.h"
//#include "vtkInteractorStyleFlight.h"

#include "vtkAbstractPropPicker.h"
#include "vtkInteractorStyle.h"
#include "vtkWorldPointPicker.h"

#include "vtkSphereSource.h"
#include "vtkAssemblyPath.h"

#include "vtkVectorText.h"
#include "vtkFollower.h"
#import "vtkMath.h"

#ifdef _STEREO_VISION_
#import "vtkCocoaGLView.h"
#include "vtkRenderer.h"
#include "vtkRenderWindow.h"
#include "vtkRenderWindowInteractor.h"
#include "vtkCocoaRenderWindowInteractor.h"
#include "vtkCocoaRenderWindow.h"
#include "vtkInteractorStyleTrackballCamera.h"
//#include "vtkParallelRenderManager.h"
#include "vtkRendererCollection.h"
#endif

#import "alertTransition.h"

//static SRView *snSRView = nil;

typedef struct _xyzArray
{
	short x;
	short y;
	short z;
} xyzArray;

//static void startRendering(vtkObject*,unsigned long c, void* ptr, void*)
//{
//	SRView* mipv = (SRView*) ptr;
//	
//	//vtkRenderWindow
//	//[self renderWindow] SetAbortRender( true);
//	if (c == vtkCommand::StartEvent)
//	{
//		[mipv newStartRenderingTime];
//	}
//	
//	if (c == vtkCommand::EndEvent)
//	{
//		[mipv stopRendering];
//		[[mipv startRenderingTime] release];
//	}
//	
//	if (c == vtkCommand::AbortCheckEvent)
//	{
////		if ([[NSDate date] timeIntervalSinceDate:[mipv startRenderingTime]] > 2.0)
////		{
////			[mipv startRendering];
////			[mipv runRendering];
////		}
//	}
//}

@implementation SRView

#ifdef _STEREO_VISION_
@synthesize currentTool;
#endif

- (void) print:(id) sender
{
	[controller print: sender];
}

-(void) restoreViewSizeAfterMatrix3DExport
{
	[self setFrame: savedViewSizeFrame];
}

- (NSRect) centerRect: (NSRect) smallRect
               inRect: (NSRect) bigRect
{
    NSRect centerRect;
    centerRect.size = smallRect.size;

    centerRect.origin.x = (bigRect.size.width - smallRect.size.width) / 2.0;
    centerRect.origin.y = (bigRect.size.height - smallRect.size.height) / 2.0;

    return (centerRect);
}

-(void) setViewSizeToMatrix3DExport
{
	savedViewSizeFrame = [self frame];
	
	NSRect windowFrame;
	
	windowFrame.origin.x = 0;
	windowFrame.origin.y = 0;
	windowFrame.size.width = [[[self window] contentView] frame].size.width;
	windowFrame.size.height = [[[self window] contentView] frame].size.height - 10;
	
	switch ([[NSUserDefaults standardUserDefaults] integerForKey:EXPORTMATRIXFOR3D_KEY])
	{
		case EXPORT_SIZE_CURRENT:
            break;
		
		case EXPORT_SIZE_512:
            [self setFrame: [self centerRect: NSMakeRect(0,0,512,512) inRect: windowFrame]];
            break;

        case EXPORT_SIZE_768:
            [self setFrame: [self centerRect: NSMakeRect(0,0,768,768) inRect: windowFrame]];
            break;
	}
	
	[self display];
}

// This is also implemented in DCMView
#define ORIENTATION_STRING_MAX_SIZE     10
- (void)getOrientationText:(char *) orientation
                    vector:(float *) vector
                 inversion:(BOOL) inv
{	
	NSString *orientationX;
	NSString *orientationY;
	NSString *orientationZ;

	NSMutableString *optr = [NSMutableString string];
	
	if (inv)
	{
		orientationX = (-vector[ 0] < 0) ? NSLocalizedString( @"R", @"R: Right")    : NSLocalizedString( @"L", @"L: Left");
		orientationY = (-vector[ 1] < 0) ? NSLocalizedString( @"A", @"A: Anterior") : NSLocalizedString( @"P", @"P: Posterior");
		orientationZ = (-vector[ 2] < 0) ? NSLocalizedString( @"I", @"I: Inferior") : NSLocalizedString( @"S", @"S: Superior");
	}
	else
	{
		orientationX = (vector[ 0]) < 0 ? NSLocalizedString( @"R", @"R: Right")    : NSLocalizedString( @"L", @"L: Left");
		orientationY = (vector[ 1]) < 0 ? NSLocalizedString( @"A", @"A: Anterior") : NSLocalizedString( @"P", @"P: Posterior");
		orientationZ = (vector[ 2]) < 0 ? NSLocalizedString( @"I", @"I: Inferior") : NSLocalizedString( @"S", @"S: Superior");
	}
	
	float absX = fabs( vector[ 0]);
	float absY = fabs( vector[ 1]);
	float absZ = fabs( vector[ 2]);
	
	// get first 3 AXIS
	for (int i=0; i < 3; ++i)
    {
		if (absX > .2 &&
            absX >= absY &&
            absX >= absZ)
		{
			[optr appendString: orientationX];
            absX=0;
		}
		else if (absY > .2 &&
                 absY >= absX &&
                 absY >= absZ)
        {
			[optr appendString: orientationY];
            absY=0;
		}
        else if (absZ > .2 &&
                 absZ >= absX &&
                 absZ >= absY)
        {
			[optr appendString: orientationZ];
            absZ=0;
		}
        else
            break;
	}
	
    // Truncate if the localized strings are too long
    strncpy(orientation, [optr UTF8String], ORIENTATION_STRING_MAX_SIZE);
    orientation[ORIENTATION_STRING_MAX_SIZE-1] = 0;
}

//- (void) getOrientationText:(char *) string : (float *) vector :(BOOL) inv
//{
//	char orientationX;
//	char orientationY;
//	char orientationZ;
//
//	char *optr = string;
//	*optr = 0;
//	
//	if (inv)
//	{
//		orientationX = -vector[ 0] < 0 ? 'R' : 'L';
//		orientationY = -vector[ 1] < 0 ? 'A' : 'P';
//		orientationZ = -vector[ 2] < 0 ? 'I' : 'S';
//	}
//	else
//	{
//		orientationX = vector[ 0] < 0 ? 'R' : 'L';
//		orientationY = vector[ 1] < 0 ? 'A' : 'P';
//		orientationZ = vector[ 2] < 0 ? 'I' : 'S';
//	}
//	
//	float absX = fabs( vector[ 0]);
//	float absY = fabs( vector[ 1]);
//	float absZ = fabs( vector[ 2]);
//	
//	for (int i=0; i<1; ++i)
//	{
//		if (absX>.0001 && absX>absY && absX>absZ)
//		{
//			*optr++=orientationX; absX=0;
//		}
//		else if (absY>.0001 && absY>absX && absY>absZ)
//		{
//			*optr++=orientationY; absY=0;
//		} else if (absZ>.0001 && absZ>absX && absZ>absY)
//		{
//			*optr++=orientationZ; absZ=0;
//		} else break; *optr='\0';
//	}
//}

-(NSImage*) imageForFrame:(NSNumber*) cur maxFrame:(NSNumber*) max
{
//	if ([cur intValue] != -1) [self Azimuth: [self rotation] / [max floatValue]];
//	return [self nsimageQuicktime];

	if ([cur intValue] != -1)
	{
		switch (rotationOrientation)
		{
			case 0:
				[self Azimuth: [self rotation] / [max floatValue]];
			break;
		
			case 1:
				[self Vertical: [self rotation] / [max floatValue]];
			break;
		}
	}
    
	return [self nsimageQuicktime];
}

-(NSImage*) imageForFrameVR:(NSNumber*) cur maxFrame:(NSNumber*) max
{
	if ([cur intValue] == -1)
	{
		aCamera->GetPosition( camPosition);
		aCamera->GetViewUp( camFocal);
		
		return [self nsimageQuicktime];
	}
	
	if ([max intValue] > 36)
	{
		if ([cur intValue] % numberOfFrames == 0 && [cur intValue] != 0)
		{
			aCamera->Azimuth( 360 / numberOfFrames);
			[self Vertical: - 360 / numberOfFrames];
		}
		else if ([cur intValue] != 0)
            aCamera->Azimuth( 360 / numberOfFrames);
	}
	else
	{
		if ([cur intValue] != 0)
            aCamera->Azimuth( 360 / numberOfFrames);
	}
	
	aCamera->OrthogonalizeViewUp();
	aCamera->ComputeViewPlaneNormal();
	
	return [self nsimageQuicktime];
}

-(IBAction) endQuicktimeSettings:(id) sender
{
	[export3DWindow orderOut:sender];
	
	[NSApp endSheet:export3DWindow returnCode:[sender tag]];
	
	numberOfFrames = [framesSlider intValue];
	
	if ([[rotation selectedCell] tag] == 1)
        rotationValue = 360;
	else
        rotationValue = 180;
	
	if ([sender tag])
	{
		[self setViewSizeToMatrix3DExport];
		QuicktimeExport *mov = [[QuicktimeExport alloc] initWithSelector: self
                                                                        : @selector(imageForFrame: maxFrame:)
                                                                        : numberOfFrames];
		[mov createMovieQTKit: YES
                             : NO
                             : [[[[[self window] windowController] fileList] objectAtIndex:0] valueForKeyPath:@"series.study.name"]];
		[mov release];
		[self restoreViewSizeAfterMatrix3DExport];
	}
}

-(float) rotation {return rotationValue;}
-(float) numberOfFrames {return numberOfFrames;}

-(void) Azimuth:(float) a
{
	aCamera->Azimuth( a);
	aCamera->OrthogonalizeViewUp();
}

-(void) Vertical:(float) a
{
	aCamera->Elevation( a);
	aCamera->OrthogonalizeViewUp();
}

- (IBAction) export3DFileFormat :(id) sender
{
	NSSavePanel     *panel = [NSSavePanel savePanel];
	
	[panel setCanSelectHiddenExtension:YES];
	
	switch ([sender tag])
	{
        case 1: [panel setAllowedFileTypes: @[@"rib"]];    break;
        case 2: [panel setAllowedFileTypes: @[@"wrl"]];    break;
        case 3: [panel setAllowedFileTypes: @[@"iv"]];     break;
        case 4: [panel setAllowedFileTypes: @[@"obj"]];    break;
        case 5: [panel setAllowedFileTypes: @[@"stl"]];    break;
	}
	
    [panel setNameFieldStringValue: @"3DFile"];

    if ([panel runModal] == NSModalResponseOK)
	{
		BOOL orientationSwitch = NO;
		
		if (orientationWidget)
		{
			if (orientationWidget->GetEnabled())
			{
				orientationSwitch= YES;
				[self switchOrientationWidget: self];
			}
		}
		
		WaitRendering *splashExport = [[WaitRendering alloc] init: NSLocalizedString( @"Exporting...", nil)];
		[splashExport showWindow:self];
		
		switch ([sender tag])
		{
			case 1:
			{
				vtkRIBExporter  *exporter = vtkRIBExporter::New();
				
				exporter->SetInput( [self renderWindow]);
				exporter->SetFilePrefix( [[[panel filename] stringByDeletingPathExtension] UTF8String]);
				exporter->Write();
				
				exporter->Delete();
			}
			break;
			
			case 2:
			{
				vtkVRMLExporter  *exporter = vtkVRMLExporter::New();
				
				exporter->SetInput( [self renderWindow]);
				exporter->SetFileName( [[panel filename] UTF8String]);
				exporter->Write();
				
				exporter->Delete();
			}
			break;
			
			case 3:
			{
				vtkIVExporter  *exporter = vtkIVExporter::New();
				
				exporter->SetInput( [self renderWindow]);
				exporter->SetFileName( [[panel filename] UTF8String]);
				exporter->Write();
				
				exporter->Delete();
			}
			break;
			
			case 4:
			{
				vtkOBJExporter  *exporter = vtkOBJExporter::New();
				
				exporter->SetInput( [self renderWindow]);
				exporter->SetFilePrefix( [[[panel filename] stringByDeletingPathExtension] UTF8String]);
				exporter->Write();
				
				exporter->Delete();
			}
			break;
			
			case 5:
			{
				vtkSTLWriter  *exporter = vtkSTLWriter::New();
				
				if (isoMapper[0] != nil)
					exporter->SetInputData(isoMapper[0]->GetInput());
				else if (isoMapper[1] != nil)
					exporter->SetInputData(isoMapper[1]->GetInput());
				else
					exporter->SetInputData( nil);
                
				exporter->SetFileName( [[panel filename] UTF8String]);
				exporter->Write();
				
				exporter->Delete();
			}
			break;
		}
		
		[splashExport close];
		[splashExport autorelease];
		
		if (orientationSwitch)
		{
			[self switchOrientationWidget: self];
		}

	}
}

-(IBAction) endQuicktimeVRSettings:(id) sender
{
//	[export3DVRWindow orderOut:sender];
//	
//	[NSApp endSheet:export3DVRWindow returnCode:[sender tag]];
//	
//	numberOfFrames = [[VRFrames selectedCell] tag];
//	
//	rotationValue = 360;
//	
//	if ([sender tag])
//	{
//		NSString			*path, *newpath;
//		QuicktimeExport		*mov;
//		
//		[self setViewSizeToMatrix3DExport];
//		
//		if (numberOfFrames == 10 || numberOfFrames == 20)
//			mov = [[QuicktimeExport alloc] initWithSelector: self : @selector(imageForFrameVR: maxFrame:) :numberOfFrames*numberOfFrames];
//		else
//			mov = [[QuicktimeExport alloc] initWithSelector: self : @selector(imageForFrameVR: maxFrame:) :numberOfFrames];
//		
//		//[mov setCodec:kJPEGCodecType :codecHighQuality];
//		
//		path = [mov createMovieQTKit: NO  :NO :[[[[[self window] windowController] fileList] objectAtIndex:0] valueForKeyPath:@"series.study.name"]];
//		
//		if (path)
//		{
//			if (numberOfFrames == 10 || numberOfFrames == 20 || numberOfFrames == 40)
//				newpath = [QuicktimeExport generateQTVR: path frames: numberOfFrames*numberOfFrames];
//			else
//				newpath = [QuicktimeExport generateQTVR: path frames: numberOfFrames];
//			
//			[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
//			[[NSFileManager defaultManager] moveItemAtPath: newpath  toPath: path error: nil];
//			
//			[[NSWorkspace sharedWorkspace] openFile: path withApplication: nil andDeactivate: YES];
//			[NSThread sleepForTimeInterval: 1];
//		}
//		
//		[mov release];
//		
//		[self restoreViewSizeAfterMatrix3DExport];
//	}
}

-(IBAction) exportQuicktime3DVR:(id) sender
{
	[NSApp beginSheet: export3DVRWindow modalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:(void*) nil];
}

- (IBAction) exportQuicktime :(id) sender
{
	
    [NSApp beginSheet: export3DWindow modalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:(void*) nil];
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
    while (view = [enumerator nextObject]) {
        [self checkView:view :OnOff];
	}
}

- (IBAction) setCurrentdcmExport:(id) sender
{
	if ([[sender selectedCell] tag] == 1)
        [self checkView: dcmBox :YES];
	else
        [self checkView: dcmBox :NO];
}

-(IBAction) endDCMExportSettings:(id) sender
{
	[exportDCMWindow makeFirstResponder: nil];	// To force nstextfield validation.
	[exportDCMWindow orderOut:sender];
	
	[NSApp endSheet:exportDCMWindow returnCode:[sender tag]];
	
	numberOfFrames = [dcmframesSlider intValue];
//	bestRenderingMode = [[dcmquality selectedCell] tag];
	if ([[dcmrotation selectedCell] tag] == 1)
        rotationValue = 360;
	else
        rotationValue = 180;
	
	if ([[dcmorientation selectedCell] tag] == 1)
        rotationOrientation = 1;
	else
        rotationOrientation = 0;
	
	NSMutableArray *producedFiles = [NSMutableArray array];
	
	if ([sender tag])
	{
		[self setViewSizeToMatrix3DExport];
		
		// CURRENT image only
		if ([[dcmExportMode selectedCell] tag] == 0)
		{
			long	width, height, spp, bpp;
			float	o[ 9];
			
			if (exportDCM == nil)
                exportDCM = [[DICOMExport alloc] init];
			
			//[self renderImageWithBestQuality: bestRenderingMode waitDialog: NO];
			unsigned char *dataPtr = [self getRawPixels:&width :&height :&spp :&bpp :YES :YES];
			//[self endRenderImageWithBestQuality];
			
			if (dataPtr)
			{
				[exportDCM setSourceFile: [firstObject sourceFile]];
				[exportDCM setSeriesDescription: [dcmSeriesName stringValue]];
				[exportDCM setSeriesNumber:5500];
				[exportDCM setPixelData: dataPtr samplesPerPixel:spp bitsPerSample:bpp width: width height: height];
				
				[self getOrientation: o];
				if ([[NSUserDefaults standardUserDefaults] boolForKey: @"exportOrientationIn3DExport"])
					[exportDCM setOrientation: o];
				
//				if (aCamera->GetParallelProjection())
//					[exportDCM setPixelSpacing: [self getResolution] :[self getResolution]];
				
				NSString *f = [exportDCM writeDCMFile: nil];
				if (f == nil)
                    NSRunCriticalAlertPanel2(NSLocalizedString(@"Error", nil),
                                            NSLocalizedString( @"Error during the creation of the DICOM File!", nil),
                                            NSLocalizedString(@"OK", nil),
                                            nil,
                                            nil);
				
				if (f)
					[producedFiles addObject: [NSDictionary dictionaryWithObjectsAndKeys: f, @"file", nil]];
				
				free( dataPtr);
			}
		}
		else // A 3D sequence
		{
			float o[ 9];
			DICOMExport *dcmSequence = [[DICOMExport alloc] init];
			
			Wait *progress = [[Wait alloc] initWithString: NSLocalizedString( @"Creating a DICOM series", nil)];
			[progress showWindow:self];
			[[progress progress] setMaxValue: numberOfFrames];
			
			[dcmSequence setSeriesNumber:5500 + [[NSCalendarDate date] minuteOfHour]  + [[NSCalendarDate date] secondOfMinute]];
			[dcmSequence setSeriesDescription: [dcmSeriesName stringValue]];
			[dcmSequence setSourceFile: [firstObject sourceFile]];
			
			//if (croppingBox->GetEnabled()) croppingBox->Off();
			
			BOOL wasPresent = NO;
	
			if (aRenderer->GetActors()->IsItemPresent( outlineRect))
			{
				aRenderer->RemoveActor( outlineRect);
				wasPresent = YES;
			}
			
			aRenderer->RemoveActor(textX);
			[self display];
			for (long i = 0; i < numberOfFrames; i++)
			{
				NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
				
			//	[self renderImageWithBestQuality: bestRenderingMode waitDialog: NO];
				long	width, height, spp, bpp;
				
				unsigned char *dataPtr = [self getRawPixels:&width :&height :&spp :&bpp :YES :YES];
				
				if (dataPtr)
				{
					[self getOrientation: o];
					if ([[NSUserDefaults standardUserDefaults] boolForKey: @"exportOrientationIn3DExport"])
						[dcmSequence setOrientation: o];
					
					[dcmSequence setPixelData: dataPtr samplesPerPixel:spp bitsPerSample:bpp width: width height: height];
				
//					if (aCamera->GetParallelProjection())
//						[dcmSequence setPixelSpacing: [self getResolution] :[self getResolution]];
					
					NSString *f = [dcmSequence writeDCMFile: nil];
					
					if (f)
						[producedFiles addObject: [NSDictionary dictionaryWithObjectsAndKeys: f, @"file", nil]];
					
					free( dataPtr);
				}
				
				switch (rotationOrientation)
				{
					case 0:
						[self Azimuth: (float) rotationValue / (float) numberOfFrames];
                        break;
					
					case 1:
						[self Vertical: (float) rotationValue / (float) numberOfFrames];
                        break;
				}
				[self display];
				[progress incrementBy: 1];
				
				[pool release];
			}
			
			if (wasPresent)
				aRenderer->AddActor(outlineRect);
			
			aRenderer->AddActor(textX);
			
//			[self endRenderImageWithBestQuality];
			
			[progress close];
			[progress autorelease];
			
			[dcmSequence release];
		}
		
		if ([producedFiles count])
		{
			NSArray *objects = [BrowserController.currentBrowser.database addFilesAtPaths: [producedFiles valueForKey: @"file"]
                                                                        postNotifications: YES
                                                                                dicomOnly: YES
                                                                      rereadExistingItems: YES
                                                                        generatedByOsiriX: YES];
			
            objects = [BrowserController.currentBrowser.database objectsWithIDs: objects];
            
			if ([[NSUserDefaults standardUserDefaults] boolForKey: @"afterExportSendToDICOMNode"])
				[[BrowserController currentBrowser] selectServer: objects];
			
			if ([[NSUserDefaults standardUserDefaults] boolForKey: @"afterExportMarkThemAsKeyImages"])
			{
				for (NSManagedObject *im in objects)
					[im setValue: @YES forKey: @"isKeyImage"];
			}
		}
		
		[self restoreViewSizeAfterMatrix3DExport];
	}
}

- (void) exportDICOMFile:(id) sender
{
	[self setCurrentdcmExport: dcmExportMode];
	//if ([[[self window] windowController] movieFrames] > 1) [[dcmExportMode cellWithTag:2] setEnabled: YES];
	//else [[dcmExportMode cellWithTag:2] setEnabled: NO];
	[NSApp beginSheet: exportDCMWindow
       modalForWindow: [self window]
        modalDelegate: self
       didEndSelector: nil
          contextInfo: (void*) nil];
}

-(BOOL) acceptsFirstMouse:(NSEvent*) theEvent
{
	return YES;
}

-(void) runRendering
{
	if (noWaitDialog == NO)
	{
		if ([splash run] == NO)
		{
			[self renderWindow]->SetAbortRender( true);
		}
	}
}

- (NSDate*) startRenderingTime
{
	return startRenderingTime;
}

- (void) newStartRenderingTime
{
	startRenderingTime = [[NSDate date] retain];
}

-(void) startRendering
{
	if (noWaitDialog == NO)
		[splash start];
}

-(void) stopRendering
{
	if (noWaitDialog == NO)
		[splash end];
}

- (IBAction) resetImage:(id) sender
{
	aCamera->SetViewUp (0, 1, 0);
	aCamera->SetFocalPoint (0, 0, 0);
	aCamera->SetPosition (0, 0, 1);
	aCamera->SetRoll(180);
	aCamera->Dolly(1.5);
	
	aRenderer->ResetCamera();
	[self saView:self];
    [self setNeedsDisplay:YES];
}

- (void) CloseViewerNotification: (NSNotification*) note
{
	if ([note object] == blendingController) // our blended serie is closing itself....
	{
		[self setBlendingPixSource:nil];
	}
}

# pragma mark-

- (ToolMode) getTool: (NSEvent*) event
{
	ToolMode tool;
	
	if ([event type] == NSRightMouseDown || [event type] == NSRightMouseDragged || [event type] == NSRightMouseUp)
        tool = tZoom;
	else if ([event type] == NSOtherMouseDown || [event type] == NSOtherMouseDragged || [event type] == NSOtherMouseUp)
        tool = tTranslate;
	else
        tool = currentTool;
	
	if (([event modifierFlags] & NSEventModifierFlagControl))  tool = tRotate;
	if (([event modifierFlags] & NSEventModifierFlagShift))  tool = tZoom;
	if (([event modifierFlags] & NSEventModifierFlagCommand))  tool = tTranslate;
	if (([event modifierFlags] & NSEventModifierFlagOption))  tool = tWL;

    if (([event modifierFlags] & NSEventModifierFlagCommand) &&
        ([event modifierFlags] & NSEventModifierFlagOption))  tool = tRotate;
	
    if (([event modifierFlags] & NSEventModifierFlagCommand) &&
        ([event modifierFlags] & NSEventModifierFlagControl))  tool = tCamera3D;
	
	return tool;
}

- (void) flagsChanged:(NSEvent *)event
{
	if ([event modifierFlags])
	{
		ToolMode tool = [self getTool: event];
		[self setCursorForView: tool];
		if (cursorSet)
            [cursor set];
	}
	
	[super flagsChanged: event];
}

-(instancetype)initWithFrame:(NSRect)frame
{
	NSLog(@"SRView initWithFrame");
    if ( self = [super initWithFrame:frame] )
    {
        NSTrackingAreaOptions _options = (NSTrackingCursorUpdate | NSTrackingInVisibleRect | NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow);
		NSTrackingArea *cursorTracking = [[[NSTrackingArea alloc] initWithRect: [self visibleRect]
                                                                       options: _options
                                                                         owner: self
                                                                      userInfo: nil] autorelease];
		
		[self addTrackingArea: cursorTracking];
		
		splash = [[WaitRendering alloc] init: NSLocalizedString( @"Rendering...", nil)];
//		[[splash window] makeKeyAndOrderFront:self];
		
		cursor = nil;
		isoExtractor[ 0] = isoExtractor[ 1] = nil;
		isoResample = nil;
		
		BisoExtractor[ 0] = BisoExtractor[ 1] = nil;
		BisoResample = nil;
		
		currentTool = t3DRotate;
		[self setCursorForView: currentTool];
		
		blendingController = nil;
		blendingFactor = 0.5;
		blendingReader = nil;
//		cbStart = nil;
		
		exportDCM = nil;
		
		noWaitDialog = NO;
		
		NSNotificationCenter *nc;
		nc = [NSNotificationCenter defaultCenter];
		[nc addObserver: self
			   selector: @selector(CloseViewerNotification:)
				   name: OsirixCloseViewerNotification
				 object: nil];
			 
		point3DActorArray     = [[NSMutableArray alloc] initWithCapacity:0];
		point3DPositionsArray = [[NSMutableArray alloc] initWithCapacity:0];
		point3DRadiusArray    = [[NSMutableArray alloc] initWithCapacity:0];
		point3DColorsArray    = [[NSMutableArray alloc] initWithCapacity:0];
		
		point3DDisplayPositionArray  = [[NSMutableArray alloc] initWithCapacity:0];
		point3DTextArray             = [[NSMutableArray alloc] initWithCapacity:0];
		point3DPositionsStringsArray = [[NSMutableArray alloc] initWithCapacity:0];
		point3DTextColorsArray       = [[NSMutableArray alloc] initWithCapacity:0];
		point3DTextSizesArray        = [[NSMutableArray alloc] initWithCapacity:0];
		
		display3DPoints = YES;
		[self load3DPointsDefaultProperties];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(windowWillClose:)
                                                     name: NSWindowWillCloseNotification
                                                   object: nil];
    }
    
    return self;
}

- (void)windowWillClose:(NSNotification *)notification
{
	if ([notification object] == [self window])
	{
		[[self window] setAcceptsMouseMovedEvents: NO];
		[self deleteMouseDownTimer];
		[self prepareForRelease];
		[[NSNotificationCenter defaultCenter] removeObserver: self];
	}
}

-(void)dealloc
{
#ifndef NDEBUG
    NSLog(@"SRView.mm:%d %@ dealloc %p", __LINE__, NSStringFromClass([self class]), self);
#endif
	
    [NSObject cancelPreviousPerformRequestsWithTarget: [self window]];
    
	[splash close];
	[splash autorelease];
	[exportDCM release];
	
	if ([firstObject isRGB])
        free( dataFRGB);
	
    [[NSNotificationCenter defaultCenter] removeObserver: self];

	[self setBlendingPixSource: nil];
	
	for (long i = 0 ; i < 2; i++)
	{
		[self deleteActor:i];
		[self BdeleteActor:i];
	}
	
	if (flip)
        flip->Delete();
	
	if (isoResample)
        isoResample->Delete();
    
	if (BisoResample)
        BisoResample->Delete();
	
//	cbStart->Delete();
	matrice->Delete();
	
	outlineData->Delete();
	mapOutline->Delete();
	outlineRect->Delete();
	
	reader->Delete();
    aCamera->Delete();
	textX->Delete();
	if (orientationWidget)
		orientationWidget->Delete();
    
    for (int i = 0; i < NUM_SR_LABELS; i++) {
        oText[i]->Delete();
        oText[i] = NULL;
    }
    
	//	aRenderer->Delete();
	
    [pixList release];
    pixList = nil;
	
	[point3DActorArray release];
	[point3DPositionsArray release];
	[point3DRadiusArray release];
	[point3DColorsArray release];
	
	[point3DDisplayPositionArray release];
	[point3DTextArray release];
	[point3DPositionsStringsArray release];
	[point3DTextColorsArray release];
	[point3DTextSizesArray release];
	
	[cursor release];
	
	[_mouseDownTimer invalidate];
	[_mouseDownTimer release];
	
	[destinationImage release];
    [super dealloc];
}
# pragma mark-

- (void) getOrientation: (float*) o 
{
    if (aCamera)
    {
        vtkMatrix4x4 *matrix = aCamera->GetViewTransformMatrix();
        
        for (long i = 0; i < 3; i++)
            for (long j = 0; j < 3; j++)
                o[ 3*i + j] = matrix->GetElement( i , j);
                
        o[ 3] = -o[ 3];
        o[ 4] = -o[ 4];
        o[ 5] = -o[ 5];
    }
}

- (void) computeOrientationText
{
	char string[ ORIENTATION_STRING_MAX_SIZE];
	float vectors[ 9];  // Why 9 ? It should be 3
	
	[self getOrientation: vectors];
	
    // Left ?
	[self getOrientationText:string vector:vectors inversion:YES];
	oText[ 0]->SetInput( string);
	
    // Right ?
	[self getOrientationText:string vector:vectors inversion:NO];
	oText[ 1]->SetInput( string);
	
    // Bottom ?
	[self getOrientationText:string vector:vectors+3 inversion:NO];
	oText[ 2]->SetInput( string);
	
    // Top ?
	[self getOrientationText:string vector:vectors+3 inversion:YES];
	oText[ 3]->SetInput( string);
}

- (void)otherMouseDown:(NSEvent *)theEvent
{
	ToolMode tool = [self getTool: theEvent];
	[self setCursorForView: tool];
	[super otherMouseDown: theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	if (_dragInProgress == NO && ([theEvent deltaX] != 0 || [theEvent deltaY] != 0))
        [self deleteMouseDownTimer];
    
	if (_dragInProgress == YES)
        return;
	
	if (_resizeFrame)
    {
		NSRect	newFrame = [self frame];
		NSRect	beforeFrame = [self frame];
#if 0 // original
		NSPoint mouseLoc = [theEvent locationInWindow];	//[self convertPoint: [theEvent locationInWindow] fromView:nil];
#else
        NSPoint mouseLoc = [self convertPointToBacking: [theEvent locationInWindow]];
#endif
		if ([theEvent modifierFlags] & NSEventModifierFlagShift)
		{
			newFrame.size.width = [[[self window] contentView] frame].size.width - mouseLoc.x*2;
			newFrame.size.height = newFrame.size.width;
			
			mouseLoc.x = ([[[self window] contentView] frame].size.width - newFrame.size.width) / 2;
			mouseLoc.y = ([[[self window] contentView] frame].size.height - newFrame.size.height) / 2;
		}
		
		if ([[[self window] contentView] frame].size.width - mouseLoc.x*2 < 100)
			mouseLoc.x = ([[[self window] contentView] frame].size.width - 100) / 2;
		
		if ([[[self window] contentView] frame].size.height - mouseLoc.y*2 < 100)
			mouseLoc.y = ([[[self window] contentView] frame].size.height - 100) / 2;
		
		if (mouseLoc.x < 10)
			mouseLoc.x = 10;
		
		if (mouseLoc.y < 10)
			mouseLoc.y = 10;
			
		newFrame.origin.x = mouseLoc.x;
		newFrame.origin.y = mouseLoc.y;
		newFrame.size.width = [[[self window] contentView] frame].size.width - mouseLoc.x*2;
		newFrame.size.height = [[[self window] contentView] frame].size.height - mouseLoc.y*2;
		[self setFrame: newFrame];
		
		aCamera->Zoom( beforeFrame.size.height / newFrame.size.height);
		
		[[self window] display];
		[self setNeedsDisplay:YES];
	}	
	else {
		int shiftDown;
		int controlDown;
		
#if 0 // original
		NSPoint mouseLoc = [self convertPoint: [theEvent locationInWindow] fromView:nil];
        mouseLoc = [self convertPointToBacking: mouseLoc]; // Retina
#else
        NSPoint mouseLoc = [self convertPointToBacking: [theEvent locationInWindow]];
#endif
		switch (_tool) {
			case tRotate:
				shiftDown  = 0;
				controlDown = 1;
				[self getInteractor]->SetEventInformation((int) mouseLoc.x, (int) mouseLoc.y, controlDown, shiftDown);
				[self computeOrientationText];
				[self getInteractor]->InvokeEvent(vtkCommand::MouseMoveEvent, NULL);
				break;
                
			case t3DRotate:
				shiftDown  = 0;
				controlDown = 0;		
				[self getInteractor]->SetEventInformation((int) mouseLoc.x, (int) mouseLoc.y, controlDown, shiftDown);
				[self computeOrientationText];
				[self getInteractor]->InvokeEvent(vtkCommand::MouseMoveEvent, NULL);
				break;
                
			case tTranslate:
				shiftDown  = 1;
				controlDown = 0;
				[self getInteractor]->SetEventInformation((int) mouseLoc.x, (int) mouseLoc.y, controlDown, shiftDown);
				[self getInteractor]->InvokeEvent(vtkCommand::MouseMoveEvent, NULL);
				break;
                
			case tZoom:				
				[self rightMouseDragged:theEvent];
				break;
                
			case tCamera3D:
				aCamera->Yaw( -(mouseLoc.x - _mouseLocStart.x) / 5.);
				aCamera->Pitch( (mouseLoc.y - _mouseLocStart.y) / 5.);
				aCamera->ComputeViewPlaneNormal();
				aCamera->OrthogonalizeViewUp();
				aRenderer->ResetCameraClippingRange();
				[self computeOrientationText];
				_mouseLocStart = mouseLoc;
				[self setNeedsDisplay:YES];
				break;
                
			default:
				break;
		}
	}	
}

- (void)rightMouseDragged:(NSEvent *)theEvent
{
	int shiftDown, controlDown;
	float distance;
	NSPoint mouseLoc, mouseLocPre;
	mouseLocPre = mouseLoc = 
#if 0 // original
    [self convertPoint: [theEvent locationInWindow] fromView:nil];
#else
    [self convertPointToBacking: [theEvent locationInWindow]];
#endif
	switch (_tool) {
		case tZoom:
			if (projectionMode != 2){
				shiftDown = 0;
				controlDown = 1;				
				[self getInteractor]->SetEventInformation((int) mouseLoc.x, (int) mouseLoc.y, controlDown, shiftDown);
				[self getInteractor]->InvokeEvent(vtkCommand::MouseMoveEvent, NULL);
			}
			else {
				distance = aCamera->GetDistance();
				aCamera->Dolly( 1.0 + ( mouseLocPre.y - _mouseLocStart.y) / 1200.);
				aCamera->SetDistance( distance);
				aCamera->ComputeViewPlaneNormal();
				aCamera->OrthogonalizeViewUp();
				aRenderer->ResetCameraClippingRange();
				_mouseLocStart = mouseLoc;
				[self setNeedsDisplay:YES];
			}
			break;
            
        default:
            break;
	}
}

- (void)mouseUp:(NSEvent *)theEvent
{
	[self deleteMouseDownTimer];
	
	switch (_tool) {
		case tRotate:
		case t3DRotate:
		case tTranslate:
			[self getInteractor]->InvokeEvent(vtkCommand::LeftButtonReleaseEvent, NULL);
			break;
            
		case tZoom:
			[self rightMouseUp:theEvent];
			break;
            
		default:
			break;
	}
		
	[super mouseUp:theEvent];
}

- (void)rightMouseDown:(NSEvent *)theEvent
{	
	noWaitDialog = YES;
	[self mouseDown:theEvent];
	noWaitDialog = NO;
}

- (void)rightMouseUp:(NSEvent *)theEvent
{
	NSPoint mouseLoc = 
#if 0 // original
    [self convertPoint: [theEvent locationInWindow] fromView:nil];
#else
    [self convertPointToBacking: [theEvent locationInWindow]];
#endif
	if (_tool == tZoom && ( projectionMode != 2)) {
		int shiftDown = 0;
		int controlDown = 1;
		[self getInteractor]->SetEventInformation((int) mouseLoc.x, (int) mouseLoc.y, controlDown, shiftDown);
		[self getInteractor]->InvokeEvent(vtkCommand::LeftButtonReleaseEvent, NULL);
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint mouseLoc, mouseLocStart, mouseLocPre;
	ToolMode tool;
    float sf = [[NSScreen mainScreen] backingScaleFactor];
	
	noWaitDialog = YES;
	tool = currentTool;

	if ([theEvent type] == NSLeftMouseDown) {
		if (_mouseDownTimer)
			[self deleteMouseDownTimer];

        _mouseDownTimer = [[NSTimer scheduledTimerWithTimeInterval: 1.0
                                                            target: self
                                                          selector: @selector(startDrag:)
                                                          userInfo: theEvent
                                                           repeats: NO] retain];
	}

#if 0 // original
	mouseLocStart = [self convertPoint: [theEvent locationInWindow] fromView: nil];
    mouseLocStart = [self convertPointToBacking: mouseLocStart]; // Retina
#else
    mouseLocStart = [self convertPointToBacking: [theEvent locationInWindow]];
#endif
	_mouseLocStart = mouseLocStart;
	
	if (mouseLocStart.x < 10*sf &&
        mouseLocStart.y < 10*sf)
	{
		_resizeFrame = YES;
		return;
		/*
		NSRect	newFrame = [self frame];
		NSRect	beforeFrame;
		
		do
		{
			theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSPeriodicMask];
			
			mouseLoc = [theEvent locationInWindow];	//[self convertPoint: [theEvent locationInWindow] fromView:nil];
			
			switch ([theEvent type])
			{
				case NSLeftMouseDragged:
					beforeFrame = [self frame];
				
					if ([[[self window] contentView] frame].size.width - mouseLoc.x*2 < 100)
						mouseLoc.x = ([[[self window] contentView] frame].size.width - 100) / 2;
					
					if ([[[self window] contentView] frame].size.height - mouseLoc.y*2 < 100)
						mouseLoc.y = ([[[self window] contentView] frame].size.height - 100) / 2;
					
					if (mouseLoc.x < 10)
						mouseLoc.x = 10;
					
					if (mouseLoc.y < 10)
						mouseLoc.y = 10;
						
					newFrame.origin.x = mouseLoc.x;
					newFrame.origin.y = mouseLoc.y;
					
					newFrame.size.width = [[[self window] contentView] frame].size.width - mouseLoc.x*2;
					newFrame.size.height = [[[self window] contentView] frame].size.height - mouseLoc.y*2;
					
					[self setFrame: newFrame];
					
					aCamera->Zoom( beforeFrame.size.height / newFrame.size.height);
					
					[[self window] display];
					
				//	NSLog(@"%f", aCamera->GetParallelScale());
				//	NSLog(@"%f", aCamera->GetViewAngle());
				break;
				
				case NSLeftMouseUp:
					noWaitDialog = NO;
					keepOn = NO;
				break;
					
				case NSPeriodic:
				break;
					
				default:				
				break;
			}
		}while (keepOn);
		
		[self setNeedsDisplay:YES];
		*/
	}
	else
	{
		if ([theEvent clickCount] > 1 &&
            (tool != t3Dpoint))
		{
			vtkWorldPointPicker *picker = vtkWorldPointPicker::New();
			picker->Pick(mouseLocStart.x, mouseLocStart.y, 0.0, aRenderer);
			
			double wXYZ[3];
			picker->GetPickPosition(wXYZ);
			picker->Delete();
			
			double dc[3], sc[3];
			dc[0] = wXYZ[0];
			dc[1] = wXYZ[1];
			dc[2] = wXYZ[2];
			
			[self convert3Dto2Dpoint:dc :sc];
			
			NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithInt: sc[0]*[firstObject pixelSpacingX]], @"x",
                                  [NSNumber numberWithInt: sc[1]*[firstObject pixelSpacingY]], @"y",
                                  [NSNumber numberWithInt: sc[2]], @"z",
                                  nil];
			
			[[NSNotificationCenter defaultCenter] postNotificationName: OsirixDisplay3dPointNotification
                                                                object: pixList
                                                              userInfo: dict];
			
			return;
		}
	
		_resizeFrame = NO;
		tool = [self getTool: theEvent];
		_tool = tool;
		[self setCursorForView: tool];
		
		if (tool == tRotate)
		{
			int shiftDown = 0;
			int controlDown = 1;

			mouseLoc = 
#if 0 // original
            [self convertPoint: [theEvent locationInWindow] fromView:nil];
#else
            [self convertPointToBacking: [theEvent locationInWindow]];
#endif
			[self getInteractor]->SetEventInformation((int) mouseLoc.x, (int) mouseLoc.y, controlDown, shiftDown);
			[self getInteractor]->InvokeEvent(vtkCommand::LeftButtonPressEvent,NULL);
			
			/*
			do {
				theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSPeriodicMask];
				mouseLoc = [self convertPoint: [theEvent locationInWindow] fromView:nil];
				[self getInteractor]->SetEventInformation((int) mouseLoc.x, (int) mouseLoc.y, controlDown, shiftDown);
				switch ([theEvent type]) {
				case NSLeftMouseDragged:
					[self computeOrientationText];
					[self getInteractor]->InvokeEvent(vtkCommand::MouseMoveEvent, NULL);
					break;
				case NSLeftMouseUp:
					noWaitDialog = NO;
					[self getInteractor]->InvokeEvent(vtkCommand::LeftButtonReleaseEvent, NULL);
					keepOn = NO;
					break;
				case NSPeriodic:
					[self getInteractor]->InvokeEvent(vtkCommand::TimerEvent, NULL);
					break;
				default:
					break;
				}
			}while (keepOn);
			*/
		}
		else if (tool == t3DRotate)
		{
			int shiftDown = 0;//([theEvent modifierFlags] & NSEventModifierFlagShift);
			int controlDown = 0;//([theEvent modifierFlags] & NSEventModifierFlagControl);

			mouseLoc = 
#if 0 // original
            [self convertPoint: [theEvent locationInWindow] fromView:nil];
#else
            [self convertPointToBacking: [theEvent locationInWindow]];
#endif
			[self getInteractor]->SetEventInformation((int)mouseLoc.x, (int)mouseLoc.y, controlDown, shiftDown);
			[self getInteractor]->InvokeEvent(vtkCommand::LeftButtonPressEvent,NULL);
			/*			
			do {
				theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSPeriodicMask];
				mouseLoc = [self convertPoint: [theEvent locationInWindow] fromView:nil];
				[self getInteractor]->SetEventInformation((int)mouseLoc.x, (int)mouseLoc.y, controlDown, shiftDown);
				switch ([theEvent type]) {
				case NSLeftMouseDragged:
					[self computeOrientationText];
					[self getInteractor]->InvokeEvent(vtkCommand::MouseMoveEvent, NULL);
					break;
				case NSLeftMouseUp:
					noWaitDialog = NO;
					[self getInteractor]->InvokeEvent(vtkCommand::LeftButtonReleaseEvent, NULL);
					keepOn = NO;
					break;
				case NSPeriodic:
					NSLog(@"NSPeriodic 3D rotate");
					[self getInteractor]->InvokeEvent(vtkCommand::TimerEvent, NULL);
					break;
				default:
					break;
				}
			}while (keepOn);
			*/
		}
		else if (tool == tTranslate)
		{
			int shiftDown = 1;
			int controlDown = 0;

			mouseLoc = 
#if 0 // original
            [self convertPoint: [theEvent locationInWindow] fromView:nil];
#else
            [self convertPointToBacking: [theEvent locationInWindow]];
#endif
			[self getInteractor]->SetEventInformation((int)mouseLoc.x, (int)mouseLoc.y, controlDown, shiftDown);
			[self getInteractor]->InvokeEvent(vtkCommand::LeftButtonPressEvent,NULL);
			/*
			do {
				theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSPeriodicMask];
				mouseLoc = [self convertPoint: [theEvent locationInWindow] fromView:nil];
				[self getInteractor]->SetEventInformation((int) mouseLoc.x, (int) mouseLoc.y, controlDown, shiftDown);
				switch ([theEvent type]) {
				case NSLeftMouseDragged:
					[self getInteractor]->InvokeEvent(vtkCommand::MouseMoveEvent, NULL);
					break;
				case NSLeftMouseUp:
					noWaitDialog = NO;
					[self getInteractor]->InvokeEvent(vtkCommand::LeftButtonReleaseEvent, NULL);
					keepOn = NO;
					break;
				case NSPeriodic:
					[self getInteractor]->InvokeEvent(vtkCommand::TimerEvent, NULL);
					break;
				default:
					break;
				}
			}while (keepOn);
			*/
		}
		else if (tool == tZoom)
		{
			if (projectionMode != 2)
			{
				int shiftDown = 0;
				int controlDown = 1;

				mouseLoc = 
#if 0 // original
                [self convertPoint: [theEvent locationInWindow] fromView:nil];
#else
                [self convertPointToBacking: [theEvent locationInWindow]];
#endif
				[self getInteractor]->SetEventInformation((int) mouseLoc.x, (int) mouseLoc.y, controlDown, shiftDown);
				[self getInteractor]->InvokeEvent(vtkCommand::RightButtonPressEvent,NULL);
				/*
				do {
					theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSPeriodicMask];
					mouseLoc = [self convertPoint: [theEvent locationInWindow] fromView:nil];
					[self getInteractor]->SetEventInformation((int) mouseLoc.x, (int) mouseLoc.y, controlDown, shiftDown);
					switch ([theEvent type]) {
					case NSLeftMouseDragged:
					case NSRightMouseDragged:
						[self getInteractor]->InvokeEvent(vtkCommand::MouseMoveEvent, NULL);
						break;
					case NSLeftMouseUp:
					case NSRightMouseUp:
						noWaitDialog = NO;
						[self getInteractor]->InvokeEvent(vtkCommand::LeftButtonReleaseEvent, NULL);
						keepOn = NO;
						break;
					case NSPeriodic:
						[self getInteractor]->InvokeEvent(vtkCommand::TimerEvent, NULL);
						break;
					default:
						break;
					}
				}while (keepOn);
				*/
			}
			else
			{
				// vtkCamera
				mouseLocPre = mouseLocStart = 
#if 0 // original
                [self convertPoint: [theEvent locationInWindow] fromView:nil];
#else
                [self convertPointToBacking: [theEvent locationInWindow]];
#endif
				//if (volumeMapper) volumeMapper->SetMinimumImageSampleDistance( LOD*3);
				/*
				do
				{
					theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSPeriodicMask];
					mouseLoc = [self convertPoint: [theEvent locationInWindow] fromView:nil];
					switch ([theEvent type])
					{
					case NSLeftMouseDragged:
					case NSRightMouseDragged:
					{
						float distance = aCamera->GetDistance();
						aCamera->Dolly( 1.0 + (mouseLoc.y - mouseLocPre.y) / 1200.);
						aCamera->SetDistance( distance);
						aCamera->ComputeViewPlaneNormal();
						aCamera->OrthogonalizeViewUp();
						aRenderer->ResetCameraClippingRange();
						
						[self setNeedsDisplay:YES];
					}
					break;
					
					case NSLeftMouseUp:
					case NSRightMouseUp:
						noWaitDialog = NO;
						keepOn = NO;
						break;
						
					case NSPeriodic:
						break;
						
					default:
						break;
					}
					
					mouseLocPre = mouseLoc;
				}while (keepOn);
				*/
				//if (volumeMapper) volumeMapper->SetMinimumImageSampleDistance( LOD);
				
				[self setNeedsDisplay:YES];
			}
		}
		else if (tool == tCamera3D)
		{
			// vtkCamera
			mouseLocPre = mouseLocStart = 
#if 0 // original
            [self convertPoint: [theEvent locationInWindow] fromView:nil];
#else
            [self convertPointToBacking: [theEvent locationInWindow]];
#endif
//			if (volumeMapper) volumeMapper->SetMinimumImageSampleDistance( LOD*3);
//			if (textureMapper) textureMapper->SetMaximumNumberOfPlanes( 512 / 10);
			/*
			do
			{
				
				theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSPeriodicMask];
				mouseLoc = [self convertPoint: [theEvent locationInWindow] fromView:nil];
				switch ([theEvent type])
				{
				case NSLeftMouseDragged:
				{
					aCamera->Yaw( -(mouseLoc.x - mouseLocPre.x) / 5.);
					aCamera->Pitch( (mouseLoc.y - mouseLocPre.y) / 5.);
					aCamera->ComputeViewPlaneNormal();
					aCamera->OrthogonalizeViewUp();
					aRenderer->ResetCameraClippingRange();
					
					[self computeOrientationText];
					[self setNeedsDisplay:YES];
				}
				break;
				
				case NSLeftMouseUp:
					noWaitDialog = NO;
					keepOn = NO;
					break;
					
				case NSPeriodic:
					break;
					
				default:
					break;
				}
				mouseLocPre = mouseLoc;
			}while (keepOn);
			*/
			
//			if (volumeMapper) volumeMapper->SetMinimumImageSampleDistance( LOD);
//			if (textureMapper) textureMapper->SetMaximumNumberOfPlanes( (int) (512 / LOD));
			
			[self setNeedsDisplay:YES];
		}
		else if (tool == t3Dpoint)
		{
			NSEvent *artificialPKeyDown = [NSEvent keyEventWithType: NSKeyDown
                                                           location: [theEvent locationInWindow]
                                                      modifierFlags: 0
                                                          timestamp: [theEvent timestamp]
                                                       windowNumber: [theEvent windowNumber]
                                                            context: [theEvent context]
                                                         characters: @"p"
                                        charactersIgnoringModifiers: @""
                                                          isARepeat: NO
                                                            keyCode: 112];
			[self keyDown:artificialPKeyDown];
			
			if (![self isAny3DPointSelected])
			{
				// add a point on the surface under the mouse click
				[self throw3DPointOnSurface: mouseLocStart.x : mouseLocStart.y];
				[self setNeedsDisplay:YES];
			}
			else
			{
				[point3DRadiusSlider setFloatValue: [[point3DRadiusArray objectAtIndex:[self selected3DPointIndex]] floatValue]];
				[point3DColorWell setColor: [point3DColorsArray objectAtIndex:[self selected3DPointIndex]]];
                [point3DPositionTextField setStringValue:[point3DPositionsStringsArray objectAtIndex:[self selected3DPointIndex]]];
				//point3DDisplayPositionArray
				[point3DDisplayPositionButton setState:[[point3DDisplayPositionArray objectAtIndex:[self selected3DPointIndex]] intValue]];
				[point3DTextSizeSlider setFloatValue: [[point3DTextSizesArray objectAtIndex:[self selected3DPointIndex]] floatValue]];
				[point3DTextColorWell setColor: [point3DTextColorsArray objectAtIndex:[self selected3DPointIndex]]];

                if ([theEvent clickCount]==2)
				{
					NSPoint mouseLocationOnScreen = [[controller window] convertBaseToScreen:[theEvent locationInWindow]];
					//[point3DInfoPanel setAlphaValue:0.8];
					[point3DInfoPanel setFrame:	NSMakeRect(	mouseLocationOnScreen.x - [point3DInfoPanel frame].size.width/2.0,
                                                            mouseLocationOnScreen.y - [point3DInfoPanel frame].size.height-20.0,
                                                            [point3DInfoPanel frame].size.width,
                                                            [point3DInfoPanel frame].size.height)
										display:YES animate: NO];
					[point3DInfoPanel orderFront:self];
				}
			}
		}
		else if (_tool == tWL) {
			NSLog(@"WL do nothing");
		}
		else
            [super mouseDown:theEvent];
		
	//	croppingBox->SetHandleSize( 0.005);
	}

	noWaitDialog = NO;
}

- (void) keyDown:(NSEvent *)event
{
    if ([[event characters] length] == 0)
        return;
    
    unichar c = [[event characters] characterAtIndex:0];
	
	if (c == ' ')
	{
		if (aRenderer->GetActors()->IsItemPresent( outlineRect))
			aRenderer->RemoveActor( outlineRect);
		else
			aRenderer->AddActor( outlineRect);
			
		[self setNeedsDisplay: YES];
	}
	else if (c == 27)
	{
		[[[self window] windowController] offFullScreen];
	}
	else if (c == NSDeleteFunctionKey || c == NSDeleteCharacter || c == NSBackspaceCharacter || c == NSDeleteCharFunctionKey)
	{
		if ([self isAny3DPointSelected])
			[self removeSelected3DPoint];
		else
            [self yaw:-90.0];
	}
	else
        [super keyDown:event];
}

-(void) setCurrentTool:(ToolMode) i
{
	if (currentTool==t3Dpoint && currentTool!=i)
	{
		[self unselectAllActors];
        
		if ([point3DInfoPanel isVisible])
            [point3DInfoPanel performClose:self];
        
		[self setNeedsDisplay:YES];
	}
	
    currentTool = i;
	
	if (currentTool != t3DRotate)
	{
		//if (croppingBox->GetEnabled()) croppingBox->Off();
	}
	
	[self setCursorForView: currentTool];
}

-(void) setBlendingFactor:(float) a
{
	float val, ii;
	double alpha[ 256];
	
	blendingFactor = a;
	
	if (a <= 0)
	{
		a += 256;
		
		for (long i=0; i < 256; i++)
		{
			ii = i;
			val = (a * ii) / 256.;
			
			if (val > 255) val = 255;
			if (val < 0) val = 0;
			
			alpha[ i] = val / 255.;
		}
	}
	else
	{
		if (a == 256)
		{
			for (long i=0; i < 256; i++)
				alpha[ i] = 1.0;
		}
		else
		{
			for (long i=0; i < 256; i++)
			{
				ii = i;
				val = (256. * ii)/(256 - a);
				
				if (val > 255) val = 255;
				if (val < 0) val = 0;
				
				alpha[ i] = val / 255.0;
			}
		}
	}
		
	[self setNeedsDisplay: YES];
}

-(void) axView:(id) sender
{
	float distance = aCamera->GetDistance();

	aCamera->SetFocalPoint (0, 0, 0);
	aCamera->SetPosition (0, 0, -1);
	aCamera->ComputeViewPlaneNormal();
	aCamera->SetViewUp(0, -1, 0);
	aCamera->OrthogonalizeViewUp();
	aRenderer->ResetCamera();

	// Apply the same zoom
	
	double vn[ 3], center[ 3];
	aCamera->GetFocalPoint(center);
	aCamera->GetViewPlaneNormal(vn);
	aCamera->SetPosition(center[0]+distance*vn[0],
                         center[1]+distance*vn[1],
                         center[2]+distance*vn[2]);
//	aCamera->SetParallelScale( pp);
	aRenderer->ResetCameraClippingRange();	
	[self setNeedsDisplay:YES];
}

-(void) saView:(id) sender
{
	float distance = aCamera->GetDistance();

	aCamera->SetFocalPoint (0, 0, 0);
	aCamera->SetPosition (1, 0, 0);
	aCamera->ComputeViewPlaneNormal();
	aCamera->SetViewUp(0, 0, 1);
	aCamera->OrthogonalizeViewUp();
	aCamera->Dolly(1.5);
	aRenderer->ResetCamera();

	// Apply the same zoom
	
	double vn[ 3], center[ 3];
	aCamera->GetFocalPoint(center);
	aCamera->GetViewPlaneNormal(vn);
	aCamera->SetPosition(center[0]+distance*vn[0],
                         center[1]+distance*vn[1],
                         center[2]+distance*vn[2]);
//	aCamera->SetParallelScale( pp);
	aRenderer->ResetCameraClippingRange();	
	[self setNeedsDisplay:YES];
}

-(void) saViewOpposite:(id) sender
{
	float distance = aCamera->GetDistance();

	aCamera->SetFocalPoint (0, 0, 0);
	aCamera->SetPosition (-1, 0, 0);
	aCamera->ComputeViewPlaneNormal();
	aCamera->SetViewUp(0, 0, 1);
	aCamera->OrthogonalizeViewUp();
	aCamera->Dolly(1.5);
	aRenderer->ResetCamera();

	// Apply the same zoom
	
	double vn[ 3], center[ 3];
	aCamera->GetFocalPoint(center);
	aCamera->GetViewPlaneNormal(vn);
	aCamera->SetPosition(center[0]+distance*vn[0],
                         center[1]+distance*vn[1],
                         center[2]+distance*vn[2]);
//	aCamera->SetParallelScale( pp);
	aRenderer->ResetCameraClippingRange();
	
	[self setNeedsDisplay:YES];
}

-(void) coView:(id) sender
{
	float distance = aCamera->GetDistance();
//	float pp = aCamera->GetParallelScale();

	aCamera->SetFocalPoint (0, 0, 0);
	aCamera->SetPosition (0, -1, 0);
	aCamera->ComputeViewPlaneNormal();
	aCamera->SetViewUp(0, 0, 1);
	aCamera->OrthogonalizeViewUp();
	aRenderer->ResetCamera();

	// Apply the same zoom
	
	double vn[ 3], center[ 3];
	aCamera->GetFocalPoint(center);
	aCamera->GetViewPlaneNormal(vn);
	aCamera->SetPosition(center[0]+distance*vn[0],
                         center[1]+distance*vn[1],
                         center[2]+distance*vn[2]);
//	aCamera->SetParallelScale( pp);
	aRenderer->ResetCameraClippingRange();
	
	[self setNeedsDisplay:YES];
}


-(void) setBlendingPixSource:(ViewerController*) bC
{	
	blendingController = bC;
	
	if (blendingController)
	{
		blendingPixList = [bC pixList];
		[blendingPixList retain];
		
		blendingData = [bC volumePtr];
		
		blendingFirstObject = [blendingPixList objectAtIndex:0];
		blendingLastObject = [blendingPixList lastObject];
		
		float blendingSliceThickness = ([blendingFirstObject sliceInterval]);
		
		if (blendingSliceThickness == 0)
		{
			NSLog(@"Blending slice interval = slice thickness!");
			blendingSliceThickness = [blendingFirstObject sliceThickness];
		}
//		NSLog(@"slice: %0.2f", blendingSliceThickness);
		
		// PLAN 
		[blendingFirstObject orientation:blendingcosines];
				
		blendingReader = vtkImageImport::New();
		blendingReader->SetWholeExtent(0, [blendingFirstObject pwidth]-1,
                                       0, [blendingFirstObject pheight]-1,
                                       0, (long)[blendingPixList count]-1);
		blendingReader->SetDataExtentToWholeExtent();
		blendingReader->SetDataScalarTypeToFloat();
//		blendingReader->SetDataOrigin(  [blendingFirstObject originX],
//										[blendingFirstObject originY],
//										[blendingFirstObject originZ]);
		blendingReader->SetImportVoidPointer(blendingData);
		blendingReader->SetDataSpacing( [blendingFirstObject pixelSpacingX], [blendingFirstObject pixelSpacingY], fabs( blendingSliceThickness));
		
		blendingReader->Update();
        
		if (blendingSliceThickness < 0 )
		{
			blendingFlip = vtkImageFlip::New();
			blendingFlip->SetInputConnection( blendingReader->GetOutputPort());
			blendingFlip->SetFlipAboutOrigin( TRUE);
			blendingFlip->SetFilteredAxis(2);
			blendingFlip->Update();
		}
		else
            blendingFlip = nil;
		
		matriceBlending = vtkMatrix4x4::New();
		matriceBlending->Element[0][0] = blendingcosines[0];
        matriceBlending->Element[1][0] = blendingcosines[1];
        matriceBlending->Element[2][0] = blendingcosines[2];
        matriceBlending->Element[3][0] = 0;
        
		matriceBlending->Element[0][1] = blendingcosines[3];
        matriceBlending->Element[1][1] = blendingcosines[4];
        matriceBlending->Element[2][1] = blendingcosines[5];
        matriceBlending->Element[3][1] = 0;
        
		matriceBlending->Element[0][2] = blendingcosines[6];
        matriceBlending->Element[1][2] = blendingcosines[7];
        matriceBlending->Element[2][2] = blendingcosines[8];
        matriceBlending->Element[3][2] = 0;

		matriceBlending->Element[0][3] = 0;
        matriceBlending->Element[1][3] = 0;
		matriceBlending->Element[2][3] = 0;
        matriceBlending->Element[3][3] = 1;
	}
	else
	{
		if (blendingReader)
		{
			matriceBlending->Delete();
			if (blendingFlip)
                blendingFlip->Delete();
            
			blendingReader->Delete();
			blendingReader = nil;
			[blendingPixList release];
		}
	}
}

- (void) drawRect:(NSRect)aRect
{
	try
	{
		[self computeOrientationText];
		[super drawRect:aRect];
	}
	
	catch (...)
	{
		NSLog( @"Exception during drawRect... not enough memory?");
        NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
		if (NSRunAlertPanel2(@"", //NSLocalizedString(@"32-bit",nil),
                            NSLocalizedString(@"Cannot use the 3D engine.",nil),
                            NSLocalizedString(@"OK", nil),
                            bundleName,
                            nil) == NSAlertAlternateReturn2)
        {
			//[[AppController sharedAppController] osirix64bit: self];
        }
		
		[[self window] performSelector:@selector(performClose:) withObject:self afterDelay: 1.0];
	}
}

- (void) deleteActor:(long) actor
{
	if (isoExtractor[ actor])
	{
        if (iso[ actor])
            aRenderer->RemoveActor( iso[ actor]);
        
		if (isoExtractor[ actor])
            isoExtractor[ actor]->Delete();
        isoExtractor[ actor] = nil;
        
        if (isoNormals[ actor])
            isoNormals[ actor]->Delete();
		isoNormals[ actor] = nil;
        
        if (isoMapper[ actor])
            isoMapper[ actor]->Delete();
		isoMapper[ actor] = nil;
        
        if (iso[ actor])
            iso[ actor]->Delete();
		iso[ actor] = nil;
        
		if (isoSmoother[ actor])
            isoSmoother[ actor]->Delete();
		isoSmoother[ actor] = nil;
		
		if (isoDeci[ actor])
            isoDeci[ actor]->Delete();
		isoDeci[ actor] = nil;
	}
	
	isoExtractor[ actor] = nil;
}

- (void) BdeleteActor:(long) actor
{
	if (BisoExtractor[ actor])
	{
		aRenderer->RemoveActor( Biso[ actor]);
		
		if (BisoExtractor[ actor])
            BisoExtractor[ actor]->Delete();
        BisoExtractor[ actor] = nil;
        
		if (BisoNormals[ actor])
            BisoNormals[ actor]->Delete();
        BisoNormals[ actor] = nil;
        
		if (BisoMapper[ actor])
            BisoMapper[ actor]->Delete();
		BisoMapper[ actor] = nil;
        
        if (Biso[ actor])
            Biso[ actor]->Delete();
        Biso[ actor] = nil;
        
		if (BisoSmoother[ actor])
            BisoSmoother[ actor]->Delete();
		BisoSmoother[ actor] = nil;
		
		if (BisoDeci[ actor])
            BisoDeci[ actor]->Delete();
		BisoDeci[ actor] = nil;
	}
	
	BisoExtractor[ actor] = nil;
}

- (void) changeActor:(long) actor
                    :(float) resolution
                    :(float) transparency
                    :(float) r
                    :(float) g
                    :(float) b
                    :(float) isocontour
                    :(BOOL) useDecimate
                    :(float) decimateVal
                    :(BOOL) useSmooth
                    :(long) smoothVal
{
//	[splash setCancel:YES];
	
	try
	{
	//NSLog(@"ChangeActor IN");
		
	// RESAMPLE IMAGE ?
	
	if (resolution == 1.0)
	{
		if (isoResample)
            isoResample->Delete();
        
		isoResample = nil;
	}
	else
	{
		if (isoResample)
		{
			if (isoResample->GetAxisMagnificationFactor( 0) != resolution)
			{
				isoResample->SetAxisMagnificationFactor(0, resolution);
				isoResample->SetAxisMagnificationFactor(1, resolution);
			}
		}
		else
		{
			isoResample = vtkImageResample::New();
			if (flip)
				isoResample->SetInputConnection( flip->GetOutputPort());
			else
				isoResample->SetInputConnection( reader->GetOutputPort());
            
			isoResample->SetAxisMagnificationFactor(0, resolution);
			isoResample->SetAxisMagnificationFactor(1, resolution);
			isoResample->Update();
		}
	}
	
	[self deleteActor: actor];
	
	if (isoResample)
	{
		isoExtractor[ actor] = vtkContourFilter::New();
		isoExtractor[ actor]->SetInputConnection( isoResample->GetOutputPort());
		isoExtractor[ actor]->SetValue(0, isocontour);
	}
	else
	{
		isoExtractor[ actor] = vtkContourFilter::New();
		if (flip)
			isoExtractor[ actor]->SetInputConnection( flip->GetOutputPort());
		else
			isoExtractor[ actor]->SetInputConnection( reader->GetOutputPort());
        
		isoExtractor[ actor]->SetValue(0, isocontour);
	}
        
	isoExtractor[ actor]->Update();
	
	vtkPolyData* previousOutput = isoExtractor[ actor]->GetOutput();
	
	if (useDecimate)
	{
		isoDeci[ actor] = vtkDecimatePro::New();
		isoDeci[ actor]->SetInputData( previousOutput);
		isoDeci[ actor]->SetTargetReduction(decimateVal);
		isoDeci[ actor]->SetPreserveTopology( TRUE);
		
//		isoDeci[ actor]->SetFeatureAngle(60);
//		isoDeci[ actor]->SplittingOff();
//		isoDeci[ actor]->AccumulateErrorOn();
//		isoDeci[ actor]->SetMaximumError(0.3);
		
		isoDeci[ actor]->Update();
		previousOutput = isoDeci[ actor]->GetOutput();		
		//NSLog(@"Use Decimate : %f", decimateVal);
	}
	
	if (useSmooth)
	{
		isoSmoother[ actor] = vtkSmoothPolyDataFilter::New();
		isoSmoother[ actor]->SetInputData( previousOutput);
		isoSmoother[ actor]->SetNumberOfIterations( smoothVal);
//		isoSmoother[ actor]->SetRelaxationFactor(0.05);
		
		isoSmoother[ actor]->Update();
		previousOutput = isoSmoother[ actor]->GetOutput();
		//NSLog(@"Use Smooth: %d", (int) smoothVal);
	}

	isoNormals[ actor] = vtkPolyDataNormals::New();
    isoNormals[ actor]->SetInputData( previousOutput);
    isoNormals[ actor]->SetFeatureAngle(120);
	
	isoMapper[ actor] = vtkPolyDataMapper::New();
    isoMapper[ actor]->SetInputConnection( isoNormals[ actor]->GetOutputPort());
    isoMapper[ actor]->ScalarVisibilityOff();
	
//	isoMapper[ actor]->GlobalImmediateModeRenderingOff();
//	isoMapper[ actor]->SetResolveCoincidentTopologyToPolygonOffset();
//	isoMapper[ actor]->SetResolveCoincidentTopologyToShiftZBuffer();
//	isoMapper[ actor]->SetResolveCoincidentTopologyToOff();
	
	isoMapper[ actor]->Update();
        
	iso[ actor] = vtkActor::New();
    iso[ actor]->SetMapper( isoMapper[ actor]);
    iso[ actor]->GetProperty()->SetDiffuseColor( r, g, b);
    iso[ actor]->GetProperty()->SetSpecular( .3);
    iso[ actor]->GetProperty()->SetSpecularPower( 20);
    iso[ actor]->GetProperty()->SetOpacity( transparency);
	
	iso[ actor]->SetOrigin( [firstObject originX], [firstObject originY], [firstObject originZ]);
        
	iso[ actor]->SetPosition([firstObject originX] * matrice->Element[0][0] +
                             [firstObject originY] * matrice->Element[1][0] +
                             [firstObject originZ] * matrice->Element[2][0],
                             
							 [firstObject originX] * matrice->Element[0][1] +
                             [firstObject originY] * matrice->Element[1][1] +
                             [firstObject originZ] * matrice->Element[2][1],
                             
							 [firstObject originX] * matrice->Element[0][2] +
                             [firstObject originY] * matrice->Element[1][2] +
                             [firstObject originZ] * matrice->Element[2][2]);
        
	iso[ actor]->SetUserMatrix( matrice);
 	iso[ actor]->PickableOff();

    aRenderer->AddActor( iso[ actor]);
    [self setNeedsDisplay:YES];
	
	//NSLog(@"ChangeActor OUT");
	}
	catch (...)
	{
        NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
		if (NSRunAlertPanel2(@"", //NSLocalizedString(@"32-bit",nil),
                            NSLocalizedString(@"Cannot use the 3D engine.",nil),
                            NSLocalizedString(@"OK", nil),
                            bundleName,
                            nil) == NSAlertAlternateReturn2)
        {
			//[[AppController sharedAppController] osirix64bit: self];
        }
	}
}

- (void) BchangeActor:(long) actor
                     :(float) resolution
                     :(float) transparency
                     :(float) r
                     :(float) g
                     :(float) b
                     :(float) isocontour
                     :(BOOL) useDecimate
                     :(float) decimateVal
                     :(BOOL) useSmooth
                     :(long) smoothVal
{
	//NSLog(@"BLENDING ChangeActor IN");
//	[splash setCancel:YES];
	
	// RESAMPLE IMAGE ?
	
	if (resolution == 1.0)
	{
		if (BisoResample)
            BisoResample->Delete();
		
		BisoResample = nil;
	}
	else
	{
		if (BisoResample)
		{
			if (BisoResample->GetAxisMagnificationFactor( 0) != resolution)
			{
				BisoResample->SetAxisMagnificationFactor(0, resolution);
				BisoResample->SetAxisMagnificationFactor(1, resolution);
			}
		}
		else
		{
			BisoResample = vtkImageResample::New();
			if (blendingFlip)
                BisoResample->SetInputConnection( blendingFlip->GetOutputPort());
			else
                BisoResample->SetInputConnection( blendingReader->GetOutputPort());
            
			BisoResample->SetAxisMagnificationFactor(0, resolution);
			BisoResample->SetAxisMagnificationFactor(1, resolution);
			BisoResample->Update();
		}
	}
	
	[self BdeleteActor: actor];
	
	if (BisoResample)
	{
		BisoExtractor[ actor] = vtkContourFilter::New();
		BisoExtractor[ actor]->SetInputConnection( BisoResample->GetOutputPort());
		BisoExtractor[ actor]->SetValue(0, isocontour);
	}
	else
	{
		BisoExtractor[ actor] = vtkContourFilter::New();
		if (blendingFlip)
            BisoExtractor[ actor]->SetInputConnection( blendingFlip->GetOutputPort());
		else
            BisoExtractor[ actor]->SetInputConnection( blendingReader->GetOutputPort());
        
		BisoExtractor[ actor]->SetValue(0, isocontour);
	}
    
	BisoExtractor[ actor]->Update();
	
	vtkPolyData* previousOutput = BisoExtractor[ actor]->GetOutput();
	
	if (useDecimate)
	{
		BisoDeci[ actor] = vtkDecimatePro::New();
		BisoDeci[ actor]->SetInputData( previousOutput);
		BisoDeci[ actor]->SetTargetReduction(decimateVal);
		BisoDeci[ actor]->SetPreserveTopology( TRUE);
	
		BisoDeci[ actor]->Update();
		previousOutput = BisoDeci[ actor]->GetOutput();
		//NSLog(@"Use Decimate");
	}
	
	if (useSmooth)
	{
		BisoSmoother[ actor] = vtkSmoothPolyDataFilter::New();
		BisoSmoother[ actor]->SetInputConnection( BisoDeci[ actor]->GetOutputPort());
		BisoSmoother[ actor]->SetNumberOfIterations( smoothVal);
		
		BisoSmoother[ actor]->Update();
		previousOutput = BisoSmoother[ actor]->GetOutput();
		//NSLog(@"Use Smooth");
	}
	
	BisoNormals[ actor] = vtkPolyDataNormals::New();
	BisoNormals[ actor]->SetInputData( previousOutput); // set skinSmooth as new Input
	BisoNormals[ actor]->SetFeatureAngle(120);
	
	BisoMapper[ actor] = vtkPolyDataMapper::New();
    BisoMapper[ actor]->SetInputConnection( BisoNormals[ actor]->GetOutputPort());
    BisoMapper[ actor]->ScalarVisibilityOff();
    
    BisoMapper[ actor]->Update();
	
	Biso[ actor] = vtkActor::New();
    Biso[ actor]->SetMapper( BisoMapper[ actor]);
    Biso[ actor]->GetProperty()->SetDiffuseColor( r, g, b);
    Biso[ actor]->GetProperty()->SetSpecular( .3);
    Biso[ actor]->GetProperty()->SetSpecularPower( 20);
    Biso[ actor]->GetProperty()->SetOpacity( transparency);
	
	Biso[ actor]->SetOrigin( [blendingFirstObject originX], [blendingFirstObject originY], [blendingFirstObject originZ]);
	
	Biso[ actor]->SetPosition([blendingFirstObject originX] * matriceBlending->Element[0][0] +
                              [blendingFirstObject originY] * matriceBlending->Element[1][0] +
                              [blendingFirstObject originZ] * matriceBlending->Element[2][0],
                              
                              [blendingFirstObject originX] * matriceBlending->Element[0][1] +
                              [blendingFirstObject originY] * matriceBlending->Element[1][1] +
                              [blendingFirstObject originZ] * matriceBlending->Element[2][1],
                              
                              [blendingFirstObject originX] * matriceBlending->Element[0][2] +
                              [blendingFirstObject originY] * matriceBlending->Element[1][2] +
                              [blendingFirstObject originZ] * matriceBlending->Element[2][2]);
    
	Biso[ actor]->SetUserMatrix( matriceBlending);
    aRenderer->AddActor( Biso[ actor]);
	[self setNeedsDisplay:YES];
	//NSLog(@"BLENDING ChangeActor OUT");
}

// Return error flag: FALSE on success, TRUE on failure
- (BOOL) setPixSource:(NSMutableArray*)pix :(float*) volumeData
{
	try
	{
		[pix retain];
		pixList = pix;
		projectionMode = 0;
		data = volumeData;
		aRenderer = [self renderer];
	//	cbStart = vtkCallbackCommand::New();
	//	cbStart->SetCallback( startRendering);
	//	cbStart->SetClientData( self);
		
	//	[self renderWindow]->AddObserver(vtkCommand::StartEvent, cbStart);
	//	[self renderWindow]->AddObserver(vtkCommand::EndEvent, cbStart);
	//	[self renderWindow]->AddObserver(vtkCommand::AbortCheckEvent, cbStart);
		
	//	aRenderer->AddObserver(vtkCommand::StartEvent, cbStart);
	//	aRenderer->AddObserver(vtkCommand::EndEvent, cbStart);

		firstObject = [pixList objectAtIndex:0];
		float sliceThickness = [firstObject sliceInterval]; //[[pixList objectAtIndex:1] sliceLocation] - [firstObject sliceLocation];
		
		if (sliceThickness == 0)
		{
			NSLog(@"slice interval = slice thickness!");
			sliceThickness = [firstObject sliceThickness];
		}
		
		NSLog(@"sliceThickness: %2.2f", sliceThickness);
		
		// Convert float to char
		
		if ([firstObject isRGB])
		{
			// Convert RGB to BW... We could add support for RGB later if needed by users....

			long size = [firstObject pheight] * [pix count];
			size *= [firstObject pwidth];
			size *= sizeof( float);
			
			dataFRGB = (float *)malloc(size);
			if (!dataFRGB) {
                NSLog( @"***** not enough memory error dataFRGB = nil");
                return TRUE;  // error
            }

            size /= 4;
            unsigned char *srcPtr = (unsigned char*) data;
            float *dstPtr = dataFRGB;
            long val;
            for (long i=0; i < size; i++)
            {
                srcPtr++;
                val = *srcPtr++;
                val += *srcPtr++;
                val += *srcPtr++;
                *dstPtr++ = val/3;
            }
            
            data = dataFRGB;
		}
		
		reader = vtkImageImport::New();
		reader->SetWholeExtent(0, [firstObject pwidth]-1, 0, [firstObject pheight]-1, 0, (long)[pixList count]-1);
		reader->SetDataExtentToWholeExtent();
		reader->SetDataScalarTypeToFloat();
		reader->SetImportVoidPointer(data);
	//	reader->SetDataOrigin(  [firstObject originX],
	//							[firstObject originY],
	//							[firstObject originZ]);
		reader->SetDataSpacing( [firstObject pixelSpacingX], [firstObject pixelSpacingY], fabs( sliceThickness)); 

		if (sliceThickness < 0 )
		{
			flip = vtkImageFlip::New();
			flip->SetInputConnection( reader->GetOutputPort());
			flip->SetFlipAboutOrigin( TRUE);
			flip->SetFilteredAxis(2);
			flip->Update();
		}
		else
            flip = nil;
			
		// PLANE
		
		[firstObject orientation:cosines];
		
		matrice = vtkMatrix4x4::New();
		matrice->Element[0][0] = cosines[0];
        matrice->Element[1][0] = cosines[1];
        matrice->Element[2][0] = cosines[2];
        matrice->Element[3][0] = 0;
        
		matrice->Element[0][1] = cosines[3];
        matrice->Element[1][1] = cosines[4];
        matrice->Element[2][1] = cosines[5];
        matrice->Element[3][1] = 0;
        
		matrice->Element[0][2] = cosines[6];
        matrice->Element[1][2] = cosines[7];
        matrice->Element[2][2] = cosines[8];
        matrice->Element[3][2] = 0;
        
		matrice->Element[0][3] = 0;
        matrice->Element[1][3] = 0;
        matrice->Element[2][3] = 0;
        matrice->Element[3][3] = 1;
		
		outlineData = vtkOutlineFilter::New();
		if (flip)
            outlineData->SetInputConnection(flip->GetOutputPort());
		else
            outlineData->SetInputConnection(reader->GetOutputPort());

        outlineData->Update();
		mapOutline = vtkPolyDataMapper::New();
		mapOutline->SetInputConnection(outlineData->GetOutputPort());
		mapOutline->Update();
		outlineRect = vtkActor::New();
		outlineRect->SetMapper(mapOutline);
		outlineRect->GetProperty()->SetColor(0,1,0);
		outlineRect->GetProperty()->SetOpacity(0.5);
		outlineRect->SetUserMatrix( matrice);
		outlineRect->SetOrigin( [firstObject originX], [firstObject originY], [firstObject originZ]);

        outlineRect->SetPosition([firstObject originX] * matrice->Element[0][0] +
                                 [firstObject originY] * matrice->Element[1][0] +
                                 [firstObject originZ] * matrice->Element[2][0],
                                 
                                 [firstObject originX] * matrice->Element[0][1] +
                                 [firstObject originY] * matrice->Element[1][1] +
                                 [firstObject originZ] * matrice->Element[2][1],
                                 
                                 [firstObject originX] * matrice->Element[0][2] +
                                 [firstObject originY] * matrice->Element[1][2] +
                                 [firstObject originZ] * matrice->Element[2][2]);

        outlineRect->PickableOff();
		
//		if ([[NSUserDefaults standardUserDefaults] boolForKey: @"dontShow3DCubeOrientation"] == NO)
		{
			vtkAnnotatedCubeActor* cube = vtkAnnotatedCubeActor::New();
			cube->SetXPlusFaceText ( [NSLocalizedString( @"L", @"L: Left") UTF8String] );		
			cube->SetXMinusFaceText( [NSLocalizedString( @"R", @"R: Right") UTF8String] );
			cube->SetYPlusFaceText ( [NSLocalizedString( @"P", @"P: Posterior") UTF8String] );
			cube->SetYMinusFaceText( [NSLocalizedString( @"A", @"A: Anterior") UTF8String] );
			cube->SetZPlusFaceText ( [NSLocalizedString( @"S", @"S: Superior") UTF8String] );
			cube->SetZMinusFaceText( [NSLocalizedString( @"I", @"I: Inferior") UTF8String] );
			cube->SetFaceTextScale( 0.67 );

			vtkProperty* property = cube->GetXPlusFaceProperty();
			property->SetColor(0, 0, 1);
			property = cube->GetXMinusFaceProperty();
			property->SetColor(0, 0, 1);
			property = cube->GetYPlusFaceProperty();
			property->SetColor(0, 1, 0);
			property = cube->GetYMinusFaceProperty();
			property->SetColor(0, 1, 0);
			property = cube->GetZPlusFaceProperty();
			property->SetColor(1, 0, 0);
			property = cube->GetZMinusFaceProperty();
			property->SetColor(1, 0, 0);

			cube->SetTextEdgesVisibility( 1);
			cube->SetCubeVisibility( 1);
			cube->SetFaceTextVisibility( 1);

			orientationWidget = vtkOrientationMarkerWidget::New();
			orientationWidget->SetOrientationMarker( cube );
			orientationWidget->SetInteractor( [self getInteractor] );
			orientationWidget->SetViewport( 0.90, 0.90, 1, 1);
			orientationWidget->SetEnabled( 1 );
			orientationWidget->InteractiveOff();
			cube->Delete();
		}

	//	croppingBox = vtkBoxWidget::New();
	//	croppingBox->GetHandleProperty()->SetColor(0, 1, 0);
	//	
	//	croppingBox->SetProp3D(skin);
	//	croppingBox->SetPlaceFactor( 1.0);
	//	croppingBox->SetHandleSize( 0.005);
	//	croppingBox->PlaceWidget();
	//    croppingBox->SetInteractor( [self renderWindowInteractor]);
	//	croppingBox->SetInsideOut( true);
	//	croppingBox->OutlineCursorWiresOff();
	//	cropcallback = vtkMyCallback::New();
	//	cropcallback->setBlendingVolume( nil);
	//	croppingBox->AddObserver(vtkCommand::InteractionEvent, cropcallback);
		
	/*	planeWidget = vtkPlaneWidget::New();
		
		planeWidget->GetHandleProperty()->SetColor(0, 0, 1);
		planeWidget->SetHandleSize( 0.005);
		planeWidget->SetProp3D(volume);
		planeWidget->SetResolution( 1);
		planeWidget->SetPoint1(-50, -50, -50);
		planeWidget->SetPoint2(50, 50, 50);
		planeWidget->PlaceWidget();
		planeWidget->SetRepresentationToWireframe();
		planeWidget->SetInteractor( [self renderWindowInteractor]);
		planeWidget->On();
		vtkPlaneCallback *planecallback = vtkPlaneCallback::New();
		planeWidget->AddObserver(vtkCommand::InteractionEvent, planecallback);
	*/	
		textX = vtkTextActor::New();
		textX->SetInput( "X");
		textX->SetTextScaleModeToNone();
		textX->GetPositionCoordinate()->SetCoordinateSystemToViewport();
		textX->GetPositionCoordinate()->SetValue( 2., 2.);
		aRenderer->AddActor2D(textX);
		
		for (long i = 0; i < NUM_SR_LABELS; i++)
		{
			oText[ i]= vtkTextActor::New();
			oText[ i]->SetInput( "X");
			oText[ i]->SetTextScaleModeToNone();
			oText[ i]->GetPositionCoordinate()->SetCoordinateSystemToNormalizedViewport();
			oText[ i]->GetTextProperty()->SetFontSize( 16);
			oText[ i]->GetTextProperty()->SetBold( true);
			oText[ i]->GetTextProperty()->SetShadow( true);
			oText[ i]->GetTextProperty()->SetShadowOffset(1, 1);
			
			aRenderer->AddActor2D( oText[ i]);
		}
        
		oText[ 0]->GetPositionCoordinate()->SetValue( 0.01, 0.5);
		oText[ 1]->GetPositionCoordinate()->SetValue( 0.99, 0.5);
		oText[ 1]->GetTextProperty()->SetJustificationToRight();
		
		oText[ 2]->GetPositionCoordinate()->SetValue( 0.5, 0.03);
		oText[ 2]->GetTextProperty()->SetVerticalJustificationToTop();
		oText[ 3]->GetPositionCoordinate()->SetValue( 0.5, 0.97);
		aCamera = vtkCamera::New();
		aCamera->SetViewUp (0, 1, 0);
		aCamera->SetFocalPoint (0, 0, 0);
		aCamera->SetPosition (0, 0, 1);
		aCamera->SetRoll(180);

	//    aCamera->ComputeViewPlaneNormal();    
		
		aCamera->Dolly(1.5);
		aRenderer->AddActor( outlineRect);
		aRenderer->SetActiveCamera(aCamera);
		aCamera->SetFocalPoint (0, 0, 0);
		aCamera->SetPosition (1, 0, 0);
		aCamera->ComputeViewPlaneNormal();
		aCamera->SetViewUp(0, 0, 1);
		aCamera->OrthogonalizeViewUp();
		aCamera->Dolly(1.5);
		aRenderer->ResetCamera();

		[self saView:self];

		GLint swap = 1;  // LIMIT SPEED TO VBL if swap == 1
		[self getVTKRenderWindow]->MakeCurrent();
		[[NSOpenGLContext currentContext] setValues:&swap forParameter:NSOpenGLCPSwapInterval];

		[self setNeedsDisplay:YES];
        
        if ([[[[NSUserDefaults standardUserDefaults] persistentDomainForName: @"com.apple.CoreGraphics"] objectForKey: @"DisplayUseInvertedPolarity"] boolValue])
            aRenderer->SetBackground( 1, 1, 1);		
	}
	catch (...)
	{
		NSLog(@"setPixSource C++ exception SRView.mm");
		return TRUE;  // error
	}

    return FALSE;  // ok
}

-(void) switchOrientationWidget:(id) sender
{
	if (orientationWidget)
	{
		if (orientationWidget->GetEnabled())
		{
			orientationWidget->Off();
			for (long i = 0; i < NUM_SR_LABELS; i++)
                aRenderer->RemoveActor2D( oText[ i]);
		}
		else if ([self renderWindow]->GetStereoRender() == false)
		{
			orientationWidget->On();
			for (long i = 0; i < NUM_SR_LABELS; i++)
                aRenderer->AddActor2D( oText[ i]);
		}
	}
    
    if (outlineRect) // discussion #140
    {
        static int outlineRectSM = 0;
        switch (outlineRectSM)
        {
            case 0:
                outlineRect->VisibilityOn();
                break;
            case 1:
                break;
            case 2:
                outlineRect->VisibilityOff();
                break;
            case 3:
                break;
        }

        outlineRectSM++;
        if (outlineRectSM > 3)
            outlineRectSM = 0;
    }
	
	[self setNeedsDisplay:YES];
}

-(IBAction) switchProjection:(id) sender
{
	//NSLog(@"switchProjection");
	projectionMode = [[sender selectedCell] tag];
	
	switch (projectionMode)
	{
		case 0: // perspective
			aCamera->SetParallelProjection( false);
			aCamera->SetViewAngle( 30);
		break;
		
		case 2: // endoscopy
			aCamera->SetParallelProjection( false);
			aCamera->SetViewAngle( 60);
		break;
		
		case 1: // parallel
			aCamera->SetParallelProjection( true);
			aCamera->SetViewAngle( 30);
		break;
	}
//	
//	if (aCamera->GetParallelProjection())
//	{
//		[[[[[self window] windowController] toolsMatrix] cellWithTag: tMeasure] setEnabled: YES];
//	}
//	else
//	{
//		[[[[[self window] windowController] toolsMatrix] cellWithTag: tMeasure] setEnabled: NO];
//		
//		if (currentTool == tMeasure)
//		{
//			[self setCurrentTool: t3DRotate];
//			[[[[self window] windowController] toolsMatrix] selectCellWithTag: t3DRotate];
//		}
//	}	
	[self setNeedsDisplay:YES];
}

-(NSImage*) nsimageQuicktime
{
	NSImage *theIm;
	BOOL wasPresent = NO;
	
	if (aRenderer->GetActors()->IsItemPresent( outlineRect))
	{
		aRenderer->RemoveActor( outlineRect);
		wasPresent = YES;
	}
	
	[self display];
	
	theIm = [self nsimage:YES];
	
	if (wasPresent)
		aRenderer->AddActor(outlineRect);
	
	return theIm;
}

-(unsigned char*) getRawPixels:(long*) width :(long*) height :(long*) spp :(long*) bpp :(BOOL) screenCapture :(BOOL) force8bits
{
	unsigned char	*buf = nil;
	long			i;
	
//	if (screenCapture)	// Pixels displayed in current window -> only RGB 8 bits data
	{
		NSRect size = [self bounds];
		
		*width = (long) size.size.width;
		*width/=4;
		*width*=4;
		*height = (long) size.size.height;
#if 1 // same as g84
        *width *= self.window.backingScaleFactor;
        *height *= self.window.backingScaleFactor;
#endif
		*spp = 3;
		*bpp = 8;
		
        const int srcStride = 4;
        int dstStride = *spp;
		buf = (unsigned char*) malloc( *width * *height * srcStride * *bpp/8);
		if (buf)
		{
			[self getVTKRenderWindow]->MakeCurrent();
//			[[NSOpenGLContext currentContext] flushBuffer];
			
			CGLContextObj cgl_ctx = (CGLContextObj) [[NSOpenGLContext currentContext] CGLContextObj];
			
			glReadBuffer(GL_FRONT);
			
#if __BIG_ENDIAN__
            glReadPixels(0, 0, *width, *height, GL_RGB, GL_UNSIGNED_BYTE, buf);
#else
            glReadPixels(0, 0, *width, *height, GL_RGBA, GL_UNSIGNED_INT_8_8_8_8_REV, buf);
#endif
            i = *width * *height;
            unsigned char *t_argb = buf;
            unsigned char *t_rgb = buf;
            while (i-- > 0)
            {
                *((int*) t_rgb) = *((int*) t_argb);
                t_argb += srcStride;
                t_rgb += dstStride;
            }
			
			long rowBytes = (*width) * dstStride * (*bpp / 8);
			
			{
				unsigned char *tempBuf = (unsigned char*) malloc( rowBytes);
				
				for (i = 0; i < *height/2; ++i)
				{
					memcpy( tempBuf, buf + (*height - 1 - i)*rowBytes, rowBytes);
					memcpy( buf + (*height - 1 - i)*rowBytes, buf + i*rowBytes, rowBytes);
					memcpy( buf + i*rowBytes, tempBuf, rowBytes);
				}
				
				free( tempBuf);
			}
			
//			[[NSOpenGLContext currentContext] flushBuffer];
			[NSOpenGLContext clearCurrentContext];
		}
	}
//	else NSLog(@"Err getRawPixels...");
		
	return buf;
}

-(NSImage*) nsimage:(BOOL) originalSize
{
	NSBitmapImageRep	*rep;
	long				width, height, x, spp, bpp;
	NSString			*colorSpace;
	unsigned char		*dataPtr;
	
	dataPtr = [self getRawPixels :&width :&height :&spp :&bpp :!originalSize : YES];
	
	if (spp == 3)
        colorSpace = NSCalibratedRGBColorSpace;
	else
        colorSpace = NSCalibratedWhiteColorSpace;
	
	rep = [[[NSBitmapImageRep alloc]
			 initWithBitmapDataPlanes:nil
						   pixelsWide:width
						   pixelsHigh:height
						bitsPerSample:bpp
					  samplesPerPixel:spp
							 hasAlpha:NO
							 isPlanar:NO
					   colorSpaceName:colorSpace
						  bytesPerRow:width*bpp*spp/8
						 bitsPerPixel:bpp*spp] autorelease];
	
	memcpy( [rep bitmapData], dataPtr, height*width*bpp*spp/8);
	
    [vtkMieleView addTiffLogo: @"SmallLogo.tif"
                             : spp //dstStride
                             : [rep bitmapData] //buf
                             : height
                             : width
                             : [rep bytesPerRow] //rowBytes
                             : 10 // width - 10 // 10 pixels margin
                             : true]; // right side
	
     NSImage *image = [[[NSImage alloc] init] autorelease];
     [image addRepresentation:rep];
     
	 free( dataPtr);
	 
    return image;
}

-(IBAction) copy:(id) sender
{
    NSPasteboard *pb = [NSPasteboard generalPasteboard];

    NSImage *im;
    
    [pb declareTypes:[NSArray arrayWithObject:NSPasteboardTypeTIFF] owner:self];
    
    im = [self nsimage:NO];
    
    [pb setData: [im TIFFRepresentation] forType:NSPasteboardTypeTIFF];
}

// joris' modifications for fly thru

- (Camera*) camera
{
	// data extraction from the vtkCamera
	double pos[3], focal[3], vUp[3];
	aCamera->GetPosition(pos);
	aCamera->GetFocalPoint(focal);
	aCamera->GetViewUp(vUp);
	double clippingRange[2];
	aCamera->GetClippingRange(clippingRange);
	double viewAngle, eyeAngle, parallelScale;
	viewAngle = aCamera->GetViewAngle();
	eyeAngle = aCamera->GetEyeAngle();
	parallelScale = aCamera->GetParallelScale();
	
	// creation of the Camera
	Camera *cam = [[Camera alloc] init];
	[cam setPosition: [[[Point3D alloc] initWithValues:pos[0] :pos[1] :pos[2]] autorelease]];
	[cam setFocalPoint: [[[Point3D alloc] initWithValues:focal[0] :focal[1] :focal[2]] autorelease]];
	[cam setViewUp: [[[Point3D alloc] initWithValues:vUp[0] :vUp[1] :vUp[2]] autorelease]];
	[cam setClippingRangeFrom: clippingRange[0] To: clippingRange[1]];
	[cam setViewAngle: viewAngle];
	[cam setEyeAngle: eyeAngle];
	[cam setParallelScale: parallelScale];
	
	[cam setPreviewImage: [self nsimage:TRUE]];
	
	return [cam autorelease];
}

- (void) setCamera: (Camera*) cam
{	
	double pos[3], focal[3], vUp[3];
	pos[0] = [[cam position] x];
	pos[1] = [[cam position] y];
	pos[2] = [[cam position] z];
	focal[0] = [[cam focalPoint] x];
	focal[1] = [[cam focalPoint] y];
	focal[2] = [[cam focalPoint] z];	
	vUp[0] = [[cam viewUp] x];
	vUp[1] = [[cam viewUp] y];
	vUp[2] = [[cam viewUp] z];
	double clippingRange[2];
	clippingRange[0] = [cam clippingRangeNear];
	clippingRange[1] = [cam clippingRangeFar];
	double viewAngle, eyeAngle, parallelScale;
	viewAngle = [cam viewAngle];
	eyeAngle = [cam eyeAngle];
	parallelScale = [cam parallelScale];

	aCamera->SetPosition(pos);
	aCamera->SetFocalPoint(focal);
	aCamera->SetViewUp(vUp);
	//aCamera->SetClippingRange(clippingRange);
	aCamera->SetViewAngle(viewAngle);
	aCamera->SetEyeAngle(eyeAngle);
	aCamera->SetParallelScale(parallelScale);
	aRenderer->ResetCameraClippingRange();
}

- (IBAction)changeColor:(id)sender
{
    //NSLog(@"%s (IBAction)", __FUNCTION__);

    //if ([backgroundColor isActive])
	{
        //NSLog(@"%s (IBAction)", __FUNCTION__);
		NSColor *color= [[(NSColorPanel*)sender color] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
		aRenderer->SetBackground([color redComponent],
                                 [color greenComponent],
                                 [color blueComponent]);
		[self setNeedsDisplay:YES];
	}
}

- (void) convert3Dto2Dpoint:(double*) pt3D :(double*) pt2D
{
	if (pt3D == nil)
		return;
	
	if (pt2D == nil)
		return;
	
	vtkTransform *Transform = vtkTransform::New();
			
	Transform->SetMatrix( matrice);
	Transform->Push();
	
	Transform->Inverse();
	
	Transform->TransformPoint( pt3D, pt2D);
	
	double vPos[ 3];
	
    if (iso[ 0])
    {
        iso[ 0]->GetPosition( vPos);
        
        pt2D[ 0] -= vPos[ 0];
        pt2D[ 1] -= vPos[ 1];
        pt2D[ 2] -= vPos[ 2];
        
        if ([firstObject pixelSpacingX])
            pt2D[0] /= [firstObject pixelSpacingX];
        
        if ([firstObject pixelSpacingY])
            pt2D[1] /= [firstObject pixelSpacingY];
        
        if ([firstObject sliceInterval])
            pt2D[2] /= [firstObject sliceInterval];
    }
    
	Transform->Delete();
}

// 3D points
#pragma mark - 3D Points

#pragma mark - add
- (void) add3DPoint: (double) x
                   : (double) y
                   : (double) z
                   : (float) radius
                   : (float) r
                   : (float) g
                   : (float) b
{
	//Sphere
	vtkSphereSource *sphereSource = vtkSphereSource::New();
	sphereSource->SetRadius(radius);
	sphereSource->SetCenter(x, y, z);
	//Mapper
	vtkPolyDataMapper *mapper = vtkPolyDataMapper::New();
	mapper->SetInputConnection(sphereSource->GetOutputPort());
	sphereSource->Delete();
	mapper->Update();
	//Actor
	vtkActor *sphereActor = vtkActor::New();
	sphereActor->SetMapper(mapper);
	mapper->Delete();
	sphereActor->GetProperty()->SetColor(r,g,b);
	sphereActor->DragableOn();
	sphereActor->PickableOn();

	double center[3];
	center[0]=x;
	center[1]=y;
	center[2]=z;
	[point3DPositionsArray addObject:[NSValue value:center withObjCType:@encode(double[3])]];
	[point3DRadiusArray addObject:[NSNumber numberWithFloat:radius]];
	[point3DColorsArray addObject:[NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0F]];

	[point3DDisplayPositionArray addObject:@0];
	[point3DPositionsStringsArray addObject:[NSString stringWithFormat:@"x: %0.3f mm\ny: %0.3f mm\nz: %0.3f mm", x, y, z]];
	[point3DTextColorsArray addObject:[NSColor colorWithCalibratedRed:1.0F green:1.0F blue:1.0F alpha:1.0F]];
	[point3DTextSizesArray addObject:@4.0F];
	
	[self add3DPointActor: sphereActor];
	
	// point annotations
//	vtkVectorText *aText = vtkVectorText::New();
	
//	const char *bufferPosition = [[NSString stringWithFormat:@"x: %0.3f mm, y: %0.3f mm, z: %0.3f mm", x, y, z] UTF8String];
//	char *bufferName = "Name\n";
//	char *bufferAnnotation = (char *)malloc((strlen(bufferPosition) + strlen(bufferName) + 1)*sizeof(char));
//	strcat(bufferAnnotation, bufferName);
//	strcat(bufferAnnotation, bufferPosition);
//	
	[self setAnnotation: "" for3DPointAtIndex:(long)[point3DPositionsArray count]-1];
	
//	aText->SetText(bufferAnnotation);
//	
//	vtkPolyDataMapper *textMapper = vtkPolyDataMapper::New();
//	textMapper->SetInput(aText->GetOutput());
//	
//		// text
//	vtkFollower *text = vtkFollower::New();
//	text->SetMapper(textMapper);
//	text->SetScale(4,4,4);
//	text->SetPosition(x+radius,y+radius,z+radius);
//	text->GetProperty()->SetColor(1, 1, 1);
	
		// shadow
//	vtkFollower *textShadow = vtkFollower::New();
//	textShadow->SetMapper(textMapper);
//	textShadow->SetScale(4.3,4.3,4.3);
//	textShadow->SetPosition(x+radius-.1,y+radius,z+radius);
//	textShadow->GetProperty()->SetColor(0, 0, 0);
//
//	aRenderer->AddActor(textShadow);
//	textShadow->SetCamera(aCamera);
//	aRenderer->AddActor(text);
//	text->SetCamera(aCamera);
//
//	void* textPointer = text;
//	[point3DTextArray addObject:[NSValue valueWithPointer:textPointer]];
}

- (void) add3DPoint: (double) x : (double) y : (double) z
{
	[self add3DPoint: x : y : z : point3DDefaultRadius : point3DDefaultColorRed : point3DDefaultColorGreen : point3DDefaultColorBlue];
}

- (void) add3DPointActor: (vtkActor*) actor
{
	void* actorPointer = actor;
	[point3DActorArray addObject:[NSValue valueWithPointer:actorPointer]];
	aRenderer->AddActor(actor);
	//actor->Delete();
}

- (void) addRandomPoints: (int) n : (int) r
{
	// add some random points
	for (long i=0; i<n ; i++)
	{
		[self add3DPoint: ((double)(random()/(pow(2.,31.)-1))*2.0-1.0)*(double)r // x coordinate
						: ((double)(random()/(pow(2.,31.)-1))*2.0-1.0)*(double)r // y
						: ((double)(random()/(pow(2.,31.)-1))*2.0-1.0)*(double)r // z
						: 2.0 // radius
						: 1.0 // red
						: 0.0 // green
						: 0.0 // blue
		];
	}
}

- (void) throw3DPointOnSurface: (double) x : (double) y
{
	vtkWorldPointPicker *picker = vtkWorldPointPicker::New();
	
	picker->Pick(x, y, 0.0, aRenderer);
	double wXYZ[3];
	picker->GetPickPosition(wXYZ);
	[self add3DPoint: wXYZ[0] : wXYZ[1] : wXYZ[2]];
	[controller add2DPoint: wXYZ[0] : wXYZ[1] : wXYZ[2]];
	
	picker->Delete();
}

#pragma mark - display

- (void) setDisplay3DPoints: (BOOL) on
{
	display3DPoints = on;
	
	NSEnumerator *enumeratorPoint = [point3DActorArray objectEnumerator];
	NSEnumerator *enumeratorText = [point3DTextArray objectEnumerator];
	id objectPoint, objectText;
	vtkActor *actor;
	vtkFollower* text;
		
	while (objectPoint = [enumeratorPoint nextObject])
	{
		actor = (vtkActor*)[objectPoint pointerValue];
		objectText = [enumeratorText nextObject];
		text = (vtkFollower*)[objectText pointerValue];
		if (on)
		{
			aRenderer->AddActor(actor);
			aRenderer->AddActor(text);
		}
		else
		{
			aRenderer->RemoveActor(actor);
			aRenderer->RemoveActor(text);
		}	
	}
	[self unselectAllActors];
	[self setNeedsDisplay:YES];
}

- (void) toggleDisplay3DPoints
{
	[self setDisplay3DPoints:!display3DPoints];
}

#pragma mark - selection

- (BOOL) isAny3DPointSelected
{
	BOOL boo = NO;
	
	if (((vtkAbstractPropPicker*)aRenderer->GetRenderWindow()->GetInteractor()->GetPicker())->GetViewProp()!=NULL)
	{
		// a vtkObject is selected, let's check if it is one of our 3D Points
		if ([self selected3DPointIndex] < [point3DActorArray count])
		{
			boo = YES;
		}
	}

	return boo;
}

- (unsigned int) selected3DPointIndex
{
	vtkProp *pickedProp = ((vtkAbstractPropPicker*)aRenderer->GetRenderWindow()->GetInteractor()->GetPicker())->GetPath()->GetFirstNode()->GetViewProp();
	
	void *pickedPropPointer = pickedProp;
	
	NSEnumerator *enumerator = [point3DActorArray objectEnumerator];
	id object;
	void *actorPointer;
	unsigned int i = 0;
	
	while (object = [enumerator nextObject])
	{
		actorPointer = [object pointerValue];
		if (pickedPropPointer==actorPointer)
		{
			return i;
		}
		i++;
	}
	return i; // if no point is selected, returns [point3DActorArray count], i.e. out of bounds...
}

- (void) unselectAllActors
{
	((vtkInteractorStyle*)aRenderer->GetRenderWindow()->GetInteractor()->GetInteractorStyle())->HighlightProp3D(NULL);
}

#pragma mark - remove

- (void) remove3DPointAtIndex: (unsigned int) index
{
	// point to remove
	vtkActor *actor = (vtkActor*)[[point3DActorArray objectAtIndex:index] pointerValue];
	// remove from Renderer
	aRenderer->RemoveActor(actor);
	// remove the highlight bounding box
	[self unselectAllActors];
	// remove from list
	[point3DActorArray removeObjectAtIndex:index];
	[point3DPositionsArray removeObjectAtIndex:index];
	[point3DRadiusArray removeObjectAtIndex:index];
	[point3DColorsArray removeObjectAtIndex:index];
	
	
	vtkFollower *text = (vtkFollower*)[[point3DTextArray objectAtIndex:index] pointerValue];
	aRenderer->RemoveActor(text);
	text->Delete();
	[point3DTextArray removeObjectAtIndex:index];
	[point3DPositionsStringsArray removeObjectAtIndex:index];
	[point3DTextColorsArray removeObjectAtIndex:index];
	[point3DTextSizesArray removeObjectAtIndex:index];
	// refresh display
	[self setNeedsDisplay:YES];
}

- (void) removeSelected3DPoint
{
	if ([self isAny3DPointSelected])
	{
		// remove 2D Point
		double position[3];
		//NSLog(@"[point3DPositionsArray count]: %d", (int) [point3DPositionsArray count]);
		[[point3DPositionsArray objectAtIndex:[self selected3DPointIndex]] getValue:position size:3*sizeof(double)];
		[controller remove2DPoint: position[0] : position[1] : position[2]];
		// remove 3D Point
		// the 3D Point is removed through notification (sent in [controller remove2DPoint..)
		//[self remove3DPointAtIndex:[self selected3DPointIndex]];
	}
}

#pragma mark - modify 3D point appearance

- (IBAction) IBSetSelected3DPointColor: (id) sender
{
	if ([point3DPropagateToAll state])
	{
		[self setAll3DPointsColor: [sender color]];
		[self setAll3DPointsRadius: [point3DRadiusSlider floatValue]];
	}
	else
	{
		[self setSelected3DPointColor: [sender color]];
	}
	[self setNeedsDisplay:YES];
}

- (IBAction) IBSetSelected3DPointRadius: (id) sender
{
	if ([point3DPropagateToAll state]) {
		[self setAll3DPointsRadius: [sender floatValue]];
		[self setAll3DPointsColor: [[point3DColorWell color] colorUsingColorSpaceName: NSCalibratedRGBColorSpace]];
	}
	else {
		[self setSelected3DPointRadius: [sender floatValue]];
	}

    [self setNeedsDisplay:YES];
}

- (IBAction) IBPropagate3DPointsSettings: (id) sender
{
	if ([sender state] == NSControlStateValueOn) {
		[self setAll3DPointsRadius: [point3DRadiusSlider floatValue]];
		[self setAll3DPointsColor: [[point3DColorWell color] colorUsingColorSpaceName: NSCalibratedRGBColorSpace]];
        [self IBSetSelected3DPointAnnotation: point3DDisplayPositionButton];
		[self IBSetSelected3DPointAnnotationColor: point3DTextColorWell];
        [self IBSetSelected3DPointAnnotationSize: point3DTextSizeSlider];
		[self setNeedsDisplay:YES];
	}
}

- (void) setSelected3DPointColor: (NSColor*) color
{
	if ([self isAny3DPointSelected])
        [self set3DPointAtIndex:[self selected3DPointIndex] Color: color];
}

- (void) setAll3DPointsColor: (NSColor*) color
{
	for (unsigned int i=0 ; i<[point3DColorsArray count] ; i++)
		[self set3DPointAtIndex:i Color: color];
}

- (void) set3DPointAtIndex:(unsigned int) index Color: (NSColor*) color
{
	vtkActor *actor = (vtkActor*)[[point3DActorArray objectAtIndex:index] pointerValue];
	actor->GetProperty()->SetColor([color redComponent],[color greenComponent],[color blueComponent]);

	[point3DColorsArray removeObjectAtIndex:index];
	[point3DColorsArray insertObject:color atIndex:index];
}

- (void) setSelected3DPointRadius: (float) radius
{
	if ([self isAny3DPointSelected])
        [self set3DPointAtIndex:[self selected3DPointIndex] Radius: radius];
}

- (void) setAll3DPointsRadius: (float) radius
{
	for (unsigned int i=0 ; i<[point3DRadiusArray count] ; i++)
		[self set3DPointAtIndex:i Radius: radius];
}

- (void) set3DPointAtIndex:(unsigned int) index Radius: (float) radius
{
	vtkActor *actor = (vtkActor*)[[point3DActorArray objectAtIndex:index] pointerValue];
	//Sphere
	vtkSphereSource *sphereSource = vtkSphereSource::New();
	sphereSource->SetRadius(radius);
	double center[3];
	[[point3DPositionsArray objectAtIndex:index] getValue:center size:3*sizeof(double)];
	sphereSource->SetCenter(center[0],center[1],center[2]);
	//Mapper
	vtkPolyDataMapper *mapper = vtkPolyDataMapper::New();
	mapper->SetInputConnection(sphereSource->GetOutputPort());
	mapper->Update();

	//Actor
	actor->SetMapper(mapper);
	
	sphereSource->Delete();
	mapper->Delete();
	
	[point3DRadiusArray removeObjectAtIndex:index];
	[point3DRadiusArray insertObject:[NSNumber numberWithFloat:radius] atIndex:index];
}

- (IBAction) save3DPointsDefaultProperties: (id) sender
{
    NSColor *color = [[point3DColorWell color] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];

    //color
	point3DDefaultColorRed = [color redComponent];
	point3DDefaultColorGreen = [color greenComponent];
	point3DDefaultColorBlue = [color blueComponent];
	point3DDefaultColorAlpha = [color alphaComponent];
	[[NSUserDefaults standardUserDefaults] setFloat:point3DDefaultColorRed forKey:@"points3DcolorRed"];
	[[NSUserDefaults standardUserDefaults] setFloat:point3DDefaultColorGreen forKey:@"points3DcolorGreen"];
	[[NSUserDefaults standardUserDefaults] setFloat:point3DDefaultColorBlue forKey:@"points3DcolorBlue"];
	[[NSUserDefaults standardUserDefaults] setFloat:point3DDefaultColorAlpha forKey:@"points3DcolorAlpha"];

	// radius
	point3DDefaultRadius = [point3DRadiusSlider floatValue];
	[[NSUserDefaults standardUserDefaults] setFloat:[point3DRadiusSlider floatValue] forKey:@"points3Dradius"];
}

- (void) load3DPointsDefaultProperties
{	
	//color
	point3DDefaultColorRed = [[NSUserDefaults standardUserDefaults] floatForKey:@"points3DcolorRed"];
	point3DDefaultColorGreen = [[NSUserDefaults standardUserDefaults] floatForKey:@"points3DcolorGreen"];
	point3DDefaultColorBlue = [[NSUserDefaults standardUserDefaults] floatForKey:@"points3DcolorBlue"];
	point3DDefaultColorAlpha = [[NSUserDefaults standardUserDefaults] floatForKey:@"points3DcolorAlpha"];
	
	if (point3DDefaultColorAlpha==0.0)
	{
		point3DDefaultColorRed = 1.0;
		point3DDefaultColorGreen = 0.0;
		point3DDefaultColorBlue = 0.0;
		point3DDefaultColorAlpha = 1.0;
	}

	//radius
	point3DDefaultRadius = [[NSUserDefaults standardUserDefaults] floatForKey:@"points3Dradius"];
	if (point3DDefaultRadius==0)
        point3DDefaultRadius = 1.0;
}

#pragma mark - annotation

- (IBAction) IBSetSelected3DPointAnnotation: (id) sender
{
//	int displayName = [[sender cellWithTag:0] state];
	int displayPosition = [sender state];
	
	if ([point3DPropagateToAll state])
	{
		for (int i=0; i<[point3DActorArray count]; i++)
			[self setAnnotationWithPosition:displayPosition for3DPointAtIndex:i];
	}
	else
	{
		[self setAnnotationWithPosition:displayPosition for3DPointAtIndex:[self selected3DPointIndex]];
	}
    
	[self setNeedsDisplay:YES];
}

- (void) setAnnotationWithPosition:(int)displayPosition for3DPointAtIndex:(unsigned int) index
{
	const char *position = nil;
    
	//position
	if (displayPosition)
		position = [[point3DPositionsStringsArray objectAtIndex:index] UTF8String];
	else
		position = "";
	
	[self setAnnotation:position for3DPointAtIndex:index];
	if (strlen( position)>0)
		[self displayAnnotationFor3DPointAtIndex:index];
	else
		[self hideAnnotationFor3DPointAtIndex:index];
	
//	NSMutableArray *form = [point3DTextMatrixArray objectAtIndex:index];
//	[form replaceObjectAtIndex:0 withObject:[NSNumber numberWithInt:displayName]];
//	[form replaceObjectAtIndex:1 withObject:[NSNumber numberWithInt:displayPosition]];
	[point3DDisplayPositionArray replaceObjectAtIndex:index withObject:[NSNumber numberWithInt:displayPosition]];
}

- (void) setAnnotation:(const char*) annotation for3DPointAtIndex:(unsigned int) index
{
	vtkVectorText *aText = vtkVectorText::New();
	aText->SetText(annotation);
	
	vtkPolyDataMapper *textMapper = vtkPolyDataMapper::New();
	textMapper->SetInputData(aText->GetOutput());
	
	float radius = [[point3DRadiusArray objectAtIndex:index] floatValue];
	double position[3];
    [[point3DPositionsArray objectAtIndex:index] getValue:position size:3*sizeof(double)];

    // text
	vtkFollower *text = vtkFollower::New();
	text->SetMapper(textMapper);
	float s = [[point3DTextSizesArray objectAtIndex:index] floatValue];
	text->SetScale(s,s,s);
	text->SetPosition(position[0]+radius,
                      position[1]+radius,
                      position[2]+radius);
	NSColor *c = [point3DTextColorsArray objectAtIndex:index];
	text->GetProperty()->SetColor([c redComponent], [c greenComponent], [c blueComponent]);
	
    // shadow
//	vtkFollower *textShadow = vtkFollower::New();
//	textShadow->SetMapper(textMapper);
//	textShadow->SetScale(4.3,4.3,4.3);
//	textShadow->SetPosition(x+radius-.1,y+radius,z+radius);
//	textShadow->GetProperty()->SetColor(0, 0, 0);
//
//	aRenderer->AddActor(textShadow);
//	textShadow->SetCamera(aCamera);

	void* textPointer = text;
	if (index<[point3DTextArray count])
	{
		vtkFollower* text0 = (vtkFollower*)[[point3DTextArray objectAtIndex:index] pointerValue];
		aRenderer->RemoveActor(text0);
		[point3DTextArray replaceObjectAtIndex:index withObject:[NSValue valueWithPointer:textPointer]];
		text0->Delete();
	}
	else
		[point3DTextArray addObject:[NSValue valueWithPointer:textPointer]];
}

- (void) displayAnnotationFor3DPointAtIndex:(unsigned int) index
{
	vtkFollower* text = (vtkFollower*)[[point3DTextArray objectAtIndex:index] pointerValue];
	aRenderer->AddActor(text);
	text->SetCamera(aCamera);
	[self setNeedsDisplay:YES];
}

- (void) hideAnnotationFor3DPointAtIndex:(unsigned int) index
{
	vtkFollower* text = (vtkFollower*)[[point3DTextArray objectAtIndex:index] pointerValue];
	aRenderer->RemoveActor(text);
	[self setNeedsDisplay:YES];
}

- (IBAction) IBSetSelected3DPointAnnotationColor: (id) sender
{
	if ([self selected3DPointIndex]<[point3DTextArray count])
	{
		NSColor *c = [sender color];
		float r, g, b;
		r = [c redComponent];
		g = [c greenComponent];
		b = [c blueComponent];
		
		if ([point3DPropagateToAll state])
		{
			for (int i=0; i<[point3DActorArray count]; i++)
			{
				vtkFollower* text = (vtkFollower*)[[point3DTextArray objectAtIndex:i] pointerValue];
				text->GetProperty()->SetColor(r, g, b);
				[point3DTextColorsArray replaceObjectAtIndex:i withObject:c];
			}
		}
		else
		{
			vtkFollower* text = (vtkFollower*)[[point3DTextArray objectAtIndex:[self selected3DPointIndex]] pointerValue];
			text->GetProperty()->SetColor(r, g, b);
			[point3DTextColorsArray replaceObjectAtIndex:[self selected3DPointIndex] withObject:c];
		}
        
		[self setNeedsDisplay:YES];
	}
}

- (IBAction) IBSetSelected3DPointAnnotationSize: (id) sender
{
	if ([self selected3DPointIndex]<[point3DTextArray count])
	{
		float s = [sender floatValue];
		
		if ([point3DPropagateToAll state])
		{
			for (int i=0; i<[point3DActorArray count]; i++)
			{
				vtkFollower* text = (vtkFollower*)[[point3DTextArray objectAtIndex:i] pointerValue];
				text->SetScale(s,s,s);
				[point3DTextSizesArray replaceObjectAtIndex:i withObject:[NSNumber numberWithFloat:s]];
			}
		}
		else
		{
			vtkFollower* text = (vtkFollower*)[[point3DTextArray objectAtIndex:[self selected3DPointIndex]] pointerValue];
			text->SetScale(s,s,s);
			[point3DTextSizesArray replaceObjectAtIndex:[self selected3DPointIndex] withObject:[NSNumber numberWithFloat:s]];
		}
        
		[self setNeedsDisplay:YES];
	}
}

#pragma mark - Cursors

//cursor methods

- (void)mouseEntered:(NSEvent *)theEvent
{
	cursorSet = YES;
}

- (void)mouseExited:(NSEvent *)theEvent
{
	cursorSet = NO;
}

-(void)cursorUpdate:(NSEvent *)theEvent
{
    cursorSet = YES;
    [cursor set];
}

- (void) checkCursor
{
	if (cursorSet)
        [cursor set];
}

-(void) setCursorForView: (ToolMode) tool
{
	NSCursor *c;
	
	if (tool == tMeasure || tool == t3Dpoint)
		c = [NSCursor crosshairCursor];
	else if (tool == t3DCut)
		c = [NSCursor crosshairCursor];
	else if (tool == t3DRotate)
		c = [NSCursor rotate3DCursor];
	else if (tool == tCamera3D)
		c = [NSCursor rotate3DCameraCursor];
	else if (tool == tTranslate)
		c = [NSCursor openHandCursor];
	else if (tool == tRotate)
		c = [NSCursor rotateCursor];
	else if (tool == tZoom)
		c = [NSCursor zoomCursor];
	else if (tool == tWL)
		c = [NSCursor contrastCursor];
	else if (tool == tNext)
		c = [NSCursor stackCursor];
	else if (tool == tText)
		c = [NSCursor IBeamCursor];
	else if (tool == t3DRotate)
		c = [NSCursor crosshairCursor];
	else if (tool == tCross)
		c = [NSCursor crosshairCursor];
	else	
		c = [NSCursor arrowCursor];
		
	if (c != cursor)
	{
		[cursor release];
		cursor = [c retain];
	}
}

#pragma mark - Drag and Drop

- (void) startDrag:(NSTimer*)theTimer
{
	@try
    {
        _dragInProgress = YES;
        
        NSEvent *event = (NSEvent *)[theTimer userInfo];
        NSSize dragOffset = NSZeroSize;
        NSPasteboard *pboard = [NSPasteboard pasteboardWithName: NSDragPboard]; 
        NSMutableArray *pbTypes = [NSMutableArray array];
        // The image we will drag 
        NSImage *image;
        if ([event modifierFlags] & NSEventModifierFlagShift)
            image = [self nsimage: YES];
        else
            image = [self nsimage: NO];
            
        // Thumbnail image and position
        float sf = [[NSScreen mainScreen] backingScaleFactor];
        NSPoint event_location = [event locationInWindow];
        NSPoint local_point = 
#if 0 // original
        [self convertPoint:event_location fromView:nil];
#else
        [self convertPointToBacking: [event locationInWindow]];
#endif
        local_point.x -= 35*sf;
        local_point.y -= 35*sf;

        NSSize originalSize = [image size];
        
        float ratio = originalSize.width / originalSize.height;
        
        NSImage *thumbnail = [[[NSImage alloc] initWithSize: NSMakeSize(100, 100/ratio)] autorelease];
        if ([thumbnail size].width > 0 && [thumbnail size].height > 0)
        {
            [thumbnail lockFocus];
            [image drawInRect: NSMakeRect(0, 0, 100, 100/ratio)
                     fromRect: NSMakeRect(0, 0, originalSize.width, originalSize.height)
                    operation: NSCompositeSourceOver
                     fraction: 1.0];
            [thumbnail unlockFocus];
        }
        
        if ([event modifierFlags] & NSEventModifierFlagOption)
            [pbTypes addObject: (__bridge NSString *)kPasteboardTypeFileURLPromise];
        else
            [pbTypes addObject: NSPasteboardTypeTIFF];

        [pboard declareTypes:pbTypes  owner:self];
            
        if ([event modifierFlags] & NSEventModifierFlagOption) {
            NSRect imageLocation;
            local_point = 
#if 0 // original
            [self convertPoint:event_location fromView:nil];
#else
            [self convertPointToBacking: [event locationInWindow]];
#endif
            imageLocation.origin = local_point;
            imageLocation.size = NSMakeSize(32,32);
            [pboard setData:nil
                    forType:(__bridge NSString *)kPasteboardTypeFileURLPromise]; 
            
            [destinationImage release];
            destinationImage = [image copy];
            
            [self dragPromisedFilesOfTypes:[NSArray arrayWithObject:@"jpg"]
                fromRect:imageLocation
                source:self
                slideBack:YES
                event:event];
        } 
        else {		
            [pboard setData: [[NSBitmapImageRep imageRepWithData: [image TIFFRepresentation]] representationUsingType:NSJPEGFileType properties:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.9] forKey:NSImageCompressionFactor]] forType:NSPasteboardTypeTIFF];
            
            [self dragImage:thumbnail
                         at:local_point
                     offset:dragOffset
                      event:event
                 pasteboard:pboard
                     source:self
                  slideBack:YES];
        }
	}
    @catch( NSException *localException)
    {
		NSLog(@"Exception while dragging: %@", [localException description]);
	}
	
	_dragInProgress = NO;
}

- (NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination
{
	NSString *name = @"OsiriX";
	name = [name stringByAppendingPathExtension:@"jpg"];
	NSArray *array = [NSArray arrayWithObject:name];
	NSData *_data = [[NSBitmapImageRep imageRepWithData: [destinationImage TIFFRepresentation]] representationUsingType:NSJPEGFileType properties:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.9] forKey:NSImageCompressionFactor]];
	NSURL *url = [NSURL  URLWithString:name  relativeToURL:dropDestination];
	[_data writeToURL:url  atomically:YES];
	[destinationImage release];
	destinationImage = nil;
	return array;
}

- (void)deleteMouseDownTimer
{
	[_mouseDownTimer invalidate];
	[_mouseDownTimer release];
	_mouseDownTimer = nil;
	_dragInProgress = NO;
}

// Part of Dragging Source Protocol
- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
    return NSDragOperationEvery; // All: Copy Link Generic Private Move Delete
}

-(void) squareView:(id) sender
{
    VRDefaultViewSizeType viewType= (VRDefaultViewSizeType)[[NSUserDefaults standardUserDefaults] integerForKey:VRDefaultViewSize_KEY];

	if (viewType == VR_VIEW_SIZE_FULL_SCREEN)
        return;
	
	NSRect newFrame = [self frame];
	NSRect beforeFrame = [self frame];
	
	int border = [self frame].size.height-1;
	
	if (border > [self frame].size.width)
        border = [self frame].size.width;
	
	if (viewType == VR_VIEW_SIZE_512x512)
        border = 512;
	else if (viewType == VR_VIEW_SIZE_768x768)
        border = 768;
	
	newFrame.size.width = border;
	newFrame.size.height = border;

	newFrame.origin.x = (int) ((beforeFrame.size.width - border) / 2);
	newFrame.origin.y = (int) (10 + (beforeFrame.size.height - border) / 2);
	
	[self setFrame: newFrame];
	[[self window] display];
}

- (vtkRenderer*) vtkRenderer;
{
	return aRenderer;
}

- (vtkCamera*) vtkCamera;
{
	return aCamera;
}

- (void)panX:(float)x Y:(float)y;
{
	vtkRenderWindowInteractor *rwi = [self getInteractor];

	double ViewFocus[4];
	double NewPickPoint[4];

	// Calculate the focal depth
	vtkCamera* camera = aCamera;
	camera->GetFocalPoint(ViewFocus);
	rwi->GetInteractorStyle()->ComputeWorldToDisplay(aRenderer, ViewFocus[0], ViewFocus[1], ViewFocus[2], ViewFocus);
	double focalDepth = ViewFocus[2];

	rwi->GetInteractorStyle()->ComputeDisplayToWorld(aRenderer, (double)x, (double)y, focalDepth, NewPickPoint);

	// Get the current focal point and position

	camera->GetFocalPoint(ViewFocus);

	double *ViewPoint = camera->GetPosition();

	// Compute a translation vector, moving everything 1/10
	// the distance to the cursor. (Arbitrary scale factor)

	double MotionVector[3];
	MotionVector[0] = 0.01 * (ViewFocus[0] - NewPickPoint[0]);
	MotionVector[1] = 0.01 * (ViewFocus[1] - NewPickPoint[1]);
	MotionVector[2] = 0.01 * (ViewFocus[2] - NewPickPoint[2]);

	camera->SetFocalPoint(MotionVector[0] + ViewFocus[0],
						  MotionVector[1] + ViewFocus[1],
						  MotionVector[2] + ViewFocus[2]);

	camera->SetPosition(MotionVector[0] + ViewPoint[0],
						MotionVector[1] + ViewPoint[1],
						MotionVector[2] + ViewPoint[2]);

	if (rwi->GetLightFollowCamera()) 
		aRenderer->UpdateLightsGeometryToFollowCamera();
}

- (void)yaw:(float)degrees;
{
	aCamera->Yaw(degrees);
	aRenderer->ResetCameraClippingRange();
	[self setNeedsDisplay:YES];
}

- (void)recordFlyThru;
{
	[controller recordFlyThru];
}

@end
