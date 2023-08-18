// Adapted from VTK
//  Rendering/Volume/vtkFixedPointVolumeRayCastMIPHelper.h
/*=========================================================================

  Program:   Visualization Toolkit
  Module:    vtkMieleFixedPointVolumeRayCastMIPHelper.h

  Copyright (c) Ken Martin, Will Schroeder, Bill Lorensen
  All rights reserved.
  See Copyright.txt or http://www.kitware.com/Copyright.htm for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.  See the above copyright notice for more information.

=========================================================================*/
/**
 * @class   vtkMieleFixedPointVolumeRayCastMIPHelper
 * @brief   A helper that generates MIP images for the volume ray cast mapper
 *
 * This is one of the helper classes for the vtkMieleFixedPointVolumeRayCastMapper.
 * It will generate maximum intensity images.
 * This class should not be used directly, it is a helper class for
 * the mapper and has no user-level API.
 *
 * @sa
 * vtkMieleFixedPointVolumeRayCastMapper
 */

#ifndef vtkMieleFixedPointVolumeRayCastMIPHelper_h
#define vtkMieleFixedPointVolumeRayCastMIPHelper_h

#include "vtkRenderingVolumeModule.h" // For export macro
#include "vtkFixedPointVolumeRayCastMIPHelper.h"

class vtkFixedPointVolumeRayCastMapper;
class vtkVolume;

class VTKRENDERINGVOLUME_EXPORT vtkMieleFixedPointVolumeRayCastMIPHelper
  : public vtkFixedPointVolumeRayCastMIPHelper
{
public:
  static vtkMieleFixedPointVolumeRayCastMIPHelper* New();
  vtkTypeMacro(vtkMieleFixedPointVolumeRayCastMIPHelper, vtkFixedPointVolumeRayCastHelper);
  void PrintSelf(ostream& os, vtkIndent indent) override;

  void GenerateImage(int threadID, int threadCount, vtkVolume* vol,
    vtkFixedPointVolumeRayCastMapper* mapper) override;

protected:
  vtkMieleFixedPointVolumeRayCastMIPHelper();
  ~vtkMieleFixedPointVolumeRayCastMIPHelper() override;

private:
  vtkMieleFixedPointVolumeRayCastMIPHelper(const vtkFixedPointVolumeRayCastMIPHelper&) = delete;
  void operator=(const vtkMieleFixedPointVolumeRayCastMIPHelper&) = delete;
};

#endif
