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

#import "StringTexture.h"
#import "N2Debug.h"
#include "glm/glm.hpp"

@implementation StringTexture

- (void) deleteTexture
{
	NSOpenGLContext *c = [NSOpenGLContext currentContext];
    if (!c)
        return;
	
	NSUInteger index = [ctxArray indexOfObjectIdenticalTo: c];
	if (index == NSNotFound)
        return;

    CGLContextObj cgl_ctx = [c CGLContextObj];
    if (cgl_ctx)
    {
        GLuint t = [[textArray objectAtIndex: index] intValue];
        if (t)
            (*cgl_ctx->disp.delete_textures)(cgl_ctx->rend, (GLuint)1, &t);
        else
            N2LogStackTrace( @"deleteTexture");
    }
    else
        N2LogStackTrace( @"deleteTexture");
    
    [ctxArray removeObjectAtIndex: index];
    [textArray removeObjectAtIndex: index];
}

- (void) deleteTexture:(NSOpenGLContext*) c
{
	NSUInteger index = [ctxArray indexOfObjectIdenticalTo: c];
	
	if (c && index != NSNotFound)
	{
		GLuint t = [[textArray objectAtIndex: index] intValue];
		CGLContextObj cgl_ctx = [c CGLContextObj];
		
        if (cgl_ctx)
        {
            if (t)
                (*cgl_ctx->disp.delete_textures)(cgl_ctx->rend, 1, &t);
            else
                N2LogStackTrace( @"deleteTexture");
		}
        else
            N2LogStackTrace( @"deleteTexture");
        
		[ctxArray removeObjectAtIndex: index];
		[textArray removeObjectAtIndex: index];
	}
}

// designated initializer
- (id) initWithAttributedString:(NSAttributedString *)attributedString
                  withTextColor:(NSColor *)text
                   withBoxColor:(NSColor *)box
                withBorderColor:(NSColor *)border
{
	self = [super init];
	antialiasing = NO;
	texSize = NSZeroSize;
	attrString = [attributedString copy];
    textColor = [text retain]; // Issue #61 ?
	boxColor = [box retain];
	borderColor = [border retain];
	staticFrame = NO;
    marginSize = NSMakeSize(4.0f, 2.0f);
	ctxArray = [[NSMutableArray arrayWithCapacity: 10] retain];
	textArray = [[NSMutableArray arrayWithCapacity: 10] retain];
	// all other variables 0 or NULL
	return self;
}

- (id) initWithString:(NSString *)str
       withAttributes:(NSDictionary *)attribs
        withTextColor:(NSColor *)text
         withBoxColor:(NSColor *)box
      withBorderColor:(NSColor *)border
{
	if (str == nil)
        str = @"";

	return [self initWithAttributedString:[[[NSAttributedString alloc] initWithString:str attributes:attribs] autorelease]
                            withTextColor:text
                             withBoxColor:box
                          withBorderColor:border];
}

// basic methods that pick up defaults
- (id) initWithAttributedString:(NSAttributedString *)attributedString;
{
	if (attributedString == nil)
        attributedString = [[[NSAttributedString alloc] initWithString: @""] autorelease];
    
	return [self initWithAttributedString:attributedString
                            withTextColor:[NSColor colorWithDeviceRed:1.0f green:1.0f blue:1.0f alpha:1.0f]
                             withBoxColor:[NSColor colorWithDeviceRed:1.0f green:1.0f blue:1.0f alpha:0.0f]
                          withBorderColor:[NSColor colorWithDeviceRed:1.0f green:1.0f blue:1.0f alpha:0.0f]];
}

- (id) initWithString:(NSString *)str
       withAttributes:(NSDictionary *)attribs
{
	if (str == nil)
        str = @"";
    
	return [self initWithAttributedString:[[[NSAttributedString alloc] initWithString:str attributes:attribs] autorelease]
                            withTextColor:[NSColor colorWithDeviceRed:1.0f green:1.0f blue:1.0f alpha:1.0f] // Issue #61 ?
                             withBoxColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.0f]
                          withBorderColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:0.0f]];
}

- (oneway void)release
{
    if (![NSThread isMainThread])
        [self performSelectorOnMainThread:@selector(release) withObject:nil waitUntilDone:NO];
    else
        [super release];
}

- (void) mainThreadAutorelease
{
    [self retain];
    [self autorelease];
}

- (id) autorelease
{
    if (![NSThread isMainThread])
        [self performSelectorOnMainThread:@selector(mainThreadAutorelease) withObject:nil waitUntilDone:NO];

    return [super autorelease];
}

- (void) dealloc
{
    if( [NSThread isMainThread] == NO)
        N2LogStackTrace( @"StringTexture dealloc NOT on main thread !");
    
	while( [ctxArray count])
        [self deleteTexture: [ctxArray lastObject]];

    [ctxArray release];
    ctxArray = nil;

    if ([textArray count])
        NSLog( @"** not all texture were deleted...");

    [textArray release];
    textArray = nil;
	
	[textColor release];
    textColor = nil;

    [boxColor release];
    boxColor = nil;

    [borderColor release];
    borderColor = nil;

    [attrString release];
    attrString = nil;

	[bitmap release];
    bitmap = nil;
	
	[super dealloc];
}

- (NSSize) texSize
{
	return texSize;
}

- (NSColor *) textColor
{
	return textColor;
}

- (NSColor *) boxColor
{
	return boxColor;
}

- (NSColor *) borderColor
{
	return borderColor;
}

- (NSSize) frameSize
{
    // find frame size if we have not already found it
	if ((NO == staticFrame) &&
        (0.0f == frameSize.width) &&
        (0.0f == frameSize.height))
    {
		frameSize = [attrString size]; // current string size
		frameSize.width += marginSize.width * 2.0f; // add padding
		frameSize.height += marginSize.height * 2.0f;
	}

    return frameSize;
}

- (NSSize) marginSize
{
	return marginSize;
}

- (BOOL) staticFrame
{
	return staticFrame;
}

- (void) setAntiAliasing:(BOOL) a
{
	antialiasing = a;
}

- (GLuint) genTexture;
{
    NSLog( @"******** WE SHOULD NOT BE HERE, use genTextureWithBackingScaleFactor instead");
    
    return [self genTextureWithBackingScaleFactor: [[NSScreen mainScreen] backingScaleFactor]];
}

// Generates the texture without drawing texture to current context
- (GLuint) genTextureWithBackingScaleFactor: (float) backingScaleFactor;
{
    //NSLog(@"%s %d, <%@>", __FUNCTION__, __LINE__, attrString.string);
    if (backingScaleFactor != 1.0 &&
        backingScaleFactor != 2.0)
    {
        //NSLog( @"******** %s backingScaleFactor == %f", __FUNCTION__, backingScaleFactor);
        backingScaleFactor = [[NSScreen mainScreen] backingScaleFactor];
    }
    
    sf = backingScaleFactor;
    
	NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
	if (currentContext == nil)
	{
		NSLog( @"********* NO CURRENT CONTEXT for genTexture");
		return 0;
	}

#ifndef WITH_OPENGL_32
    CGLContextObj cgl_ctx = [currentContext CGLContextObj];
#endif

	[self deleteTexture: currentContext];
    
    // find frame size if we have not already found it
	if (staticFrame == NO &&
        frameSize.width == 0 &&
        frameSize.height == 0)
    {
		frameSize = [attrString size]; // current string size
		frameSize.width += marginSize.width * 2.0f; // add padding
		frameSize.height += marginSize.height * 2.0f;
        
        frameSize.width = (int) frameSize.width;
        frameSize.height = (int) frameSize.height;
	}
	
	GLuint textureID = 0;
	
	[bitmap release];
	bitmap = nil;
	NSImage *image = [[NSImage alloc] initWithSize:frameSize];
	if ([image size].width > 0 &&
        [image size].height > 0)
	{
		[image lockFocus];
		
        if (backingScaleFactor == 1) // On Retina system, this will cancel the default 2x resolution in the NSImage "world"
            [[NSAffineTransform transform] set];
        
		[[NSGraphicsContext currentContext] setShouldAntialias: antialiasing];
		
		if ([boxColor alphaComponent])
		{ // this should be == 0.0f but need to make sure
			[boxColor set]; 
			NSRectFill (NSMakeRect (0.0f, 0.0f, frameSize.width, frameSize.height));
		}

        if ([borderColor alphaComponent])
		{
			[borderColor set]; 
			NSFrameRect (NSMakeRect (0.0f, 0.0f, frameSize.width, frameSize.height));
		}

        [textColor set];    // Issue #61 ?
		[attrString drawAtPoint:NSMakePoint (marginSize.width, marginSize.height)];
		
        if (frameSize.width > 0 && frameSize.height > 0)
            bitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0.0f, 0.0f, frameSize.width, frameSize.height)];
		else
            NSLog( @"StringTexture: frameSize.width > 0 && frameSize.height > 0");
        
#ifdef DEBUG_TEXTURE_BITMAP
        if ([attrString.string isEqualToString:@"R"]) {
            NSLog(@"%s %d %@, SPP:%ld, BPS:%ld, PPR:%ld", __FUNCTION__, __LINE__,
                  NSStringFromSize(bitmap.size),
                  (long)bitmap.samplesPerPixel, // 4
                  (long)bitmap.bitsPerSample, // 8
                  (long)[bitmap pixelsWide]); // pixels per row
            assert((bitmap.bytesPerRow / (bitmap.bitsPerPixel/8)) == [bitmap pixelsWide]);

            unsigned int *bmp = (unsigned int *)self->bitmap.bitmapData;
            for (int i=0; i<(self->bitmap.size.width * self->bitmap.size.height); i++) {
                if ((i%(int)self->bitmap.size.width) == 0)
                    printf("\n");
                printf("%3d ", bmp[i]);
            }
            printf("\n\n");
        }
#endif
        
		[image unlockFocus];
        
        if (bitmap)
        {
#ifdef WITH_OPENGL_32
            GLenum target = GL_TEXTURE_RECTANGLE;
            // With internalFormat, you tell the GL driver how you want the texture to be stored on the GPU.
            GLint internalFormat = GL_RGBA8;
            
            // externalFormat is defined by format and type.
            GLenum format = GL_RGBA; // format of the pixel data
#else
            GLenum target = GL_TEXTURE_RECTANGLE_EXT;
            // TODO: use [bitmap hasAlpha]
            GLenum format = ([bitmap samplesPerPixel] == 4) ? GL_RGBA : GL_RGB; // always 4 ?
            GLint internalFormat = format;
#endif

            GLenum type = GL_UNSIGNED_BYTE;
            if (bitmap.bitsPerSample == 16 &&
                bitmap.bitsPerPixel == 64)  // bitsPerSample * samplesPerPixel
            {
                type = GL_SHORT;  // This is fixing issue #47.3
            }

            texSize.width = [bitmap size].width * backingScaleFactor; // retina
            texSize.height = [bitmap size].height * backingScaleFactor; // retina
            
            glActiveTexture(GL_TEXTURE0);
            glGenTextures(1, &textureID);
            glBindTexture(target, textureID);

            // Define the number of pixels in a row
            // Each pixel is typically 4 bytes or 4 words (=8 bytes)
            glPixelStorei(GL_UNPACK_ROW_LENGTH, bitmap.pixelsWide);

            glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
#if defined( WITH_OPENGL_32) && !defined( WITH_GLEW)
            // TODO:
#else
            // The cached hint specifies to cache texture data in video memory.
            // This hint is recommended when you have textures that you plan to use multiple times or that use linear filtering
            glTexParameteri (target, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_CACHED_APPLE);
#endif

            glTexImage2D(target, 0,
                         internalFormat,
                         bitmap.pixelsWide, bitmap.pixelsHigh, 0,

                         format,
                         type,
                         [bitmap bitmapData]);
            
            [ctxArray addObject: currentContext];
            [textArray addObject: [NSNumber numberWithInt: textureID]];
            //NSLog(@"%s %d, ctxArray count:%lu\n%@", __FUNCTION__, __LINE__, (unsigned long)[ctxArray count], ctxArray);
            //NSLog(@"%s %d, textArray (IDs) count:%lu\n%@", __FUNCTION__, __LINE__, (unsigned long)[textArray count], textArray);
        }
	}

#ifdef DEBUG_TEXTURE_BITMAP
    //NSString *path = [NSString stringWithFormat:@"/tmp/stringtexture_%@.tiff", attrString.string];
    //[[image TIFFRepresentation] writeToFile: path atomically: YES];
#endif
	[image release];
	
	return textureID;
}

- (void) setFlippedX: (BOOL) x Y:(BOOL) y
{
	xFlipped = x;
	yFlipped = y;
}

- (void) drawWithBounds:(NSRect)bounds
{
//    NSLog(@"%s %d, bounds:%@ <%@>", __FUNCTION__, __LINE__,
//          NSStringFromRect(bounds), attrString.string);

    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
	GLuint textureID = 0;
    
    if (sf != currentContext.view.window.backingScaleFactor)
    {
        while ([ctxArray count])
            [self deleteTexture: [ctxArray lastObject]];
    }
    
	NSUInteger index = [ctxArray indexOfObjectIdenticalTo: currentContext];
    
	if (index != NSNotFound)
		textureID = [[textArray objectAtIndex: index] intValue];
	
    if (!textureID) {
        // generate the texture bitmap (again)
		textureID = [self genTextureWithBackingScaleFactor: currentContext.view.window.backingScaleFactor];
    }
	
	if (textureID)
	{
#ifdef WITH_OPENGL_32
        GLenum target = GL_TEXTURE_RECTANGLE;
#else
		CGLContextObj cgl_ctx = [currentContext CGLContextObj];
		if (cgl_ctx == nil)
            return;

        GLenum target = GL_TEXTURE_RECTANGLE_EXT;
#endif

#ifdef DEBUG_TEXTURE_WITH_SHADER
        glDisable(GL_BLEND);
#endif
#if 0 // No difference. Originally not here
        glDisable (GL_DEPTH_TEST); // ensure text is not removed by depth buffer test.
        glEnable (GL_BLEND); // for text fading
        glBlendFunc (GL_ONE, GL_ONE_MINUS_SRC_ALPHA); // ditto
#endif

        checkOpenGLErrors(__LINE__);
#ifndef DEBUG_TEXTURE_WITH_SHADER
  #ifndef WITH_OPENGL_32
        glEnable(target);
  #endif
        glBindTexture(target, textureID);
#endif
        checkOpenGLErrors(__LINE__);

        // world coordinates ?
        GLfloat xA, yA; // left upper
        GLfloat xB, yB; // left lower
        GLfloat xC, yC; // right lower
        GLfloat xD, yD; // right upper

        if (xFlipped) {
            xA = NSMaxX(bounds);
            xB = NSMaxX(bounds);
            xC = NSMinX(bounds);
            xD = NSMinX(bounds);
        }
        else {
            xA = NSMinX(bounds);
            xB = NSMinX(bounds);
            xC = NSMaxX(bounds);
            xD = NSMaxX(bounds);
        }

        if (yFlipped) {
            yA = NSMaxY(bounds);
            yB = NSMinY(bounds);
            yC = NSMinY(bounds);
            yD = NSMaxY(bounds);
        }
        else {
            yA = NSMinY(bounds);
            yB = NSMaxY(bounds);
            yC = NSMaxY(bounds);
            yD = NSMinY(bounds);
        }
        
//        NSLog(@"%s %d %@, bounds:%@\n A:(%5.1f, %5.1f)\n B:(%5.1f, %5.1f)\n C:(%5.1f, %5.1f)\n D:(%5.1f, %5.1f)", __FUNCTION__, __LINE__,
//              NSStringFromClass([self class]),
//              NSStringFromRect(bounds),
//              xA, yA, xB, yB, xC, yC, xD, yD);

        // Assume we are alreading using text program or shaderMode
        {
        NSMutableArray *pArray = [NSMutableArray array];

        glm::vec2 t = glm::vec2(0,0);
        glm::vec2 p = glm::vec2(xA, yA);
        glm::vec4 v = glm::vec4(p, t);
        [pArray addObject: [NSValue valueWithBytes:&v objCType:@encode(glm::vec4)]];
        //NSLog(@"%s %d, [A] %5.1f %5.1f %5.1f %5.1f", __FUNCTION__, __LINE__, p.x, p.y, t.x, t.y);
        
        t = glm::vec2(0.0f, texSize.height);
        p = glm::vec2(xB, yB);
        v = glm::vec4(p, t);
        [pArray addObject: [NSValue valueWithBytes:&v objCType:@encode(glm::vec4)]];
        //NSLog(@"%s %d, [B] %5.1f %5.1f %5.1f %5.1f", __FUNCTION__, __LINE__, p.x, p.y, t.x, t.y);

        t = glm::vec2(texSize.width, texSize.height);
        p = glm::vec2(xC, yC);
        v = glm::vec4(p, t);
        [pArray addObject: [NSValue valueWithBytes:&v objCType:@encode(glm::vec4)]];
        //NSLog(@"%s %d, [C] %5.1f %5.1f %5.1f %5.1f", __FUNCTION__, __LINE__, p.x, p.y, t.x, t.y);

        t = glm::vec2(texSize.width, 0.0f);
        p = glm::vec2(xD, yD);
        v = glm::vec4(p, t);
        [pArray addObject: [NSValue valueWithBytes:&v objCType:@encode(glm::vec4)]];
        //NSLog(@"%s %d, [D] %5.1f %5.1f %5.1f %5.1f", __FUNCTION__, __LINE__, p.x, p.y, t.x, t.y);

        checkOpenGLErrors(__LINE__);
        renderer_drawQuad_xyuv([pArray copy]); // originally GL_QUADS
        checkOpenGLErrors(__LINE__);
        }
	}
}

- (void) drawAtPoint:(NSPoint) point
               ratio:(float) ratio
{
//    NSLog(@"%s %d, %@ <%@>", __FUNCTION__, __LINE__,
//          NSStringFromPoint(point), attrString.string);

    NSOpenGLContext *currentContext = [NSOpenGLContext currentContext];
	GLuint textureID = 0;
	NSUInteger index = [ctxArray indexOfObjectIdenticalTo: currentContext];
	if (index != NSNotFound)
		textureID = [[textArray objectAtIndex: index] intValue];
	
	if (!textureID)
		textureID = [self genTextureWithBackingScaleFactor: currentContext.view.window.backingScaleFactor];
	
	if (textureID) // if successful
		[self drawWithBounds:NSMakeRect (point.x, point.y, texSize.width, texSize.height*ratio)];
}

- (void) drawAtPoint:(NSPoint)point
{
	[self drawAtPoint: point ratio: 1.0];
}

- (void) setString:(NSAttributedString *)attributedString // set string after initial creation
{
	while ([ctxArray count])
        [self deleteTexture: [ctxArray lastObject]];

	if ([textArray count])
        NSLog( @"** not all texture were deleted...");
	
	[attrString release];
	attrString = [attributedString copy];
	if (NO == staticFrame) // ensure dynamic frame sizes will be recalculated
        frameSize = NSZeroSize;
}

// set string after initial creation
- (void) setString:(NSString *)str
    withAttributes:(NSDictionary *)attribs;
{
	if (str == nil)
        str = @"";

    [self setString:[[[NSAttributedString alloc] initWithString:str attributes:attribs] autorelease]];
}

// set default text color
- (void) setTextColor:(NSColor *)color
{
	while ([ctxArray count])
        [self deleteTexture: [ctxArray lastObject]];

    if ([textArray count])
        NSLog( @"** not all texture were deleted...");
	
	[color retain];
	[textColor release];
	textColor = color;
}

// set default box color
- (void) setBoxColor:(NSColor *)color
{
	while ([ctxArray count])
        [self deleteTexture: [ctxArray lastObject]];

    if ([textArray count])
        NSLog( @"** not all texture were deleted...");
	
	[color retain];
	[boxColor release];
	boxColor = color;
}

// set default border color
- (void) setBorderColor:(NSColor *)color
{
	while ([ctxArray count])
        [self deleteTexture: [ctxArray lastObject]];

    if ([textArray count])
        NSLog( @"** not all texture were deleted...");
	
	[color retain];
	[borderColor release];
	borderColor = color;
}

- (NSString*) description
{
    return attrString.string;
}

@end
