//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//
//  At the end of 2014 the project was forked from OsiriX to become Miele-LXIV
//  The original version of this file had no header

#import "mgl.h" // for WITH_OPENGL_32

#include "vtkMieleFixedPointVolumeRayCastMapper.h"

#include "vtkObjectFactory.h"
#include "vtkRenderWindow.h"
#include "vtkRenderer.h"
#include "vtkTimerLog.h"
//#include "vtkOpenGLRenderWindow.h"
#include "vtkImageData.h"

#include "vtkMieleFixedPointVolumeRayCastMIPHelper.h"

#include "vtkFixedPointRayCastImage.h"
#include "vtkDataArray.h"
#include "vtkPointData.h"

#ifndef NDEBUG
#include "vtkRayCastImageDisplayHelper.h"
#endif

#include <cmath>
#include <algorithm>
#include <iostream>

#include "vtkVersion.h"

static_assert(VTK_MAJOR_VERSION == 9 && VTK_MINOR_VERSION == 7,
              "vtkMieleFixedPointVolumeRayCastMapper must compile against VTK 9.7 headers");

extern bool skipRenderingVR; // Moved to VRView.mm

vtkStandardNewMacro(vtkMieleFixedPointVolumeRayCastMapper);

vtkMieleFixedPointVolumeRayCastMapper::vtkMieleFixedPointVolumeRayCastMapper()
{
    // Issue e27
    this->MIPHelper = vtkMieleFixedPointVolumeRayCastMIPHelper::New();
}

// See VTK's vtkFixedPointVolumeRayCastMapper.cxx line 1361
void vtkMieleFixedPointVolumeRayCastMapper::Render( vtkRenderer *ren, vtkVolume *vol )
{
    //vtkDebugMacro(<< "Blend mode = " << this->GetBlendMode());

#if 1 // added after comparing with latest VTK code
    if (vtkImageData::SafeDownCast(this->GetInput()) == nullptr)
    {
      vtkWarningMacro("Mapper supports only vtkImageData");
      return;
    }

    // AVERAGE_INTENSITY_BLEND not supported (Issue e27)
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
    double dummyOrigin[3] = { 0.0, 0.0, 0.0 };
    double dummySpacing[3] = { 0.0, 0.0, 0.0 };
    int dummyExtent[6] = { 0, 0, 0, 0, 0, 0 };
    this->PerImageInitialization(ren, vol, 0, dummyOrigin, dummySpacing, dummyExtent);

    this->PerVolumeInitialization(ren, vol);
#ifndef NDEBUG
    {
        vtkImageData *input = vtkImageData::SafeDownCast(this->GetInput());
        vtkDataArray *inputScalars = input->GetPointData()->GetScalars();

        std::cerr << "CPU input tuples="
                  << (inputScalars ? inputScalars->GetNumberOfTuples() : -1)
                  << " current tuples="
                  << (this->CurrentScalars ? this->CurrentScalars->GetNumberOfTuples() : -1)
                  << " scalarMode=" << this->GetScalarMode()
                  << std::endl;
    }
#endif
#ifndef NDEBUG
    {
        double mapperRange[2];
        this->GetCurrentScalars()->GetRange(mapperRange);

        std::cerr << "CPU mapper scalars=" << this->GetCurrentScalars()->GetClassName()
                  << " components=" << this->GetCurrentScalars()->GetNumberOfComponents()
                  << " range=(" << mapperRange[0] << "," << mapperRange[1] << ")"
                  << std::endl;
    }
    {
        auto* mapperData =
          static_cast<unsigned short*>(this->GetCurrentScalars()->GetVoidPointer(0));

        std::cerr << "mapper data=" << static_cast<void*>(mapperData)
                  << " voxels=(" << mapperData[0] << "," << mapperData[1]
                  << "," << mapperData[1000] << ")" << std::endl;
    }
#endif

    vtkRenderWindow* renWin = ren->GetRenderWindow(); // vtkCocoaRenderWindow

#if 0 // @@@ TBC (not in VTK)
  #if 0 // original
    vtkOpenGLRenderWindow *rw = (vtkOpenGLRenderWindow *)renWin;
    //if (!rw->Initialized)
        rw->OpenGLInit();
  #else // #g93
    //vtkOpenGLRenderWindow *rw = static_cast<vtkOpenGLRenderWindow*>(renWin);
    auto rw = vtkOpenGLRenderWindow::SafeDownCast(renWin);
    {
        static bool Initialized = false;
        if (!Initialized) {
            rw->OpenGLInit();
            #ifndef NDEBUG
            int majorV, minorV;
            rw->GetOpenGLVersion(majorV, minorV); // 4.1
            #endif
            Initialized = true;
        }
    }
    
    rw->MakeCurrent();
  #endif
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

#if 1
    if (!skipRenderingVR)  // Our addition
#endif
    {
#ifndef NDEBUG
        {
            if (this->CurrentScalars)
            {
                double scalarRange[2];
                this->CurrentScalars->GetRange(scalarRange);

                std::cerr << "CPU mapper tuples="
                          << this->CurrentScalars->GetNumberOfTuples()
                          << " components=" << this->CurrentScalars->GetNumberOfComponents()
                          << " range=(" << scalarRange[0] << "," << scalarRange[1] << ")"
                          << " first=" << this->CurrentScalars->GetTuple1(0)
                          << std::endl;
            }
        }
#endif
        this->RenderSubVolume(); // #g93
    }

#ifndef NDEBUG
    {
        int imageSize[2];
        this->RayCastImage->GetImageMemorySize(imageSize);

        unsigned short maxAlpha = 0;
        unsigned short* image = this->RayCastImage->GetImage();
        for (int i = 0; i < imageSize[0] * imageSize[1]; ++i)
            maxAlpha = std::max(maxAlpha, image[4 * i + 3]);

        //NSLog(@"CPU ray-cast image=%dx%d maxAlpha=%u", imageSize[0], imageSize[1], maxAlpha);
        std::cerr << "CPU ray-cast image=" << imageSize[0] << "x" << imageSize[1]
                  << " maxAlpha=" << maxAlpha << std::endl;
    }
#endif
    
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
    
    std::cerr << __FILE__ << ":" << __LINE__
    << ", ren:" << ren->GetClassName() // vtkOpenGLRenderer
    << ", win:" << ren->GetRenderWindow()->GetClassName() // vtkCocoaRenderWindow
    << std::endl;
#endif

#ifdef WITH_OPENGL_32
    this->DisplayRenderedImage(ren, vol); // Issue i18, g93 ? // FIXME:
#endif

    this->Timer->StopTimer();
    this->TimeToDraw = this->Timer->GetElapsedTime();
    // If we've increased the sample distance, account for that in the stored time. Since we
    // don't get linear performance improvement, use a factor of .66
    this->StoreRenderTime(ren, vol,
			 this->TimeToDraw * this->ImageSampleDistance * this->ImageSampleDistance *
			 (1.0 + 0.66 * (this->SampleDistance - this->OldSampleDistance) / this->OldSampleDistance));

    this->SampleDistance = this->OldSampleDistance;
}
