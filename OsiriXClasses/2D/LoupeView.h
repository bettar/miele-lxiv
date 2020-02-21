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

#import <Cocoa/Cocoa.h>
#import "DCMView.h"

@interface LoupeView : NSOpenGLView
{
    NSImage *loupeRingImage;	
    GLuint loupeRingTextureID;
    GLuint loupeTextureWidth, loupeTextureHeight;
	GLubyte *loupeTextureBuffer;
	
    NSImage *loupeMaskImage;
    GLuint loupeMaskTextureID;
    GLuint loupeMaskTextureWidth, loupeMaskTextureHeight;
	GLubyte *loupeMaskTextureBuffer;
	
	GLuint textureID, textureWidth, textureHeight;
	GLubyte *textureBuffer;
	float textureRotation;
}

@property BOOL drawLoupeBorder;

- (void)makeTextureObjectFromImage: (NSImage*)image
                        forTexture: (GLuint*)texName
                            buffer: (GLubyte*)buffer;

- (void)setTexture:(char*)texture
          withSize:(NSSize)textureSize
       bytesPerRow:(int)bytesPerRow
          rotation:(float)rotation;
	
@end
