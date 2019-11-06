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
#ifdef _STEREO_VISION_

#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>

#ifdef __cplusplus
#import "vtkCocoaGLView.h"
#import "vtkMieleView.h"

//#import "vtkCocoaWindow.h"
#define id Id
#include "vtkCamera.h"
#include "vtkRenderer.h"
#include "vtkRenderWindow.h"
#include "vtkRenderWindowInteractor.h"
#include "vtkCocoaRenderWindowInteractor.h"
#include "vtkCocoaRenderWindow.h"

#undef id
#else
typedef char* vtkCocoaWindow;
typedef char* vtkRenderer;
typedef char* vtkRenderWindow;
typedef char* vtkRenderWindowInteractor;
typedef char* vtkCocoaRenderWindowInteractor;
typedef char* vtkCocoaRenderWindow;
typedef char* vtkCamera;
#endif

@class SRView;

@interface VTKStereoSRView : vtkMieleView
{
	NSCursor *cursor;
	SRView	*superSRView;
}

-(id)initWithFrame:(NSRect)frame: (SRView*) aSRView;

@end
#endif
