//
//  mgl.h
//  Miele_LXIV
//
//  Created by Alessandro Bettarini on 10 Nov 2019.
//  Copyright © 2019 bettar. All rights reserved.
//  License GPLv3.0 -- see License File
//
// Purpose: centralized place to include OpenGL related header files

#ifndef mgl_h
#define mgl_h

#define WITH_OPENGL_32 // core profile
//#define WITH_GLEW

#ifdef WITH_OPENGL_32
//#define WITH_OPENGL_32_STEP2   2  // overlay program with only 2D points
//#define WITH_OPENGL_32_STEP3   3  // overlay program with renderer call
#endif

#pragma mark -

//#import <vtk_glew.h>

#ifdef WITH_GLEW
#import <GLEW/glew.h>
#else

#define GL_GLEXT_WUNDEF_SUPPORT // see glext.h

#ifdef WITH_OPENGL_32
#import <OpenGL/gl3.h>
#import <OpenGL/gl3ext.h>
#else
#import <OpenGL/OpenGL.h>
#import <OpenGL/CGLCurrent.h>
#import <OpenGL/CGLMacro.h>
#import <OpenGL/glu.h> // for gluUnProject, it includes gl.h
//#import <OpenGL/gl.h>
//#import <OpenGL/glext.h>
#endif

#endif // WITH_GLEW

#import <OpenGL/CGLContext.h> // for (*cgl_ctx->disp.delete_textures)

#if defined(WITH_OPENGL_32)
//#define WITH_SWIZZLE_MASK
#endif

#endif /* mgl_h */
