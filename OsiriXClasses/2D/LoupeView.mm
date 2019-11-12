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
 Distributed under GNU - GPL
 
 See http://www.osirix-viewer.com/copyright.html for details.
 
 This software is distributed WITHOUT ANY WARRANTY; without even
 the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 PURPOSE.
 =========================================================================*/

#import "mgl.h" // include first

#import "LoupeView.h"

@implementation LoupeView

- (void)makeTextureFromImage:(NSImage*)image
                  forTexture:(GLuint*)texName
                      buffer:(GLubyte*)buffer;
{
    //NSLog(@"%s %d", __FUNCTION__, __LINE__);
	NSSize imageSize = [image size];
	
	NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithData:[image TIFFRepresentation]];
	
	buffer = (GLubyte *)malloc([bitmap bytesPerRow] * imageSize.height);
	memcpy(buffer, [bitmap bitmapData], [bitmap bytesPerRow] * imageSize.height);
	
	[bitmap release];
	
	CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
	glGenTextures(1, texName);
	glBindTexture(GL_TEXTURE_RECTANGLE_EXT, *texName);  // TODO: GLEW_EXT_texture_rectangle
	glPixelStorei(GL_UNPACK_ROW_LENGTH, [bitmap bytesPerRow]/[bitmap samplesPerPixel]);
	glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
	glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0,
                 ([bitmap samplesPerPixel]==4) ? GL_RGBA : GL_RGB,
                 imageSize.width, imageSize.height, 0,
                 ([bitmap samplesPerPixel]==4) ? GL_RGBA : GL_RGB,
                 GL_UNSIGNED_BYTE,
                 buffer);
}

- (void)setTexture:(char*)texture
          withSize:(NSSize)textureSize
       bytesPerRow:(int)bytesPerRow
          rotation:(float)rotation;
{
    //NSLog(@"%s %d", __FUNCTION__, __LINE__);
	textureRotation = rotation;
	
	[[self openGLContext] makeCurrentContext];
	CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
	
	if (textureID)
        glDeleteTextures(1, &textureID);

	if (textureWidth!=textureSize.width || textureHeight!=textureSize.height)
		//free(textureBuffer);
	
	textureWidth = textureSize.width;
	textureHeight = textureSize.height;
	
//	if(!textureBuffer)
//		textureBuffer = malloc(bytesPerRow * textureSize.height);
//	memcpy(textureBuffer, texture, bytesPerRow * textureSize.height);
	textureBuffer = (GLubyte *)texture;
	
	glGenTextures(1, &textureID);
	glBindTexture(GL_TEXTURE_RECTANGLE_EXT, textureID);
	glPixelStorei(GL_UNPACK_ROW_LENGTH, bytesPerRow);
	glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
	glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MIN_FILTER, GL_LINEAR);  // TODO: GLEW_EXT_texture_rectangle
	glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

	glColor4f( 1, 1, 1, 1);
    
#if __BIG_ENDIAN__
    GLenum _type = GL_UNSIGNED_INT_8_8_8_8_REV;
#else
    GLenum _type = GL_UNSIGNED_INT_8_8_8_8;
#endif

    glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0,
                 GL_RGBA,
                 textureSize.width, textureSize.height, 0,
                 GL_BGRA, _type,
                 textureBuffer);
		
	[self setNeedsDisplay:YES];
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    //NSLog(@"%s %d", __FUNCTION__, __LINE__);
	NSOpenGLPixelFormatAttribute attrs[] =
    {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFADepthSize, (NSOpenGLPixelFormatAttribute)32,
        0
    };

    NSOpenGLPixelFormat* pixFmt = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attrs] autorelease];
#ifndef NDEBUG
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    const GLubyte *strVersion = glGetString(GL_VERSION);
    NSLog(@"%s %d, OpenGL %s, ctx:%p, class:%@", __FUNCTION__, __LINE__, strVersion, cgl_ctx, NSStringFromClass([self class]));
#endif

	self = [super initWithFrame:frameRect pixelFormat:pixFmt];
    if (self)
	{
		NSBundle *bundle = [NSBundle bundleForClass: [LoupeView class]];
		loupeImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"loupe.png"]];
		loupeTextureWidth = [loupeImage size].width;
		loupeTextureHeight = [loupeImage size].height;
		loupeMaskImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"loupeMask.png"]];
		loupeMaskTextureWidth = [loupeMaskImage size].width;
		loupeMaskTextureHeight = [loupeMaskImage size].height;
		_drawLoupeBorder = NO;
    }
    return self;
}

- (void) dealloc
{
	if (loupeTextureBuffer)
		free(loupeTextureBuffer);

	if (loupeMaskTextureBuffer)
		free(loupeMaskTextureBuffer);
	
	if (textureBuffer)
		free(textureBuffer);
	
	[super dealloc];
}

- (void)drawRect:(NSRect)rect
{
    //NSLog(@"%s %d", __FUNCTION__, __LINE__);
	CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];

	GLint opaque = 0;
	[[self openGLContext] setValues:&opaque forParameter:NSOpenGLCPSurfaceOpacity];
	glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
	glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
	
    glViewport(0, 0, [self frame].size.width, [self frame].size.height);
#ifdef WITH_OPENGL_32
    // TODO:
#else
	glMatrixMode (GL_MODELVIEW);
	glLoadIdentity ();
	glScalef(2.0f/[self frame].size.width, -2.0f / [self frame].size.height, 1.0f);
	glTranslatef(-([self frame].size.width)/2.0f, -([self frame].size.height)/2.0f, 0.0f); // translate center to upper left
#endif

	glEnable(GL_BLEND);
//	glBlendEquation(GL_FUNC_ADD);
//	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	if (loupeTextureID==0)
		[self makeTextureFromImage:loupeImage forTexture:&loupeTextureID buffer:loupeTextureBuffer];

	if (loupeMaskTextureID==0)
		[self makeTextureFromImage:loupeMaskImage forTexture:&loupeMaskTextureID buffer:loupeMaskTextureBuffer];

	if (loupeMaskTextureID)
	{		
		glEnable(GL_TEXTURE_RECTANGLE_EXT);
		
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, loupeMaskTextureID);
		
		glColor4f(1.0, 1.0, 1.0, 1.0);
		
		glBegin(GL_QUAD_STRIP);
        {
            glTexCoord2f(0, 0);
            glVertex2f(0, 0);
            
            glTexCoord2f(loupeMaskTextureWidth, 0);
            glVertex2f(loupeMaskTextureWidth, 0);
            
            glTexCoord2f(0, loupeMaskTextureHeight);
            glVertex2f(0, loupeMaskTextureHeight);
            
            glTexCoord2f(loupeMaskTextureWidth, loupeMaskTextureHeight);
            glVertex2f(loupeMaskTextureWidth, loupeMaskTextureHeight);
        }
		glEnd();
		
		glDisable(GL_TEXTURE_RECTANGLE_EXT);
	}

	if (textureID)
	{
		glBlendFunc(GL_DST_ALPHA, GL_ZERO);
		
        {
        GLfloat x = [self frame].size.width/2.0f;
        GLfloat y = [self frame].size.height/2.0f;
		glTranslatef(x, y, 0.0f); // translate the origin to the center
		glRotatef(textureRotation, 0.0f, 0.0f, 1.0f);
		glTranslatef(-x, -y, 0.0f); // translate the origin to upper left corner
        }
		
		glPixelStorei(GL_UNPACK_ROW_LENGTH, textureWidth*4);
		glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);

		glEnable(GL_TEXTURE_RECTANGLE_EXT);
		
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, textureID);
				
		glColor4f(1.0, 1.0, 1.0, 1.0);

		glPixelStorei(GL_UNPACK_ROW_LENGTH, textureWidth*4);
		glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);

		glBegin(GL_QUAD_STRIP);
        {
            glTexCoord2f(0, 0);
            glVertex2f(0, 0);
            
            glTexCoord2f(textureWidth, 0);
            glVertex2f([self frame].size.width, 0);
            
            glTexCoord2f(0, textureHeight);
            glVertex2f(0, [self frame].size.height);
            
            glTexCoord2f(textureWidth, textureHeight);
            glVertex2f([self frame].size.width, [self frame].size.height);
        }
		glEnd();
		
		glDisable(GL_TEXTURE_RECTANGLE_EXT);
		
        {
        GLfloat x = [self frame].size.width / 2.0f;
        GLfloat y = [self frame].size.height / 2.0f;
		glTranslatef( x, y, 0.0f); // translate the origin to the center
		glRotatef(-textureRotation, 0.0f, 0.0f, 1.0f);
		glTranslatef(-x, -y, 0.0f); // translate the origin to upper left corner
        }
	}
	
	glBlendEquation(GL_FUNC_ADD);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	
	if (loupeTextureID && _drawLoupeBorder)
	{
		glEnable(GL_TEXTURE_RECTANGLE_EXT);
		
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, loupeTextureID);
		
		glColor4f(1.0, 1.0, 1.0, 1.0);
		
		glBegin(GL_QUAD_STRIP);
        {
			glTexCoord2f(0, 0);
			glVertex2f(0, 0);
			
			glTexCoord2f(loupeTextureWidth, 0);
			glVertex2f(loupeTextureWidth, 0);
			
			glTexCoord2f(0, loupeTextureHeight);
			glVertex2f(0, loupeTextureHeight);
			
			glTexCoord2f(loupeTextureWidth, loupeTextureHeight);
			glVertex2f(loupeTextureWidth, loupeTextureHeight);
        }
		glEnd();

		glDisable(GL_TEXTURE_RECTANGLE_EXT);
	}
	
//	glColor4f(0.7, 0.7, 0.0, 1.0);
//	glLineWidth(10);
//	
//	int resol = 80;//[self frame].size.width*4.0;
//	
//	NSPoint center;
//	center.x += [self frame].size.width*0.5;
//	center.y += [self frame].size.height*0.5;
//	
//	glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);
//	glHint(GL_LINE_SMOOTH_HINT, GL_NICEST);
//#ifndef WITH_OPENGL_32
//        glEnable(GL_POINT_SMOOTH);
//#endif
//	glEnable(GL_LINE_SMOOTH);
//	glEnable(GL_POLYGON_SMOOTH);
//	
//	float f = [self frame].size.width*0.5-5;
//	float angle;
//	glBegin(GL_LINE_LOOP);
//	for (int i = 0; i < resol ; i++ )
//	{
//		angle = i * 2 * M_PI /resol;
//		glVertex2f( center.x + f *cos(angle), center.y + f *sin(angle));
//	}
//	glEnd();
	
//	glPointSize( 10);
//	glBegin( GL_POINTS);
//	for( int i = 0; i < resol ; i++ )
//	{
//		angle = i * 2 * M_PI /resol;
//		
//		glVertex2f( center.x + f *cos(angle), center.y + f *sin(angle));
//	}
//	glEnd();
//	glDisable(GL_LINE_SMOOTH);
//	glDisable(GL_POLYGON_SMOOTH);
//#ifndef WITH_OPENGL_32
//    glDisable(GL_POINT_SMOOTH);
//#endif
	
	glDisable(GL_BLEND);
	
	[[self openGLContext] flushBuffer];	
}

-(void)awakeFromNib
{
    [self setNeedsDisplay:YES];
}

@end
