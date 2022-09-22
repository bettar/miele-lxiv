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

#include "options.h"
#import "mgl.h" // include first

#import "NSFont_OpenGL/NSFont+OpenGL.h"
#import "PreviewView.h"

@implementation PreviewView

- (void) changeGLFontNotification:(NSNotification*) note
{
	if ([note object] != self)
        return;

    [[self openGLContext] makeCurrentContext];
    
#ifndef WITH_OPENGL_32
    CGLContextObj cgl_ctx = [[NSOpenGLContext currentContext] CGLContextObj];
    if (cgl_ctx == nil)
        return;
    
    if (fontListGL)
        glDeleteLists (fontListGL, NUM_DISPLAY_LISTS);
    
    fontListGL = glGenLists(NUM_DISPLAY_LISTS);
    assert(fontListGL != 0);
#endif

    [fontGL release];
    fontGL = [[NSFont systemFontOfSize: 12] retain];
    
    [fontGL makeGLDisplayListFirst:' '
                             count:NUM_DISPLAY_LISTS
                              base:fontListGL
                                  :fontListGLSize
                                  :FONT_TYPE_PREVIEW
                                  :self.window.backingScaleFactor];

    stringSize = [self convertSizeToBacking: [DCMView sizeOfString:@"B" forFont:fontGL]];
    
    [DCMView purgeStringTextureCache];
    [stringTextureDic release];
    stringTextureDic = nil;
    
    [self setNeedsDisplay:YES];
}

- (BOOL)is2DViewer
{
	return NO;
}

-(BOOL)actionForHotKey:(NSString *)hotKey
{
	NSLog(@"preview Hot Key");
	return [super actionForHotKey:(NSString *)hotKey];
}

@end
