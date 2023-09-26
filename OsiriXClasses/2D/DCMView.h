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

#ifndef DCMVIEW_H_INCLUDED
#define DCMVIEW_H_INCLUDED

#import "options.h"

#import "ROI.h"
#import "N3Geometry.h"

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#import "mieleTypes.h"
#include "glm/glm.hpp"

#define STAT_UPDATE					0.6f
#define IMAGE_COUNT					1
#define IMAGE_DEPTH					32

#define NUM_DISPLAY_LISTS           150

#ifdef WITH_OPENGL_32
struct _points {
    GLuint programHandle;

    GLint vertexAttribXY;
    GLint vertexAttribRGB;
    GLint vertexUniformProjection;
};
#endif // WITH_OPENGL_32

#pragma mark - Tools

extern NSString *pasteBoardOsiriX;
extern NSString *pasteBoardOsiriXPlugin;
extern NSString *OsirixPluginPboardUTI;
extern ClutBarsType CLUTBARS;
extern int ANNOTATIONS;
extern int SOFTWAREINTERPOLATION_MAX;
//extern BOOL DISPLAYCROSSREFERENCELINES;

typedef NS_ENUM(NSUInteger, DCMViewTextAlign) {
    DCMVVIEW_TEXT_ALIGN_LEFT,
    DCMVVIEW_TEXT_ALIGN_CENTER,
    DCMVVIEW_TEXT_ALIGN_RIGHT
};

typedef NS_ENUM(NSUInteger, MyScrollMode) {
    MY_SCROLL_MODE_UNDEFINED = 0,
    MY_SCROLL_MODE_VER = 1,
    MY_SCROLL_MODE_HOR = 2
};

typedef NS_ENUM(NSUInteger, PETWindowingMode) {
    PETWindowingMode_CLASSIC = 0,   // X window width, Y window level
    PETWindowingMode_FIXED_MIN = 1, // X nothing, Y maximum with specified minimum
    PETWindowingMode_MAXIMUM = 2    // X minimum, Y maximum
};

// See also tags in some .xib files
typedef NS_ENUM(NSInteger, BlendingMode2DType) {
    BLENDING_MODE_LINEAR_FUSION = 0,
    BLENDING_MODE_HIGH_LOW_HIGH = 1,
    BLENDING_MODE_LOW_HIGH_LOW = 2,
    BLENDING_MODE_LOG = 3,
    BLENDING_MODE_LOG_INV = 4,
    BLENDING_MODE_FLAT = 5
};

@class GLString;
@class DCMPix;
@class DCMView;
@class ROI;
@class OrthogonalMPRController;
@class DICOMExport;
@class Dicom_Image, DicomSeries, DicomStudy;
@class DCMObject;

#pragma mark -

@interface DCMExportPlugin: NSObject
- (void) finalize:(DCMObject*) dcmDst withSourceObject:(DCMObject*) dcmObject;
- (NSString*) seriesName;
@end

#pragma mark -

/** \brief Image/Frame View for ViewerController */

@interface DCMView: NSOpenGLView <NSColorChanging, NSFontChanging>
{
	NSInteger		_imageRows;
	NSInteger		_imageColumns;
	NSInteger		_tag;

	NSString		*yearOld;
	
	ROI				*curROI;
	int				volumicData, areDCMPixParallel;
	BOOL			drawingROI, noScale, mouseDraggedForROIUndo;
	DCMView			*blendingView;
	float			blendingFactor, blendingFactorStart;
	BOOL			eraserFlag; // use by the PaletteController to switch between the Brush and the Eraser
	BOOL			colorTransfer;
	unsigned char   *colorBuf, *blendingColorBuf;
	unsigned char   alphaTable[256], opaqueTable[256], redTable[256], greenTable[256], blueTable[256];

    float redFactor, greenFactor, blueFactor;

    BlendingMode2DType blendingMode;
	
    float sliceFromTo[ 2][ 3];
    float sliceFromToS[ 2][ 3];
    float sliceFromToE[ 2][ 3];
    float sliceFromTo2[ 2][ 3];
    float sliceFromToThickness;
	
	float sliceVector[ 3];
	float slicePoint3D[ 3];
	float syncRelativeDiff;

    //long syncSeriesIndex;
	
    float mprVector[ 3];
    float mprPoint[ 3];
    
    NSTimeInterval timeIntervalForDrag;
	
	short thickSlabMode, thickSlabStacks;
	
	NSMutableArray	*rectArray;
	
    NSMutableArray  *dcmPixList;
    NSArray			*dcmFilesList;
    NSMutableArray  *dcmRoiList; // array of arrays of ROI
    NSMutableArray  *curRoiList; // array of ROI
    DCMPix			*curDCM;
	DCMExportPlugin	*dcmExportPlugin;
	
    char listType;
    
    short curImage, startImage;
    
    ToolMode currentTool, currentToolRight, currentMouseEventTool;
    
	BOOL mouseDragging;
	BOOL suppress_labels; // keep from drawing the labels when command+shift is pressed

    NSPoint start, originStart, previous;
	
    float			startWW, curWW, startMin, startMax;
    float			startWL, curWL;

    float			bdstartWW, bdcurWW, bdstartMin, bdstartMax;
    float			bdstartWL, bdcurWL;
	
	BOOL			curWLWWSUVConverted;
	float			curWLWWSUVFactor;
	
    NSSize          scaleStart, scaleInit;
    
	double			resizeTotal;

    float           scaleValue;
    float           startScaleValue;
    float           rotationStart;  // in degrees
    NSPoint			origin;

    short			crossMove;
    
    NSMatrix        *matrix;
    
    long            count;
	
    BOOL            xFlipped, yFlipped;

    // FONT_TYPE_2D_VIEW
    // 2DView (and Preview?) text annotations
    NSColor         *fontColor;
    NSSize			stringSize;
    NSFont          *fontGL;
    GLuint          fontListGL;  // OpenGL legacy
    long            fontListGLSize[256];

    // FONT_TYPE_ROI
    // ROI text annotations
    NSFont			*labelFont;
    GLuint          labelFontListGL;  // OpenGL legacy
    long            labelFontListGLSize[ 256];

	float			fontRasterY;
		
    NSPoint         measureA, measureB;
    NSRect          roiRect;
	NSString		*stringID;
	NSSize			previousViewSize;

	float			contextualMenuInWindowPosX;
	float			contextualMenuInWindowPosY;
	
	float			mouseXPos, mouseYPos;
    BOOL            mouseOnImage, mouseOnView, blendingMouseOnImage;
	float			pixelMouseValue;
	long			pixelMouseValueR, pixelMouseValueG, pixelMouseValueB;
    
	float blendingMouseXPos, blendingMouseYPos;
	float blendingPixelMouseValue;
	long blendingPixelMouseValueR, blendingPixelMouseValueG, blendingPixelMouseValueB;
	
    long			textureX, blendingTextureX;
    long			textureY, blendingTextureY;
    GLuint			*pTextureName;  // texture ID
	GLuint			*blendingTextureName;
    long			textureWidth, blendingTextureWidth;
    long			textureHeight, blendingTextureHeight;
    
	GLint           edgeClampParam; // the param that is passed to the texturing parameteres
    GLint           interpolationType;
	
	BOOL			isKeyView; //needed for Image View subclass
	NSCursor		*cursor;
	
	BOOL			cursorSet;
	NSTrackingArea	*cursorTracking;

#ifdef WITH_TRACKPAD
	int trackPadNumberOfFingers;
    float trackPadScaleAccumulator;
    BOOL trackPadMoved;
#endif

	NSPoint display2DPoint;
    int display2DPointIndex;
	
#define STRCAPACITY 800
	NSMutableDictionary	*stringTextureDic; // cache ? similar to FreeType map, but for entire words
	
	BOOL _dragInProgress; // Are we doing drag and drop ?
	NSTimer *_mouseDownTimer; // Timer to check if mouseDown is Persisting
	NSTimer *_rightMouseDownTimer; // Checking For Right hold
	NSImage *destinationImage; // image will be dropping
	
    BOOL _hasChanged;
    BOOL needToLoadTexture;
	
	BOOL scaleToFitNoReentry;
	
    BOOL showDescriptionInLarge;
	GLString *showDescriptionInLargeText;

#ifdef WITH_RED_CAPTION
    GLString *warningNotice;
#endif
    float previousScalingFactor;
	
#ifdef WITH_ICHAT
	//Context for rendering to iChat
	NSOpenGLContext *_alternateContext;
#endif
    
	BOOL drawing;
	
	int				repulsorRadius;
	NSPoint			repulsorPosition;
	NSTimer			*repulsorColorTimer;
	float			repulsorAlpha, repulsorAlphaSign;
	BOOL			repulsorROIEdition;
	MyScrollMode    scrollMode;
	
	NSPoint			ROISelectorStartPoint, ROISelectorEndPoint;
	BOOL			selectorROIEdition;
	NSMutableArray	*ROISelectorSelectedROIList;
	
	BOOL			syncOnLocationImpossible, updateNotificationRunning;
	
	char			*resampledBaseAddr, *blendingResampledBaseAddr;
    BOOL			zoomIsSoftwareInterpolated;
    BOOL            firstTimeDisplay;
    float           resampledScale;
	
	int				resampledBaseAddrSize, blendingResampledBaseAddrSize;
		
	// iChat
//	float			iChatWidth, iChatHeight;
//	unsigned char*	iChatCursorTextureBuffer;
//	GLuint			iChatCursorTextureName;
//	NSSize			iChatCursorImageSize;
//	NSPoint			iChatCursorHotSpot;
//	BOOL			iChatDrawing;
//	GLuint			iChatFontListGL;
//	NSFont			*iChatFontGL;
//	long			iChatFontListGLSize[ 256];
//	NSMutableDictionary	*iChatStringTextureCache;
//	NSSize			iChatStringSize;
    NSRect			drawingFrameRect;
    NSRect          screenCaptureRect;
	
	BOOL			exceptionDisplayed;
	BOOL			COPYSETTINGSINSERIES;
	BOOL			is2DViewerCached, is2DViewerValue;
	
	char *lensTexture;
	int LENSSIZE;
	float LENSRATIO;
	BOOL cursorhidden;
	int avoidRecursiveSync;
	BOOL avoidMouseMovedRecursive;
	BOOL avoidChangeWLWWRecursive;
	BOOL TextureComputed32bitPipeline;
    
//    BOOL iChatRunning;

#define DRAW_LOUPE_RING
#ifdef DRAW_LOUPE_RING
    // The ring, drawn without multi-texturing
    NSImage *loupeRingImage;
    GLubyte *loupeTextureBuffer;
    GLuint loupeRingTextureID;
    GLuint loupeTextureWidth;
    GLuint loupeTextureHeight;
#endif

    // Loupe mask
    // The inside disk where the magnified image is shown through, drawn with multi-texturing
    NSImage *loupeMaskImage;
    GLubyte *loupeMaskTextureBuffer;
    GLuint loupeMaskTextureID;
    GLuint loupeMaskTextureWidth;
    GLuint loupeMaskTextureHeight;

    float studyColorR, studyColorG, studyColorB;
    NSUInteger studyDateIndex;
//	LoupeController *loupeController;
    
    GLString *studyDateBox;
    
    int annotationType;
    
    NSArray *cleanedOutDcmPixArray;
    NSTimeInterval firstDisplay;
    NSString *mousePosUSRegion;

#ifdef WITH_OPENGL_32
    //glm::mat4 MV; // Tentative #g93
#endif
}

#if 0 //def WITH_OPENGL_32
@property (readwrite,retain) NSMutableArray *m_buffers; // VBOs
#endif

@property NSRect drawingFrameRect;
@property (retain) NSArray *cleanedOutDcmPixArray;
@property (readonly) NSMutableArray *rectArray;
@property (readonly) NSMutableArray *curRoiList;
@property BOOL COPYSETTINGSINSERIES;
@property BOOL flippedData;
@property BOOL showDescriptionInLarge;
@property (nonatomic) BOOL whiteBackground; // annotation text shadow color
@property (retain) NSMutableArray *dcmPixList, *dcmRoiList;
@property (readonly) NSArray *dcmFilesList;
@property long syncSeriesIndex;
@property (nonatomic)float syncRelativeDiff, studyColorR, studyColorG, studyColorB;
@property (nonatomic) BlendingMode2DType blendingMode; // custom setter
@property (nonatomic) NSUInteger studyDateIndex;
@property (retain,setter=setBlending:) DCMView *blendingView;
@property (readonly) float blendingFactor;
@property (nonatomic) BOOL xFlipped, yFlipped;
@property (retain) NSString *stringID;
@property (retain) NSString *mousePosUSRegion;
@property (nonatomic) ToolMode currentTool;
@property (setter=setRightTool:) ToolMode currentToolRight; // custom setter
@property (readonly) short curImage;
@property (retain) NSMatrix *theMatrix;
@property (readonly) BOOL suppressLabels;

@property (nonatomic) NSPoint origin;
@property (nonatomic) float scaleValue;
@property (nonatomic) float rotation;  // in degrees, custom setter, getter seems to be displayedRotation

@property (readonly) double pixelSpacing, pixelSpacingX, pixelSpacingY;
@property (readonly) DCMPix *curDCM;
@property (retain) DCMExportPlugin *dcmExportPlugin;
@property (readonly) float mouseXPos, mouseYPos;
@property (readonly) float contextualMenuInWindowPosX, contextualMenuInWindowPosY;
@property (readonly) GLuint fontListGL;
@property (readonly) NSFont *fontGL;
@property NSInteger tag;
@property (readonly) float curWW, curWL;
@property NSInteger rows, columns;
@property (readonly) NSCursor *cursor;
@property BOOL eraserFlag;
@property BOOL drawing;
@property (readonly) BOOL volumicSeries;
@property (nonatomic) NSTimeInterval timeIntervalForDrag;
@property (readonly) BOOL isKeyView, mouseDragging;
@property int annotationType;
@property (readonly) int volumicData;

#pragma mark - Class methods

+ (SynchroType)syncro;
+ (void)setSyncro:(SynchroType) s;

+ (void) setDontListenToSyncMessage: (BOOL) v;
+ (BOOL) noPropagateSettingsInSeriesForModality: (Dicom_Image*) imageObj;
+ (void) purgeStringTextureCache;
+ (void) setDefaults;
+ (void) setCLUTBARS:(ClutBarsType) c withAnnotations:(int) a;
+ (void)setPluginOverridesMouse: (BOOL)override DEPRECATED_ATTRIBUTE;
+ (void) computePETBlendingCLUT;
+ (NSString*) findWLWWPreset: (float) wl :(float) ww :(DCMPix*) pix;
+ (NSSize)sizeOfString:(NSString *)string forFont:(NSFont *)font;
+ (long) lengthOfString:( char *) cstr forFont:(long *)fontSizeArray;
+ (BOOL) intersectionBetweenTwoLinesA1:(NSPoint) a1 A2:(NSPoint) a2 B1:(NSPoint) b1 B2:(NSPoint) b2 result:(NSPoint*) r;
+ (float) Magnitude:( NSPoint) Point1 :(NSPoint) Point2;
+ (float) angleBetweenVector: (float*) v1 andVector: (float*) v2;
+ (double) angleBetweenVectorD: (double*) v1 andVectorD: (double*) v2;
+ (int) DistancePointLine: (NSPoint) Point :(NSPoint) startPoint :(NSPoint) endPoint :(float*) Distance;
+ (float) pbase_Plane: (float*) point :(float*) planeOrigin :(float*) planeVector :(float*) pointProjection;
+ (double) pbaseDouble_Plane: (double*) point :(double*) planeOrigin :(double*) planeVector :(double*) pointProjection;
+ (unsigned char*) PETredTable;
+ (unsigned char*) PETgreenTable;
+ (unsigned char*) PETblueTable;
+ (NSDictionary*) hotKeyDictionary;
+ (NSDictionary*) hotKeyModifiersDictionary;
+ (NSArray*)cleanedOutDcmPixArray:(NSArray*)input; // filters the input array of DCMPix by returning only the pix with the most common ImageType in the input array

#pragma mark - IBAction

- (IBAction) syncronize:(id) sender;
- (IBAction) flipVertical:(id) sender;
- (IBAction) flipHorizontal:(id) sender;
- (IBAction) sliderRGBFactor:(id) sender;
- (IBAction) alwaysSyncMenu:(id) sender;
- (IBAction) roiLoadFromXMLFiles: (NSArray*) filenames;
- (IBAction)realSize:(id)sender;
- (IBAction)scaleToFit:(id)sender;
- (IBAction)actualSize:(id)sender;
- (IBAction)resizeWindow:(id)sender;

#pragma mark - Instance methods

- (SynchroType)syncro;
- (void)setSyncro:(SynchroType) s;

- (BOOL) softwareInterpolation;
- (void) applyImageTransformation __deprecated;
//- (void) loadOpenGLIdentityForDrawingFrame: (NSRect) r;
- (void) gClickCountSetReset;

- (NSUInteger) findPlaneAndPoint:(float*) pt
                                :(float*) location;

- (NSUInteger) findPlaneForPoint:(float*) pt
                      localPoint:(float*) location
               distanceWithPlane:(float*) distanceResult;

- (NSUInteger) findPlaneForPoint:(float*) pt
                preferParallelTo:(float*) parto
                      localPoint:(float*) location
               distanceWithPlane:(float*) distanceResult;

- (NSUInteger) findPlaneForPoint:(float*) pt
                preferParallelTo:(float*) parto
                      localPoint:(float*) location
               distanceWithPlane:(float*) distanceResult
         limitWithSliceThickness:(BOOL) limitWithSliceThickness;

- (unsigned char*) getRawPixels:(long*) width :(long*) height :(long*) spp :(long*) bpp :(BOOL) screenCapture :(BOOL) force8bits;

- (unsigned char*) getRawPixelsWidth:(long*) width height:(long*) height spp:(long*) spp bpp:(long*) bpp screenCapture:(BOOL) screenCapture force8bits:(BOOL) force8bits removeGraphical:(BOOL) removeGraphical squarePixels:(BOOL) squarePixels allTiles:(BOOL) allTiles allowSmartCropping:(BOOL) allowSmartCropping origin:(float*) imOrigin spacing:(float*) imSpacing;

- (unsigned char*) getRawPixelsWidth:(long*) width height:(long*) height spp:(long*) spp bpp:(long*) bpp screenCapture:(BOOL) screenCapture force8bits:(BOOL) force8bits removeGraphical:(BOOL) removeGraphical squarePixels:(BOOL) squarePixels allTiles:(BOOL) allTiles allowSmartCropping:(BOOL) allowSmartCropping origin:(float*) imOrigin spacing:(float*) imSpacing offset:(int*) offset isSigned:(BOOL*) isSigned;

- (unsigned char*) getRawPixelsWidth:(long*) width height:(long*) height spp:(long*) spp bpp:(long*) bpp screenCapture:(BOOL) screenCapture force8bits:(BOOL) force8bits removeGraphical:(BOOL) removeGraphical squarePixels:(BOOL) squarePixels allTiles:(BOOL) allTiles allowSmartCropping:(BOOL) allowSmartCropping origin:(float*) imOrigin spacing:(float*) imSpacing offset:(int*) offset isSigned:(BOOL*) isSigned views: (NSArray*) views viewsRect: (NSArray*) rects;

- (unsigned char*) getRawPixelsViewWidth:(long*) width height:(long*) height spp:(long*) spp bpp:(long*) bpp screenCapture:(BOOL) screenCapture force8bits:(BOOL) force8bits removeGraphical:(BOOL) removeGraphical squarePixels:(BOOL) squarePixels allowSmartCropping:(BOOL) allowSmartCropping origin:(float*) imOrigin spacing:(float*) imSpacing;

- (unsigned char*) getRawPixelsViewWidth:(long*) width height:(long*) height spp:(long*) spp bpp:(long*) bpp screenCapture:(BOOL) screenCapture force8bits:(BOOL) force8bits removeGraphical:(BOOL) removeGraphical squarePixels:(BOOL) squarePixels allowSmartCropping:(BOOL) allowSmartCropping origin:(float*) imOrigin spacing:(float*) imSpacing offset:(int*) offset isSigned:(BOOL*) isSigned;

- (void) blendingPropagate;
- (void) subtract:(DCMView*) bV;
- (void) subtract:(DCMView*) bV absolute:(BOOL) abs;
- (void) multiply:(DCMView*) bV;

- (GLuint *) loadTextureIn: (GLuint *) texture
                  blending: (BOOL) blending
                  colorBuf: (unsigned char**) colorBufPtr
                  textureX: (long*) tX
                  textureY: (long*) tY
                  redTable: (unsigned char*) rT
                greenTable: (unsigned char*) gT
                 blueTable: (unsigned char*) bT
              textureWidth: (long*) tW
             textureHeight: (long*) tH
         resampledBaseAddr: (char**) rAddr
     resampledBaseAddrSize: (int*) rBAddrSize;

// checks to see if tool is for ROIs.  maybe better name - (BOOL)isToolforROIs:(long)tool
- (BOOL) roiTool:(long) tool;
- (void) prepareToRelease;
- (void) orientationCorrectedToView:(float*) correctedOrientation;
//#ifndef MIELE_LIGHT
- (N3AffineTransform)pixToSubDrawRectTransform; // Converts points in DCMPix "Slice Coordinates" to coordinates that need to be passed to GL in subDrawRect
//#endif
- (NSPoint) ConvertFromNSView2GL:(NSPoint) a;
- (NSPoint) ConvertFromView2GL:(NSPoint) a;
- (NSPoint) ConvertFromUpLeftView2GL:(NSPoint) a;
- (NSPoint) ConvertFromGL2View:(NSPoint) a;
- (NSPoint) ConvertFromGL2NSView:(NSPoint) a;
- (NSPoint) ConvertFromGL2Screen:(NSPoint) a;
- (NSPoint) ConvertFromGL2GL:(NSPoint) a toView:(DCMView*) otherView;
- (NSRect) smartCrop;
- (void) setWLWW:(float) wl :(float) ww;
- (void)discretelySetWLWW:(float)wl :(float)ww;
- (void) getWLWW:(float*) wl :(float*) ww;
- (void) getThickSlabThickness:(float*) thickness location:(float*) location;
- (void) setCLUT:( unsigned char*) r :(unsigned char*) g :(unsigned char*) b;
- (NSImage*) nsimage;
- (NSImage*) nsimage:(BOOL) originalSize;
- (NSImage*) nsimage:(BOOL) originalSize allViewers:(BOOL) allViewers;
- (NSDictionary*) exportDCMCurrentImage: (DICOMExport*) exportDCM size:(int) size;
- (NSDictionary*) exportDCMCurrentImage: (DICOMExport*) exportDCM size:(int) size  views: (NSArray*) views viewsRect: (NSArray*) viewsRect;
- (NSDictionary*) exportDCMCurrentImage: (DICOMExport*) exportDCM size:(int) size  views: (NSArray*) views viewsRect: (NSArray*) viewsRect exportSpacingAndOrigin: (BOOL) exportSpacingAndOrigin;
- (NSDictionary*) exportDCMCurrentImage: (DICOMExport*) exportDCM size:(int) size  views: (NSArray*) views viewsRect: (NSArray*) viewsRect exportSpacingAndOrigin: (BOOL) exportSpacingAndOrigin force8bits:(BOOL) force8bits;
- (NSImage*) exportNSImageCurrentImageWithSize:(int) size;
- (void) setIndex:(short) index;
- (void) setIndexWithReset:(short) index :(BOOL)sizeToFit;
- (void) setDCM:(NSMutableArray*) c :(NSArray*)d :(NSMutableArray*)e :(short) firstImage :(char) type :(BOOL) reset;

- (void) setPixels: (NSMutableArray*) pixels
             files: (NSArray*) files
              rois: (NSMutableArray*) rois
        firstImage: (short) firstImage
             level: (char) level
             reset: (BOOL) reset;

- (void) sendSyncMessage:(short) inc;
- (void) loadTextures;
- (void)loadTexturesCompute;
- (void) setFusion:(short) mode :(short) stacks;
- (void) FindMinimumOpenGLCapabilities;
- (NSPoint) rotatePoint:(NSPoint) a;
- (void) setOrigin:(NSPoint) x;
- (void) setOriginX:(float) x Y:(float) y;
- (void) scaleToFit;
- (float) scaleToFitForDCMPix: (DCMPix*) d;
- (BOOL) isScaledFit;
- (void) setBlendingFactor:(float) f;
- (void) sliderAction:(id) sender;
- (void) roiSet;
- (void) sync3DPosition;
- (void) roiSet:(ROI*) aRoi __deprecated;

- (void) colorTables:(unsigned char **) a
                    :(unsigned char **) r
                    :(unsigned char **) g
                    :(unsigned char **) b;

- (void) blendingColorTables:(unsigned char **) a
                            :(unsigned char **) r
                            :(unsigned char **) g
                            :(unsigned char **) b;

- (void )changeFont:(id)sender;

- (void) getCLUT:(unsigned char**) r
                :(unsigned char**) g
                :(unsigned char**) b;

- (void) sync:(NSNotification*)note;

- (instancetype)createOpenGLView:(NSRect)frameRect;

- (instancetype)initWithFrame:(NSRect)frame
                    imageRows:(int)rows
                 imageColumns:(int)columns;

- (float)getSUV;
- (BOOL)checkHasChanged;
- (void) drawRectIn:(NSRect) size :(GLuint *) texture :(NSPoint) offset :(long) tX :(long) tY :(long) tW :(long) tH;

- (void)DrawNSStringGL:(NSString*) cstrOut :(GLuint)fontL :(long) x :(long) y;
- (void)DrawNSStringGL:(NSString*) str     :(GLuint)fontL :(long) x :(long) y rightAlignment: (BOOL) right useStringTexture: (BOOL) stringTex;
- (void)DrawNSStringGL:(NSString*) str     :(GLuint)fontL :(long) x :(long) y align:(DCMViewTextAlign)align useStringTexture:(BOOL)stringTex;

- (void)DrawCStringGL:(char *)cstrOut :(GLuint)fontL :(long)x :(long)y;
- (void)DrawCStringGL:(char *)cstrOut :(GLuint)fontL :(long)x :(long)y rightAlignment:(BOOL)right useStringTexture:(BOOL)stringTex;
- (void)DrawCStringGL:(char *)cstrOut :(GLuint)fontL :(long)x :(long)y align:(DCMViewTextAlign)align useStringTexture:(BOOL)stringTex;

- (void) drawTextualData:(NSRect) size :(long) annotations;
- (void) drawTextualData:(NSRect) size annotationsLevel:(long) annotations fullText: (BOOL) fullText onlyOrientation: (BOOL) onlyOrientation;
- (void) draw2DPointMarker;
- (void) drawImage:(NSImage *)image inBounds:(NSRect)rect;
- (void) setScaleValueCentered:(float) x;
- (void) updateCurrentImage: (NSNotification*) note;
- (void) setImageParamatersFromView:(DCMView *)aView;
- (void) setRows:(int)rows columns:(int)columns;
- (DCMPix*) middleSliceInThickStack;
- (void) updateTilingViews;
- (void) becomeMainWindow;
- (void) checkCursor;
- (Dicom_Image *)imageObj;
- (DicomSeries *)seriesObj;
- (DicomStudy *)studyObj;
- (void) updatePresentationStateFromSeries;
- (void) updatePresentationStateFromSeriesOnlyImageLevel: (BOOL) onlyImage;
- (void) updatePresentationStateFromSeriesOnlyImageLevel: (BOOL) onlyImage scale: (BOOL) scale offset: (BOOL) offset;
- (void) setCursorForView: (long) tool;
- (ToolMode) getTool: (NSEvent*) event;
- (void)resizeWindowToScale:(float)resizeScale;
- (float) getBlendedSUV;
- (OrthogonalMPRController*) controller;
- (void) roiChange:(NSNotification*)note;
- (void) roiSelected:(NSNotification*) note;
- (void) magnifyWithEvent:(NSEvent *)anEvent;
- (void) rotateWithEvent:(NSEvent *)anEvent;
- (void) setStartWLWW;
- (void) stopROIEditing;
- (void) deleteInvalidROIs;
- (void) computeMagnifyLens:(NSPoint) p;

- (void) makeTextureObjectFromImage:(NSImage*)image
                   forTexture:(GLuint*)texName
                       buffer:(GLubyte*)buffer
                  //textureUnit:(GLuint)textureUnit
                            ;

- (void) stopROIEditingForce:(BOOL) force;
- (void) subDrawRect: (NSRect)aRect;     // Subclassable, default does nothing.
- (void) drawRectAnyway:(NSRect)aRect;   // Subclassable, default does nothing.
- (void) updateImage;
//- (NSPoint) convertFromView2iChat: (NSPoint) a;
//- (NSPoint) convertFromNSView2iChat: (NSPoint) a;
- (void) annotMenu:(id) sender;
- (ROI*) clickInROI: (NSPoint) tempPt;
- (ROI*) clickInROI: (NSPoint) tempPt testTextBox: (BOOL) t;
- (void) switchShowDescriptionInLarge;
- (void) deleteLens;
- (void)getOrientationText:(char *) orientation : (float *) vector :(BOOL) inv;
- (NSMutableArray*) selectedROIs;

- (void) computeSliceIntersection: (DCMPix*) oPix
                      sliceFromTo: (float[2][3]) sft
                           vector: (float*) vectorB
                           origin: (float*) originB;

- (void) drawCrossLines:(float[2][3]) sft ctx: (CGLContextObj) cgl_ctx;
- (void) drawCrossLines:(float[2][3]) sft ctx: (CGLContextObj) cgl_ctx withShift: (double) shift;
- (void) drawCrossLines:(float[2][3]) sft ctx: (CGLContextObj) cgl_ctx withShift: (double) shift showPoint: (BOOL) showPoint;
- (void) drawCrossLines:(float[2][3]) sft ctx: (CGLContextObj) cgl_ctx perpendicular:(BOOL) perpendicular;
- (void) drawCrossLines:(float[2][3]) sft ctx: (CGLContextObj) cgl_ctx perpendicular:(BOOL) perpendicular withShift:(double) shift;
- (void) drawCrossLines:(float[2][3]) sft ctx: (CGLContextObj) cgl_ctx perpendicular:(BOOL) perpendicular withShift:(double) shift half:(BOOL) half;
- (void) drawCrossLines:(float[2][3]) sft ctx: (CGLContextObj) cgl_ctx perpendicular:(BOOL) perpendicular withShift:(double) shift half:(BOOL) half showPoint: (BOOL) showPoint;

- (void) startDrag:(NSTimer*)theTimer;
- (void)deleteMouseDownTimer;
- (void) roiLoadFromFilesArray: (NSArray*) filenames;
- (id)windowController;
- (BOOL)is2DViewer;
- (NSPoint) positionWithoutRotation: (NSPoint) tPt;
- (void) drawOrientations:(NSRect) aRect;
- (void) setCOPYSETTINGSINSERIESdirectly: (BOOL) b;
- (BOOL)actionForHotKey:(NSString *)hotKey;
- (void) delete3DROIsAliases;
//iChat
// New Draw method to allow for IChat Theater
- (void) drawRect:(NSRect)aRect withContext:(NSOpenGLContext *)ctx;
- (BOOL)_checkHasChanged:(BOOL)flag;

// Methods for mouse drag response. They can be modified for subclassing
// This allow the various tools to have different responses in different subclasses.
// Making it easy to modify mouseDragged:
- (BOOL)checkROIsForHitAtPoint:(NSPoint)point forEvent:(NSEvent *)event;
- (BOOL)mouseDraggedForROIs:(NSEvent *)event;
- (void)mouseDraggedCrosshair:(NSEvent *)event;
- (void)mouseDragged3DRotate:(NSEvent *)event;
- (void)mouseDraggedZoom:(NSEvent *)event;
- (void)mouseDraggedTranslate:(NSEvent *)event;
- (void)mouseDraggedRotate:(NSEvent *)event;
- (void)mouseDraggedImageScroll:(NSEvent *)event;
- (void)mouseDraggedBlending:(NSEvent *)event;
- (void)mouseDraggedWindowLevel:(NSEvent *)event;
- (void)mouseDraggedRepulsor:(NSEvent *)event;
- (void)mouseDraggedROISelector:(NSEvent *)event;

- (void)computeStudyColor;
- (void)setIsLUT12Bit:(BOOL)boo;
- (BOOL)isLUT12Bit;

//- (void)displayLoupe;
//- (void)displayLoupeWithCenter:(NSPoint)center;
//- (void)hideLoupe;

- (void) setShaderProgramForLineWidth:(GLfloat) w;

- (void) setShaderProgramFont;
- (void) setShaderProgramImage;
- (void) setShaderProgramOverlay;
- (void) setShaderProgramOverlayLine;

- (void) setShaderProgramOverlay_withMode_Normal;
- (void) setShaderProgramOverlay_withMode_Point;
- (void) setShaderProgramOverlay_withMode_TextureRgba;
- (void) setShaderProgramOverlay_withMode_TextureLuminosity;

@end
#endif
