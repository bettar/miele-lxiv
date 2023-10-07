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

#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtc/type_ptr.hpp"

#import "GLRenderer.h"

#import "DCMPix.h"

#import "cprTypes.h"
#import "CPRStraightenedView.h"
#import "CPRGenerator.h"
#import "CPRGeneratorRequest.h"
#import "CPRVolumeData.h"
#import "CPRCurvedPath.h"
#import "CPRDisplayInfo.h"
#import "CPRMPRDCMView.h"
#import "CPRController.h"

#import "N3BezierPath.h"
#import "N3Geometry.h"
#import "N3BezierCoreAdditions.h"
#import "ROI.h"
#import "MyPoint.h"

#import "Notifications.h"
#import "StringTexture.h"
#import "NSColor+N2.h"
#import <objc/runtime.h>

#define _extraWidthFactor       1.2

extern BOOL frameZoomed;
extern int splitPosition[ 3];

#pragma mark -

@interface _CPRStraightenedViewPlaneRun : NSObject
{
    NSRange _range;
    NSMutableArray *_distances;
}

@property (nonatomic, readwrite, assign) NSRange range;
@property (nonatomic, readwrite, retain) NSMutableArray *distances;

@end

#pragma mark -

@interface N3BezierPath (CPRStraightenedViewPlaneRunAdditions)
- (id)initWithCPRStraightenedViewPlaneRun:(_CPRStraightenedViewPlaneRun *)planeRun heightPixelsPerMm:(CGFloat)pixelsPerMm;
@end

#pragma mark -

@implementation _CPRStraightenedViewPlaneRun

@synthesize range = _range;
@synthesize distances = _distances;

- (id)init
{
    if ( (self = [super init]) ) {
		_distances = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_distances release];
    _distances = nil;
    [super dealloc];
}

@end

#pragma mark -

@interface CPRStraightenedView ()

@property (nonatomic, readwrite, retain) CPRVolumeData *curvedVolumeData; // the volume data that was generated
@property (nonatomic, readwrite, retain) CPRStraightenedGeneratorRequest *lastRequest;
@property (nonatomic, readwrite, assign) BOOL drawAllNodes;
@property (nonatomic, readwrite, retain) NSMutableDictionary *mousePlanePointsInPix;

+ (NSInteger)_fusionModeForCPRViewClippingRangeMode:(MPRProjectionMode)clippingRangeMode;

- (void)_setNeedsNewRequest;
- (void)_sendNewRequestIfNeeded;
- (void)_sendNewRequest;

- (void)_sendWillEditCurvedPath;
- (void)_sendDidUpdateCurvedPath;
- (void)_sendDidEditCurvedPath;

- (void)_sendWillEditDisplayInfo;
- (void)_sendDidEditDisplayInfo;

- (void)_updateGeneratedHeight;
- (void)_adjustROIs;

- (void)_drawVerticalLines:(NSArray *)verticalLines;

- (void)_updateMousePlanePointsForViewPoint:(NSPoint)point; // this will modify _mousePlanePointsInPix and _displayInfo
- (CGFloat)_distanceToPoint:(NSPoint)point onVerticalLines:(NSArray *)verticalLines pixVector:(N3VectorPointer)closestPixVectorPtr volumeVector:(N3VectorPointer)volumeVectorPtr;
- (CGFloat)_distanceToPoint:(NSPoint)point onPlaneRuns:(NSArray *)planeRuns pixVector:(N3VectorPointer)closestPixVectorPtr volumeVector:(N3VectorPointer)volumeVectorPtr;

- (void)_drawPlaneRuns:(NSArray*)planeRuns;
- (NSArray *)_runsForPlane:(N3Plane)plane verticalLineIndexes:(NSArray **)verticalLinesHandle;
- (void)_buildVerticalLinesAndPlaneRunsForPlaneFullName:(NSString *)planeFullName;
- (void)_clearAllPlanes;
- (void)_planeSetter:(N3Plane)plane;
- (N3Plane)_planeGetter;
- (void)_slabThicknessSetter:(CGFloat)thickness;
- (CGFloat)_slabThicknessGetter;
- (void)_planeColorSetter:(NSColor *)color;
- (NSColor *)_planeColorGetter;

- (void)_osirixUpdateVolumeDataNotification:(NSNotification *)notification;

@end

#pragma mark -

@implementation CPRStraightenedView

@synthesize delegate = _delegate;
@synthesize volumeData = _volumeData;
@synthesize curvedPath = _curvedPath;
@synthesize displayInfo = _displayInfo;
@synthesize curvedVolumeData = _curvedVolumeData;
@synthesize lastRequest = _lastRequest;
@synthesize drawAllNodes = _drawAllNodes;

@dynamic orangePlane;
@dynamic purplePlane;
@dynamic bluePlane;

@dynamic orangeSlabThickness;
@dynamic purpleSlabThickness;
@dynamic blueSlabThickness;

@dynamic orangePlaneColor;
@dynamic purplePlaneColor;
@dynamic bluePlaneColor;

@synthesize mousePlanePointsInPix = _mousePlanePointsInPix;
@synthesize displayTransverseLines = _displayTransverseLines;
@synthesize displayCrossLines = _displayCrossLines;

+ (BOOL)resolveInstanceMethod:(SEL)selector
{
    NSString *methodName = NSStringFromSelector(selector);
    SEL proxySelector = NULL;
    
    if ([methodName hasPrefix:@"get"] == NO && [methodName hasPrefix:@"set"] == NO)
    {
        if ([methodName hasSuffix:@"Plane"]) {
            proxySelector = @selector(_planeGetter);
        }
        else if ([methodName hasSuffix:@"SlabThickness"]) {
            proxySelector = @selector(_slabThicknessGetter);
        }
        else if ([methodName hasSuffix:@"PlaneColor"]) {
            proxySelector = @selector(_planeColorGetter);
        }
    }
    else if ([methodName hasPrefix:@"set"])
    {
        if ([methodName hasSuffix:@"Plane:"]) {
            proxySelector = @selector(_planeSetter:);
        }
        else if ([methodName hasSuffix:@"SlabThickness:"]) {
            proxySelector = @selector(_slabThicknessSetter:);
        }
        else if ([methodName hasSuffix:@"PlaneColor:"]) {
            proxySelector = @selector(_planeColorSetter:);
        }
    }
    
    if (proxySelector) {
        IMP imp = class_getMethodImplementation([self class], proxySelector);
        const char *typeEncoding = method_getTypeEncoding(class_getInstanceMethod([self class], proxySelector));
        return class_addMethod([self class], selector, imp, typeEncoding);
    }
    
    return [super resolveInstanceMethod:selector];
}

- (void)setDisplayCrossLines:(BOOL)displayCrossLines
{
	if (displayCrossLines != _displayCrossLines) {
        _displayCrossLines = displayCrossLines;
        if (_displayCrossLines == NO) {
            [self _clearAllPlanes];
        }
        
        [self setNeedsDisplay:YES];
        [[self windowController] updateToolbarItems];
    }
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _planes = [[NSMutableDictionary alloc] init];
        _slabThicknesses = [[NSMutableDictionary alloc] init];
        _verticalLines = [[NSMutableDictionary alloc] init];
        _planeRuns = [[NSMutableDictionary alloc] init];
        _planeColors = [[NSMutableDictionary alloc] init];
		_mousePlanePointsInPix = [[NSMutableDictionary alloc] init];
		_displayCrossLines = NO;
		_displayTransverseLines = YES;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_osirixUpdateVolumeDataNotification:) name:OsirixUpdateVolumeDataNotification object:nil];
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    _generator.delegate = nil;
    [_generator release];
    _generator = nil;
    [_volumeData release];
    _volumeData = nil;
    [_curvedVolumeData release];
    _curvedVolumeData = nil;
    [_curvedPath release];
    _curvedPath = nil;
    [_displayInfo release];
    _displayInfo = nil;
    [_lastRequest release];
    _lastRequest = nil;
    [_planes release];
    _planes = nil;
    [_slabThicknesses release];
    _slabThicknesses = nil;
    [_verticalLines release];
    _verticalLines = nil;
    [_planeRuns release];
    _planeRuns = nil;
    [_planeColors release];
    _planeColors = nil;

	[self _clearAllPlanes];
	
	[_mousePlanePointsInPix release];
	_mousePlanePointsInPix = nil;
	
	[stanStringAttrib release];
	[stringTexA release];
	[stringTexB release];
	[stringTexC release];
	
    [super dealloc];
}

- (id)valueForKey:(NSString *)key
{
    NSString *planeFullName; // full plane name may include Top or Bottom before the plane name
    
    if ([key hasSuffix:@"VerticalLines"]) {
        planeFullName = [key substringToIndex:[key length] - 13];
        if ([_verticalLines valueForKey:planeFullName] == nil) {
            [self _buildVerticalLinesAndPlaneRunsForPlaneFullName:planeFullName];
        }
        return [_verticalLines objectForKey:planeFullName];    
    }
    else if ([key hasSuffix:@"PlaneRuns"]) {
        planeFullName = [key substringToIndex:[key length] - 9];
        if ([_planeRuns valueForKey:planeFullName] == nil) {
            [self _buildVerticalLinesAndPlaneRunsForPlaneFullName:planeFullName];
        }
        return [_planeRuns valueForKey:planeFullName];
    }

    return [super valueForKey:key];

}

- (void)mouseDraggedWindowLevel:(NSEvent *)event
{
	[super mouseDraggedWindowLevel: event];
	
	[[self windowController] propagateWLWW: self];
}

- (void)setDrawAllNodes:(BOOL)drawAllNodes
{
    if (drawAllNodes != _drawAllNodes) {
        _drawAllNodes = drawAllNodes;
        [self setNeedsDisplay:YES];
    }
}

- (void)setVolumeData:(CPRVolumeData *)volumeData
{
    if (volumeData != _volumeData) {
        _generator.delegate = nil;
        [_generator release];
        [_volumeData release];
        _volumeData = [volumeData retain];
        _generator = [[CPRGenerator alloc] initWithVolumeData:_volumeData];
        _generator.delegate = self;
        [self _setNeedsNewRequest];
    }
}

- (void)setCurvedPath:(CPRCurvedPath *)curvedPath
{
    if (curvedPath != _curvedPath) {
        [_curvedPath release];
        _curvedPath = [curvedPath copy];
        [self _setNeedsNewRequest];
        [self setNeedsDisplay:YES];
    }
}

- (void)setDisplayInfo:(CPRDisplayInfo *)dispalyInfo
{
	assert(dispalyInfo); // doesn't really need to be the case, but for debugging 
    if (dispalyInfo != _displayInfo) {
        [_displayInfo release];
        _displayInfo = [dispalyInfo copy];
        [self setNeedsDisplay:YES];
    }
}

- (void)setClippingRangeMode:(MPRProjectionMode)mode
{
    if (mode == _clippingRangeMode)
        return;

    _clippingRangeMode = mode;
    
    if (curDCM) {
        [self setFusion:[[self class] _fusionModeForCPRViewClippingRangeMode:_clippingRangeMode] :self.curvedVolumeData.pixelsDeep];
    }

    [self _setNeedsNewRequest];
}

- (void)setFrame:(NSRect)frameRect
{
    BOOL needsUpdate;
    
    needsUpdate = NO;
	if ( NSEqualRects( frameRect, [self frame]) == NO) {
        needsUpdate = YES;
    }

    [super setFrame: frameRect];

    if (needsUpdate) {
        [self _setNeedsNewRequest];
	}
}

- (CGFloat)generatedHeight
{
    return _generatedHeight;
}

- (void) drawTextualData:(NSRect) size :(long) annotations
{
	if (_displayTransverseLines)
	{
		float length = [_curvedPath.bezierPath length];
	
		NSMutableArray *topLeft = [curDCM.annotationsDictionary objectForKey: @"TopLeft"];
		
		length *= 0.1; // We want cm
		
		[topLeft addObject: [NSArray arrayWithObject: [NSString stringWithFormat: NSLocalizedString( @"A-B : %2.2f cm", nil), length*fabs( _curvedPath.transverseSectionPosition - _curvedPath.leftTransverseSectionPosition)]]];

        [topLeft addObject: [NSArray arrayWithObject: [NSString stringWithFormat: NSLocalizedString( @"B-C : %2.2f cm", nil), length*fabs( _curvedPath.transverseSectionPosition - _curvedPath.rightTransverseSectionPosition)]]];

        [topLeft addObject: [NSArray arrayWithObject: [NSString stringWithFormat: NSLocalizedString( @"A-C : %2.2f cm", nil), length*fabs( _curvedPath.leftTransverseSectionPosition - _curvedPath.rightTransverseSectionPosition)]]];
		
		[super drawTextualData: size :annotations];
		
		[topLeft removeLastObject];
		[topLeft removeLastObject];
		[topLeft removeLastObject];
	}
	else
        [super drawTextualData: size :annotations];
}

#pragma mark -

- (void) drawRect:(NSRect)rect
{
	if (rect.size.width <= 10)
        return;

    _processingRequest = YES;
    [self _sendNewRequestIfNeeded];
    _processingRequest = NO;
    
    [self _adjustROIs];
    [super drawRect: rect]; // It will call subDrawRect below
}

- (void)setNeedsDisplay:(BOOL)flag
{
    if (_processingRequest == NO)
        [super setNeedsDisplay:flag];
}

#pragma mark -

- (void)subDrawRect:(NSRect)rect
{
    N3Vector lineStart;
    N3Vector lineEnd;
    N3Vector cursorVector;
    N3AffineTransform pixToSubDrawRectTransform;
    CGFloat relativePosition;
    CGFloat draggedPosition;
    CGFloat transverseSectionPosition;
    CGFloat leftTransverseSectionPosition;
    CGFloat rightTransverseSectionPosition;
    CGFloat pixelsPerMm;
	NSColor *planeColor;

    renderer_enable_blend_smooth();
    renderer_set_point_size( 12 * self.window.backingScaleFactor);
	
    pixToSubDrawRectTransform = [self pixToSubDrawRectTransform];
    pixelsPerMm = (CGFloat)curDCM.pwidth/[_curvedPath.bezierPath length];

#pragma mark cross lines
    
    if (_displayCrossLines) {
        for (NSString *planeName in _planes) {
            planeColor = [self valueForKey:[planeName stringByAppendingString:@"PlaneColor"]];
            
            [self setShaderProgramForLineWidth: 2.0 * self.window.backingScaleFactor];

            // draw planes
            renderer_set_rgba([planeColor redComponent], [planeColor greenComponent], [planeColor blueComponent], [planeColor alphaComponent]);
            [self _drawPlaneRuns:[self valueForKey:[planeName stringByAppendingString:@"PlaneRuns"]]];
            [self _drawVerticalLines:[self valueForKey:[planeName stringByAppendingString:@"VerticalLines"]]];

            [self setShaderProgramForLineWidth: 1.0 * self.window.backingScaleFactor];

            [self _drawPlaneRuns:[self valueForKey:[planeName stringByAppendingString:@"TopPlaneRuns"]]];
            [self _drawPlaneRuns:[self valueForKey:[planeName stringByAppendingString:@"BottomPlaneRuns"]]];
            [self _drawVerticalLines:[self valueForKey:[planeName stringByAppendingString:@"TopVerticalLines"]]];
            [self _drawVerticalLines:[self valueForKey:[planeName stringByAppendingString:@"BottomVerticalLines"]]];
        }
    }
    
#pragma mark green hor. centerline
	
	lineStart = N3VectorMake(0,             (CGFloat)curDCM.pheight/2.0, 0);
    lineEnd   = N3VectorMake(curDCM.pwidth, (CGFloat)curDCM.pheight/2.0, 0);
    
    lineStart = N3VectorApplyTransform(lineStart, pixToSubDrawRectTransform);
    lineEnd = N3VectorApplyTransform(lineEnd, pixToSubDrawRectTransform);
    
    glm::vec2 pStart(lineStart.x, lineStart.y);
    glm::vec2 pEnd(lineEnd.x, lineEnd.y);
    NSMutableArray *pArray = [NSMutableArray array];
    [pArray addObject: [NSValue valueWithBytes:&pStart objCType:@encode(glm::vec2)]];
    [pArray addObject: [NSValue valueWithBytes:&pEnd objCType:@encode(glm::vec2)]];

    [self setShaderProgramForLineWidth: 2.0 * self.window.backingScaleFactor];
    renderer_set_rgba(0.0, 1.0, 0.0, 0.2); // green 0.2
    renderer_drawLine_xy([pArray copy], GL_LINES);
    
#pragma mark green (alpha 0.8) point mouse position

#ifndef WITH_OPENGL_32
    // Original code (refactored). Maybe not the bset place to put it here
    [self setShaderProgramOverlay];
    renderer_set_rgba(0.0, 1.0, 0.0, 0.8); // green 0.8
#endif

    if ([[self windowController] displayMousePosition] == YES &&
        _displayInfo.mouseCursorHidden == NO)
	{
        cursorVector = N3VectorMake(curDCM.pwidth * _displayInfo.mouseCursorPosition,
                                    (CGFloat)curDCM.pheight/2.0,
                                    0);
        cursorVector = N3VectorApplyTransform(cursorVector, pixToSubDrawRectTransform);

        NSMutableArray *pArray = [NSMutableArray array];
        glm::vec2 a(cursorVector.x, cursorVector.y);
        [pArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];

#ifdef WITH_OPENGL_32
        [self setShaderProgramOverlay_withMode_Point];
        renderer_set_rgba(0.0, 1.0, 0.0, 0.8); // green 0.8
#else
        CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
        glEnable(GL_POINT_SMOOTH);
#endif
        renderer_set_point_size(8 * self.window.backingScaleFactor);
        renderer_drawPoints([pArray copy]);
    }
    
#pragma mark red line strip, dragged position

    if (_displayInfo.draggedPositionHidden == NO)
	{
        draggedPosition = _displayInfo.draggedPosition;
        lineStart = N3VectorApplyTransform(N3VectorMake((CGFloat)curDCM.pwidth*draggedPosition, 0, 0), pixToSubDrawRectTransform);
        lineEnd   = N3VectorApplyTransform(N3VectorMake((CGFloat)curDCM.pwidth*draggedPosition, curDCM.pheight, 0), pixToSubDrawRectTransform);
        
        const int nPoints = 2;
        glm::vec2 pA[nPoints];
        pA[0] = glm::vec2(lineStart.x, lineStart.y);
        pA[1] = glm::vec2(lineEnd.x, lineEnd.y);
        
        NSMutableArray *pArray = [NSMutableArray array];
        for (int i=0; i<nPoints; i++)
            [pArray addObject: [NSValue valueWithBytes:&pA[i] objCType:@encode(glm::vec2)]];

        [self setShaderProgramForLineWidth: 2.0 * self.window.backingScaleFactor];
        renderer_set_rgba(1.0, 0.0, 0.0, 1.0); // red
        renderer_drawLine_xy([pArray copy], GL_LINE_STRIP);  // TODO consolidate
	}
    
	float exportTransverseSliceInterval = 0;
	
	if ([[self windowController] exportSequenceType] == CPRSeriesExportSequenceType &&
        [[self windowController] exportSeriesType] == CPRTransverseViewsExportSeriesType)
    {
	   exportTransverseSliceInterval = [[self windowController] exportTransverseSliceInterval];
    }
	   
#pragma mark yellow vertical lines (export transverse slice)

	if (exportTransverseSliceInterval > 0)
	{
        [self setShaderProgramForLineWidth: 2.0 * self.window.backingScaleFactor];
		renderer_set_rgba(1.0, 1.0, 0.0, 1.0); // yellow
		
		N3MutableBezierPath *flattenedPath = [[_curvedPath.bezierPath mutableCopy] autorelease];
		[flattenedPath subdivide:N3BezierDefaultSubdivideSegmentLength];
		[flattenedPath flatten:N3BezierDefaultFlatness];
		
		float curveLength = [flattenedPath length];
		int noOfFrames = ( curveLength / exportTransverseSliceInterval);
		noOfFrames++;
		
		float startingDistance = curveLength - (noOfFrames-1) * exportTransverseSliceInterval;
		startingDistance /= 2;
		
        CPRTransverseView *t = [[self windowController] middleTransverseView];
        CGFloat transverseWidth = (float)t.curDCM.pwidth/t.pixelsPerMm;
        transverseWidth /= self.pixelSpacingY;
        
        CGFloat topEdge    = curDCM.pheight/2. - transverseWidth/2.;
        CGFloat bottomEdge = curDCM.pheight/2. + transverseWidth/2.;

        for (int i = 0; i < noOfFrames; i++)
		{
			transverseSectionPosition = (startingDistance + ((float) i * exportTransverseSliceInterval)) / (float) _curvedPath.bezierPath.length;
			lineStart = N3VectorApplyTransform(N3VectorMake((CGFloat)curDCM.pwidth*transverseSectionPosition, topEdge, 0), pixToSubDrawRectTransform);
			lineEnd = N3VectorApplyTransform(N3VectorMake((CGFloat)curDCM.pwidth*transverseSectionPosition, bottomEdge, 0), pixToSubDrawRectTransform);

            {
            const int nPoints = 2;
            glm::vec2 pA[nPoints];
            pA[0] = glm::vec2(lineStart.x, lineStart.y);
            pA[1] = glm::vec2(lineEnd.x, lineEnd.y);
            
            NSMutableArray *pArray = [NSMutableArray array];
            for (int i=0; i<nPoints; i++)
                [pArray addObject: [NSValue valueWithBytes:&pA[i] objCType:@encode(glm::vec2)]];

            renderer_drawLine_xy([pArray copy], GL_LINE_STRIP); // TODO consolidate
            }
		}
	}
	else if (_displayTransverseLines)
	{
#pragma mark transverse line B (middle, thicker)
		
        CPRTransverseView *t = [[self windowController] middleTransverseView];
        CGFloat transverseWidth = (float)t.curDCM.pwidth/t.pixelsPerMm;
        transverseWidth /= self.pixelSpacingY;
        
		// Draw the transverse section lines
        [self setShaderProgramForLineWidth: 2.0 * self.window.backingScaleFactor];
        renderer_set_rgba(1.0, 1.0, 0.0, 1.0);  // yellow

		transverseSectionPosition = _curvedPath.transverseSectionPosition;

        CGFloat topEdge    = curDCM.pheight/2. - transverseWidth/2.;
        CGFloat bottomEdge = curDCM.pheight/2. + transverseWidth/2.;

        N3Vector lineBStart = N3VectorApplyTransform(N3VectorMake((CGFloat)curDCM.pwidth*transverseSectionPosition, topEdge, 0), pixToSubDrawRectTransform);

		N3Vector lineBEnd = N3VectorApplyTransform(N3VectorMake((CGFloat)curDCM.pwidth*transverseSectionPosition, bottomEdge, 0), pixToSubDrawRectTransform);

        {
            const int nPoints = 2;
            glm::vec2 pA[nPoints];
            pA[0] = glm::vec2(lineBStart.x, lineBStart.y);
            pA[1] = glm::vec2(lineBEnd.x, lineBEnd.y);
            
            NSMutableArray *pArray = [NSMutableArray array];
            for (int i=0; i<nPoints; i++)
                [pArray addObject: [NSValue valueWithBytes:&pA[i] objCType:@encode(glm::vec2)]];

            renderer_drawLine_xy([pArray copy], GL_LINE_STRIP); // TODO consolidate
        }
				
#pragma mark transverse line A (left)

		leftTransverseSectionPosition = _curvedPath.leftTransverseSectionPosition;

		N3Vector lineAStart = N3VectorApplyTransform(N3VectorMake((CGFloat)curDCM.pwidth*leftTransverseSectionPosition, topEdge, 0), pixToSubDrawRectTransform);

		N3Vector lineAEnd = N3VectorApplyTransform(N3VectorMake((CGFloat)curDCM.pwidth*leftTransverseSectionPosition, bottomEdge, 0), pixToSubDrawRectTransform);

        [self setShaderProgramForLineWidth: 1.0 * self.window.backingScaleFactor];
        renderer_set_rgba(1.0, 1.0, 0.0, 1.0);  // yellow redefine it because it could be a different shader program

        {
            const int nPoints = 2;
            glm::vec2 pA[nPoints];
            pA[0] = glm::vec2(lineAStart.x, lineAStart.y);
            pA[1] = glm::vec2(lineAEnd.x, lineAEnd.y);
            
            NSMutableArray *pArray = [NSMutableArray array];
            for (int i=0; i<nPoints; i++)
                [pArray addObject: [NSValue valueWithBytes:&pA[i] objCType:@encode(glm::vec2)]];

            renderer_drawLine_xy([pArray copy], GL_LINE_STRIP); // TODO consolidate
        }
		
#pragma mark transverse line C (right)

		rightTransverseSectionPosition = _curvedPath.rightTransverseSectionPosition;

		N3Vector lineCStart = N3VectorApplyTransform(N3VectorMake((CGFloat)curDCM.pwidth*rightTransverseSectionPosition, topEdge, 0), pixToSubDrawRectTransform);

		N3Vector lineCEnd = N3VectorApplyTransform(N3VectorMake((CGFloat)curDCM.pwidth*rightTransverseSectionPosition, bottomEdge, 0), pixToSubDrawRectTransform);

        {
            const int nPoints = 2;
            glm::vec2 pA[nPoints];
            pA[0] = glm::vec2(lineCStart.x, lineCStart.y);
            pA[1] = glm::vec2(lineCEnd.x, lineCEnd.y);
            
            NSMutableArray *pArray = [NSMutableArray array];
            for (int i=0; i<nPoints; i++)
                [pArray addObject: [NSValue valueWithBytes:&pA[i] objCType:@encode(glm::vec2)]];

            renderer_drawLine_xy([pArray copy], GL_LINE_STRIP); // TODO consolidate
        }
		
#pragma mark Text

        if (stanStringAttrib == nil)
		{
			stanStringAttrib = [[NSMutableDictionary dictionary] retain];
			[stanStringAttrib setObject:[NSFont fontWithName:@"Helvetica" size: 14.0] forKey:NSFontAttributeName];
			[stanStringAttrib setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
		}
		
		if (stringTexA == nil)
		{
			stringTexA = [[StringTexture alloc] initWithString: @"A"
                                                withAttributes:stanStringAttrib
                                                 withTextColor:[NSColor colorWithDeviceRed: 1 green: 1 blue: 0 alpha:1.0f]
                                                  withBoxColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.0f]
                                               withBorderColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.0f]];
			[stringTexA setAntiAliasing: YES];
		}

        if (stringTexB == nil)
		{
			stringTexB = [[StringTexture alloc] initWithString: @"B"
                                                withAttributes:stanStringAttrib
                                                 withTextColor:[NSColor colorWithDeviceRed: 1 green: 1 blue: 0 alpha:1.0f]
                                                  withBoxColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.0f]
                                               withBorderColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.0f]];
			[stringTexB setAntiAliasing: YES];
		}

        if (stringTexC == nil)
		{
			stringTexC = [[StringTexture alloc] initWithString: @"C"
                                                withAttributes:stanStringAttrib
                                                 withTextColor:[NSColor colorWithDeviceRed: 1 green: 1 blue: 0 alpha:1.0f]
                                                  withBoxColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.0f]
                                               withBorderColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.0f]];
			[stringTexC setAntiAliasing: YES];
		}
		
#ifdef WITH_OPENGL_32
        {
            static int warnCount = 3;
            if (warnCount > 0) {
                NSLog(@"%s %d, TODO: OpenGL Core", __FUNCTION__, __LINE__);
                warnCount--;
            }
        }
#else
        CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
		glEnable(GL_TEXTURE_RECTANGLE_EXT);
#endif
		glEnable(GL_BLEND);
		glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
		
        {
            float ratio = 1;
            
            if (self.pixelSpacingX != 0 &&
                self.pixelSpacingY != 0)
            {
                ratio = self.pixelSpacingX / self.pixelSpacingY;
            }
            
#ifdef WITH_OPENGL_32
            //#define WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRAIGHT2
            #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRAIGHT2
            // Define a local model matrix and apply it locally without affecting the shader
            BOOL flipX = [self xFlipped];
            BOOL flipY = [self yFlipped];
            float signX = flipX ? -1.0 : 1.0;
            float signY = flipY ? -1.0 : 1.0;
            glm::mat4 M = glm::mat4(1.0);
            M = glm::scale(M, glm::vec3(signX * 2.0f / [self drawingFrameRect].size.width,
                                       -signY * 2.0f / [self drawingFrameRect].size.height,
                                        1.0f));
            M = glm::translate(M, glm::vec3( [self origin].x, -[self origin].y, 0.0f));
            #endif
#else
            glPushMatrix();
            glLoadIdentity();
            glScalef(2.0f / ([self xFlipped] ? -([self drawingFrameRect].size.width) : [self drawingFrameRect].size.width),
                    -2.0f / ([self yFlipped] ? -([self drawingFrameRect].size.height) : [self drawingFrameRect].size.height),
                     1.0f); // scale to port per pixel scale
            glTranslatef( [self origin].x, -[self origin].y, 0.0f);
#endif
            
            [stringTexA setFlippedX: [self xFlipped] Y:[self yFlipped]];
            [stringTexB setFlippedX: [self xFlipped] Y:[self yFlipped]];
            [stringTexC setFlippedX: [self xFlipped] Y:[self yFlipped]];
            
            float quarter = -(lineAStart.y - lineAEnd.y)/3.;

            [self setShaderProgramOverlay_withMode_TextureRgba];

            NSPoint tPt;

            tPt = [self positionWithoutRotation: NSMakePoint( lineAStart.x - [stringTexA frameSize].width, quarter+lineAStart.y)];
            #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRAIGHT2
            // Apply local model transformation
            // OpenGL 2.1 (-35,-76)
            // OpenGL 4.1 (-35,-76) --> -0.08, 0.32 wrong
            glm::vec4 pTemp = M*glm::vec4(glm::vec2(tPt.x, tPt.y),0,1);
            tPt = NSMakePoint(pTemp.x, pTemp.y);
            #endif
            renderer_setTextColor(0, 0, 0, 1);
            [stringTexA drawAtPoint:NSMakePoint(tPt.x+1, tPt.y+1) ratio: 1];
            renderer_setTextColor(1, 1, 0, 1);
            [stringTexA drawAtPoint:NSMakePoint(tPt.x, tPt.y) ratio: 1];
            
            tPt = [self positionWithoutRotation: NSMakePoint( lineBStart.x - [stringTexB frameSize].width, quarter+lineBStart.y)];
            renderer_setTextColor(0, 0, 0, 1);
            [stringTexB drawAtPoint:NSMakePoint(tPt.x+1, tPt.y+1) ratio: 1];
            renderer_setTextColor(1, 1, 0, 1);
            [stringTexB drawAtPoint:NSMakePoint(tPt.x, tPt.y) ratio: 1];
            
            tPt = [self positionWithoutRotation: NSMakePoint( lineCStart.x - [stringTexC frameSize].width, quarter+lineCStart.y)];
            renderer_setTextColor(0, 0, 0, 1);
            [stringTexC drawAtPoint:NSMakePoint(tPt.x+1, tPt.y+1) ratio: 1];
            renderer_setTextColor(1, 1, 0, 1);
            [stringTexC drawAtPoint:NSMakePoint(tPt.x, tPt.y) ratio: 1];

#ifndef WITH_OPENGL_32
            glPopMatrix();
#endif
        }
        
#ifdef WITH_OPENGL_32
        // TODO:
#else
		glDisable(GL_TEXTURE_RECTANGLE_EXT);
#endif
	}
	
	if ([[self windowController] displayMousePosition] == YES)
	{
#pragma mark Points on the plane (plane color), size 8

#ifdef WITH_OPENGL_32
        [self setShaderProgramOverlay_withMode_Point]; // Added
#else
        CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
        glEnable(GL_POINT_SMOOTH);
#endif
        renderer_set_point_size(8 * self.window.backingScaleFactor);

        NSMutableArray *pArray = [NSMutableArray array];
        for (NSString *planeName in _mousePlanePointsInPix)
		{
			planeColor = [self valueForKey:[NSString stringWithFormat:@"%@PlaneColor", planeName]];
            renderer_set_rgba([planeColor redComponent],
                              [planeColor greenComponent],
                              [planeColor blueComponent],
                              [planeColor alphaComponent]);

			cursorVector = N3VectorApplyTransform([[_mousePlanePointsInPix objectForKey:planeName] N3VectorValue],
                                                  pixToSubDrawRectTransform);

            glm::vec2 a(cursorVector.x, cursorVector.y);
            [pArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];
		}

        renderer_drawPoints([pArray copy]); // 1 point

#pragma mark yellow point, size 8

        if (_displayInfo.mouseTransverseSection != CPR_TRANSVERSE_VIEW_SECTION_NONE)
        {
            switch (_displayInfo.mouseTransverseSection)
            {
                case CPR_TRANSVERSE_VIEW_SECTION_LEFT:
                    relativePosition = _curvedPath.leftTransverseSectionPosition;
                    break;
                    
                case CPR_TRANSVERSE_VIEW_SECTION_CENTER:
                    relativePosition = _curvedPath.transverseSectionPosition;
                    break;
                    
                case CPR_TRANSVERSE_VIEW_SECTION_RIGHT:
                    relativePosition = _curvedPath.rightTransverseSectionPosition;
                    break;
                    
                default:
                    relativePosition = 0;
                    break;
            }
            
            cursorVector = N3VectorMake((CGFloat)curDCM.pwidth*relativePosition,
                                        ((CGFloat)curDCM.pheight/2.0)+(_displayInfo.mouseTransverseSectionDistance*pixelsPerMm),
                                        0);
            cursorVector = N3VectorApplyTransform(cursorVector, pixToSubDrawRectTransform);

            NSMutableArray *pArray = [NSMutableArray array];
            glm::vec2 a(cursorVector.x, cursorVector.y);
            [pArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];

#ifndef WITH_OPENGL_32
            glEnable(GL_POINT_SMOOTH);
#endif
            glPointSize(8 * self.window.backingScaleFactor);
            renderer_set_rgba(1.0, 1.0, 0.0, 1.0); // yellow
            renderer_drawPoints([pArray copy]); // 1 point
        }
    }
	
#pragma mark all curved path nodes
    
    if (_drawAllNodes)
	{
#ifdef WITH_OPENGL_32
        [self setShaderProgramOverlay_withMode_Point]; // Added
#else
        CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
        glEnable(GL_POINT_SMOOTH);
#endif
        renderer_set_point_size(8 * self.window.backingScaleFactor);

        for (int i = 0; i < [_curvedPath.nodes count]; i++)
		{
            relativePosition = [_curvedPath relativePositionForNodeAtIndex:i];
            cursorVector = N3VectorMake(curDCM.pwidth * relativePosition, (CGFloat)curDCM.pheight/2.0, 0);
            cursorVector = N3VectorApplyTransform(cursorVector, pixToSubDrawRectTransform);
            
            if (_displayInfo.hoverNodeHidden == NO &&
                _displayInfo.hoverNodeIndex == i)
            {
                renderer_set_rgba(1.0, 0.5, 0.0, 1.0); // yellowish red
            }
            else
            {
                renderer_set_rgba(1.0, 0.0, 0.0, 1.0); // red
            }

            {
                NSMutableArray *pArray = [NSMutableArray array];
                glm::vec2 a(cursorVector.x, cursorVector.y);
                [pArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];

                renderer_drawPoints([pArray copy]); // 1 point at a time. TODO consolidate
            }
        }
    }
    
#pragma mark Red box bounding the subview

    // Maybe we don't need this, it will be defined later anyway
    [self setShaderProgramForLineWidth: 1.0 * self.window.backingScaleFactor];

    if ([[self window] firstResponder] == self &&
        stringID == nil)
	{
#ifdef WITH_OPENGL_32
        // With the following commented in, the bounding box appears as
        // a red little cross marking the center
        //#define WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRAIGHT
        #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRAIGHT
        // Define a local model matrix and apply it locally without affecting the shader
        glm::mat4 M = glm::mat4(1.0);
        M = glm::scale(M, glm::vec3(2.0f / (xFlipped ? -drawingFrameRect.size.width : drawingFrameRect.size.width),
                                   -2.0f / (yFlipped ? -drawingFrameRect.size.height : drawingFrameRect.size.height),
                                    1.0f));
        #endif
#else
        CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
		glLoadIdentity();
		glScalef (2.0f / (xFlipped ? -drawingFrameRect.size.width : drawingFrameRect.size.width),
                 -2.0f / (yFlipped ? -drawingFrameRect.size.height : drawingFrameRect.size.height),
                  1.0f); // scale to port per pixel scale
#endif

        float heighthalf = drawingFrameRect.size.height/2;
		float widthhalf  = drawingFrameRect.size.width/2;
		
        [self setShaderProgramForLineWidth: 8.0 * self.window.backingScaleFactor];
        renderer_set_rgba(1.0, 0.0, 0.0, 1.0); // red

#ifdef WITH_OPENGL_32
        {
            const int nPoints = 4;
            glm::vec2 pA[nPoints];
            pA[0] = glm::vec2( -widthhalf, -heighthalf);
            pA[1] = glm::vec2( -widthhalf,  heighthalf);
            pA[2] = glm::vec2(  widthhalf,  heighthalf);
            pA[3] = glm::vec2(  widthhalf, -heighthalf);
            
            NSMutableArray *pArray = [NSMutableArray array];
            for (int i=0; i<nPoints; i++) {
                #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRAIGHT
                glm::vec4 pTemp = M*glm::vec4(pA[i],0,1);
                pA[i] = glm::vec2(pTemp.x, pTemp.y);
                #endif
                [pArray addObject: [NSValue valueWithBytes:&pA[i] objCType:@encode(glm::vec2)]];
            }

            renderer_drawLine_xy([pArray copy], GL_LINE_LOOP);
        }
#else
		glBegin(GL_LINE_LOOP);
        {
            glVertex2f(  -widthhalf, -heighthalf);
            glVertex2f(  -widthhalf, heighthalf);
            glVertex2f(  widthhalf, heighthalf);
            glVertex2f(  widthhalf, -heighthalf);
        }
		glEnd();
#endif
	}
	
    renderer_disable_blend_smooth();
}

#pragma mark - Mouse

- (void)mouseEntered:(NSEvent *)theEvent
{
	[self _sendWillEditDisplayInfo];
    _displayInfo.mouseCursorHidden = NO;
	[self _sendDidEditDisplayInfo];
    [super mouseEntered:theEvent];
}

- (void)mouseExited:(NSEvent *)theEvent
{
	[self _sendWillEditDisplayInfo];
    _displayInfo.mouseCursorHidden = YES;
	[_displayInfo clearAllMouseVectors];
    _displayInfo.mouseTransverseSection = CPR_TRANSVERSE_VIEW_SECTION_NONE;
    _displayInfo.mouseTransverseSectionDistance = 0;
	[self _sendDidEditDisplayInfo];
    [_mousePlanePointsInPix removeAllObjects];
	
    self.drawAllNodes = NO;
    
    [self setNeedsDisplay:YES];
    
    [super mouseExited:theEvent];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
	NSView* view = [[[theEvent window] contentView] hitTest:[theEvent locationInWindow]];
	
	if( view == self)
	{
		NSPoint viewPoint;
		N3Vector pixVector;
		N3Line line;
		BOOL overNode;
		NSInteger hoverNodeIndex;
		CGFloat relativePosition;
        CGFloat distance;
        CGFloat minDistance;
		
		viewPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
		
		if( NSPointInRect( viewPoint, [self bounds]) == NO)
			return;
		
		pixVector = N3VectorApplyTransform(N3VectorMakeFromNSPoint(viewPoint), [self viewToPixTransform]);
		
		if (NSPointInRect(viewPoint, self.bounds) && curDCM.pwidth > 0) {
			[self _sendWillEditDisplayInfo];
			_displayInfo.mouseCursorPosition = MIN(MAX(pixVector.x/(CGFloat)curDCM.pwidth, 0.0), 1.0);
			[self setNeedsDisplay:YES];
		
			[self _updateMousePlanePointsForViewPoint:viewPoint];  // this will modify _mousePlanePointsInPix and _displayInfo
			
            // test to see if the mouse is near a trasverse line
            _displayInfo.mouseTransverseSection = CPR_TRANSVERSE_VIEW_SECTION_NONE;
            _displayInfo.mouseTransverseSectionDistance = 0.0;
            if (_displayTransverseLines) {
                distance = ABS(pixVector.x - _curvedPath.leftTransverseSectionPosition*(CGFloat)curDCM.pwidth);
                minDistance = distance;
                if (distance < 20.0) {
                    _displayInfo.mouseTransverseSection = CPR_TRANSVERSE_VIEW_SECTION_LEFT;
                    _displayInfo.mouseTransverseSectionDistance = (pixVector.y - ((CGFloat)curDCM.pheight/2.0))*([_curvedPath.bezierPath length]/(CGFloat)curDCM.pwidth);
                }
                distance = ABS(pixVector.x - _curvedPath.rightTransverseSectionPosition*(CGFloat)curDCM.pwidth);
                if (distance < 20.0 && distance < minDistance) {
                    _displayInfo.mouseTransverseSection = CPR_TRANSVERSE_VIEW_SECTION_RIGHT;
                    _displayInfo.mouseTransverseSectionDistance = (pixVector.y - ((CGFloat)curDCM.pheight/2.0))*([_curvedPath.bezierPath length]/(CGFloat)curDCM.pwidth);
                    minDistance = distance;
                }
                distance = ABS(pixVector.x - _curvedPath.transverseSectionPosition*(CGFloat)curDCM.pwidth);
                if (distance < 20.0 && distance < minDistance) {
                    _displayInfo.mouseTransverseSection = CPR_TRANSVERSE_VIEW_SECTION_CENTER;
                    _displayInfo.mouseTransverseSectionDistance = (pixVector.y - ((CGFloat)curDCM.pheight/2.0))*([_curvedPath.bezierPath length]/(CGFloat)curDCM.pwidth);
                }
            }            
            
			line = N3LineMake(N3VectorMake(0, (CGFloat)curDCM.pheight / 2.0, 0), N3VectorMake(1, 0, 0));
			line = N3LineApplyTransform(line, N3AffineTransformInvert([self viewToPixTransform]));
			
			if (N3VectorDistanceToLine(N3VectorMakeFromNSPoint(viewPoint), line) < 20.0) {
				self.drawAllNodes = YES;
			}
            else {
				self.drawAllNodes = NO;
			}
			
			overNode = NO;
			hoverNodeIndex = 0;
			if (self.drawAllNodes) {
				for (NSInteger i = 0; i < [_curvedPath.nodes count]; i++) {
					relativePosition = [_curvedPath relativePositionForNodeAtIndex:i];
					
					if (N3VectorDistance(N3VectorMakeFromNSPoint(viewPoint),
										  N3VectorApplyTransform(N3VectorMake((CGFloat)curDCM.pwidth*relativePosition, (CGFloat)curDCM.pheight/2.0, 0), N3AffineTransformInvert([self viewToPixTransform]))) < 10.0) {
						overNode = YES;
						hoverNodeIndex = i;
						break;
					}
				}
				
				if (overNode) {
					if (_displayInfo.hoverNodeHidden == YES || _displayInfo.hoverNodeIndex != hoverNodeIndex) {
						_displayInfo.hoverNodeHidden = NO;
						_displayInfo.hoverNodeIndex = hoverNodeIndex;
					}
				}
                else {
					if (_displayInfo.hoverNodeHidden == NO) {
						_displayInfo.hoverNodeHidden = YES;
						_displayInfo.hoverNodeIndex = 0;
					}
				}
			}
			
			[self _sendDidEditDisplayInfo];
		}
		
		float exportTransverseSliceInterval = 0;
		
		if( [[self windowController] exportSequenceType] == CPRSeriesExportSequenceType && [[self windowController] exportSeriesType] == CPRTransverseViewsExportSeriesType)
			exportTransverseSliceInterval = [[self windowController] exportTransverseSliceInterval];
		
		
		if( curDCM.pwidth != 0 && exportTransverseSliceInterval == 0 && _displayTransverseLines && ((ABS((pixVector.x/curDCM.pwidth) - _curvedPath.transverseSectionPosition)*curDCM.pwidth < 5.0) || (ABS((pixVector.x/curDCM.pwidth) - _curvedPath.leftTransverseSectionPosition)*curDCM.pwidth < 10.0) || (ABS((pixVector.x/curDCM.pwidth) - _curvedPath.rightTransverseSectionPosition)*curDCM.pwidth < 10.0)))
		{
			if( [theEvent type] == NSLeftMouseDragged || [theEvent type] == NSLeftMouseDown)
				[[NSCursor closedHandCursor] set];
			else
				[[NSCursor openHandCursor] set];
		}
		else
		{
			[cursor set];
			
			[super mouseMoved:theEvent];
		}
	}
	else
	{
		[view mouseMoved:theEvent];
	}
}


- (void)mouseDown:(NSEvent *)event
{
    NSPoint viewPoint;
    N3Vector pixVector;
    CGFloat pixWidth;
    CGFloat relativePosition;
    
    viewPoint = [self convertPoint:[event locationInWindow] fromView:nil];
    pixVector = N3VectorApplyTransform(N3VectorMakeFromNSPoint(viewPoint), [self viewToPixTransform]);
    pixWidth = curDCM.pwidth;
    _clickedNode = NO;
    
    if (pixWidth == 0.0) {
        [super mouseDown:event];
        return;
    }
	
	float exportTransverseSliceInterval = 0;
	
	if ( [[self windowController] exportSequenceType] == CPRSeriesExportSequenceType && [[self windowController] exportSeriesType] == CPRTransverseViewsExportSeriesType)
		exportTransverseSliceInterval = [[self windowController] exportTransverseSliceInterval];
	
    if ( exportTransverseSliceInterval == 0 && _displayTransverseLines && (ABS((pixVector.x/pixWidth) - _curvedPath.transverseSectionPosition)*pixWidth < 5.0))
	{
		[self _sendWillEditCurvedPath];
        _draggingTransverse = YES;
		[self mouseMoved: event];
    }
	else if( exportTransverseSliceInterval == 0 && _displayTransverseLines && ((ABS((pixVector.x/pixWidth) - _curvedPath.leftTransverseSectionPosition)*pixWidth < 10.0) ||  (ABS((pixVector.x/pixWidth) - _curvedPath.rightTransverseSectionPosition)*pixWidth < 10.0)))
	{
		[self _sendWillEditCurvedPath];
        _draggingTransverseSpacing = YES;
		[self mouseMoved: event];
    }
	else
	{
        for (NSInteger i = 0; i < [_curvedPath.nodes count]; i++)
		{
            relativePosition = [_curvedPath relativePositionForNodeAtIndex:i];
            
            if (N3VectorDistance(N3VectorMakeFromNSPoint(viewPoint),
                                  N3VectorApplyTransform(N3VectorMake((CGFloat)curDCM.pwidth*relativePosition, (CGFloat)curDCM.pheight/2.0, 0), N3AffineTransformInvert([self viewToPixTransform]))) < 10.0) {
                if ([_delegate respondsToSelector:@selector(CPRView:setCrossCenter:)]) {
                    [_delegate CPRView: [[self windowController] mprView1] setCrossCenter:[[_curvedPath.nodes objectAtIndex:i] N3VectorValue]];
                }
                _clickedNode = YES;
                break;
            }
        }
        if (_clickedNode == NO)
		{
			int clickCount = 1;
			
			@try
			{
				if( [event type] ==	NSLeftMouseDown || [event type] ==	NSRightMouseDown || [event type] ==	NSLeftMouseUp || [event type] == NSRightMouseUp)
					clickCount = [event clickCount];
			}
			@catch (NSException * e)
			{
				clickCount = 1;
			}
			
			if( clickCount == 2)
			{
				NSPoint tempPt = [self convertPoint: [event locationInWindow] fromView: nil];
				tempPt = [self ConvertFromNSView2GL:tempPt];
				
				CPRController *windowController = [self windowController];
				
				ToolMode tool = [self getTool: event];
				
				if( [self roiTool: tool] && [self clickInROI: tempPt])
				{
					[[self windowController] roiGetInfo: self];
				}
				else if( frameZoomed == NO)
				{
					splitPosition[0] = NSMaxX([[windowController mprView1] frame]);	// vert

                    splitPosition[1] = NSMaxY([[windowController mprView1] frame]);	// hori12
					splitPosition[2] = NSMaxY([[windowController mprView3] frame]);	// horiz2
					
					frameZoomed = YES;
					
					[windowController.verticalSplit setPosition: [windowController.verticalSplit minPossiblePositionOfDividerAtIndex: 0] ofDividerAtIndex: 0];
					[windowController.horizontalSplit1 setPosition: [windowController.horizontalSplit1 minPossiblePositionOfDividerAtIndex: 0] ofDividerAtIndex: 0];
					[windowController.horizontalSplit2 setPosition: [windowController.horizontalSplit2 minPossiblePositionOfDividerAtIndex: 0] ofDividerAtIndex: 0];
				}
				else
				{
					frameZoomed = NO;
					[windowController.verticalSplit setPosition: splitPosition[ 0] ofDividerAtIndex: 0];
					[windowController.horizontalSplit1 setPosition: splitPosition[ 1] ofDividerAtIndex: 0];
					[windowController.horizontalSplit2 setPosition: splitPosition[ 2] ofDividerAtIndex: 0];
                    
                    [windowController.mprView1 restoreCamera];
                    windowController.mprView1.camera.forceUpdate = YES;
                    [windowController.mprView1 updateViewMPR];
                    
                    [windowController.mprView2 restoreCamera];
                    windowController.mprView2.camera.forceUpdate = YES;
                    [windowController.mprView2 updateViewMPR];
                    
                    [windowController.mprView3 restoreCamera];
                    windowController.mprView3.camera.forceUpdate = YES;
                    [windowController.mprView3 updateViewMPR];
				}
			}
			else
			{
				if( [self roiTool: currentTool])
				{
					if( currentTool != tText && currentTool != tArrow)
						currentTool = tMeasure;
				}
				
				[super mouseDown:event];
			}
        }
    }
}

- (void)mouseDragged:(NSEvent *)event
{
    NSPoint viewPoint;
    N3Vector pixVector;
    CGFloat relativePosition;
    CGFloat pixWidth;
    
	if( _clickedNode)
		return;
	
    viewPoint = [self convertPoint:[event locationInWindow] fromView:nil];
    pixVector = N3VectorApplyTransform(N3VectorMakeFromNSPoint(viewPoint), [self viewToPixTransform]);
    pixWidth = curDCM.pwidth;
    
    if (pixWidth == 0.0) {
        [super mouseDragged:event];
        return;
    }
    
    if (_draggingTransverse)
	{
        relativePosition = pixVector.x/pixWidth;
        _curvedPath.transverseSectionPosition = MAX(MIN(relativePosition, 1.0), 0.0);
		[self _sendDidUpdateCurvedPath];

		[self _sendWillEditDisplayInfo];
        _displayInfo.mouseCursorPosition = pixVector.x/pixWidth;
		[self _sendDidEditDisplayInfo];

		[self setNeedsDisplay:YES];
		[self mouseMoved: event];
    }
	else if (_draggingTransverseSpacing)
	{
        _curvedPath.transverseSectionSpacing = ABS(pixVector.x/pixWidth-_curvedPath.transverseSectionPosition)*[_curvedPath.bezierPath length];
		[self _sendDidUpdateCurvedPath];

		[self _sendWillEditDisplayInfo];
        _displayInfo.mouseCursorPosition = pixVector.x/pixWidth;
		[self _sendDidEditDisplayInfo];
        [self setNeedsDisplay:YES];
		[self mouseMoved: event];
    }
	else
	{
		[self _sendWillEditDisplayInfo];
        _displayInfo.mouseCursorPosition = pixVector.x/pixWidth;
		[self _sendDidEditDisplayInfo];

        [super mouseDragged:event];
    }
}

- (void)mouseUp:(NSEvent *)event
{
	if (_draggingTransverse) {
		_draggingTransverse = NO;
		[self _sendDidEditCurvedPath];
	} else if (_draggingTransverseSpacing) {
		_draggingTransverseSpacing = NO;
		[self _sendDidEditCurvedPath];
	}
    
    [super mouseUp:event];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
	// Scroll/Move transverse lines
	if( [theEvent modifierFlags] & NSEventModifierFlagOption)
	{
		CGFloat transverseSectionPosition = MIN(MAX(_curvedPath.transverseSectionPosition + [theEvent deltaY] * .002, 0.0), 1.0); 
		
		[self _sendWillEditCurvedPath];
		_curvedPath.transverseSectionPosition = transverseSectionPosition;
		[self _sendDidEditCurvedPath];
		
		[self _setNeedsNewRequest];
		[self setNeedsDisplay: YES];
	}
	
	// Scroll/Move transverse lines
	else if( [theEvent modifierFlags] & NSEventModifierFlagCommand)
	{
        float factor = 0.4;
        
        if( curDCM.pixelSpacingX)
            factor = curDCM.pixelSpacingX;
        
		CGFloat transverseSectionSpacing = MIN(MAX(_curvedPath.transverseSectionSpacing + [theEvent deltaY] * factor, 0.0), 300);
		
		[self _sendWillEditCurvedPath];
		_curvedPath.transverseSectionSpacing = transverseSectionSpacing;
		[self _sendDidEditCurvedPath];
		
		[self _setNeedsNewRequest];
		[self setNeedsDisplay: YES];
	}
	else
	{
		N3Vector initialNormal;
		CGFloat angle;
		
		angle = [theEvent deltaY] * (M_PI/180);
		
		initialNormal = _curvedPath.initialNormal;
		initialNormal = N3VectorApplyTransform(initialNormal, N3AffineTransformMakeRotationAroundVector(angle, [_curvedPath.bezierPath tangentAtStart]));

		[self _sendWillEditCurvedPath];
		_curvedPath.initialNormal = initialNormal;
		[self _sendDidEditCurvedPath];
		[self _setNeedsNewRequest];
	}
}

- (void) updatePresentationStateFromSeriesOnlyImageLevel: (BOOL) onlyImage
{
}

- (void)generator:(CPRGenerator *)generator didGenerateVolume:(CPRVolumeData *)volume request:(CPRGeneratorRequest *)request
{
	if( [self windowController] == nil)
		return;
		
//    static NSDate *lastDate = nil;
//    if (lastDate == nil) {
//        lastDate = [[NSDate date] retain];
//    }
//    
//    [lastDate release];
//    lastDate = [[NSDate date] retain];
    
    NSMutableArray *pixArray;
    DCMPix *newPix;
	CPRVolumeDataInlineBuffer inlineBuffer;

    [self _updateGeneratedHeight];
	
	NSPoint previousOrigin = [self origin];
	float previousScale = [self scaleValue];
	float previousRotation = [self rotation];
	int previousHeight = [curDCM pheight], previousWidth = [curDCM pwidth];
	NSData *previousROIs = [NSKeyedArchiver archivedDataWithRootObject: [self curRoiList]];
	
	[[self.curvedVolumeData retain] autorelease]; // make sure this is around long enough so that it doesn't disapear under the old DCMPix
    self.curvedVolumeData = volume;
    
    pixArray = [[NSMutableArray alloc] init];
    
    for (NSUInteger i = 0; i < self.curvedVolumeData.pixelsDeep; i++)
	{
		[self.curvedVolumeData aquireInlineBuffer:&inlineBuffer];
        newPix = [[DCMPix alloc] initWithData:(float *)CPRVolumeDataFloatBytes(&inlineBuffer) + (i*self.curvedVolumeData.pixelsWide*self.curvedVolumeData.pixelsHigh)
                                             :32
                                             :self.curvedVolumeData.pixelsWide
                                             :self.curvedVolumeData.pixelsHigh
                                             :self.curvedVolumeData.pixelSpacingX
                                             :self.curvedVolumeData.pixelSpacingY
                                             :0.0 :0.0 :0.0 :NO];

		[newPix setImageObjectID: [[[self windowController] originalPix] imageObjectID]];
		[newPix setSourceFile: [[[self windowController] originalPix] sourceFile]];
		[newPix setAnnotationsDictionary: [[[self windowController] originalPix] annotationsDictionary]];
		
		
		[pixArray addObject:newPix];
        [newPix release];
    }
	
	if( [pixArray count])
	{
		for (NSUInteger i = 0; i < [pixArray count]; i++)
			[[pixArray objectAtIndex: i] setArrayPix:pixArray :i];
		
		[self setPixels:pixArray files:NULL rois:NULL firstImage:0 level:'i' reset:YES];
		[self setScaleValueCentered: 0.8 * self.window.backingScaleFactor];
		
		//[self setWLWW:wl :ww];
		[[self windowController] propagateWLWW: [[self windowController] mprView1]];
		
		[self setFusion:[[self class] _fusionModeForCPRViewClippingRangeMode:_clippingRangeMode] :self.curvedVolumeData.pixelsDeep];
		
		if (previousWidth == [curDCM pwidth] &&
            previousHeight == [curDCM pheight])
		{
			[self setOrigin:previousOrigin];
			[self setScaleValue: previousScale];
			[self setRotation: previousRotation];
		}
		
		NSArray *roiArray = [NSKeyedUnarchiver unarchiveObjectWithData: previousROIs];
		for (ROI *r in roiArray)
		{
			r.pix = curDCM;
			[r setOriginAndSpacing :curDCM.pixelSpacingX : curDCM.pixelSpacingY :NSMakePoint( curDCM.originX, curDCM.originY) :NO :NO];
			[r setRoiView :self];
		}
		
		[[self curRoiList] addObjectsFromArray: roiArray];
		
		[self _clearAllPlanes];
		[self setNeedsDisplay:YES];
	}
	[pixArray release];
}

- (void)generator:(CPRGenerator *)generator didAbandonRequest:(CPRGeneratorRequest *)request
{
}

- (void)waitUntilPixUpdate
{
	[self _sendNewRequestIfNeeded];
	[_generator runUntilAllRequestsAreFinished];
}

+ (NSInteger)_fusionModeForCPRViewClippingRangeMode:(MPRProjectionMode)clippingRangeMode
{
    switch (clippingRangeMode)
    {
        case MPR_PROJECTION_MODE_VR:
            return 0; // not supported
            break;

        case MPR_PROJECTION_MODE_MIP:
            return 2;
            break;

        case MPR_PROJECTION_MODE_MIN_IP:
            return 3;
            break;

        case MPR_PROJECTION_MODE_MEAN:
            return 1;
            break;

        default:
            NSLog(@"%s asking for invalid clipping range mode: %d", __func__,  (int) clippingRangeMode);
            return 0;
            break;
    }
}

- (void)_sendWillEditCurvedPath
{
	if (_editingCurvedPathCount == 0) {
		if ([_delegate respondsToSelector:@selector(CPRViewWillEditCurvedPath:)]) {
			[_delegate CPRViewWillEditCurvedPath:self];
		}
	}
	_editingCurvedPathCount++;
}

- (void)_sendDidUpdateCurvedPath
{
	if ([_delegate respondsToSelector:@selector(CPRViewDidUpdateCurvedPath:)]) {
		[_delegate CPRViewDidUpdateCurvedPath:self];
	}
}

- (void)_sendDidEditCurvedPath
{
	_editingCurvedPathCount--;
	if (_editingCurvedPathCount == 0) {
		if ([_delegate respondsToSelector:@selector(CPRViewDidEditCurvedPath:)]) {
			[_delegate CPRViewDidEditCurvedPath:self];
		}
	}
}

- (void)_sendWillEditDisplayInfo
{
	if ([_delegate respondsToSelector:@selector(CPRViewWillEditDisplayInfo:)]) {
		[_delegate CPRViewWillEditDisplayInfo:self];
	}
}

- (void)_sendDidEditDisplayInfo
{
	if ([_delegate respondsToSelector:@selector(CPRViewDidEditDisplayInfo:)]) {
		[_delegate CPRViewDidEditDisplayInfo:self];
	}
}

- (void)_sendNewRequest
{
    CPRStraightenedGeneratorRequest *request;
    
    if ([_curvedPath.bezierPath elementCount] >= 3)
	{
        request = [[CPRStraightenedGeneratorRequest alloc] init];
        
        if( [[self windowController] viewsPosition] == VerticalPosition)
        {
            request.pixelsWide = [self bounds].size.height * _extraWidthFactor;
            request.pixelsHigh = [self bounds].size.width * _extraWidthFactor;
		}
        else
        {
            request.pixelsWide = [self bounds].size.width * _extraWidthFactor;
            request.pixelsHigh = [self bounds].size.height * _extraWidthFactor;
		}
        request.slabWidth = _curvedPath.thickness;

        request.slabSampleDistance = 0;
        request.bezierPath = _curvedPath.bezierPath;
        request.initialNormal = _curvedPath.initialNormal;
        request.projectionMode = _clippingRangeMode;
//        request.vertical = NO;
        
        if ([_lastRequest isEqual:request] == NO) {
			if (request.slabWidth < 2) {
				CPRVolumeData *curvedVolume;
				curvedVolume = [CPRGenerator synchronousRequestVolume:request volumeData:_generator.volumeData];
				
				[_generator runUntilAllRequestsAreFinished];
				[self generator:nil didGenerateVolume:curvedVolume request:request];
			}
            else {
				[_generator requestVolume:request];
			}

			self.lastRequest = request;
        }
        
        [request release];
    }
	else
	{
		[self setPixels: nil files:NULL rois:NULL firstImage:0 level:'i' reset:YES];
	}
	
    _needsNewRequest = NO;
}

- (void)_setNeedsNewRequest
{
    _needsNewRequest = YES;
    [self setNeedsDisplay:YES];
//	if (_needsNewRequest == NO) {
//		[self performSelector:@selector(_sendNewRequestIfNeeded) withObject:nil afterDelay:0 inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
//	}
//    _needsNewRequest = YES;
}

- (void)_sendNewRequestIfNeeded
{
    if (_needsNewRequest) {
        [self _sendNewRequest];
    }
}

- (void)_updateGeneratedHeight
{
    CGFloat newGeneratedHeight;
    
    newGeneratedHeight = ([_curvedPath.bezierPath length] / NSWidth(self.bounds)) * NSHeight(self.bounds);
    
    if (newGeneratedHeight != _generatedHeight) {
        _generatedHeight = newGeneratedHeight;
        if ([_delegate respondsToSelector:@selector(CPRViewDidChangeGeneratedHeight:)]) {
            [_delegate CPRViewDidChangeGeneratedHeight:self];
        }        
    }
}

- (void)_adjustROIs
{
	if ([self.curvedPath isPlaneMeasurable] == NO)
	{
        //NSLog(@"%s %d %@ %p", __FUNCTION__, __LINE__, NSStringFromClass([self class]), self);
		for (int i = 0; i < curRoiList.count; i++ )
		{
			ROI *r = [curRoiList objectAtIndex:i];
			if (r.type != tMeasure &&
                r.type != tText &&
                r.type != tArrow)
			{
				[[NSNotificationCenter defaultCenter] postNotificationName: OsirixRemoveROINotification object:r userInfo: nil];
				[curRoiList removeObjectAtIndex:i];
				i--;
			}
			else
				r.displayCMOrPixels = YES; // We don't want the value in pixels
		}
		
		for (ROI *c in curRoiList)
		{
			if (c.type == tMeasure)
			{
				NSMutableArray *points = c.points;
				
				NSPoint A = [[points objectAtIndex: 0] point];
				NSPoint B = [[points objectAtIndex: 1] point];
				
				if (fabs( A.x - B.x) > 4 ||
                    fabs( A.y - B.y) > 4)
				{
					if (fabs( A.x - B.x) > fabs( A.y - B.y) ||
                        A.y == [curDCM pheight] / 2)
					{
						// Horizontal length -> centered in y, and horizontal
						
						A.y = [curDCM pheight] / 2;
						B.y = [curDCM pheight] / 2;
						
						[[points objectAtIndex: 0] setPoint: A];
						[[points objectAtIndex: 1] setPoint: B];
					}
					else
					{
						// Vectical length -> vertical
						
						A.x = B.x;
						
						[[points objectAtIndex: 0] setPoint: A];
						[[points objectAtIndex: 1] setPoint: B];
					}
				}
			}
		}

#if 0 // Issue #39 it seems to cause an infinite loop
        [self setNeedsDisplay: YES];
#endif
	}
	else
	{
        //NSLog(@"%s %d %@ %p", __FUNCTION__, __LINE__, NSStringFromClass([self class]), self);
		for (ROI *r in curRoiList)
			r.displayCMOrPixels = YES;

        if ([curRoiList count] > 0)
            [self setNeedsDisplay: YES];
	}
}

- (void)_drawVerticalLines:(NSArray *)verticalLines
{
    if ([verticalLines count] == 0)
        return;
    
    double pixToSubdrawRectOpenGLTransform[16];
    N3AffineTransformGetOpenGLMatrixd([self pixToSubDrawRectTransform], pixToSubdrawRectOpenGLTransform);

#ifdef WITH_OPENGL_32
    #define WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRAIGHT4
    #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRAIGHT4
    // Define a local model matrix and apply it locally without affecting the shader
    glm::mat4 M = glm::make_mat4(pixToSubdrawRectOpenGLTransform);
    #endif
#else
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    if (cgl_ctx == nil)
        return;

    glMatrixMode(GL_MODELVIEW);
    glPushMatrix();
    glMultMatrixd(pixToSubdrawRectOpenGLTransform);
#endif

#ifdef WITH_OPENGL_32
    NSMutableArray *pArray = [NSMutableArray array];
    for (NSNumber *indexNumber in verticalLines) {
        glm::vec2 lineStart([indexNumber doubleValue], 0);
        #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRAIGHT4
        // Apply local matrix transformation
        glm::vec4 pTemp = M*glm::vec4(lineStart,0,1);
        lineStart = glm::vec2(pTemp.x, pTemp.y);
        #endif
        [pArray addObject: [NSValue valueWithBytes:&lineStart objCType:@encode(glm::vec2)]];

        glm::vec2 lineEnd([indexNumber doubleValue], curDCM.pheight);
        #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRAIGHT4
        // Apply local matrix transformation
        pTemp = M*glm::vec4(lineEnd,0,1);
        lineEnd = glm::vec2(pTemp.x, pTemp.y);
        #endif
        [pArray addObject: [NSValue valueWithBytes:&lineEnd objCType:@encode(glm::vec2)]];
    }

    renderer_drawLine_xy([pArray copy], GL_LINES);

#else
	for (NSNumber *indexNumber in verticalLines) {
		N3Vector lineStart = N3VectorMake([indexNumber doubleValue], 0, 0);
        N3Vector lineEnd = N3VectorMake([indexNumber doubleValue], curDCM.pheight, 0);
        glBegin(GL_LINE_STRIP);
        {
            glVertex2d(lineStart.x, lineStart.y);
            glVertex2d(lineEnd.x, lineEnd.y);
        }
        glEnd();
	}
#endif
    
#ifndef WITH_OPENGL_32
    glPopMatrix();
#endif
}

- (void)_drawPlaneRuns:(NSArray*)planeRuns
{
	_CPRStraightenedViewPlaneRun *planeRun;
    
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
	if (cgl_ctx == nil)
        return;
    
	CGFloat pixelsPerMm = (CGFloat)curDCM.pwidth/[_curvedPath.bezierPath length];
    CGFloat pheight_2 = (CGFloat)curDCM.pheight/2.0;
    
    double pixToSubdrawRectOpenGLTransform[16];
    N3AffineTransformGetOpenGLMatrixd([self pixToSubDrawRectTransform], pixToSubdrawRectOpenGLTransform);

#ifdef WITH_OPENGL_32
    #define WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRAIGHT3
    #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRAIGHT3
    // Define a local model matrix and apply it locally without affecting the shader
    glm::mat4 M = glm::make_mat4(pixToSubdrawRectOpenGLTransform);
    #endif
#else
    glMatrixMode(GL_MODELVIEW);
    glPushMatrix();
    glMultMatrixd(pixToSubdrawRectOpenGLTransform);
#endif

    for (planeRun in planeRuns)
    {
#ifdef WITH_OPENGL_32
        NSMutableArray *pArray = [NSMutableArray array];
        for (NSInteger i = 0; i < planeRun.range.length; i++)
        {
            N3Vector planePointVector = N3VectorMake(planeRun.range.location + i,
                                                     ([[planeRun.distances objectAtIndex:i] doubleValue] * pixelsPerMm) + pheight_2,
                                                     0);
            glm::vec2 a(planePointVector.x, planePointVector.y);
            #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRAIGHT3
            // Apply local matrix transformation
            glm::vec4 pTemp = M*glm::vec4(a,0,1);
            a = glm::vec2(pTemp.x, pTemp.y);
            #endif
            [pArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];
        }

        renderer_drawLine_xy([pArray copy], GL_LINE_STRIP);
#else
		glBegin(GL_LINE_STRIP);
        {
            for (NSInteger i = 0; i < planeRun.range.length; i++)
            {
                N3Vector planePointVector = N3VectorMake(planeRun.range.location + i,
                                                         ([[planeRun.distances objectAtIndex:i] doubleValue] * pixelsPerMm) + pheight_2,
                                                         0);
                glVertex2d(planePointVector.x, planePointVector.y);
            }
        }
		glEnd();
#endif
	}

#ifndef WITH_OPENGL_32
    glPopMatrix();
#endif
}

- (NSArray *)_runsForPlane:(N3Plane)plane verticalLineIndexes:(NSArray **)verticalLinesHandle
{
	NSInteger numVectors;
	BOOL topPointAbove;
	BOOL bottomPointAbove;
	BOOL prevBottomPointAbove;
	NSMutableArray *runs;
	NSMutableArray *verticalLines;
	CGFloat mmPerPixel;
	CGFloat halfHeight;
	CGFloat distance;
	N3VectorArray normals;
	N3VectorArray points;
	N3Vector bottom;
	N3Vector top;
	_CPRStraightenedViewPlaneRun *planeRun;
	NSRange range;
	NSInteger aboveOrBelow;
	NSInteger prevAboveOrBelow;


	points = (N3VectorArray)malloc(curDCM.pwidth * sizeof(N3Vector));
	normals = (N3VectorArray)malloc(curDCM.pwidth * sizeof(N3Vector));
	runs = [NSMutableArray array];
	planeRun = nil;

	if (verticalLinesHandle) {
		verticalLines = [NSMutableArray array];
		*verticalLinesHandle = verticalLines;
	}
    else {
		verticalLines = nil;
	}
	
	mmPerPixel = [_curvedPath.bezierPath length]/(CGFloat)curDCM.pwidth;
	halfHeight = ((CGFloat)curDCM.pheight*mmPerPixel)/2.0;
	numVectors = N3BezierCoreGetVectorInfo([_curvedPath.bezierPath N3BezierCore], [_curvedPath.bezierPath length]/(CGFloat)curDCM.pwidth, 0, _curvedPath.initialNormal, points, NULL, normals, curDCM.pwidth);
	
	for (NSInteger i = 0; i < numVectors; i++) {
		bottom = N3VectorAdd(points[i], N3VectorScalarMultiply(normals[i], -halfHeight));
		top = N3VectorAdd(points[i], N3VectorScalarMultiply(normals[i], halfHeight));
		
		bottomPointAbove = N3VectorDotProduct(plane.normal, N3VectorSubtract(bottom, plane.point)) > 0.0;
		topPointAbove = N3VectorDotProduct(plane.normal, N3VectorSubtract(top, plane.point)) > 0.0;

		if (!bottomPointAbove && !topPointAbove) {
			aboveOrBelow = -1;
		}
        else if (bottomPointAbove && topPointAbove) {
			aboveOrBelow = 1;
		}
        else {
			aboveOrBelow = 0;
		}
		
		if (i == 0) {
			prevAboveOrBelow = aboveOrBelow;
		}
		
		if (bottomPointAbove != topPointAbove) {
			if (planeRun == nil) { //start a new run
				planeRun = [[_CPRStraightenedViewPlaneRun alloc] init];
				range = planeRun.range;
				if (i != 0) {
					range.location = i-1;
					range.length = 1;
					if (prevBottomPointAbove != bottomPointAbove) {
						[planeRun.distances addObject:[NSNumber numberWithDouble:-halfHeight]];
					}
                    else {
						[planeRun.distances addObject:[NSNumber numberWithDouble:halfHeight]];
					}
				}
			}
			distance = N3VectorDotProduct(N3VectorSubtract(N3LineIntersectionWithPlane(N3LineMakeFromPoints(bottom, top), plane), points[i]), normals[i]);
			[planeRun.distances addObject:[NSNumber numberWithDouble:distance]];
			range.length++;
		}
        else {
			if (planeRun != nil) { // finish up and save the last run
				if (NSMaxRange(range) < numVectors) {
					range.length++;
					if (prevBottomPointAbove != bottomPointAbove) {
						[planeRun.distances addObject:[NSNumber numberWithDouble:-halfHeight]];
					}
                    else {
						[planeRun.distances addObject:[NSNumber numberWithDouble:halfHeight]];
					}
				}
				planeRun.range = range;
				[runs addObject:planeRun];
				[planeRun release];
				planeRun = nil;
			}
            else if (ABS(prevAboveOrBelow - aboveOrBelow) == 2) { // if we switched sides without ever getting any points, put in a vertical line
				[verticalLines addObject:[NSNumber numberWithInteger:i]];
			}
		}
		
		prevAboveOrBelow = aboveOrBelow;
		prevBottomPointAbove =bottomPointAbove;
	}
	
	if (planeRun) {
		planeRun.range = range;
		[runs addObject:planeRun];
		[planeRun release];
		planeRun = nil;	
	}
	
	free(points);
	free(normals);
	
	return runs;	
}

- (void)_updateMousePlanePointsForViewPoint:(NSPoint)point // this will modify _mousePlanePointsInPix and _displayInfo
{
	CGFloat lineDistance;
	CGFloat runDistance;
	N3Vector linePixVector;
	N3Vector lineVolumeVector;
	N3Vector runPixVector;
	N3Vector runVolumeVector;
    NSString *planeName;
    NSArray *verticalLines;
    NSArray *planeRuns;
	
	linePixVector = N3VectorZero;
	lineVolumeVector = N3VectorZero;
	runPixVector = N3VectorZero;
	runVolumeVector = N3VectorZero;
	
	[_displayInfo clearAllMouseVectors];
	[_mousePlanePointsInPix removeAllObjects];
	
    for (planeName in _planes) {
        verticalLines = [self valueForKey:[planeName stringByAppendingString:@"VerticalLines"]];
        planeRuns = [self valueForKey:[planeName stringByAppendingString:@"PlaneRuns"]];
        lineDistance = [self _distanceToPoint:point onVerticalLines:verticalLines pixVector:&linePixVector volumeVector:&lineVolumeVector];
        runDistance = [self _distanceToPoint:point onPlaneRuns:planeRuns pixVector:&runPixVector volumeVector:&runVolumeVector];
        if (MIN(lineDistance, runDistance) < 30) {
            if (lineDistance < runDistance) {
                [_mousePlanePointsInPix setObject:[NSValue valueWithN3Vector:linePixVector] forKey:planeName];
                [_displayInfo setMouseVector:lineVolumeVector forPlane:planeName];
            }
            else {
                [_mousePlanePointsInPix setObject:[NSValue valueWithN3Vector:runPixVector] forKey:planeName];
                [_displayInfo setMouseVector:runVolumeVector forPlane:planeName];
            }
        }
    }        
}

// point and distance are in view coordinates, vector is in patient coordinates closestPoint is in pixCoordinates
- (CGFloat)_distanceToPoint:(NSPoint)point onVerticalLines:(NSArray *)verticalLines pixVector:(N3VectorPointer)closestPixVectorPtr volumeVector:(N3VectorPointer)volumeVectorPtr;
{
	N3AffineTransform pixToViewTransform;
	CGFloat pixelsPerMm;
	NSNumber *indexNumber;
	N3Vector pixPointVector;
	N3Vector pixVector;
	N3Vector lineStart;
	N3Vector lineEnd;
	CGFloat relativePosition;
	CGFloat distance;
	CGFloat minDistance;
	N3Vector normalVector;
    
	pixToViewTransform = N3AffineTransformInvert([self viewToPixTransform]);
	minDistance = CGFLOAT_MAX;
	pixPointVector = N3VectorApplyTransform(N3VectorMakeFromNSPoint(point), [self viewToPixTransform]);
	pixelsPerMm = (CGFloat)curDCM.pwidth/[_curvedPath.bezierPath length];

	for (indexNumber in verticalLines) {
		lineStart = N3VectorMake([indexNumber doubleValue], 0, 0);
        lineEnd = N3VectorMake([indexNumber doubleValue], curDCM.pheight, 0);
		
		distance = N3VectorDistanceToLine(N3VectorMakeFromNSPoint(point), N3LineApplyTransform(N3LineMakeFromPoints(lineStart, lineEnd), pixToViewTransform));
		if (distance < minDistance) {
			minDistance = distance;
			if (closestPixVectorPtr) {
				pixVector = N3VectorMake([indexNumber doubleValue], pixPointVector.y, 0);
				*closestPixVectorPtr = pixVector;
			}
			
			if (volumeVectorPtr) {
				relativePosition = [indexNumber doubleValue]/(CGFloat)curDCM.pwidth;
				normalVector = [_curvedPath.bezierPath normalAtRelativePosition:relativePosition initialNormal:_curvedPath.initialNormal];
				*volumeVectorPtr = N3VectorAdd([_curvedPath.bezierPath vectorAtRelativePosition:relativePosition], N3VectorScalarMultiply(normalVector, (pixPointVector.y - (CGFloat)curDCM.pheight/2.0)/ pixelsPerMm));
			}
		}
	}
	return minDistance;
}

// point and distance are in view coordinates, vector is in patient coordinates closestPoint is in pixCoordinates
- (CGFloat)_distanceToPoint:(NSPoint)point onPlaneRuns:(NSArray *)planeRuns pixVector:(N3VectorPointer)closestPixVectorPtr volumeVector:(N3VectorPointer)volumeVectorPtr;
{
	CGFloat pixelsPerMm;
	N3Vector closeVector;
	N3Vector closestVector;
	N3Vector pointVector;
	N3Vector normalVector;
	CGFloat distance;
	CGFloat minDistance;
	CGFloat relativePosition;
	_CPRStraightenedViewPlaneRun *planeRun;
	N3MutableBezierPath *planeRunBezierPath;
	
	pointVector = N3VectorMakeFromNSPoint(point);
	pixelsPerMm = (CGFloat)curDCM.pwidth/[_curvedPath.bezierPath length];
	minDistance = CGFLOAT_MAX;
	closestVector = N3VectorZero;
    
	for (planeRun in planeRuns) {
		planeRunBezierPath = [[N3MutableBezierPath alloc] initWithCPRStraightenedViewPlaneRun:planeRun heightPixelsPerMm:pixelsPerMm];
		[planeRunBezierPath applyAffineTransform:N3AffineTransformMakeTranslation(0, (CGFloat)curDCM.pheight/2.0, 0)];
		[planeRunBezierPath applyAffineTransform:N3AffineTransformInvert([self viewToPixTransform])];
		
		N3BezierCoreRelativePositionClosestToVector([planeRunBezierPath N3BezierCore], pointVector, &closeVector, &distance);
		if (distance < minDistance) {
			minDistance = distance;
			closestVector = N3VectorApplyTransform(closeVector, [self viewToPixTransform]);
			closestVector.y -= (CGFloat)curDCM.pheight/2.0;
		}
		[planeRunBezierPath release];
		planeRunBezierPath = nil;
	}
	
	if (closestPixVectorPtr) {
		*closestPixVectorPtr = N3VectorMake(closestVector.x, closestVector.y + (CGFloat)curDCM.pheight/2.0, 0);
	}
	if (volumeVectorPtr) {
		relativePosition = closestVector.x/(CGFloat)curDCM.pwidth;
		normalVector = [_curvedPath.bezierPath normalAtRelativePosition:relativePosition initialNormal:_curvedPath.initialNormal];
		*volumeVectorPtr = N3VectorAdd([_curvedPath.bezierPath vectorAtRelativePosition:relativePosition], N3VectorScalarMultiply(normalVector, closestVector.y / pixelsPerMm));
	}

	return minDistance;
}

- (void)_buildVerticalLinesAndPlaneRunsForPlaneFullName:(NSString *)planeFullName
{
    NSString *planeName;
    CGFloat slabThickness;
    NSArray *vertLines;
    
    if ([planeFullName hasSuffix:@"Top"]) {
        planeName = [planeFullName substringToIndex:[planeFullName length] - 3];
        slabThickness = [[self valueForKey:[planeName stringByAppendingString:@"SlabThickness"]] doubleValue];
        if (slabThickness == 0) {
            return;
        }
    }
    else if ([planeFullName hasSuffix:@"Bottom"]) {
        planeName = [planeFullName substringToIndex:[planeFullName length] - 6];
        slabThickness = -[[self valueForKey:[planeName stringByAppendingString:@"SlabThickness"]] doubleValue];

        if (slabThickness == 0)
            return;
    }
    else {
        planeName = planeFullName;
        slabThickness = 0;
    }
    
    N3Plane plane = [[self valueForKey:[planeName stringByAppendingString:@"Plane"]] N3PlaneValue];
    if (N3PlaneIsValid(plane)) {
        plane.normal = N3VectorNormalize(plane.normal);
        plane.point = N3VectorAdd(plane.point, N3VectorScalarMultiply(plane.normal, slabThickness/2.0));
        NSArray *planeRuns = [self _runsForPlane:plane verticalLineIndexes:&vertLines];
        [_verticalLines setValue:vertLines forKey:planeFullName];
        [_planeRuns setValue:planeRuns forKey:planeFullName];
    }
}

- (void)_clearAllPlanes
{
    [_verticalLines removeAllObjects];
    [_planeRuns removeAllObjects];
}

- (void)_planeSetter:(N3Plane)plane
{
    NSString *selectorName = NSStringFromSelector(_cmd);
    NSString *planeName = [selectorName stringByReplacingCharactersInRange:NSMakeRange(0, 4) withString:[[selectorName substringWithRange:NSMakeRange(3, 1)] lowercaseString]];
    planeName = [planeName substringToIndex:[planeName length] - 6];
    [_verticalLines removeObjectForKey:planeName];
    [_verticalLines removeObjectForKey:[planeName stringByAppendingString:@"Top"]];
    [_verticalLines removeObjectForKey:[planeName stringByAppendingString:@"Bottom"]];
    [_planeRuns removeObjectForKey:planeName];
    [_planeRuns removeObjectForKey:[planeName stringByAppendingString:@"Top"]];
    [_planeRuns removeObjectForKey:[planeName stringByAppendingString:@"Bottom"]];

    [_planes setValue:[NSValue valueWithN3Plane:plane] forKey:planeName];
    [self setNeedsDisplay:YES];
}

- (N3Plane)_planeGetter
{
    NSString *selectorName = NSStringFromSelector(_cmd);
    NSString *planeName = [selectorName substringToIndex:[selectorName length] - 5];
    return [[_planes valueForKey:planeName] N3PlaneValue];
}

- (void)_slabThicknessSetter:(CGFloat)thickness
{
    NSString *selectorName = NSStringFromSelector(_cmd);
    NSString *planeName = [selectorName stringByReplacingCharactersInRange:NSMakeRange(0, 4) withString:[[selectorName substringWithRange:NSMakeRange(3, 1)] lowercaseString]];
    planeName = [planeName substringToIndex:[planeName length] - 14];
    [_verticalLines removeObjectForKey:planeName];
    [_planeRuns removeObjectForKey:planeName];
    [_slabThicknesses setValue:[NSNumber numberWithDouble:thickness] forKey:planeName];    
    [self setNeedsDisplay:YES];
}

- (CGFloat)_slabThicknessGetter
{
    NSString *selectorName = NSStringFromSelector(_cmd);
    NSString *planeName = [selectorName substringToIndex:[selectorName length] - 13];
    return [[_slabThicknesses valueForKey:planeName] doubleValue];
}

- (void)_planeColorSetter:(NSColor *)color
{
    NSString *selectorName = NSStringFromSelector(_cmd);
    NSString *planeName = [selectorName stringByReplacingCharactersInRange:NSMakeRange(0, 4) withString:[[selectorName substringWithRange:NSMakeRange(3, 1)] lowercaseString]];
    planeName = [planeName substringToIndex:[planeName length] - 11];
    [_planeColors setValue:color forKey:planeName];
    [self setNeedsDisplay:YES];
}

- (NSColor *)_planeColorGetter
{
    NSString *selectorName = NSStringFromSelector(_cmd);
    NSString *planeName = [selectorName substringToIndex:[selectorName length] - 10];
    
    if ([_planeColors valueForKey:planeName] == nil) {
        [_planeColors setValue:[NSColor colorWithDeviceRed:1 green:1 blue:1 alpha:1] forKey:planeName];
    }

    return [_planeColors valueForKey:planeName];
}

- (void)_osirixUpdateVolumeDataNotification:(NSNotification *)notification
{
    self.lastRequest = nil;
    [self _setNeedsNewRequest];
}

@end

#pragma mark -

@implementation N3BezierPath (CPRViewPlaneRunAdditions)

- (id)initWithCPRStraightenedViewPlaneRun:(_CPRStraightenedViewPlaneRun *)planeRun
                        heightPixelsPerMm:(CGFloat)pixelsPerMm
{
	N3MutableBezierPath *mutableBezierPath = [[N3MutableBezierPath alloc] init];

    for (NSInteger i = planeRun.range.location; i < NSMaxRange(planeRun.range); i++) {
		if (i == planeRun.range.location) {
			[mutableBezierPath moveToVector:N3VectorMake(i, [[planeRun.distances objectAtIndex:i - planeRun.range.location] doubleValue] * pixelsPerMm, 0)];
		}
        else {
			[mutableBezierPath lineToVector:N3VectorMake(i, [[planeRun.distances objectAtIndex:i - planeRun.range.location] doubleValue] * pixelsPerMm, 0)];
		}
	}
	
	[self autorelease];
	self = mutableBezierPath;
	return self;
}

@end
