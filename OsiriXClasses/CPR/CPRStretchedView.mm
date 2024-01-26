//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//
//  At the end of 2014 the project was forked from OsiriX to become Miele-LXIV
//  The original header follows:

//
//  CPRStretchedView.m
//  OsiriX
//
//  Created by Joël Spaltenstein on 6/4/11.
//  Copyright 2011 OsiriX Team. All rights reserved.
//

#import "options.h"
#import "mgl.h" // include first

#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtc/type_ptr.hpp"

#import "GLRenderer.h"

#import "CPRStretchedView.h"
#import "CPRGeneratorRequest.h"
#import "CPRVolumeData.h"
#import "DCMPix.h"
#import "CPRCurvedPath.h"
#import "CPRDisplayInfo.h"
#import "N3BezierPath.h"
#import "CPRMPRDCMView.h"
#import "N3Geometry.h"
#import "N3BezierCoreAdditions.h"
#import "CPRController.h"
#import "ROI.h"
#import "Notifications.h"
#import "StringTexture.h"
#import "NSColor+N2.h"
#import <objc/runtime.h>

#define _extraWidthFactor 1.2

extern BOOL frameZoomed;
extern int splitPosition[ 3];

@interface _CPRStretchedViewPlaneRun : NSObject
{
    NSRange _range;
    NSMutableArray *_distances;
}

@property (nonatomic, readwrite, assign) NSRange range;
@property (nonatomic, readwrite, retain) NSMutableArray *distances;

@end

#pragma mark -

@interface N3BezierPath (CPRStretchedViewPlaneRunAdditions)
- (id)initWithCPRStretchedViewPlaneRun:(_CPRStretchedViewPlaneRun *)planeRun heightPixelsPerMm:(CGFloat)pixelsPerMm;
@end

#pragma mark -

@implementation _CPRStretchedViewPlaneRun

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

@interface CPRStretchedView ()

@property (nonatomic, readwrite, retain) CPRVolumeData *curvedVolumeData; // the volume data that was generated
@property (nonatomic, readwrite, retain) CPRStretchedGeneratorRequest *lastRequest;
@property (nonatomic, readwrite, assign) BOOL drawAllNodes;
@property (nonatomic, readwrite, retain) N3BezierPath *centerlinePath;

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

- (N3BezierPath *)_projectedBezierPathFromStretchedGeneratorRequest:(CPRStretchedGeneratorRequest *)generatorRequest;

- (void)_drawVerticalLines:(NSArray *)verticalLines;
- (void)_drawVerticalLines:(NSArray *)verticalLines length:(CGFloat)length;

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
- (void)_buildTransverseVerticalLinesAndPlaneRuns;
- (void)_clearTransversePlanes;
- (N3Vector)_centerlinePixVectorForRelativePosition:(CGFloat)relativePosition;
- (CGFloat)_relativePositionForPixPoint:(NSPoint)pixPoint;
- (CGFloat)_relativePositionForIndex:(NSInteger)index;
- (N3Vector)_vectorForPixPoint:(NSPoint)pixPoint;
- (_CPRStretchedViewPlaneRun *)_limitedRunForRelativePosition:(CGFloat)relativePosition verticalLineIndex:(NSUInteger *)verticalLinePointer lengthFromCenterline:(CGFloat)length;

// calls for dealing with intersections with planes

- (void)_pushBezierPath:(CGFloat)distance;

- (void)_osirixUpdateVolumeDataNotification:(NSNotification *)notification;

@end

#pragma mark -

@implementation CPRStretchedView

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
@synthesize displayTransverseLines = _displayTransverseLines;
@synthesize displayCrossLines = _displayCrossLines;
@synthesize centerlinePath = _centerlinePath;

+ (BOOL)resolveInstanceMethod:(SEL)selector
{
    NSString *methodName;
    IMP imp;
    const char* typeEncoding;
    SEL proxySelector;
    
    methodName = NSStringFromSelector(selector);
    proxySelector = NULL;
    
    if ([methodName hasPrefix:@"get"] == NO && [methodName hasPrefix:@"set"] == NO) {
        if ([methodName hasSuffix:@"Plane"]) {
            proxySelector = @selector(_planeGetter);
        } else if ([methodName hasSuffix:@"SlabThickness"]) {
            proxySelector = @selector(_slabThicknessGetter);
        } else if ([methodName hasSuffix:@"PlaneColor"]) {
            proxySelector = @selector(_planeColorGetter);
        }
    } else if ([methodName hasPrefix:@"set"]) {
        if ([methodName hasSuffix:@"Plane:"]) {
            proxySelector = @selector(_planeSetter:);
        } else if ([methodName hasSuffix:@"SlabThickness:"]) {
            proxySelector = @selector(_slabThicknessSetter:);
        } else if ([methodName hasSuffix:@"PlaneColor:"]) {
            proxySelector = @selector(_planeColorSetter:);
        }
    }
    
    if (proxySelector) {
        imp = class_getMethodImplementation([self class], proxySelector);
        typeEncoding = method_getTypeEncoding(class_getInstanceMethod([self class], proxySelector));
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

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _planes = [[NSMutableDictionary alloc] init];
        _slabThicknesses = [[NSMutableDictionary alloc] init];
        _verticalLines = [[NSMutableDictionary alloc] init];
        _planeRuns = [[NSMutableDictionary alloc] init];
        _planeColors = [[NSMutableDictionary alloc] init];
		_mousePlanePointsInPix = [[NSMutableDictionary alloc] init];
        _transverseVerticalLines = [[NSMutableDictionary alloc] init];
		_transversePlaneRuns = [[NSMutableDictionary alloc] init];
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
    [_centerlinePath release];
    _centerlinePath = nil;
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
    [_transverseVerticalLines release];
    _transverseVerticalLines = nil;
    [_transversePlaneRuns release];
    _transversePlaneRuns = nil;
    
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
    } else if ([key hasSuffix:@"PlaneRuns"]) {
        planeFullName = [key substringToIndex:[key length] - 9];
        if ([_planeRuns valueForKey:planeFullName] == nil) {
            [self _buildVerticalLinesAndPlaneRunsForPlaneFullName:planeFullName];
        }
        return [_planeRuns valueForKey:planeFullName];
    }
    else {
        return [super valueForKey:key];
    }
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
        [self _clearTransversePlanes];
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
	if (NSEqualRects( frameRect, [self frame]) == NO) {
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

- (void)drawRect:(NSRect)rect
{
	if (rect.size.width <= 10)
        return;

		_processingRequest = YES;
		[self _sendNewRequestIfNeeded];
		_processingRequest = NO;    
		
//		[self _adjustROIs];
		
		[super drawRect: rect];
}

- (void)setNeedsDisplay:(BOOL)flag
{
    if (_processingRequest == NO)
        [super setNeedsDisplay:flag];
}

- (NSPoint) positionWithoutRotation: (NSPoint) tPt
{
    NSRect unrotatedRect = NSMakeRect( tPt.x/scaleValue, tPt.y/scaleValue, 1, 1);
    NSRect centeredRect = unrotatedRect;
    
    float ratio = 1;
    
    if (self.pixelSpacingX != 0 && self.pixelSpacingY != 0)
        ratio = self.pixelSpacingX / self.pixelSpacingY;
    
    centeredRect.origin.y -= [self origin].y*ratio/scaleValue;
    centeredRect.origin.x -= - [self origin].x/scaleValue;
    
    unrotatedRect.origin.x = centeredRect.origin.x*cos( glm::radians(-self.rotation)) +
                             centeredRect.origin.y*sin( glm::radians(-self.rotation))/ratio;

    unrotatedRect.origin.y = -centeredRect.origin.x*sin( glm::radians(-self.rotation)) +
                              centeredRect.origin.y*cos( glm::radians(-self.rotation))/ratio;
    
    unrotatedRect.origin.y *= ratio;
    
    unrotatedRect.origin.y += [self origin].y * ratio/scaleValue;
    unrotatedRect.origin.x -= [self origin].x/scaleValue;
    
    tPt = NSMakePoint( unrotatedRect.origin.x, unrotatedRect.origin.y);
    tPt.x = (tPt.x)*scaleValue - unrotatedRect.size.width/2;
    tPt.y = (tPt.y)/ratio*scaleValue - unrotatedRect.size.height/2/ratio;
    
    return tPt;
}

#pragma mark -

- (void)subDrawRect:(NSRect)rect
{
    N3Vector endpoint;
    NSString *planeName;
	NSColor *planeColor;
    N3Vector cursorVector;
    CGFloat relativePosition;
    
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    if (cgl_ctx == nil)
        return;
    
    renderer_enable_blend_smooth();
	
    if ([curDCM pixelSpacingX] == 0)
        return;
    
    N3BezierPath *centerline = [self centerlinePath];
    N3AffineTransform pixToSubDrawRectTransform = [self pixToSubDrawRectTransform];

    double pixToSubdrawRectOpenGLTransform[16];
    N3AffineTransformGetOpenGLMatrixd([self pixToSubDrawRectTransform], pixToSubdrawRectOpenGLTransform);

#ifdef WITH_OPENGL_32
    #define WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRETCH
    #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRETCH
    // Define a local model matrix and apply it locally without affecting the shader
    glm::mat4 M = glm::make_mat4(pixToSubdrawRectOpenGLTransform);
    #endif
#else
    glMatrixMode(GL_MODELVIEW);
    glPushMatrix();
    glMultMatrixd(pixToSubdrawRectOpenGLTransform);
#endif

#pragma mark green centerline
    
    [self setShaderProgramForLineWidth: 1.0 * self.window.backingScaleFactor];
    renderer_set_rgb(0, 1, 0); // green

    NSMutableArray *pArray = [NSMutableArray array];
    for (NSInteger i = 0; i < [centerline elementCount]; i++) {
        [centerline elementAtIndex:i control1:NULL control2:NULL endpoint:&endpoint];
        glm::vec2 a(endpoint.x, endpoint.y);
        #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRETCH
        // Apply local matrix transformation
        glm::vec4 pTemp = M*glm::vec4(a,0,1);
        a = glm::vec2(pTemp.x, pTemp.y);
        #endif
        [pArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];
    }

    renderer_drawLine_xy([pArray copy], GL_LINE_STRIP);

#pragma mark green (alpha 0.8) point mouse position

    [self setShaderProgramOverlay_withMode_Point];
    renderer_set_rgba(0.0, 1.0, 0.0, 0.8); // green

    if ([[self windowController] displayMousePosition] == YES &&
        _displayInfo.mouseCursorHidden == NO)
	{
        cursorVector = [self _centerlinePixVectorForRelativePosition: _displayInfo.mouseCursorPosition];

        NSMutableArray *pArray = [NSMutableArray array];
        glm::vec2 a(cursorVector.x, cursorVector.y);
        #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRETCH
        // Apply local matrix transformation
        glm::vec4 pTemp = M*glm::vec4(a,0,1);
        a = glm::vec2(pTemp.x, pTemp.y);
        #endif
        [pArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];

        glPointSize(8 * self.window.backingScaleFactor);
        renderer_drawPoints([pArray copy]);

#ifndef WITH_OPENGL_32
        glDisable(GL_POINT_SMOOTH);
#endif
    }
    
#ifndef WITH_OPENGL_32
    glPopMatrix();
#endif
 
#pragma mark cross lines

    if (_displayCrossLines) {
        for (planeName in _planes) {
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
    
    float exportTransverseSliceInterval = 0;
	
	if ([[self windowController] exportSequenceType] == CPRSeriesExportSequenceType &&
        [[self windowController] exportSeriesType] == CPRTransverseViewsExportSeriesType)
    {
        exportTransverseSliceInterval = [[self windowController] exportTransverseSliceInterval];
    }

#pragma mark export transverse slice

    if (exportTransverseSliceInterval > 0)
	{
		renderer_set_rgba(1.0, 1.0, 0.0, 1.0); // yellow
		
		N3MutableBezierPath *flattenedPath = [[_curvedPath.bezierPath mutableCopy] autorelease];
		[flattenedPath subdivide:N3BezierDefaultSubdivideSegmentLength];
		[flattenedPath flatten:N3BezierDefaultFlatness];
		
		float curveLength = [flattenedPath length];
		int noOfFrames = (curveLength / exportTransverseSliceInterval);
		noOfFrames++;
		
		float startingDistance = curveLength - (noOfFrames-1) * exportTransverseSliceInterval;
		startingDistance /= 2;
		
        // We need to find the tangents to the curve at
        N3VectorArray vectors = (N3VectorArray)malloc(noOfFrames * sizeof(N3Vector));
        N3VectorArray tangents = (N3VectorArray)malloc(noOfFrames * sizeof(N3Vector));
        noOfFrames = N3BezierCoreGetVectorInfo([_curvedPath.bezierPath N3BezierCore], exportTransverseSliceInterval, startingDistance, N3VectorZero, vectors, tangents, NULL, noOfFrames);
        
        CPRTransverseView *t = [[self windowController] middleTransverseView];
        CGFloat transverseWidth = (float)t.curDCM.pwidth/t.pixelsPerMm;
        transverseWidth /= self.pixelSpacingY;
        
		for (int i = 0; i < noOfFrames; i++)
		{
            _CPRStretchedViewPlaneRun *transverseRun;
            NSUInteger transverseIndex;
            
            relativePosition = (startingDistance + (exportTransverseSliceInterval * (CGFloat)i)) / curveLength;
            transverseRun = [self _limitedRunForRelativePosition:relativePosition verticalLineIndex:&transverseIndex lengthFromCenterline: transverseWidth];
            
            [self setShaderProgramForLineWidth: 2.0 * self.window.backingScaleFactor];
#ifdef WITH_OPENGL_32
            renderer_set_rgba(1.0, 1.0, 0.0, 1.0); // yellow
#endif

            if (transverseRun)
                [self _drawPlaneRuns:[NSArray arrayWithObject:transverseRun]];
            else
                [self _drawVerticalLines:[NSArray arrayWithObject:[NSNumber numberWithUnsignedInteger:transverseIndex]]
                                  length: transverseWidth];
		}
	}
	else if (_displayTransverseLines)
	{
        NSString *name;
        
        if ([_transverseVerticalLines count] == 0)
            [self _buildTransverseVerticalLinesAndPlaneRuns];
        
        renderer_set_rgba(1.0, 1.0, 0.0, 1.0); // yellow
        
        for (name in _transverseVerticalLines) {
            NSArray *transverseVerticalLine = [_transverseVerticalLines objectForKey:name];
            
            if ([name isEqualToString:@"center"])
                [self setShaderProgramForLineWidth: 2.0 * self.window.backingScaleFactor];
            else
                [self setShaderProgramForLineWidth: 1.0 * self.window.backingScaleFactor];
            
#ifdef WITH_OPENGL_32
            renderer_set_rgba(1.0, 1.0, 0.0, 1.0); // yellow
#endif
            [self _drawVerticalLines:transverseVerticalLine length:curDCM.pheight/3.0];
        }
        
        for (name in _transversePlaneRuns) {
            NSArray *transversePlaneRun = [_transversePlaneRuns objectForKey:name];
            
            if ([name isEqualToString:@"center"])
                [self setShaderProgramForLineWidth: 2.0 * self.window.backingScaleFactor];
            else
                [self setShaderProgramForLineWidth: 1.0 * self.window.backingScaleFactor];
            
#ifdef WITH_OPENGL_32
            renderer_set_rgba(1.0, 1.0, 0.0, 1.0); // yellow
#endif
            [self _drawPlaneRuns:transversePlaneRun];
        }
        
        N3Vector transverseIntersectionA = [self _centerlinePixVectorForRelativePosition:[_curvedPath leftTransverseSectionPosition]];
        N3Vector transverseIntersectionB = [self _centerlinePixVectorForRelativePosition:[_curvedPath transverseSectionPosition]];
        N3Vector transverseIntersectionC = [self _centerlinePixVectorForRelativePosition:[_curvedPath rightTransverseSectionPosition]];
        
        transverseIntersectionA = N3VectorApplyTransform(transverseIntersectionA, pixToSubDrawRectTransform);
        transverseIntersectionB = N3VectorApplyTransform(transverseIntersectionB, pixToSubDrawRectTransform);
        transverseIntersectionC = N3VectorApplyTransform(transverseIntersectionC, pixToSubDrawRectTransform);

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
        NSLog(@"%s %d, TODO: OpenGL Core", __FUNCTION__, __LINE__);
#else
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
            //#define WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRETCH2
            #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRETCH2
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
            glScalef (2.0f /([self xFlipped] ? -([self drawingFrameRect].size.width) : [self drawingFrameRect].size.width),
                     -2.0f / ([self yFlipped] ? -([self drawingFrameRect].size.height) : [self drawingFrameRect].size.height),
                      1.0f); // scale to port per pixel scale
            glTranslatef( [self origin].x, -[self origin].y, 0.0f);
#endif
            
            [stringTexA setFlippedX: [self xFlipped] Y:[self yFlipped]];
            [stringTexB setFlippedX: [self xFlipped] Y:[self yFlipped]];
            [stringTexC setFlippedX: [self xFlipped] Y:[self yFlipped]];
            
            [self setShaderProgramOverlay_withMode_TextureRgba];
            
            NSPoint tPt;
            
            tPt = [self positionWithoutRotation: NSMakePoint( transverseIntersectionA.x, transverseIntersectionA.y)];
            #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRETCH2
            // Apply local model transformation
            glm::vec4 pTemp = M*glm::vec4(glm::vec2(tPt.x, tPt.y),0,1);
            tPt = NSMakePoint(pTemp.x, pTemp.y);
            #endif
            renderer_setTextColor(0, 0, 0, 1);
            [stringTexA drawAtPoint:NSMakePoint(tPt.x+1, tPt.y+1) ratio: 1];
            renderer_setTextColor(1, 1, 0, 1);
            [stringTexA drawAtPoint:NSMakePoint(tPt.x, tPt.y) ratio: 1];
            
            tPt = [self positionWithoutRotation: NSMakePoint( transverseIntersectionB.x, transverseIntersectionB.y)];
            renderer_setTextColor(0, 0, 0, 1);
            [stringTexB drawAtPoint:NSMakePoint(tPt.x+1, tPt.y+1) ratio: 1];
            renderer_setTextColor(1, 1, 0, 1);
            [stringTexB drawAtPoint:NSMakePoint(tPt.x, tPt.y) ratio: 1];
            
            tPt = [self positionWithoutRotation: NSMakePoint( transverseIntersectionC.x, transverseIntersectionC.y)];
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
#pragma mark  Points on the plane (plane color), size 8
        
#ifdef WITH_OPENGL_32
        [self setShaderProgramOverlay_withMode_Point]; // Added
#else
        CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
        glEnable(GL_POINT_SMOOTH);
#endif

        renderer_set_point_size(8 * self.window.backingScaleFactor);

        NSMutableArray *pArray = [NSMutableArray array];
        for (planeName in _mousePlanePointsInPix)
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

        renderer_drawPoints([pArray copy]);

//      CPRStraightened view has code here for drawing a yellow point
    }

#pragma mark all curved path nodes

    if (_drawAllNodes)
	{
#ifdef WITH_OPENGL_32
        [self setShaderProgramOverlay_withMode_Point]; // Added
#endif
        for (NSInteger i = 0; i < [_curvedPath.nodes count]; i++)
		{
            relativePosition = [_curvedPath relativePositionForNodeAtIndex:i];
            cursorVector = [self _centerlinePixVectorForRelativePosition:relativePosition];
//            cursorVector = N3VectorMake(curDCM.pwidth * relativePosition, (CGFloat)curDCM.pheight/2.0, 0);
            cursorVector = N3VectorApplyTransform(cursorVector, pixToSubDrawRectTransform);
            
            if (_displayInfo.hoverNodeHidden == NO && _displayInfo.hoverNodeIndex == i)
                renderer_set_rgba(1.0, 0.5, 0.0, 1.0);
            else
                renderer_set_rgba(1.0, 0.0, 0.0, 1.0);
            
#ifndef WITH_OPENGL_32
            glEnable(GL_POINT_SMOOTH);
#endif
            glPointSize(8 * self.window.backingScaleFactor);
            
#ifdef WITH_OPENGL_32
            NSMutableArray *pArray = [NSMutableArray array];
            glm::vec2 a(cursorVector.x, cursorVector.y);
            [pArray addObject: [NSValue valueWithBytes:&a objCType:@encode(glm::vec2)]];
            renderer_drawPoints([pArray copy]);
#else
            glBegin(GL_POINTS);
            {
                glVertex2f(cursorVector.x, cursorVector.y);
            }
            glEnd();
#endif
        }
    }

#pragma mark Red box bounding the subview
	if ([[self window] firstResponder] == self && stringID == nil)
	{
#ifdef WITH_OPENGL_32
        NSLog(@"%s %d, TODO: OpenGL Core", __FUNCTION__, __LINE__);
#else
		glLoadIdentity();

        // scale to port per pixel scale
        glScalef (2.0f / (xFlipped ? -(drawingFrameRect.size.width)  : drawingFrameRect.size.width),
                 -2.0f / (yFlipped ? -(drawingFrameRect.size.height) : drawingFrameRect.size.height),
                  1.0f);		
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

#pragma mark -

- (void) updatePresentationStateFromSeriesOnlyImageLevel: (BOOL) onlyImage
{
}

- (void)generator:(CPRGenerator *)generator
didGenerateVolume:(CPRVolumeData *)volume
          request:(CPRGeneratorRequest *)request
{
	if ([self windowController] == nil)
		return;
    
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
    
    // blow away local caches of overlay lines
    self.centerlinePath = nil;
    _midHeightPoint = N3VectorZero;
    _projectionNormal = N3VectorZero;
    
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
	
	if ([pixArray count])
	{
        [self _clearAllPlanes];
        [self _clearTransversePlanes];
        self.centerlinePath = [self _projectedBezierPathFromStretchedGeneratorRequest:(CPRStretchedGeneratorRequest*)request];
        _midHeightPoint = [(CPRStretchedGeneratorRequest*)request midHeightPoint];
        _projectionNormal = [(CPRStretchedGeneratorRequest*)request projectionNormal];

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
		for( ROI *r in roiArray)
		{
			r.pix = curDCM;
			[r setOriginAndSpacing :curDCM.pixelSpacingX : curDCM.pixelSpacingY :NSMakePoint( curDCM.originX, curDCM.originY) :NO :NO];
			[r setRoiView :self];
		}
		
		[[self curRoiList] addObjectsFromArray: roiArray];
		
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
	
	if (view == self)
	{
		NSPoint viewPoint;
		N3Vector pixVector;
		BOOL overNode;
		NSInteger hoverNodeIndex;
		CGFloat relativePosition;
		N3Vector vector;
        CGFloat distanceFromCenterline;
		
		viewPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        // TODO: retina ?
		
		if (NSPointInRect( viewPoint, [self bounds]) == NO)
			return;
		
		pixVector = N3VectorApplyTransform(N3VectorMakeFromNSPoint(viewPoint), [self viewToPixTransform]);
		
		if (NSPointInRect(viewPoint, self.bounds) && curDCM.pwidth > 0) {
			[self _sendWillEditDisplayInfo];
			_displayInfo.mouseCursorPosition = [self _relativePositionForPixPoint:NSPointFromN3Vector(pixVector)];
//			_displayInfo.mouseCursorPosition = MIN(MAX(pixVector.x/(CGFloat)curDCM.pwidth, 0.0), 1.0);
			[self setNeedsDisplay:YES];
            
			[self _updateMousePlanePointsForViewPoint:viewPoint];  // this will modify _mousePlanePointsInPix and _displayInfo
			
            // test to see if the mouse is near a trasverse line
//            _displayInfo.mouseTransverseSection = CPR_TRANSVERSE_VIEW_SECTION_NONE;
//            _displayInfo.mouseTransverseSectionDistance = 0.0;
//            if (_displayTransverseLines) {
//                distance = ABS(pixVector.x - _curvedPath.leftTransverseSectionPosition*(CGFloat)curDCM.pwidth);
//                minDistance = distance;
//                if (distance < 20.0) {
//                    _displayInfo.mouseTransverseSection = CPR_TRANSVERSE_VIEW_SECTION_LEFT;
//                    _displayInfo.mouseTransverseSectionDistance = (pixVector.y - ((CGFloat)curDCM.pheight/2.0))*([_curvedPath.bezierPath length]/(CGFloat)curDCM.pwidth);
//                }
//                distance = ABS(pixVector.x - _curvedPath.rightTransverseSectionPosition*(CGFloat)curDCM.pwidth);
//                if (distance < 20.0 && distance < minDistance) {
//                    _displayInfo.mouseTransverseSection = CPR_TRANSVERSE_VIEW_SECTION_RIGHT;
//                    _displayInfo.mouseTransverseSectionDistance = (pixVector.y - ((CGFloat)curDCM.pheight/2.0))*([_curvedPath.bezierPath length]/(CGFloat)curDCM.pwidth);
//                    minDistance = distance;
//                }
//                distance = ABS(pixVector.x - _curvedPath.transverseSectionPosition*(CGFloat)curDCM.pwidth);
//                if (distance < 20.0 && distance < minDistance) {
//                    _displayInfo.mouseTransverseSection = CPR_TRANSVERSE_VIEW_SECTION_CENTER;
//                    _displayInfo.mouseTransverseSectionDistance = (pixVector.y - ((CGFloat)curDCM.pheight/2.0))*([_curvedPath.bezierPath length]/(CGFloat)curDCM.pwidth);
//                }
//            }            
            
//			line = N3LineMake(N3VectorMake(0, (CGFloat)curDCM.pheight / 2.0, 0), N3VectorMake(1, 0, 0));
//			line = N3LineApplyTransform(line, N3AffineTransformInvert([self viewToPixTransform]));
//			
            
            [_centerlinePath relativePositionClosestToLine:N3LineMake(pixVector, N3VectorMake(0, 0, 1)) closestVector:&vector];
            distanceFromCenterline = N3VectorDistanceToLine(vector, N3LineMake(pixVector, N3VectorMake(0, 0, 1)));
			if (distanceFromCenterline < 20.0) {
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
					
                    
                    if (N3VectorDistance(pixVector, [self _centerlinePixVectorForRelativePosition:relativePosition]) < 10) {
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
        NSMutableArray *allTransverseVerticalLines;
        NSMutableArray *allTransverseRuns;
        CGFloat transverseLineDistance;
        CGFloat transverseRunDistance;
        
		if( [[self windowController] exportSequenceType] == CPRSeriesExportSequenceType && [[self windowController] exportSeriesType] == CPRTransverseViewsExportSeriesType)
			exportTransverseSliceInterval = [[self windowController] exportTransverseSliceInterval];
		
        allTransverseVerticalLines = [NSMutableArray array];
        allTransverseRuns = [NSMutableArray array];
        
        for (NSArray *values in [_transverseVerticalLines allValues]) {
            [allTransverseVerticalLines addObjectsFromArray:values];
        }
        for (NSArray *values in [_transversePlaneRuns allValues]) {
            [allTransverseRuns addObjectsFromArray:values];
        }
        
        transverseLineDistance = [self _distanceToPoint:viewPoint onVerticalLines:allTransverseVerticalLines pixVector:NULL volumeVector:NULL];
        transverseRunDistance = [self _distanceToPoint:viewPoint onPlaneRuns:allTransverseRuns pixVector:NULL volumeVector:NULL];

		if( curDCM.pwidth != 0 && exportTransverseSliceInterval == 0 && _displayTransverseLines && (transverseLineDistance < 5.0 || transverseRunDistance < 5.0))
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
    N3Vector vector;
    CGFloat pixWidth;
    CGFloat relativePosition;
    CGFloat distanceFromCenterline;
    
    viewPoint = [self convertPoint:[event locationInWindow] fromView:nil];
    // TODO: retina ?
    
    pixVector = N3VectorApplyTransform(N3VectorMakeFromNSPoint(viewPoint), [self viewToPixTransform]);
    pixWidth = curDCM.pwidth;
    
    if (pixWidth == 0.0) {
        [super mouseDown:event];
        return;
    }
	
	float exportTransverseSliceInterval = 0;
    NSMutableArray *outsideTransverseVerticalLines;
    NSMutableArray *outsideTransverseRuns;
    CGFloat outsideTransverseLineDistance;
    CGFloat outsideTransverseRunDistance;
    CGFloat centerTransverseLineDistance;
    CGFloat centerTransverseRunDistance;
    
    outsideTransverseVerticalLines = [NSMutableArray array];
    outsideTransverseRuns = [NSMutableArray array];
    
    for (NSString *key in _transverseVerticalLines ) {
        if ([key isEqualToString:@"center"] == NO) {
            [outsideTransverseVerticalLines addObjectsFromArray:[_transverseVerticalLines objectForKey:key]];
        }
    }
    for (NSString *key in _transversePlaneRuns ) {
        if ([key isEqualToString:@"center"] == NO) {
            [outsideTransverseRuns addObjectsFromArray:[_transversePlaneRuns objectForKey:key]];
        }
    }
    
    outsideTransverseLineDistance = [self _distanceToPoint:viewPoint onVerticalLines:outsideTransverseVerticalLines pixVector:NULL volumeVector:NULL];
    outsideTransverseRunDistance = [self _distanceToPoint:viewPoint onPlaneRuns:outsideTransverseRuns pixVector:NULL volumeVector:NULL];
    centerTransverseLineDistance = [self _distanceToPoint:viewPoint onVerticalLines:[_transverseVerticalLines objectForKey:@"center"] pixVector:NULL volumeVector:NULL];
    centerTransverseRunDistance = [self _distanceToPoint:viewPoint onPlaneRuns:[_transversePlaneRuns objectForKey:@"center"] pixVector:NULL volumeVector:NULL];
    
	if ( [[self windowController] exportSequenceType] == CPRSeriesExportSequenceType && [[self windowController] exportSeriesType] == CPRTransverseViewsExportSeriesType)
		exportTransverseSliceInterval = [[self windowController] exportTransverseSliceInterval];
	
    if ( exportTransverseSliceInterval == 0 && _displayTransverseLines && MIN(centerTransverseLineDistance, centerTransverseRunDistance) < 5.0)
	{
		[self _sendWillEditCurvedPath];
        _draggingTransverse = YES;
		[self mouseMoved: event];
    }
	else if( exportTransverseSliceInterval == 0 && _displayTransverseLines && MIN(outsideTransverseLineDistance, outsideTransverseRunDistance) < 10.0)
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
            if (N3VectorDistance(pixVector, [self _centerlinePixVectorForRelativePosition:relativePosition]) < 10) {
                if (i == 0 || i == [_curvedPath.nodes count] - 1) {
                    if ([_delegate respondsToSelector:@selector(CPRView:setCrossCenter:)]) {
                        [_delegate CPRView: [[self windowController] mprView1] setCrossCenter:[[_curvedPath.nodes objectAtIndex:i] N3VectorValue]];
                    }
                    _draggedNode = -1;
                    _isDraggingNode = YES;
                    break;
                }
                else {
                    _draggedNode = i;
                    _isDraggingNode = YES;
                    [self _sendWillEditCurvedPath];
                    
                    break;
                }
            }
        }
        
        if (_isDraggingNode == NO) {
            relativePosition = [_centerlinePath relativePositionClosestToLine:N3LineMake(pixVector, N3VectorMake(0, 0, 1)) closestVector:&vector];
            distanceFromCenterline = N3VectorDistanceToLine(vector, N3LineMake(pixVector, N3VectorMake(0, 0, 1)));
            if (distanceFromCenterline < 5.0) {
                _isDraggingNode = YES;
                [self _sendWillEditCurvedPath];
                _draggedNode = [_curvedPath insertNodeAtRelativePosition:relativePosition];
                
                _isDraggingNode = YES;
                [self setNeedsDisplay:YES];
                [self _setNeedsNewRequest];
            }
        }
        
        if (_isDraggingNode == NO)
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
//					if( currentTool != tText && currentTool != tArrow)
//						currentTool = tMeasure;
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
    	
    viewPoint = [self convertPoint:[event locationInWindow] fromView:nil];
    // TODO: retina ?
    
    pixVector = N3VectorApplyTransform(N3VectorMakeFromNSPoint(viewPoint), [self viewToPixTransform]);
    pixWidth = curDCM.pwidth;
    
    if (pixWidth == 0.0) {
        [super mouseDragged:event];
        return;
    }
    
    if (_isDraggingNode) {
        if (_draggedNode >= 0) {
            [_curvedPath moveNodeAtIndex:_draggedNode toVector:[self _vectorForPixPoint:NSPointFromN3Vector(pixVector)]];
        }
        [self _sendDidUpdateCurvedPath];
        [self _setNeedsNewRequest];
        [self display];
        [self mouseMoved: event];
    }
    else if (_draggingTransverse)
	{
        relativePosition = [self _relativePositionForPixPoint:NSPointFromN3Vector(pixVector)];
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
        _curvedPath.transverseSectionSpacing = ABS([self _relativePositionForPixPoint:NSPointFromN3Vector(pixVector)]-_curvedPath.transverseSectionPosition)*[_curvedPath.bezierPath length];
		[self _sendDidUpdateCurvedPath];
        
		[self _sendWillEditDisplayInfo];
        _displayInfo.mouseCursorPosition = [self _relativePositionForPixPoint:NSPointFromN3Vector(pixVector)];
		[self _sendDidEditDisplayInfo];
        [self setNeedsDisplay:YES];
		[self mouseMoved: event];
    }
	else
	{
		[self _sendWillEditDisplayInfo];
        _displayInfo.mouseCursorPosition = [self _relativePositionForPixPoint:NSPointFromN3Vector(pixVector)];
		[self _sendDidEditDisplayInfo];
        
        [super mouseDragged:event];
    }
}

- (void)mouseUp:(NSEvent *)event
{
    if (_isDraggingNode) {
//        [_draggingCenterlinePath release];
//        _draggingCenterlinePath = nil;
//        _draggingMidHeightPoint = N3VectorZero;
//        _draggingProjectionNormal = N3VectorZero;
        [[NSNotificationCenter defaultCenter] postNotificationName:OsirixUpdateCurvedPathCostNotification object:nil];
        [self _sendDidEditCurvedPath];
        
        if (_draggedNode >= 0) {
            if ([_delegate respondsToSelector:@selector(CPRView:setCrossCenter:)]) {
                [_delegate CPRView: [[self windowController] mprView1] setCrossCenter:[[_curvedPath.nodes objectAtIndex:_draggedNode] N3VectorValue]];
            }
        }
    }
    _draggedNode = 0;
    _isDraggingNode = NO;

	if (_draggingTransverse) {
		_draggingTransverse = NO;
		[self _sendDidEditCurvedPath];
	} else if (_draggingTransverseSpacing) {
		_draggingTransverseSpacing = NO;
		[self _sendDidEditCurvedPath];
	}
    
    [super mouseUp:event];
}

- (void)keyDown:(NSEvent *)theEvent
{
    if( [[theEvent characters] length] == 0)
        return;
    
    unichar c = [[theEvent characters] characterAtIndex:0];
    
    if (( c == NSDeleteCharacter || c == NSDeleteFunctionKey) && _isDraggingNode && _draggedNode != -1)
	{
		// Delete node
        [_curvedPath removeNodeAtIndex:_draggedNode];
        _draggedNode = -1;
        [self setNeedsDisplay:YES];
        [self _setNeedsNewRequest];
        [[NSNotificationCenter defaultCenter] postNotificationName:OsirixUpdateCurvedPathCostNotification object:nil];
    }
    else
        [super keyDown:theEvent];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
	// Scroll/Move transverse lines
	if ( [theEvent modifierFlags] & NSEventModifierFlagOption)
	{
		CGFloat transverseSectionPosition = MIN(MAX(_curvedPath.transverseSectionPosition + [theEvent deltaY] * .002, 0.0), 1.0); 
		
		[self _sendWillEditCurvedPath];
		_curvedPath.transverseSectionPosition = transverseSectionPosition;
		[self _sendDidEditCurvedPath];
		
		[self _setNeedsNewRequest];
		[self setNeedsDisplay: YES];
	}
	
	// Scroll/Move transverse lines
	else if ( [theEvent modifierFlags] & NSEventModifierFlagCommand)
	{
        float factor = 0.4;
        
        if ( curDCM.pixelSpacingX)
            factor = curDCM.pixelSpacingX;
        
		CGFloat transverseSectionSpacing = MIN(MAX(_curvedPath.transverseSectionSpacing + [theEvent deltaY] * factor, 0.0), 300);
		
		[self _sendWillEditCurvedPath];
		_curvedPath.transverseSectionSpacing = transverseSectionSpacing;
		[self _sendDidEditCurvedPath];
		
		[self _setNeedsNewRequest];
		[self setNeedsDisplay: YES];
	}
    
    // Scroll/push the curve in and out
	else if ( [theEvent modifierFlags] & NSEventModifierFlagControl) {
        [self _pushBezierPath:[theEvent deltaY] * .4];
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


+ (NSInteger)_fusionModeForCPRViewClippingRangeMode:(MPRProjectionMode)mode
{
    switch (mode)
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
            NSLog(@"%s asking for invalid clipping range mode: %d", __func__, (int) mode);
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
    CPRStretchedGeneratorRequest *request;
//    N3Vector curveDirection;
//    N3Vector baseNormal;
    
    if ([_curvedPath.bezierPath elementCount] >= 3)
	{
        request = [[CPRStretchedGeneratorRequest alloc] init];
        
        if( [[self windowController] viewsPosition] == VerticalPosition)
        {
            request.pixelsWide = [self bounds].size.height*_extraWidthFactor;
            request.pixelsHigh = [self bounds].size.width*_extraWidthFactor;
		}
        else
        {
            request.pixelsWide = [self bounds].size.width*_extraWidthFactor;
            request.pixelsHigh = [self bounds].size.height*_extraWidthFactor;
		}
        
        request.slabWidth = _curvedPath.thickness;
        
        request.slabSampleDistance = 0;
        request.bezierPath = _curvedPath.bezierPath;
        request.projectionMode = _clippingRangeMode;
        request.projectionNormal = [_curvedPath stretchedProjectionNormal];
        request.midHeightPoint = N3VectorLerp([_curvedPath.bezierPath topBoundingPlaneForNormal:request.projectionNormal].point, 
                                              [_curvedPath.bezierPath bottomBoundingPlaneForNormal:request.projectionNormal].point, 0.5);
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

- (N3BezierPath *)_projectedBezierPathFromStretchedGeneratorRequest:(CPRStretchedGeneratorRequest *)generatorRequest
{
    N3MutableBezierPath *centerlinePath;
    N3Vector newPoint;

    // figure out how many horizonatal pixels we will have
    NSInteger pixelsWide = [generatorRequest pixelsWide];
    NSInteger pixelsHigh = [generatorRequest pixelsHigh];
    N3Vector projectionNormal = N3VectorNormalize(generatorRequest.projectionNormal);
    N3Vector midHeightPoint = generatorRequest.midHeightPoint;
    
    N3BezierCoreRef flattenedBezierCore = N3BezierCoreCreateFlattenedCopy([generatorRequest.bezierPath N3BezierCore], N3BezierDefaultFlatness);
    N3BezierCoreRef projectedBezierCore = N3BezierCoreCreateCopyProjectedToPlane(flattenedBezierCore, N3PlaneMake(N3VectorZero, projectionNormal));
    CGFloat projectedBezierLength = N3BezierCoreLength(projectedBezierCore);
    CGFloat sampleSpacing = projectedBezierLength / (CGFloat)pixelsWide;

    N3VectorArray vectors = (N3Vector *)malloc(sizeof(N3Vector) * pixelsWide);
    CGFloat *relativePositions = (CGFloat *)malloc(sizeof(CGFloat) * pixelsWide);
    
    NSUInteger numVectors = N3BezierCoreGetProjectedVectorInfo(flattenedBezierCore, sampleSpacing, 0, projectionNormal, vectors, NULL, NULL, relativePositions, pixelsWide);
    
    if (numVectors > 0) {
        while (numVectors < pixelsWide) { // make sure that the full array is filled and that there is not a vector that did not get filled due to roundoff error
            vectors[numVectors] = vectors[numVectors - 1];
            relativePositions[numVectors] = relativePositions[numVectors - 1];
            numVectors++;
        }
    }
    else { // there are no vectors at all to copy from, so just zero out everthing
        while (numVectors < pixelsWide) { // make sure that the full array is filled and that there is not a vector that did not get filled due to roundoff error
            vectors[numVectors] = N3VectorZero;
            relativePositions[numVectors] = 0;
            numVectors++;
        }
    }

    centerlinePath = [N3MutableBezierPath bezierPath];
    
    if (numVectors) {
        newPoint.x = 0;
        //        newPoint.y = N3VectorLength(N3VectorProject(N3VectorSubtract(vectors[0], midHeightPoint), projectionNormal));
        newPoint.y = N3VectorDotProduct(N3VectorSubtract(vectors[0], midHeightPoint), projectionNormal);
        newPoint.y /= sampleSpacing;
        newPoint.y += (CGFloat)pixelsHigh/2.0;
        newPoint.z = relativePositions[0];
        
        [centerlinePath moveToVector:newPoint];
    }
    
    for (NSInteger i = 1; i < numVectors; i++) {
        newPoint.x = i;
        newPoint.y = N3VectorDotProduct(N3VectorSubtract(vectors[i], midHeightPoint), projectionNormal);
        newPoint.y /= sampleSpacing;
        newPoint.y += (CGFloat)pixelsHigh/2.0;
        newPoint.z = relativePositions[i];
        
        [centerlinePath lineToVector:newPoint];
    }
    
    N3BezierCoreRelease(flattenedBezierCore);
    N3BezierCoreRelease(projectedBezierCore);
    free(vectors);
    free(relativePositions);
        
    return centerlinePath;    
}

- (void)_drawVerticalLines:(NSArray *)verticalLines
{
    if ([verticalLines count] == 0)
        return;

    double pixToSubdrawRectOpenGLTransform[16];
    N3AffineTransformGetOpenGLMatrixd([self pixToSubDrawRectTransform], pixToSubdrawRectOpenGLTransform);

#ifdef WITH_OPENGL_32
    #define WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRETCH4
    #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRETCH4
    // Define a local model matrix and apply it locally without affecting the shader
    glm::mat4 M = glm::make_mat4(pixToSubdrawRectOpenGLTransform);
    #endif
#else
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    if( cgl_ctx == nil)
        return;

    glMatrixMode(GL_MODELVIEW);
    glPushMatrix();
    glMultMatrixd(pixToSubdrawRectOpenGLTransform);
#endif

#ifdef WITH_OPENGL_32
    NSMutableArray *pArray = [NSMutableArray array];
    for (NSNumber *indexNumber in verticalLines) {
        glm::vec2 lineStart([indexNumber doubleValue], 0);
        #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRETCH4
        // Apply local matrix transformation
        glm::vec4 pTemp = M*glm::vec4(lineStart,0,1);
        lineStart = glm::vec2(pTemp.x, pTemp.y);
        #endif
        [pArray addObject: [NSValue valueWithBytes:&lineStart objCType:@encode(glm::vec2)]];

        glm::vec2 lineEnd([indexNumber doubleValue], curDCM.pheight);
        #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRETCH4
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

        glBegin(GL_LINE_STRIP); // A better way if all pairs of vertexes together with GL_LINES
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

- (void)_drawVerticalLines:(NSArray *)verticalLines
                    length:(CGFloat)length;
{
    double pixToSubdrawRectOpenGLTransform[16];
    N3AffineTransformGetOpenGLMatrixd([self pixToSubDrawRectTransform], pixToSubdrawRectOpenGLTransform);

#ifdef WITH_OPENGL_32
    #define WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRETCH5
    #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRETCH5
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
        CGFloat relativePostion = [self _relativePositionForIndex:[indexNumber integerValue]];
        N3Vector centerlineVector = [self _centerlinePixVectorForRelativePosition:relativePostion];
        
        glm::vec2 lineStart([indexNumber doubleValue],
                            centerlineVector.y - length/2.0);
        #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRETCH5
        // Apply local matrix transformation
        glm::vec4 pTemp = M*glm::vec4(lineStart,0,1);
        lineStart = glm::vec2(pTemp.x, pTemp.y);
        #endif
        [pArray addObject: [NSValue valueWithBytes:&lineStart objCType:@encode(glm::vec2)]];
        
        glm::vec2 lineEnd([indexNumber doubleValue],
                          centerlineVector.y + length/2.0);
        #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRETCH5
        // Apply local matrix transformation
        pTemp = M*glm::vec4(lineEnd,0,1);
        lineEnd = glm::vec2(pTemp.x, pTemp.y);
        #endif
        [pArray addObject: [NSValue valueWithBytes:&lineEnd objCType:@encode(glm::vec2)]];
    }

    renderer_drawLine_xy([pArray copy], GL_LINES);
#else
    for (NSNumber *indexNumber in verticalLines) {
        CGFloat relativePostion = [self _relativePositionForIndex:[indexNumber integerValue]]; // this is dumb, just do one iteration! and do it in log(n) time while your at it to!
        N3Vector centerlineVector = [self _centerlinePixVectorForRelativePosition:relativePostion];
        
		N3Vector lineStart = N3VectorMake([indexNumber doubleValue], centerlineVector.y - length/2.0, 0);
        N3Vector lineEnd   = N3VectorMake([indexNumber doubleValue], centerlineVector.y + length/2.0, 0);

        glBegin(GL_LINE_STRIP); // A better way if all pairs of vertexes together with GL_LINES
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
    if ([curDCM pixelSpacingX] == 0)
        return;
    
    CGFloat pixelsPerMm = 1.0/[curDCM pixelSpacingX];
    CGFloat pheight_2 = (CGFloat)curDCM.pheight/2.0;
    
    double pixToSubdrawRectOpenGLTransform[16];
    N3AffineTransformGetOpenGLMatrixd([self pixToSubDrawRectTransform], pixToSubdrawRectOpenGLTransform);

#ifdef WITH_OPENGL_32
    // Needed for the yellow lines
    #define WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRETCH3
    #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRETCH3
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
    
	for (_CPRStretchedViewPlaneRun *planeRun in planeRuns)
    {
#ifdef WITH_OPENGL_32
        NSMutableArray *pArray = [NSMutableArray array];
        for (NSInteger i = 0; i < planeRun.range.length; i++)
        {
            N3Vector planePointVector = N3VectorMake(planeRun.range.location + i,
                                            ([[planeRun.distances objectAtIndex:i] doubleValue] * pixelsPerMm) + pheight_2,
                                            0);
            glm::vec2 a(planePointVector.x, planePointVector.y);
            #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_CPR_STRETCH3
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
    
#ifdef WITH_OPENGL_32
    // TODO:
#else
    glPopMatrix();
#endif
}

- (_CPRStretchedViewPlaneRun *)_limitedRunForRelativePosition:(CGFloat)relativePosition verticalLineIndex:(NSUInteger *)verticalLinePointer lengthFromCenterline:(CGFloat)length
{
    N3Plane transversePlane;
    CGFloat mmPerPixel;
	CGFloat halfHeight;
    NSInteger pixelsWide;
    N3Vector projectionNormal;
    N3Plane topPlane;
    N3Plane bottomPlane;
    N3Vector midHeightPoint;
    N3BezierCoreRef flattenedBezierCore;
    N3BezierCoreRef projectedBezierCore;
    CGFloat projectedBezierLength;
    CGFloat sampleSpacing;
    N3VectorArray vectors;
    CGFloat *relativePositions;
    NSInteger relativePositionIndex;
    N3Vector top;
    N3Vector bottom;
    BOOL topPointAbove;
    BOOL bottomPointAbove;
    BOOL prevBottomPointAbove;
    _CPRStretchedViewPlaneRun *planeRun;
    NSRange range;
    CGFloat distance;
    CGFloat traveledDistance;
    N3Vector distanceVector;
    N3Vector lastDistanceVector;
    NSInteger numVectors;
    
    transversePlane.point = [_curvedPath.bezierPath vectorAtRelativePosition:relativePosition];
    transversePlane.normal = [_curvedPath.bezierPath tangentAtRelativePosition:relativePosition];
    
    mmPerPixel = [curDCM pixelSpacingX];
	halfHeight = ((CGFloat)curDCM.pheight*mmPerPixel)/2.0;
    length /= 2.0; // because the rest of the code uses the length from the centerline 
    
    // figure out how many horizonatal pixels we will have
    pixelsWide = curDCM.pwidth;
    projectionNormal = _projectionNormal;
    
    midHeightPoint = _midHeightPoint;
    topPlane = N3PlaneMake(N3VectorAdd(midHeightPoint, N3VectorScalarMultiply(projectionNormal, halfHeight*1e2)), projectionNormal); // make the virtual top and bottom of the world be real far away
    bottomPlane = N3PlaneMake(N3VectorAdd(midHeightPoint, N3VectorScalarMultiply(projectionNormal, -halfHeight*1e2)), projectionNormal);
    
    flattenedBezierCore = N3BezierCoreCreateFlattenedCopy([_curvedPath.bezierPath N3BezierCore], N3BezierDefaultFlatness);
    projectedBezierCore = N3BezierCoreCreateCopyProjectedToPlane(flattenedBezierCore, N3PlaneMake(N3VectorZero, projectionNormal));
    projectedBezierLength = N3BezierCoreLength(projectedBezierCore);
    sampleSpacing = projectedBezierLength / (CGFloat)pixelsWide;
    
    vectors = (N3Vector *)malloc(sizeof(N3Vector) * pixelsWide);
    relativePositions = (CGFloat *)malloc(sizeof(CGFloat) * pixelsWide);
    
    numVectors = N3BezierCoreGetProjectedVectorInfo(flattenedBezierCore, sampleSpacing, 0, projectionNormal, vectors, NULL, NULL, relativePositions, pixelsWide);
    
    if (numVectors > 0) {
        while (numVectors < pixelsWide) { // make sure that the full array is filled and that there is not a vector that did not get filled due to roundoff error
            vectors[numVectors] = vectors[numVectors - 1];
            relativePositions[numVectors] = relativePositions[numVectors - 1];
            numVectors++;
        }
    }
    else { // there are no vectors, bail!
        free(vectors);
        free(relativePositions);
        return [[[_CPRStretchedViewPlaneRun alloc] init] autorelease];
    }
    
    NSInteger ii;
    for (ii = 0; ii < numVectors; ii++) {
        if (relativePositions[ii] > relativePosition) {
            break;
        }
    }
    relativePositionIndex = MAX(0, ii-1);
    
    if (numVectors >= 2 && relativePositionIndex < numVectors - 1) { // it only makes sense to check for a vertical line if numVec is at least 2 and there i is not on the last line
        bottom = N3LineIntersectionWithPlane(N3LineMake(vectors[relativePositionIndex], projectionNormal), bottomPlane);
        top = N3LineIntersectionWithPlane(N3LineMake(vectors[relativePositionIndex], projectionNormal), topPlane);
        
        bottomPointAbove = N3VectorDotProduct(transversePlane.normal, N3VectorSubtract(bottom, transversePlane.point)) > 0.0;
		topPointAbove = N3VectorDotProduct(transversePlane.normal, N3VectorSubtract(top, transversePlane.point)) > 0.0;
        
        if (bottomPointAbove == topPointAbove) {
            if (verticalLinePointer) {
                *verticalLinePointer = relativePositionIndex;
            }
            free(vectors);
            free(relativePositions);
            return nil;
        }
    }
    
    // now know that this is not vertical line, and so we have to make a plane run    
    planeRun = [[[_CPRStretchedViewPlaneRun alloc] init] autorelease];
        
    // it is easier to extend the curve than to start it, so we will put th first point checking all the edge cases, and then we will worry about extending it
    bottom = N3LineIntersectionWithPlane(N3LineMake(vectors[relativePositionIndex], projectionNormal), bottomPlane); // isn't this already set?
    bottomPointAbove = N3VectorDotProduct(transversePlane.normal, N3VectorSubtract(bottom, transversePlane.point)) > 0.0;
    prevBottomPointAbove = bottomPointAbove;
        
    distance = N3VectorDotProduct(N3VectorSubtract(vectors[relativePositionIndex], midHeightPoint), projectionNormal);
    [planeRun.distances addObject:[NSNumber numberWithDouble:distance]];
    planeRun.range = NSMakeRange(relativePositionIndex, 1);
    lastDistanceVector = N3VectorMake(relativePositionIndex, distance/mmPerPixel, 0);
    
    // start walking forwards
    traveledDistance = 0;
    for (NSInteger i = relativePositionIndex + 1; i < numVectors; i++) {
        bottom = N3LineIntersectionWithPlane(N3LineMake(vectors[i], projectionNormal), bottomPlane);
        top = N3LineIntersectionWithPlane(N3LineMake(vectors[i], projectionNormal), topPlane);
        bottomPointAbove = N3VectorDotProduct(transversePlane.normal, N3VectorSubtract(bottom, transversePlane.point)) > 0.0;
        topPointAbove = N3VectorDotProduct(transversePlane.normal, N3VectorSubtract(top, transversePlane.point)) > 0.0;

        // if we just walked off the projection
        if (bottomPointAbove == topPointAbove) {
            // figure out if we just walked up or down
            if (prevBottomPointAbove != bottomPointAbove) {
                distance = -(halfHeight*1e10);
            }
            else {
                distance = halfHeight*1e10;
            }
        }
        else {
            distance = N3VectorDotProduct(N3VectorSubtract(N3LineIntersectionWithPlane(N3LineMakeFromPoints(bottom, top), transversePlane), midHeightPoint), projectionNormal);
        }
        
        distanceVector = N3VectorMake(i, distance/mmPerPixel, 0);
        if (N3VectorDistance(distanceVector, lastDistanceVector) + traveledDistance > length) { // we can't make the whole segment
            distanceVector = N3VectorAdd(lastDistanceVector, N3VectorScalarMultiply(N3VectorNormalize(N3VectorSubtract(distanceVector, lastDistanceVector)), length - traveledDistance));
            traveledDistance = length;
        }
        else {
            traveledDistance += N3VectorDistance(distanceVector, lastDistanceVector);
        }
        
        [planeRun.distances addObject:[NSNumber numberWithDouble:distanceVector.y*mmPerPixel]];
        lastDistanceVector = distanceVector;
        
        // and now update the range
        range = planeRun.range;
        range.length++;
        planeRun.range = range;
        
        if (traveledDistance == length)
            break;
        
        prevBottomPointAbove = bottomPointAbove;
    }
    
    // and walk back
    bottom = N3LineIntersectionWithPlane(N3LineMake(vectors[relativePositionIndex], projectionNormal), bottomPlane); // isn't this already set?
    prevBottomPointAbove = N3VectorDotProduct(transversePlane.normal, N3VectorSubtract(bottom, transversePlane.point)) > 0.0;
        
    distance = N3VectorDotProduct(N3VectorSubtract(vectors[relativePositionIndex], midHeightPoint), projectionNormal);
    lastDistanceVector = N3VectorMake(relativePositionIndex, distance/mmPerPixel, 0);
    traveledDistance = 0;
    for (NSInteger i = relativePositionIndex - 1; i >= 0; i--) {
        bottom = N3LineIntersectionWithPlane(N3LineMake(vectors[i], projectionNormal), bottomPlane);
        top = N3LineIntersectionWithPlane(N3LineMake(vectors[i], projectionNormal), topPlane);
        bottomPointAbove = N3VectorDotProduct(transversePlane.normal, N3VectorSubtract(bottom, transversePlane.point)) > 0.0;
        topPointAbove = N3VectorDotProduct(transversePlane.normal, N3VectorSubtract(top, transversePlane.point)) > 0.0;
        
        // if we just walked off the projection
        if (bottomPointAbove == topPointAbove) {
            // figure out if we just walked up or down
            if (prevBottomPointAbove != bottomPointAbove) {
                distance = -(halfHeight*1e10);
            }
            else {
                distance = halfHeight*1e10;
            }
        }
        else {
            distance = N3VectorDotProduct(N3VectorSubtract(N3LineIntersectionWithPlane(N3LineMakeFromPoints(bottom, top), transversePlane), midHeightPoint), projectionNormal);
        }
        
        distanceVector = N3VectorMake(i, distance/mmPerPixel, 0);
        if (N3VectorDistance(distanceVector, lastDistanceVector) + traveledDistance > length) { // we can't make the whole segment
            distanceVector = N3VectorAdd(lastDistanceVector, N3VectorScalarMultiply(N3VectorNormalize(N3VectorSubtract(distanceVector, lastDistanceVector)), length - traveledDistance));
            traveledDistance = length;
        }
        else {
            traveledDistance += N3VectorDistance(distanceVector, lastDistanceVector);
        }
        
        [planeRun.distances insertObject:[NSNumber numberWithDouble:distanceVector.y*mmPerPixel] atIndex:0];
        lastDistanceVector = distanceVector;
        
        // and now update the range
        range = planeRun.range;
        range.location--;
        range.length++;
        planeRun.range = range;
        
        if (traveledDistance == length)
            break;
        
        prevBottomPointAbove = bottomPointAbove;
    }

    free(vectors);
    free(relativePositions);
    return planeRun;
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
	N3Vector bottom;
	N3Vector top;
	_CPRStretchedViewPlaneRun *planeRun;
	NSRange range;
	NSInteger aboveOrBelow;
	NSInteger prevAboveOrBelow;
    NSInteger pixelsWide;
    N3Vector projectionNormal;
    N3BezierCoreRef flattenedBezierCore;
    N3BezierCoreRef projectedBezierCore;
    CGFloat projectedBezierLength;
    CGFloat sampleSpacing;
    N3VectorArray vectors;
    N3Plane topPlane;
    N3Plane bottomPlane;
    N3Vector midHeightPoint;
    
	runs = [NSMutableArray array];
	planeRun = nil;
    
	if (verticalLinesHandle) {
		verticalLines = [NSMutableArray array];
		*verticalLinesHandle = verticalLines;
	}
    else {
		verticalLines = nil;
	}
	
    mmPerPixel = [curDCM pixelSpacingX];
	halfHeight = ((CGFloat)curDCM.pheight*mmPerPixel)/2.0;
    
    // figure out how many horizonatal pixels we will have
    pixelsWide = curDCM.pwidth;
    projectionNormal = _projectionNormal;
    
    midHeightPoint = _midHeightPoint;
    topPlane = N3PlaneMake(N3VectorAdd(midHeightPoint, N3VectorScalarMultiply(projectionNormal, halfHeight)), projectionNormal);
    bottomPlane = N3PlaneMake(N3VectorAdd(midHeightPoint, N3VectorScalarMultiply(projectionNormal, -halfHeight)), projectionNormal);

    flattenedBezierCore = N3BezierCoreCreateFlattenedCopy([_curvedPath.bezierPath N3BezierCore], N3BezierDefaultFlatness);
    projectedBezierCore = N3BezierCoreCreateCopyProjectedToPlane(flattenedBezierCore, N3PlaneMake(N3VectorZero, projectionNormal));
    projectedBezierLength = N3BezierCoreLength(projectedBezierCore);
    sampleSpacing = projectedBezierLength / (CGFloat)pixelsWide;
    
    vectors = (N3Vector *)malloc(sizeof(N3Vector) * pixelsWide);
    
    numVectors = N3BezierCoreGetProjectedVectorInfo(flattenedBezierCore, sampleSpacing, 0, projectionNormal, vectors, NULL, NULL, NULL, pixelsWide);
    
    if (numVectors > 0) {
        while (numVectors < pixelsWide) { // make sure that the full array is filled and that there is not a vector that did not get filled due to roundoff error
            vectors[numVectors] = vectors[numVectors - 1];
            numVectors++;
        }
    }
    else { // there are no vectors at all to copy from, so just zero out everthing
        while (numVectors < pixelsWide) { // make sure that the full array is filled and that there is not a vector that did not get filled due to roundoff error
            vectors[numVectors] = N3VectorZero;
            numVectors++;
        }
    }

	for (NSInteger i = 0; i < numVectors; i++) {
        bottom = N3LineIntersectionWithPlane(N3LineMake(vectors[i], projectionNormal), bottomPlane);
        top = N3LineIntersectionWithPlane(N3LineMake(vectors[i], projectionNormal), topPlane);
		
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
				planeRun = [[_CPRStretchedViewPlaneRun alloc] init];
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

            distance = N3VectorDotProduct(N3VectorSubtract(N3LineIntersectionWithPlane(N3LineMakeFromPoints(bottom, top), plane), midHeightPoint), projectionNormal);
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
	
	free(vectors);
	
	return runs;	
}


// This function will modify _mousePlanePointsInPix and _displayInfo
- (void)_updateMousePlanePointsForViewPoint:(NSPoint)point
{
	N3Vector linePixVector = N3VectorZero;
	N3Vector lineVolumeVector = N3VectorZero;
	N3Vector runPixVector = N3VectorZero;
	N3Vector runVolumeVector = N3VectorZero;
	
	[_displayInfo clearAllMouseVectors];
	[_mousePlanePointsInPix removeAllObjects];
	
    for (NSString *planeName in _planes) {
        NSArray *verticalLines = [self valueForKey:[planeName stringByAppendingString:@"VerticalLines"]];
        NSArray *planeRuns = [self valueForKey:[planeName stringByAppendingString:@"PlaneRuns"]];
        CGFloat lineDistance = [self _distanceToPoint:point
                                      onVerticalLines:verticalLines
                                            pixVector:&linePixVector
                                         volumeVector:&lineVolumeVector];

        CGFloat runDistance = [self _distanceToPoint:point
                                         onPlaneRuns:planeRuns
                                           pixVector:&runPixVector
                                        volumeVector:&runVolumeVector];

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
	NSNumber *indexNumber;
	N3Vector pixPointVector;
	N3Vector pixVector;
	N3Vector lineStart;
	N3Vector lineEnd;
	//CGFloat height;
	CGFloat distance;
	CGFloat minDistance;
    
    if ([curDCM pixelSpacingX] == 0 || [verticalLines count] == 0) {
        return CGFLOAT_MAX;
    }
    
	pixToViewTransform = N3AffineTransformInvert([self viewToPixTransform]);
	minDistance = CGFLOAT_MAX;
	pixPointVector = N3VectorApplyTransform(N3VectorMakeFromNSPoint(point), [self viewToPixTransform]);
    
	for (indexNumber in verticalLines) {
		lineStart = N3VectorMake([indexNumber doubleValue], 0, 0);
        lineEnd = N3VectorMake([indexNumber doubleValue], curDCM.pheight, 0);
		
		distance = N3VectorDistanceToLine(N3VectorMakeFromNSPoint(point), N3LineApplyTransform(N3LineMakeFromPoints(lineStart, lineEnd), pixToViewTransform));
		if (distance < minDistance) {
			minDistance = distance;
            pixVector = N3VectorMake([indexNumber doubleValue], pixPointVector.y, 0);
			if (closestPixVectorPtr) {
				*closestPixVectorPtr = pixVector;
			}
			
			if (volumeVectorPtr) {
                *volumeVectorPtr = [self _vectorForPixPoint:NSPointFromN3Vector(pixVector)];
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
	CGFloat distance;
	CGFloat minDistance;
	_CPRStretchedViewPlaneRun *planeRun;
	N3MutableBezierPath *planeRunBezierPath;
	
    if ([curDCM pixelSpacingX] == 0 || [planeRuns count] == 0) {
        return CGFLOAT_MAX;
    }
    
	pointVector = N3VectorMakeFromNSPoint(point);
    pixelsPerMm = 1.0/[curDCM pixelSpacingX];

	minDistance = CGFLOAT_MAX;
	closestVector = N3VectorZero;
    
	for (planeRun in planeRuns) {
		planeRunBezierPath = [[N3MutableBezierPath alloc] initWithCPRStretchedViewPlaneRun:planeRun heightPixelsPerMm:pixelsPerMm];
		[planeRunBezierPath applyAffineTransform:N3AffineTransformMakeTranslation(0, (CGFloat)curDCM.pheight/2.0, 0)];
		[planeRunBezierPath applyAffineTransform:N3AffineTransformInvert([self viewToPixTransform])];
		
		N3BezierCoreRelativePositionClosestToVector([planeRunBezierPath N3BezierCore], pointVector, &closeVector, &distance);
		if (distance < minDistance) {
			minDistance = distance;
			closestVector = N3VectorApplyTransform(closeVector, [self viewToPixTransform]);
		}
		[planeRunBezierPath release];
		planeRunBezierPath = nil;
	}
	
	if (closestPixVectorPtr) {
		*closestPixVectorPtr = N3VectorMake(closestVector.x, closestVector.y, 0);
	}
	if (volumeVectorPtr) {
        *volumeVectorPtr = [self _vectorForPixPoint:NSPointFromN3Vector(closestVector)];
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
    } else if ([planeFullName hasSuffix:@"Bottom"]) {
        planeName = [planeFullName substringToIndex:[planeFullName length] - 6];
        slabThickness = -[[self valueForKey:[planeName stringByAppendingString:@"SlabThickness"]] doubleValue];
        if (slabThickness == 0) {
            return;
        }        
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
    NSString *selectorName;
    NSString *planeName;
    
    selectorName = NSStringFromSelector(_cmd);
    planeName = [selectorName stringByReplacingCharactersInRange:NSMakeRange(0, 4) withString:[[selectorName substringWithRange:NSMakeRange(3, 1)] lowercaseString]];
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
    NSString *selectorName;
    NSString *planeName;
    
    selectorName = NSStringFromSelector(_cmd);
    planeName = [selectorName substringToIndex:[selectorName length] - 5];    
    return [[_planes valueForKey:planeName] N3PlaneValue];
}

- (void)_slabThicknessSetter:(CGFloat)thickness
{
    NSString *selectorName;
    NSString *planeName;
    
    selectorName = NSStringFromSelector(_cmd);
    planeName = [selectorName stringByReplacingCharactersInRange:NSMakeRange(0, 4) withString:[[selectorName substringWithRange:NSMakeRange(3, 1)] lowercaseString]];
    planeName = [planeName substringToIndex:[planeName length] - 14];
    [_verticalLines removeObjectForKey:planeName];
    [_planeRuns removeObjectForKey:planeName];
    [_slabThicknesses setValue:[NSNumber numberWithDouble:thickness] forKey:planeName];    
    [self setNeedsDisplay:YES];
}

- (CGFloat)_slabThicknessGetter
{
    NSString *selectorName;
    NSString *planeName;
    
    selectorName = NSStringFromSelector(_cmd);
    planeName = [selectorName substringToIndex:[selectorName length] - 13];    
    return [[_slabThicknesses valueForKey:planeName] doubleValue];
}

- (void)_planeColorSetter:(NSColor *)color
{
    NSString *selectorName;
    NSString *planeName;
    
    selectorName = NSStringFromSelector(_cmd);
    planeName = [selectorName stringByReplacingCharactersInRange:NSMakeRange(0, 4) withString:[[selectorName substringWithRange:NSMakeRange(3, 1)] lowercaseString]];
    planeName = [planeName substringToIndex:[planeName length] - 11];
    [_planeColors setValue:color forKey:planeName];
    [self setNeedsDisplay:YES];
}

- (NSColor *)_planeColorGetter
{
    NSString *selectorName;
    NSString *planeName;
    
    selectorName = NSStringFromSelector(_cmd);
    planeName = [selectorName substringToIndex:[selectorName length] - 10];  
    if ([_planeColors valueForKey:planeName] == nil) {
        [_planeColors setValue:[NSColor colorWithDeviceRed:1 green:1 blue:1 alpha:1] forKey:planeName];
    }
    return [_planeColors valueForKey:planeName];
}

- (void)_buildTransverseVerticalLinesAndPlaneRuns
{
    NSUInteger verticalLine;
    _CPRStretchedViewPlaneRun *planeRun;
    
    CPRTransverseView *t = [[self windowController] middleTransverseView];
    CGFloat transverseWidth = (float)t.curDCM.pwidth/t.pixelsPerMm;
    transverseWidth /= self.pixelSpacingY;
    
    planeRun = [self _limitedRunForRelativePosition:[_curvedPath transverseSectionPosition] verticalLineIndex:&verticalLine lengthFromCenterline: transverseWidth];
    if (planeRun) {
        [_transversePlaneRuns setObject:[NSArray arrayWithObject:planeRun] forKey:@"center"];
    }
    else {
        [_transverseVerticalLines setObject:[NSArray arrayWithObject:[NSNumber numberWithUnsignedInteger:verticalLine]] forKey:@"center"];
    }
    
    planeRun = [self _limitedRunForRelativePosition:[_curvedPath leftTransverseSectionPosition] verticalLineIndex:&verticalLine lengthFromCenterline: transverseWidth];
    if (planeRun) {
        [_transversePlaneRuns setObject:[NSArray arrayWithObject:planeRun] forKey:@"left"];
    }
    else {
        [_transverseVerticalLines setObject:[NSArray arrayWithObject:[NSNumber numberWithUnsignedInteger:verticalLine]] forKey:@"left"];
    }
    
    planeRun = [self _limitedRunForRelativePosition:[_curvedPath rightTransverseSectionPosition] verticalLineIndex:&verticalLine lengthFromCenterline: transverseWidth];
    if (planeRun) {
        [_transversePlaneRuns setObject:[NSArray arrayWithObject:planeRun] forKey:@"right"];
    }
    else {
        [_transverseVerticalLines setObject:[NSArray arrayWithObject:[NSNumber numberWithUnsignedInteger:verticalLine]] forKey:@"right"];
    }
    
    
//    
//    _CPRStretchedViewPlaneRun *)_limitedRunForRelativePosition
//    N3Plane transversePlane;
//    NSArray *planeRuns;
//    NSArray *verticalLines;
//    
//    transversePlane.point = [_curvedPath.bezierPath vectorAtRelativePosition:[_curvedPath transverseSectionPosition]];
//    transversePlane.normal = [_curvedPath.bezierPath tangentAtRelativePosition:[_curvedPath transverseSectionPosition]];
//    planeRuns = [self _runsForPlane:transversePlane verticalLineIndexes:&verticalLines];
//    [_transverseVerticalLines setObject:verticalLines forKey:@"center"];
//    [_transversePlaneRuns setObject:planeRuns forKey:@"center"];
//    
//    transversePlane.point = [_curvedPath.bezierPath vectorAtRelativePosition:[_curvedPath leftTransverseSectionPosition]];
//    transversePlane.normal = [_curvedPath.bezierPath tangentAtRelativePosition:[_curvedPath leftTransverseSectionPosition]];
//    planeRuns = [self _runsForPlane:transversePlane verticalLineIndexes:&verticalLines];
//    [_transverseVerticalLines setObject:verticalLines forKey:@"left"];
//    [_transversePlaneRuns setObject:planeRuns forKey:@"left"];
//    
//    transversePlane.point = [_curvedPath.bezierPath vectorAtRelativePosition:[_curvedPath rightTransverseSectionPosition]];
//    transversePlane.normal = [_curvedPath.bezierPath tangentAtRelativePosition:[_curvedPath rightTransverseSectionPosition]];
//    planeRuns = [self _runsForPlane:transversePlane verticalLineIndexes:&verticalLines];
//    [_transverseVerticalLines setObject:verticalLines forKey:@"right"];
//    [_transversePlaneRuns setObject:planeRuns forKey:@"right"];
}

- (void)_clearTransversePlanes
{
    [_transverseVerticalLines removeAllObjects];
    [_transversePlaneRuns removeAllObjects];
}

- (N3Vector)_centerlinePixVectorForRelativePosition:(CGFloat)relativePosition
{
    N3Plane relativePositionPlane;
    NSArray *intersections;
    N3Vector relativePositionIntersection;
    
    if ([curDCM pixelSpacingX] == 0) {
        return N3VectorZero;
    }
    
    if (relativePosition == 0) {
        relativePositionIntersection = [self.centerlinePath vectorAtStart];
    } else if (relativePosition == 1) {
        relativePositionIntersection = [self.centerlinePath vectorAtEnd];
    }
    else {
        relativePositionPlane = N3PlaneMake(N3VectorMake(0, 0, relativePosition), N3VectorMake(0, 0, 1));
        intersections = [self.centerlinePath intersectionsWithPlane:relativePositionPlane]; // TODO make this O(log(n)) not O(n)
        
        if ([intersections count] == 0)
            return N3VectorZero;
        
        relativePositionIntersection = [[intersections objectAtIndex:0] N3VectorValue];
    }
    
    return relativePositionIntersection;
}

- (CGFloat)_relativePositionForIndex:(NSInteger)index
{
    N3Plane plane;
    NSArray *intersections;
    
    plane = N3PlaneMake(N3VectorMake((CGFloat)index, 0, 0), N3VectorMake(1, 0, 0));
    
    intersections = [_centerlinePath intersectionsWithPlane:plane]; // TODO make this O(log(n)) not O(n) 
    if ([intersections count] == 0)
        return 0;
    
    return [[intersections objectAtIndex:0] N3VectorValue].z;
}

- (CGFloat)_relativePositionForPixPoint:(NSPoint)pixPoint
{
    N3Line pixLine;
    N3Vector closestVector;
    
    if (_centerlinePath == nil) {
        return 0;
    }
    
    closestVector = N3VectorZero;
    pixLine.point = N3VectorMakeFromNSPoint(pixPoint);
    pixLine.vector = N3VectorMake(0, 0, 1.0);
    
    [_centerlinePath relativePositionClosestToLine:pixLine closestVector:&closestVector];
    
    return MIN(MAX(closestVector.z, 0.0), 1.0);
}

- (N3Vector)_vectorForPixPoint:(NSPoint)pixPoint
{
    N3Plane intersectionPlane;
    NSArray *intersections;
    N3Vector intersectionVector;
    N3Vector vector;
    CGFloat relativePosition;
    CGFloat mmPerPixel;
    CGFloat pixDistance;
    CGFloat mmDistance;
    N3Vector projectionNormal;
        
    projectionNormal = _projectionNormal;
    mmPerPixel = [curDCM pixelSpacingX];
    intersectionPlane = N3PlaneMake(N3VectorMakeFromNSPoint(pixPoint), N3VectorMake(1.0, 0, 0));
    intersections = [_centerlinePath intersectionsWithPlane:intersectionPlane];
    if ([intersections count] == 0) {
        return N3VectorZero;
    }
    intersectionVector = [[intersections objectAtIndex:0] N3VectorValue];
    relativePosition = intersectionVector.z;
    vector = [_curvedPath.bezierPath vectorAtRelativePosition:relativePosition];
    pixDistance = pixPoint.y - intersectionVector.y;
    mmDistance = pixDistance * mmPerPixel;
    
    return N3VectorAdd(vector, N3VectorScalarMultiply(projectionNormal, mmDistance));
}

- (void)_pushBezierPath:(CGFloat)distance
{
    CGFloat relativePosition;
    N3Vector tangent;
    N3Vector normal;
    N3Vector newNode;
    
    [self _sendWillEditCurvedPath];
    for (NSInteger i = 0; i < [[_curvedPath nodes] count]; i++) {
        relativePosition = [_curvedPath relativePositionForNodeAtIndex:i];
        
        tangent = [_curvedPath.bezierPath tangentAtRelativePosition:relativePosition];
        normal = N3VectorNormalize(N3VectorCrossProduct(_projectionNormal, tangent));
        
        newNode = N3VectorAdd([[[_curvedPath nodes] objectAtIndex:i] N3VectorValue], N3VectorScalarMultiply(normal, distance));
        [_curvedPath moveNodeAtIndex:i toVector:newNode];
    }
    [self _sendDidEditCurvedPath];
}

- (void)_osirixUpdateVolumeDataNotification:(NSNotification *)notification
{
    self.lastRequest = nil;
    [self _setNeedsNewRequest];
}

@end

#pragma mark -

@implementation N3BezierPath (CPRStretchedViewPlaneRunAdditions)

- (id)initWithCPRStretchedViewPlaneRun:(_CPRStretchedViewPlaneRun *)planeRun heightPixelsPerMm:(CGFloat)pixelsPerMm
{
	N3MutableBezierPath *mutableBezierPath;
	
	mutableBezierPath = [[N3MutableBezierPath alloc] init];
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










