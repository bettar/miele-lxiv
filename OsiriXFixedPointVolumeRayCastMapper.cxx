//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//
//  At the end of 2014 the project was forked from OsiriX to become Miele-LXIV
//  The original version of this file had no header

#import "mgl.h" // for WITH_OPENGL_32

#include "OsiriXFixedPointVolumeRayCastMapper.h"

#include "vtkObjectFactory.h"
#include "vtkRenderWindow.h"
#include "vtkRenderer.h"
#include "vtkTimerLog.h"
#include "vtkOpenGLRenderWindow.h"
#include "vtkImageData.h"

#ifndef NDEBUG
#include "vtkRayCastImageDisplayHelper.h"
#include "vtkFixedPointRayCastImage.h"
#endif

#include <cmath>

bool dontRenderVolumeRenderingOsiriX = false;

vtkStandardNewMacro(OsiriXFixedPointVolumeRayCastMapper);

OsiriXFixedPointVolumeRayCastMapper::OsiriXFixedPointVolumeRayCastMapper()
{
    //this->MIPHelper = vtkMieleFixedPointVolumeRayCastHelper::New();
}

// See VTK's vtkFixedPointVolumeRayCastMapper.cxx line 1361
void OsiriXFixedPointVolumeRayCastMapper::Render( vtkRenderer *ren, vtkVolume *vol )
{
#ifndef NDEBUG
    vtkDebugMacro(<< "Blend mode = " << this->GetBlendMode()); // COMPOSITE_BLEND
#endif

#if 1 // added after comparing with latest VTK code
    if (vtkImageData::SafeDownCast(this->GetInput()) == nullptr)
    {
      vtkWarningMacro("Mapper supports only vtkImageData");
      return;
    }

    if (this->GetBlendMode() != vtkVolumeMapper::COMPOSITE_BLEND &&
      this->GetBlendMode() != vtkVolumeMapper::MAXIMUM_INTENSITY_BLEND &&
      this->GetBlendMode() != vtkVolumeMapper::MINIMUM_INTENSITY_BLEND &&
      this->GetBlendMode() != vtkVolumeMapper::ADDITIVE_BLEND)
    {
      vtkErrorMacro(<< "Selected blend mode not supported. "
                    << "Only Composite, MIP, MinIP and additive modes "
                    << "are supported by the fixed point implementation.");
      return;
    }
#endif

    this->Timer->StartTimer();

    // Since we are passing in a value of 0 for the multiRender flag
    // (this is a single render pass - not part of a multipass AMR render)
    // then we know the origin, spacing, and extent values will not
    // be used so just initialize everything to 0. No need to check
    // the return value of the PerImageInitialization method - since this
    // is not a multirender it will always return 1.
    double dummyOrigin[3]  = {0.0, 0.0, 0.0};
    double dummySpacing[3] = {0.0, 0.0, 0.0};
    int dummyExtent[6] = {0, 0, 0, 0, 0, 0};
    this->PerImageInitialization(ren, vol, 0, dummyOrigin, dummySpacing, dummyExtent);

    this->PerVolumeInitialization( ren, vol );

    vtkRenderWindow *renWin = ren->GetRenderWindow(); // vtkCocoaRenderWindow

#if 1 // @@@ TBC
    vtkOpenGLRenderWindow *rw = (vtkOpenGLRenderWindow *)renWin;
    //if (!rw->Initialized)
        rw->OpenGLInit();
#endif
    
    if (renWin && renWin->CheckAbortStatus())
    {
      this->AbortRender();
      return;
    }

    this->PerSubVolumeInitialization(ren, vol, 0);
    if (renWin && renWin->CheckAbortStatus())
    {
      this->AbortRender();
      return;
    }

    if (!dontRenderVolumeRenderingOsiriX)  // Our addition
        this->RenderSubVolume();

    if (renWin && renWin->CheckAbortStatus())
    {
        this->AbortRender();
        return;
    }

#if 0 //ndef NDEBUG
    this->DebugOn();
    vtkIndent *indent = vtkIndent::New();
    std::cerr << this->GetClassName() << std::endl;
    this->PrintSelf(std::cerr, *indent);

    std::cerr << "\n=== ImageDisplayHelper" << std::endl;
    this->ImageDisplayHelper->PrintSelf(std::cerr, *indent);

    std::cerr << "\n=== RayCastImage" << std::endl;
    this->RayCastImage->PrintSelf(std::cerr, *indent);

    std::cerr << "\n=== ren" << std::endl;
    ren->PrintSelf(std::cerr, *indent);
#endif

#if 0 //ndef NDEBUG
    std::cerr << __FILE__ << ":" << __LINE__
    << ", ren:" << ren->GetClassName() // vtkOpenGLRenderer
    << ", win:" << ren->GetRenderWindow()->GetClassName() // vtkCocoaRenderWindow
    << std::endl;
#endif

    this->DisplayRenderedImage( ren, vol ); // Issue #i18

    this->Timer->StopTimer();
    this->TimeToDraw = this->Timer->GetElapsedTime();
    // If we've increased the sample distance, account for that in the stored time. Since we
    // don't get linear performance improvement, use a factor of .66
    this->StoreRenderTime( ren, vol,
			 this->TimeToDraw * this->ImageSampleDistance * this->ImageSampleDistance *
			 (1.0 + 0.66 * (this->SampleDistance - this->OldSampleDistance) / this->OldSampleDistance));

    this->SampleDistance = this->OldSampleDistance;
}
