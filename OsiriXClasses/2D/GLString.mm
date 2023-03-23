//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//
//  At the end of 2014 the project was forked from OsiriX to become Miele-LXIV
//  The original header follows:

//
// File:		GLString.m
//				(Originally StringTexture.m)
//
// Abstract:	Uses Quartz to draw a string into an OpenGL texture
//
// Version:		1.1 - Antialiasing option, Rounded Corners to the frame
//					  self contained OpenGL state, performance enhancements,
//					  other bug fixes.
//				1.0 - Original release.
//				
//
// Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Inc. ("Apple")
//				in consideration of your agreement to the following terms, and your use,
//				installation, modification or redistribution of this Apple software
//				constitutes acceptance of these terms.  If you do not agree with these
//				terms, please do not use, install, modify or redistribute this Apple
//				software.
//
//				In consideration of your agreement to abide by the following terms, and
//				subject to these terms, Apple grants you a personal, non - exclusive
//				license, under Apple's copyrights in this original Apple software ( the
//				"Apple Software" ), to use, reproduce, modify and redistribute the Apple
//				Software, with or without modifications, in source and / or binary forms;
//				provided that if you redistribute the Apple Software in its entirety and
//				without modifications, you must retain this notice and the following text
//				and disclaimers in all such redistributions of the Apple Software. Neither
//				the name, trademarks, service marks or logos of Apple Inc. may be used to
//				endorse or promote products derived from the Apple Software without specific
//				prior written permission from Apple.  Except as expressly stated in this
//				notice, no other rights or licenses, express or implied, are granted by
//				Apple herein, including but not limited to any patent rights that may be
//				infringed by your derivative works or by other works in which the Apple
//				Software may be incorporated.
//
//				The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
//				WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
//				WARRANTIES OF NON - INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A
//				PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION
//				ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
//
//				IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
//				CONSEQUENTIAL DAMAGES ( INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//				SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//				INTERRUPTION ) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION
//				AND / OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER
//				UNDER THEORY OF CONTRACT, TORT ( INCLUDING NEGLIGENCE ), STRICT LIABILITY OR
//				OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Copyright ( C ) 2003-2007 Apple Inc. All Rights Reserved.
//

#import "mgl.h" // include first

#import "GLRenderer.h"

#import "GLString.h"
#import "N2Debug.h"

// The following is a NSBezierPath category to allow
// for rounded corners of the border

#pragma mark - NSBezierPath Category

@implementation NSBezierPath (RoundRect)

+ (NSBezierPath *)bezierPathWithRoundedRect:(NSRect)rect cornerRadius:(float)radius {
    NSBezierPath *result = [NSBezierPath bezierPath];
    [result appendBezierPathWithRoundedRect:rect cornerRadius:radius];
    return result;
}

- (void)appendBezierPathWithRoundedRect:(NSRect)rect cornerRadius:(float)radius {
    if (!NSIsEmptyRect(rect)) {
		if (radius > 0.0) {
			// Clamp radius to be no larger than half the rect's width or height.
			float clampedRadius = MIN(radius, 0.5 * MIN(rect.size.width, rect.size.height));
			
			NSPoint topLeft = NSMakePoint(NSMinX(rect), NSMaxY(rect));
			NSPoint topRight = NSMakePoint(NSMaxX(rect), NSMaxY(rect));
			NSPoint bottomRight = NSMakePoint(NSMaxX(rect), NSMinY(rect));
			
			[self moveToPoint:NSMakePoint(NSMidX(rect), NSMaxY(rect))];
			[self appendBezierPathWithArcFromPoint:topLeft     toPoint:rect.origin radius:clampedRadius];
			[self appendBezierPathWithArcFromPoint:rect.origin toPoint:bottomRight radius:clampedRadius];
			[self appendBezierPathWithArcFromPoint:bottomRight toPoint:topRight    radius:clampedRadius];
			[self appendBezierPathWithArcFromPoint:topRight    toPoint:topLeft     radius:clampedRadius];
			[self closePath];
		}
        else {
			// When radius == 0.0, this degenerates to the simple case of a plain rectangle.
			[self appendBezierPathWithRect:rect];
		}
    }
}
@end

#pragma mark -

@implementation GLString

- (void) deleteTexture
{
	if (textureID && cgl_ctx) {
		(*cgl_ctx->disp.delete_textures)(cgl_ctx->rend, 1, &textureID);
		textureID = 0; // ensure it is zeroed for failure cases
		cgl_ctx = 0;
	}
}

- (void) dealloc
{
#ifndef NDEBUG
    if( [NSThread isMainThread] == NO)
        N2LogStackTrace( @"[NSThread isMainThread] == NO");
#endif
    
	[self deleteTexture];
	[textColor release];
	[boxColor release];
	[borderColor release];
	[attrString release];
	[bitmap release];
	[super dealloc];
}

#pragma mark - Initializers

// designated initializer
- (id) initWithAttributedString:(NSAttributedString *)attributedString
                   withBoxColor:(NSColor *)box
                withBorderColor:(NSColor *)border
{
	self = [super init];
	cgl_ctx = NULL;
	textureID = 0;
	texSize = NSZeroSize;
	[attributedString retain];
	attrString = attributedString;
	[box retain];
	[border retain];
	boxColor = box;
	borderColor = border;
	staticFrame = NO;
	antialias = YES;
    marginSize = NSMakeSize(4.0f, 2.0f);  // standard margins
	cRadius = 4.0f;
	requiresUpdate = YES;
	// all other variables 0 or NULL
	return self;
}

- (id) initWithString:(NSString *)aString
       withAttributes:(NSDictionary *)attribs
         withBoxColor:(NSColor *)box
      withBorderColor:(NSColor *)border
{
	if (aString == nil)
        aString = @"";
    
	return [self initWithAttributedString:[[[NSAttributedString alloc] initWithString:aString attributes:attribs] autorelease] withBoxColor:box withBorderColor:border];
}

// basic methods that pick up defaults
- (id) initWithAttributedString:(NSAttributedString *)attributedString;
{
	if( attributedString == nil)
		attributedString = [[[NSAttributedString alloc] initWithString: @""] autorelease];
		
	return [self initWithAttributedString:attributedString
                             withBoxColor:[NSColor colorWithDeviceRed:1.0f green:1.0f blue:1.0f alpha:0.0f]
                          withBorderColor:[NSColor colorWithDeviceRed:1.0f green:1.0f blue:1.0f alpha:0.0f]];
}

- (id) initWithString:(NSString *)aString withAttributes:(NSDictionary *)attribs
{
	if( aString == nil)
        aString = @"";
    
	return [self initWithAttributedString:[[[NSAttributedString alloc] initWithString:aString attributes:attribs] autorelease]
                             withBoxColor:[NSColor colorWithDeviceRed:1.0f green:1.0f blue:1.0f alpha:0.0f]
                          withBorderColor:[NSColor colorWithDeviceRed:1.0f green:1.0f blue:1.0f alpha:0.0f]];
}

#pragma mark -

- (void) genTexture // generates the texture without drawing texture to current context
{
	if ((NO == staticFrame) &&
        (0.0f == frameSize.width) &&
        (0.0f == frameSize.height)) // find frame size if we have not already found it
    {
		frameSize = [attrString size]; // current string size
        
        frameSize.width = (int) frameSize.width;
        frameSize.height = (int) frameSize.height;
        
		frameSize.width += marginSize.width * 2.0f; // add padding
		frameSize.height += marginSize.height * 2.0f;
	}
    
    NSImage *image = [[NSImage alloc] initWithSize:frameSize];
	if ([image size].width > 0 &&
        [image size].height > 0)
	{
		[image lockFocus];
		[[NSGraphicsContext currentContext] setShouldAntialias:antialias];
		
        // Fill box
		if ([boxColor alphaComponent]) // this should be == 0.0f but need to make sure
		{ 
			[boxColor set]; 
			NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(NSMakeRect (0.0f, 0.0f, frameSize.width-1, frameSize.height-1) , 0.5, 0.5) cornerRadius:cRadius];
			[path fill];
		}

        // Stroke border
		if ([borderColor alphaComponent])
		{
			[borderColor set]; 
			NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(NSMakeRect (0.0f, 0.0f, frameSize.width-1, frameSize.height-1), 0.5, 0.5) cornerRadius:cRadius];
			[path setLineWidth:1.0f];
			[path stroke];
		}
		
        // Text
		[textColor set];
		[attrString drawAtPoint:NSMakePoint (marginSize.width, marginSize.height)]; // draw at offset position

		[bitmap release];
		bitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect (0.0f, 0.0f, frameSize.width, frameSize.height)];
		
		[image unlockFocus];
		
		texSize.width = [bitmap pixelsWide];    // TBC: * sf (Retina)
		texSize.height = [bitmap pixelsHigh];   // TBC: * sf (Retina)
        
#if 0 //def DEBUG_TEXTURE_BITMAP
        float sf = [[NSScreen mainScreen] backingScaleFactor];//backingScaleFactor;
        NSLog(@"%s %s:%d\n<%@>", __FUNCTION__, __FILE__, __LINE__, attrString.string);
        NSString *debugString = @" 1 ";
//#include "../../../priv/snippets/1.mm"
#include "../../../priv/snippets/2.mm"
#endif
		
        cgl_ctx = CGLGetCurrentContext();
		if (!cgl_ctx)
            NSLog(@"%s GLString: Failure to get current OpenGL context\n", __FUNCTION__);
        else
		{
#ifdef WITH_OPENGL_32
            GLenum target = GL_TEXTURE_RECTANGLE;
#else
			glPushAttrib(GL_TEXTURE_BIT);
            GLenum target = GL_TEXTURE_RECTANGLE_EXT;
#endif
			if (textureID != 0)
                glDeleteTextures(1, &textureID);

            glGenTextures(1, &textureID);
			
#if !defined( WITH_OPENGL_32) || defined( WITH_GLEW)
			glTexParameterf(target, GL_TEXTURE_PRIORITY, 1.0f);
#endif
			glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
            
#ifndef WITH_OPENGL_32
            // The cached hint specifies to cache texture data in video memory.
            // This hint is recommended when you have textures that you plan to use multiple times or that use linear filtering
			glTexParameteri(target, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_CACHED_APPLE);

            // Make a single memory mapping for all of the textures used by the application:
            glTextureRangeAPPLE(target, texSize.width * texSize.height * 4, [bitmap bitmapData]);
#endif

            glPixelStorei(GL_UNPACK_ROW_LENGTH, texSize.width);
			
#ifdef WITH_OPENGL_32
            GLint internalFormat = GL_RGBA8;
            if (bitmap.bitsPerSample==16)  // issue i69
                internalFormat = GL_RGBA16;

            GLenum format = GL_RGBA;
#else
            GLint internalFormat = GL_RGBA;
            GLenum format = [bitmap hasAlpha] ? GL_RGBA : GL_RGB;
#endif

            GLenum type = GL_UNSIGNED_BYTE;
#if 1 // FIX_ISSUE_i69
            if (bitmap.bitsPerSample == 16 &&
                bitmap.bitsPerPixel == 64)  // bitsPerSample * samplesPerPixel
            {
                type = GL_SHORT;  // Signed short.
            }

            if (bitmap.bitsPerSample==16)// && sf == 2.0)
            {
                const float sf2 = 2.0; // bitmap.bitsPerSample / 8
                int w = self->bitmap.size.width * sf2;
                int h = self->bitmap.size.height * sf2;
                int spp = bitmap.samplesPerPixel;
                unsigned short *sample = (unsigned short *)self->bitmap.bitmapData;
                for (int i=0; i<(w*h*spp); ++i)
                    sample[i] <<= 1;
            }
#endif
            
            glBindTexture (target, textureID);
			
            glTexParameteri(target, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(target, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexImage2D(target, 0,
                         internalFormat,
                         texSize.width, texSize.height, 0,

                         format,
                         type,
                         [bitmap bitmapData]);

#ifndef WITH_OPENGL_32
			glPopAttrib();
#endif
		}
	}
        
#ifdef DEBUG_TEXTURE_BITMAP
//    if ([attrString.string isEqualToString:@" 1 "])
//        [[image TIFFRepresentation] writeToFile: @"/tmp/glstring.tiff" atomically: YES];
#endif

    [image release];
	requiresUpdate = NO;
}

#pragma mark - Accessors

- (GLuint) texName
{
	return textureID;
}

- (NSSize) texSize
{
	return texSize;
}

#pragma mark - Text Color

// Set default text color
- (void) setTextColor:(NSColor *)color
{
	[color retain];
	[textColor release];
	textColor = color;
	requiresUpdate = YES;
}

- (NSColor *) textColor
{
	return textColor;
}

#pragma mark - Box Color

// Set default box color
- (void) setBoxColor:(NSColor *)color
{
	[color retain];
	[boxColor release];
	boxColor = color;
	requiresUpdate = YES;
}

- (NSColor *) boxColor
{
	return boxColor;
}

#pragma mark - Border Color

// Set default border color
- (void) setBorderColor:(NSColor *)color
{
	[color retain];
	[borderColor release];
	borderColor = color;
	requiresUpdate = YES;
}

- (NSColor *) borderColor
{
	return borderColor;
}

#pragma mark - Margin Size

- (NSSize) marginSize
{
	return marginSize;
}

#pragma mark - Antialiasing
- (BOOL) antialias
{
	return antialias;
}

- (void) setAntialias:(bool)request
{
	antialias = request;
	requiresUpdate = YES;
}

#pragma mark - Frame

- (NSSize) frameSize
{
	if ((NO == staticFrame) &&
        (0.0f == frameSize.width) &&
        (0.0f == frameSize.height)) // find frame size if we have not already found it
    {
		frameSize = [attrString size]; // current string size
        
        frameSize.width = (int) frameSize.width;
        frameSize.height = (int) frameSize.height;
        
		frameSize.width += marginSize.width * 2.0f; // add padding
		frameSize.height += marginSize.height * 2.0f;
	}
	return frameSize;
}

- (BOOL) staticFrame
{
	return staticFrame;
}

#pragma mark - String

// set string after initial creation
- (void) setString:(NSAttributedString *)attributedString
{
	[attributedString retain];
	[attrString release];
	attrString = attributedString;
	if (NO == staticFrame) // ensure dynamic frame sizes will be recalculated
		frameSize = NSZeroSize;

    requiresUpdate = YES;
}

// set string after initial creation
- (void) setString:(NSString *)aString
    withAttributes:(NSDictionary *)attribs;
{
	if (aString == nil)
        aString = @"";
    
	[self setString:[[[NSAttributedString alloc] initWithString:aString attributes:attribs] autorelease]];
}

#pragma mark - Drawing

- (void) drawAtPoint: (NSPoint) p view:(NSView*) view
{
    NSRect r = NSMakeRect(p.x,
                          p.y,
                          [view convertSizeToBacking: [self frameSize]].width,
                          [view convertSizeToBacking: [self frameSize]].height);
    
    [self drawWithBounds: r];
}

- (void) drawWithBounds:(NSRect)bounds
{
	if (requiresUpdate)
		[self genTexture];
    
	if (textureID == 0)
        return;

    //NSLog(@"%s %d, bounds:%@ <%@>", __FUNCTION__, __LINE__, NSStringFromRect(bounds), attrString);
#ifdef WITH_OPENGL_32
    GLenum target = GL_TEXTURE_RECTANGLE;
#else
    glPushAttrib(GL_ENABLE_BIT | GL_TEXTURE_BIT | GL_COLOR_BUFFER_BIT); // GL_COLOR_BUFFER_BIT for glBlendFunc, GL_ENABLE_BIT for glEnable / glDisable

    GLenum target = GL_TEXTURE_RECTANGLE_EXT;
#endif
    
    glDisable (GL_DEPTH_TEST); // ensure text is not removed by depth buffer test.
    
#ifdef DEBUG_TEXTURE_WITH_SHADER
    glDisable(GL_BLEND);
#else
    glEnable(GL_BLEND); // for text fading
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA); // ditto
#endif
    
#ifndef DEBUG_TEXTURE_WITH_SHADER
#ifndef WITH_OPENGL_32
    glEnable(target);
#endif
    glBindTexture(target, textureID);
#endif
    checkOpenGLErrors(__LINE__);

    NSMutableArray *pArray = [NSMutableArray array];
    
    // upper left in world coordinates
    glm::vec2 t = glm::vec2(0,0);
    glm::vec2 p = glm::vec2(NSMinX(bounds), NSMinY(bounds));
    glm::vec4 v = glm::vec4(p, t);
    [pArray addObject: [NSValue valueWithBytes:&v objCType:@encode(glm::vec4)]];

    // lower left in world coordinates
    t = glm::vec2(0.0f, texSize.height);
    p = glm::vec2(NSMinX(bounds), NSMaxY(bounds));
    v = glm::vec4(p, t);
    [pArray addObject: [NSValue valueWithBytes:&v objCType:@encode(glm::vec4)]];

    // upper right in world coordinates
    t = glm::vec2(texSize.width, texSize.height);
    p = glm::vec2(NSMaxX(bounds), NSMaxY(bounds));
    v = glm::vec4(p, t);
    [pArray addObject: [NSValue valueWithBytes:&v objCType:@encode(glm::vec4)]];

    // lower right in world coordinates
    t = glm::vec2(texSize.width, 0.0f);
    p = glm::vec2(NSMaxX(bounds), NSMinY(bounds));
    v = glm::vec4(p, t);
    [pArray addObject: [NSValue valueWithBytes:&v objCType:@encode(glm::vec4)]];

    renderer_drawQuad_xyuv([pArray copy]); // originally GL_QUADS

#ifndef WITH_OPENGL_32
    glPopAttrib();
#endif
}

@end
