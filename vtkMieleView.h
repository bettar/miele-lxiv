//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//
//  At the end of 2014 the project was forked from OsiriX to become Miele-LXIV
//  The original header follows:
/*=========================================================================
 Program:   OsiriX

 Copyright (c) Pixmeo
 All rights reserved.
 =========================================================================*/

#ifndef _VTKVIEWOSIRIX_H_INCLUDED_
#define _VTKVIEWOSIRIX_H_INCLUDED_

#import "options.h"

#include "vtkAutoInit.h"
VTK_MODULE_INIT(vtkRenderingOpenGL2);
VTK_MODULE_INIT(vtkRenderingVolumeOpenGL2);
VTK_MODULE_INIT(vtkRenderingFreeType);

#import <AppKit/AppKit.h>

#ifdef __cplusplus
#import "vtkCocoaGLView.h"
#define id Id
#include "vtkRenderer.h"
#include "vtkRenderWindow.h"
#include "vtkRenderWindowInteractor.h"
#include "vtkCocoaRenderWindowInteractor.h"
#include "vtkCocoaRenderWindow.h"
#undef id
#else
/*
typedef char* vtkCocoaWindow;
typedef char* vtkRenderer;
typedef char* vtkRenderWindow;
typedef char* vtkRenderWindowInteractor;
typedef char* vtkCocoaRenderWindowInteractor;
typedef char* vtkCocoaRenderWindow;
 */
#endif

/** \brief View for using VTK */
@interface vtkMieleView : vtkCocoaGLView
{
    vtkCocoaRenderWindow *_cocoaRenderWindow;
    vtkRenderer *_renderer;
}

+ (unsigned long) VRAMSizeForDisplayID: (CGDirectDisplayID) displayID;

-(instancetype)initWithFrame:(NSRect)frame;
-(void)dealloc;

// Access to VTK instances
-(vtkRenderer *)renderer;
-(vtkRenderWindow *)renderWindow;
-(vtkCocoaRenderWindow *) cocoaWindow;
-(void)removeAllActors;
-(void) prepareForRelease;

- (void)initializeVTKSupport;
- (void)cleanUpVTKSupport;

+ (void) addTiffLogo:(NSString*) name
                    :(int) dstStride
                    :(unsigned char *) buf
                    :(long) height
                    :(long) width
                    :(long) rowBytes
                    :(int) marginH // pixels margin
                    :(BOOL) rightSide;

// Accessors
- (void)setRenderer:(vtkRenderer*)theRenderer;

@end

#endif
