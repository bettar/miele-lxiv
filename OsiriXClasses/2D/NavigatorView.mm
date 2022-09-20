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

#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"
#include "glm/gtc/type_ptr.hpp"

#import "NavigatorView.h"
#import "NavigatorWindowController.h"
#import "ROI.h"
#import "Notifications.h"
#import "AppController.h"

#import "DCMPix.h"

// max size of the thumbnails in pixels
#define thumbnailMaxHeight      100
#define thumbnailMaxWidth       100

// maximum number of thumbnails displayed at the same time in the view
#define maxThumbRow             10
#define maxThumbColumn          20

// lateral scroll bar size
#define lateralScrollBarSize    20

@implementation NavigatorView

@synthesize thumbnailWidth, thumbnailHeight;

- (int) minimumWindowHeight
{
	int scrollbarShift = thumbnailHeight;
	//if ([[[[self viewer] window] screen] visibleFrame].size.width < [[self window] maxSize].width) scrollbarShift += 12;
	if ([[[[self viewer] window] screen] visibleFrame].size.width < [self frame].size.width)
        scrollbarShift += 12;

    return 16 + scrollbarShift;
}

+ (NSRect) rect
{
	if ([NavigatorWindowController navigatorWindowController])
	{
		NavigatorView * n = [[NavigatorWindowController navigatorWindowController] navigatorView];
		ViewerController *v = [[NavigatorWindowController navigatorWindowController] viewerController];
		NSRect rect;
		
		rect.size.width = [[n window] maxSize].width;
		rect.size.height = [v maxMovieIndex]*n.thumbnailHeight;
		
        NSScreen *screen = [[[AppController sharedAppController] viewerScreens] objectAtIndex: 0];
        
		if (rect.size.width > [screen visibleFrame].size.width)
            rect.size.width = [screen visibleFrame].size.width;

        if (rect.size.height > [screen visibleFrame].size.height/2)
            rect.size.height = [screen visibleFrame].size.height/2;
		
		rect.origin.x = [screen visibleFrame].origin.x;
		rect.origin.y = [screen visibleFrame].origin.y;
		
		float scrollbarShift = 0;
		if (rect.size.width < [n frame].size.width)
            scrollbarShift = 12;
		
		rect.size.height += 17+scrollbarShift;
		
		return rect;
	}
	
	return NSZeroRect;
}

+ (NSRect) adjustIfScreenAreaIf4DNavigator: (NSRect) frame;
{
	if ([NavigatorWindowController navigatorWindowController])
	{
		NSRect navRect = [[[NavigatorWindowController navigatorWindowController] window] frame]; 
		
		NSRect iRect = NSIntersectionRect( frame, navRect);
		
		if (NSIsEmptyRect( iRect) == NO)
		{
			frame.size.height = frame.size.height - iRect.size.height;
			frame.origin.y = NSMaxY(iRect);
		}
	}
	
	return frame;
}

- (void) removeNotificationObserver;
{
	dontListenToNotification++;
}

- (void) addNotificationObserver;
{
	dontListenToNotification--;
}

#pragma mark -

- (id)initWithFrame:(NSRect)frame
{
    NSLog(@"%s", __FUNCTION__);

	NSOpenGLPixelFormatAttribute attrs[] = {
#ifdef WITH_OPENGL_32

    #if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_10
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion4_1Core,
    #elif MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_7
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,  // results in "OpenGL version:4.1 INTEL-10.14.73"
    #endif

#else
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersionLegacy,  // for immediate mode
#endif
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFADepthSize, (NSOpenGLPixelFormatAttribute)32,
        0
    };

    NSOpenGLPixelFormat* pixFmt = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attrs] autorelease];
	  
	self = [super initWithFrame:frame pixelFormat:pixFmt];
    if (self)
	{
        [self setWantsBestResolutionOpenGLSurface:YES]; // Retina https://developer.apple.com/library/mac/#documentation/GraphicsAnimation/Conceptual/HighResolutionOSX/CapturingScreenContents/CapturingScreenContents.html#//apple_ref/doc/uid/TP40012302-CH10-SW1
        
		userAction = idle;
		translation = NSZeroPoint;
		offset = NSZeroPoint;
		sizeFactor = 1.0;
		zoomFactor = 1.0;
		
		drawLeftLateralScrollBar = NO;
		drawRightLateralScrollBar = NO;

		previousImageIndex = -1;
		previousMovieIndex = -1;
		
		savedTransformDict = [[NSMutableDictionary dictionary] retain];
		
//		previousViewer = nil;
		
		cursorTracking = [[NSTrackingArea alloc] initWithRect:[self visibleRect] options:(NSTrackingActiveWhenFirstResponder|NSTrackingInVisibleRect|NSTrackingMouseEnteredAndExited|NSTrackingActiveInKeyWindow) owner:self userInfo:nil];
		[self addTrackingArea:cursorTracking];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeWLWW:) name:OsirixChangeWLWWNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh:) name:OsirixDCMViewIndexChangedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshROIs:) name:OsirixRemoveROINotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshROIs:) name:OsirixROIChangeNotification object:nil];

		[[self window] setDelegate:self];
		
		[[self openGLContext] makeCurrentContext];
        NSLog(@"%s %d, class %@, OpenGL legacy:%i", __FUNCTION__, __LINE__,
              NSStringFromClass([self class]), checkOGLVersion());

		CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
        if (cgl_ctx)
        {
            GLint swap = 1;  // LIMIT SPEED TO VBL if swap == 1
            [[self openGLContext] setValues:&swap forParameter:NSOpenGLCPSwapInterval];
		
            glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        }
        
#ifdef WITH_OPENGL_32
        scene = [GLScene new];
        [scene addProgramImage];
        [scene addProgramOverlay];
        [scene addProgramOverlayLine];

        //renderer_setScene(&scene);
        [GLScene setCurrentScene: &scene]; // maybe only needed in drawRect
#endif
    }

    return self;
}

- (void)awakeFromNib
{
    NSLog(@"%s", __FUNCTION__);
	[[self enclosingScrollView] setBackgroundColor:[NSColor blackColor]];
}

- (void)dealloc
{
	NSLog(@"%s", __FUNCTION__);
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[thumbnailsTextureArray release];
	[isTextureWLWWUpdated release];
	[savedTransformDict release];
	
//	[previousViewer release];
	
	if (scrollTimer)
	{
		[scrollTimer invalidate];
		[scrollTimer release];
		scrollTimer = nil;
	}
	
	[cursorTracking release];
	
	[super dealloc];
}

- (void)setViewer;
{
	wl = [[self viewer] imageView].curWL;
	ww = [[self viewer] imageView].curWW;
	[self initTextureArray];
	[self computeThumbnailSize];
	[self setFrame:NSMakeRect(0.0, 0.0, [[[self viewer] pixList] count]*thumbnailWidth, [[self viewer] maxMovieIndex]*thumbnailHeight)];
	previousImageIndex = -1;
	previousMovieIndex = -1;
//	[previousViewer release];
//	previousViewer = [[self viewer] retain];
	[self loadTransformForCurrentViewer];
	[self setNeedsDisplay:YES];
}

- (void)initTextureArray;
{
	if (!thumbnailsTextureArray)
		thumbnailsTextureArray = [[NSMutableArray array] retain];
	else
	{
		[[self openGLContext] makeCurrentContext];
#ifndef WITH_OPENGL_32
		CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
        if (cgl_ctx == nil)
            return;
#endif
        
		for (NSNumber *n in thumbnailsTextureArray)
		{
			GLuint textureName = [n intValue];
			glDeleteTextures(1, &textureName);
		}
		[thumbnailsTextureArray removeAllObjects];
	}

	if (!isTextureWLWWUpdated)
		isTextureWLWWUpdated = [[NSMutableArray array] retain];
	else
		[isTextureWLWWUpdated removeAllObjects];
		
	for(int t=0; t<[[self viewer] maxMovieIndex]; t++)
	{
		NSMutableArray *pixList2 = [[self viewer] pixList:t];
		for(int z=0; z<[pixList2 count]; z++)
		{
			[thumbnailsTextureArray addObject:[NSNumber numberWithInt:-1]];
			[isTextureWLWWUpdated addObject:@NO];
		}
	}
}

- (GLuint) generateTextureForSlice:(int)z
                        movieIndex:(int)t
                        arrayIndex:(int)i;
{
	if (!thumbnailsTextureArray || i >= [thumbnailsTextureArray count])
        [self initTextureArray];
	
	NSMutableArray *pixList3 = [[self viewer] pixList:t];
	DCMPix *pix = [pixList3 objectAtIndex:z];
	
	if (![[isTextureWLWWUpdated objectAtIndex:i] boolValue])
        [pix changeWLWW:wl :ww];
	else if ([[thumbnailsTextureArray objectAtIndex:i] intValue] >= 0)
        return [[thumbnailsTextureArray objectAtIndex:i] intValue];
	
	[[self openGLContext] makeCurrentContext];
#ifndef WITH_OPENGL_32
	CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
#endif

	[isTextureWLWWUpdated replaceObjectAtIndex:i withObject:@YES];	
	
	char *textureBuffer = [pix baseAddr];
	
	GLuint textureID = 0;
	
	if (textureBuffer)
	{
#ifdef WITH_OPENGL_32
        GLenum target = GL_TEXTURE_RECTANGLE;
#else
        GLenum target = GL_TEXTURE_RECTANGLE_EXT;
#endif

#ifndef WITH_OPENGL_32
		glTextureRangeAPPLE(target, [pix pwidth]*[pix pheight]*4, textureBuffer);
#endif
		
		glGenTextures(1, &textureID);
		glBindTexture(target, textureID);
		glPixelStorei(GL_UNPACK_ROW_LENGTH, [pix pwidth]);
		glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);

#ifndef WITH_OPENGL_32
		glTexParameteri(target, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_CACHED_APPLE);
#endif

		GLfloat borderColor[4] = {0., 0., 0., 1.0}; // black
        glTexParameterfv(target, GL_TEXTURE_BORDER_COLOR, borderColor);

        glTexParameteri(target, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
        glTexParameteri(target, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
        glTexParameteri(target, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(target, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

#ifdef WITH_OPENGL_32
        GLint internalFormat = GL_R8;
        GLenum format = GL_RED;
#else
        GLint internalFormat = GL_INTENSITY8;
        GLenum format = GL_LUMINANCE;
#endif

		glTexImage2D(target, 0,
                     internalFormat,
                     [pix pwidth], [pix pheight], 0,

                     format, GL_UNSIGNED_BYTE,
                     textureBuffer);
		
		if ([[thumbnailsTextureArray objectAtIndex:i] intValue] >= 0)
		{
			GLuint oldTextureName = [[thumbnailsTextureArray objectAtIndex:i] intValue];
			glDeleteTextures(1, &oldTextureName);
		}

        [thumbnailsTextureArray replaceObjectAtIndex:i withObject:[NSNumber numberWithInt:textureID]];
	}
	else
		[thumbnailsTextureArray replaceObjectAtIndex:i withObject:[NSNumber numberWithInt:-1]];
		
	return textureID;
}

- (void)computeThumbnailSize;
{
	// we consider that every image has the same size
	DCMPix *aPix = [[[self viewer] pixList] objectAtIndex:0];
	int width = [aPix pwidth];
	int height = [aPix pheight]*[aPix pixelRatio];
	
	float wFactor = (float)width / (float)thumbnailMaxWidth;
	float hFactor = (float)height / (float)thumbnailMaxHeight;
	sizeFactor = (wFactor>hFactor) ? wFactor : hFactor;
		
	thumbnailWidth = width / sizeFactor;
	thumbnailHeight = height / sizeFactor;
		
	[[self enclosingScrollView] setHorizontalPageScroll:thumbnailWidth];
	[[self enclosingScrollView] setHorizontalLineScroll:thumbnailWidth];
	
	[[self enclosingScrollView] setVerticalPageScroll:thumbnailHeight];
	[[self enclosingScrollView] setVerticalLineScroll:thumbnailHeight];
}

#pragma mark - Drawing

- (void) reshape
{
	[self setNeedsDisplay: YES];
	
	[super reshape];
}

#pragma mark -

- (void)drawRect:(NSRect)a
{
    //NSLog(@"%s", __FUNCTION__);

	[[self openGLContext] makeCurrentContext];

	NSClipView *clipView = [[self enclosingScrollView] contentView];
	NSRect viewBounds = [self convertRectToBacking: [clipView documentVisibleRect]];
	NSRect viewFrame = [self convertRectToBacking: [clipView frame]];
	NSSize viewSize = viewFrame.size;
	
    float scaledThumbnailWidth = thumbnailWidth * self.window.backingScaleFactor;
    float scaledThumbnailHeight = thumbnailHeight * self.window.backingScaleFactor;
    
	CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    if (cgl_ctx == nil)
        return;

    checkOpenGLErrors(__LINE__);
    [GLScene setCurrentScene: &scene];

	glViewport(0, 0, viewSize.width, viewSize.height); // set the viewport to cover entire view
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT);
    checkOpenGLErrors(__LINE__);

#ifdef WITH_OPENGL_32
    GLenum target = GL_TEXTURE_RECTANGLE;
#else
    GLenum target = GL_TEXTURE_RECTANGLE_EXT;
    glEnable(target); checkOpenGLErrors(__LINE__);
#endif

#ifdef WITH_OPENGL_32
    glm::mat4 MV = glm::mat4(1.0);
    MV = glm::scale(MV, glm::vec3(2.0f/viewSize.width,
                                 -2.0f/viewSize.height,
                                  1.0f));
    MV = glm::translate(MV, glm::vec3(-viewSize.width/2.0,
                                      -viewSize.height/2.0,
                                      0.0));

    [scene.imageProgram Bind: __LINE__];
    [scene.imageProgram setUniformMatrix: glm::value_ptr(MV) name:"uModelViewM"];

    [scene.overlayLineProgram Bind: __LINE__];
    [scene.overlayLineProgram setUniformMatrix: glm::value_ptr(MV) name:"uModelViewM"];

#else
    glMatrixMode (GL_MODELVIEW);
	glLoadIdentity();
	glScalef(2.0f/viewSize.width, -2.0f/viewSize.height, 1.0f);
	glTranslatef(-viewSize.width/2.0, -viewSize.height/2.0, 0.0);
#endif
		
	int i=0;
	NSPoint upperLeft;
	NSRect thumbRect;
	
	NSArray *associatedViewers = [self associatedViewers];
	
#ifdef WITH_OPENGL_32
    GLScene *s = [GLScene currentScene];
    [s.overlayProgram Bind];
    [s.overlayProgram setMode: SHADER_MODE_TEXTURE_RGBA];
    [s.overlayProgram setUniformMatrix: glm::value_ptr(MV) name:"uModelViewM"]; // Added. TBC
    
    glm::mat4 M = glm::mat4(1.0);// Added. TBC
#endif
	for (int t=0; t<[[self viewer] maxMovieIndex]; t++)
	{
		BOOL highlightLine = NO;
        //renderer_set_rgba(0.5f, 0.5f, 0.5f, 1.0f);  // grey (redundant here ?)
        renderer_setTextColor(0.5f, 0.5f, 0.5f, 1.0f);  // grey (redundant here ?)

		if (t == [[self viewer] curMovieIndex])
			highlightLine = YES;
		else
		{
			// associated Viewers	
			for (ViewerController *v in associatedViewers)
			{
				if (t == [v curMovieIndex])
                    highlightLine = YES;
			}
		}
		
		if ([[self viewer] isPlaying4D])
            highlightLine = YES;
		
		BOOL highlightThumbnail = NO;
		NSMutableArray *pixList4 = [[self viewer] pixList:t];
		
		BOOL flippedData = [[[self viewer] imageView] flippedData];
		
		for (int z=0; z<[pixList4 count]; z++)
		{
			highlightThumbnail = highlightLine || (z == [[self viewer] imageIndex]);
			
#ifdef WITH_OPENGL_32
            //GLScene *s = [GLScene currentScene];
            [s.overlayProgram Bind];
            [s.overlayProgram setMode: SHADER_MODE_TEXTURE_RGBA];   // LUMINANCE ?

            if (highlightThumbnail)
                renderer_setTextColor(1.0f, 1.0f, 1.0f, 1.0f); // white
            else
                renderer_setTextColor(0.5f, 0.5f, 0.5f, 1.0f); // grey
#else
            if (highlightThumbnail)
                renderer_set_rgba(1.0f, 1.0f, 1.0f, 1.0f); // white
            else
                renderer_set_rgba(0.5f, 0.5f, 0.5f, 1.0f); // grey
#endif
			
			upperLeft = NSMakePoint(z*scaledThumbnailWidth-viewBounds.origin.x, t*scaledThumbnailHeight +viewBounds.origin.y +viewSize.height -viewFrame.size.height);
			thumbRect = NSMakeRect(upperLeft.x, upperLeft.y, scaledThumbnailWidth, scaledThumbnailHeight);
			
			if (NSIntersectsRect(thumbRect, viewFrame))
			{
				int correctedZ = (flippedData) ? [pixList4 count]-z-1 : z ;
				
				GLuint textureId = [self generateTextureForSlice:correctedZ movieIndex:t arrayIndex:i];
				
				{
					DCMPix *pix = [pixList4 objectAtIndex:correctedZ];
					
                    NSPoint texUpperLeft  = NSZeroPoint;
                    NSPoint texUpperRight = NSMakePoint(pix.pwidth, 0);
                    NSPoint texLowerLeft  = NSMakePoint(0, pix.pheight); // y *= [pix pixelRatio]
                    NSPoint texLowerRight = NSMakePoint(pix.pwidth, pix.pheight); // y *= [pix pixelRatio]

                    glBindTexture(target, textureId);
					glScissor( upperLeft.x, viewSize.height - (upperLeft.y+scaledThumbnailHeight), scaledThumbnailWidth, scaledThumbnailHeight);
					glEnable(GL_SCISSOR_TEST);
					
#ifdef WITH_OPENGL_32
                    // Define local matrix transformation (1)
                    M = glm::translate(M, glm::vec3(upperLeft.x, upperLeft.y, 0.0));
                    M = glm::translate(M, glm::vec3(scaledThumbnailWidth/2.0, scaledThumbnailHeight/2.0, 0.0));
                    M = glm::rotate(M, -rotationAngleRad, glm::vec3(0.0f, 0.0f, 1.0f));
                    M = glm::scale(M, glm::vec3(1.0/zoomFactor, 1.0/zoomFactor, 1.0));
                    M = glm::translate(M, glm::vec3(-scaledThumbnailWidth/2.0, -scaledThumbnailHeight/2.0, 0.0));
                    M = glm::translate(M, glm::vec3(-upperLeft.x, -upperLeft.y, 0.0));
                            
                    M = glm::translate(M, glm::vec3(-offset.x/sizeFactor, -offset.y/sizeFactor, 0.0));
#else
                    glTranslatef(upperLeft.x, upperLeft.y, 0.0);
                    glTranslatef(scaledThumbnailWidth/2.0, scaledThumbnailHeight/2.0, 0.0);
					glRotatef(glm::degrees(-rotationAngleRad), 0.0f, 0.0f, 1.0f);
					glScalef(1.0/zoomFactor, 1.0/zoomFactor, 1.0);
					glTranslatef(-scaledThumbnailWidth/2.0, -scaledThumbnailHeight/2.0, 0.0);
					glTranslatef(-upperLeft.x, -upperLeft.y, 0.0);
							
					glTranslatef(-offset.x/sizeFactor, -offset.y/sizeFactor, 0.0);
#endif
							
#pragma mark draw texture

                    //if ([pix pixelRatio]!=1.0) glScalef( 1.0, [pix pixelRatio], 1.0);
#ifdef WITH_OPENGL_32
                    GLScene *s = [GLScene currentScene];
                    [s.overlayProgram Bind];  // To use renderer_drawQuadStrip_xyuv()
                    [s.overlayProgram setMode: SHADER_MODE_TEXTURE_LUMINOSITY];

                    NSMutableArray *pArray = [NSMutableArray array];
                    
                    // TODO: Apply local model transformation
                    
                    glm::vec2 t = glm::vec2(texUpperLeft.x, texUpperLeft.y);
                    glm::vec2 p = glm::vec2(upperLeft.x, upperLeft.y);
                    glm::vec4 v = glm::vec4(p, t);
                    [pArray addObject: [NSValue valueWithBytes:&v
                                                      objCType:@encode(glm::vec4)]];
                    
                    t = glm::vec2(texUpperRight.x, texUpperRight.y);
                    p = glm::vec2(upperLeft.x+scaledThumbnailWidth, upperLeft.y);
                    v = glm::vec4(p, t);
                    [pArray addObject: [NSValue valueWithBytes:&v
                                                      objCType:@encode(glm::vec4)]];

                    
                    t = glm::vec2(texLowerLeft.x, texLowerLeft.y);
                    p = glm::vec2(upperLeft.x, upperLeft.y+scaledThumbnailHeight);
                    v = glm::vec4(p, t);
                    [pArray addObject: [NSValue valueWithBytes:&v
                                                      objCType:@encode(glm::vec4)]];
                
                    t = glm::vec2(texLowerRight.x, texLowerRight.y);
                    p = glm::vec2(upperLeft.x+scaledThumbnailWidth, upperLeft.y+scaledThumbnailHeight);
                    v = glm::vec4(p, t);
                    [pArray addObject: [NSValue valueWithBytes:&v
                                                      objCType:@encode(glm::vec4)]];
                    
                    renderer_drawQuadStrip_xyuv([pArray copy]);
#else
                    NSLog(@"%s %d, GL_QUAD_STRIP", __FUNCTION__, __LINE__);
                    glBegin(GL_QUAD_STRIP);
                    {
                        glTexCoord2f(texUpperLeft.x, texUpperLeft.y);
                        glVertex2f(upperLeft.x, upperLeft.y);
                        
                        glTexCoord2f(texUpperRight.x, texUpperRight.y);
                        glVertex2f(upperLeft.x+scaledThumbnailWidth, upperLeft.y);
                        
                        glTexCoord2f(texLowerLeft.x, texLowerLeft.y);
                        glVertex2f(upperLeft.x, upperLeft.y+scaledThumbnailHeight);
                    
                        glTexCoord2f(texLowerRight.x, texLowerRight.y);
                        glVertex2f(upperLeft.x+scaledThumbnailWidth, upperLeft.y+scaledThumbnailHeight);
                    }
                    glEnd();
#endif
						
					glDisable(GL_SCISSOR_TEST); checkOpenGLErrors(__LINE__);

					//if ([pix pixelRatio]!=1.0) glScalef(1.0, 1.0/[pix pixelRatio], 1.0);
					
#ifdef WITH_OPENGL_32
                    NSLog(@"%s %d, TODO: OpenGL Core", __FUNCTION__, __LINE__);
                    // Undo local matrix transformation (1)
                    M = glm::translate(M, glm::vec3(offset.x/sizeFactor, offset.y/sizeFactor, 0.0));
                    
                    M = glm::translate(M, glm::vec3(upperLeft.x, upperLeft.y, 0.0));
                    M = glm::translate(M, glm::vec3(scaledThumbnailWidth/2.0, scaledThumbnailHeight/2.0, 0.0));
                    M = glm::scale(M, glm::vec3(zoomFactor, zoomFactor, 1.0));
                    M = glm::rotate(M, rotationAngleRad, glm::vec3(0.0f, 0.0f, 1.0f));
                    M = glm::translate(M, glm::vec3(-scaledThumbnailWidth/2.0, -scaledThumbnailHeight/2.0, 0.0));
                    M = glm::translate(M, glm::vec3(-upperLeft.x, -(upperLeft.y), 0.0));
#else
					glTranslatef(offset.x/sizeFactor, offset.y/sizeFactor, 0.0);
					
					glTranslatef(upperLeft.x, upperLeft.y, 0.0);
					glTranslatef(scaledThumbnailWidth/2.0, scaledThumbnailHeight/2.0, 0.0);
					glScalef(zoomFactor, zoomFactor, 1.0);
					glRotatef(glm::degrees(rotationAngleRad), 0.0f, 0.0f, 1.0f);
					glTranslatef(-scaledThumbnailWidth/2.0, -scaledThumbnailHeight/2.0, 0.0);
					glTranslatef(-upperLeft.x, -(upperLeft.y), 0.0);
#endif
				}
			}
			else
			{
				if (i < [thumbnailsTextureArray count])
				{
					if ([[thumbnailsTextureArray objectAtIndex:i] intValue] >= 0)
					{
						GLuint oldTextureName = [[thumbnailsTextureArray objectAtIndex:i] intValue];
						glDeleteTextures(1, &oldTextureName);
					}
					[thumbnailsTextureArray replaceObjectAtIndex:i withObject:[NSNumber numberWithInt:-1]];
				}
				else
					[thumbnailsTextureArray addObject:[NSNumber numberWithInt:-1]];
			}

            i++;
		}
	}
	
#ifndef WITH_OPENGL_32
	glDisable(GL_TEXTURE_RECTANGLE_EXT);
#endif
	
#pragma mark annotations

#if 0 //def DRAW_ROIS_IN_NAVIGATOR_WITH_OPENGL_32
    // TODO
    // Try printing and comparing the context used by the ROI
#else // DRAW_ROIS_IN_NAVIGATOR_WITH_OPENGL_32
    if ([[NSUserDefaults standardUserDefaults] integerForKey: ANNOTATIONS_KEY] > ANNOTATIONS_NONE)
	{
    #ifdef WITH_OPENGL_32
        [scene.overlayProgram Bind: __LINE__];
        M = glm::mat4(1.0);
    #endif
		for (int t=0; t<[[self viewer] maxMovieIndex]; t++)
		{
			NSMutableArray *pixList5 = [[self viewer] pixList:t];
			NSMutableArray *roiList5 = [[self viewer] roiList:t];
			
			BOOL flippedData = [[[self viewer] imageView] flippedData];
					
			for (int z=0; z<[pixList5 count]; z++)
			{
				int correctedZ = (flippedData) ? [pixList5 count]-z-1 : z ;
				DCMPix *pix = [pixList5 objectAtIndex:correctedZ];
				
				upperLeft = NSMakePoint(z*scaledThumbnailWidth-viewBounds.origin.x, t*scaledThumbnailHeight+viewBounds.origin.y+viewSize.height-viewFrame.size.height);
				
				glScissor( upperLeft.x, viewSize.height - (upperLeft.y+scaledThumbnailHeight), scaledThumbnailWidth, scaledThumbnailHeight);
				glEnable(GL_SCISSOR_TEST);
		
				NSArray *rois = [roiList5 objectAtIndex:correctedZ];

    #ifdef WITH_OPENGL_32
                //[overlayProgram Bind: __LINE__];
                #define WITH_LOCAL_MV_MATRIX_TRANSFORMATION_NAVIGATOR2
                #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_NAVIGATOR2
                // Define local matrix transformation (2)
                M = glm::translate(M, glm::vec3(upperLeft.x, upperLeft.y, 0.0));
                M = glm::translate(M, glm::vec3(scaledThumbnailWidth/2.0, scaledThumbnailHeight/2.0, 0.0));
                M = glm::rotate(M, -rotationAngleRad, glm::vec3(0.0f, 0.0f, 1.0f));

                if ([pix pixelRatio]!=1.0)
                    M = glm::scale(M, glm::vec3( 1.0, [pix pixelRatio], 1.0));
                #endif
    #else
				glTranslatef(upperLeft.x, upperLeft.y, 0.0);
				glTranslatef(scaledThumbnailWidth/2.0, scaledThumbnailHeight/2.0, 0.0);
				glRotatef(glm::degrees(-rotationAngleRad), 0.0f, 0.0f, 1.0f);
				
				if ([pix pixelRatio]!=1.0)
                    glScalef( 1.0, [pix pixelRatio], 1.0);
    #endif

                float f = self.window.backingScaleFactor;
                
				for (ROI *r in rois)
				{
    #ifdef WITH_OPENGL_32
                    GLScene *s = [GLScene currentScene];
                    [s.overlayProgram Bind];           // Added
                    [s.overlayProgram setMode: SHADER_MODE_NORMAL];    // Added
    #endif
					renderer_set_rgba(1.0f, 1.0f, 1.0f, 1.0f); // white, maybe redundant
					
					if ([r type] != tText)
					{
                        NSPoint anOffset = NSMakePoint(offset.x / f + pix.pwidth/2.0,
                                                       offset.y / (f*[pix pixelRatio]) + pix.pheight/2.0);
                        NSSize aSpacing= NSMakeSize([pix pixelSpacingX], [pix pixelSpacingY]);
                        #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_NAVIGATOR2
                        // Apply local matrix transformation
                        glm::vec2 pA(anOffset.x, anOffset.y);
                        glm::vec4 pTemp = M*glm::vec4(pA,0,1);
                        pA = glm::vec2(pTemp.x, pTemp.y);
                        anOffset = NSMakePoint(pTemp.x, pTemp.y);
                        
                        // TODO: aSpacing
                        #endif
						[r drawROIWithScaleValue: f/(zoomFactor*sizeFactor)
                                          offset: anOffset
                                    pixelSpacing: aSpacing
                             highlightIfSelected: NO
                                       thickness: 1.0
                              prepareTextualData: NO];
					}
				}
				
				glDisable(GL_SCISSOR_TEST);
				
    #ifdef WITH_OPENGL_32
                #ifdef WITH_LOCAL_MV_MATRIX_TRANSFORMATION_NAVIGATOR2
                // Undo local matrix transformation (2)
                if ([pix pixelRatio] != 1.0)
                    M = glm::scale(M, glm::vec3(1.0, 1.0/[pix pixelRatio], 1.0));

                M = glm::rotate(M, rotationAngleRad, glm::vec3(0.0f, 0.0f, 1.0f));
                M = glm::translate(M, glm::vec3(-scaledThumbnailWidth/2.0,
                                                -scaledThumbnailHeight/2.0,
                                                0.0));
                M = glm::translate(M, glm::vec3(-upperLeft.x, -upperLeft.y, 0.0));
                #endif
    #else
				if ([pix pixelRatio] != 1.0)
                    glScalef(1.0, 1.0/[pix pixelRatio], 1.0);

                glRotatef(glm::degrees(rotationAngleRad), 0.0f, 0.0f, 1.0f);
				glTranslatef(-scaledThumbnailWidth/2.0, -scaledThumbnailHeight/2.0, 0.0);
				glTranslatef(-upperLeft.x, -upperLeft.y, 0.0);
    #endif
			} // for z
		} // for t
	}
#endif // DRAW_ROIS_IN_NAVIGATOR_WITH_OPENGL_32

#pragma mark draw selection in associated 4D viewers

    glEnable(GL_LINE_SMOOTH); checkOpenGLErrors(__LINE__);
		
	// Associated Viewers
    NSLog(@"%s %d, associatedViewers count:%lu", __FUNCTION__, __LINE__, (unsigned long)[associatedViewers count]);
	for (ViewerController *v in [self associatedViewers])
	{
		int t = [v curMovieIndex];
		upperLeft.y = t*scaledThumbnailHeight+viewBounds.origin.y+viewSize.height-viewFrame.size.height;
		
		int z = [v imageIndex];
		upperLeft.x = z*scaledThumbnailWidth-viewBounds.origin.x;
		thumbRect = NSMakeRect(upperLeft.x, upperLeft.y, scaledThumbnailWidth, scaledThumbnailHeight);
		
#ifndef DEBUG_NAVIGATOR_PANEL
		if (NSIntersectsRect(thumbRect, viewFrame))
#endif
		{
			glScissor( upperLeft.x, viewSize.height - (upperLeft.y+scaledThumbnailHeight), scaledThumbnailWidth, scaledThumbnailHeight);
			glEnable(GL_SCISSOR_TEST);
			
            #ifdef WITH_OPENGL_32
            [scene.overlayLineProgram Bind];
            #endif
			renderer_setLineWidth(6.0 * self.window.backingScaleFactor);
            renderer_set_rgb(0.0f, 1.0f, 0.0f); // green

#ifdef WITH_OPENGL_32
            //[overlayProgram Bind: __LINE__];
            const int nPoints = 4;
            glm::vec2 pA[nPoints];
            
            pA[0] = glm::vec2(upperLeft.x+1, upperLeft.y+1);
            pA[1] = glm::vec2(upperLeft.x-1+scaledThumbnailWidth, upperLeft.y+1);
            pA[2] = glm::vec2(upperLeft.x-1+scaledThumbnailWidth, upperLeft.y+scaledThumbnailHeight-1);
            pA[3] = glm::vec2(upperLeft.x+1, upperLeft.y+scaledThumbnailHeight-1);
            
            NSMutableArray *pArray = [NSMutableArray array];
            for (int i=0; i<nPoints; i++)
                [pArray addObject: [NSValue valueWithBytes:&pA[i] objCType:@encode(glm::vec2)]];

            renderer_drawLine_xy([pArray copy], GL_LINE_LOOP);
#else
			glBegin(GL_LINE_LOOP);
            {
				glVertex2f(upperLeft.x+1, upperLeft.y+1);
				glVertex2f(upperLeft.x-1+scaledThumbnailWidth, upperLeft.y+1);
				glVertex2f(upperLeft.x-1+scaledThumbnailWidth, upperLeft.y+scaledThumbnailHeight-1);
				glVertex2f(upperLeft.x+1, upperLeft.y+scaledThumbnailHeight-1);
            }
			glEnd();
#endif
			glDisable(GL_SCISSOR_TEST);
			
			renderer_set_rgb(0.0f, 0.0f, 0.0f);  // black
			renderer_setLineWidth(1.0 * self.window.backingScaleFactor);
		}
	}
	
    // Selected time line
    int t = [[self viewer] curMovieIndex];
	upperLeft.y = t*scaledThumbnailHeight + viewBounds.origin.y + viewSize.height - viewFrame.size.height;

    // Selected image
    int z = [[self viewer] imageIndex];
	upperLeft.x = z*scaledThumbnailWidth - viewBounds.origin.x;
	thumbRect = NSMakeRect(upperLeft.x, upperLeft.y, scaledThumbnailWidth, scaledThumbnailHeight);

#pragma mark red box

    if (NSIntersectsRect(thumbRect, viewFrame))
	{
		glScissor( upperLeft.x, viewSize.height - (upperLeft.y+scaledThumbnailHeight), scaledThumbnailWidth, scaledThumbnailHeight);
		glEnable(GL_SCISSOR_TEST);
		
#ifdef WITH_OPENGL_32
        [scene.overlayLineProgram Bind: __LINE__];
#endif
		renderer_setLineWidth(6.0 * self.window.backingScaleFactor);
        renderer_set_rgb(1.0f, 0.0f, 0.0f); // red
#ifdef WITH_OPENGL_32
        const int nPoints = 4;
        glm::vec2 pA[nPoints];
        pA[0] = glm::vec2(upperLeft.x+1, upperLeft.y+1);
        pA[1] = glm::vec2(upperLeft.x-1+scaledThumbnailWidth, upperLeft.y+1);
        pA[2] = glm::vec2(upperLeft.x-1+scaledThumbnailWidth, upperLeft.y+scaledThumbnailHeight-1);
        pA[3] = glm::vec2(upperLeft.x+1, upperLeft.y+scaledThumbnailHeight-1);

        NSMutableArray *pArray = [NSMutableArray array];
        for (int i=0; i<nPoints; i++) {
            [pArray addObject: [NSValue valueWithBytes:&pA[i] objCType:@encode(glm::vec2)]];
        }

        renderer_drawLine_xy([pArray copy], GL_LINE_LOOP);
#else
		glBegin(GL_LINE_LOOP);
        {
			glVertex2f(upperLeft.x+1, upperLeft.y+1);
			glVertex2f(upperLeft.x-1+scaledThumbnailWidth, upperLeft.y+1);
			glVertex2f(upperLeft.x-1+scaledThumbnailWidth, upperLeft.y+scaledThumbnailHeight-1);
			glVertex2f(upperLeft.x+1, upperLeft.y+scaledThumbnailHeight-1);
        }
		glEnd();
#endif
        
        // Restore
		glDisable(GL_SCISSOR_TEST);
		renderer_set_rgb(0.0f, 0.0f, 0.0f); // black
		renderer_setLineWidth(1.0 * self.window.backingScaleFactor);
	}

	glDisable(GL_LINE_SMOOTH);
	
#pragma mark lateral scroll bar (left)

#ifndef DEBUG_NAVIGATOR_PANEL
    if (drawLeftLateralScrollBar && [self cansScrollLeft])
#endif
	{
		// draw the dark part
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		glEnable(GL_BLEND);
		glEnable(GL_POLYGON_SMOOTH);
#ifdef WITH_OPENGL_32
        GLScene *s = [GLScene currentScene];
        [s.overlayProgram Bind];   // Added
        [s.overlayProgram setMode: SHADER_MODE_NORMAL];   // Added
#endif
        renderer_set_rgba(0.0f, 0.0f, 0.0f, 0.75f); // black 0.75

#ifdef WITH_OPENGL_32
        {
        const int nPoints = 4;
        glm::vec2 pA[nPoints];
        pA[0] = glm::vec2(0.0, 0.0);
        pA[1] = glm::vec2(lateralScrollBarSize, 0.0);
        pA[2] = glm::vec2(lateralScrollBarSize, viewSize.height);
        pA[3] = glm::vec2(0.0, viewSize.height);
        
        NSMutableArray *pArray = [NSMutableArray array];
        for (int i=0; i<nPoints; i++)
            [pArray addObject: [NSValue valueWithBytes:&pA[i] objCType:@encode(glm::vec2)]];

        renderer_drawPolygon([pArray copy]); // fills the inside ?
        }
#else
		glBegin(GL_POLYGON);
        {
			glVertex2f(0.0, 0.0);
			glVertex2f(lateralScrollBarSize, 0.0);
			glVertex2f(lateralScrollBarSize, viewSize.height);
			glVertex2f(0.0, viewSize.height);
        }
		glEnd();
#endif
		
        // draw the white left triangle
		renderer_set_rgba(1.0f, 1.0f, 1.0f, 0.9f); // white 0.9

#ifdef WITH_OPENGL_32
        {
        const int nPoints = 3;
        glm::vec2 pA[nPoints];
        pA[0] = glm::vec2(lateralScrollBarSize-7.0, viewBounds.size.height/2.0-6.0);
        pA[1] = glm::vec2(lateralScrollBarSize-7.0, viewBounds.size.height/2.0+6.0);
        pA[2] = glm::vec2(3.0, viewBounds.size.height/2.0);
            
        NSMutableArray *pArray = [NSMutableArray array];
        for (int i=0; i<nPoints; i++)
            [pArray addObject: [NSValue valueWithBytes:&pA[i] objCType:@encode(glm::vec2)]];

        renderer_drawPolygon([pArray copy]); // fills the inside ?
        }
#else
		glBegin(GL_POLYGON);
        {
			glVertex2f(lateralScrollBarSize-7.0, viewBounds.size.height/2.0-6.0);
			glVertex2f(lateralScrollBarSize-7.0, viewBounds.size.height/2.0+6.0);
			glVertex2f(3.0, viewBounds.size.height/2.0);
        }
		glEnd();
#endif

        renderer_set_rgb(0.0f, 0.0f, 0.0f); // black
		glDisable(GL_BLEND);
		glDisable(GL_POLYGON_SMOOTH);
	}
	
#pragma mark lateral scroll bar (right)

#ifndef DEBUG_NAVIGATOR_PANEL
	if (drawRightLateralScrollBar && [self cansScrollRight])
#endif
	{
		// draw the dark part
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		glEnable(GL_BLEND);
		glEnable(GL_POLYGON_SMOOTH);

#ifdef WITH_OPENGL_32
        GLScene *s = [GLScene currentScene];
        [s.overlayProgram Bind];           // Added
        [s.overlayProgram setMode: SHADER_MODE_NORMAL];    // Added
#endif

        renderer_set_rgba(0.0f, 0.0f, 0.0f, 0.75f); // black 0.75
#ifdef WITH_OPENGL_32
        {
        const int nPoints = 4;
        glm::vec2 pA[nPoints];
        pA[0] = glm::vec2(viewBounds.size.width-lateralScrollBarSize, 0.0);
        pA[1] = glm::vec2(viewBounds.size.width, 0.0);
        pA[2] = glm::vec2(viewBounds.size.width, viewSize.height);
        pA[3] = glm::vec2(viewBounds.size.width-lateralScrollBarSize, viewSize.height);
        
        NSMutableArray *pArray = [NSMutableArray array];
        for (int i=0; i<nPoints; i++)
            [pArray addObject: [NSValue valueWithBytes:&pA[i] objCType:@encode(glm::vec2)]];

        renderer_drawPolygon([pArray copy]); // fills the inside ?
        }
#else
		glBegin(GL_POLYGON);
        {
			glVertex2f(viewBounds.size.width-lateralScrollBarSize, 0.0);
			glVertex2f(viewBounds.size.width, 0.0);
			glVertex2f(viewBounds.size.width, viewSize.height);
			glVertex2f(viewBounds.size.width-lateralScrollBarSize, viewSize.height);
        }
		glEnd();
#endif
				
        // draw the white right triangle
        renderer_set_rgba(1.0f, 1.0f, 1.0f, 0.9f); // white 0.9
#ifdef WITH_OPENGL_32
        {
        const int nPoints = 3;
        glm::vec2 pA[nPoints];
        pA[0] = glm::vec2(viewBounds.size.width-lateralScrollBarSize+6.0,
                          viewBounds.size.height/2.0-6.0);
        pA[1] = glm::vec2(viewBounds.size.width-lateralScrollBarSize+6.0,
                          viewBounds.size.height/2.0+6.0);
        pA[2] = glm::vec2(viewBounds.size.width-4.0,
                          viewBounds.size.height/2.0);
        
        NSMutableArray *pArray = [NSMutableArray array];
        for (int i=0; i<nPoints; i++)
            [pArray addObject: [NSValue valueWithBytes:&pA[i] objCType:@encode(glm::vec2)]];

        renderer_drawPolygon([pArray copy]); // fills the inside ?
        }
#else
		glBegin(GL_POLYGON);
        {
			glVertex2f(viewBounds.size.width-lateralScrollBarSize+6.0, viewBounds.size.height/2.0-6.0);
			glVertex2f(viewBounds.size.width-lateralScrollBarSize+6.0, viewBounds.size.height/2.0+6.0);
			glVertex2f(viewBounds.size.width-4.0, viewBounds.size.height/2.0);
        }
		glEnd();
#endif
        renderer_set_rgb(0.0f, 0.0f, 0.0f); // black
		glDisable(GL_BLEND);
		glDisable(GL_POLYGON_SMOOTH);
	}
	
// mouse position (for debug purpose)	
//	glPointSize(10.0 * self.window.backingScaleFactor);
//	renderer_set_rgb(0.0f, 1.0f, 1.0f);
//	glBegin(GL_POINTS);
//		glVertex2f(mouseMovedPosition.x, mouseMovedPosition.y);
//	glEnd();
//	renderer_set_rgb(0.0f, 0.0f, 0.0f);
//	glPointSize(1.0 * self.window.backingScaleFactor);

	[[self openGLContext] flushBuffer];
}

#pragma mark - Mouse functions

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
	return YES;
}

- (BOOL)acceptsFirstResponder
{
	return NO;
}

- (NSPoint)convertPointFromWindowToOpenGL:(NSPoint)pointInWindow;
{
	NSPoint pointInView = [self convertPoint:pointInWindow fromView:nil];
	pointInView.x -= [[[self enclosingScrollView] contentView] documentVisibleRect].origin.x;
	pointInView.y -= [[[self enclosingScrollView] contentView] documentVisibleRect].origin.y;
	pointInView.y = [[[self enclosingScrollView] contentView] documentVisibleRect].size.height-pointInView.y;
    
    pointInView = [self convertPointToBacking: pointInView];
    
	return pointInView;
}

- (void)mouseDown:(NSEvent *)theEvent;
{
	NSPoint event_location = [theEvent locationInWindow];
	mouseDownPosition = [self convertPointFromWindowToOpenGL:event_location];	
	mouseDragged = NO;
	
	BOOL scrollLeft = [self isMouseOnLeftLateralScrollBar: [self convertPointFromBacking: mouseDownPosition]] && [self cansScrollLeft];
	BOOL scrollRight = [self isMouseOnRightLateralScrollBar: [self convertPointFromBacking: mouseDownPosition]] && [self cansScrollRight];

	mouseClickedWithCommandKey = NO;
	
	if ([theEvent modifierFlags] & NSEventModifierFlagShift)
    {
        userAction=zoom;
    }
	else if (([theEvent modifierFlags] & NSEventModifierFlagOption) &&
            ([theEvent modifierFlags] & NSEventModifierFlagCommand))
    {
        userAction=rotate;
    }
	else if ([theEvent modifierFlags] & NSEventModifierFlagCommand)
	{
		userAction=translate;
		mouseClickedWithCommandKey = YES;
	}
	else if ([theEvent modifierFlags] & NSEventModifierFlagOption)
    {
        userAction=wlww;
    }
	else
	{
		if (!scrollLeft && !scrollRight)
            [self displaySelectedViewInNewWindow:NO];

        userAction = (MouseEventType)[[self viewer] imageView].currentTool;
	}

	startWW = ww;
	startWL = wl;
	
    if (scrollLeft && !scrollTimer)
    {
        scrollTimer = [[NSTimer scheduledTimerWithTimeInterval:0.01
                                                        target:self
                                                      selector:@selector(scrollLeft:)
                                                      userInfo:nil
                                                       repeats:YES] retain];
    }
    else if (scrollRight && !scrollTimer)
    {
        scrollTimer = [[NSTimer scheduledTimerWithTimeInterval:0.01
                                                        target:self
                                                      selector:@selector(scrollRight:)
                                                      userInfo:nil
                                                       repeats:YES] retain];
    }

	if (scrollLeft || scrollRight)
	{
		userAction = idle;
	}
	
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
	NSPoint event_location = [theEvent locationInWindow];
	mouseDownPosition = [self convertPointFromWindowToOpenGL:event_location];	

	userAction = (MouseEventType)[[self viewer] imageView].currentToolRight;
}

- (void)mouseDragged:(NSEvent *)theEvent;
{
	NSPoint event_location = [theEvent locationInWindow];
	mouseDraggedPosition = [self convertPointFromWindowToOpenGL:event_location];
	mouseDragged = YES;
	
	if (userAction==translate)
		[self translationFrom:mouseDownPosition to:mouseDraggedPosition];
	else if (userAction==rotate)
		[self rotateFrom:mouseDownPosition to:mouseDraggedPosition];
	else if (userAction==zoom)
		[self zoomFrom:mouseDownPosition to:mouseDraggedPosition];
	else if (userAction==wlww)
		[self wlwwFrom:mouseDownPosition to:mouseDraggedPosition];
		
	if (userAction!=wlww)
        mouseDownPosition = mouseDraggedPosition;
	
	[self setNeedsDisplay:YES];
}

- (void)rightMouseDragged:(NSEvent *)theEvent;
{
	[self mouseDragged:theEvent];
}

- (void)mouseUp:(NSEvent *)theEvent;
{
	BOOL scrollLeft = [self isMouseOnLeftLateralScrollBar: [self convertPointFromBacking: mouseDownPosition]] && [self cansScrollLeft];
	BOOL scrollRight = [self isMouseOnRightLateralScrollBar: [self convertPointFromBacking: mouseDownPosition]] && [self cansScrollRight];

	if (!mouseDragged && !scrollLeft && !scrollRight)
	{
		BOOL newWindow = mouseClickedWithCommandKey;
		[self displaySelectedViewInNewWindow:newWindow];
	}
	
	userAction = idle;
	if (scrollTimer)
	{
		[scrollTimer invalidate];
		[scrollTimer release];
		scrollTimer = nil;
	}
}

- (void)rightMouseUp:(NSEvent *)theEvent;
{
	[self mouseUp:theEvent];
}

- (void)translationFrom:(NSPoint)start to:(NSPoint)stop;
{
	translation.x = start.x - stop.x;
	translation.y = start.y - stop.y;

	translation = [self rotatePoint:translation
                        aroundPoint:NSZeroPoint
                              angle:rotationAngleRad];

	offset.x += translation.x*zoomFactor*sizeFactor;
	offset.y += translation.y*zoomFactor*sizeFactor;
}

- (void)rotateFrom:(NSPoint)start
                to:(NSPoint)stop;
{
	rotationAngleRad += (stop.x-start.x) / (sizeFactor * 10.);
}

- (NSPoint)rotatePoint:(NSPoint)pt
           aroundPoint:(NSPoint)c
                 angle:(float)aRad;
{
	pt.x -= c.x;
	pt.y -= c.y;
	
    NSPoint rot;
	rot.x = cos(aRad)*pt.x - sin(aRad)*pt.y;
	rot.y = sin(aRad)*pt.x + cos(aRad)*pt.y;

	rot.x += c.x;
	rot.y += c.y;
	
	return rot;
}

- (void)zoomFrom:(NSPoint)start
              to:(NSPoint)stop;
{
	float zoom = stop.y - start.y;
 	zoom *= zoomFactor;
 	zoom /= 50.;
	
	zoomFactor += zoom;
	
	if (zoomFactor < 0.01)
        zoomFactor = 0.01;

    if (zoomFactor > 10)
        zoomFactor = 10;
}

- (NSPoint)zoomPoint:(NSPoint)pt
          withCenter:(NSPoint)c
              factor:(float)f;
{
	pt.x -= c.x;
	pt.y -= c.y;
	
	pt.x *= f;
	pt.y *= f;

	pt.x += c.x;
	pt.y += c.y;
	
	return pt;
}

- (void)changeWLWW:(NSNotification*)notif;
{
	if (dontListenToNotification > 0)
        return;

	DCMPix *pix = [notif object];
	if (pix.ww!=ww || pix.wl!=wl)
	{
		ww = pix.ww;
		wl = pix.wl;
		for(int i=0; i<[isTextureWLWWUpdated count]; i++)
			[isTextureWLWWUpdated replaceObjectAtIndex:i withObject:@NO];
		[self setNeedsDisplay:YES];
		
		for (ViewerController *viewer in [self associatedViewers])
		{
			[[viewer imageView] setWLWW:wl :ww];
		}
	}
}

- (void)refresh:(NSNotification*)notif;
{
	if (dontListenToNotification > 0)
        return;
	
	int curImageIndex = [[self viewer] imageIndex];
	int curMovieIndex = [[self viewer] curMovieIndex];
	if (curImageIndex != previousImageIndex ||
        curMovieIndex != previousMovieIndex)
	{
		[self computeThumbnailSize];
		[[[self viewer] imageView] sendSyncMessage:0];
		[self displaySelectedImage];
		[self setNeedsDisplay:YES];
		previousImageIndex = curImageIndex;
		previousMovieIndex = curMovieIndex;
	}
}

- (void)refreshROIs:(NSNotification*)notif;
{
	if (dontListenToNotification > 0)
        return;
	
	[self displaySelectedImage];
	[self setNeedsDisplay:YES];
}

- (void)wlwwFrom:(NSPoint)start to:(NSPoint)stop;
{
	float WWAdapter = startWW / 100.0;
	if (WWAdapter < 0.001)
        WWAdapter = 0.001;
	
	wl = startWL - (stop.y - start.y)*WWAdapter;
	ww = startWW + (stop.x - start.x)*WWAdapter;
	
	[[[self viewer] imageView] setWLWW:wl :ww];

    for (int i=0; i<[isTextureWLWWUpdated count]; i++)
		[isTextureWLWWUpdated replaceObjectAtIndex:i withObject:@NO];
		
	for (ViewerController *viewer in [self associatedViewers])
		[[viewer imageView] setWLWW:wl :ww];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
	if (![[self window] isVisible])
		return;
	
	NSPoint event_location = [theEvent locationInWindow];
	mouseMovedPosition = [self convertPointFromWindowToOpenGL:event_location];	
	
	BOOL leftLateralScrollBarAlreadyDrawn = drawLeftLateralScrollBar;
	BOOL rightLateralScrollBarAlreadyDrawn = drawRightLateralScrollBar;

	drawLeftLateralScrollBar = NO;
	drawRightLateralScrollBar = NO;
	
	if ([self isMouseOnLeftLateralScrollBar:mouseMovedPosition])
	{
		drawLeftLateralScrollBar = YES;
	}
	else if ([self isMouseOnRightLateralScrollBar:mouseMovedPosition])
	{
		drawRightLateralScrollBar = YES;
	}
	
	if (leftLateralScrollBarAlreadyDrawn != drawLeftLateralScrollBar || rightLateralScrollBarAlreadyDrawn != drawRightLateralScrollBar)
    {
		[self setNeedsDisplay:YES];
    }
		
//	BOOL scrollLeft = [self isMouseOnLeftLateralScrollBar:mouseMovedPosition];
//	BOOL scrollRight = [self isMouseOnRightLateralScrollBar:mouseMovedPosition];
//	if (scrollLeft && !scrollTimer) scrollTimer = [[NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(scrollLeft:) userInfo:nil repeats:YES] retain];
//	else if (scrollRight && !scrollTimer) scrollTimer = [[NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(scrollRight:) userInfo:nil repeats:YES] retain];
//
//	if (scrollLeft || scrollRight)
//	{
//		//[scrollTimer fire];
//		userAction = idle;
//	}
//	else if (scrollTimer)
//	{
//		[scrollTimer invalidate];
//		[scrollTimer release];
//		scrollTimer = nil;
//	}
}

- (void)mouseExited:(NSEvent *)theEvent
{
	BOOL leftLateralScrollBarAlreadyDrawn = drawLeftLateralScrollBar;
	BOOL rightLateralScrollBarAlreadyDrawn = drawRightLateralScrollBar;

	drawLeftLateralScrollBar = NO;
	drawRightLateralScrollBar = NO;

	if (leftLateralScrollBarAlreadyDrawn != drawLeftLateralScrollBar ||
        rightLateralScrollBarAlreadyDrawn != drawRightLateralScrollBar)
    {
		[self setNeedsDisplay:YES];
    }
}

#pragma mark - Scroll functions

- (BOOL)isMouseOnLeftLateralScrollBar:(NSPoint)mousePos;
{
	NSClipView *clipView = [[self enclosingScrollView] contentView];
	NSRect viewBounds = [clipView documentVisibleRect];
	BOOL inZone = mousePos.x <= lateralScrollBarSize;
	inZone = inZone && mousePos.x>=0;
	inZone = inZone && mousePos.y+viewBounds.origin.y<=viewBounds.size.height;
	inZone = inZone && mousePos.y+viewBounds.origin.y>=0;
	return inZone;
}

- (BOOL)isMouseOnRightLateralScrollBar:(NSPoint)mousePos;
{
	NSClipView *clipView = [[self enclosingScrollView] contentView];
	NSRect viewBounds = [clipView documentVisibleRect];
	BOOL inZone = mousePos.x >= viewBounds.size.width - lateralScrollBarSize;
	inZone = inZone && mousePos.x<=viewBounds.size.width;
	inZone = inZone && mousePos.y+viewBounds.origin.y<=viewBounds.size.height;
	inZone = inZone && mousePos.y+viewBounds.origin.y>=0;
	return inZone;
}

- (BOOL)canScrollHorizontallyOfAmount:(float)amount;
{
	NSClipView *clipView = [[self enclosingScrollView] contentView];
	NSRect viewBounds = [clipView documentVisibleRect];
	NSPoint origin = viewBounds.origin;
	
	BOOL canScroll = YES;
	
	if (amount<0)
        canScroll = (origin.x>0);
	else
        canScroll = (origin.x+viewBounds.size.width<[self frame].size.width);

	return canScroll;
}

- (void)scrollHorizontallyOfAmount:(float)amount;
{
	NSClipView *clipView = [[self enclosingScrollView] contentView];
	NSRect viewBounds = [clipView documentVisibleRect];
	NSPoint newOrigin = viewBounds.origin;
	newOrigin.x += amount;
//	if ([self needsHorizontalScroller])
//		newOrigin.y += 20.0; // ... ?? don't know why, but it works...
		
	if (newOrigin.x<0)
        newOrigin.x = 0.0;

    if (newOrigin.x+viewBounds.size.width>[self frame].size.width)
        newOrigin.x = [self frame].size.width - viewBounds.size.width;

	if (newOrigin.x!=viewBounds.origin.x)
	{
		[clipView scrollToPoint: [clipView constrainScrollPoint: newOrigin]];//scrollToPoint
		[[self enclosingScrollView] reflectScrolledClipView:clipView];
	}
}

- (void)scrollLeft;
{
	[self scrollHorizontallyOfAmount:-[[self enclosingScrollView] horizontalPageScroll]];
}

- (BOOL)cansScrollLeft;
{
	return [self canScrollHorizontallyOfAmount:-[[self enclosingScrollView] horizontalPageScroll]];
}

- (void)scrollRight;
{
	[self scrollHorizontallyOfAmount:[[self enclosingScrollView] horizontalPageScroll]];
}

- (BOOL)cansScrollRight;
{
	return [self canScrollHorizontallyOfAmount:[[self enclosingScrollView] horizontalPageScroll]];
}

- (void)scrollLeft:(NSTimer*)theTimer;
{
	[self scrollLeft];
}

- (void)scrollRight:(NSTimer*)theTimer;
{
	[self scrollRight];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
	//float d = [theEvent deltaY];
	if ([theEvent deltaY] == 0)
        return;
    
	//if (fabs( d) < 1.0) d = 1.0 * fabs( d) / d;
	
	[[[self viewer] imageView] scrollWheel:theEvent];

	if (!([theEvent modifierFlags] & NSEventModifierFlagOption))
		[self displaySelectedImage];
}	

- (void)displaySelectedImage;
{
	if (![self viewer])
        return;
	
	NSClipView *clipView = [[self enclosingScrollView] contentView];
	NSRect viewBounds = [clipView documentVisibleRect];
	NSRect viewFrame = [clipView frame];
	
	int z = [[[self viewer] imageView] curImage];
	int t = [[self viewer] curMovieIndex];
	NSPoint upperLeft;
	upperLeft.x = z*thumbnailWidth;

	if ([[[self viewer] imageView] flippedData]) upperLeft.x = ([[[self viewer] pixList] count]-z-1)*thumbnailWidth;
	
	upperLeft.y = ([[self viewer] maxMovieIndex]-t)*thumbnailHeight;//-viewBounds.origin.y;
	
	NSRect thumbRect = NSMakeRect(upperLeft.x, upperLeft.y-thumbnailHeight, thumbnailWidth, thumbnailHeight);
	NSRect intersectionRect = NSIntersectionRect(thumbRect, viewBounds);

	if (fabs(intersectionRect.size.width) < thumbnailWidth ||
        fabs(intersectionRect.size.height) < thumbnailHeight)
	{
		NSPoint scrollToMe = viewBounds.origin;
		
		if (NSMinX(thumbRect) < NSMinX(viewBounds))
			scrollToMe.x = NSMinX(thumbRect);
		else if (NSMinX(thumbRect) + thumbnailWidth > NSMaxX(viewBounds))
			scrollToMe.x = NSMaxX(thumbRect) - viewFrame.size.width;

        if (NSMinY(thumbRect) < NSMinY(viewBounds))
			scrollToMe.y = NSMinY(thumbRect);
		else if (NSMinY(thumbRect) + thumbnailHeight > NSMaxY(viewBounds))
			scrollToMe.y = NSMaxY(thumbRect) - viewFrame.size.height;
		
		[clipView scrollToPoint:[clipView constrainScrollPoint:scrollToMe]];

		[[self enclosingScrollView] reflectScrolledClipView:clipView];
	}
}

- (BOOL)needsHorizontalScroller;
{
	return [[[self viewer] pixList] count]*thumbnailWidth > [[[self enclosingScrollView] contentView] frame].size.width;
}

#pragma mark - New Viewers

// current selected viewer
- (ViewerController*)viewer;
{
	return [[NavigatorWindowController navigatorWindowController] viewerController];
	
//	NSArray *displayed2DViewers = [ViewerController getDisplayed2DViewers];
//	
//	for (ViewerController *v in displayed2DViewers)
//	{
//		if ([[[v imageView] window] isMainWindow] && [v imageView].isKeyView)
//			return v;
//	}
//	
//	if ([displayed2DViewers count])
//    return [displayed2DViewers lastObject];
//	
//	return previousViewer;
}

// associatedViewers are all the open viewers that share the same NSData, i.e. same stack
- (NSArray*)associatedViewers;
{
	NSMutableArray *associatedViewers = [NSMutableArray array];
	
	NSArray *displayed2DViewers = [ViewerController getDisplayed2DViewers];
	ViewerController *mainViewer = [self viewer];
	
	for (ViewerController *v in displayed2DViewers)
	{		
		if ([v maxMovieIndex]==[mainViewer maxMovieIndex] && v!=mainViewer)
		{
			BOOL sameVolumeData = YES;
			for (int i=0; i<[v maxMovieIndex]; i++)
			{
				sameVolumeData = sameVolumeData && ([v volumeData:i] == [mainViewer volumeData:i]);
			}

            if (sameVolumeData)
                [associatedViewers addObject:v];
		}
	}
	
	return [NSArray arrayWithArray:associatedViewers];
}

- (void)displaySelectedViewInNewWindow:(BOOL)newWindow;
{
	NSClipView *clipView = [[self enclosingScrollView] contentView];
	NSRect viewBounds = [clipView documentVisibleRect];
	NSRect viewFrame = [clipView frame];
	NSSize viewSize = viewFrame.size;
    
    NSPoint position = [self convertPointFromBacking: mouseDownPosition];
    
	int z = (position.x + viewBounds.origin.x) / thumbnailWidth;
	int t = (position.y + [self frame].size.height-viewSize.height-viewBounds.origin.y)/thumbnailHeight;

	if (!newWindow)//t == [[self viewer] curMovieIndex] || [[self viewer] isPlaying4D]) // same time line: select the clicked slice
	{
		DCMView *view = [[self viewer] imageView];
		if ([view flippedData])
            [view setIndex:[[[self viewer] pixList] count]-z-1];
		else
            [view setIndex:z];
		
		if (t != [[self viewer] curMovieIndex])
		{
			ViewerController *selectedViewer;
			BOOL alreadyOpen = NO;
			for (ViewerController *viewer in [self associatedViewers])
			{
				if (t == [viewer curMovieIndex])
				{
					selectedViewer = viewer;
					alreadyOpen = YES;
				}
			}

			if (t == [[self viewer] curMovieIndex])
			{
				selectedViewer = [self viewer];
				alreadyOpen = YES;
			}

			if (!alreadyOpen)
				[[self viewer] setMovieIndex:t];
			else
			{
				// select the correct slice
				DCMView *view = [selectedViewer imageView];
				if ([view flippedData])
                    [view setIndex:[[[self viewer] pixList] count]-z-1];
				else
                    [view setIndex:z];
                
				// sync other viewers
				[view sendSyncMessage:0];
				// make key viewer
				[[selectedViewer window] makeKeyWindow];
				[self setNeedsDisplay:YES];
			}

		}
		
		[view sendSyncMessage:0];
	}
	else
	{
		dontListenToNotification++;
		[self openNewViewerAtSlice:z movieFrame:t]; // creates a new viewer
		dontListenToNotification--;
	}
}

- (void)openNewViewerAtSlice:(int)z movieFrame:(int)t;
{
	// create the new viewer
	ViewerController *newViewer = [ViewerController newWindow:[[self viewer] pixList:0] :[[self viewer] fileList:0] :[[self viewer] volumeData:0]];
	
	// add all the 4D frames
	for (int i=1; i<[[self viewer] maxMovieIndex]; i++)
	{
		[newViewer addMovieSerie:[[self viewer] pixList:i] :[[self viewer] fileList:i] :[[self viewer] volumeData:i]];
	}
	
	for (int i=0; i<[[self viewer] maxMovieIndex]; i++)
	{
		[newViewer setRoiList: i array: [[self viewer] roiList: i]];
	}
	
	[newViewer setMovieIndex:t];

	// select the correct slice
	DCMView *view = [newViewer imageView];
	if ([[[self viewer] imageView] flippedData])
        [view setIndex:[[[self viewer] pixList] count]-z-1];
	else
        [view setIndex:z];
	
	// flippedData must be the same on all viewers
	view.flippedData = [[self viewer] imageView].flippedData;
	
	[newViewer adjustSlider];
	
    NSLog(@"%s %d, self class:%@, newViewer class:%@", __FUNCTION__, __LINE__,
          NSStringFromClass([self class]),
          NSStringFromClass([newViewer class]));
    
	[[newViewer window] makeKeyAndOrderFront:self];
	[newViewer.imageView setWLWW: wl : ww];
	[newViewer propagateSettings];

	//[view sendSyncMessage:0];
	[newViewer checkEverythingLoaded];
}

#pragma mark - Keyboard

- (void) keyDown:(NSEvent *)event
{
	[[[self viewer] imageView] keyDown:event];
}

#pragma mark - Saving Transformation Values

- (void)saveTransformForCurrentViewer;
{
	if (![self viewer])
        return;
    
	NSString *seriesInstanceUID = [[[[[self viewer] pixList:0] objectAtIndex:0] seriesObj] valueForKey:@"seriesInstanceUID"];
	NSMutableDictionary *currentTransform = [NSMutableDictionary dictionary];
	[currentTransform setObject:[NSNumber numberWithFloat:zoomFactor] forKey:@"zoomFactor"];
	[currentTransform setObject:[NSNumber numberWithFloat:rotationAngleRad] forKey:@"rotationAngle"];
	[currentTransform setObject:[NSValue valueWithPoint:offset] forKey:@"offset"];
	[savedTransformDict setObject:currentTransform forKey:seriesInstanceUID];
}

- (void)loadTransformForCurrentViewer;
{
	if (![self viewer])
        return;
    
	NSString *seriesInstanceUID = [[[[[self viewer] pixList:0] objectAtIndex:0] seriesObj] valueForKey:@"seriesInstanceUID"];
	NSMutableDictionary *currentTransform = [savedTransformDict objectForKey:seriesInstanceUID];
	if (currentTransform)
	{
		zoomFactor = [[currentTransform objectForKey:@"zoomFactor"] floatValue];
		rotationAngleRad = [[currentTransform objectForKey:@"rotationAngle"] floatValue];
		offset = [[currentTransform objectForKey:@"offset"] pointValue];
	}
	else
	{
		zoomFactor = 1.0;
		rotationAngleRad = 0.0;
		offset = NSZeroPoint;
	}
	
	[self setNeedsDisplay:YES];
}

@end
