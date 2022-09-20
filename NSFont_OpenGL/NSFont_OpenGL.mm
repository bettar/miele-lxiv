//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//
//  At the end of 2014 the project was forked from OsiriX to become Miele-LXIV
//  The original header follows:

/*
 * This program is Copyright � 2002 Bryan L Blackburn.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 3. Neither the names Bryan L Blackburn, Withay.com, nor the names of any
 *    contributors may be used to endorse or promote products derived from this
 *    software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY BRYAN L BLACKBURN ``AS IS'' AND ANY EXPRESSED OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
 * EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Initial version, 27 October, 2002
 */

/* NSFont_OpenGL.m */

#import "mgl.h" // include first
#import "mieleTypes.h"

#import "NSFont_OpenGL.h"
#import "N2Debug.h"

#define MAXCOUNT                    256
#define NUM_DISPLAY_LISTS           150  // starting from ' ' = 32

@interface NSFont (withay_OpenGL_InternalMethods)
+ (unsigned char*) createCharacterWithImage:(NSBitmapImageRep *)bitmap;
+ (void) doOpenGLLog:(NSString *)format, ...;
@end

#pragma mark -

@implementation NSFont (withay_OpenGL)

static BOOL openGLLoggingEnabled = YES;
static BOOL fontOpenGLInitialized = NO;

// Scale 1
static NSMutableArray *imageArray = nil;                // FONT_TYPE_0
static NSMutableArray *imageArrayPreview = nil;         // FONT_TYPE_1
static NSMutableArray *imageArrayROI = nil;             // FONT_TYPE_2

static long charSizeArray[ MAXCOUNT];                   // FONT_TYPE_0
static long charSizeArrayPreview[ MAXCOUNT];            // FONT_TYPE_1
static long charSizeArrayROI[ MAXCOUNT];                // FONT_TYPE_2

static unsigned char *charPtrArray[ MAXCOUNT];          // FONT_TYPE_0
static unsigned char *charPtrArrayPreview[ MAXCOUNT];   // FONT_TYPE_1
static unsigned char *charPtrArrayROI[ MAXCOUNT];       // FONT_TYPE_2

// Scale 2
static NSMutableArray *imageArrayScale2 = nil;          // FONT_TYPE_0
static NSMutableArray *imageArrayPreviewScale2 = nil;   // FONT_TYPE_1
static NSMutableArray *imageArrayROIScale2 = nil;       // FONT_TYPE_2

static long charSizeArrayScale2[ MAXCOUNT];             // FONT_TYPE_0
static long charSizeArrayPreviewScale2[ MAXCOUNT];      // FONT_TYPE_1
static long charSizeArrayROIScale2[ MAXCOUNT];          // FONT_TYPE_2

static unsigned char *charPtrArrayScale2[ MAXCOUNT];        // FONT_TYPE_0
static unsigned char *charPtrArrayPreviewScale2[ MAXCOUNT]; // FONT_TYPE_1
static unsigned char *charPtrArrayROIScale2[ MAXCOUNT];     // FONT_TYPE_2

// Enable/disable logging, class-wide, not object-wide

+ (void) setOpenGLLogging:(BOOL)logEnabled
{
   openGLLoggingEnabled = logEnabled;
}

+ (void) resetFont: (int) fontType
{
	if (fontOpenGLInitialized == NO)
	{
        for (int i = 0; i < MAXCOUNT; i++) {
            charPtrArrayPreview[ i] = 0;
            charPtrArray[ i] = 0;
            charPtrArrayROI[ i] = 0;
        
            charPtrArrayPreviewScale2[ i] = 0;
            charPtrArrayScale2[ i] = 0;
            charPtrArrayROIScale2[ i] = 0;
        }
		
		fontOpenGLInitialized = YES;
	}
	
	switch (fontType)
	{
		case FONT_TYPE_0:
			if (imageArray)
			{
				for (int i = 0; i < MAXCOUNT; i++)
				{
					if (charPtrArray[ i])
                        free( charPtrArray[ i]);

                    charPtrArray[ i] = 0L;
				}
                
				[imageArray release];
				imageArray = nil;
			}
            
            if (imageArrayScale2)
			{
				for (int i = 0; i < MAXCOUNT; i++)
				{
                    if ( charPtrArrayScale2[ i]) {
                        free( charPtrArrayScale2[ i]);
                        charPtrArrayScale2[ i] = NULL;
                    }
				}
                
				[imageArrayScale2 release];
				imageArrayScale2 = nil;
			}
            break;
		
		case FONT_TYPE_PREVIEW:
			if (imageArrayPreview)
			{
				for (int i = 0; i < MAXCOUNT; i++)
				{
					if (charPtrArrayPreview[ i])
                        free( charPtrArrayPreview[ i]);
                    
					charPtrArrayPreview[ i] = 0L;
				}
                
				[imageArrayPreview release];
				imageArrayPreview = nil;
			}
            
            if (imageArrayPreviewScale2)
			{
				for (int i = 0; i < MAXCOUNT; i++)
				{
					if (charPtrArrayPreviewScale2[ i])
                        free( charPtrArrayPreviewScale2[ i]);
                    
					charPtrArrayPreviewScale2[ i] = 0L;
				}
                
				[imageArrayPreviewScale2 release];
				imageArrayPreviewScale2 = nil;
			}
            break;
		
		case FONT_TYPE_ROI:
			if (imageArrayROI)
			{
				for (int i = 0; i < MAXCOUNT; i++)
				{
					if (charPtrArrayROI[ i])
                        free( charPtrArrayROI[ i]);
                    
					charPtrArrayROI[ i] = 0L;
				}
                
				[imageArrayROI release];
				imageArrayROI = nil;
			}
            
            if (imageArrayROIScale2)
			{
				for (int i = 0; i < MAXCOUNT; i++)
				{
					if ( charPtrArrayROIScale2[ i])
                        free( charPtrArrayROIScale2[ i]);
                    
					charPtrArrayROIScale2[ i] = 0L;
				}
				[imageArrayROIScale2 release];
				imageArrayROIScale2 = nil;
			}
            break;
	}
}

+ (void) initFontImage:(unichar) first
                 count:(int) count
                  font:(NSFont*) font
              fontType:(FontType) fontType
               scaling:(float) scaling
{
	if (fontOpenGLInitialized == NO)
	{
        for (long i = 0; i < MAXCOUNT; i++) {
            charPtrArrayPreview[ i] = 0;
            charPtrArray[ i] = 0;
            charPtrArrayROI[ i] = 0;
            charPtrArrayPreviewScale2[ i] = 0;
            charPtrArrayScale2[ i] = 0;
            charPtrArrayROIScale2[ i] = 0;
        }
		
		fontOpenGLInitialized = YES;
	}
	
    if (scaling != 1.0 &&
        scaling != 2.0)
    {
        NSLog( @"******* ******* ******* ******* ******* *******");
        NSLog( @"******* UNKNOW scaling factor: %f", scaling);
        NSLog( @"******* ******* ******* ******* ******* *******");
        scaling = [[NSScreen mainScreen] backingScaleFactor];
    }
    
    NSMutableArray *curArray_A;
    long *curSizeArray;
    unsigned char **curPtrArray = nil;

    if (scaling == 2.0)
    {
        switch (fontType)
        {
            case FONT_TYPE_PREVIEW:
                curArray_A = imageArrayPreviewScale2;
                curSizeArray = charSizeArrayPreviewScale2;
                curPtrArray = charPtrArrayPreviewScale2;
                break;
                
            case FONT_TYPE_0:
                curArray_A = imageArrayScale2;
                curSizeArray = charSizeArrayScale2;
                curPtrArray = charPtrArrayScale2;
                break;
                
            case FONT_TYPE_ROI:
                curArray_A = imageArrayROIScale2;
                curSizeArray = charSizeArrayROIScale2;
                curPtrArray = charPtrArrayROIScale2;
                break;
        }
    }
    else
    {
        switch (fontType)
        {
            case FONT_TYPE_PREVIEW:
                curArray_A = imageArrayPreview;
                curSizeArray = charSizeArrayPreview;
                curPtrArray = charPtrArrayPreview;
                break;
            
            case FONT_TYPE_0:
                curArray_A = imageArray;
                curSizeArray = charSizeArray;
                curPtrArray = charPtrArray;
                break;
            
            case FONT_TYPE_ROI:
                curArray_A = imageArrayROI;
                curSizeArray = charSizeArrayROI;
                curPtrArray = charPtrArrayROI;
                break;
        }
    }
    
    for (long i = 0; i < MAXCOUNT; i++)
    {
        if (curPtrArray[ i])
            free( curPtrArray[ i]);
        
        curPtrArray[ i] = 0;
    }
	
	if (curArray_A == nil)
        curArray_A = [[NSMutableArray alloc] initWithCapacity:0];
	else
        [curArray_A removeAllObjects];
    
    NSColor *blackColor = [ NSColor blackColor ];
    NSDictionary *attribDict = [ NSDictionary dictionaryWithObjectsAndKeys:
                  font, NSFontAttributeName,
                  [ NSColor whiteColor ], NSForegroundColorAttributeName,
                  blackColor, NSBackgroundColorAttributeName,
                  nil ];
    NSRect charRect = NSZeroRect;
	for (unichar currentUnichar = first; currentUnichar < first + count; currentUnichar++)
	{
		@try
		{
            NSString *currentChar = [NSString stringWithCharacters:&currentUnichar length:1];
			NSSize charSize = [currentChar sizeWithAttributes: attribDict];
			charRect.size = charSize;
			charRect = NSIntegralRect( charRect);
			if (charRect.size.width <= 0 &&
                charRect.size.height <= 0) // character with no glyph in the current font
			{
				currentChar = @"?";
				charSize = [currentChar sizeWithAttributes: attribDict];
                
				charRect.size = charSize;
				charRect = NSIntegralRect( charRect);
			}	
            
            NSImage *theImage = [[NSImage alloc] initWithSize:NSZeroSize];
			[theImage setSize: charRect.size];
			
			if ([theImage size].width > 0 &&
                [theImage size].height > 0)
			{
				[theImage lockFocus];
                
                if (scaling == 1) // On Retina system, this will cancel the default 2x resolution in the NSImage "world"
                    [[NSAffineTransform transform] set];
                
				[blackColor set];
				[NSBezierPath fillRect:charRect];
				[[NSGraphicsContext currentContext] setShouldAntialias: NO];
				[currentChar drawInRect:charRect withAttributes:attribDict];
				[theImage unlockFocus];
			}
			
            NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:[theImage TIFFRepresentationUsingCompression:NSTIFFCompressionNone factor:0]];
			
			if (bitmap)
			{
                if (scaling == 1 &&
                    bitmap.pixelsWide / charRect.size.width == 2) // We don't want a Retina image, on a Retina OS...
                {
                    curSizeArray[currentUnichar] = bitmap.pixelsWide/2;
                }
                else
                    curSizeArray[currentUnichar] = bitmap.pixelsWide;
                
				[curArray_A addObject: bitmap];
				[theImage release];
				
				curPtrArray[ currentUnichar] = [NSFont createCharacterWithImage:[curArray_A objectAtIndex: currentUnichar - first]];
			}
		}
		@catch (NSException * e)
		{
            N2LogExceptionWithStackTrace(e);
		}
	}
    
    if (scaling == 2.0)
    {
        switch (fontType)
        {
            case FONT_TYPE_PREVIEW: imageArrayPreviewScale2 = curArray_A; break;
            case FONT_TYPE_0: imageArrayScale2 = curArray_A; break;
            case FONT_TYPE_ROI: imageArrayROIScale2 = curArray_A; break;
        }
    }
    else
    {
        switch (fontType)
        {
            case FONT_TYPE_PREVIEW: imageArrayPreview = curArray_A; break;
            case FONT_TYPE_0: imageArray = curArray_A; break;
            case FONT_TYPE_ROI: imageArrayROI = curArray_A; break;
        }
    }
}

/*
 * Create the set of display lists for the bitmaps
 */
- (BOOL) makeGLDisplayListFirst:(unichar) first
                          count:(int) count
                           base:(GLint) base
                               :(long*) charSizeArrayIn
                               :(FontType) fontType
                               :(float) scaling
{
    //NSLog(@"makeGLDisplayListFirst %d, font list: %i, type: %d", __LINE__, base, fontType);

    GLint dListNum;
	//unichar currentUnichar;
	BOOL retval;
	
	NSMutableArray *curArray_B = nil;
	long *curSizeArray = nil;
	unsigned char **curPtrArray = nil;
    
    if (scaling == 2.0)
    {
        switch (fontType)
        {
            case FONT_TYPE_0:
                if (imageArrayScale2 == nil)
                    [NSFont initFontImage:' ' count:NUM_DISPLAY_LISTS font:self fontType: fontType scaling: scaling];
                
                curArray_B = imageArrayScale2;
                curSizeArray = charSizeArrayScale2;
                curPtrArray = charPtrArrayScale2;
                break;
                
            case FONT_TYPE_PREVIEW:
                if (imageArrayPreviewScale2 == nil)
                    [NSFont initFontImage:' ' count:NUM_DISPLAY_LISTS font:self fontType: fontType scaling: scaling];
                
                curArray_B = imageArrayPreviewScale2;
                curSizeArray = charSizeArrayPreviewScale2;
                curPtrArray = charPtrArrayPreviewScale2;
                break;
                
            case FONT_TYPE_ROI:
                if (imageArrayROIScale2 == nil)
                    [NSFont initFontImage:' ' count:NUM_DISPLAY_LISTS font:self fontType: fontType scaling: scaling];
                
                curArray_B = imageArrayROIScale2;
                curSizeArray = charSizeArrayROIScale2;
                curPtrArray = charPtrArrayROIScale2;
                break;
        }
    }
    else
    {
        switch (fontType)
        {
            case FONT_TYPE_0:
                if (imageArray == nil)
                    [NSFont initFontImage:' ' count:NUM_DISPLAY_LISTS font:self fontType: fontType scaling: scaling];
                
                curArray_B = imageArray;
                curSizeArray = charSizeArray;
                curPtrArray = charPtrArray;
                break;
            
            case FONT_TYPE_PREVIEW:
                if (imageArrayPreview == nil)
                    [NSFont initFontImage:' ' count:NUM_DISPLAY_LISTS font:self fontType: fontType scaling: scaling];
                
                curArray_B = imageArrayPreview;
                curSizeArray = charSizeArrayPreview;
                curPtrArray = charPtrArrayPreview;
                break;
            
            case FONT_TYPE_ROI:
                if (imageArrayROI == nil)
                    [NSFont initFontImage:' ' count:NUM_DISPLAY_LISTS font:self fontType: fontType scaling: scaling];
                    
                curArray_B = imageArrayROI;
                curSizeArray = charSizeArrayROI;
                curPtrArray = charPtrArrayROI;
                break;
        }
	}
    
   // Make sure a list isn't already under construction
#ifndef WITH_OPENGL_32
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];

    GLint curListIndex;
    glGetIntegerv( GL_LIST_INDEX, &curListIndex );
    if (curListIndex != 0 )
    {
        [NSFont doOpenGLLog:@"Display list already under construction" ];
        return FALSE;
    }
#endif

    // Save pixel unpacking state
#ifdef WITH_OPENGL_32
    #ifndef NDEBUG
    NSLog(@"NSFont_OpenGL.mm %d makeGLDisplayListFirst, TODO: GL_CLIENT_PIXEL_STORE_BIT", __LINE__);
    #endif
#else
    glPushClientAttrib( GL_CLIENT_PIXEL_STORE_BIT );
#endif

   glPixelStorei( GL_UNPACK_SWAP_BYTES,     GL_FALSE );
   glPixelStorei( GL_UNPACK_LSB_FIRST,      GL_FALSE );
   glPixelStorei( GL_UNPACK_SKIP_ROWS,      GL_FALSE );
   glPixelStorei( GL_UNPACK_SKIP_PIXELS,    GL_FALSE );
   glPixelStorei( GL_UNPACK_ROW_LENGTH,     0 );
   glPixelStorei( GL_UNPACK_ALIGNMENT,      1 );  // otherwise default is 4
	
   glPixelStorei (GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
    // The cached hint specifies to cache texture data in video memory. This hint is recommended when you have textures that you plan to use multiple times or that use linear filtering

#ifndef WITH_OPENGL_32
   glTexParameteri (GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_CACHED_APPLE);
#endif
    
   retval = TRUE;
   unichar currentUnichar;
   for (dListNum = base, currentUnichar = first;
        currentUnichar < first + count;
        dListNum++, currentUnichar++ )
   {
	   charSizeArrayIn[ currentUnichar] = curSizeArray[ currentUnichar];
		
	   if (currentUnichar - first < curArray_B.count)
       {
			NSBitmapImageRep *bitmap = [curArray_B objectAtIndex: currentUnichar - first];
            if (bitmap)
            {
#ifndef WITH_OPENGL_32
                glNewList( dListNum, GL_COMPILE);
                
                if (curPtrArray[ currentUnichar])
                    glBitmap([bitmap pixelsWide],
                             [bitmap pixelsHigh],
                             0, 0, // origin
                             curSizeArray[currentUnichar],  // xmove
                             0,                             // ymove
                             curPtrArray[ currentUnichar]); // bitmap
                
                glEndList();
#endif
            }
		}
   } // for

#ifndef WITH_OPENGL_32
    glPopClientAttrib();
#endif

   return retval;
}

/*
 * Create one display list based on the given image.
 * This assumes the image uses 8-bit chunks to represent a sample.
 */
+ (unsigned char *) createCharacterWithImage:(NSBitmapImageRep *)bitmap
{
   int pixelsHigh = [bitmap pixelsHigh];
   int pixelsWide = [bitmap pixelsWide];
   unsigned char *bitmapBytes = [bitmap bitmapData];
   int bytesPerRow = [bitmap bytesPerRow];
   int samplesPerPixel = [bitmap samplesPerPixel];
   
   unsigned char *newBuffer = (unsigned char *)calloc( ceil( (float) bytesPerRow / 8.0 ), pixelsHigh);
   if (!newBuffer)
   {
		NSLog(@"Failed to calloc() memory in");
		return nil;
   }

   unsigned char *movingBuffer = newBuffer;

   /*
    * Convert the color bitmap into a true bitmap, ie, one bit per pixel.  We
    * read at last row, write to first row as Cocoa and OpenGL have opposite
    * y origins
    */
   for (int rowIndex = pixelsHigh - 1; rowIndex >= 0; rowIndex --)
   {
      int currentBit = 0x80;
      int byteValue = 0;
      for (int colIndex = 0; colIndex < pixelsWide; colIndex++)
      {
         if (bitmapBytes[ rowIndex * bytesPerRow + colIndex * samplesPerPixel])
             byteValue |= currentBit;

         currentBit >>= 1;
         if (currentBit == 0)
         {
            *movingBuffer++ = byteValue;
            currentBit = 0x80;
            byteValue = 0;
         }
      }

       if (currentBit != 0x80)
         *movingBuffer++ = byteValue;
   }
	
	return newBuffer;
}

/*
 * Log the warning/error, if logging is enabled
 */
+ (void) doOpenGLLog:(NSString *)format, ...
{
   va_list args;

   if (openGLLoggingEnabled)
   {
      va_start( args, format );
      NSLogv( [ NSString stringWithFormat:@"NSFont_OpenGL: %@\n", format ],
              args );
      va_end( args );
   }
}

@end
