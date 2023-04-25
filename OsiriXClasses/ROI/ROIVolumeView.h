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
	 
	 
	ROIVolumeView creates and displays an ROI Volume created feom a stack of 2D ROIs
=========================================================================*/

#import <AppKit/AppKit.h>
#import "options.h"
#import "vtkMieleView.h"
#import "DCMPix.h"
#import "Camera.h"

#define id Id
#include "vtkSphereSource.h"
#include "vtkGlyph3D.h"
#include "vtkSurfaceReconstructionFilter.h"
#include "vtkReverseSense.h"
#include "vtkCommand.h"
#include "vtkDelaunay3D.h"
#include "vtkDelaunay2D.h"
#include "vtkProperty.h"
#include "vtkActor.h"
#include "vtkPolyData.h"
#include "vtkRenderer.h"
#include "vtkOrientationMarkerWidget.h"
#include "vtkAnnotatedCubeActor.h"
#include "vtkRenderWindow.h"
#include "vtkRenderWindowInteractor.h"
#include "vtkPolyDataMapper.h"
#include "vtkActor.h"

#include "vtkOutlineFilter.h"
#include "vtkImageImport.h"
#include "vtkCamera.h"

#include "vtkPolyDataNormals.h"
#include "vtkContourFilter.h"

#include "vtkImageData.h"

#include "vtkDataSetMapper.h"

#include "vtkDecimatePro.h"
#include "vtkSmoothPolyDataFilter.h"

#include "vtkTIFFReader.h"

#include "vtkTexture.h"
#include "vtkTextureMapToSphere.h"

#include "vtkPowerCrustSurfaceReconstruction.h"

#undef id

class vtkMyCallback;

#import <Accelerate/Accelerate.h>
#import "ViewerController.h"
#import "WaitRendering.h"

@class Camera;

/** \brief  View for ROI Volume */

@interface ROIVolumeView : vtkMieleView
{
    vtkRenderer					*aRenderer;
    vtkCamera					*aCamera;
	
//	vtkActor					*ballActor;
	vtkActor					*roiVolumeActor;
	vtkTexture					*texture;
	
    vtkActor					*outlineRect;
    vtkPolyDataMapper			*mapOutline;
    vtkOutlineFilter			*outlineData;
	vtkOrientationMarkerWidget	*orientationWidget;
	
    ROI                         *roi;
	BOOL						computeMedialSurface;
}


- (NSDictionary*) setPixSource: (ROI*) r;
- (void) setROIActorVolume:(NSValue*)roiActorPointer;

- (void) setOpacity: (float) opacity
         showPoints: (BOOL) sp
        showSurface: (BOOL) sS
      showWireframe: (BOOL) w
            texture: (BOOL) tex
           useColor: (BOOL) usecol
              color: (NSColor*) col;

- (IBAction) exportDICOMFile:(id) sender;
- (NSDictionary*) renderVolume;
+ (vtkMapper*) generateMapperForRoi:(ROI*) roi viewerController: (ViewerController*) vc factor: (float) factor statistics: (NSMutableDictionary*) statistics;
- (NSSet *)connectedPointsForPoint:(vtkIdType)pt fromPolyData:(vtkPolyData *)data;

@end
