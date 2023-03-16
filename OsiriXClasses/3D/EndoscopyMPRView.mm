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


#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtc/type_ptr.hpp"

#import "EndoscopyMPRView.h"
#import "EndoscopyViewer.h"
#import "DCMPix.h"
#import "Mailer.h"
#import "DICOMExport.h"
#import "BrowserController.h"
#import "DCMCursor.h"
#import "Notifications.h"
#import "DicomDatabase.h"
#import "AppDefaults.h"
#import "url.h"

@implementation EndoscopyMPRView

@synthesize flyThroughPath;

- (id)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self != nil)
	{
		cameraPosition.x = 0.0;
		cameraPosition.y = 0.0;
		cameraFocalPoint.x = 0.0;
		cameraFocalPoint.y = 0.0;
		cameraAngle = 0.0;
		focalPointX = 0;
		focalPointY = 0;
		focalShiftX = 0;
		focalShiftY = 0;
		viewUpX = 0;
		viewUpY = 0;
		near = 6.0;
		maxFocalLength = 50.0;
	}
	return self;
}

#pragma mark -

- (void) subDrawRect:(NSRect)aRect
{	
	[super subDrawRect:aRect];
	
	float xCrossCenter = (crossPositionX-[[self curDCM] pwidth]/2) * scaleValue;
	float yCrossCenter = (crossPositionY-[[self curDCM] pheight]/2) * scaleValue;
		
	// normalization of FOCAL VECTOR
	float vectNorm = sqrt(pow(focalShiftX,2)+pow(focalShiftY/[self pixelSpacingX]*[self pixelSpacingY],2));
	float maxSize = maxFocalLength;
	vectNorm = (vectNorm==0)? 1.0: vectNorm;
	maxSize = (vectNorm==0)? 0.0: maxSize;
	maxSize = (vectNorm>maxSize)? maxSize : vectNorm;
	float normalizationFactor = maxSize/vectNorm;
	
	//normalizationFactor = 1.0;
   
#ifdef WITH_OPENGL_32
    // We don't need this to apply the local MV because in OpenGL 2.1 (Legacy)
    // it redefines the whole matrix transformation and the end
    // result is apparently the same as what we have by doing nothing.
    // TBC: maybe only the last transformation, the pixelRatio, should be applied.
    //#define WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ENDO
    #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ENDO
    // Define a local model matrix and apply it locally without affecting the shader
    glm::mat4 M = glm::mat4(1.0);
    M = glm::scale(M, glm::vec3(2.0f / (xFlipped ? -(drawingFrameRect.size.width) : drawingFrameRect.size.width),
                               -2.0f / (yFlipped ? -(drawingFrameRect.size.height) : drawingFrameRect.size.height),
                                1.0f));
    M = glm::rotate(M, glm::radians(self.rotation), glm::vec3(0.0f, 0.0f, 1.0f));
    M = glm::translate(M, glm::vec3(origin.x, -origin.y, 0.0f));
    M = glm::scale(M, glm::vec3(1.f, curDCM.pixelRatio, 1.f));
    #endif // WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ENDO
#else // WITH_OPENGL_32
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    if (cgl_ctx == nil)
        return;

    glPushMatrix();
	
	glLoadIdentity();
	glScalef (2.0f / (xFlipped ? -(drawingFrameRect.size.width) : drawingFrameRect.size.width),
             -2.0f / (yFlipped ? -(drawingFrameRect.size.height) : drawingFrameRect.size.height),
              1.0f); // scale to port per pixel scale
	glRotatef (self.rotation, 0.0f, 0.0f, 1.0f); // rotate matrix for image rotation
	glTranslatef( origin.x, -origin.y, 0.0f);
	glScalef( 1.f, curDCM.pixelRatio, 1.f);
#endif // WITH_OPENGL_32

	// Antialiasing
	glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA );
	glEnable(GL_BLEND);
#ifndef WITH_OPENGL_32
    glEnable(GL_POINT_SMOOTH);
#endif
	glEnable(GL_LINE_SMOOTH);
	glEnable(GL_POLYGON_SMOOTH);
    checkOpenGLErrors(__LINE__);

#pragma mark Focal Vector

    // Draw the direction vector
    [self setShaderProgramForLineWidth: 1.0 * self.window.backingScaleFactor];
    renderer_set_rgb(1.0f, 0.0f, 1.0f); // magenta

    float cfocalShiftX = focalShiftX;
    float cfocalShiftY = focalShiftY;
    
    if (xFlipped)
        cfocalShiftX *= -1.0;
        
    if (yFlipped)
        cfocalShiftY *= -1.0;

    {
        glm::vec2 pFrom(xCrossCenter,yCrossCenter);
        glm::vec2 pTo(xCrossCenter + cfocalShiftX * normalizationFactor,
                      yCrossCenter + cfocalShiftY * normalizationFactor);
        
#ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ENDO
        // Apply local model transformation
        glm::vec4 pTemp;
        pTemp= M*glm::vec4(pFrom,0,1);
        pFrom =glm::vec2(pTemp.x, pTemp.y);

        pTemp= M*glm::vec4(pTo,0,1);
        pTo =glm::vec2(pTemp.x, pTemp.y);
#endif
        NSMutableArray *pArray = [NSMutableArray array];
        [pArray addObject: [NSValue valueWithBytes:&pFrom objCType:@encode(glm::vec2)]];
        [pArray addObject: [NSValue valueWithBytes:&pTo objCType:@encode(glm::vec2)]];

        renderer_drawLine_xy([pArray copy], GL_LINES);
    }
				
#pragma mark Focal Vector Handle

    [self setShaderProgramOverlay_withMode_Point];
	// Draw a point at the end of FOCAL POINT vector (handle to move the vector)
	glPointSize(2.0 * near * self.window.backingScaleFactor);
    
    {
        NSMutableArray *pArray = [NSMutableArray array];
        glm::vec2 a(xCrossCenter + cfocalShiftX * normalizationFactor,
                    yCrossCenter + cfocalShiftY * normalizationFactor);

        #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ENDO
        // Apply local model transformation
        glm::vec4 pTemp;
        pTemp= M*glm::vec4(a,0,1);
        a =glm::vec2(pTemp.x, pTemp.y);
        #endif
        [pArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];

        renderer_drawPoints([pArray copy]);
    }

    // Restore
    glPointSize(1.0 * self.window.backingScaleFactor);
	
#pragma mark View Up Vector

	// Normalization of VIEW UP VECTOR
	float vectViewUpNorm = sqrt(pow(viewUpX,2) + pow(viewUpY,2));
	float sizeViewUp = 25.0;
	vectViewUpNorm = (vectViewUpNorm == 0) ? 1.0 : vectViewUpNorm;
	sizeViewUp = (vectViewUpNorm == 0) ? 0.0 : sizeViewUp; // does nothing ??
	sizeViewUp = (vectViewUpNorm > sizeViewUp) ? sizeViewUp : vectViewUpNorm;
	float normalizationViewUpFactor = sizeViewUp / vectViewUpNorm * 2.0;

    // Draw the view up vector

    [self setShaderProgramForLineWidth: 1.0 * self.window.backingScaleFactor];
    renderer_set_rgb(0.0f, 0.75f, 1.0f); // cyan

    {
        glm::vec2 pFrom(xCrossCenter,yCrossCenter);
        glm::vec2 pTo(xCrossCenter + viewUpX * normalizationViewUpFactor,
                      yCrossCenter + viewUpY * normalizationViewUpFactor);

        #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ENDO
        // Apply local model transformation
        glm::vec4 pTemp;
        pTemp = M*glm::vec4(pFrom,0,1);
        pFrom = glm::vec2(pTemp.x, pTemp.y);

        pTemp = M*glm::vec4(pTo,0,1);
        pTo = glm::vec2(pTemp.x, pTemp.y);
        #endif
        NSMutableArray *pArray = [NSMutableArray array];
        [pArray addObject: [NSValue valueWithBytes:&pFrom objCType:@encode(glm::vec2)]];
        [pArray addObject: [NSValue valueWithBytes:&pTo objCType:@encode(glm::vec2)]];

        renderer_drawLine_xy([pArray copy], GL_LINES);
    }
	
#pragma mark Fly Through Path

    if (flyThroughPath)
    {
        [self setShaderProgramForLineWidth: 1.0 * self.window.backingScaleFactor];
        renderer_set_rgb(0.8f, 0.0f, 0.25f);

        NSMutableArray *pArray = [NSMutableArray array];
        
        for (int i=0; i<[flyThroughPath count]; i++)
        {
            Point3D *pt = [flyThroughPath objectAtIndex:i];
            glm::vec2 a((pt.x - [[self curDCM] pwidth]/2) * scaleValue,
                        (pt.y - [[self curDCM] pheight]/2) * scaleValue);
            #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_ENDO
            // Apply local model transformation
            glm::vec4 pTemp;
            pTemp= M*glm::vec4(a,0,1);
            a =glm::vec2(pTemp.x, pTemp.y);
            #endif
            //* [self pixelSpacingY]/[self pixelSpacingX];
            [pArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];
        }

        renderer_drawLine_xy([pArray copy], GL_LINE_STRIP);
    }
	
	// Antialiasing end
	glDisable(GL_LINE_SMOOTH);
	glDisable(GL_POLYGON_SMOOTH);
	glDisable(GL_BLEND);
	
#ifndef WITH_OPENGL_32
    glDisable(GL_POINT_SMOOTH);
    glPopMatrix();
#endif
}

#pragma mark -

- (BOOL) mouseOnFocal:(NSEvent *)theEvent
{
	NSPoint mouseLocStart;
	
	mouseLocStart = [self convertPoint: [theEvent locationInWindow] fromView: self];
	mouseLocStart = [[[theEvent window] contentView] convertPoint:mouseLocStart toView:self];
	mouseLocStart = [self ConvertFromNSView2GL:mouseLocStart];
	
	// normalization of focal vector
	float vectNorm = sqrt(pow(focalShiftX,2)+pow(focalShiftY/[self pixelSpacingX]*[self pixelSpacingY],2));
	float maxSize = maxFocalLength;
	vectNorm = (vectNorm==0)? 1.0: vectNorm;
	maxSize = (vectNorm==0)? 0.0: maxSize;
	maxSize = (vectNorm>maxSize)? maxSize : vectNorm;
	
	float normalizationFactor = maxSize/vectNorm;
	float scaleFactor = scaleValue;
	
	float sX = focalShiftX;
	float sY = focalShiftY;
	
	if (xFlipped)
		sX *= -1.0;
		
	if (yFlipped)
		sY *= -1.0;
	
	if ((mouseLocStart.x > crossPositionX+sX*normalizationFactor/scaleFactor-near/scaleFactor && mouseLocStart.x < crossPositionX+sX*normalizationFactor/scaleFactor+near/scaleFactor) &&
		(mouseLocStart.y > crossPositionY+sY*normalizationFactor/scaleFactor-near/scaleFactor && mouseLocStart.y < crossPositionY+sY*normalizationFactor/scaleFactor+near/scaleFactor) )		//
	{
		return YES;
	}
	
	return NO;
}
//navigator
- (void) keyDown:(NSEvent *)event
{
    if ([[event characters] length] == 0)
        return;
    
    unichar c = [[event characters] characterAtIndex:0];
    
	if (c ==  NSUpArrowFunctionKey)
	{
		[[NSNotificationCenter defaultCenter] postNotificationName: @"PathAssistantGoForwardNotification" object:nil userInfo: 0L];
	}
	else if (c ==  NSDownArrowFunctionKey)
	{
		[[NSNotificationCenter defaultCenter] postNotificationName: @"PathAssistantGoBackwardNotification" object:nil userInfo: 0L];
	}
	else 
	{
		[super keyDown: event];
	}
}
-(void) mouseMoved: (NSEvent*) theEvent
{
	if (![[self window] isVisible])
		return;
	
	NSView* view = [[[theEvent window] contentView] hitTest:[theEvent locationInWindow]];
	
	if (view == self)
	{
		[super mouseMoved: theEvent];

		if ([self mouseOnFocal: theEvent])
		{
			[cursor release];
			cursor = [[NSCursor rotateAxisCursor] retain];
			[cursor set];
		}
		else
            [self flagsChanged: theEvent];
	}
	else
        [view mouseMoved:theEvent];
}

- (void) mouseDown:(NSEvent *)theEvent
{
	NSPoint		mouseLocStart, mouseLoc;
	
	mouseLocStart = [self convertPoint: [theEvent locationInWindow] fromView: self];
	mouseLocStart = [[[theEvent window] contentView] convertPoint:mouseLocStart toView:self];
	mouseLocStart = [self ConvertFromNSView2GL:mouseLocStart];
	
	// normalization of focal vector
	float vectNorm = sqrt(pow(focalShiftX,2)+pow(focalShiftY/[self pixelSpacingX]*[self pixelSpacingY],2));
	float maxSize = maxFocalLength;
	vectNorm = (vectNorm==0)? 1.0: vectNorm;
	maxSize = (vectNorm==0)? 0.0: maxSize;
	maxSize = (vectNorm>maxSize)? maxSize : vectNorm;
	
	float normalizationFactor = maxSize/vectNorm;
	float scaleFactor = scaleValue;
	
	float sX = focalShiftX;
	float sY = focalShiftY;
	
	if (xFlipped)
		sX *= -1.0;
		
	if (yFlipped)
		sY *= -1.0;
	
	if ((mouseLocStart.x > crossPositionX+sX*normalizationFactor/scaleFactor-near/scaleFactor && mouseLocStart.x < crossPositionX+sX*normalizationFactor/scaleFactor+near/scaleFactor) &&
		(mouseLocStart.y > crossPositionY+sY*normalizationFactor/scaleFactor-near/scaleFactor && mouseLocStart.y < crossPositionY+sY*normalizationFactor/scaleFactor+near/scaleFactor) )		//
	{
		BOOL keepOn = YES;
		while (keepOn)
		{
			theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSPeriodicMask];
			
			mouseLoc = [self convertPoint: [theEvent locationInWindow] fromView: self];
			mouseLoc = [[[theEvent window] contentView] convertPoint:mouseLoc toView:self];
			mouseLoc = [self ConvertFromNSView2GL:mouseLoc];
			
			switch ([theEvent type])
			{
				case NSLeftMouseDragged:
					focalShiftX = (mouseLoc.x - crossPositionX)*scaleFactor;
					focalShiftY = (mouseLoc.y - crossPositionY)*scaleFactor;
					
					[self setFocalShiftX:focalShiftX];
					[self setFocalShiftY:focalShiftY];
					[self setNeedsDisplay:YES];
					[[NSNotificationCenter defaultCenter] postNotificationName: OsirixChangeFocalPointNotification object:self  userInfo: nil];
				break;
				
				case NSLeftMouseUp:
					keepOn = NO;
				break;
					
				case NSPeriodic:
					
				break;
					
				default:
				
				break;
			}
		}
		[self setNeedsDisplay:YES];
	}
	else
	{
		[super mouseDown:theEvent];
	}
}

- (void) setCrossPosition: (float) x :(float) y
{
	[super setCrossPosition: x : y];
	[self setFocalShiftX:[self focalShiftX]]; // will recompute focalPointX
	[self setFocalShiftY:[self focalShiftY]]; // will recompute focalPointX
	[[NSNotificationCenter defaultCenter] postNotificationName: OsirixChangeFocalPointNotification object:self  userInfo: nil];
	[(EndoscopyViewer*)[[self controller] viewer] setCamera];
}

- (void) setCrossPositionX: (float) x
{
	[super setCrossPositionX: x];
	//focalShiftX = focalPointX - crossPositionX;
}

- (void) setCrossPositionY: (float) y
{
	[super setCrossPositionY: y];
	//focalShiftY = focalPointY - crossPositionY;
}

- (void) adjustWLWW:(float) wl :(float) ww
{
	[super adjustWLWW :wl :ww];
	[[NSNotificationCenter defaultCenter] postNotificationName: OsirixUpdate2dWLWWMenuNotification object: curWLWWMenu userInfo: nil];
}

- (void) setCameraPosition: (float) x : (float) y
{
	//NSLog(@"setCameraPosition: %f, %f", x, y);
	cameraPosition.x = x;
	cameraPosition.y = y;
	
//	y = ([[self controller] sign]>0)? [[originalView dcmPixList] count]-sliceIndex-1 : sliceIndex ;
//	[[self controller] reslice: (long)x+0.5:  (long)y+0.5: self];
//	[self setCrossPositionX: (float)x];
//	[self setCrossPositionY: (float)y];
//	[self setCrossPosition:x+[[self curDCM] pwidth]/2 :y+[[self curDCM] pwidth]/2];
}

- (NSPoint) cameraPosition
{
	return cameraPosition;
}

- (void) setCameraFocalPoint: (float) x : (float) y
{
	cameraFocalPoint.x = x;
	cameraFocalPoint.y = y;
}

//- (void) setCameraFocalPoint
//{
//	float x, y;
//	x = cameraPosition.x + focalShiftX * [[[self pixList] objectAtIndex:0] pixelSpacingX];
//	y = cameraPosition.y + focalShiftY * [[[self pixList] objectAtIndex:0] pixelSpacingY];
//	[self setCameraFocalPoint:x : y];
//}

- (NSPoint) cameraFocalPoint
{
	return cameraFocalPoint;
}

- (void) setCameraAngle: (float) alpha
{
	cameraAngle = alpha;
}

- (float) cameraAngle
{
	return cameraAngle;
}

- (void) setFocalPointX: (long) x
{
	focalPointX = x;
	focalShiftX = focalPointX - crossPositionX;
	
	if (xFlipped)
		focalShiftX *= -1.0;
}

- (void) setFocalPointY: (long) y
{
	focalPointY = y;
	focalShiftY = focalPointY - crossPositionY;
	
	if (yFlipped)
		focalShiftY *= -1.0;
}

- (long) focalPointX
{
	return focalPointX;
}

- (long) focalPointY
{
	return focalPointY;
}

- (void) setFocalShiftX: (long) x
{
	if (xFlipped)
		x *= -1.0;
		
	focalShiftX = x;
		focalPointX = crossPositionX + focalShiftX;
}

- (void) setFocalShiftY: (long) y
{
	if (yFlipped)
		y *= -1.0;
		
	focalShiftY = y;
		focalPointY = crossPositionY + focalShiftY;
}

- (long) focalShiftX
{
	if (xFlipped)
		return -focalShiftX;
	else
		return focalShiftX;
}

- (long) focalShiftY
{
	if (yFlipped)
		return -focalShiftY;
	else
		return focalShiftY;
}

- (void) setViewUpX: (long) x
{
	viewUpX = x;
}

- (void) setViewUpY: (long) y
{
	viewUpY = y;
}

- (long) viewUpX
{
	return viewUpX;
}

- (long) viewUpY
{
	return viewUpY;
}

#pragma mark - Export

-(void) sendMail:(id) sender
{
	NSImage *im = [self nsimage: NO];

	NSArray *representations = [im representations];

	NSData *bitmapData = [NSBitmapImageRep representationOfImageRepsInArray:representations usingType:NSJPEGFileType properties:[NSDictionary dictionaryWithObject:[NSDecimalNumber numberWithFloat:0.9] forKey:NSImageCompressionFactor]];

    NSString *path = [[[BrowserController currentBrowser] documentsDirectory] stringByAppendingFormat:@"/%@/%@", TEMP_PATH, OUR_IMAGE_JPG];
	[bitmapData writeToFile:path
                 atomically:YES];
				
	Mailer *email = [[Mailer alloc] init];
	
	[email sendMail:@"--"
                 to:@"--"
            subject:@""
             isMIME:YES
               name:@"--"
            sendNow:NO
              image:path];
	
	[email release];
}

- (void) exportJPEG:(id) sender
{
    NSSavePanel *panel = [NSSavePanel savePanel];
	[panel setCanSelectHiddenExtension:YES];
    [panel setAllowedFileTypes: @[@"jpg"]];
    [panel setNameFieldStringValue: [[[controller originalDCMFilesList] objectAtIndex:0] valueForKeyPath:@"series.name"]];
	if ([panel runModal] == NSModalResponseOK)
	{		
			NSImage *im = [self nsimage:NO];
						
			NSArray *representations = [im representations];
			
			NSData *bitmapData = [NSBitmapImageRep representationOfImageRepsInArray:representations usingType:NSJPEGFileType properties:[NSDictionary dictionaryWithObject:[NSDecimalNumber numberWithFloat:0.9] forKey:NSImageCompressionFactor]];
			
			[bitmapData writeToFile:[panel filename] atomically:YES];
			
			if ([[NSUserDefaults standardUserDefaults] boolForKey: OpenViewer_b_KEY])
            {
                NSWorkspace *ws = [NSWorkspace sharedWorkspace];
                [ws openFile:[panel filename]];
            }
	}
}

- (void) exportDICOMFile:(id) sender
{
	if ([sender isEqual:[[self window] windowController]])
	{
		DCMPix *curPix1 = [self curDCM];

        long annotCopy = [[NSUserDefaults standardUserDefaults] integerForKey: ANNOTATIONS_KEY];
        ClutBarsType clutBarsCopy = (ClutBarsType)[[NSUserDefaults standardUserDefaults] integerForKey: CLUTBARS_KEY];
		long width, height, spp, bpp;
		float cwl, cww;
		float o[9];
		
		[[NSUserDefaults standardUserDefaults] setInteger: ANNOTATIONS_GRAPHICS forKey: ANNOTATIONS_KEY];
		[[NSUserDefaults standardUserDefaults] setInteger: CLUT_BAR_HIDE forKey: CLUTBARS_KEY];
		[DCMView setDefaults];
		
		NSMutableArray *producedFiles = [NSMutableArray array];
		
		unsigned char *data = [self superGetRawPixels:&width :&height :&spp :&bpp :YES :NO :NO];
		
		if (data)
		{
			DICOMExport *exportDCM = [[DICOMExport alloc] init];
			 
			[exportDCM setSourceFile: [[[controller originalDCMFilesList] objectAtIndex:[self curImage]] valueForKey:@"completePath"]];
			[exportDCM setSeriesDescription: @"Endoscopy"];
			
			[self getWLWW:&cwl :&cww];
			[exportDCM setDefaultWWWL: cww :cwl];
			
			[exportDCM setPixelSpacing: [curPix1 pixelSpacingX] / [self scaleValue] :[curPix1 pixelSpacingX] / [self scaleValue]];
				
			[exportDCM setSliceThickness: [curPix1 sliceThickness]];
			[exportDCM setSlicePosition: [curPix1 sliceLocation]];
			
			[self orientationCorrectedToView: o];	// <- Because we do screen capture !!!!! We need to apply the rotation of the image
			
			[exportDCM setOrientation: o];
			
			NSPoint tempPt = [self ConvertFromUpLeftView2GL: NSZeroPoint]; // <- Because we do screen capture !!!!!
			[curPix1 convertPixX: tempPt.x pixY: tempPt.y toDICOMCoords: o pixelCenter: YES];
			[exportDCM setPosition: o];
			
			[exportDCM setPixelData: data samplesPerPixel:spp bitsPerSample:bpp width: width height: height];
			
			NSString *f = [exportDCM writeDCMFile: nil];
			if (f == nil)
                NSRunCriticalAlertPanel(NSLocalizedString(@"Error", nil),
                                        NSLocalizedString(@"Error during the creation of the DICOM File!", nil),
                                        NSLocalizedString(@"OK", nil),
                                        nil,
                                        nil);
			
			if (f)
				[producedFiles addObject: [NSDictionary dictionaryWithObjectsAndKeys: f, @"file", nil]];
			
			[exportDCM release];
			free( data);
		}
				
		[[NSUserDefaults standardUserDefaults] setInteger: annotCopy forKey: ANNOTATIONS_KEY];
		[[NSUserDefaults standardUserDefaults] setInteger: clutBarsCopy forKey: CLUTBARS_KEY];
		[DCMView setDefaults];
		
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
				for( NSManagedObject *im in objects)
					[im setValue: @YES forKey: @"isKeyImage"];
			}
		}
	}
	else
	{
        EndoscopyViewer *v = (EndoscopyViewer*)[[self window] windowController];
        
		[v.vrController.view exportDICOMFile:sender];
	}
}

- (NSBitmapImageRep *)bitmapImageRepForCachingDisplayInRect:(NSRect)aRect
{
	long	width, height, spp, bpp;
	unsigned char *data = [self getRawPixels:&width :&height :&spp :&bpp :YES :NO];
	NSBitmapImageRep *bits;
	bits = [[NSBitmapImageRep alloc] initWithData:[NSData dataWithBytes:data length:width*height*spp]];
	[bits autorelease];
	return bits;
}

-(unsigned char*) superGetRawPixels:(long*) width :(long*) height :(long*) spp :(long*) bpp :(BOOL) screenCapture :(BOOL) force8bits :(BOOL) removeGraphical
{
	return [super getRawPixelsWidth:width height:height spp:spp bpp:bpp screenCapture:screenCapture force8bits:force8bits removeGraphical:removeGraphical squarePixels:YES allTiles:NO allowSmartCropping:NO origin:nil spacing:nil offset: nil isSigned: nil];
}

-(unsigned char*) getRawPixels:(long*) width :(long*) height :(long*) spp :(long*) bpp :(BOOL) screenCapture :(BOOL) force8bits :(BOOL) removeGraphical
{
	if ([(EndoscopyViewer*)[[self window] windowController] exportAllViews])
		return [(EndoscopyViewer*)[[self window] windowController] getRawPixels:width :height :spp :bpp];
	else
		return [super getRawPixelsWidth:width height:height spp:spp bpp:bpp screenCapture:screenCapture force8bits:force8bits removeGraphical:removeGraphical squarePixels:YES allTiles:NO allowSmartCropping:NO origin:nil spacing:nil offset: nil isSigned: nil];
}

@end
